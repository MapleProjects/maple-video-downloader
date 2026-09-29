enum SupportedPlatform {
  youtube,
  tiktok,
  twitter,
  instagram,
  facebook,
  twitch,
  reddit,
  bilibili,
  generic,
}

/// Helper to identify video platform from URL and provide platform metadata.
class PlatformDetector {
  static SupportedPlatform detect(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return SupportedPlatform.youtube;
    }
    if (lower.contains('tiktok.com')) {
      return SupportedPlatform.tiktok;
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return SupportedPlatform.twitter;
    }
    if (lower.contains('instagram.com')) {
      return SupportedPlatform.instagram;
    }
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return SupportedPlatform.facebook;
    }
    if (lower.contains('twitch.tv')) {
      return SupportedPlatform.twitch;
    }
    if (lower.contains('reddit.com') || lower.contains('v.redd.it')) {
      return SupportedPlatform.reddit;
    }
    if (lower.contains('bilibili.com')) {
      return SupportedPlatform.bilibili;
    }
    return SupportedPlatform.generic;
  }

  static String getDisplayName(SupportedPlatform platform) {
    switch (platform) {
      case SupportedPlatform.youtube:
        return 'YouTube';
      case SupportedPlatform.tiktok:
        return 'TikTok';
      case SupportedPlatform.twitter:
        return 'X / Twitter';
      case SupportedPlatform.instagram:
        return 'Instagram';
      case SupportedPlatform.facebook:
        return 'Facebook';
      case SupportedPlatform.twitch:
        return 'Twitch';
      case SupportedPlatform.reddit:
        return 'Reddit';
      case SupportedPlatform.bilibili:
        return 'Bilibili';
      case SupportedPlatform.generic:
        return 'Web Video';
    }
  }

  static String getBadgeColorHex(SupportedPlatform platform) {
    switch (platform) {
      case SupportedPlatform.youtube:
        return '#FF0000';
      case SupportedPlatform.tiktok:
        return '#00F2FE';
      case SupportedPlatform.twitter:
        return '#1DA1F2';
      case SupportedPlatform.instagram:
        return '#E1306C';
      case SupportedPlatform.facebook:
        return '#1877F2';
      case SupportedPlatform.twitch:
        return '#9146FF';
      case SupportedPlatform.reddit:
        return '#FF4500';
      case SupportedPlatform.bilibili:
        return '#00A1D6';
      case SupportedPlatform.generic:
        return '#A855F7';
    }
  }

  /// Parses multiple URLs pasted together (separated by newlines, spaces or commas).
  static List<String> extractUrls(String rawInput) {
    final regex = RegExp(r'https?://[^\s,;"<>]+');
    final matches = regex.allMatches(rawInput);
    final results = <String>[];

    for (final match in matches) {
      final url = match.group(0);
      if (url != null && url.isNotEmpty) {
        results.add(url.trim());
      }
    }

    return results;
  }
}
