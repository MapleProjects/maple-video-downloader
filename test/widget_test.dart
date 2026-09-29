import 'package:flutter_test/flutter_test.dart';
import 'package:maple_video_downloader/main.dart';

void main() {
  testWidgets('Maple Video Downloader smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MapleVideoDownloaderApp());
    expect(find.text('Maple Video Downloader'), findsOneWidget);
  });
}
