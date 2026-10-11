import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_context.dart';
import 'storage/shared_preferences_store.dart';

/// Initialises [analytics] with the Flutter defaults:
///
/// * storage backed by `shared_preferences`,
/// * device metadata from `device_info_plus` / `package_info_plus`.
///
/// ```dart
/// await initOpenpanelFlutter(
///   OpenpanelAnalytics.instance,
///   config: OpenpanelConfig(clientId: 'YOUR_CLIENT_ID'),
/// );
/// ```
Future<void> initOpenpanelFlutter(
  OpenpanelAnalytics analytics, {
  required OpenpanelConfig config,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await analytics.init(
    config: config,
    keyValueStore: SharedPreferencesStore(prefs),
    deviceContext: FlutterDeviceContext(),
  );
}
