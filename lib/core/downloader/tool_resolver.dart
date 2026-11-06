import 'dart:io';

/// Resuelve las rutas de yt-dlp, ffmpeg y node.
///
/// Prioridad: ruta configurada por el usuario, binarios empaquetados en
/// `<dir del ejecutable>/bin`, y por último el PATH del sistema.
class ToolResolver {
  ToolResolver._();

  /// Directorio `bin` junto al ejecutable, solo si contiene ffmpeg.
  static String? bundledBinDir() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final bin = Directory('$exeDir${Platform.pathSeparator}bin');
      if (!bin.existsSync()) return null;
      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final ffmpeg = File('${bin.path}${Platform.pathSeparator}$ffmpegName');
      return ffmpeg.existsSync() ? bin.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Ruta al yt-dlp empaquetado, si existe.
  static String? bundledYtDlp() {
    final bin = bundledBinDir();
    if (bin == null) return null;
    final name = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
    final candidate = File('$bin${Platform.pathSeparator}$name');
    return candidate.existsSync() ? candidate.path : null;
  }

  /// Ruta efectiva de yt-dlp para lanzar el proceso.
  static String resolveYtDlp(String? custom) {
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    return bundledYtDlp() ?? (Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp');
  }

  /// Argumentos para que yt-dlp use el ffmpeg empaquetado.
  static List<String> ffmpegArgs() {
    final bin = bundledBinDir();
    return bin == null ? const [] : ['--ffmpeg-location', bin];
  }

  /// Runtime de Node para los desafíos de YouTube, si está disponible.
  static String? nodeRuntime() {
    if (!Platform.isLinux) return null;
    const localNode = '/home/maple/.local/bin/node';
    return File(localNode).existsSync() ? localNode : null;
  }
}
