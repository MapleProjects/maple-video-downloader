import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/auth/cookie_service.dart';
import '../../core/auth/user_agent_helper.dart';
import '../theme/app_theme.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isCapturing = false;
  String? _statusMessage;
  bool _captureSuccess = false;

  final TextEditingController _rawCookieController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initBrowser();
  }

  void _initBrowser() {
    // Check if webview_flutter is supported in this platform
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(UserAgentHelper.getAuthUserAgent(forceDesktop: true))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                _checkAndExtractCookies(url);
              }
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(
          Uri.parse(
            'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://www.youtube.com/',
          ),
        );

      _webViewController = controller;
    }
  }

  Future<void> _checkAndExtractCookies(String url) async {
    if (_isCapturing || _captureSuccess) return;

    // Check if user has redirected back to youtube.com
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.contains('youtube.com')) {
      setState(() {
        _isCapturing = true;
        _statusMessage = 'Detectada cuenta de YouTube. Extrayendo cookies...';
      });

      try {
        // Extract raw cookie string via JS evaluation as well
        final rawJsCookies = await _webViewController?.runJavaScriptReturningResult(
          'document.cookie',
        );

        String cookiesString = '';
        if (rawJsCookies is String) {
          cookiesString = rawJsCookies.replaceAll('"', '').trim();
        }

        if (cookiesString.isNotEmpty) {
          final success = await CookieService.instance.importFromRawHeaderString(
            cookiesString,
            domain: '.youtube.com',
          );

          if (success && CookieService.instance.hasValidYouTubeSession) {
            setState(() {
              _captureSuccess = true;
              _statusMessage = '¡Sesión capturada y guardada permanentemente!';
            });

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
            return;
          }
        }

        setState(() {
          _isCapturing = false;
          _statusMessage = 'Navega o completa el inicio de sesión para capturar las credenciales.';
        });
      } catch (e) {
        setState(() {
          _isCapturing = false;
          _statusMessage = 'Error al leer cookies: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio de Sesión en YouTube'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _webViewController?.reload();
            },
            tooltip: 'Recargar navegador',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Notification Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _captureSuccess
                ? AppTheme.success.withValues(alpha: 0.15)
                : AppTheme.surfaceVariant,
            child: Row(
              children: [
                Icon(
                  _captureSuccess
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: _captureSuccess ? AppTheme.success : AppTheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage ??
                        'Inicia sesión normalmente con tu cuenta de Google para capturar las cookies.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _captureSuccess
                          ? AppTheme.success
                          : AppTheme.onBackground,
                    ),
                  ),
                ),
                if (_isLoading || _isCapturing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
              ],
            ),
          ),

          // Main View: Embedded WebView or Desktop Session Manager
          Expanded(
            child: isMobile && _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : _buildDesktopSessionManager(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSessionManager() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cookie_rounded, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestión de Cookies en Escritorio (Linux / Windows)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Almacenamiento automático y permanente en formato Netscape',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF2A273F)),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: CookieService.instance.isAuthenticatedNotifier,
                    builder: (context, isAuth, _) {
                      return Row(
                        children: [
                          Icon(
                            isAuth ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 18,
                            color: isAuth ? AppTheme.success : AppTheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAuth
                                ? 'Sesión de YouTube activa y configurada'
                                : 'Sin sesión activa de YouTube',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isAuth ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Archivo de cookies: ${CookieService.instance.cookiesFilePath ?? "No inicializado"}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showPasteCookiesModal,
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: const Text('Importar / Actualizar Cookies'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await CookieService.instance.clearCookies();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cookies eliminadas')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Limpiar Sesión'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Cómo funciona la captura automática?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. En Android, el navegador embebido detecta tu inicio de sesión en YouTube, extrae las cookies de sesión (LOGIN_INFO, SID, SSID) y las guarda automáticamente en formato Netscape cookies.txt.\n\n'
                    '2. En Linux y Windows, el motor yt-dlp lee este archivo permanentemente desde la carpeta de configuración sin necesidad de extensiones externas ni navegadores auxiliares.\n\n'
                    '3. Todas las descargas posteriores se benefician de la cuenta autenticada para evitar bloqueos por edad o contenido privado.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasteCookiesModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pegar Cookies de YouTube'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pega el contenido en formato texto (pares clave=valor separados por punto y coma o formato Netscape):',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rawCookieController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'LOGIN_INFO=...; SID=...; HSID=...;',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = _rawCookieController.text.trim();
                if (text.isNotEmpty) {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await CookieService.instance.importFromRawHeaderString(text);
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Cookies guardadas correctamente'
                          : 'No se pudieron parsear las cookies'),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _rawCookieController.dispose();
    super.dispose();
  }
}
