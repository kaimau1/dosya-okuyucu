import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/image_edit_screen.dart';
import 'package:dosya_okuyucu/services/image_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Faz 32: yazı nesnesi kaydetmeden önce eklenir, taşınır, düzenlenir; filtre
// ve ayar tek dokunuşla uygulanır/sıfırlanır.
void main() {
  late String path;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('ied_screen');
    path = '${dir.path}/foto.png';
    final im = img.Image(width: 300, height: 200);
    img.fill(im, color: img.ColorRgb8(90, 140, 200));
    File(path).writeAsBytesSync(img.encodePng(im));
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 800) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ImageEditScreen(path: path),
    ));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('ied-canvas')).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
    }
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
  }

  ImageEdits edits() => ImageEditScreen.debugEdits!;

  /// Yatay kaydırılan şeritteki öğe önce görünür yapılır.
  Future<void> tapKey(WidgetTester t, Object key) async {
    final f = key is Finder ? key : find.byKey(ValueKey<String>(key as String));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('yazı nesnesi: ekle → taşı → düzenle → yazı tipi/arka plan', (t) async {
    await open(t);
    await t.tap(find.text('İşaretle'));
    await t.pumpAndSettle();
    await tapKey(t, 'tool-text');
    final canvas = find.byKey(const ValueKey('ied-canvas'));
    final c = t.getCenter(canvas);
    await t.tapAt(c);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Merhaba');
    await t.tap(find.text('Ekle'));
    await t.pumpAndSettle();
    final added = edits().marks.single;
    expect((added.kind, added.text), (MarkKind.text, 'Merhaba'));

    // Taşı: seçili yazıyı 60 dp sağa sürükle.
    await t.timedDragFrom(c, const Offset(60, 0), const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    final moved = edits().marks.single;
    expect(moved.points.single.dx, greaterThan(added.points.single.dx + 0.1));
    expect(moved.points.single.dy, closeTo(added.points.single.dy, 0.01));

    // Seçiliyken dokun → düzenle.
    await t.tapAt(c + const Offset(60, 0));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Merhaba dünya');
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(edits().marks.single.text, 'Merhaba dünya');

    await tapKey(t, find.text('Tırnaklı'));
    await tapKey(t, 'text-bg');
    expect((edits().marks.single.font, edits().marks.single.background),
        ('serif', true));
    // Geri al: arka plan kalkar, yazı yerinde kalır.
    await t.tap(find.byTooltip('Geri al'));
    await t.pumpAndSettle();
    expect(edits().marks.single.background, isFalse);
  });

  testWidgets('filtre seç + ayar kaydır, tek dokunuşla sıfırla', (t) async {
    await open(t);
    await t.tap(find.text('Filtreler'));
    await t.pumpAndSettle();
    await tapKey(t, 'filter-sepia');
    expect(edits().filter, 'sepia');
    expect(find.byKey(const ValueKey('filter-strength')), findsOneWidget);

    await t.tap(find.text('Ayarla'));
    await t.pumpAndSettle();
    await tapKey(t, 'adj-vignette');
    await t.drag(find.byKey(const ValueKey('adj-slider')), const Offset(80, 0));
    await t.pumpAndSettle();
    expect(edits().vignette, greaterThan(0));
    await t.tap(find.byKey(const ValueKey('adj-reset')));
    await t.pumpAndSettle();
    expect(edits().vignette, 0);
    expect(edits().filter, 'sepia');
  });
}
