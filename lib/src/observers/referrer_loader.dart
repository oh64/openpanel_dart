import 'referrer_loader_stub.dart'
    if (dart.library.io) 'referrer_loader_io.dart' as loader;

/// Resolves the install/deeplink referrer, or `null` when unavailable
Future<String?> loadReferrer() => loader.loadReferrer();
