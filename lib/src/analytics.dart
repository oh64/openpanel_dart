import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'constants.dart';
import 'errors.dart';
import 'identity/identity_store.dart';
import 'models/track_request.dart';
import 'models/transport_result.dart';
import 'platform/device_context.dart';
import 'queue/event_queue.dart';
import 'transport/track_transport.dart';

/// Flutter analytics client for [OpenPanel](https://openpanel.dev).
///
/// The client is fire-and-forget by design: every public asynchronous method
/// only schedules work. Events are persisted *before* any attempt to send
/// them, so nothing is lost when the application is killed while a flush is in
/// flight. Use `OpenpanelAnalytics.instance` for a process wide singleton or
/// construct your own instance.
///
/// Self-hosting is supported by pointing [OpenpanelConfig.apiUrl] at your own
/// domain and, if necessary, adding extra headers such as `Origin`.
class OpenpanelAnalytics {
  OpenpanelAnalytics({
    @visibleForTesting TrackTransport? transport,
    @visibleForTesting EventQueue? queue,
    @visibleForTesting IdentityStore? identityStore,
    @visibleForTesting DeviceContext? deviceContext,
  })  : _transportOverride = transport,
        _queueOverride = queue,
        _identityOverride = identityStore,
        _deviceContextOverride = deviceContext;

  /// Shared instance.
  static final OpenpanelAnalytics instance = OpenpanelAnalytics();

  final TrackTransport? _transportOverride;
  final EventQueue? _queueOverride;
  final IdentityStore? _identityOverride;
  final DeviceContext? _deviceContextOverride;

  OpenpanelConfig? _config;
  TrackTransport? _transport;
  EventQueue? _queue;
  IdentityStore? _identity;
  DeviceContext? _deviceContext;

  final Map<String, dynamic> _globalProperties = <String, dynamic>{};
  final Random _random = Random();
  List<String>? _groups;

  bool _initialized = false;
  bool _flushing = false;
  bool _fatalPaused = false;
  bool _disposed = false;

  Timer? _flushTimer;
  Timer? _retryTimer;

  /// `true` once [init] has completed.
  bool get isInitialized => _initialized;

  /// Currently identified profile id, if any.
  String? get profileId => _identity?.profileId;

  /// Best effort device identifier resolved from the server.
  String? get deviceId => _identity?.deviceId;

  /// Best effort session identifier resolved from the server.
  String? get sessionId => _identity?.sessionId;

  /// Number of events waiting to be sent.
  Future<int> pendingEventCount() async {
    final length = await _queue?.length();
    return length ?? 0;
  }

  /// Initialises the client.
  ///
  /// Events are never sent before the client is initialised.
  Future<void> init({required OpenpanelConfig config}) async {
    if (_initialized) return;
    _config = config;
    _deviceContext = _deviceContextOverride ?? DefaultDeviceContext();

    final prefs = await SharedPreferences.getInstance();
    _identity = _identityOverride ?? IdentityStore(prefs);
    await _identity!.load();

    _queue = _queueOverride ??
        SharedPreferencesEventQueue(
          prefs: prefs,
          maxQueueSize: config.maxQueueSize,
          maxEventBytes: config.maxEventBytes,
          onError: config.onError,
        );
    await _queue!.load();

    if (_transportOverride != null) {
      _transport = _transportOverride;
    } else {
      final userAgent = await _deviceContext!.buildUserAgent();
      _transport = DioTrackTransport(config: config, userAgent: userAgent);
    }

    if (config.collectDeviceInfo) {
      addGlobalProperties(await _deviceContext!.collectProperties());
    }

    _initialized = true;
    _fatalPaused = false;
    _disposed = false;

    if (config.flushInterval > Duration.zero) {
      _flushTimer = Timer.periodic(
        config.flushInterval,
        (_) => unawaited(flush()),
      );
    }

    unawaited(_resolveDeviceId());
    unawaited(flush());
  }

