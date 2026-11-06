// Faz 42 süzgeç cilası tasarım görüntüleri:
//
//   flutter test tool/design_shots_faz42_test.dart
//
// → docs/design/faz42/*.png (tür levhası seçimli + sıfır sonuçlu kutu, açık
// ve koyu tema). Normal test takımında KOŞMAZ. Yöntem faz32 betiğiyle aynı.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fm_type.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_type_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const out = 'docs/design/faz42';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    Directory(out).createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name, ThemeData theme,
      Set<FmType> selected) async {
    tester.view.physicalSize = const Size(400, 820) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showFmTypeSheet(
                  context,
                  counts: const {
                    FmType.pdf: 42,
                    FmType.word: 17,
                    FmType.excel: 9,
                    FmType.image: 812,
                    FmType.video: 0,
                    FmType.archive: 3,
                  },
                  present: const [
                    FmType.pdf,
                    FmType.word,
                    FmType.excel,
                    FmType.image,
                    FmType.video,
                    FmType.archive,
                  ],
                  selected: selected,
                  onChanged: (_) {},
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$out/$name.png').writeAsBytesSync(bytes!);
  }

  testWidgets('tür levhası açık tema, seçimli',
      (t) => shot(t, 'tur_acik_secimli', AppTheme.light(), {FmType.pdf, FmType.word}));
  testWidgets('tür levhası koyu tema, seçimsiz',
      (t) => shot(t, 'tur_koyu', AppTheme.dark(), const {}));
}
