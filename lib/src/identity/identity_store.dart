import 'dart:convert';

import '../constants.dart';
import '../storage/key_value_store.dart';

/// Persists identity state across launches:
///
/// * [profileId] is the identifier attached to events once the user has been
///   identified. It is stable and should come from the host application's own
///   database.
/// * [deviceId] / [sessionId] are best effort identifiers resolved from the
///   server and are informational only.
/// * [collectionEnabled] mirrors the runtime kill switch.
class IdentityStore {
  IdentityStore(this._store);

  static final String _key = '${kStoragePrefix}identity';

  final KeyValueStore _store;

  String? profileId;
  String? deviceId;
  String? sessionId;
  bool collectionEnabled = true;

  Future<void> load() async {
    final raw = await _store.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      profileId = map['profileId'] as String?;
      deviceId = map['deviceId'] as String?;
      sessionId = map['sessionId'] as String?;
      collectionEnabled = map['collectionEnabled'] as bool? ?? true;
    } catch (_) {
      // Corrupt state is discarded; defaults are used.
    }
  }

  Future<void> setProfileId(String? id) async {
    profileId = id;
    await _save();
  }

  Future<void> setDeviceIdentity({String? deviceId, String? sessionId}) async {
    this.deviceId = deviceId ?? this.deviceId;
    this.sessionId = sessionId ?? this.sessionId;
    await _save();
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
    await _save();
  }

  /// Resets every identity field AND the collection kill switch. The event
  /// queue is intentionally left untouched.
  Future<void> clear() async {
    profileId = null;
    deviceId = null;
    sessionId = null;
    collectionEnabled = true;
    await _save();
  }

  Future<void> _save() {
    return _store.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'profileId': profileId,
        'deviceId': deviceId,
        'sessionId': sessionId,
        'collectionEnabled': collectionEnabled,
      }),
    );
  }
}
