import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] backed by `shared_preferences`.
///
/// This is the storage the Flutter integration uses by default. Pass it to
/// `OpenpanelAnalytics.init(keyValueStore: ...)`.
final class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
