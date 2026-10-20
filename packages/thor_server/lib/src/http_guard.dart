import 'dart:async';
import 'dart:io';

/// What `HttpClient.connectionFactory` takes.
typedef ConnectionFactory =
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    );

/// The connection was refused before any byte left: the host resolves to an
/// address of a private network (see [isPrivateAddress]).
class PrivateAddressException implements Exception {
  /// [host] resolved to [address].
  const PrivateAddressException(this.host, this.address);

  /// The name (or literal address) of the URL.
  final String host;

  /// The private address it resolved to.
  final InternetAddress address;

  @override
  String toString() =>
      'refused: $host is a private address (${address.address})';
}

/// Whether [address] is one a server must not reach on behalf of a visitor:
/// the host itself (`127/8`, `::1`, `0.0.0.0`), the private ranges (`10/8`,
/// `172.16/12`, `192.168/16`, `fc00::/7`), link-local (`169.254/16`, which is
/// where the cloud metadata services live, and `fe80::/10`), carrier-grade
/// NAT (`100.64/10`), the benchmark, protocol-assignment, multicast and
/// reserved ranges, and the IPv6 forms that carry an IPv4 address inside
/// (`::ffff:a.b.c.d`, `::a.b.c.d`, NAT64 `64:ff9b::/96`, 6to4 `2002::/16`,
/// Teredo `2001::/32`): they are judged by the address they carry.
bool isPrivateAddress(InternetAddress address) {
  final b = address.rawAddress;
  if (b.length == 4) return _privateV4(b[0], b[1], b[2]);
  if (b.length != 16) return true;
  bool zero(int from, int to) {
    for (var i = from; i < to; i++) {
      if (b[i] != 0) return false;
    }
    return true;
  }

  // ::a.b.c.d (also `::` and `::1`) and ::ffff:a.b.c.d.
  if (zero(0, 12)) return _privateV4(b[12], b[13], b[14]);
  if (zero(0, 10) && b[10] == 0xff && b[11] == 0xff) {
    return _privateV4(b[12], b[13], b[14]);
  }
  // NAT64 (64:ff9b::/96) carries the IPv4 address; 64:ff9b:1::/48 is local.
  if (b[0] == 0x00 && b[1] == 0x64 && b[2] == 0xff && b[3] == 0x9b) {
    return b[4] == 0 && b[5] == 0 && zero(6, 12)
        ? _privateV4(b[12], b[13], b[14])
        : true;
  }
  // 6to4 (2002::/16): the IPv4 address follows the prefix.
  if (b[0] == 0x20 && b[1] == 0x02) return _privateV4(b[2], b[3], b[4]);
  // Teredo (2001::/32).
  if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0 && b[3] == 0) return true;
  // fe80::/10 link-local and fec0::/10 site-local.
  if (b[0] == 0xfe && (b[1] & 0x80) != 0) return true;
  // fc00::/7 unique local (fd00::/8 is where AWS puts its IPv6 metadata).
  if ((b[0] & 0xfe) == 0xfc) return true;
  // ff00::/8 multicast.
  return b[0] == 0xff;
}

bool _privateV4(int a, int b, int c) =>
    a == 0 ||
    a == 10 ||
    a == 127 ||
    (a == 100 && b >= 64 && b <= 127) ||
    (a == 169 && b == 254) ||
    (a == 172 && b >= 16 && b <= 31) ||
    (a == 192 && b == 0 && c == 0) ||
    (a == 192 && b == 168) ||
    (a == 198 && (b == 18 || b == 19)) ||
    a >= 224;

/// A `connectionFactory` for an `HttpClient` that never connects to a
/// private address (see [isPrivateAddress]; [isBlocked] replaces it in
/// tests). The host is resolved here, every answer is checked (one private
/// answer among public ones refuses the host: that is what DNS rebinding
/// serves), and the socket goes to the address that was checked, not to the
/// name again, so the answer cannot change between the check and the
/// connection. It runs for every connection, so a redirect to a private
/// address is refused when the client follows it. For `https` the TLS
/// handshake is made here, against the name of the URL.
///
/// The client must have `findProxy` set to `DIRECT`: through a proxy the
/// proxy is the one that connects, and no address of the target is seen.
ConnectionFactory guardedConnection({
  bool Function(InternetAddress address)? isBlocked,
  Future<List<InternetAddress>> Function(String host)? resolve,
  SecurityContext? context,
}) {
  final blocked = isBlocked ?? isPrivateAddress;
  final lookup = resolve ?? InternetAddress.lookup;
  return (url, proxyHost, proxyPort) async {
    final host = url.host;
    final port = url.port;
    final addresses = await lookup(host);
    if (addresses.isEmpty) {
      throw SocketException('Failed host lookup: $host');
    }
    for (final a in addresses) {
      if (blocked(a)) throw PrivateAddressException(host, a);
    }
    var cancelled = false;
    Socket? pending;
    Future<Socket> connect() async {
      Object? last;
      for (final a in addresses) {
        if (cancelled) break;
        try {
          final socket = pending = await Socket.connect(a, port);
          if (cancelled) {
            socket.destroy();
            break;
          }
          return socket;
        } on SocketException catch (e) {
          last = e;
        }
      }
      throw last ?? const SocketException('connection cancelled');
    }

    final plain = connect();
    final Future<Socket> socket = url.scheme == 'https'
        ? plain.then<Socket>(
            (s) => SecureSocket.secure(s, host: host, context: context),
          )
        : plain;
    return ConnectionTask.fromSocket(socket, () {
      cancelled = true;
      pending?.destroy();
    });
  };
}
