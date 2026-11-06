import 'dart:convert';
import 'dart:io';
import '../auth/cookie_service.dart';
import '../services/settings_service.dart';
import 'format_preset.dart';
import 'platform_detector.dart';
import 'tool_resolver.dart';

/// Error de inspección con el detalle real de yt-dlp para mostrarlo al usuario.
class VideoInfoException implements Exception {
  final String message;
  const VideoInfoException(this.message);

  @override
  String toString() => message;
}

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
  ///
  /// Lanza [VideoInfoException] con el detalle real del fallo para que la UI
  /// pueda mostrarlo y copiarlo.
  Future<VideoInfoResult?> fetchVideoInfo(String url) async {
    final customYtDlp = SettingsService.instance.customYtDlpPathNotifier.value;
    final ytDlpExecutable = ToolResolver.resolveYtDlp(customYtDlp);

    final args = <String>[
      '--dump-single-json',
      '--no-playlist',
      '--no-warnings',
    ];

    args.addAll(ToolResolver.ffmpegArgs());

    // Cookies
    final autoCookies = SettingsService.instance.autoUseCookiesNotifier.value;
    final cookiesPath = CookieService.instance.cookiesFilePath;
    if (autoCookies && cookiesPath != null && await File(cookiesPath).exists()) {
      args.addAll(['--cookies', cookiesPath]);
    }

    // Node JS runtime
    final node = ToolResolver.nodeRuntime();
    if (node != null) {
      args.addAll(['--js-runtimes', 'node:$node']);
    }

    args.add(url);

    ProcessResult result;
    try {
      result = await Process.run(ytDlpExecutable, args);
    } on ProcessException catch (e) {
      throw VideoInfoException(
        'No se encontró yt-dlp.\n'
        'Ruta intentada: $ytDlpExecutable\n\n'
        'Coloca yt-dlp.exe en la carpeta bin junto a la aplicación, '
        'o instálalo en el PATH del sistema.\n\n'
        '${e.message}',
      );
    }

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      final detail = stderr.length > 1500
          ? stderr.substring(stderr.length - 1500)
          : stderr;
      throw VideoInfoException(
        'yt-dlp falló con código ${result.exitCode}.\n\n'
        '${detail.isEmpty ? 'Sin salida de error.' : detail}',
      );
    }

    try {
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
      throw VideoInfoException('No se pudo interpretar la respuesta de yt-dlp: $e');
    }
  }

  List<FormatPreset> _parseAvailableFormats(List<dynamic> rawFormats, SupportedPlatform platform) {
    final list = <FormatPreset>[];

    // Collect all video streams grouped by height and HDR status
    final formatGroups = <String, Map<String, dynamic>>{};

    for (final item in rawFormats) {
      if (item is! Map<String, dynamic>) continue;
      final ext = item['ext'] as String? ?? '';
      if (ext == 'mhtml') continue;

      final height = item['height'] as int?;
      final vcodec = item['vcodec'] as String? ?? 'none';
      if (height != null && height > 0 && vcodec != 'none') {
        final dr = (item['dynamic_range'] as String?)?.toUpperCase() ?? '';
        final note = (item['format_note'] as String?)?.toUpperCase() ?? '';
        final isHdr = (dr.isNotEmpty && dr != 'SDR') || note.contains('HDR');

        final groupKey = '${height}_${isHdr ? "hdr" : "sdr"}';
        final existing = formatGroups[groupKey];

        final currentFps = (item['fps'] as num?)?.toDouble() ?? 0.0;
        final existingFps = (existing?['fps'] as num?)?.toDouble() ?? 0.0;
        final currentTbr = (item['tbr'] as num?)?.toDouble() ?? 0.0;
        final existingTbr = (existing?['tbr'] as num?)?.toDouble() ?? 0.0;

        if (existing == null ||
            currentFps > existingFps ||
            (currentFps == existingFps && currentTbr > existingTbr)) {
          formatGroups[groupKey] = item;
        }
      }
    }

    // Sort entries from highest resolution to lowest, placing HDR alongside or above SDR
    final sortedKeys = formatGroups.keys.toList()
      ..sort((a, b) {
        final hA = (formatGroups[a]!['height'] as int?) ?? 0;
        final hB = (formatGroups[b]!['height'] as int?) ?? 0;
        if (hA != hB) return hB.compareTo(hA);
        final isHdrA = a.endsWith('_hdr') ? 1 : 0;
        final isHdrB = b.endsWith('_hdr') ? 1 : 0;
        return isHdrB.compareTo(isHdrA);
      });

    // Dynamic resolution options from highest to lowest
    for (final key in sortedKeys) {
      final f = formatGroups[key]!;
      final h = (f['height'] as int?) ?? 0;
      final formatId = f['format_id'] as String? ?? '$h';
      final fps = (f['fps'] as num?)?.toInt() ?? 0;
      final ext = f['ext'] as String? ?? 'mp4';
      final acodec = f['acodec'] as String? ?? 'none';
      final isHdr = key.endsWith('_hdr');

      String resLabel = '${h}p';
      final fpsSuffix = fps > 30 ? '$fps' : '';

      if (h >= 7500) {
        resLabel = fps > 30 ? '16K (${h}p$fpsSuffix)' : '16K (${h}p)';
      } else if (h >= 3800) {
        resLabel = fps > 30 ? '8K (${h}p$fpsSuffix)' : '8K (${h}p)';
      } else if (h >= 2100) {
        resLabel = fps > 30 ? '4K (${h}p$fpsSuffix)' : '4K (${h}p)';
      } else if (h >= 1400) {
        resLabel = fps > 30 ? '2K (${h}p$fpsSuffix)' : '2K (${h}p)';
      } else if (h >= 1000) {
        resLabel = fps > 30 ? 'Full HD (${h}p$fpsSuffix)' : 'Full HD (${h}p)';
      } else if (h >= 700) {
        resLabel = fps > 30 ? 'HD (${h}p$fpsSuffix)' : 'HD (${h}p)';
      } else if (h >= 450) {
        resLabel = '480p';
      } else if (h >= 300) {
        resLabel = '360p';
      } else {
        resLabel = '${h}p';
      }

      final hdrTag = isHdr ? ' • HDR' : '';
      final hasAudio = acodec != 'none';
      final ytArg = hasAudio
          ? '$formatId+bestaudio/$formatId/best'
          : '$formatId+bestaudio/best';

      list.add(
        FormatPreset(
          id: 'dyn_${formatId}_$h${isHdr ? "_hdr" : ""}',
          label: '$resLabel$hdrTag • ${ext.toUpperCase()}',
          description: '$h líneas${fps > 0 ? ' a $fps fps' : ''}${isHdr ? ' • HDR' : ''}',
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
        label: 'Máxima resolución disponible',
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
        label: 'Audio MP3 (320 kbps)',
        description: 'Extracción en formato MP3 universal',
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
        label: 'Audio M4A (Original)',
        description: 'Audio AAC original sin recompresión',
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
