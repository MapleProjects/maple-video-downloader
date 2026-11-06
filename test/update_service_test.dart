import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maple_video_downloader/core/updater/update_models.dart';
import 'package:maple_video_downloader/core/updater/update_service.dart';

void main() {
  late HttpServer server;
  late Directory workDir;
  late List<int> packageBytes;
  late String packageHash;
  const assetName = 'maple-video-downloader-1.1.0-linux-x64.tar.gz';

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('maple-update-test');

    final archive = Archive();
    final content = utf8.encode('contenido de la version nueva');
    archive.addFile(ArchiveFile('app.txt', content.length, content));
    final tar = TarEncoder().encode(archive);
    packageBytes = GZipEncoder().encode(tar);
    packageHash = sha256.convert(packageBytes).toString();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      switch (request.uri.path) {
        case '/$assetName':
          request.response.add(packageBytes);
          break;
        case '/SHA256SUMS.txt':
          request.response.write('$packageHash  $assetName\n');
          break;
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  });

  ReleaseInfo buildRelease({String? checksumUrl}) {
    final base = 'http://127.0.0.1:${server.port}';
    return ReleaseInfo(
      tagName: 'v1.1.0',
      version: '1.1.0',
      title: 'Maple Video Downloader v1.1.0',
      notes: 'Notas de la versión',
      pageUrl: 'https://example.com/release',
      publishedAt: DateTime.utc(2026, 11, 6),
      assets: [
        ReleaseAsset(
          name: assetName,
          downloadUrl: '$base/$assetName',
          size: packageBytes.length,
        ),
        if (checksumUrl != null)
          ReleaseAsset(
            name: 'SHA256SUMS.txt',
            downloadUrl: checksumUrl,
            size: 0,
          ),
      ],
    );
  }

  setUp(() {
    final service = UpdateService.instance;
    service.workDirOverride = workDir;
    service.currentVersion = '1.0.0';
    service.state.value = const UpdateState.idle();
  });

  test('descarga, verifica el hash y descomprime el paquete', () async {
    final service = UpdateService.instance;
    service.state.value = UpdateState(
      phase: UpdatePhase.available,
      release: buildRelease(
        checksumUrl: 'http://127.0.0.1:${server.port}/SHA256SUMS.txt',
      ),
    );

    await service.downloadAndStage();

    final state = service.state.value;
    expect(state.phase, UpdatePhase.ready);
    expect(state.stagedPath, isNotNull);

    final staged = File('${state.stagedPath}${Platform.pathSeparator}app.txt');
    expect(await staged.exists(), isTrue);
    expect(await staged.readAsString(), 'contenido de la version nueva');
  });

  test('rechaza el paquete cuando el hash no coincide', () async {
    final service = UpdateService.instance;
    service.state.value = UpdateState(
      phase: UpdatePhase.available,
      release: buildRelease(
        checksumUrl: 'http://127.0.0.1:${server.port}/SHA256SUMS.txt',
      ),
    );

    // Fuerza un hash distinto sirviendo un checksum alterado.
    final original = packageHash;
    packageHash = List.filled(64, '0').join();
    try {
      await expectLater(
        service.downloadAndStage(),
        throwsA(isA<UpdateException>()),
      );
    } finally {
      packageHash = original;
    }
  });

  test('falla si la release no trae el paquete de la plataforma', () async {
    final service = UpdateService.instance;
    service.state.value = UpdateState(
      phase: UpdatePhase.available,
      release: ReleaseInfo(
        tagName: 'v1.1.0',
        version: '1.1.0',
        title: 'x',
        notes: '',
        pageUrl: '',
        publishedAt: null,
        assets: const [
          ReleaseAsset(
            name: 'maple-video-downloader-1.1.0-macos.zip',
            downloadUrl: 'https://example.com/macos.zip',
            size: 1,
          ),
        ],
      ),
    );

    await expectLater(
      service.downloadAndStage(),
      throwsA(isA<UpdateException>()),
    );
  });
}
