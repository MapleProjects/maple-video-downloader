import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/cookie_service.dart';
import '../models/download_task.dart';
import '../services/settings_service.dart';
import 'format_preset.dart';
import 'platform_detector.dart';

class DownloadEngine {
  static const String _prefHistoryKey = 'maple_download_history_json';

  static DownloadEngine? _instance;
  static DownloadEngine get instance => _instance ??= DownloadEngine._();

  DownloadEngine._();

  final ValueNotifier<List<DownloadTask>> tasksNotifier = ValueNotifier<List<DownloadTask>>([]);
  final ValueNotifier<List<DownloadTask>> historyNotifier = ValueNotifier<List<DownloadTask>>([]);
  final ValueNotifier<int> activeDownloadsCountNotifier = ValueNotifier<int>(0);

  bool _isQueueProcessing = false;

  Future<void> init() async {
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefHistoryKey) ?? [];
      final loaded = <DownloadTask>[];

      for (final item in list) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          loaded.add(DownloadTask.fromJson(map));
        } catch (_) {}
      }

      historyNotifier.value = loaded;
    } catch (e) {
      debugPrint('[DownloadEngine] Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = historyNotifier.value
          .take(150)
          .map((task) => jsonEncode(task.toJson()))
          .toList();
      await prefs.setStringList(_prefHistoryKey, list);
    } catch (e) {
      debugPrint('[DownloadEngine] Error saving history: $e');
    }
  }

  /// Adds multiple URLs to the download queue.
  void addUrls(List<String> urls, {FormatPreset? format}) {
    final selectedFormat = format ??
        FormatPreset.getById(SettingsService.instance.defaultFormatNotifier.value);

    final currentTasks = List<DownloadTask>.from(tasksNotifier.value);

    for (final url in urls) {
      final platform = PlatformDetector.detect(url);
      final id =
          '${DateTime.now().microsecondsSinceEpoch}_${currentTasks.length + 1}';

      final task = DownloadTask(
        id: id,
        url: url,
        platform: platform,
        format: selectedFormat,
        title: '${PlatformDetector.getDisplayName(platform)} Video',
      );

      currentTasks.add(task);
    }

    tasksNotifier.value = currentTasks;
    _processQueue();
  }

  /// Adds a single task with pre-inspected title, thumbnail, and format.
  void addSingleTask({
    required String url,
    required FormatPreset format,
    String? title,
    String? thumbnailUrl,
  }) {
    final platform = PlatformDetector.detect(url);
    final currentTasks = List<DownloadTask>.from(tasksNotifier.value);
    final id = '${DateTime.now().microsecondsSinceEpoch}_${currentTasks.length + 1}';

    final task = DownloadTask(
      id: id,
      url: url,
      platform: platform,
      format: format,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : '${PlatformDetector.getDisplayName(platform)} Video',
      thumbnailUrl: thumbnailUrl,
    );

    currentTasks.add(task);
    tasksNotifier.value = currentTasks;
    _processQueue();
  }

  /// Concurrency-controlled queue scheduler.
  void _processQueue() {
    if (_isQueueProcessing) return;
    _isQueueProcessing = true;

    final currentTasks = tasksNotifier.value;
    final maxConcurrent = SettingsService.instance.maxConcurrentNotifier.value;

    final activeCount = currentTasks.where((t) => t.isActive).length;
    activeDownloadsCountNotifier.value = activeCount;

    if (activeCount < maxConcurrent) {
      final availableSlots = maxConcurrent - activeCount;
      final queuedTasks = currentTasks
          .where((t) => t.status == TaskStatus.queued)
          .take(availableSlots)
          .toList();

      for (final task in queuedTasks) {
        _startTask(task);
      }
    }

    _isQueueProcessing = false;
  }

  /// Starts execution of a single download task via yt-dlp.
  Future<void> _startTask(DownloadTask task) async {
    task.status = TaskStatus.analyzing;
    task.errorMessage = null;
    _notifyTaskUpdate();

    final downloadDir = SettingsService.instance.downloadDirectoryNotifier.value;
    final customYtDlp = SettingsService.instance.customYtDlpPathNotifier.value;
    final ytDlpExecutable = customYtDlp ?? (Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp');

    // Build argument list
    final args = <String>[
      '--newline',
      '--no-colors',
      '--no-playlist',
      '--progress-template',
      'download:MAPLE_PROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._total_bytes_str)s',
      '-f',
      task.format.ytDlpFormatArg,
      ...task.format.extraArgs,
      '-P',
      downloadDir,
      '-o',
      '%(title)s [%(id)s].%(ext)s',
    ];

    // Inject cookies if enabled and available
    final autoCookies = SettingsService.instance.autoUseCookiesNotifier.value;
    final cookiesPath = CookieService.instance.cookiesFilePath;
    if (autoCookies && cookiesPath != null && await File(cookiesPath).exists()) {
      args.addAll(['--cookies', cookiesPath]);
    }

    // Inject node JS runtime if available in ~/.local/bin/node
    const localNode = '/home/maple/.local/bin/node';
    if (await File(localNode).exists()) {
      args.addAll(['--js-runtimes', 'node:$localNode']);
    }

    args.add(task.url);

    try {
      final process = await Process.start(ytDlpExecutable, args);
      task.process = process;
      task.status = TaskStatus.downloading;
      _notifyTaskUpdate();

      // Listen to stdout for title, progress, and file completion
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleProcessOutput(task, line);
      });

      // Listen to stderr for errors or warnings
      final errorLines = <String>[];
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('WARNING:')) {
          final clean = trimmed.startsWith('ERROR:') ? trimmed.substring(6).trim() : trimmed;
          errorLines.add(clean);
          task.errorMessage = errorLines.join('\n');
        }
      });

      final exitCode = await process.exitCode;
      task.process = null;

      if (task.status == TaskStatus.cancelled) {
        _notifyTaskUpdate();
        _processQueue();
        return;
      }

      if (exitCode == 0) {
        task.status = TaskStatus.completed;
        task.progress = 100.0;
        task.speed = 'Completado';
        task.eta = '00:00';

        // Move to history
        _moveToHistory(task);
      } else {
        task.status = TaskStatus.error;
        task.errorMessage ??= 'Error en yt-dlp (código $exitCode)';
      }
    } catch (e) {
      task.status = TaskStatus.error;
      task.errorMessage = 'No se pudo iniciar el proceso de descarga: $e';
    } finally {
      _notifyTaskUpdate();
      _processQueue();
    }
  }

  void _handleProcessOutput(DownloadTask task, String line) {
    // Primary progress parser for MAPLE_PROGRESS template
    if (line.contains('MAPLE_PROGRESS:')) {
      final payload = line.substring(line.indexOf('MAPLE_PROGRESS:') + 'MAPLE_PROGRESS:'.length).trim();
      final parts = payload.split('|');
      if (parts.isNotEmpty) {
        final pctStr = parts[0].replaceAll('%', '').trim();
        final parsedPct = double.tryParse(pctStr);
        if (parsedPct != null) {
          task.progress = parsedPct;
        }
      }
      if (parts.length > 1 && parts[1].trim().isNotEmpty && parts[1].trim() != 'NA') {
        task.speed = parts[1].trim();
      }
      if (parts.length > 2 && parts[2].trim().isNotEmpty && parts[2].trim() != 'NA') {
        task.eta = parts[2].trim();
      }
      if (parts.length > 3 && parts[3].trim().isNotEmpty && parts[3].trim() != 'NA') {
        task.totalSize = parts[3].trim();
      }
      _notifyTaskUpdate();
      return;
    }

    // Fallback progress parser for standard yt-dlp output
    if (line.contains('[download]') && line.contains('%')) {
      final regExp = RegExp(r'\[download\]\s+([\d\.]+)%\s+of\s+([^\s]+)\s+at\s+([^\s]+)\s+ETA\s+([^\s]+)');
      final match = regExp.firstMatch(line);
      if (match != null) {
        final pct = double.tryParse(match.group(1) ?? '');
        if (pct != null) {
          task.progress = pct;
        }
        final totalSize = match.group(2);
        if (totalSize != null && totalSize != '~') {
          task.totalSize = totalSize;
        }
        task.speed = match.group(3) ?? task.speed;
        task.eta = match.group(4) ?? task.eta;
        _notifyTaskUpdate();
        return;
      }
    }

    // Title / Destination parser
    if (line.contains('[download] Destination:')) {
      final dest = line.replaceAll('[download] Destination:', '').trim();
      task.outputPath = dest;
      final file = File(dest);
      task.title = file.uri.pathSegments.last;
      _notifyTaskUpdate();
      return;
    }

    if (line.contains('[Merger] Merging formats into')) {
      task.status = TaskStatus.processing;
      final dest = line.replaceAll('[Merger] Merging formats into', '').replaceAll('"', '').trim();
      task.outputPath = dest;
      _notifyTaskUpdate();
      return;
    }

    if (line.contains('[ExtractAudio] Destination:')) {
      task.status = TaskStatus.processing;
      final dest = line.replaceAll('[ExtractAudio] Destination:', '').trim();
      task.outputPath = dest;
      _notifyTaskUpdate();
      return;
    }
  }

  void cancelTask(DownloadTask task) {
    if (task.process != null) {
      task.status = TaskStatus.cancelled;
      task.process!.kill(ProcessSignal.sigterm);
      task.process = null;
    } else {
      task.status = TaskStatus.cancelled;
    }
    _notifyTaskUpdate();
    _processQueue();
  }

  void retryTask(DownloadTask task) {
    task.status = TaskStatus.queued;
    task.progress = 0.0;
    task.errorMessage = null;
    _notifyTaskUpdate();
    _processQueue();
  }

  void removeTask(DownloadTask task) {
    if (task.isActive) {
      cancelTask(task);
    }
    final currentTasks = List<DownloadTask>.from(tasksNotifier.value);
    currentTasks.removeWhere((t) => t.id == task.id);
    tasksNotifier.value = currentTasks;
    _processQueue();
  }

  void clearFinishedTasks() {
    final currentTasks = List<DownloadTask>.from(tasksNotifier.value);
    currentTasks.removeWhere((t) => t.isFinished);
    tasksNotifier.value = currentTasks;
  }

  void _moveToHistory(DownloadTask task) {
    final currentHistory = List<DownloadTask>.from(historyNotifier.value);
    currentHistory.insert(0, task);
    historyNotifier.value = currentHistory;
    _saveHistory();
  }

  void clearHistory() {
    historyNotifier.value = [];
    _saveHistory();
  }

  void _notifyTaskUpdate() {
    tasksNotifier.value = List<DownloadTask>.from(tasksNotifier.value);
    activeDownloadsCountNotifier.value =
        tasksNotifier.value.where((t) => t.isActive).length;
  }
}
