import 'package:meta/meta.dart';

/// Outcome of a single delivery attempt.
@immutable
sealed class TransportResult {
  const TransportResult();

  /// Whether the caller should stop processing the queue for now.
  bool get shouldPause => this is TransportFatal;
}

/// The event was accepted by the API.
@immutable
final class TransportSuccess extends TransportResult {
  const TransportSuccess({this.statusCode});

  final int? statusCode;
}

/// The event was rejected in a way that will never succeed
@immutable
final class TransportInvalid extends TransportResult {
  const TransportInvalid({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
}

/// A configuration problem, typically `401` or `403`. Retrying the same
/// request cannot help, so the SDK pauses and reports a configuration error.
@immutable
final class TransportFatal extends TransportResult {
  const TransportFatal({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
}

/// A transient failure that should be retried with backoff.
@immutable
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
