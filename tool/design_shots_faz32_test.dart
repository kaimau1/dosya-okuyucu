// Faz 32 tasarım görüntüleri — görsel düzenleyici 2.0:
//
//   flutter test tool/design_shots_faz32_test.dart
//
// → docs/design/faz32/*.png (serbest açı + ızgara, ayar şeridi, filtreler,
// işaretle: seçili yazı nesnesi + bulanıklaştırma). Gerçek [ImageEditScreen]
// çizilir. Normal test takımında KOŞMAZ. Yöntem faz28 betiğiyle aynı.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/image_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const out = 'docs/design/faz32';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Gün batımı manzarası + "plaka": düzenleyicide anlamlı görünsün.
Future<Uint8List> _photo() async {
  const w = 1200.0, h = 900.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, h * 0.6),
            const [Color(0xFF3B5BA9), Color(0xFFF2A65A)]));
  c.drawCircle(const Offset(820, 470), 90, Paint()..color = const Color(0xFFFFE08A));
  c.drawRect(const Rect.fromLTWH(0, h * 0.58, w, h * 0.42),
      Paint()..color = const Color(0xFF2E4A3A));
  final hill = Path()
    ..moveTo(0, 560)
    ..quadraticBezierTo(300, 380, 640, 560)
    ..close();
  c.drawPath(hill, Paint()..color = const Color(0xFF233A2E));
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(380, 690, 300, 80), const Radius.circular(10)),
      Paint()..color = const Color(0xFFF5F5F5));
  final tp = TextPainter(
    text: const TextSpan(
        text: '34 ABC 123',
        style: TextStyle(
            fontSize: 52, color: Color(0xFF111111), fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, const Offset(395, 700));
  final im = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await im.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  late String path;

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    Directory(out).createSync(recursive: true);
    final dir = Directory.systemTemp.createTempSync('faz32_shots');
    path = '${dir.path}/manzara.png';
  });

  Future<void> tapKey(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name,
      Future<void> Function(WidgetTester) after) async {
    if (!File(path).existsSync()) {
      File(path).writeAsBytesSync((await tester.runAsync(_photo))!);
    }
    tester.view.physicalSize = const Size(400, 820) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ImageEditScreen(path: path),
      ),
    ));
    for (var i = 0;
        i < 40 && find.byKey(const ValueKey('ied-canvas')).evaluate().isEmpty;
        i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await after(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
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

  testWidgets('kırp + serbest açı', (t) => shot(t, 'kirp_aci', (t) async {
        final s = find.byKey(const ValueKey('ied-angle'));
        final g = await t.startGesture(t.getCenter(s));
        await g.moveBy(const Offset(30, 0));
        await t.pump();
        // Izgara sürüklerken görünür: parmak kalkmadan çek.
        await t.runAsync(() async {});
        addTearDown(g.up);
      }));

  testWidgets('ayarla', (t) => shot(t, 'ayarla', (t) async {
        await t.tap(find.text('Ayarla'));
        await t.pumpAndSettle();
        await tapKey(t, find.byKey(const ValueKey('adj-temperature')));
        await t.drag(find.byKey(const ValueKey('adj-slider')), const Offset(70, 0));
        await tapKey(t, find.byKey(const ValueKey('adj-vignette')));
        await t.drag(find.byKey(const ValueKey('adj-slider')), const Offset(-40, 0));
      }));

  testWidgets('filtreler', (t) => shot(t, 'filtreler', (t) async {
        await t.tap(find.text('Filtreler'));
        await t.pumpAndSettle();
        await tapKey(t, find.byKey(const ValueKey('filter-drama')));
      }));

  testWidgets('işaretle', (t) => shot(t, 'isaretle', (t) async {
        await t.tap(find.text('İşaretle'));
        await t.pumpAndSettle();
        final c = t.getCenter(find.byKey(const ValueKey('ied-canvas')));
        await tapKey(t, find.byKey(const ValueKey('tool-pixelate')));
        await t.dragFrom(c + const Offset(-35, 60), const Offset(80, 0));
        await t.pumpAndSettle();
        await tapKey(t, find.byKey(const ValueKey('tool-text')));
        await t.tapAt(c + const Offset(0, -90));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'Tatil 2026');
        await t.tap(find.text('Ekle'));
        await t.pumpAndSettle();
        await tapKey(t, find.byKey(const ValueKey('text-bg')));
      }));
}
