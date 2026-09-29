import 'package:flutter/material.dart';
import '../../core/downloader/download_engine.dart';
import '../../core/downloader/format_preset.dart';
import '../../core/downloader/platform_detector.dart';
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
  FormatPreset _selectedFormat = FormatPreset.defaultPreset;
  List<String> _detectedUrls = [];

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlInputChanged);
  }

  void _onUrlInputChanged() {
    final text = _urlController.text;
    final urls = PlatformDetector.extractUrls(text);
    if (urls.length != _detectedUrls.length || !_listEquals(urls, _detectedUrls)) {
      setState(() {
        _detectedUrls = urls;
      });
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _startDownloads() {
    if (_detectedUrls.isEmpty) return;

    DownloadEngine.instance.addUrls(_detectedUrls, format: _selectedFormat);

    _urlController.clear();
    setState(() {
      _detectedUrls = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Se añadieron ${_detectedUrls.length} descargas a la cola'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
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

          // URL Input & Format Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descargar Videos Múltiples',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pega uno o varios enlaces de YouTube, TikTok, Twitter/X, Instagram o Twitch',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Multiline URL Input
                      TextField(
                        controller: _urlController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'https://www.youtube.com/watch?v=...\nhttps://www.tiktok.com/@...\nhttps://x.com/...',
                          suffixIcon: _urlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => _urlController.clear(),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Detected URLs chip count
                      if (_detectedUrls.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${_detectedUrls.length} enlaces detectados',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            ..._buildPlatformSummaryChips(),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Format Selector Dropdown
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<FormatPreset>(
                              initialValue: _selectedFormat,
                              decoration: const InputDecoration(
                                labelText: 'Formato y Calidad',
                                isDense: true,
                              ),
                              items: FormatPreset.presets.map((preset) {
                                return DropdownMenuItem<FormatPreset>(
                                  value: preset,
                                  child: Text(
                                    preset.label,
                                    style: const TextStyle(fontSize: 13),
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
                            onPressed: _detectedUrls.isNotEmpty ? _startDownloads : null,
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            label: const Text('Descargar'),
                          ),
                        ],
                      ),
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

  List<Widget> _buildPlatformSummaryChips() {
    final counts = <SupportedPlatform, int>{};
    for (final url in _detectedUrls) {
      final p = PlatformDetector.detect(url);
      counts[p] = (counts[p] ?? 0) + 1;
    }

    return counts.entries.map((entry) {
      final hex = PlatformDetector.getBadgeColorHex(entry.key);
      final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${entry.value}x ${PlatformDetector.getDisplayName(entry.key)}',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlInputChanged);
    _urlController.dispose();
    super.dispose();
  }
}
