import 'dart:io';
// ignore: implementation_imports
import 'package:desktop_webview_window/src/cookie.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cookie_model.dart';

/// Service managing YouTube & platform cookie persistence in Netscape format.
class CookieService {
  static const String _prefCookieKey = 'maple_saved_cookies_json';
  static const String _prefLastLoginKey = 'maple_last_cookie_login';
  static const String _prefAccountNameKey = 'maple_cookie_account_name';

  static CookieService? _instance;
  static CookieService get instance => _instance ??= CookieService._();

  CookieService._();

  final ValueNotifier<bool> isAuthenticatedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> accountNameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> cookieCountNotifier = ValueNotifier<int>(0);

  String? _cookiesFilePath;
  String? get cookiesFilePath => _cookiesFilePath;

  List<NetscapeCookie> _cachedCookies = [];
  List<NetscapeCookie> get cookies => List.unmodifiable(_cachedCookies);

  /// Initializes the service, resolves storage path and loads existing cookies.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookiesDir = Directory('${dir.path}/maple_video_downloader');
    if (!await cookiesDir.exists()) {
      await cookiesDir.create(recursive: true);
    }

    _cookiesFilePath = '${cookiesDir.path}/youtube_cookies.txt';

    await loadPersistedCookies();
  }

  /// Loads cookies from the Netscape file on disk or SharedPreferences fallback.
  Future<void> loadPersistedCookies() async {
    try {
      if (_cookiesFilePath != null) {
        final file = File(_cookiesFilePath!);
        if (await file.exists()) {
          final content = await file.readAsString();
          _cachedCookies = _parseNetscapeContent(content);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final savedAccount = prefs.getString(_prefAccountNameKey);
      accountNameNotifier.value = savedAccount;

      _updateAuthState();
    } catch (e) {
      debugPrint('[CookieService] Error loading cookies: $e');
    }
  }

  /// Imports and persists cookies from a raw semicolon-separated cookie header string
  /// (e.g. from document.cookie or Android CookieManager.getCookie).
  Future<bool> importFromRawHeaderString(
    String rawCookies, {
    String domain = '.youtube.com',
    String? accountName,
  }) async {
    final pairs = rawCookies.split(';');
    final newCookies = <NetscapeCookie>[];

    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Set 1 year expiry for session cookies if none specified
    final defaultExpiry = nowEpoch + (365 * 24 * 60 * 60);

    for (final pair in pairs) {
      final trimmed = pair.trim();
      if (trimmed.isEmpty) continue;

      final eqIdx = trimmed.indexOf('=');
      if (eqIdx == -1) continue;

      final name = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();

      if (name.isNotEmpty) {
        newCookies.add(
          NetscapeCookie(
            domain: domain,
            includeSubdomains: true,
            path: '/',
            isSecure: true,
            expiresEpochSeconds: defaultExpiry,
            name: name,
            value: value,
            httpOnly: false,
          ),
        );
      }
    }

    return await saveCookies(newCookies, accountName: accountName);
  }

  /// Imports and persists cookies captured from desktop_webview_window.
  Future<bool> importFromDesktopWebviewCookies(
    List<WebviewCookie> webviewCookies, {
    String? accountName,
  }) async {
    final newCookies = <NetscapeCookie>[];
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final defaultExpiry = nowEpoch + (365 * 24 * 60 * 60);

    for (final c in webviewCookies) {
      if (c.name.trim().isEmpty) continue;

      final domain = c.domain.isEmpty ? '.youtube.com' : c.domain;
      final path = c.path.isEmpty ? '/' : c.path;
      final expiry = c.expires != null
          ? (c.expires!.millisecondsSinceEpoch ~/ 1000)
          : defaultExpiry;

      newCookies.add(
        NetscapeCookie(
          domain: domain,
          includeSubdomains: domain.startsWith('.') || !domain.contains('.'),
          path: path,
          isSecure: c.secure,
          expiresEpochSeconds: expiry,
          name: c.name,
          value: c.value,
          httpOnly: c.httpOnly,
        ),
      );
    }

    if (newCookies.isEmpty) return false;
    return await saveCookies(newCookies, accountName: accountName);
  }

  /// Saves a list of NetscapeCookie objects into permanent storage.
  Future<bool> saveCookies(
    List<NetscapeCookie> newCookies, {
    String? accountName,
  }) async {
    try {
      // Merge with existing cookies by domain+name
      final map = <String, NetscapeCookie>{};
      for (final c in _cachedCookies) {
        map['${c.domain}:${c.name}'] = c;
      }
      for (final c in newCookies) {
        map['${c.domain}:${c.name}'] = c;
      }

      _cachedCookies = map.values.toList();

      // Write to Netscape cookies.txt file
      if (_cookiesFilePath != null) {
        final buffer = StringBuffer();
        buffer.writeln('# Netscape HTTP Cookie File');
        buffer.writeln('# Exported automatically by Maple Video Downloader');
        buffer.writeln('# Format: domain, subdomains, path, secure, expiry, name, value');
        buffer.writeln('');

        for (final cookie in _cachedCookies) {
          buffer.writeln(cookie.toNetscapeLine());
        }

        final file = File(_cookiesFilePath!);
        await file.writeAsString(buffer.toString());
      }

      // Save metadata in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastLoginKey, DateTime.now().toIso8601String());
      if (accountName != null && accountName.isNotEmpty) {
        await prefs.setString(_prefAccountNameKey, accountName);
        accountNameNotifier.value = accountName;
      }

      _updateAuthState();
      return true;
    } catch (e) {
      debugPrint('[CookieService] Error saving cookies: $e');
      return false;
    }
  }

  /// Parses content of a standard Netscape cookies.txt file.
  List<NetscapeCookie> _parseNetscapeContent(String content) {
    final list = <NetscapeCookie>[];
    final lines = content.split('\n');
    for (final line in lines) {
      final parsed = NetscapeCookie.fromNetscapeLine(line);
      if (parsed != null) {
        list.add(parsed);
      }
    }
    return list;
  }

  /// Checks whether essential YouTube authentication tokens are present on .youtube.com.
  bool get hasValidYouTubeSession {
    final ytCookies = _cachedCookies.where((c) {
      final d = c.domain.toLowerCase();
      return d.contains('youtube.com');
    }).toList();

    final names = ytCookies.map((c) => c.name.toUpperCase()).toSet();
    // YouTube authenticated session strictly requires LOGIN_INFO on youtube.com OR SID + SSID/HSID on youtube.com
    final hasLoginInfo = names.contains('LOGIN_INFO');
    final hasSid = names.contains('SID') ||
        names.contains('__SECURE-3PSID') ||
        names.contains('__SECURE-1PSID');
    final hasSsid = names.contains('SSID') || names.contains('HSID');

    return hasLoginInfo || (hasSid && hasSsid);
  }

  void _updateAuthState() {
    cookieCountNotifier.value = _cachedCookies.length;
    isAuthenticatedNotifier.value = hasValidYouTubeSession;
  }

  /// Clears all saved cookies and session state.
  Future<void> clearCookies() async {
    _cachedCookies.clear();
    if (_cookiesFilePath != null) {
      final file = File(_cookiesFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCookieKey);
    await prefs.remove(_prefLastLoginKey);
    await prefs.remove(_prefAccountNameKey);

    accountNameNotifier.value = null;
    _updateAuthState();
  }
}
