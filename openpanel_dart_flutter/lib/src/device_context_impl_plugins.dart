import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:openpanel_dart/openpanel_dart.dart';
import 'package:package_info_plus/package_info_plus.dart';

final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

Future<String> buildUserAgent() async {
  final info = await _safePackageInfo();
  final platform = await _platformInfo();
  return '${info.appName}/${info.version} '
      '(${platform.osName} ${platform.osVersion}; ${platform.model}) '
      'openpanel-dart/$kSdkVersion';
}

Future<Map<String, dynamic>> collectProperties() async {
  final info = await _safePackageInfo();
  final platform = await _platformInfo();
  return <String, dynamic>{
    'app_name': info.appName,
    'app_version': info.version,
    'app_build': info.buildNumber,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'os_name': platform.osName,
    'os_version': platform.osVersion,
    'device_model': platform.model,
  };
}

Future<({String osName, String osVersion, String model})>
    _platformInfo() async {
  if (kIsWeb) {
    try {
      final web = await _deviceInfo.webBrowserInfo;
      return (
        osName: 'Web',
        osVersion: web.platform ?? 'unknown',
        model: web.browserName.name,
      );
    } catch (_) {
      return (osName: 'Web', osVersion: 'unknown', model: 'browser');
    }
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      try {
        final android = await _deviceInfo.androidInfo;
        return (
          osName: 'Android',
          osVersion: android.version.release,
          model: '${android.brand} ${android.model}'.trim(),
        );
      } catch (_) {
        return (osName: 'Android', osVersion: 'unknown', model: 'unknown');
      }
    case TargetPlatform.iOS:
      try {
        final ios = await _deviceInfo.iosInfo;
        return (
          osName: 'iOS',
          osVersion: ios.systemVersion,
          model: ios.utsname.machine,
        );
      } catch (_) {
        return (osName: 'iOS', osVersion: 'unknown', model: 'iPhone');
      }
    case TargetPlatform.macOS:
      try {
        final mac = await _deviceInfo.macOsInfo;
        return (osName: 'macOS', osVersion: mac.osRelease, model: mac.model);
      } catch (_) {
        return (osName: 'macOS', osVersion: 'unknown', model: 'Mac');
      }
    case TargetPlatform.windows:
      try {
        final win = await _deviceInfo.windowsInfo;
        return (
          osName: 'Windows',
          osVersion: win.displayVersion,
          model: win.computerName,
        );
      } catch (_) {
        return (osName: 'Windows', osVersion: 'unknown', model: 'PC');
      }
    case TargetPlatform.linux:
      try {
        final linux = await _deviceInfo.linuxInfo;
        final version = linux.version?.trim();
        return (
          osName: 'Linux',
          osVersion: (version?.isNotEmpty ?? false) ? version! : 'unknown',
          model: linux.name,
        );
      } catch (_) {
        return (osName: 'Linux', osVersion: 'unknown', model: 'Linux');
      }
    case TargetPlatform.fuchsia:
      return (osName: 'Fuchsia', osVersion: 'unknown', model: 'Fuchsia');
  }
}

Future<_PackageInfoData> _safePackageInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return _PackageInfoData(
      appName: info.appName,
      version: info.version,
      buildNumber: info.buildNumber,
    );
  } catch (_) {
    return const _PackageInfoData(
      appName: 'app',
      version: '0.0.0',
      buildNumber: '0',
    );
  }
}

final class _PackageInfoData {
  const _PackageInfoData({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;
}
