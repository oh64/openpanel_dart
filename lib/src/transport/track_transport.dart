import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config.dart';
import '../constants.dart';
import '../models/track_request.dart';
import '../models/transport_result.dart';

/// Result of a device identifier resolution.
@immutable
class DeviceIdentity {
  const DeviceIdentity({this.deviceId, this.sessionId});

  /// Device identifier, when returned by the server.
  final String? deviceId;

  /// Session identifier, when returned by the server.
  final String? sessionId;
}

/// HTTP client responsible for talking to the OpenPanel API.
abstract interface class TrackTransport {
  /// Sends the request and classifies the outcome.
  Future<TransportResult> send(TrackRequest request);

  /// Resolution of a device/session identifier.
  /// Returns `null` when the server did not answer or the answer could not be
  /// parsed.
  Future<DeviceIdentity?> fetchDeviceId();

  /// Releases any held resources.
  void close();
}

/// [TrackTransport] backed by `package:dio`.
class DioTrackTransport implements TrackTransport {
  DioTrackTransport({
    required OpenpanelConfig config,
    required String userAgent,
    Dio? dio,
  })  : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 10),
                // We classify every status code ourselves.
                validateStatus: (_) => true,
                headers: <String, dynamic>{
                  kClientIdHeader: config.clientId,
                  kSdkNameHeader: kSdkName,
                  kSdkVersionHeader: kSdkVersion,
                  'User-Agent': userAgent,
                  if (config.clientSecret != null)
                    kClientSecretHeader: config.clientSecret,
                  ...config.headers,
                },
              ),
            );

  final OpenpanelConfig _config;
  final Dio _dio;

  @override
  Future<TransportResult> send(TrackRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        kTrackPath,
        data: request.toBody(),
      );
      _log('POST $kTrackPath -> ${response.statusCode}');
      return classifyStatus(
        statusCode: response.statusCode ?? 0,
        headers: response.headers.map,
      );
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) {
        _log('POST $kTrackPath -> ${response.statusCode}');
        return classifyStatus(
          statusCode: response.statusCode ?? 0,
          headers: response.headers.map,
        );
      }
      // Network / timeout error.
      return TransportRetryable(message: error.message ?? 'Network error');
    }
  }

  @override
  Future<DeviceIdentity?> fetchDeviceId() async {
    try {
      final response = await _dio.get<dynamic>(kDeviceIdPath);
      final body = response.data;
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      return DeviceIdentity(
        deviceId: _firstString(map, <String>['deviceId', 'device_id', 'id']),
        sessionId: _firstString(map, <String>['sessionId', 'session_id']),
      );
    } on DioException {
      return null;
    }
  }

  @override
  void close() {
    _dio.close(force: true);
  }

  void _log(String message) {
    if (_config.verbose) {
      // ignore: avoid_print
      print('[openpanel_dart] $message');
    }
  }
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// Classifies a raw HTTP status code into a [TransportResult].
@visibleForTesting
TransportResult classifyStatus({
  required int statusCode,
  Map<String, List<String>>? headers,
  String message = '',
}) {
  if (statusCode >= 200 && statusCode < 300) {
    return TransportSuccess(statusCode: statusCode);
  }
  if (statusCode == 401 || statusCode == 403) {
    return TransportFatal(
      statusCode: statusCode,
      message: message.isNotEmpty
          ? message
          : 'Authentication rejected by the API (HTTP $statusCode). '
              'Check the client id, and the client secret if set.',
    );
  }
  if (statusCode == 429) {
    return TransportRetryable(
      statusCode: statusCode,
      message: 'Rate limited (HTTP 429).',
      retryAfter: parseRetryAfter(headers),
    );
  }
  if (statusCode >= 500) {
    return TransportRetryable(
      statusCode: statusCode,
      message: 'Server error (HTTP $statusCode).',
    );
  }
  return TransportInvalid(
    statusCode: statusCode,
    message: message.isNotEmpty
        ? message
        : 'The API rejected the event (HTTP $statusCode).',
  );
}

/// Parses the `Retry-After` header which can be expressed in seconds or as an
/// HTTP date. Returns `null` when absent or unparseable.
Duration? parseRetryAfter(Map<String, List<String>>? headers) {
  if (headers == null) return null;
  final values = headers['retry-after'];
  if (values == null || values.isEmpty) return null;
  final raw = values.first.trim();
  final seconds = int.tryParse(raw);
  if (seconds != null && seconds >= 0) {
    return Duration(seconds: seconds);
  }
  final date = DateTime.tryParse(raw);
  if (date != null) {
    final delta = date.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }
  return null;
}

/// Decodes the API error body for logging purposes.
@visibleForTesting
String decodeErrorBody(Object? body) {
  if (body is String) return body;
  if (body is Map) return jsonEncode(body);
  return '$body';
}
