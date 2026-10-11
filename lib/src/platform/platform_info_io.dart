import 'dart:io';

/// `dart:io` platform description, for example `linux 6.1.0`.
String describePlatform() {
  final version = Platform.operatingSystemVersion.trim();
  return version.isEmpty
      ? Platform.operatingSystem
      : '${Platform.operatingSystem} $version';
}
