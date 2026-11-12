import 'dart:js_interop';

import 'key_value_store.dart';

/// Web default store backed by `window.localStorage`.
KeyValueStore createDefaultKeyValueStore() => WebKeyValueStore();

@JS('localStorage')
external _WebStorage get _localStorage;

/// Minimal binding over [`Storage`](https://developer.mozilla.org/en-US/docs/Web/API/Storage).
extension type _WebStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

final class WebKeyValueStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => _localStorage.getItem(key);

  @override
  Future<void> setString(String key, String value) async {
    _localStorage.setItem(key, value);
  }

  @override
  Future<void> remove(String key) async {
    _localStorage.removeItem(key);
  }
}
