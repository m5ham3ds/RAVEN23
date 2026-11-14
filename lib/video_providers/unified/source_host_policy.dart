import 'dart:io';

/// Host policy shared by external repository and playback-source HTTP clients
/// (QuickJS, Stremio, VidKing Direct and OpenStream anime/web embed). DNS is
/// checked before each Dart-managed request and every redirect; private,
/// loopback and link-local destinations fail closed. The Android WebView bridge
/// additionally rejects private literals/local hostnames, but cannot pin its
/// internal DNS result to the socket. This is defense in depth, not a trust or
/// signature check.
class SourceHostPolicy {
  const SourceHostPolicy({
    this.resolveDns = true,
    this.lookup = InternetAddress.lookup,
    this.maxRedirects = 4,
  });

  final bool resolveDns;
  final Future<List<InternetAddress>> Function(String host) lookup;
  final int maxRedirects;

  Future<Uri> validate(String value) async {
    final uri = Uri.tryParse(value);
    final hostName = uri?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        hostName == null ||
        hostName.isEmpty ||
        uri.userInfo.isNotEmpty ||
        hostName == 'localhost' ||
        hostName.endsWith('.localhost') ||
        hostName.endsWith('.local') ||
        hostName.endsWith('.internal') ||
        hostName.endsWith('.test') ||
        hostName.endsWith('.invalid')) {
      throw const FormatException(
        'Source URL must be a public HTTP(S) address without embedded credentials.',
      );
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      throw const FormatException('Source URL contains an invalid port.');
    }

    final host = uri.host.startsWith('[') && uri.host.endsWith(']')
        ? uri.host.substring(1, uri.host.length - 1)
        : uri.host;
    final literal = InternetAddress.tryParse(host);
    final numericAddressCandidate = RegExp(
      r'^(?:(?:0x[0-9a-f]+)|[0-9]+)(?:\.(?:(?:0x[0-9a-f]+)|[0-9]+))*$',
      caseSensitive: false,
    ).hasMatch(hostName);
    if (literal == null && numericAddressCandidate) {
      throw const FormatException(
        'Non-canonical numeric IP addresses are not allowed.',
      );
    }
    if (literal != null) {
      if (!_isPublicAddress(literal)) {
        throw const FormatException(
          'Private or reserved network destinations are not allowed.',
        );
      }
    } else if (resolveDns) {
      final addresses = await lookup(host).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw const FormatException('Source host DNS lookup timed out.'),
      );
      if (addresses.isEmpty ||
          addresses.any((address) => !_isPublicAddress(address))) {
        throw const FormatException(
          'Source host resolves to a private or reserved network address.',
        );
      }
    }
    return uri;
  }

  bool _isPublicAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return false;
    }
    if (address.type == InternetAddressType.IPv4) {
      final parts = address.address.split('.').map(int.tryParse).toList();
      if (parts.length != 4 || parts.any((part) => part == null)) return false;
      final a = parts[0]!;
      final b = parts[1]!;
      final c = parts[2]!;
      return a != 0 &&
          a != 10 &&
          a != 127 &&
          !(a == 100 && b >= 64 && b <= 127) &&
          !(a == 169 && b == 254) &&
          !(a == 172 && b >= 16 && b <= 31) &&
          !(a == 192 && b == 0 && c == 0) &&
          !(a == 192 && b == 0 && c == 2) &&
          !(a == 192 && b == 168) &&
          !(a == 198 && (b == 18 || b == 19)) &&
          !(a == 198 && b == 51 && c == 100) &&
          !(a == 203 && b == 0 && c == 113) &&
          a < 224;
    }

    final normalized = address.address.toLowerCase();
    // IPv6-mapped IPv4 is unpacked and checked using the IPv4 deny list.
    // Other IPv4-compatible/NAT64 forms are denied. Only global-unicast
    // 2000::/3 is eligible, then IANA special-purpose ranges are excluded.
    if (normalized.startsWith('::ffff:')) {
      final mapped = normalized.substring('::ffff:'.length);
      final ipv4 = InternetAddress.tryParse(mapped);
      if (ipv4 != null) return _isPublicAddress(ipv4);
      final groups = mapped.split(':');
      if (groups.length == 2) {
        final high = int.tryParse(groups[0], radix: 16);
        final low = int.tryParse(groups[1], radix: 16);
        if (high != null && low != null) {
          final octets = <int>[
            (high >> 8) & 255,
            high & 255,
            (low >> 8) & 255,
            low & 255,
          ];
          return _isPublicAddress(InternetAddress(octets.join('.')));
        }
      }
      return false;
    }
    if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      if (bytes.length != 16) return false;
      final firstWord = (bytes[0] << 8) | bytes[1];
      if ((firstWord & 0xe000) != 0x2000) return false;
      final secondWord = (bytes[2] << 8) | bytes[3];
      if ((firstWord == 0x2001 && secondWord <= 0x01ff) ||
          (firstWord == 0x2001 && secondWord == 0x0db8) ||
          firstWord == 0x2002) {
        // Deny IETF protocol/special-purpose allocations in 2001::/23,
        // documentation space, and the deprecated 6to4 transition block.
        return false;
      }
    }
    return true;
  }
}
