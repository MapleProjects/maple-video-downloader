/// Model representing a single HTTP cookie with Netscape format compatibility.
class NetscapeCookie {
  final String domain;
  final bool includeSubdomains;
  final String path;
  final bool isSecure;
  final int expiresEpochSeconds;
  final String name;
  final String value;
  final bool httpOnly;

  const NetscapeCookie({
    required this.domain,
    required this.name,
    required this.value,
    this.includeSubdomains = true,
    this.path = '/',
    this.isSecure = true,
    this.expiresEpochSeconds = 0,
    this.httpOnly = false,
  });

  /// Serializes into the standard Netscape cookies.txt format.
  /// Format: domain | include_subdomains | path | secure | expiry | name | value
  String toNetscapeLine() {
    final prefix = httpOnly ? '#HttpOnly_' : '';
    final subdomainsFlag = includeSubdomains ? 'TRUE' : 'FALSE';
    final secureFlag = isSecure ? 'TRUE' : 'FALSE';
    final normalizedDomain = domain.startsWith('.') ? domain : '.$domain';

    return '$prefix$normalizedDomain\t$subdomainsFlag\t$path\t$secureFlag\t$expiresEpochSeconds\t$name\t$value';
  }

  /// Parses a single line from a Netscape cookies.txt file.
  static NetscapeCookie? fromNetscapeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    bool isHttpOnly = false;
    String cleanLine = trimmed;
    if (cleanLine.startsWith('#HttpOnly_')) {
      isHttpOnly = true;
      cleanLine = cleanLine.substring('#HttpOnly_'.length);
    } else if (cleanLine.startsWith('#')) {
      return null; // Comment line
    }

    final parts = cleanLine.split('\t');
    if (parts.length < 7) {
      // Space separated fallback
      final spaceParts = cleanLine.split(RegExp(r'\s+'));
      if (spaceParts.length >= 7) {
        return _fromParts(spaceParts, isHttpOnly);
      }
      return null;
    }

    return _fromParts(parts, isHttpOnly);
  }

  static NetscapeCookie? _fromParts(List<String> parts, bool isHttpOnly) {
    try {
      final domain = parts[0];
      final includeSubdomains = parts[1].toUpperCase() == 'TRUE';
      final path = parts[2];
      final isSecure = parts[3].toUpperCase() == 'TRUE';
      final expiry = int.tryParse(parts[4]) ?? 0;
      final name = parts[5];
      final value = parts.sublist(6).join('\t');

      return NetscapeCookie(
        domain: domain,
        includeSubdomains: includeSubdomains,
        path: path,
        isSecure: isSecure,
        expiresEpochSeconds: expiry,
        name: name,
        value: value,
        httpOnly: isHttpOnly,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'includeSubdomains': includeSubdomains,
        'path': path,
        'isSecure': isSecure,
        'expiresEpochSeconds': expiresEpochSeconds,
        'name': name,
        'value': value,
        'httpOnly': httpOnly,
      };

  factory NetscapeCookie.fromJson(Map<String, dynamic> json) => NetscapeCookie(
        domain: json['domain'] as String? ?? '.youtube.com',
        includeSubdomains: json['includeSubdomains'] as bool? ?? true,
        path: json['path'] as String? ?? '/',
        isSecure: json['isSecure'] as bool? ?? true,
        expiresEpochSeconds: json['expiresEpochSeconds'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
        httpOnly: json['httpOnly'] as bool? ?? false,
      );
}
