import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/video_shrink_estimate.dart';
import 'package:dosya_okuyucu/widgets/fm/video_shrink_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(VideoShrinkEstimate.resetForTest);

  final video = FsEntry(
    path: '/storage/emulated/0/DCIM/Camera/VID_1.mp4',
    name: 'VID_1.mp4',
    isDir: false,
    sizeBytes: 1700 * 1024 * 1024,
    modifiedMs: DateTime(2024, 1, 7).millisecondsSinceEpoch,
  );

  testWidgets('ölçülemeyen videoda "Küçült" yazar, dokununca iş başlar',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: VideoShrinkPill(entry: video, onTap: () => taps++),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Küçült'), findsOneWidget);
    await tester.tap(find.byType(VideoShrinkPill));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  test('video olmayan dosyada tahmin yok', () async {
    final doc = FsEntry(
      path: '/storage/emulated/0/Download/a.pdf',
      name: 'a.pdf',
      isDir: false,
      sizeBytes: 1000,
      modifiedMs: 0,
    );
    expect(await VideoShrinkEstimate.of(doc), isNull);
  });
}
