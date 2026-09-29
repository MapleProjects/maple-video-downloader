import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../auth/cookie_service.dart';
import '../services/settings_service.dart';
import 'format_preset.dart';
import 'platform_detector.dart';

class VideoInfoResult {
  final String url;
  final String title;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? uploader;
  final SupportedPlatform platform;
  final List<FormatPreset> availableFormats;
  final FormatPreset defaultFormat;

  const VideoInfoResult({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.durationSeconds,
    this.uploader,
    required this.platform,
    required this.availableFormats,
    required this.defaultFormat,
  });

  String get durationFormatted {
    if (durationSeconds == null || durationSeconds! <= 0) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class VideoInfoService {
  VideoInfoService._();
  static final VideoInfoService instance = VideoInfoService._();

  /// Fetches video title, thumbnail, duration, and dynamic formats from yt-dlp.
  Future<VideoInfoResult?> fetchVideoInfo(String url) async {
    final customYtDlp = SettingsService.instance.customYtDlpPathNotifier.value;
    final ytDlpExecutable = customYtDlp ?? (Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp');

    final args = <String>[
      '--dump-single-json',
      '--no-playlist',
      '--no-warnings',
    ];

    // Cookies
    final autoCookies = SettingsService.instance.autoUseCookiesNotifier.value;
    final cookiesPath = CookieService.instance.cookiesFilePath;
    if (autoCookies && cookiesPath != null && await File(cookiesPath).exists()) {
      args.addAll(['--cookies', cookiesPath]);
    }

    // Node JS runtime
    const localNode = '/home/maple/.local/bin/node';
    if (await File(localNode).exists()) {
      args.addAll(['--js-runtimes', 'node:$localNode']);
    }

    // YouTube extractor args (unlocks HLS web_safari formats without 403)
    args.addAll(['--extractor-args', 'youtube:player_client=web_safari,web,default']);

    args.add(url);

    try {
      final result = await Process.run(ytDlpExecutable, args);
      if (result.exitCode != 0) {
        debugPrint('[VideoInfoService] Failed to extract info: ${result.stderr}');
        return null;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final title = json['title'] as String? ?? 'Video';
      final thumbnail = json['thumbnail'] as String?;
      final duration = json['duration'] as int?;
      final uploader = json['uploader'] as String?;
      final platform = PlatformDetector.detect(url);

      final rawFormats = (json['formats'] as List<dynamic>?) ?? [];
      final parsedFormats = _parseAvailableFormats(rawFormats, platform);

      return VideoInfoResult(
        url: url,
        title: title,
        thumbnailUrl: thumbnail,
        durationSeconds: duration,
        uploader: uploader,
        platform: platform,
        availableFormats: parsedFormats,
        defaultFormat: parsedFormats.isNotEmpty ? parsedFormats.first : FormatPreset.defaultPreset,
      );
    } catch (e) {
      debugPrint('[VideoInfoService] Error parsing video info: $e');
      return null;
    }
  }

  List<FormatPreset> _parseAvailableFormats(List<dynamic> rawFormats, SupportedPlatform platform) {
    final list = <FormatPreset>[];

    // 1. Collect all video heights available
    final videoHeights = <int>{};
    final formatByHeight = <int, Map<String, dynamic>>{};

    for (final item in rawFormats) {
      if (item is! Map<String, dynamic>) continue;
      final ext = item['ext'] as String? ?? '';
      if (ext == 'mhtml') continue;

      final height = item['height'] as int?;
      final vcodec = item['vcodec'] as String? ?? 'none';
      if (height != null && height > 0 && vcodec != 'none') {
        videoHeights.add(height);
        final existing = formatByHeight[height];
        final currentFps = (item['fps'] as num?)?.toDouble() ?? 0.0;
        final existingFps = (existing?['fps'] as num?)?.toDouble() ?? 0.0;
        if (existing == null || currentFps > existingFps) {
          formatByHeight[height] = item;
        }
      }
    }

    final sortedHeights = videoHeights.toList()..sort((a, b) => b.compareTo(a));

    // Dynamic resolution options from highest to lowest
    for (final h in sortedHeights) {
      final f = formatByHeight[h]!;
      final formatId = f['format_id'] as String? ?? '$h';
      final fps = (f['fps'] as num?)?.toInt() ?? 0;
      final ext = f['ext'] as String? ?? 'mp4';
      final acodec = f['acodec'] as String? ?? 'none';

      String resLabel = '${h}p';
      if (h >= 2160) {
        resLabel = '2160p (4K UHD)';
      } else if (h >= 1440) {
        resLabel = '1440p (2K QHD)';
      } else if (h >= 1080) {
        resLabel = fps > 30 ? '1080p$fps (Full HD)' : '1080p (Full HD)';
      } else if (h >= 720) {
        resLabel = fps > 30 ? '720p$fps (HD)' : '720p (HD)';
      } else if (h >= 480) {
        resLabel = '480p (SD)';
      } else if (h >= 360) {
        resLabel = '360p (Ligero)';
      }

      final hasAudio = acodec != 'none';
      final ytArg = hasAudio
          ? '$formatId+bestaudio/$formatId/best'
          : '$formatId+bestaudio/best';

      list.add(
        FormatPreset(
          id: 'dyn_${formatId}_$h',
          label: '$resLabel - ${ext.toUpperCase()}',
          description: 'Resolución: $h líneas${fps > 0 ? ' • $fps fps' : ''}',
          type: FormatType.video,
          ytDlpFormatArg: ytArg,
          extraArgs: const ['--merge-output-format', 'mp4'],
        ),
      );
    }

    // Add Max Quality (Auto)
    list.add(
      const FormatPreset(
        id: 'best_video',
        label: 'Máxima Calidad (Auto)',
        description: 'Mejor video y audio combinados',
        type: FormatType.video,
        ytDlpFormatArg: 'bv*+ba/b',
        extraArgs: ['--merge-output-format', 'mp4'],
      ),
    );

    // Audio options
    list.add(
      const FormatPreset(
        id: 'audio_mp3',
        label: 'Solo Audio (MP3 320k)',
        description: 'Extracción de audio en alta fidelidad',
        type: FormatType.audio,
        ytDlpFormatArg: 'ba/b',
        extraArgs: [
          '-x',
          '--audio-format',
          'mp3',
          '--audio-quality',
          '0',
        ],
      ),
    );

    list.add(
      const FormatPreset(
        id: 'audio_m4a',
        label: 'Solo Audio (M4A / AAC)',
        description: 'Extracción sin pérdida de codificación original',
        type: FormatType.audio,
        ytDlpFormatArg: 'ba[ext=m4a]/ba/b',
        extraArgs: [
          '-x',
          '--audio-format',
          'm4a',
        ],
      ),
    );

    return list;
  }
}
