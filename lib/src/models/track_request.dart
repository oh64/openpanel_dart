import 'package:meta/meta.dart';

/// A single unit of work sent to `POST /track`.
/// The API accepts a `{ "type": ..., "payload": ... }` envelope.
@immutable
class TrackRequest {
  const TrackRequest({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  /// Locally generated identifier, unique within the queue.
  final String id;

  /// One of `track`, `identify`, `increment`, `decrement`, `group`,
  /// `assign_group` or `alias`.
  final String type;

  /// The `payload` object of the request envelope.
  final Map<String, dynamic> payload;

  /// When the request was created.
  final DateTime createdAt;

  /// Number of failed delivery attempts so far.
  final int attempts;

  /// The JSON body sent to the API.
  Map<String, dynamic> toBody() => <String, dynamic>{
        'type': type,
        'payload': payload,
      };

  /// Serialization used by the persistent queue.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
      };

  /// Deserializes an event previously written by [toJson].
  factory TrackRequest.fromJson(Map<String, dynamic> json) => TrackRequest(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );

  TrackRequest copyWith({int? attempts}) => TrackRequest(
        id: id,
        type: type,
        payload: payload,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
      );

  @override
  String toString() => 'TrackRequest($type, id: $id, attempts: $attempts)';
}
