import 'package:meta/meta.dart';

/// Callback invoked whenever the SDK reports an error.
typedef OpenpanelErrorHandler = void Function(OpenpanelError error);

/// Category of an [OpenpanelError]
enum OpenpanelErrorKind {
  /// The SDK is misconfigured
  configuration,

  /// A transport level problem
  /// These are retried with until `maxAttempts` is
  /// reached, after which the event is dropped.
  transport,

  /// The queue rejected an event because it was too large or malformed
  invalidEvent,

  /// A local storage problem while persisting the queue
  storage,
}

/// Error surfaced by the SDK.
@immutable
class OpenpanelError {
  const OpenpanelError({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  /// Category of the error
  final OpenpanelErrorKind kind;

  /// Human readable description
  final String message;

  /// HTTP status code, when applicable
  final int? statusCode;

  /// Underlying cause, when available
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'OpenpanelError(${kind.name})$code: $message';
  }
}
