import 'dart:io';

import 'package:test/test.dart';
import 'package:openpanel_dart/openpanel_dart.dart';

void main() {
  test('kSdkVersion matches the version published in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(
      match,
      isNotNull,
      reason: 'pubspec.yaml must declare a `version` field',
    );
    expect(
      kSdkVersion,
      match!.group(1),
      reason: 'kSdkVersion does not match pubspec.yaml version',
    );
  });
}
