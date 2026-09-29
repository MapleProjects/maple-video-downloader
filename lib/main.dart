import 'package:flutter/material.dart';
import 'core/auth/cookie_service.dart';
import 'core/downloader/download_engine.dart';
import 'core/services/settings_service.dart';
import 'ui/main_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services
  await CookieService.instance.init();
  await SettingsService.instance.init();
  await DownloadEngine.instance.init();

  runApp(const MapleVideoDownloaderApp());
}

class MapleVideoDownloaderApp extends StatelessWidget {
  const MapleVideoDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maple Video Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
