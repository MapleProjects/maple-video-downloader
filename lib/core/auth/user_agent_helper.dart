/// Helper providing clean User-Agents to prevent Google's 'disallowed_useragent'
/// block during embedded WebView sign-in.
class UserAgentHelper {
  /// Standard desktop Chrome User-Agent on Windows 10/11 x64.
  /// Bypasses Google OAuth blocks by presenting as a native desktop browser.
  static const String desktopChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// Modern Linux desktop Firefox User-Agent.
  static const String desktopFirefox =
      'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0';

  /// Modern Android Mobile Chrome User-Agent stripped of 'wv' (WebView indicator).
  /// Google checks for 'wv' or 'Version/4.0' to deny OAuth in embedded WebViews.
  static const String androidMobileChromeClean =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.6723.107 Mobile Safari/537.36';

  /// Selects the best User-Agent for Google/YouTube authentication based on platform.
  static String getAuthUserAgent({bool forceDesktop = true}) {
    if (forceDesktop) {
      return desktopChrome;
    }
    return androidMobileChromeClean;
  }
}
