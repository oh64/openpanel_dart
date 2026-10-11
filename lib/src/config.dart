import 'constants.dart';
import 'errors.dart';

/// Configuration for [OpenpanelAnalytics.init].
class OpenpanelConfig {
  const OpenpanelConfig({
    required this.clientId,
    this.apiUrl = kDefaultApiUrl,
    this.clientSecret,
    this.headers = const {},
    this.verbose = false,
    this.disabled = false,
    this.flushInterval = const Duration(seconds: 15),
    this.maxQueueSize = 500,
    this.maxEventBytes = 64 * 1024,
    this.maxQueueBytes = 4 * 1024 * 1024,
    this.maxAttempts = 8,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.retryMaxDelay = const Duration(minutes: 5),
    this.collectDeviceInfo = true,
    this.resolveDeviceId = true,
    this.autoFlush = true,
    this.onError,
  })  : assert(maxQueueSize > 0, 'maxQueueSize must be positive'),
        assert(maxEventBytes > 0, 'maxEventBytes must be positive'),
        assert(maxQueueBytes > 0, 'maxQueueBytes must be positive'),
        assert(maxAttempts > 0, 'maxAttempts must be positive');

  /// Base URL of the OpenPanel API.
  ///
  /// For a self-hosted instance this is your own domain, for example
  /// `https://analytics.example.com`. Do not append `/track`: the path is
  /// added automatically.
  final String apiUrl;

  /// Public client id of the project.
  final String clientId;

  /// Optional client secret.
  ///
  /// This is **not** a security boundary. Any value embedded in a Flutter
  /// application can be extracted by an attacker, so the server must apply
  /// controls suited to a public client. Server side events will not be
  /// authorised without it.
  final String? clientSecret;

  /// Additional headers sent with every request, for example an `Origin`
  /// header when talking to a self-hosted instance behind a proxy.
  final Map<String, String> headers;

  /// Enables verbose request logging through `dart:developer`.
  final bool verbose;

  /// When `true` no event is ever sent.
  final bool disabled;

  /// How often the pending queue is flushed.
  final Duration flushInterval;

  /// Maximum number of events kept in the persistent queue.
  /// When the queue is full the oldest events are dropped.
  final int maxQueueSize;

  /// Maximum serialized size of a single event. Larger events are
  /// dropped and reported as [OpenpanelErrorKind.invalidEvent].
  final int maxEventBytes;

  /// Maximum serialized size of the whole pending queue, in bytes.
  ///
  /// When adding an event would exceed this budget the oldest events are
  /// dropped until both [maxQueueSize] and [maxQueueBytes] are satisfied.
  /// Defaults to 4 MiB, which keeps a worst case queue well below the storage limits of a web browser.
  final int maxQueueBytes;

  /// Maximum number of delivery attempts for a single event before it is
  /// dropped.
  final int maxAttempts;

  /// Base delay used for exponential backoff.
  final Duration retryBaseDelay;

  /// Upper bound for the exponential backoff delay.
  final Duration retryMaxDelay;

  /// Collects app/device metadata and merges it into the global properties.
  final bool collectDeviceInfo;

  /// Resolves a stable device/session identifier from the server on init.
  ///
  /// The response of that endpoint is not part of the published schema, so the
  /// call is best effort and any failure is ignored.
  final bool resolveDeviceId;

  /// When `true` (the default), enqueuing an event immediately triggers an
  /// asynchronous flush. Set to `false` to only send through the periodic
  /// timer or explicit [OpenpanelAnalytics.flush] calls.
  final bool autoFlush;

  /// Receives non fatal errors produced by the SDK.
  final OpenpanelErrorHandler? onError;

  /// Validates the configuration and throws an [ArgumentError] describing the first problem found.
  void validate() {
    if (clientId.trim().isEmpty) {
      throw ArgumentError.value(clientId, 'clientId', 'must not be empty');
    }

    final url = apiUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(
        apiUrl,
        'apiUrl',
        'must be an absolute URL such as https://analytics.example.com',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(
        apiUrl,
        'apiUrl',
        'scheme must be http or https',
      );
    }
    if (uri.scheme == 'http' && !_isLoopbackHost(uri.host)) {
      throw ArgumentError.value(
        apiUrl,
        'apiUrl',
        'plain http is only allowed for loopback hosts, use https',
      );
    }

    if (maxQueueSize <= 0) {
      throw ArgumentError.value(
        maxQueueSize,
        'maxQueueSize',
        'must be positive',
      );
    }
    if (maxEventBytes <= 0) {
      throw ArgumentError.value(
        maxEventBytes,
        'maxEventBytes',
        'must be positive',
      );
    }
    if (maxQueueBytes <= 0) {
      throw ArgumentError.value(
        maxQueueBytes,
        'maxQueueBytes',
        'must be positive',
      );
    }
    if (maxQueueBytes < maxEventBytes) {
      throw ArgumentError(
        'maxQueueBytes ($maxQueueBytes) must be >= maxEventBytes '
        '($maxEventBytes), otherwise no event could ever fit in the queue.',
      );
    }
    if (maxAttempts <= 0) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }
    if (retryBaseDelay.isNegative) {
      throw ArgumentError.value(
        retryBaseDelay,
        'retryBaseDelay',
        'must not be negative',
      );
    }
    if (retryMaxDelay.isNegative) {
      throw ArgumentError.value(
        retryMaxDelay,
        'retryMaxDelay',
        'must not be negative',
      );
    }
  }
}

bool _isLoopbackHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.startsWith('127.');
}
