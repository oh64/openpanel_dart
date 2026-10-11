import 'package:flutter_test/flutter_test.dart';
import 'package:openpanel_dart/src/models/transport_result.dart';
import 'package:openpanel_dart/src/transport/track_transport.dart';

void main() {
  group('classifyStatus', () {
    test('2xx is a success', () {
      final result = classifyStatus(statusCode: 200);
      expect(result, isA<TransportSuccess>());
    });

    test('202 is a success', () {
      final result = classifyStatus(statusCode: 202);
      expect(result, isA<TransportSuccess>());
    });

    test('401 and 403 are fatal (configuration)', () {
      expect(classifyStatus(statusCode: 401), isA<TransportFatal>());
      expect(classifyStatus(statusCode: 403), isA<TransportFatal>());
      expect(classifyStatus(statusCode: 401).shouldPause, isTrue);
    });

    test('429 is retryable and honours Retry-After', () {
      final result = classifyStatus(
        statusCode: 429,
        headers: <String, List<String>>{'retry-after': <String>['30']},
      );
      expect(result, isA<TransportRetryable>());
      expect(
        (result as TransportRetryable).retryAfter,
        const Duration(seconds: 30),
      );
    });

    test('5xx are retryable', () {
      for (final code in <int>[500, 502, 503, 504]) {
        expect(classifyStatus(statusCode: code), isA<TransportRetryable>(),
            reason: 'code $code');
      }
    });

    test('other 4xx are permanently invalid', () {
      for (final code in <int>[400, 404, 413, 422]) {
        expect(classifyStatus(statusCode: code), isA<TransportInvalid>(),
            reason: 'code $code');
        expect(classifyStatus(statusCode: code).shouldPause, isFalse);
      }
    });

    test('surfaces the server message when provided', () {
      final result = classifyStatus(
        statusCode: 400,
        message: 'Invalid type',
      ) as TransportInvalid;
      expect(result.message, 'Invalid type');
    });
  });

  group('extractServerMessage', () {
    test('reads the message field from a JSON body', () {
      expect(
        extractServerMessage(<String, dynamic>{
          'status': 400,
          'error': 'Bad Request',
          'message': 'Invalid type',
        }),
        'Invalid type',
      );
    });

    test('falls back to error and detail', () {
      expect(
        extractServerMessage(<String, dynamic>{'error': 'Unauthorized'}),
        'Unauthorized',
      );
      expect(
        extractServerMessage(<String, dynamic>{'detail': 'nope'}),
        'nope',
      );
    });

    test('returns an empty string for anything else', () {
      expect(extractServerMessage('plain text'), isEmpty);
      expect(extractServerMessage(null), isEmpty);
      expect(extractServerMessage(<String, dynamic>{'nope': 1}), isEmpty);
    });
  });

  group('parseRetryAfter', () {
    test('parses a seconds value', () {
      expect(
        parseRetryAfter(<String, List<String>>{'retry-after': <String>['5']}),
        const Duration(seconds: 5),
      );
    });

    test('parses an HTTP date', () {
      final futureDate =
          DateTime.now().toUtc().add(const Duration(seconds: 60));
      final formatted = futureDate.toIso8601String();
      final duration = parseRetryAfter(
        <String, List<String>>{'retry-after': <String>[formatted]},
      );
      expect(duration, isNotNull);
      expect(duration!.inSeconds, greaterThanOrEqualTo(55));
    });

    test('returns null when absent or malformed', () {
      expect(parseRetryAfter(null), isNull);
      expect(
        parseRetryAfter(<String, List<String>>{'retry-after': <String>['NaN']}),
        isNull,
      );
    });
  });
}