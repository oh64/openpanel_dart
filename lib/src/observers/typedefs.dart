import 'package:flutter/widgets.dart';

/// Filters the routes observed by [OpenpanelRouteObserver].
typedef RouteFilter = bool Function(Route<dynamic>? route);

/// Extracts the screen name from a route's settings.
typedef ScreenNameExtractor = String? Function(RouteSettings settings);