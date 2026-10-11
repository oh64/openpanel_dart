import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../errors.dart';
import '../models/track_request.dart';

/// Storage backend for queued events, ordered oldest first.
///
/// The default implementation is backed by `shared_preferences`. It can be
/// swapped for a file or SQLite backed implementation by implementing this
/// interface and passing it to `OpenpanelAnalytics`.
abstract interface class EventQueue {
  /// Loads any previously persisted events.
  Future<void> load();

  /// Number of events currently queued.
  Future<int> length();

  /// Appends an event. May drop the oldest events when full.
  Future<void> enqueue(TrackRequest request);

  /// Returns the oldest event without removing it, or `null` when empty.
  Future<TrackRequest?> peek();

  /// Removes the event carrying [id].
  Future<void> remove(String id);

  /// Persists changes made to [request] (for example its attempt count).
  Future<void> update(TrackRequest request);

  /// Removes every event.
  Future<void> clear();
}

final class InMemoryEventQueue implements EventQueue {
  final List<TrackRequest> _events = <TrackRequest>[];
  final _Mutex _mutex = _Mutex();

  @override
  Future<void> load() async {}

  @override
  Future<int> length() => _mutex.run(() async => _events.length);

  @override
  Future<void> enqueue(TrackRequest request) =>
      _mutex.run(() async => _events.add(request));

  @override
  Future<TrackRequest?> peek() => _mutex.run(() async {
        if (_events.isEmpty) return null;
        return _events.first;
      });

  @override
  Future<void> remove(String id) => _mutex.run(() async {
        _events.removeWhere((e) => e.id == id);
      });

  @override
  Future<void> update(TrackRequest request) => _mutex.run(() async {
        final index = _events.indexWhere((e) => e.id == request.id);
        if (index != -1) {
          _events[index] = request;
        }
      });

  @override
  Future<void> clear() => _mutex.run(() async => _events.clear());
}

/// Default queue backed by `shared_preferences`.
final class SharedPreferencesEventQueue implements EventQueue {
  SharedPreferencesEventQueue({
    required SharedPreferences prefs,
    required this.maxQueueSize,
    required this.maxEventBytes,
    this.onError,
  }) : _prefs = prefs;

  static final String _key = '${kStoragePrefix}queue';

  final SharedPreferences _prefs;
  final _Mutex _mutex = _Mutex();
  List<TrackRequest> _events = <TrackRequest>[];
  bool _loaded = false;

  /// Maximum number of events kept before the oldest are dropped.
  final int maxQueueSize;

  /// Maximum serialized size of a single event in bytes.
  final int maxEventBytes;

  /// Reports events dropped by the queue.
  final OpenpanelErrorHandler? onError;

  @override
  Future<void> load() => _mutex.run(() => _loadUnsafe());

  Future<void> _loadUnsafe() async {
    if (_loaded) return;
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _events = decoded
            .map((e) =>
                TrackRequest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (error) {
        // The queue payload is corrupt; starting clean is safer than failing.
        _events = <TrackRequest>[];
        onError?.call(OpenpanelError(
          kind: OpenpanelErrorKind.storage,
          message: 'Failed to decode the persisted queue, discarding it.',
          cause: error,
        ));
      }
    }
    _loaded = true;
  }

  @override
  Future<int> length() => _mutex.run(() async {
        await _loadUnsafe();
        return _events.length;
      });

  @override
  Future<void> enqueue(TrackRequest request) => _mutex.run(() async {
        await _loadUnsafe();
        final size = utf8.encode(jsonEncode(request.toBody())).length;
        if (size > maxEventBytes) {
          onError?.call(OpenpanelError(
            kind: OpenpanelErrorKind.invalidEvent,
            message: 'Dropping event "$request": serialized size '
                '($size bytes) exceeds maxEventBytes ($maxEventBytes).',
          ));
          return;
        }
        while (_events.length >= maxQueueSize) {
          final dropped = _events.removeAt(0);
          onError?.call(OpenpanelError(
            kind: OpenpanelErrorKind.invalidEvent,
            message: 'Event queue is full; dropped oldest event "$dropped".',
          ));
        }
        _events.add(request);
        await _persistUnsafe();
      });

  @override
  Future<TrackRequest?> peek() => _mutex.run(() async {
        await _loadUnsafe();
        if (_events.isEmpty) return null;
        return _events.first;
      });

  @override
  Future<void> remove(String id) => _mutex.run(() async {
        await _loadUnsafe();
        final before = _events.length;
        _events.removeWhere((e) => e.id == id);
        if (_events.length != before) {
          await _persistUnsafe();
        }
      });

  @override
  Future<void> update(TrackRequest request) => _mutex.run(() async {
        await _loadUnsafe();
        final index = _events.indexWhere((e) => e.id == request.id);
        if (index != -1) {
          _events[index] = request;
          await _persistUnsafe();
        }
      });

  @override
  Future<void> clear() => _mutex.run(() async {
        _events = <TrackRequest>[];
        _loaded = true;
        await _persistUnsafe();
      });

  Future<void> _persistUnsafe() async {
    final encoded = jsonEncode(
      _events.map((e) => e.toJson()).toList(),
    );
    await _prefs.setString(_key, encoded);
  }
}

/// Serializes access to shared mutable state.
final class _Mutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}
