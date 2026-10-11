import 'default_key_value_store_stub.dart'
    if (dart.library.io) 'default_key_value_store_io.dart'
    if (dart.library.js_interop) 'default_key_value_store_web.dart' as impl;

import 'key_value_store.dart';

/// Returns the platform default [KeyValueStore].
///
/// * `dart:io` platforms (CLI, desktop, mobile): a JSON file under `$OPENPANEL_HOME/.openpanel_dart` (falling back to `$HOME`, then to the system temporary directory).
/// * Web: `window.localStorage`.
/// * Any other platform: an [InMemoryKeyValueStore].
///
/// Flutter applications should inject a `shared_preferences` backed store from `openpanel_dart_flutter` instead of relying on this default.
KeyValueStore createDefaultKeyValueStore() => impl.createDefaultKeyValueStore();
