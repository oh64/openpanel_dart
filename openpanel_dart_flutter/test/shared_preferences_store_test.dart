import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart_flutter/openpanel_dart_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrackRequest _request(String id) => TrackRequest(
      id: id,
      type: 'track',
      payload: <String, dynamic>{
        'name': 'x',
        'properties': const <String, dynamic>{},
      },
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SharedPreferencesStore persists values', () async {
    final store = SharedPreferencesStore(await SharedPreferences.getInstance());
    expect(await store.getString('missing'), isNull);
    await store.setString('k', 'v');
    expect(await store.getString('k'), 'v');
    await store.remove('k');
    expect(await store.getString('k'), isNull);
  });

  test('KeyValueEventQueue persists across instances via shared_preferences',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = KeyValueEventQueue(
      store: SharedPreferencesStore(prefs),
      maxQueueSize: 100,
      maxEventBytes: 65536,
      maxQueueBytes: 1024 * 1024,
    );
    await first.load();
    await first.enqueue(_request('a'));

    final second = KeyValueEventQueue(
      store: SharedPreferencesStore(await SharedPreferences.getInstance()),
      maxQueueSize: 100,
      maxEventBytes: 65536,
      maxQueueBytes: 1024 * 1024,
    );
    await second.load();
    expect(await second.length(), 1);
    expect((await second.peek())!.id, 'a');
  });
}
