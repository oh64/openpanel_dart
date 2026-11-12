import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../constants.dart';
import '../models/track_request.dart';
import '../models/transport_result.dart';

/// Result of a device identifier resolution.
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

/// [TrackTransport] backed by `package:http`.
class HttpTrackTransport implements TrackTransport {
  HttpTrackTransport({
    required OpenpanelConfig config,
    required String userAgent,
    http.Client? client,
  })  : _config = config,
        _client = client ?? http.Client(),
        _baseHeaders = <String, String>{
          kClientIdHeader: config.clientId,
          kSdkNameHeader: kSdkName,
          kSdkVersionHeader: kSdkVersion,
          'User-Agent': userAgent,
          if (config.clientSecret != null)
            kClientSecretHeader: config.clientSecret!,
          ...config.headers,
        };

  static const Duration _requestTimeout = Duration(seconds: 20);

  final OpenpanelConfig _config;
  final http.Client _client;
  final Map<String, String> _baseHeaders;

  Uri _uri(String path) => Uri.parse('${_config.apiUrl}$path');

  @override
  Future<TransportResult> send(TrackRequest request) async {
    try {
      final response = await _client
          .post(
            _uri(kTrackPath),
            headers: <String, String>{
              ..._baseHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toBody()),
          )
          .timeout(_requestTimeout);
      final body = _decodeBody(response.body);
      _log(
        'POST $kTrackPath -> ${response.statusCode} '
        '${decodeErrorBody(body)}',
      );
      return classifyStatus(
        statusCode: response.statusCode,
        headers: _responseHeaders(response),
        message: extractServerMessage(body),
      );
    } on TimeoutException catch (error) {
      return TransportRetryable(
        message: error.message ?? 'Network timeout',
      );
    } on http.ClientException catch (error) {
      return TransportRetryable(message: error.message);
    }
  }

  @override
  Future<DeviceIdentity?> fetchDeviceId() async {
    try {
      final response = await _client
          .get(_uri(kDeviceIdPath), headers: _baseHeaders)
          .timeout(_requestTimeout);
      final body = _decodeBody(response.body);
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      return DeviceIdentity(
        deviceId: _firstString(map, const <String>['deviceId', 'device_id', 'id']),
        sessionId: _firstString(map, const <String>['sessionId', 'session_id']),
      );
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  @override
  void close() {
    _client.close();
  }

  void _log(String message) {
    if (_config.verbose) {
      // ignore: avoid_print
      print('[openpanel_dart] $message');
    }
  }

  /// Decodes a JSON body, falling back to the raw text.
  static Object? _decodeBody(String body) {
    if (body.isEmpty) return '';
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  static Map<String, List<String>> _responseHeaders(http.Response response) =>
      response.headers.map(
        (key, value) => MapEntry(key.toLowerCase(), <String>[value]),
      );
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
  // RFC 7231 `HTTP-date`
  final httpDate = parseHttpDate(raw);
  if (httpDate != null) {
    final delta = httpDate.difference(DateTime.now().toUtc());
    return delta.isNegative ? Duration.zero : delta;
  }
  final iso = DateTime.tryParse(raw);
  if (iso != null) {
    final delta = iso.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }
  return null;
}

/// Parses an RFC 7231 `HTTP-date` :
///
/// * IMF-fixdate: `Sun, 06 Nov 1994 08:49:37 GMT`
/// * RFC 850: `Sunday, 06-Nov-94 08:49:37 GMT`
/// * ANSI C asctime: `Sun Nov  6 08:49:37 1994`
///
/// Returns `null` when [value] is not a valid HTTP-date.
DateTime? parseHttpDate(String value) {
  final raw = value.trim();

  final imfFixdate = RegExp(
    r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) '
    r'(\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(raw);
  if (imfFixdate != null) {
    return _buildUtc(
      year: imfFixdate[3],
      month: imfFixdate[2],
      day: imfFixdate[1],
      hour: imfFixdate[4],
      minute: imfFixdate[5],
      second: imfFixdate[6],
    );
  }

  final rfc850 = RegExp(
    r'^[A-Za-z]+, (\d{2})-([A-Za-z]{3})-(\d{2}) '
    r'(\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(raw);
  if (rfc850 != null) {
    final shortYear = int.tryParse(rfc850[3] ?? '');
    if (shortYear == null) return null;
    final year = shortYear >= 70 ? 1900 + shortYear : 2000 + shortYear;
    return _buildUtc(
      year: '$year',
      month: rfc850[2],
      day: rfc850[1],
      hour: rfc850[4],
      minute: rfc850[5],
      second: rfc850[6],
    );
  }

  final asctime = RegExp(
    r'^[A-Za-z]{3} ([A-Za-z]{3})\s+(\d{1,2}) '
    r'(\d{2}):(\d{2}):(\d{2}) (\d{4})$',
  ).firstMatch(raw);
  if (asctime != null) {
    return _buildUtc(
      year: asctime[6],
      month: asctime[1],
      day: asctime[2],
      hour: asctime[3],
      minute: asctime[4],
      second: asctime[5],
    );
  }

  return null;
}

const Map<String, int> _monthNumbers = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

DateTime? _buildUtc({
  required String? year,
  required String? month,
  required String? day,
  required String? hour,
  required String? minute,
  required String? second,
}) {
  final y = int.tryParse(year ?? '');
  final d = int.tryParse(day ?? '');
  final h = int.tryParse(hour ?? '');
  final mi = int.tryParse(minute ?? '');
  final s = int.tryParse(second ?? '');
  final m = _monthNumbers[(month ?? '').toLowerCase()];
  if (y == null ||
      d == null ||
      h == null ||
      mi == null ||
      s == null ||
      m == null) {
    return null;
  }
  return DateTime.utc(y, m, d, h, mi, s);
}

/// Decodes the API error body for logging purposes.
String decodeErrorBody(Object? body) {
  if (body is String) return body;
  if (body is Map) return jsonEncode(body);
  return '$body';
}

/// Extracts a human readable message from an error response body.
String extractServerMessage(Object? body) {
  if (body is Map) {
    for (final key in const <String>['message', 'error', 'detail']) {
      final value = body[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
  }
  return '';
}