  /// Tracks a named event.
  ///
  /// [properties], [profileId] and [groups] override the client defaults for this event only.
  Future<void> track(
    String name, {
    Map<String, dynamic> properties = const <String, dynamic>{},
    String? profileId,
    List<String>? groups,
    DateTime? timestamp,
  }) async {
    final merged = <String, dynamic>{..._globalProperties, ...properties};
    if (timestamp != null) {
      merged[kTimestampProperty] = timestamp.toUtc().toIso8601String();
    }
    final effectiveProfileId = profileId ?? _identity?.profileId;
    final effectiveGroups = groups ?? _groups;
    final payload = <String, dynamic>{
      'name': name,
      'properties': merged,
      if (effectiveProfileId != null) 'profileId': effectiveProfileId,
      if (effectiveGroups != null && effectiveGroups.isNotEmpty)
        'groups': List<String>.from(effectiveGroups),
    };
    await _enqueue('track', payload);
  }

  /// Creates or updates a profile and marks it as the current profile.
  ///
  /// Unlike [alias], calling [identify] also changes the profile id attached to subsequent events.
  Future<void> identify({
    required String profileId,
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
    Map<String, dynamic> properties = const <String, dynamic>{},
  }) async {
    final payload = <String, dynamic>{
      'profileId': profileId,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (avatar != null) 'avatar': avatar,
      'properties': <String, dynamic>{..._globalProperties, ...properties},
    };
    await setProfileId(profileId);
    await _enqueue('identify', payload);
  }

  /// Increments a numeric profile property by [value] (defaults to 1).
  Future<void> increment({
    String? profileId,
    required String property,
    int value = 1,
  }) async {
    final id = profileId ?? _identity?.profileId;
    if (id == null) return;
    await _enqueue('increment', <String, dynamic>{
      'profileId': id,
      'property': property,
      'value': value,
    });
  }

  /// Decrements a numeric profile property by [value] (defaults to 1).
  Future<void> decrement({
    String? profileId,
    required String property,
    int value = 1,
  }) async {
    final id = profileId ?? _identity?.profileId;
    if (id == null) return;
    await _enqueue('decrement', <String, dynamic>{
      'profileId': id,
      'property': property,
      'value': value,
    });
  }

  /// Creates or updates a group.
  Future<void> upsertGroup({
    required String id,
    required String type,
    required String name,
    Map<String, dynamic> properties = const <String, dynamic>{},
  }) async {
    await _enqueue('group', <String, dynamic>{
      'id': id,
      'type': type,
      'name': name,
      'properties': properties,
    });
  }

  /// Links the current (or given) profile to [groupIds].
  Future<void> assignGroups(
    List<String> groupIds, {
    String? profileId,
  }) async {
    final id = profileId ?? _identity?.profileId;
    if (id == null) return;
    await _enqueue('assign_group', <String, dynamic>{
      'groupIds': List<String>.from(groupIds),
      'profileId': id,
    });
  }

  /// Sets the groups attached to subsequent [track] calls.
  void setGroups(List<String> groupIds) {
    _groups = List<String>.from(groupIds);
  }

  /// Registers an alias for the current (or given) profile without changing
  /// which profile is attached to future events.
  Future<void> alias({
    required String alias,
    String? profileId,
  }) async {
    final id = profileId ?? _identity?.profileId;
    if (id == null) return;
    await _enqueue('alias', <String, dynamic>{
      'profileId': id,
      'alias': alias,
    });
  }

  /// Replaces the global properties attached to every event.
  void setGlobalProperties(Map<String, dynamic> properties) {
    _globalProperties
      ..clear()
      ..addAll(properties);
  }

  /// Merges [properties] into the global properties attached to every event.
  void addGlobalProperties(Map<String, dynamic> properties) {
    _globalProperties.addAll(properties);
  }

  /// Sets the profile id attached to subsequent events. Does not send
  /// anything to the API; use [identify] to send the profile to the server.
  Future<void> setProfileId(String? profileId) async {
    await _identity?.setProfileId(profileId);
  }

  /// Toggles event collection for this installation. Events enqueued while
  /// disabled stay queued and are sent once collection is re-enabled.
  Future<void> setCollectionEnabled(bool enabled) async {
    await _identity?.setCollectionEnabled(enabled);
    if (enabled && _initialized) {
      unawaited(flush());
    }
  }

