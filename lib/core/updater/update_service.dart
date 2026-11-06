import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_installer.dart';
import 'update_models.dart';

/// Comprueba, descarga y aplica actualizaciones desde las releases de GitHub.
///
/// Flujo: consulta `releases/latest`, compara versiones, descarga el paquete
/// de la plataforma, verifica su SHA-256, lo descomprime en un directorio de
/// staging y delega la copia final a un script que corre tras cerrar la app.
class UpdateService {
  static const String repository = 'MapleProjects/maple-video-downloader';
  static const String _apiLatest =
      'https://api.github.com/repos/$repository/releases/latest';
  static const String _checksumsName = 'SHA256SUMS.txt';

  static const String _prefAutoCheck = 'maple_auto_check_updates';
  static const String _prefSkippedVersion = 'maple_skipped_update_version';

  static UpdateService? _instance;
  static UpdateService get instance => _instance ??= UpdateService._();

  UpdateService._();

  final ValueNotifier<UpdateState> state =
      ValueNotifier<UpdateState>(const UpdateState.idle());
  final ValueNotifier<bool> autoCheckNotifier = ValueNotifier<bool>(true);

  String currentVersion = '0.0.0';
  String currentBuild = '0';
  String? _skippedVersion;
  bool _initialized = false;

  /// Directorio de trabajo alternativo, usado por las pruebas para no
  /// depender de los canales de plataforma de path_provider.
  @visibleForTesting
  Directory? workDirOverride;

  bool get isSupportedPlatform => Platform.isWindows || Platform.isLinux;

  /// Sufijo del asset publicado por el workflow de release.
  String? get _assetSuffix {
    if (Platform.isWindows) return 'windows-x64.zip';
    if (Platform.isLinux) return 'linux-x64.tar.gz';
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      currentBuild = info.buildNumber;
    } catch (e) {
      debugPrint('[UpdateService] No se pudo leer la versión: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    autoCheckNotifier.value = prefs.getBool(_prefAutoCheck) ?? true;
    _skippedVersion = prefs.getString(_prefSkippedVersion);
  }

  Future<void> setAutoCheck(bool value) async {
    autoCheckNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoCheck, value);
  }

