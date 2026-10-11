import 'package:openpanel_dart/openpanel_dart.dart';

/// Small scripted demo used by the example binary and its test.
///
/// It exercises the main calls: [OpenpanelAnalytics.identify],
/// [OpenpanelAnalytics.track] and [OpenpanelAnalytics.increment].
Future<void> runDemo(OpenpanelAnalytics analytics) async {
  await analytics.identify(
    profileId: 'user_123',
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@forsaken.com',
    properties: const <String, dynamic>{'plan': 'free'},
  );
  await analytics.track(
    'app_open',
    properties: const <String, dynamic>{'source': 'dart cli'},
  );
  await analytics.increment(property: 'runs');
  await analytics.flush();
}
