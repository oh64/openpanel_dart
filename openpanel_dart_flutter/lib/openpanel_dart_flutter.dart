/// Flutter integration for `openpanel_dart`.
///
/// Adds automatic screen tracking, referrer/lifecycle observers and
/// plugin-backed storage & device metadata on top of the pure Dart core, which this library re-exports.
///
/// ```dart
/// import 'package:openpanel_dart_flutter/openpanel_dart_flutter.dart';
///
/// final analytics = OpenpanelAnalytics.instance;
/// await initOpenpanelFlutter(
///   analytics,
///   config: OpenpanelConfig(clientId: 'YOUR_CLIENT_ID'),
/// );
/// ```
library;

export 'package:openpanel_dart/openpanel_dart.dart';

export 'src/device_context.dart';
export 'src/initialize.dart';
export 'src/observers/lifecycle_observer.dart';
export 'src/observers/referrer_observer.dart';
export 'src/observers/route_observer.dart';
export 'src/observers/typedefs.dart';
export 'src/storage/shared_preferences_store.dart';
