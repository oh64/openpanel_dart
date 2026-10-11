# openpanel_dart_flutter

**Flutter** integration for [OpenPanel](https://openpanel.dev). Use this package in Flutter apps.

For plain Dart, CLI, server, web, use the core package
**[`openpanel_dart`](https://pub.dev/packages/openpanel_dart)** instead (see its [README](../README.md)).

This package re-exports the whole `openpanel_dart` API and adds the Flutter
specific pieces on top of it, so a Flutter app only needs a single import:

- `OpenpanelRouteObserver` -> automatic `screen_view` tracking for named routes.
- `OpenpanelReferrerObserver` -> install/deeplink referrer on Android & iOS.
- `OpenpanelLifecycleObserver` -> flush the queue when the app is backgrounded.
- `SharedPreferencesStore` -> `shared_preferences` backed `KeyValueStore`.
- `FlutterDeviceContext` -> app/device metadata from `device_info_plus` and
  `package_info_plus`.
- `initOpenpanelFlutter` -> one call that wires the two above.

## Getting started

```dart
import 'package:openpanel_dart_flutter/openpanel_dart_flutter.dart';

final analytics = OpenpanelAnalytics.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance
    ..addObserver(OpenpanelReferrerObserver(analytics: analytics))
    ..addObserver(OpenpanelLifecycleObserver(analytics: analytics));

  await initOpenpanelFlutter(
    analytics,
    config: const OpenpanelConfig(
      clientId: 'YOUR_CLIENT_ID',
      // Self-hosting? Point apiUrl at your own instance:
      // apiUrl: 'https://analytics.example.com',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Tracks every route change as a `screen_view` event.
      navigatorObservers: [OpenpanelRouteObserver()],
      home: const HomeScreen(),
    );
  }
}
```

## Manual storage / metadata

If you do not want `initOpenpanelFlutter`, pass the Flutter implementations
yourself:

```dart
final prefs = await SharedPreferences.getInstance();

await analytics.init(
  config: const OpenpanelConfig(clientId: 'YOUR_CLIENT_ID'),
  keyValueStore: SharedPreferencesStore(prefs),
  deviceContext: FlutterDeviceContext(),
);
```

`Origin` header: browsers control the `Origin` header, so on the web
configure CORS on the server instead of passing it through `OpenpanelConfig`.

## Running the example

```sh
cd example
flutter pub get
flutter run
```

Set a real `clientId` (and `apiUrl` for a self-hosted instance) in
`example/lib/main.dart` to deliver events.

## License

MIT, see `LICENSE`. The core package and third-party dependencies are
distributed under their own licenses.
