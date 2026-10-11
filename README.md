# openpanel_dart

Dart/Flutter analytics client for [OpenPanel](https://openpanel.dev)

It supports cloud and **self-hosted** OpenPanel instances.

## Getting started

```dart
import 'package:openpanel_dart/openpanel_dart.dart';

final analytics = OpenpanelAnalytics.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await analytics.init(
    OpenpanelConfig(
      clientId: 'YOUR_CLIENT_ID',
      // Optional, only required for server-side events. Never a security
      // boundary in a mobile app: 
      // anything embedded in the binary can be extracted!
      clientSecret: null,
    ),
  );
  runApp(const MyApp());
}

void someAction() {
  analytics.track('button_clicked', properties: {'label': 'signup'});
}
```

## Self-hosting

Point `apiUrl` at your own instance. Add `headers` as needed (for example an
`Origin` header to satisfy a proxy in front of your OpenPanel).

```dart
await analytics.init(
  OpenpanelConfig(
    apiUrl: 'https://analytics.example.com',
    clientId: 'YOUR_CLIENT_ID',
    headers: {'Origin': 'https://app.example.com'},
  ),
);
```

## Users

```dart
await analytics.identify(
  profileId: 'user_123',
  firstName: 'Jane',
  lastName: 'Doe',
  email: 'jane@example.com',
  avatar: 'https://example.com/avatar.png',
  properties: {'plan': 'premium'},
);
```

`identify` also sets the profile id used by subsequent events. Use
`analytics.alias(alias: 'other-id')` to link identifiers without changing the
current profile, and `analytics.setProfileId('user_123')` to only switch which
profile future events are attributed to.

## Automatic tracking

```dart
// Screen views (add to navigatorObservers).
navigatorObservers: [OpenpanelRouteObserver()],

// Install / deeplink referrer (Android & iOS).
WidgetsBinding.instance.addObserver(OpenpanelReferrerObserver());

// Flush the queue when the app is paused / resumed.
WidgetsBinding.instance.addObserver(OpenpanelLifecycleObserver());
```

the queue is persisted first, so a flush interrupted by the OS is replayed on the next launch.

## Configuration

See `OpenpanelConfig` for the full list of options, including:

- `flushInterval` -> how often the queue is flushed (default 15 s).
- `maxQueueSize` / `maxEventBytes` -> queue and size limits.
- `maxAttempts`, `retryBaseDelay`, `retryMaxDelay` -> retry policy.
- `autoFlush` -> flush immediately after each event (default `true`).
- `disabled`, `verbose`, `onError` -> runtime switches.

## Clearing data

```dart
await analytics.clear();      // queue + identity + global properties
await analytics.clearQueue(); // only pending events
```

Third-party dependencies are distributed under their own licenses (listed in `LICENSE`).
