import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';

import 'support/temp_dir.dart';

/// Faz 24 kalanı — Word Mobil görünüm: resim (ekle, Resim sekmesi, oran
/// kilitli tutamak), yorum, dipnot, yatay çizgi.
void main() {
  late Directory dir;

  setUp(() async {
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('word_media');
    await File('${dir.path}/r.docx').writeAsBytes(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
  });

  tearDown(() {
    WordMobileEditorScreen.pickImageForTest = null;
    WordMobileEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<DocxEditController> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      home: WordMobileEditorScreen(path: '${dir.path}/r.docx', name: 'r.docx'),
    ));
    for (var i = 0;
        i < 20 && find.byType(DocxEditorView).evaluate().isEmpty;
        i++) {
      await settle(t);
    }
    await settle(t);
    return t.widget<DocxEditorView>(find.byType(DocxEditorView)).controller;
  }

  /// Şerit sekmeleri yatay kayar (tembel liste): görünene dek kaydır.
  Future<void> tab(WidgetTester t, String label) async {
    final f = find.text(label);
    if (f.evaluate().isEmpty) {
      final sc = find
          .ancestor(
              of: find.text('Giriş').last, matching: find.byType(Scrollable))
          .first;
      await t.scrollUntilVisible(f, 60, scrollable: sc);
    }
    await t.ensureVisible(f.last);
    await t.pump();
    await t.tap(f.last);
    await t.pump();
  }

  /// Şerit içeriği yatay kayar (tembel): düğme kurulana dek kaydır.
  Future<void> button(WidgetTester t, String key) async {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isEmpty) {
      final sc = find
          .ancestor(
              of: find.byKey(const ValueKey('word-ins-table')),
              matching: find.byType(Scrollable))
          .first;
      await t.scrollUntilVisible(f, 80, scrollable: sc);
    }
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f);
  }

  testWidgets('Ekle > Resim → Resim sekmesi; tutamakla küçült (oran kilitli)',
      (t) async {
    final png = File('test/fixtures/media/transparent.png').readAsBytesSync();
    WordMobileEditorScreen.pickImageForTest = () async => (png, 'png');
    final c = await open(t);
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    await tab(t, 'Ekle');
    await button(t, 'word-ins-image');
    // Görsel çözme gerçek asenkron iş: sahte saatin dışında.
    for (var i = 0; i < 10 && c.selectedImage == null; i++) {
      await settle(t);
    }
    final img = c.selectedImage;
    expect(img, isNotNull);
    await settle(t);
    expect(find.text('Resim').evaluate(), isNotEmpty, reason: 'bağlamsal sekme');
    final handle = find.byKey(const ValueKey('docx-img-handle'));
    expect(handle, findsOneWidget);
    final ratio = img!.heightPt / img.widthPt;
    final g = await t.startGesture(t.getCenter(handle));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-10, 0));
      await t.pump();
    }
    await g.up();
    await t.pump();
    final after = c.selectedImage!;
    expect(after.widthPt, lessThan(img.widthPt));
    expect(after.heightPt / after.widthPt, closeTo(ratio, 0.001));
    // Sil
    await tab(t, 'Resim');
    await t.tap(find.byKey(const ValueKey('word-img-delete')));
    await t.pump();
    expect(c.selectedImage, isNull);
  });

  testWidgets('Yeni yorum → işaret görünür; işarete dokun → Yorumlar levhası',
      (t) async {
    SharedPreferences.setMockInitialValues({'word.comment_author': 'Deneme'});
    final c = await open(t);
    final p = c.paras.indexWhere((p) => p.text.length > 5);
    c.select(DocPos(p, 0), DocPos(p, 4));
    await tab(t, 'Gözden Geçir');
    await t.tap(find.byKey(const ValueKey('word-rev-new-comment')));
    await settle(t);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('word-comment-text')), 'Kontrol et');
    await t.tap(find.byKey(const ValueKey('word-text-ok')));
    await t.pumpAndSettle();
    expect(c.comments.single.text, 'Kontrol et');
    expect(c.comments.single.author, 'Deneme');
    final id = c.comments.single.id;
    final mark = find.byKey(ValueKey('docx-comment-$id'));
    await t.ensureVisible(mark);
    await t.tap(mark);
    await t.pumpAndSettle();
    expect(find.text('Kontrol et'), findsOneWidget);
  });

  testWidgets('Ekle > Dipnot ve Yatay çizgi', (t) async {
    final c = await open(t);
    final p = c.paras.indexWhere((p) => p.text.length > 5);
    c.select(DocPos(p, 2), DocPos(p, 2));
    await tab(t, 'Ekle');
    await button(t, 'word-ins-footnote');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('word-footnote-field')), 'Not');
    await t.tap(find.byKey(const ValueKey('word-text-ok')));
    await t.pumpAndSettle();
    expect(c.paras[p].atoms.whereType<DocxAtom>()
        .any((a) => a.kind == DocxAtomKind.note), isTrue);
    final n = c.paras.length;
    await button(t, 'word-ins-rule');
    await t.pump();
    expect(c.paras.length, greaterThan(n));
    expect(c.paras[p + 1].look.borderBottom, isTrue);
  });
}