  /// Sends every queued event now.
  Future<void> flush() async {
    if (_disposed || !_initialized || _flushing || _fatalPaused) return;
    if (_config!.disabled) return;
    _flushing = true;
    try {
      while (!_fatalPaused && (_identity?.collectionEnabled ?? false)) {
        final request = await _queue!.peek();
        if (request == null) break;
        final result = await _transport!.send(request);
        switch (result) {
          case TransportSuccess():
            await _queue!.remove(request.id);
          case TransportInvalid(:final statusCode, :final message):
            _report(
              OpenpanelError(
                kind: OpenpanelErrorKind.invalidEvent,
                message: 'Event "$request" rejected permanently '
                    '(HTTP $statusCode): $message',
                statusCode: statusCode,
              ),
            );
            await _queue!.remove(request.id);
          case TransportFatal(:final statusCode, :final message):
            _report(
              OpenpanelError(
                kind: OpenpanelErrorKind.configuration,
                message: message,
                statusCode: statusCode,
              ),
            );
            _fatalPaused = true;
          case TransportRetryable(
              :final message,
              :final statusCode,
              :final retryAfter,
            ):
            final attempts = request.attempts + 1;
            if (attempts >= _config!.maxAttempts) {
              _report(
                OpenpanelError(
                  kind: OpenpanelErrorKind.transport,
                  message: 'Event "$request" dropped after $attempts attempts: '
                      '$message',
                  statusCode: statusCode,
                ),
              );
              await _queue!.remove(request.id);
              continue;
            }
            await _queue!.update(request.copyWith(attempts: attempts));
            _scheduleRetry(retryAfter ?? _backoff(attempts));
            return;
        }
      }
    } catch (error) {
      _report(
        OpenpanelError(
          kind: OpenpanelErrorKind.transport,
          message: 'Flush failed',
          cause: error,
        ),
      );
    } finally {
      _flushing = false;
    }
  }

  /// Fully resets the installation:
  ///
  /// * clears every pending event in the queue,
  /// * clears the persisted identity (profile id, device id, session id),
  /// * clears the global properties and remembered groups,
  /// * unpauses the client in case a fatal authentication error had stopped
  ///   the flush loop.
  ///
  /// Use [clearQueue] when you only want to discard pending events.
  Future<void> clear() async {
    await _queue?.clear();
    await _identity?.clear();
    _globalProperties.clear();
    _groups = null;
    _fatalPaused = false;
  }

  /// Discards every event currently waiting to be sent.
  Future<void> clearQueue() async {
    await _queue?.clear();
    _fatalPaused = false;
  }

  /// Re-enables the flush loop after a fatal authentication error.
  void resume() {
    _fatalPaused = false;
    unawaited(flush());
  }

  /// Cancels timers and releases the underlying transport. The instance can
  /// not be used afterwards.
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _retryTimer?.cancel();
    _transport?.close();
  }

  Future<void> _enqueue(String type, Map<String, dynamic> payload) async {
    if (_disposed || !_initialized) return;
    if (_config!.disabled) return;
    if (!(_identity?.collectionEnabled ?? false)) return;
    final request = TrackRequest(
      id: const Uuid().v4(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await _queue!.enqueue(request);
    if (_config!.autoFlush) {
      unawaited(flush());
    }
  }

  Future<void> _resolveDeviceId() async {
    if (!(_config?.resolveDeviceId ?? false)) return;
    try {
      final identity = await _transport!.fetchDeviceId();
      if (identity != null) {
        await _identity!.setDeviceIdentity(
          deviceId: identity.deviceId,
          sessionId: identity.sessionId,
        );
      }
    } catch (_) {
      // the response schema is not documented? any failure is deliberately ignored.
    }
  }

  Duration _backoff(int attempts) {
    final base = _config!.retryBaseDelay.inMilliseconds;
    final max = _config!.retryMaxDelay.inMilliseconds;
    final exponent = (attempts - 1).clamp(0, 20);
    final ms = min(max, base * (1 << exponent));
    final jittered = (ms * (0.5 + _random.nextDouble() * 0.5)).round();
    return Duration(milliseconds: jittered);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(flush()));
  }

  void _report(OpenpanelError error) {
    _config?.onError?.call(error);
    if (_config?.verbose ?? false) {
      // ignore: avoid_print
      print('[openpanel_dart] $error');
    }
  }
}
