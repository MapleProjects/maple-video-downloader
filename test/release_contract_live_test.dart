import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maple_video_downloader/core/updater/update_models.dart';
import 'package:maple_video_downloader/core/updater/update_service.dart';

/// Verifica contra la release real publicada que el contrato de nombres de
/// assets sigue vigente.
///
/// Requiere red y se ejecuta solo de forma explícita:
///   MAPLE_LIVE_RELEASE_TEST=1 flutter test test/release_contract_live_test.dart
void main() {
  final enabled = Platform.environment['MAPLE_LIVE_RELEASE_TEST'] == '1';

  test(
    'la release publicada expone los assets esperados',
    () async {
      final service = UpdateService.instance;
      service.currentVersion = '0.0.1';

      final release = await service.checkForUpdates();

      expect(release, isNotNull, reason: 'No se detectó ninguna release');
      expect(compareVersions(release!.version, '0.0.1'), greaterThan(0));
      expect(release.assetEndingWith('windows-x64.zip'), isNotNull);
      expect(release.assetEndingWith('linux-x64.tar.gz'), isNotNull);
      expect(release.assetNamed('SHA256SUMS.txt'), isNotNull);
    },
    skip: enabled ? false : 'Requiere red. Usa MAPLE_LIVE_RELEASE_TEST=1',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
