import 'dart:io';

import 'package:referrer/referrer.dart' as referrer;

/// IO (Android/iOS) implementation of the referrer loader.
Future<String?> loadReferrer() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return null;
  }
  try {
    final info = await referrer.Referrer().getReferrer();
    return info?.referrer?.toString();
  } catch (_) {
    // MissingPluginException and friends are expected on some devices.
    return null;
  }
}
