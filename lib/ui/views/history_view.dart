import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/downloader/download_engine.dart';
import '../../core/models/download_task.dart';
import '../theme/app_theme.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Descargas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Borrar historial',
            onPressed: () {
              DownloadEngine.instance.clearHistory();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<DownloadTask>>(
        valueListenable: DownloadEngine.instance.historyNotifier,
        builder: (context, history, _) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.history_rounded, size: 48, color: Color(0xFF2A273F)),
                  SizedBox(height: 12),
                  Text(
                    'No hay descargas completadas aún',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 28,
                  ),
                  title: Text(
                    item.title.isNotEmpty ? item.title : item.url,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.format.label} • ${item.createdAt.toString().split(".").first}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  trailing: item.outputPath != null
                      ? IconButton(
                          icon: const Icon(Icons.folder_open_rounded, size: 20),
                          tooltip: 'Abrir archivo',
                          onPressed: () async {
                            final uri = Uri.file(item.outputPath!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
