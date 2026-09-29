enum FormatType {
  video,
  audio,
}

class FormatPreset {
  final String id;
  final String label;
  final String description;
  final FormatType type;
  final String ytDlpFormatArg;
  final List<String> extraArgs;

  const FormatPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    required this.ytDlpFormatArg,
    this.extraArgs = const [],
  });

  static const List<FormatPreset> presets = [
    FormatPreset(
      id: 'best_video',
      label: 'Máxima Calidad (Auto)',
      description: 'Mejor video y audio combinados (hasta 4K/8K)',
      type: FormatType.video,
      ytDlpFormatArg: 'bv*+ba/b',
      extraArgs: ['--merge-output-format', 'mp4'],
    ),
    FormatPreset(
      id: 'video_1080p',
      label: '1080p Full HD',
      description: 'Ideal para pantallas de escritorio y televisores',
      type: FormatType.video,
      ytDlpFormatArg: 'bv*[height<=1080]+ba/b[height<=1080]',
      extraArgs: ['--merge-output-format', 'mp4'],
    ),
    FormatPreset(
      id: 'video_720p',
      label: '720p HD',
      description: 'Equilibrio entre peso y resolución para móviles',
      type: FormatType.video,
      ytDlpFormatArg: 'bv*[height<=720]+ba/b[height<=720]',
      extraArgs: ['--merge-output-format', 'mp4'],
    ),
    FormatPreset(
      id: 'video_480p',
      label: '480p SD (Ligero)',
      description: 'Descargas rápidas y menor uso de almacenamiento',
      type: FormatType.video,
      ytDlpFormatArg: 'bv*[height<=480]+ba/b[height<=480]',
      extraArgs: ['--merge-output-format', 'mp4'],
    ),
    FormatPreset(
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
    FormatPreset(
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
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'type': type.name,
        'ytDlpFormatArg': ytDlpFormatArg,
        'extraArgs': extraArgs,
      };

  factory FormatPreset.fromJson(Map<String, dynamic> json) {
    return FormatPreset(
      id: json['id'] as String? ?? 'best_video',
      label: json['label'] as String? ?? 'Máxima Calidad (Auto)',
      description: json['description'] as String? ?? '',
      type: FormatType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FormatType.video,
      ),
      ytDlpFormatArg: json['ytDlpFormatArg'] as String? ?? 'bv*+ba/b',
      extraArgs: (json['extraArgs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['--merge-output-format', 'mp4'],
    );
  }

  static FormatPreset defaultPreset = presets.first;

  static FormatPreset getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => FormatPreset(
        id: id,
        label: 'Formato ($id)',
        description: 'Calidad personalizada detectada',
        type: FormatType.video,
        ytDlpFormatArg: id,
        extraArgs: const ['--merge-output-format', 'mp4'],
      ),
    );
  }
}
