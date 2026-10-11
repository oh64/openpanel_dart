import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.js_interop) 'platform_info_web.dart' as impl;

/// Short human readable description of the current platform
String describePlatform() => impl.describePlatform();
