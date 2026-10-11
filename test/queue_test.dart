import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:test/test.dart';

TrackRequest _request(String id, {int payloadBytes = 8}) {
  return TrackRequest(
    id: id,
    type: 'track',
    payload: <String, dynamic>{
      'name': 'x' * payloadBytes,
      'properties': const <String, dynamic>{},
    },
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

KeyValueEventQueue _queue(
  KeyValueStore store, {
  int maxQueueSize = 100,
  int maxEventBytes = 65536,
  int maxQueueBytes = 1024 * 1024,
  void Function(OpenpanelError error)? onError,
}) {
  return KeyValueEventQueue(
    store: store,
    maxQueueSize: maxQueueSize,
    maxEventBytes: maxEventBytes,
    maxQueueBytes: maxQueueBytes,
    onError: onError,
  );
}

void main() {
  group('KeyValueEventQueue', () {
    test('persists events across instances', () async {
      final store = InMemoryKeyValueStore();
      final first = _queue(store);
      await first.load();
      await first.enqueue(_request('a'));
      await first.enqueue(_request('b'));

      final second = _queue(store);
      await second.load();
      expect(await second.length(), 2);
      expect((await second.peek())!.id, 'a');
      await second.remove('a');
      expect((await second.peek())!.id, 'b');
    });

    test('keeps the queue bounded by dropping the oldest events', () async {
      final store = InMemoryKeyValueStore();
      final queue = _queue(store, maxQueueSize: 3);
      await queue.load();
      await queue.enqueue(_request('1'));
      await queue.enqueue(_request('2'));
      await queue.enqueue(_request('3'));
      await queue.enqueue(_request('4'));
      expect(await queue.length(), 3);
      expect((await queue.peek())!.id, '2');
    });

    test('drops oversized events and reports them', () async {
      final store = InMemoryKeyValueStore();
      final reported = <OpenpanelError>[];
      final queue = _queue(store, maxEventBytes: 32, onError: reported.add);
      await queue.load();
      await queue.enqueue(_request('big', payloadBytes: 100));
      expect(await queue.length(), 0);
      expect(reported.single.kind, OpenpanelErrorKind.invalidEvent);
    });

    test('keeps the queue bounded by the global byte budget', () async {
      final store = InMemoryKeyValueStore();
      final reported = <OpenpanelError>[];
      final queue = _queue(store,
          maxQueueSize: 1000, maxQueueBytes: 200, onError: reported.add);
      await queue.load();
      for (var i = 0; i < 5; i++) {
        await queue.enqueue(_request('e$i', payloadBytes: 16));
      }
      expect(await queue.length(), lessThan(5));
      expect(reported, isNotEmpty);

      final remaining = <String>[];
      TrackRequest? next = await queue.peek();
      while (next != null) {
        remaining.add(next.id);
        await queue.remove(next.id);
        next = await queue.peek();
      }
      expect(remaining.last, 'e4');
      expect(remaining, isNot(contains('e0')));
    });

    test('serializes concurrent access without losing events', () async {
      final store = InMemoryKeyValueStore();
      final queue = _queue(store, maxQueueSize: 1000);
      await queue.load();
      final futures = <Future<void>>[
        for (var i = 0; i < 50; i++) queue.enqueue(_request('e$i')),
      ];
      await Future.wait(futures);
      expect(await queue.length(), 50);
    });
  });

  group('InMemoryEventQueue', () {
    test('supports read/remove/update', () async {
      final queue = InMemoryEventQueue();
      await queue.enqueue(_request('a'));
      await queue.enqueue(_request('b'));
      expect((await queue.peek())!.id, 'a');
      await queue.update((await queue.peek())!.copyWith(attempts: 3));
      expect((await queue.peek())!.attempts, 3);
      await queue.remove('a');
      expect((await queue.peek())!.id, 'b');
      await queue.clear();
      expect(await queue.length(), 0);
    });
  });
}
