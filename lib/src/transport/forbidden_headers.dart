import 'forbidden_headers_native.dart'
    if (dart.library.js_interop) 'forbidden_headers_web.dart' as impl;

/// Header names a browser refuses to let application code set
Set<String> get browserForbiddenHeaders => impl.browserForbiddenHeaders;

/// Returns [headers] without every entry whose name
Map<String, String> dropForbiddenHeaders(
  Map<String, String> headers,
  Set<String> forbidden,
) {
  if (forbidden.isEmpty) return headers;
  return <String, String>{
    for (final entry in headers.entries)
      if (!forbidden.contains(entry.key.toLowerCase())) entry.key: entry.value,
  };
}
