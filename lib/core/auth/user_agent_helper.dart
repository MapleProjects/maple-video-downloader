import 'dart:io';

/// Helper providing clean User-Agents to prevent Google's 'disallowed_useragent'
/// block during embedded WebView sign-in.
class UserAgentHelper {
  /// Standard desktop Chrome User-Agent on Linux x86_64.
  static const String linuxChrome =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Standard desktop Chrome User-Agent on Windows 10/11 x64.
  static const String windowsChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Modern Android Mobile Chrome User-Agent stripped of 'wv' (WebView indicator).
  /// Google checks for 'wv' or 'Version/4.0' to deny OAuth in embedded WebViews.
  static const String androidMobileChromeClean =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.6723.107 Mobile Safari/537.36';

  /// Selects the best User-Agent for Google/YouTube authentication based on platform.
  static String getAuthUserAgent({bool forceDesktop = true}) {
    if (forceDesktop) {
      if (Platform.isLinux) {
        return linuxChrome;
      }
      return windowsChrome;
    }
    return androidMobileChromeClean;
  }
}
