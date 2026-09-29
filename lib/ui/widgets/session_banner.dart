import 'package:flutter/material.dart';
import '../../core/auth/cookie_service.dart';
import '../theme/app_theme.dart';

class SessionBanner extends StatelessWidget {
  final VoidCallback onOpenAuth;

  const SessionBanner({
    super.key,
    required this.onOpenAuth,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CookieService.instance.isAuthenticatedNotifier,
      builder: (context, isAuthenticated, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: CookieService.instance.accountNameNotifier,
          builder: (context, accountName, _) {
            return ValueListenableBuilder<int>(
              valueListenable: CookieService.instance.cookieCountNotifier,
              builder: (context, cookieCount, _) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAuthenticated
                        ? AppTheme.surfaceVariant
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAuthenticated
                          ? AppTheme.success.withValues(alpha: 0.4)
                          : const Color(0xFF2A273F),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAuthenticated
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : AppTheme.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAuthenticated
                              ? Icons.lock_open_rounded
                              : Icons.account_circle_outlined,
                          size: 20,
                          color: isAuthenticated
                              ? AppTheme.success
                              : AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAuthenticated
                                  ? (accountName != null
                                      ? 'Cuenta de YouTube: $accountName'
                                      : 'Sesión de YouTube activa')
                                  : 'Iniciar sesión en YouTube',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAuthenticated
                                  ? 'Acceso habilitado a contenido protegido y máxima resolución'
                                  : 'Permite descargar videos con restricción de edad',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onOpenAuth,
                        icon: Icon(
                          isAuthenticated ? Icons.manage_accounts_rounded : Icons.login_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        label: Text(
                          isAuthenticated ? 'Gestionar' : 'Iniciar sesión',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
