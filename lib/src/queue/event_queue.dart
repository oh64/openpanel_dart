import 'dart:async';
import 'dart:convert';

import '../constants.dart';
import '../errors.dart';
import '../models/track_request.dart';
import '../storage/key_value_store.dart';

/// Storage backend for queued events, ordered oldest first.
///
/// The default implementation is backed by a [KeyValueStore]. It can be swapped
/// for a custom implementation by implementing this interface and passing it to
/// `OpenpanelAnalytics`.
///
/// The default [KeyValueEventQueue] serializes the whole queue
/// as a single JSON string. Awaiting the write is not a guarantee that the data
/// has reached the disk (the value may still sit in an OS or platform channel
/// buffer), and on the web the backing `localStorage` is size limited. Treat
/// the queue as best effort: an abrupt process kill can lose the events queued
/// since the last successful write.
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

/// [EventQueue] that never persists anything. Handy for tests.
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

/// Default queue backed by a [KeyValueStore].
final class KeyValueEventQueue implements EventQueue {
  KeyValueEventQueue({
    required KeyValueStore store,
    required this.maxQueueSize,
    required this.maxEventBytes,
    required this.maxQueueBytes,
    this.onError,
  }) : _store = store;

  static final String _key = '${kStoragePrefix}queue';

  final KeyValueStore _store;
  final _Mutex _mutex = _Mutex();
  List<TrackRequest> _events = <TrackRequest>[];
  bool _loaded = false;
  int _totalBytes = 0;

  /// Maximum number of events kept before the oldest are dropped.
  final int maxQueueSize;

  /// Maximum serialized size of a single event in bytes.
  final int maxEventBytes;

  /// Maximum serialized size of the whole queue in bytes.
  final int maxQueueBytes;

  /// Reports events dropped by the queue.
  final OpenpanelErrorHandler? onError;

  @override
  Future<void> load() => _mutex.run(_loadUnsafe);

  Future<void> _loadUnsafe() async {
    if (_loaded) return;
    final raw = await _store.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _events = decoded
            .map((e) =>
                TrackRequest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _totalBytes = _events.fold(0, (sum, e) => sum + _sizeOf(e));
      } catch (error) {
        // The queue payload is corrupt; starting clean is safer than failing.
        _events = <TrackRequest>[];
        _totalBytes = 0;
        _report(OpenpanelError(
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
        final size = _sizeOf(request);
        if (size > maxEventBytes) {
          _report(OpenpanelError(
            kind: OpenpanelErrorKind.invalidEvent,
            message: 'Dropping event "$request": serialized size '
                '($size bytes) exceeds maxEventBytes ($maxEventBytes).',
          ));
          return;
        }
        _events.add(request);
        _totalBytes += size;
        while (_events.length > maxQueueSize || _totalBytes > maxQueueBytes) {
          final dropped = _events.removeAt(0);
          _totalBytes -= _sizeOf(dropped);
          _report(OpenpanelError(
            kind: OpenpanelErrorKind.invalidEvent,
            message: 'Event queue is full; dropped oldest event "$dropped".',
          ));
        }
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
        final removed = <TrackRequest>[];
        _events.removeWhere((e) {
          if (e.id == id) {
            removed.add(e);
            return true;
          }
          return false;
        });
        if (removed.isEmpty) return;
        for (final event in removed) {
          _totalBytes -= _sizeOf(event);
        }
        await _persistUnsafe();
      });

  @override
  Future<void> update(TrackRequest request) => _mutex.run(() async {
        await _loadUnsafe();
        final index = _events.indexWhere((e) => e.id == request.id);
        if (index != -1) {
          _totalBytes -= _sizeOf(_events[index]);
          _events[index] = request;
          _totalBytes += _sizeOf(request);
          await _persistUnsafe();
        }
      });

  @override
  Future<void> clear() => _mutex.run(() async {
        _events = <TrackRequest>[];
        _totalBytes = 0;
        _loaded = true;
        await _persistUnsafe();
      });

  int _sizeOf(TrackRequest request) =>
      utf8.encode(jsonEncode(request.toBody())).length;

  void _report(OpenpanelError error) {
    try {
      onError?.call(error);
    } catch (_) {
      // A misbehaving error handler must not corrupt the queue mutex.
    }
  }

  Future<void> _persistUnsafe() async {
    final encoded = jsonEncode(
      _events.map((e) => e.toJson()).toList(),
    );
    await _store.setString(_key, encoded);
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
