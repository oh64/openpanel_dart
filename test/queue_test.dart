import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SharedPreferencesEventQueue', () {
    test('persists events across instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = SharedPreferencesEventQueue(
        prefs: prefs,
        maxQueueSize: 100,
        maxEventBytes: 65536,
      );
      await first.load();
      await first.enqueue(_request('a'));
      await first.enqueue(_request('b'));

      final second = SharedPreferencesEventQueue(
        prefs: prefs,
        maxQueueSize: 100,
        maxEventBytes: 65536,
      );
      await second.load();
      expect(await second.length(), 2);
      expect((await second.peek())!.id, 'a');
      await second.remove('a');
      expect((await second.peek())!.id, 'b');
    });

    test('keeps the queue bounded by dropping the oldest events', () async {
      final prefs = await SharedPreferences.getInstance();
      final queue = SharedPreferencesEventQueue(
        prefs: prefs,
        maxQueueSize: 3,
        maxEventBytes: 65536,
      );
      await queue.load();
      await queue.enqueue(_request('1'));
      await queue.enqueue(_request('2'));
      await queue.enqueue(_request('3'));
      await queue.enqueue(_request('4'));
      expect(await queue.length(), 3);
      expect((await queue.peek())!.id, '2');
    });

    test('drops oversized events and reports them', () async {
      final prefs = await SharedPreferences.getInstance();
      final reported = <OpenpanelError>[];
      final queue = SharedPreferencesEventQueue(
        prefs: prefs,
        maxQueueSize: 100,
        maxEventBytes: 32,
        onError: reported.add,
      );
      await queue.load();
      await queue.enqueue(_request('big', payloadBytes: 100));
      expect(await queue.length(), 0);
      expect(reported.single.kind, OpenpanelErrorKind.invalidEvent);
    });

    test('serializes concurrent access without losing events', () async {
      final prefs = await SharedPreferences.getInstance();
      final queue = SharedPreferencesEventQueue(
        prefs: prefs,
        maxQueueSize: 1000,
        maxEventBytes: 65536,
      );
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