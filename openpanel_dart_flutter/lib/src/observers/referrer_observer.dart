import 'package:flutter/widgets.dart';
import 'package:openpanel_dart/openpanel_dart.dart';

import 'referrer_loader.dart';

/// Reads the install/deeplink referrer on Android and iOS and records it as a global `__referrer` property.
///
/// The underlying plugin only exists on Android and iOS; on every other
/// platform (including web and desktop) this observer is a no-op. Attach it to your `WidgetsBinding` via `WidgetsBinding.instance.addObserver(...)`.
class OpenpanelReferrerObserver with WidgetsBindingObserver {
  OpenpanelReferrerObserver({OpenpanelAnalytics? analytics})
      : _analytics = analytics ?? OpenpanelAnalytics.instance;

  final OpenpanelAnalytics _analytics;

  @override
  Future<bool> didPushRouteInformation(
      RouteInformation routeInformation) async {
    final referrer = await loadReferrer();
    if (referrer != null && referrer.isNotEmpty) {
      _analytics.addGlobalProperties(<String, dynamic>{
        kReferrerProperty: referrer,
      });
    }
    return super.didPushRouteInformation(routeInformation);
  }
}
