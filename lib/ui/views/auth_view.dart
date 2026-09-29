import 'dart:async';
import 'dart:io';
import 'package:desktop_webview_window/desktop_webview_window.dart';
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
  // Mobile webview controller (Android / iOS)
  WebViewController? _webViewController;

  // Desktop webview instance (Linux / Windows / macOS)
  Webview? _desktopWebview;
  Timer? _desktopCookieTimer;
  bool _isDesktopBrowserActive = false;

  bool _isLoading = true;
  bool _isCapturing = false;
  String? _statusMessage;
  bool _captureSuccess = false;

  final TextEditingController _rawCookieController = TextEditingController();

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _initMobileBrowser();
    } else {
      _isLoading = false;
      _statusMessage = CookieService.instance.hasValidYouTubeSession
          ? 'Sesión de YouTube activa.'
          : 'Presiona el botón para abrir el navegador embebido e iniciar sesión.';
    }
  }

  void _initMobileBrowser() {
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
              _checkAndExtractMobileCookies(url);
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

  Future<void> _checkAndExtractMobileCookies(String url) async {
    if (_isCapturing || _captureSuccess) return;

    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.contains('youtube.com')) {
      setState(() {
        _isCapturing = true;
        _statusMessage = 'Detectada cuenta de YouTube. Extrayendo cookies...';
      });

      try {
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
              _isCapturing = false;
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

  /// Opens native embedded browser window on Linux / Windows.
  Future<void> _openDesktopLoginBrowser() async {
    if (_isDesktopBrowserActive) return;

    final isAvailable = await WebviewWindow.isWebviewAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El motor de navegador embebido no está disponible en este sistema.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDesktopBrowserActive = true;
      _captureSuccess = false;
      _statusMessage = 'Navegador embebido abierto. Inicia sesión en tu cuenta de YouTube.';
    });

    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Iniciar Sesión en YouTube - Maple Video Downloader',
          windowWidth: 1040,
          windowHeight: 720,
          titleBarHeight: 38,
          titleBarTopPadding: Platform.isMacOS ? 20 : 0,
          userDataFolderWindows: 'maple_webview_cache',
        ),
      );

      _desktopWebview = webview;

      // Set platform-aware desktop Chrome User-Agent to avoid Google bot flags
      await webview.setApplicationNameForUserAgent(
        UserAgentHelper.getAuthUserAgent(forceDesktop: true),
      );

      // Periodically check for authenticated YouTube cookies
      _desktopCookieTimer?.cancel();
      _desktopCookieTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_desktopWebview != null && _isDesktopBrowserActive && !_captureSuccess) {
          _captureDesktopCookies(webview, autoClose: true);
        }
      });

      // Monitor URL changes: also check shortly after any YouTube navigation
      webview.setOnUrlRequestCallback((url) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.host.contains('youtube.com') && !url.contains('accounts.google.com')) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (_desktopWebview != null && _isDesktopBrowserActive && !_captureSuccess) {
              _captureDesktopCookies(webview, autoClose: true);
            }
          });
        }
        return true;
      });

      // Launch YouTube Google OAuth entry point
      webview.launch(
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https://www.youtube.com/',
      );

      // Window close listener
      webview.onClose.then((_) {
        _desktopCookieTimer?.cancel();
        _desktopCookieTimer = null;
        _desktopWebview = null;
        if (mounted) {
          setState(() {
            _isDesktopBrowserActive = false;
            if (!_captureSuccess) {
              _statusMessage = CookieService.instance.hasValidYouTubeSession
                  ? 'Sesión de YouTube activa.'
                  : 'Navegador cerrado. Puedes volver a abrirlo cuando lo desees.';
            }
          });
        }
      });
    } catch (e) {
      _desktopCookieTimer?.cancel();
      _desktopCookieTimer = null;
      setState(() {
        _isDesktopBrowserActive = false;
        _statusMessage = 'Error al abrir el navegador embebido: $e';
      });
    }
  }

  /// Captures cookies from desktop webview and saves them permanently when authenticated.
  Future<void> _captureDesktopCookies(
    Webview webview, {
    bool autoClose = false,
    bool manual = false,
  }) async {
    if (_isCapturing || _captureSuccess) return;

    try {
      final allCookies = await webview.getAllCookies();
      if (allCookies.isEmpty) {
        if (manual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron cookies en el navegador todavía.'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        return;
      }

      // Filter cookies for youtube.com and google.com
      final relevantCookies = allCookies.where((c) {
        final d = c.domain.toLowerCase();
        return d.contains('youtube.com') || d.contains('google.com');
      }).toList();

      // Check strictly for .youtube.com authentication cookies
      final ytAuthCookies = relevantCookies.where((c) {
        final d = c.domain.toLowerCase();
        return d.contains('youtube.com');
      }).toList();

      final ytNames = ytAuthCookies.map((c) => c.name.toUpperCase()).toSet();
      final hasLoginInfo = ytNames.contains('LOGIN_INFO');
      final hasYtSid = ytNames.contains('SID') ||
          ytNames.contains('__SECURE-3PSID') ||
          ytNames.contains('__SECURE-1PSID');
      final hasYtSsid = ytNames.contains('SSID') || ytNames.contains('HSID');

      final isYtAuthenticated = hasLoginInfo || (hasYtSid && hasYtSsid);

      if (isYtAuthenticated) {
        setState(() {
          _isCapturing = true;
          _statusMessage = '¡Cuenta de YouTube detectada! Guardando cookies permanentemente...';
        });

        final success =
            await CookieService.instance.importFromDesktopWebviewCookies(relevantCookies);

        if (success && CookieService.instance.hasValidYouTubeSession) {
          _desktopCookieTimer?.cancel();
          _desktopCookieTimer = null;

          setState(() {
            _captureSuccess = true;
            _isCapturing = false;
            _isDesktopBrowserActive = false;
            _statusMessage = '¡Sesión de YouTube vinculada y guardada permanentemente!';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Sesión de YouTube vinculada y guardada permanentemente!'),
                backgroundColor: AppTheme.success,
              ),
            );
          }

          if (autoClose || manual) {
            // Allow 1.5s for WebKitGTK network and state to settle before closing window
            await Future.delayed(const Duration(milliseconds: 1500));
            try {
              webview.close();
            } catch (e) {
              debugPrint('[AuthView] Error closing webview: $e');
            }
          }
        } else {
          setState(() {
            _isCapturing = false;
          });
        }
      } else if (manual) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aún no se detectan credenciales de YouTube. Completa el inicio de sesión en la ventana emergente y espera a que aparezca tu foto de perfil en YouTube.',
              ),
              backgroundColor: AppTheme.accent,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DesktopWebview] Error checking cookies: $e');
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar cookies: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta de YouTube'),
        actions: [
          if (_isMobile)
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
                        (_isMobile
                            ? 'Inicia sesión con tu cuenta para continuar.'
                            : 'Inicia sesión para vincular tu cuenta.'),
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

          // Main View: Embedded Mobile WebView or Desktop Native Session Flow
          Expanded(
            child: _isMobile && _webViewController != null
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_circle_outlined,
                          color: AppTheme.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuenta de YouTube',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Inicia sesión para descargar videos con restricción de edad y en máxima resolución',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2A273F)),
                  const SizedBox(height: 16),

                  // Session status badge
                  ValueListenableBuilder<bool>(
                    valueListenable: CookieService.instance.isAuthenticatedNotifier,
                    builder: (context, isAuth, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isAuth
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAuth
                                ? AppTheme.success.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAuth ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 20,
                              color: isAuth ? AppTheme.success : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAuth
                                        ? 'Sesión de YouTube activa'
                                        : 'Sin sesión iniciada',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isAuth ? AppTheme.success : AppTheme.onBackground,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAuth
                                        ? 'Tu cuenta está conectada para todas las descargas.'
                                        : 'Abre el navegador e inicia sesión con tu cuenta de Google.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isDesktopBrowserActive ? null : _openDesktopLoginBrowser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: _isDesktopBrowserActive
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded, size: 18),
                        label: Text(
                          _isDesktopBrowserActive
                              ? 'Esperando inicio de sesión...'
                              : 'Iniciar sesión en YouTube',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isDesktopBrowserActive && _desktopWebview != null)
                        OutlinedButton.icon(
                          onPressed: () => _captureDesktopCookies(_desktopWebview!, manual: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Verificar sesión'),
                        ),
                      ValueListenableBuilder<bool>(
                        valueListenable: CookieService.instance.isAuthenticatedNotifier,
                        builder: (context, isAuth, _) {
                          if (!isAuth) return const SizedBox.shrink();
                          return OutlinedButton.icon(
                            onPressed: () async {
                              await CookieService.instance.clearCookies();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sesión cerrada')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              foregroundColor: AppTheme.error,
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Cerrar sesión'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _desktopCookieTimer?.cancel();
    _desktopCookieTimer = null;
    try {
      _desktopWebview?.close();
    } catch (_) {}
    _rawCookieController.dispose();
    super.dispose();
  }
}
