import 'package:flutter/material.dart';
import '../core/updater/update_models.dart';
import '../core/updater/update_service.dart';
import 'theme/app_theme.dart';
import 'views/history_view.dart';
import 'views/home_view.dart';
import 'views/settings_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _notifiedVersion;

  final List<Widget> _views = const [
    HomeView(),
    HistoryView(),
    SettingsView(),
  ];

  @override
  void initState() {
    super.initState();
    UpdateService.instance.state.addListener(_onUpdateState);
  }

  @override
  void dispose() {
    UpdateService.instance.state.removeListener(_onUpdateState);
    super.dispose();
  }

  void _onUpdateState() {
    final state = UpdateService.instance.state.value;
    final release = state.release;
    if (state.phase != UpdatePhase.available || release == null) return;
    if (_notifiedVersion == release.version) return;
    _notifiedVersion = release.version;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Versión ${release.version} disponible'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => setState(() => _currentIndex = 2),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              backgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.primaryContainer.withValues(alpha: 0.5),
              onDestinationSelected: (val) {
                setState(() => _currentIndex = val);
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded, color: AppTheme.primary),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download_rounded, color: AppTheme.primary),
                  label: Text('Descargas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primary),
                  label: Text('Historial'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
                  label: Text('Ajustes'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF2A273F)),
            Expanded(child: _views[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _views[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (val) {
          setState(() => _currentIndex = val);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded, color: AppTheme.primary),
            label: 'Descargas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primary),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
