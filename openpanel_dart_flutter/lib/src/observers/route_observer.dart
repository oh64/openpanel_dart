import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:openpanel_dart/openpanel_dart.dart';

import 'typedefs.dart';

/// The default filter keeps only [PageRoute]s.
bool defaultRouteFilter(Route<dynamic>? route) => route is PageRoute;

/// The default extractor uses `RouteSettings.name`.
String? defaultScreenNameExtractor(RouteSettings settings) => settings.name;

/// Tracks screen views by pushing a `screen_view` event carrying the route
/// name in the `__path` property.
///
/// Add an instance to the `navigatorObservers` list of your `MaterialApp` /
/// `CupertinoApp`.
class OpenpanelRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  OpenpanelRouteObserver({
    RouteFilter routeFilter = defaultRouteFilter,
    ScreenNameExtractor screenNameExtractor = defaultScreenNameExtractor,
  })  : _routeFilter = routeFilter,
        _screenNameExtractor = screenNameExtractor;

  final RouteFilter _routeFilter;
  final ScreenNameExtractor _screenNameExtractor;

  /// The instance used to track screen views.
  @visibleForTesting
  OpenpanelAnalytics? analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_routeFilter(route)) {
      _track(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && _routeFilter(newRoute)) {
      _track(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null &&
        _routeFilter(previousRoute) &&
        _routeFilter(route)) {
      _track(previousRoute);
    }
  }

  void _track(Route<dynamic> route) {
    final name = _screenNameExtractor(route.settings);
    if (name == null) return;
    final target = analytics ?? OpenpanelAnalytics.instance;
    unawaited(
      target.track('screen_view', properties: <String, dynamic>{
        kPathProperty: name,
      }),
    );
  }
}
