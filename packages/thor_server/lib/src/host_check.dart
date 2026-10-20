/// Whether the `Host` header [host] names one of [allowed].
///
/// [allowed] entries are host names without port (`example.com`), or
/// `*.example.com` for any subdomain (not `example.com` itself). Case does
/// not matter; the port of the header is ignored. A missing header, an
/// empty one or one with characters a host name never has (`/`, `@`, `\`,
/// a space, a comma that lists two hosts) is refused.
bool hostAllowed(String? host, List<String> allowed) {
  final name = hostName(host);
  if (name == null) return false;
  for (final entry in allowed) {
    final e = entry.toLowerCase();
    if (e.startsWith('*.')) {
      final suffix = e.substring(1); // `.example.com`
      if (name.length > suffix.length && name.endsWith(suffix)) return true;
    } else if (name == e) {
      return true;
    }
  }
  return false;
}

/// The lowercase host name of a `Host` header, or `null` when it is not a
/// well-formed `host[:port]`.
String? hostName(String? header) {
  if (header == null) return null;
  final h = header.trim().toLowerCase();
  final match = RegExp(
    r'^(?:\[([0-9a-f:.]+)\]|([a-z0-9._-]+))(?::(\d{1,5}))?$',
  ).firstMatch(h);
  if (match == null) return null;
  final name = match[1] != null ? '[${match[1]}]' : match[2]!;
  // `example.com.` is the same host with the root dot.
  return name.endsWith('.') ? name.substring(0, name.length - 1) : name;
}
