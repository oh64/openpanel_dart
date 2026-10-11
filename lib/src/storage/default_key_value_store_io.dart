import 'dart:convert';
import 'dart:io';

import 'key_value_store.dart';

/// `dart:io` default store: a single JSON file under the user home directory.
KeyValueStore createDefaultKeyValueStore() => FileKeyValueStore(_defaultFile());

File _defaultFile() {
  final env = Platform.environment;
  final home = env['OPENPANEL_HOME'] ?? env['HOME'] ?? env['USERPROFILE'];
  final base =
      (home == null || home.isEmpty) ? Directory.systemTemp.path : home;
  return File('$base/.openpanel_dart/store.json');
}

/// A [KeyValueStore] persisting its values as a JSON object in a single file.
///
/// Writes use [File.writeAsString] with `flush: true`.
/// !! it does not protect against a power loss that occurs
/// between the write and the filesystem journal flush.
final class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this._file);

  final File _file;
  Future<Map<String, String>>? _pending;

  Future<Map<String, String>> _load() => _pending ??= _read();

  Future<Map<String, String>> _read() async {
    if (!await _file.exists()) return <String, String>{};
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry<String, String>('$key', '$value'),
        );
      }
    } catch (_) {
      // A corrupt file is treated as empty
    }
    return <String, String>{};
  }

  @override
  Future<String?> getString(String key) async => (await _load())[key];

  @override
  Future<void> setString(String key, String value) async {
    final values = await _load();
    values[key] = value;
    await _flush(values);
  }

  @override
  Future<void> remove(String key) async {
    final values = await _load();
    if (values.remove(key) != null) {
      await _flush(values);
    }
  }

  Future<void> _flush(Map<String, String> values) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(values), flush: true);
  }
}
