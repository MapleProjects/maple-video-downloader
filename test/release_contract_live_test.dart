import 'package:flutter_test/flutter_test.dart';
import 'package:maple_video_downloader/core/updater/update_service.dart';

/// Verifica contra la release real publicada que el contrato de nombres de
/// assets sigue vigente. Requiere red.
void main() {
  test('la release publicada expone los assets esperados', () async {
    final service = UpdateService.instance;
    service.currentVersion = '1.1.2';

    final release = await service.checkForUpdates();

    expect(release, isNotNull, reason: 'No se detectó una versión más nueva');
    expect(release!.version, '1.1.3');
    expect(release.assetEndingWith('windows-x64.zip'), isNotNull);
    expect(release.assetEndingWith('linux-x64.tar.gz'), isNotNull);
    expect(release.assetNamed('SHA256SUMS.txt'), isNotNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
