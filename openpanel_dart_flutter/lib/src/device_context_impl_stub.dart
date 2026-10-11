import 'package:openpanel_dart/openpanel_dart.dart';

final DeviceContext _fallback = DefaultDeviceContext();

Future<String> buildUserAgent() => _fallback.buildUserAgent();

Future<Map<String, dynamic>> collectProperties() =>
    _fallback.collectProperties();
