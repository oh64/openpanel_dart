import 'dart:io';

import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:openpanel_dart_example/demo.dart';

/// Pure Dart example for `openpanel_dart`.
///
/// Run it with a real client id (and, for a self-hosted instance, your API URL):
///
/// ```sh
/// OPENPANEL_CLIENT_ID=... OPENPANEL_API_URL=https://analytics.example.com \
///   dart run bin/main.dart
/// ```
///
/// Storage defaults to a JSON file under `$HOME/.openpanel_dart`.
Future<void> main() async {
  final clientId =
      Platform.environment['OPENPANEL_CLIENT_ID'] ?? 'YOUR_CLIENT_ID';
  final apiUrl = Platform.environment['OPENPANEL_API_URL'] ?? kDefaultApiUrl;

  final analytics = OpenpanelAnalytics.instance;
  await analytics.init(
    config: OpenpanelConfig(
      apiUrl: apiUrl,
      clientId: clientId,
      verbose: true,
    ),
  );

  try {
    await runDemo(analytics);
    stdout.writeln(
      'Demo done. Pending events: ${await analytics.pendingEventCount()}',
    );
  } finally {
    analytics.dispose();
  }
}
