import 'package:web/web.dart' as web;

import 'key_value_store.dart';

/// Web default store backed by `window.localStorage`.
KeyValueStore createDefaultKeyValueStore() => WebKeyValueStore();

final class WebKeyValueStore implements KeyValueStore {
  final web.Storage _storage = web.window.localStorage;

  @override
  Future<String?> getString(String key) async => _storage.getItem(key);

  @override
  Future<void> setString(String key, String value) async {
    _storage.setItem(key, value);
  }

  @override
  Future<void> remove(String key) async {
    _storage.removeItem(key);
  }
}
