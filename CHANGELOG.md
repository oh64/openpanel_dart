# Changelog

## 0.1.5

- Headers verifications for the web version

## 0.1.4

- Dependencies reduced from four to one: `dio` is replaced by `package:http`,
  `uuid` by a local UUID v4 generator (`Random.secure()`), `package:web` by
  direct `dart:js_interop` bindings to `localStorage`, and `package:meta`
  annotations are dropped.

## 0.1.3

- Just a description change to follow Dart file conventions

## 0.1.2

- Split the SDK into a **pure Dart** core (`openpanel_dart`) and a Flutter
  integration package (`openpanel_dart_flutter`).
- Storage is now pluggable through a `KeyValueStore` interface. The core
  defaults to a JSON file on `dart:io` platforms and to `localStorage` on the
  web.
- Validate `OpenpanelConfig` in `init()` and fail fast with an explicit `ArgumentError`.
- Add a global `maxQueueBytes` budget so the persisted queue stays below a configurable size, in addition to the per event limit.
- Parse the standard RFC 7231 `HTTP-date` form of `Retry-After`.
- Isolate the SDK from exceptions thrown by a user `onError` callback.

## 0.1.1

- Add a cross-platform example app (`example/`) that runs on iOS, Android, Web, Windows, macOS and Linux.
- Surface the server-provided error message on rejected requests: 4xx/5xx errors now include the `message` / `error` / `detail` body instead of a generic text, which makes misconfigurations easier to diagnose.

## 0.1.0

- Initial implementation.