  Future<void> skipVersion(String version) async {
    _skippedVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkippedVersion, version);
  }

  /// Consulta la última release. Devuelve la release si hay una versión nueva.
  Future<ReleaseInfo?> checkForUpdates({bool silent = false}) async {
    if (!isSupportedPlatform) {
      state.value = state.value.copyWith(
        phase: UpdatePhase.upToDate,
        message: 'Las actualizaciones automáticas están disponibles en '
            'Windows y Linux. En Android descarga el APK desde GitHub.',
      );
      return null;
    }

    if (state.value.isBusy) return null;

    state.value = state.value.copyWith(
      phase: UpdatePhase.checking,
      message: 'Buscando actualizaciones...',
      progress: 0,
      clearError: true,
    );

    try {
      final response = await http.get(
        Uri.parse(_apiLatest),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'MapleVideoDownloader/$currentVersion',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        state.value = state.value.copyWith(
          phase: UpdatePhase.upToDate,
          message: 'Todavía no hay releases publicadas.',
        );
        return null;
      }

      if (response.statusCode == 403) {
        throw const UpdateException(
          'GitHub limitó las consultas desde esta red. Intenta más tarde.',
        );
      }

      if (response.statusCode != 200) {
        throw UpdateException(
          'GitHub respondió con código ${response.statusCode}.',
        );
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const UpdateException('Respuesta inesperada de GitHub.');
      }

      final release = ReleaseInfo.fromJson(json);
      final comparison = compareVersions(release.version, currentVersion);

      if (silent && _skippedVersion == release.version) {
        state.value = state.value.copyWith(
          phase: UpdatePhase.upToDate,
          message: 'Versión ${release.version} omitida.',
          clearRelease: true,
        );
        return null;
      }

      if (comparison <= 0) {
        state.value = state.value.copyWith(
          phase: UpdatePhase.upToDate,
          message: 'Estás en la última versión ($currentVersion).',
          clearRelease: true,
        );
        return null;
      }

      final managed = await UpdateInstaller.isManagedByPackageManager();
      final writable = await UpdateInstaller.isInstallDirectoryWritable();

      state.value = state.value.copyWith(
        phase: UpdatePhase.available,
        message: managed
            ? 'Versión ${release.version} disponible. Instalación gestionada '
                'por pacman: actualiza con paru -Syu.'
            : writable
                ? 'Versión ${release.version} disponible.'
                : 'Versión ${release.version} disponible, pero el directorio '
                    'de instalación no admite escritura.',
        release: release,
        managedByPackageManager: managed,
        clearError: true,
      );
      return release;
    } on UpdateException catch (e) {
      _fail(e.message, silent: silent);
      return null;
    } on TimeoutException {
      _fail('La consulta a GitHub agotó el tiempo de espera.', silent: silent);
      return null;
    } catch (e) {
      _fail('No se pudo comprobar la actualización: $e', silent: silent);
      return null;
    }
  }

  void _fail(String message, {required bool silent}) {
    if (silent) {
      state.value = state.value.copyWith(
        phase: UpdatePhase.idle,
        message: '',
        clearError: true,
      );
      return;
    }
    state.value = state.value.copyWith(
      phase: UpdatePhase.error,
      message: message,
      error: message,
    );
  }

  /// Descarga el paquete de la release, verifica el hash y lo descomprime.
  Future<void> downloadAndStage() async {
    final release = state.value.release;
    if (release == null) {
      throw const UpdateException('No hay una release seleccionada.');
    }

    final suffix = _assetSuffix;
    if (suffix == null) {
      throw const UpdateException(
        'Esta plataforma no admite actualizaciones automáticas.',
      );
    }

    final asset = release.assetEndingWith(suffix);
    if (asset == null) {
      throw UpdateException(
        'La release ${release.version} no incluye el paquete para esta '
        'plataforma ($suffix).',
      );
    }

    final supportDir =
        workDirOverride ?? await getApplicationSupportDirectory();
    final workDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}updates'
      '${Platform.pathSeparator}${release.version}',
    );
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);

    final archiveFile = File(
      '${workDir.path}${Platform.pathSeparator}${asset.name}',
    );

    state.value = state.value.copyWith(
      phase: UpdatePhase.downloading,
      message: 'Descargando ${asset.name}...',
      progress: 0,
      clearError: true,
    );

    await _download(asset.downloadUrl, archiveFile, (received, total) {
      final pct = total > 0 ? received / total : 0.0;
      state.value = state.value.copyWith(
        phase: UpdatePhase.downloading,
        message: 'Descargando ${_formatBytes(received)}'
            '${total > 0 ? ' de ${_formatBytes(total)}' : ''}',
        progress: pct.clamp(0.0, 1.0),
      );
    });

    state.value = state.value.copyWith(
      phase: UpdatePhase.verifying,
      message: 'Verificando integridad...',
      progress: 0,
    );

    final expected = await _expectedChecksum(release, asset.name);
    if (expected != null) {
      final actual = await _sha256OfFile(archiveFile);
      if (actual.toLowerCase() != expected.toLowerCase()) {
        await archiveFile.delete();
        throw UpdateException(
          'El hash del paquete no coincide.\n'
          'Esperado: $expected\nObtenido: $actual',
        );
      }
    } else {
      debugPrint('[UpdateService] Release sin SHA256SUMS.txt, se omite la verificación.');
    }

    state.value = state.value.copyWith(
      phase: UpdatePhase.extracting,
      message: 'Descomprimiendo...',
      progress: 0,
    );

    final extractDir = Directory(
      '${workDir.path}${Platform.pathSeparator}stage',
    );
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    await extractFileToDisk(archiveFile.path, extractDir.path);

    final root = await _resolveStageRoot(extractDir);
    await _ensureExecutable(root);

    state.value = state.value.copyWith(
      phase: UpdatePhase.ready,
      message: 'Versión ${release.version} lista para instalar.',
      progress: 1,
      stagedPath: root.path,
    );
  }

  /// Aplica la actualización preparada y cierra la aplicación.
  Future<void> installAndRestart() async {
    final stagedPath = state.value.stagedPath;
    if (stagedPath == null) {
      throw const UpdateException('No hay una actualización preparada.');
    }

    if (state.value.managedByPackageManager) {
      throw const UpdateException(
        'Esta instalación la gestiona pacman. Usa paru -Syu.',
      );
    }

    final target = UpdateInstaller.installDirectory();
    if (!await UpdateInstaller.isInstallDirectoryWritable()) {
      throw UpdateException(
        'Sin permisos para escribir en ${target.path}.\n'
        'Descarga el paquete manualmente desde la página de la release.',
      );
    }

    state.value = state.value.copyWith(
      phase: UpdatePhase.installing,
      message: 'Aplicando actualización y reiniciando...',
      progress: 1,
    );

    await UpdateInstaller.applyAndRestart(
      stage: Directory(stagedPath),
      target: target,
      executablePath: Platform.resolvedExecutable,
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }

  Future<void> openReleasePage() async {
    final url = state.value.release?.pageUrl;
    final uri = Uri.parse(
      (url == null || url.isEmpty)
          ? 'https://github.com/$repository/releases'
          : url,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _download(
    String url,
    File destination,
    void Function(int received, int total) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'MapleVideoDownloader/$currentVersion';
      final response = await client.send(request).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        throw UpdateException(
          'La descarga falló con código ${response.statusCode}.',
        );
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = destination.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<String?> _expectedChecksum(ReleaseInfo release, String assetName) async {
    final checksums = release.assetNamed(_checksumsName);
    if (checksums == null) return null;

    try {
      final response = await http.get(
        Uri.parse(checksums.downloadUrl),
        headers: {'User-Agent': 'MapleVideoDownloader/$currentVersion'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;

      for (final line in const LineSplitter().convert(response.body)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 2) continue;
        final name = parts.last.replaceFirst('*', '');
        if (name == assetName) return parts.first;
      }
    } catch (e) {
      debugPrint('[UpdateService] No se pudo leer SHA256SUMS.txt: $e');
    }
    return null;
  }

  Future<String> _sha256OfFile(File file) async {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return sink.value?.toString() ?? '';
  }

  /// Si el paquete trae una carpeta raíz única, se usa como origen de copia.
  Future<Directory> _resolveStageRoot(Directory extractDir) async {
    final entries = await extractDir.list().toList();
    if (entries.length == 1 && entries.first is Directory) {
      return entries.first as Directory;
    }
    return extractDir;
  }

  Future<void> _ensureExecutable(Directory root) async {
    if (Platform.isWindows) return;
    try {
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && !entity.path.endsWith('.so')) {
          final stat = await entity.stat();
          if (stat.mode & 0x49 != 0) {
            await Process.run('chmod', ['+x', entity.path]);
          }
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] No se pudieron ajustar permisos: $e');
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
