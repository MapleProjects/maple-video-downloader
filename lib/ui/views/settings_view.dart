import 'package:flutter/material.dart';
import '../../core/auth/cookie_service.dart';
import '../../core/downloader/format_preset.dart';
import '../../core/services/settings_service.dart';
import '../theme/app_theme.dart';
import 'auth_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Descargas
          _buildSectionHeader('Motor de Descargas'),
          Card(
            child: Column(
              children: [
                // Download directory
                ValueListenableBuilder<String>(
                  valueListenable: SettingsService.instance.downloadDirectoryNotifier,
                  builder: (context, dir, _) {
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined, color: AppTheme.primary),
                      title: const Text('Directorio de destino', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        dir.isNotEmpty ? dir : 'Automático',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showEditDirDialog(context, dir),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF2A273F)),

                // Max concurrent downloads
                ValueListenableBuilder<int>(
                  valueListenable: SettingsService.instance.maxConcurrentNotifier,
                  builder: (context, maxConcurrent, _) {
                    return ListTile(
                      leading: const Icon(Icons.speed_rounded, color: AppTheme.primary),
                      title: const Text('Descargas simultáneas', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '$maxConcurrent hilos paralelos activos',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: maxConcurrent > 1
                                ? () => SettingsService.instance.setMaxConcurrent(maxConcurrent - 1)
                                : null,
                          ),
                          Text(
                            '$maxConcurrent',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: maxConcurrent < 8
                                ? () => SettingsService.instance.setMaxConcurrent(maxConcurrent + 1)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF2A273F)),

                // Default format
                ValueListenableBuilder<String>(
                  valueListenable: SettingsService.instance.defaultFormatNotifier,
                  builder: (context, defaultFormat, _) {
                    final preset = FormatPreset.getById(defaultFormat);
                    return ListTile(
                      leading: const Icon(Icons.high_quality_outlined, color: AppTheme.primary),
                      title: const Text('Formato predeterminado', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        preset.label,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: DropdownButton<String>(
                        value: defaultFormat,
                        underline: const SizedBox(),
                        items: FormatPreset.presets.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.label, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            SettingsService.instance.setDefaultFormat(val);
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Autenticación y Cookies
          _buildSectionHeader('Sesión y Cookies'),
          Card(
            child: Column(
              children: [
                // Auto attach cookies toggle
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.autoUseCookiesNotifier,
                  builder: (context, autoCookies, _) {
                    return SwitchListTile(
                      secondary: const Icon(Icons.cookie_outlined, color: AppTheme.primary),
                      title: const Text('Inyectar cookies automáticamente', style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                        'Pasa las credenciales capturadas de YouTube a yt-dlp',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      value: autoCookies,
                      activeTrackColor: AppTheme.primary,
                      onChanged: (val) => SettingsService.instance.setAutoUseCookies(val),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF2A273F)),

                // Open Auth view
                ListTile(
                  leading: const Icon(Icons.login_rounded, color: AppTheme.primary),
                  title: const Text('Navegador Embebido de YouTube', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Iniciar sesión para capturar cookies o renovar sesión',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthView()),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF2A273F)),

                // Clear cookies
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                  title: const Text('Eliminar cookies guardadas', style: TextStyle(fontSize: 13, color: AppTheme.error)),
                  subtitle: const Text(
                    'Borra el archivo youtube_cookies.txt local',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  onTap: () async {
                    await CookieService.instance.clearCookies();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cookies eliminadas')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: Acerca de
          _buildSectionHeader('Información'),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: AppTheme.primary),
                  title: Text('Maple Video Downloader', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Versión 1.0.0 • Multiplataforma (Android, Windows, Linux)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showEditDirDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Directorio de Descargas'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Ruta absoluta',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  SettingsService.instance.setDownloadDirectory(text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
