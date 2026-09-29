import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/downloader/download_engine.dart';
import '../../core/downloader/platform_detector.dart';
import '../../core/models/download_task.dart';
import '../theme/app_theme.dart';

class DownloadCard extends StatelessWidget {
  final DownloadTask task;

  const DownloadCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Platform chip + Status + Action
            Row(
              children: [
                _buildPlatformBadge(task.platform),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.format.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionButtons(context),
              ],
            ),
            const SizedBox(height: 8),

            // Title / URL
            Text(
              task.title.isNotEmpty ? task.title : task.url,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Progress bar
            if (task.isActive) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.status == TaskStatus.analyzing
                      ? null
                      : (task.progress / 100.0).clamp(0.0, 1.0),
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.status == TaskStatus.analyzing
                        ? 'Analizando enlace...'
                        : task.status == TaskStatus.processing
                            ? 'Procesando formatos / audio...'
                            : '${task.progress.toStringAsFixed(1)}% (${task.speed})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    task.eta != '--' ? 'Restante: ${task.eta}' : task.totalSize,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else if (task.status == TaskStatus.completed) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Descarga completada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                  const Spacer(),
                  if (task.outputPath != null)
                    TextButton.icon(
                      onPressed: () => _openFile(task.outputPath!),
                      icon: const Icon(Icons.folder_open_rounded, size: 14),
                      label: const Text('Abrir', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ] else if (task.status == TaskStatus.error) ...[
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showErrorDialog(context, task.errorMessage ?? 'Error desconocido'),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        task.errorMessage ?? 'Error desconocido',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.error,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    color: AppTheme.textMuted,
                    onPressed: () {
                      final msg = task.errorMessage ?? 'Error desconocido';
                      Clipboard.setData(ClipboardData(text: msg));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copiar error',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => DownloadEngine.instance.retryTask(task),
                    tooltip: 'Reintentar',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(SupportedPlatform platform) {
    final hex = PlatformDetector.getBadgeColorHex(platform);
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        PlatformDetector.getDisplayName(platform),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (task.isActive) {
      return IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        color: AppTheme.textMuted,
        onPressed: () => DownloadEngine.instance.cancelTask(task),
        tooltip: 'Cancelar',
        constraints: const BoxConstraints(),
        padding: EdgeInsets.zero,
      );
    }

    return IconButton(
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      color: AppTheme.textMuted,
      onPressed: () => DownloadEngine.instance.removeTask(task),
      tooltip: 'Eliminar de la lista',
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _openFile(String path) async {
    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
              SizedBox(width: 8),
              Text('Detalles del Error', style: TextStyle(fontSize: 15)),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: SelectableText(
                error,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.onBackground,
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: error));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error copiado al portapapeles'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar Error'),
            ),
          ],
        );
      },
    );
  }
}
