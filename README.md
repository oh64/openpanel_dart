# openpanel_dart

**Dart** analytics client for [OpenPanel](https://openpanel.dev).

Track events, identify users and manage groups through the HTTP API. This package is **pure Dart with no Flutter dependency**, so it runs on plain Dart (CLI, server, web) *and* inside Flutter. It supports cloud and **self-hosted** OpenPanel instances.

## There is also a Flutter package

If you are building a Flutter app, use the companion package
**[`openpanel_dart_flutter`](https://pub.dev/packages/openpanel_dart_flutter)**
instead. It re-exports everything from this package and adds the Flutter
specific pieces:

- automatic `screen_view` tracking (`OpenpanelRouteObserver`),
- install/deeplink referrer and app lifecycle observers,
- `shared_preferences` storage and `device_info_plus` metadata.

```dart
import 'package:openpanel_dart_flutter/openpanel_dart_flutter.dart';
```

See the [Flutter README](openpanel_dart_flutter/README.md) for the Flutter
getting started. The rest of this document describes the Dart core, which the Flutter package builds upon.

## Getting started

```dart
import 'package:openpanel_dart/openpanel_dart.dart';

final analytics = OpenpanelAnalytics.instance;

Future<void> main() async {
  await analytics.init(
    OpenpanelConfig(
      clientId: 'YOUR_CLIENT_ID',
      // Optional, only required for server-side events. 
      // Anything embedded in a shipped client can be extracted!
      clientSecret: null,
    ),
  );

  analytics.track('app_open');
}
```

Storage defaults to a JSON file under `$HOME/.openpanel_dart` on `dart:io`
platforms and to `localStorage` on the web. Inject your own `KeyValueStore`
through `init(keyValueStore: ...)` to change it.

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

`identify` also sets the profile id used by subsequent events. Use `analytics.alias(alias: 'other-id')` to link identifiers without changing the current profile, and `analytics.setProfileId('user_123')` to only switch which profile future events are attributed to.

## Configuration

See `OpenpanelConfig` for the full list of options, including:

- `flushInterval` -> how often the queue is flushed (default 15 s).
- `maxQueueSize` / `maxEventBytes` / `maxQueueBytes` -> queue count, per event size and total queue size limits.
- `maxAttempts`, `retryBaseDelay`, `retryMaxDelay` -> retry policy.
- `autoFlush` -> flush immediately after each event (default `true`).
- `disabled`, `verbose`, `onError` -> runtime switches.

`init()` validates the configuration and throws an `ArgumentError` for an empty client id, an invalid API URL, non positive limits or negative retry delays.

## Storage & durability

Events are queued before they are sent, so a flush interrupted by the OS is
replayed on the next launch.

> The default queue serializes the whole queue as a single JSON string. Awaiting the write is not a guarantee that the data has physically reached the disk, and on the web `localStorage` is size limited. 
> Treat the queue as best effort: an abrupt process kill can lose the events queued since the last successful write. Implement `KeyValueStore` (file or SQLite backed) when stronger guarantees are required.

## Clearing data

```dart
await analytics.clear();      // queue + identity + global properties
await analytics.clearQueue(); // only pending events
```

## Development

This repository is a single [pub workspace](https://dart.dev/tools/pub/workspaces),
so all packages share one resolution:

- `openpanel_dart` (this package) the pure Dart core.
- `example/` the pure Dart example for the core.
- `openpanel_dart_flutter` the Flutter integration.
- `openpanel_dart_flutter/example/` the Flutter example.

Resolve once from the repository root, then run the checks from each package.
The Flutter SDK is required to resolve the workspace because it contains the
Flutter package.

```sh
# Resolve the whole workspace (needs the Flutter SDK)
dart pub get

# Core (pure Dart)
dart analyze && dart test

# Core example (pure Dart)
cd example && dart analyze && dart test

# Flutter integration and its example
cd openpanel_dart_flutter && flutter analyze && flutter test
cd example && flutter analyze && flutter test
```

Third-party dependencies are distributed under their own licenses (listed in `LICENSE`).
