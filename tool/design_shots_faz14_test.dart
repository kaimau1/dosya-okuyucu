// Faz 14 tasarım görüntüleri: `flutter test tool/design_shots_faz14_test.dart`
// → docs/design/faz14/*.png. Normal test takımında KOŞMAZ (test/ altında değil).
// Yöntem `tool/design_shots_test.dart` ile aynı (FontLoader + toImage).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/widgets/fm/media_resize_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

const _photo = MediaSourceInfo(
    name: 'IMG_2026_tatil.jpg',
    sizeBytes: 4200000,
    isVideo: false,
    width: 4000,
    height: 3000);

void main() {
  setUpAll(() async {
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    Directory('docs/design/faz14').createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name,
      {MediaResizeOptions initial = const MediaResizeOptions(),
      Brightness brightness = Brightness.light,
      Future<void> Function(WidgetTester)? act}) async {
    const size = Size(400, 860);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMediaResizeSheet(context,
                    hasImages: true,
                    hasVideos: false,
                    fileCount: 1,
                    initial: initial,
                    sources: const [_photo]),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    if (act != null) {
      await act(tester);
      await tester.pumpAndSettle();
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('docs/design/faz14/$name.png').writeAsBytesSync(bytes!);
  }

  testWidgets('uzun kenar', (t) => shot(t, 'uzun_kenar_acik'));
  testWidgets('uzun kenar koyu',
      (t) => shot(t, 'uzun_kenar_koyu', brightness: Brightness.dark));
  testWidgets('piksel kilitli', (t) => shot(t, 'piksel_kilitli_acik',
          initial: const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customWidth: 1600)));
  testWidgets('piksel serbest kenar boşluğu', (t) => shot(t, 'piksel_bosluk_acik',
          initial: const MediaResizeOptions(
              resolution: ResolutionChoice.custom,
              customWidth: 1080,
              customHeight: 1080,
              lockAspect: false,
              fit: ResizeFit.pad,
              padColor: PadColor.blur)));
  testWidgets('dosya boyutu', (t) => shot(t, 'dosya_boyutu_acik',
          initial: const MediaResizeOptions(
              resolution: ResolutionChoice.fileSize, targetKb: 200)));
  testWidgets('yüzde büyütme', (t) => shot(t, 'yuzde_150_koyu',
          brightness: Brightness.dark,
          initial: const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 150)));
}
