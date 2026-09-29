import 'dart:io';
import '../downloader/format_preset.dart';
import '../downloader/platform_detector.dart';

enum TaskStatus {
  queued,
  analyzing,
  downloading,
  processing,
  completed,
  error,
  cancelled,
}

class DownloadTask {
  final String id;
  final String url;
  final SupportedPlatform platform;
  final FormatPreset format;
  final DateTime createdAt;

  String title;
  String? thumbnailUrl;
  TaskStatus status;
  double progress; // 0.0 to 100.0
  String speed;
  String eta;
  String totalSize;
  String? outputPath;
  String? errorMessage;
  Process? process;

  DownloadTask({
    required this.id,
    required this.url,
    required this.platform,
    required this.format,
    DateTime? createdAt,
    this.title = '',
    this.thumbnailUrl,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    this.speed = '--',
    this.eta = '--',
    this.totalSize = '--',
    this.outputPath,
    this.errorMessage,
    this.process,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isActive =>
      status == TaskStatus.analyzing ||
      status == TaskStatus.downloading ||
      status == TaskStatus.processing;

  bool get isFinished =>
      status == TaskStatus.completed ||
      status == TaskStatus.error ||
      status == TaskStatus.cancelled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'platform': platform.name,
        'format': format.toJson(),
        'formatId': format.id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'status': status.name,
        'progress': progress,
        'speed': speed,
        'eta': eta,
        'totalSize': totalSize,
        'outputPath': outputPath,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String,
        url: json['url'] as String,
        platform: SupportedPlatform.values.firstWhere(
          (p) => p.name == json['platform'],
          orElse: () => SupportedPlatform.generic,
        ),
        format: json['format'] != null
            ? FormatPreset.fromJson(json['format'] as Map<String, dynamic>)
            : FormatPreset.getById(json['formatId'] as String? ?? 'best_video'),
        title: json['title'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        status: TaskStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TaskStatus.completed,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 100.0,
        speed: json['speed'] as String? ?? '--',
        eta: json['eta'] as String? ?? '--',
        totalSize: json['totalSize'] as String? ?? '--',
        outputPath: json['outputPath'] as String?,
        errorMessage: json['errorMessage'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
