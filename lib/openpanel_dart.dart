/// ```dart
/// import 'package:openpanel_dart/openpanel_dart.dart';
///
/// final analytics = OpenpanelAnalytics.instance;
/// await analytics.init(
///   OpenpanelConfig(
///     apiUrl: 'https://your-self-hosted-domain',
///     clientId: 'your-client-id',
///     headers: {'Origin': 'https://your-app.example'},
///   ),
/// );
///
/// analytics.track('app_open');
/// ```
library;

export 'src/analytics.dart';
export 'src/config.dart';
export 'src/constants.dart';
export 'src/errors.dart';
export 'src/identity/identity_store.dart';
export 'src/models/track_request.dart';
export 'src/models/transport_result.dart';
export 'src/observers/lifecycle_observer.dart';
export 'src/observers/referrer_observer.dart';
export 'src/observers/route_observer.dart';
export 'src/observers/typedefs.dart';
export 'src/platform/device_context.dart';
export 'src/queue/event_queue.dart';
export 'src/transport/track_transport.dart';
