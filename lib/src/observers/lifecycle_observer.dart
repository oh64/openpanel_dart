import 'dart:async';

import 'package:flutter/widgets.dart';

import '../analytics.dart';

/// Observes the application lifecycle and flushes the pending queue when the
/// app is backgrounded or resumed.
class OpenpanelLifecycleObserver with WidgetsBindingObserver {
  OpenpanelLifecycleObserver({OpenpanelAnalytics? analytics})
      : _analytics = analytics ?? OpenpanelAnalytics.instance;

  final OpenpanelAnalytics _analytics;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.resumed) {
      unawaited(_analytics.flush());
    }
  }
}
