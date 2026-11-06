import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/updater/update_models.dart';
import '../../core/updater/update_service.dart';
import '../theme/app_theme.dart';

/// Sección de configuración para comprobar e instalar actualizaciones.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final service = UpdateService.instance;

    return ValueListenableBuilder<UpdateState>(
      valueListenable: service.state,
      builder: (context, state, _) {
        final release = state.release;
        final busy = state.isBusy || _working;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_alt_rounded,
                    color: AppTheme.primary),
                title: const Text('Versión instalada',
                    style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  'Maple Video Downloader ${service.currentVersion}'
                  '${service.currentBuild.isNotEmpty ? ' (build ${service.currentBuild})' : ''}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _check(context),
                        child: const Text('Buscar'),
                      ),
              ),
              const Divider(height: 1, color: Color(0xFF2A273F)),
              ValueListenableBuilder<bool>(
                valueListenable: service.autoCheckNotifier,
                builder: (context, autoCheck, _) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.autorenew_rounded,
                        color: AppTheme.primary),
                    title: const Text('Buscar al iniciar',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      'Consulta GitHub en segundo plano al abrir la aplicación',
                      style:
                          TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    value: autoCheck,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (value) => service.setAutoCheck(value),
                  );
                },
              ),
              if (state.phase == UpdatePhase.downloading ||
                  state.phase == UpdatePhase.verifying ||
                  state.phase == UpdatePhase.extracting ||
                  state.phase == UpdatePhase.installing) ...[
                const Divider(height: 1, color: Color(0xFF2A273F)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: state.phase == UpdatePhase.downloading
                            ? state.progress
                            : null,
                        backgroundColor: AppTheme.surfaceVariant,
                        color: AppTheme.primary,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.message,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.phase == UpdatePhase.available && release != null) ...[
                const Divider(height: 1, color: Color(0xFF2A273F)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.new_releases_outlined,
                              size: 18, color: AppTheme.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Versión ${release.version} disponible',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          state.message,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!state.managedByPackageManager)
                            ElevatedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _downloadAndInstall(context),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Descargar e instalar'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _showNotes(context, release),
                            icon: const Icon(Icons.notes_rounded, size: 18),
                            label: const Text('Notas'),
                          ),
                          TextButton(
                            onPressed: () => service.openReleasePage(),
                            child: const Text('Ver en GitHub'),
                          ),
                          TextButton(
                            onPressed: () => service.skipVersion(release.version),
                            child: const Text('Omitir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (state.phase == UpdatePhase.ready) ...[
                const Divider(height: 1, color: Color(0xFF2A273F)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: AppTheme.success),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Actualización lista. Reinicia para aplicarla.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _restart(context),
                        child: const Text('Reiniciar'),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.phase == UpdatePhase.upToDate) ...[
                const Divider(height: 1, color: Color(0xFF2A273F)),
                ListTile(
                  leading: const Icon(Icons.verified_outlined,
                      size: 18, color: AppTheme.success),
                  title: Text(
                    state.message,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
              if (state.phase == UpdatePhase.error && state.error != null) ...[
                const Divider(height: 1, color: Color(0xFF2A273F)),
                _ErrorBox(
                  message: state.error!,
                  onCopy: () => _copy(context, state.error!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _check(BuildContext context) async {
    setState(() => _working = true);
    try {
      await UpdateService.instance.checkForUpdates();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _downloadAndInstall(BuildContext context) async {
    setState(() => _working = true);
    try {
      await UpdateService.instance.downloadAndStage();
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Actualización descargada'),
          content: const Text(
            'La aplicación se cerrará, reemplazará los archivos instalados y '
            'se abrirá de nuevo con la nueva versión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reiniciar ahora'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await UpdateService.instance.installAndRestart();
      }
    } catch (e) {
      if (!context.mounted) return;
      await _showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restart(BuildContext context) async {
    try {
      await UpdateService.instance.installAndRestart();
    } catch (e) {
      if (!context.mounted) return;
      await _showError(context, e.toString());
    }
  }

  Future<void> _showError(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No se pudo actualizar'),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Error copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error copiado')),
      );
    }
  }

  void _showNotes(BuildContext context, ReleaseInfo release) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Novedades ${release.version}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              release.notes.trim().isEmpty
                  ? 'Esta versión no incluye notas.'
                  : release.notes,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onCopy;

  const _ErrorBox({required this.message, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, color: AppTheme.error),
            ),
          ),
          IconButton(
            tooltip: 'Copiar error',
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
