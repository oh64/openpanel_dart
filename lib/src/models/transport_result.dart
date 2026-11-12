/// Outcome of a single delivery attempt.
sealed class TransportResult {
  const TransportResult();

  /// Whether the caller should stop processing the queue for now.
  bool get shouldPause => this is TransportFatal;
}

/// The event was accepted by the API.
final class TransportSuccess extends TransportResult {
  const TransportSuccess({this.statusCode});

  final int? statusCode;
}

/// The event was rejected in a way that will never succeed
final class TransportInvalid extends TransportResult {
  const TransportInvalid({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
}

/// A configuration problem, typically `401` or `403`. Retrying the same
/// request cannot help, so the SDK pauses and reports a configuration error.
final class TransportFatal extends TransportResult {
  const TransportFatal({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
}

/// A transient failure that should be retried with backoff.
final class TransportRetryable extends TransportResult {
  const TransportRetryable({
    required this.message,
    this.statusCode,
    this.retryAfter,
  });

  final String message;
  final int? statusCode;

  final Duration? retryAfter;
}
