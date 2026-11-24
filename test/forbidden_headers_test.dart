import 'package:openpanel_dart/src/transport/forbidden_headers.dart';
import 'package:openpanel_dart/src/transport/forbidden_headers_web.dart'
    as web;
import 'package:test/test.dart';

void main() {
  group('dropForbiddenHeaders', () {
    test('keeps every header outside of a browser', () {
      final headers = <String, String>{
        'Origin': 'https://app.example',
        'User-Agent': 'openpanel_dart/0.1.4',
        'X-Trace': '1',
      };

      expect(dropForbiddenHeaders(headers, browserForbiddenHeaders), headers);
      expect(browserForbiddenHeaders, isEmpty);
    });

    test('drops the headers a browser refuses to set', () {
      final dropped = dropForbiddenHeaders(
        <String, String>{
          'Origin': 'https://app.example',
          'ORIGIN': 'https://app.example',
          'User-Agent': 'openpanel_dart/0.1.4',
          'X-Trace': '1',
        },
        web.browserForbiddenHeaders,
      );

      expect(dropped, <String, String>{'X-Trace': '1'});
    });

    test('the web set covers the headers used by the transport', () {
      expect(web.browserForbiddenHeaders, contains('origin'));
      expect(web.browserForbiddenHeaders, containsAll(<String>[
        'content-length',
        'host',
        'referer',
        'user-agent',
      ]));
    });
  });
}
