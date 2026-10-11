import '../constants.dart';
import 'platform_info.dart';

/// Provides read only metadata about the running application and device.
abstract interface class DeviceContext {
  /// Builds the `User-Agent` header value.
  Future<String> buildUserAgent();

  /// Collects app/device metadata merged into every event's properties.
  Future<Map<String, dynamic>> collectProperties();
}

/// Flutter-free default [DeviceContext].
///
/// It reports the SDK identity and the operating system, but no application
/// name/version (that is not reliably available outside a host framework).
/// Flutter applications usually provide a richer context from
/// `openpanel_dart_flutter`.
class DefaultDeviceContext implements DeviceContext {
  @override
  Future<String> buildUserAgent() async => 'openpanel-dart/$kSdkVersion'
      ' (${describePlatform()})';

  @override
  Future<Map<String, dynamic>> collectProperties() async =>
      <String, dynamic>{'platform': describePlatform()};
}
