import 'package:openpanel_dart/openpanel_dart.dart';

import 'device_context_impl_stub.dart'
    if (dart.library.io) 'device_context_impl_io.dart'
    if (dart.library.html) 'device_context_impl_web.dart' as impl;

/// Flutter [DeviceContext] backed by `device_info_plus` and `package_info_plus`.
///
/// Reports the app name/version and the operating system/device model.
/// Falls back to sensible defaults when a plugin is unavailable.
class FlutterDeviceContext implements DeviceContext {
  FlutterDeviceContext();

  @override
  Future<String> buildUserAgent() => impl.buildUserAgent();

  @override
  Future<Map<String, dynamic>> collectProperties() => impl.collectProperties();
}
