/// Modelos de datos del sistema de actualizaciones.
library;

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: (json['name'] as String?) ?? '',
      downloadUrl: (json['browser_download_url'] as String?) ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReleaseInfo {
  final String tagName;
  final String version;
  final String title;
  final String notes;
  final String pageUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.notes,
    required this.pageUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?) ?? '';
    final assets = <ReleaseAsset>[];
    for (final raw in (json['assets'] as List<dynamic>? ?? const [])) {
      if (raw is Map<String, dynamic>) {
        assets.add(ReleaseAsset.fromJson(raw));
      }
    }
    return ReleaseInfo(
      tagName: tag,
      version: normalizeVersion(tag),
      title: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : tag,
      notes: (json['body'] as String?) ?? '',
      pageUrl: (json['html_url'] as String?) ?? '',
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
      assets: assets,
    );
  }

  ReleaseAsset? assetEndingWith(String suffix) {
    for (final asset in assets) {
      if (asset.name.toLowerCase().endsWith(suffix.toLowerCase())) {
        return asset;
      }
    }
    return null;
  }

  ReleaseAsset? assetNamed(String name) {
    for (final asset in assets) {
      if (asset.name.toLowerCase() == name.toLowerCase()) return asset;
    }
    return null;
  }
}

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  extracting,
  ready,
  installing,
  error,
}

class UpdateState {
  final UpdatePhase phase;
  final String message;
  final double progress;
  final ReleaseInfo? release;
  final String? error;
  final String? stagedPath;
  final bool managedByPackageManager;

  const UpdateState({
    required this.phase,
    this.message = '',
    this.progress = 0,
    this.release,
    this.error,
    this.stagedPath,
    this.managedByPackageManager = false,
  });

  const UpdateState.idle()
      : phase = UpdatePhase.idle,
        message = '',
        progress = 0,
        release = null,
        error = null,
        stagedPath = null,
        managedByPackageManager = false;

  bool get isBusy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.extracting ||
      phase == UpdatePhase.installing;

  UpdateState copyWith({
    UpdatePhase? phase,
    String? message,
    double? progress,
    ReleaseInfo? release,
    String? error,
    String? stagedPath,
    bool? managedByPackageManager,
    bool clearError = false,
    bool clearRelease = false,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      release: clearRelease ? null : (release ?? this.release),
      error: clearError ? null : (error ?? this.error),
      stagedPath: stagedPath ?? this.stagedPath,
      managedByPackageManager:
          managedByPackageManager ?? this.managedByPackageManager,
    );
  }
}

/// Normaliza un tag de release a una versión comparable: "v1.2.3" -> "1.2.3".
String normalizeVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  final plus = value.indexOf('+');
  if (plus >= 0) value = value.substring(0, plus);
  final dash = value.indexOf('-');
  if (dash >= 0) value = value.substring(0, dash);
  return value;
}

/// Compara dos versiones semánticas. Devuelve >0 si [a] es mayor que [b].
int compareVersions(String a, String b) {
  final left = _parts(a);
  final right = _parts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

List<int> _parts(String version) {
  final clean = normalizeVersion(version);
  final out = <int>[];
  for (final chunk in clean.split('.')) {
    final digits = RegExp(r'^\d+').firstMatch(chunk)?.group(0);
    out.add(int.tryParse(digits ?? '') ?? 0);
  }
  return out;
}
