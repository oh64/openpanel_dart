/// Minimal asynchronous key/value store used by the persistent event queue and the identity store.
///
/// The core package ships an in-memory implementation and a platform default
/// ([createDefaultKeyValueStore]) backed by a file on `dart:io` platforms and by
/// `localStorage` on the web. Flutter applications normally inject a
/// `shared_preferences` backed implementation from `openpanel_dart_flutter`.
abstract interface class KeyValueStore {
  /// Reads the value stored under [key], or `null` when absent.
  Future<String?> getString(String key);

  /// Stores [value] under [key].
  Future<void> setString(String key, String value);

  /// Removes the value stored under [key].
  Future<void> remove(String key);
}

/// In-memory [KeyValueStore].
///
/// nothing survive a restart.
final class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial])
      : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
