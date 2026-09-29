import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _prefDownloadDir = 'maple_download_directory';
  static const String _prefMaxConcurrent = 'maple_max_concurrent_downloads';
  static const String _prefAutoUseCookies = 'maple_auto_use_cookies';
  static const String _prefDefaultFormat = 'maple_default_format';
  static const String _prefCustomYtDlp = 'maple_custom_ytdlp_path';

  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  SettingsService._();

  final ValueNotifier<String> downloadDirectoryNotifier = ValueNotifier<String>('');
  final ValueNotifier<int> maxConcurrentNotifier = ValueNotifier<int>(3);
  final ValueNotifier<bool> autoUseCookiesNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String> defaultFormatNotifier = ValueNotifier<String>('best_video');
  final ValueNotifier<String?> customYtDlpPathNotifier = ValueNotifier<String?>(null);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedDir = prefs.getString(_prefDownloadDir);
    if (savedDir == null || savedDir.isEmpty) {
      savedDir = await _getDefaultDownloadDirectory();
    }
    downloadDirectoryNotifier.value = savedDir;

    maxConcurrentNotifier.value = prefs.getInt(_prefMaxConcurrent) ?? 3;
    autoUseCookiesNotifier.value = prefs.getBool(_prefAutoUseCookies) ?? true;
    defaultFormatNotifier.value = prefs.getString(_prefDefaultFormat) ?? 'best_video';
    customYtDlpPathNotifier.value = prefs.getString(_prefCustomYtDlp);

    final dir = Directory(downloadDirectoryNotifier.value);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<String> _getDefaultDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Standard Android Download folder
        final dir = Directory('/storage/emulated/0/Download/MapleDownloader');
        return dir.path;
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return '${downloadsDir.path}/MapleDownloader';
      }

      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        return '$home/Downloads/MapleDownloader';
      }

      final docDir = await getApplicationDocumentsDirectory();
      return '${docDir.path}/Downloads';
    } catch (_) {
      return '/tmp/MapleDownloader';
    }
  }

  Future<void> setDownloadDirectory(String path) async {
    downloadDirectoryNotifier.value = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDownloadDir, path);

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> setMaxConcurrent(int count) async {
    maxConcurrentNotifier.value = count.clamp(1, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefMaxConcurrent, maxConcurrentNotifier.value);
  }

  Future<void> setAutoUseCookies(bool value) async {
    autoUseCookiesNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoUseCookies, value);
  }

  Future<void> setDefaultFormat(String formatId) async {
    defaultFormatNotifier.value = formatId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDefaultFormat, formatId);
  }

  Future<void> setCustomYtDlpPath(String? path) async {
    customYtDlpPathNotifier.value = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_prefCustomYtDlp, path);
    } else {
      await prefs.remove(_prefCustomYtDlp);
    }
  }
}
