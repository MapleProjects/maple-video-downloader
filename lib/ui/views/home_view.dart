import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/downloader/download_engine.dart';
import '../../core/downloader/format_preset.dart';
import '../../core/downloader/platform_detector.dart';
import '../../core/downloader/video_info_service.dart';
import '../../core/models/download_task.dart';
import '../theme/app_theme.dart';
import '../widgets/download_card.dart';
import '../widgets/session_banner.dart';
import 'auth_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _urlController = TextEditingController();
  Timer? _debounceTimer;

  bool _isAnalyzing = false;
  String? _analyzeError;
  VideoInfoResult? _videoInfo;
  FormatPreset? _selectedFormat;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlInputChanged);
  }

  void _onUrlInputChanged() {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _debounceTimer?.cancel();
      if (_videoInfo != null || _analyzeError != null) {
        setState(() {
          _videoInfo = null;
          _selectedFormat = null;
          _analyzeError = null;
          _isAnalyzing = false;
        });
      }
      return;
    }

    // Auto-analyze when a complete URL is pasted or entered
    if (text.startsWith('http://') || text.startsWith('https://')) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _urlController.text.trim() == text && (_videoInfo == null || _videoInfo!.url != text)) {
          _analyzeCurrentUrl();
        }
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      _analyzeCurrentUrl();
    }
  }

  void _clearInput() {
    _debounceTimer?.cancel();
    _urlController.clear();
    setState(() {
      _videoInfo = null;
      _selectedFormat = null;
      _analyzeError = null;
      _isAnalyzing = false;
    });
  }

  Future<void> _analyzeCurrentUrl() async {
    final rawText = _urlController.text.trim();
    final urls = PlatformDetector.extractUrls(rawText);
    if (urls.isEmpty) {
      setState(() {
        _analyzeError = 'Ingresa un enlace de video válido (http/https).';
        _videoInfo = null;
      });
      return;
    }

    final targetUrl = urls.first;

    setState(() {
      _isAnalyzing = true;
      _analyzeError = null;
    });

    final info = await VideoInfoService.instance.fetchVideoInfo(targetUrl);

    if (!mounted) return;

    if (info != null) {
      setState(() {
        _isAnalyzing = false;
        _videoInfo = info;
        _selectedFormat = info.defaultFormat;
        _analyzeError = null;
      });
    } else {
      setState(() {
        _isAnalyzing = false;
        _analyzeError = 'No se pudieron obtener las calidades del video. Verifica tu conexión o el enlace.';
      });
    }
  }

  void _startDownload() {
    if (_videoInfo == null || _selectedFormat == null) return;

    DownloadEngine.instance.addSingleTask(
      url: _videoInfo!.url,
      format: _selectedFormat!,
      title: _videoInfo!.title,
      thumbnailUrl: _videoInfo!.thumbnailUrl,
    );

    final title = _videoInfo!.title;
    _clearInput();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descarga añadida a la cola: $title'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPlatformBadge(SupportedPlatform platform) {
    final hex = PlatformDetector.getBadgeColorHex(platform);
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        PlatformDetector.getDisplayName(platform),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.download_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Maple Video Downloader'),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // YouTube Cookie Auth Banner
          SliverToBoxAdapter(
            child: SessionBanner(
              onOpenAuth: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthView()),
                );
              },
            ),
          ),

          // URL Input & Dynamic Format Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Descargar Video',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onBackground,
                            ),
                          ),
                          if (_videoInfo != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Calidades Listas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ingresa el enlace de un video para obtener automáticamente sus calidades disponibles',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Single-line URL input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              maxLines: 1,
                              keyboardType: TextInputType.url,
                              onSubmitted: (_) => _analyzeCurrentUrl(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                                hintText: 'https://www.youtube.com/watch?v=... o pega un enlace',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_urlController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: _clearInput,
                                      )
                                    else
                                      IconButton(
                                        tooltip: 'Pegar del portapapeles',
                                        icon: const Icon(Icons.paste_rounded, size: 18),
                                        onPressed: _pasteFromClipboard,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isAnalyzing || _urlController.text.trim().isEmpty
                                ? null
                                : _analyzeCurrentUrl,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              backgroundColor: AppTheme.surfaceVariant,
                              foregroundColor: AppTheme.onBackground,
                            ),
                            icon: _isAnalyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.manage_search_rounded, size: 18),
                            label: Text(_isAnalyzing ? 'Analizando...' : 'Analizar'),
                          ),
                        ],
                      ),

                      // Analyzing indicator
                      if (_isAnalyzing) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Analizando enlace y obteniendo resoluciones disponibles...',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Error banner
                      if (_analyzeError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _analyzeError!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Video Info & Dynamic Quality Card
                      if (_videoInfo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A273F)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail + Title + Details
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_videoInfo!.thumbnailUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _videoInfo!.thumbnailUrl!,
                                        width: 96,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 96,
                                          height: 60,
                                          color: AppTheme.surfaceVariant,
                                          child: const Icon(Icons.video_library_rounded, size: 24),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 96,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.video_library_rounded, size: 24),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _videoInfo!.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onBackground,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _buildPlatformBadge(_videoInfo!.platform),
                                            if (_videoInfo!.durationFormatted.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.4),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.timer_outlined, size: 11, color: AppTheme.textMuted),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      _videoInfo!.durationFormatted,
                                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Color(0xFF2A273F)),
                              const SizedBox(height: 14),

                              // Dynamic Formats Dropdown + Download Button
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<FormatPreset>(
                                      key: ValueKey(_videoInfo?.url),
                                      initialValue: _selectedFormat,
                                      decoration: const InputDecoration(
                                        labelText: 'Resolución / Calidad Disponible',
                                        isDense: true,
                                      ),
                                      items: _videoInfo!.availableFormats.map((preset) {
                                        return DropdownMenuItem<FormatPreset>(
                                          value: preset,
                                          child: Text(
                                            preset.label,
                                            style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedFormat = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _startDownload,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    ),
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text('Descargar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Active Queue Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<List<DownloadTask>>(
                    valueListenable: DownloadEngine.instance.tasksNotifier,
                    builder: (context, tasks, _) {
                      return Text(
                        'Cola de Descargas (${tasks.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () => DownloadEngine.instance.clearFinishedTasks(),
                    child: const Text('Limpiar terminados', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Active Queue List
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadEngine.instance.tasksNotifier,
            builder: (context, tasks, _) {
              if (tasks.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: const [
                        Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF2A273F)),
                        SizedBox(height: 10),
                        Text(
                          'No hay descargas activas en la cola',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = tasks[index];
                    return DownloadCard(task: task);
                  },
                  childCount: tasks.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlInputChanged);
    _urlController.dispose();
    super.dispose();
  }
}
