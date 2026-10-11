import 'package:test/test.dart';
import 'package:openpanel_dart/openpanel_dart.dart';

OpenpanelConfig _config({
  String clientId = 'client-1',
  String apiUrl = 'https://analytics.example.com',
  int maxQueueSize = 500,
  int maxEventBytes = 64 * 1024,
  int maxQueueBytes = 4 * 1024 * 1024,
  int maxAttempts = 8,
  Duration retryBaseDelay = const Duration(seconds: 2),
  Duration retryMaxDelay = const Duration(minutes: 5),
}) {
  return OpenpanelConfig(
    clientId: clientId,
    apiUrl: apiUrl,
    maxQueueSize: maxQueueSize,
    maxEventBytes: maxEventBytes,
    maxQueueBytes: maxQueueBytes,
    maxAttempts: maxAttempts,
    retryBaseDelay: retryBaseDelay,
    retryMaxDelay: retryMaxDelay,
  );
}

void main() {
  group('OpenpanelConfig.validate', () {
    test('accepts a valid configuration', () {
      expect(_config().validate, returnsNormally);
    });

    test('allows plain http on a loopback host for development', () {
      expect(
        _config(apiUrl: 'http://localhost:3000').validate,
        returnsNormally,
      );
      expect(
        _config(apiUrl: 'http://127.0.0.1:8080').validate,
        returnsNormally,
      );
    });

    test('rejects an empty client id', () {
      expect(
        _config(clientId: '  ').validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a malformed or relative URL', () {
      for (final url in <String>['', 'not a url', '/track', 'https://']) {
        expect(
          _config(apiUrl: url).validate,
          throwsA(isA<ArgumentError>()),
          reason: 'url "$url" should be rejected',
        );
      }
    });

    test('rejects a non http(s) scheme', () {
      expect(
        _config(apiUrl: 'ftp://analytics.example.com').validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects plain http for a non loopback host', () {
      expect(
        _config(apiUrl: 'http://analytics.example.com').validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects negative retry delays', () {
      expect(
        _config(retryBaseDelay: const Duration(seconds: -1)).validate,
        throwsA(isA<ArgumentError>()),
      );
      expect(
        _config(retryMaxDelay: const Duration(seconds: -1)).validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a byte budget smaller than the per event limit', () {
      expect(
        _config(maxQueueBytes: 100, maxEventBytes: 1000).validate,
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non positive integer limits', () {
      expect(
        () => _config(maxQueueSize: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _config(maxEventBytes: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _config(maxQueueBytes: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _config(maxAttempts: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
