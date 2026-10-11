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
    this.maxAttempts = 8,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.retryMaxDelay = const Duration(minutes: 5),
    this.collectDeviceInfo = true,
    this.resolveDeviceId = true,
    this.autoFlush = true,
    this.onError,
  }) : assert(maxQueueSize > 0, 'maxQueueSize must be positive');

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
}
