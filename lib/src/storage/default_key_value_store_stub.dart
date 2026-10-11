import 'key_value_store.dart';

/// Fallback default store for platforms without a built in persistence layer.
KeyValueStore createDefaultKeyValueStore() => InMemoryKeyValueStore();
