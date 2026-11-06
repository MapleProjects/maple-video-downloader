import 'package:flutter_test/flutter_test.dart';
import 'package:maple_video_downloader/core/updater/update_models.dart';

void main() {
  group('normalizeVersion', () {
    test('quita el prefijo v', () {
      expect(normalizeVersion('v1.2.3'), '1.2.3');
    });

    test('quita build y prerelease', () {
      expect(normalizeVersion('v1.2.3+7'), '1.2.3');
      expect(normalizeVersion('1.2.3-beta.1'), '1.2.3');
    });
  });

  group('compareVersions', () {
    test('detecta versiones mayores', () {
      expect(compareVersions('1.1.0', '1.0.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('detecta versiones iguales con distinto formato', () {
      expect(compareVersions('v1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });

    test('detecta versiones menores', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.0.9', '1.1.0'), lessThan(0));
    });

    test('compara componentes numéricos, no texto', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    });
  });

  group('ReleaseInfo', () {
    final release = ReleaseInfo.fromJson({
      'tag_name': 'v1.1.0',
      'name': 'Maple Video Downloader v1.1.0',
      'body': 'Notas',
      'html_url': 'https://github.com/MapleProjects/maple-video-downloader/releases/tag/v1.1.0',
      'published_at': '2026-11-06T12:00:00Z',
      'assets': [
        {
          'name': 'maple-video-downloader-1.1.0-windows-x64.zip',
          'browser_download_url': 'https://example.com/win.zip',
          'size': 100,
        },
        {
          'name': 'maple-video-downloader-1.1.0-linux-x64.tar.gz',
          'browser_download_url': 'https://example.com/linux.tar.gz',
          'size': 200,
        },
        {
          'name': 'SHA256SUMS.txt',
          'browser_download_url': 'https://example.com/SHA256SUMS.txt',
          'size': 10,
        },
      ],
    });

    test('normaliza la versión del tag', () {
      expect(release.version, '1.1.0');
    });

    test('selecciona el asset por sufijo', () {
      expect(
        release.assetEndingWith('windows-x64.zip')?.name,
        'maple-video-downloader-1.1.0-windows-x64.zip',
      );
      expect(
        release.assetEndingWith('linux-x64.tar.gz')?.name,
        'maple-video-downloader-1.1.0-linux-x64.tar.gz',
      );
      expect(release.assetEndingWith('macos.zip'), isNull);
    });

    test('encuentra el archivo de checksums sin distinguir mayúsculas', () {
      expect(release.assetNamed('sha256sums.txt')?.name, 'SHA256SUMS.txt');
    });
  });
}
