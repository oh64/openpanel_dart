/// Default OpenPanel API base URL.
const String kDefaultApiUrl = 'https://api.openpanel.dev';

/// Endpoint used to ingest tracking events.
const String kTrackPath = '/track';

/// Endpoint used to resolve a stable device/session identifier.
const String kDeviceIdPath = '/track/device-id';

/// Identifier sent in the `openpanel-sdk-name` header.
const String kSdkName = 'openpanel-dart';

/// Version sent in the `openpanel-sdk-version` header.
const String kSdkVersion = '0.1.2';

/// Header carrying the client id.
const String kClientIdHeader = 'openpanel-client-id';

/// Header carrying the client secret.
const String kClientSecretHeader = 'openpanel-client-secret';

/// Header carrying the SDK name.
const String kSdkNameHeader = 'openpanel-sdk-name';

/// Header carrying the SDK version.
const String kSdkVersionHeader = 'openpanel-sdk-version';

/// Property key used to attach a caller supplied timestamp to an event.
const String kTimestampProperty = '__timestamp';

/// Property key used by the route observer for the current screen path.
const String kPathProperty = '__path';

/// Property key used by the referrer observer.
const String kReferrerProperty = '__referrer';

/// Storage key prefix used by the persistent queue and identity store.
const String kStoragePrefix = 'openpanel_dart.';
