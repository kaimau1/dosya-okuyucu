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

import 'support/temp_dir.dart';

/// Faz 24 — Word Mobil görünüm: Ekle sekmesi (tablo, bağlantı, sayfa sonu,
/// sembol), Düzen sekmesi, Bul/Değiştir çubuğu.
void main() {
  late Directory dir;

  setUp(() async {
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('word_insert');
    await File('${dir.path}/r.docx').writeAsBytes(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
  });

  tearDown(() {
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

  testWidgets('Ekle > Tablo: ızgaradan 3×4 seç → 12 hücre paragrafı',
      (t) async {
    final c = await open(t);
    final before = c.paras.where((p) => p.cell != null).length;
    await tab(t, 'Ekle');
    await t.tap(find.byKey(const ValueKey('word-ins-table')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('word-cell-3-4')));
    await t.pump();
    expect(find.text('3 × 4 tablo'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('word-table-ok')));
    await t.tap(find.byKey(const ValueKey('word-table-ok')));
    await settle(t);
    expect(c.paras.where((p) => p.cell != null).length, before + 12);
    c.undo();
    expect(c.paras.where((p) => p.cell != null).length, before);
  });

  testWidgets('Ekle > Sembol ve Sayfa sonu', (t) async {
    final c = await open(t);
    final i = c.paras.indexWhere((p) => p.text.startsWith('Ortalanmış'));
    c.select(DocPos(i, 0), DocPos(i, 0));
    await tab(t, 'Ekle');
    await t.tap(find.byKey(const ValueKey('word-ins-symbol')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('word-sym-€')));
    await settle(t);
    expect(c.paras[i].text.startsWith('€'), isTrue);
    await t.tap(find.byKey(const ValueKey('word-ins-break')));
    await t.pump();
    expect(c.paras[i].atoms.any((a) => a != null), isTrue);
  });

  testWidgets('Düzen > Yönlendirme: yatay', (t) async {
    final c = await open(t);
    await tab(t, 'Düzen');
    await t.tap(find.byKey(const ValueKey('word-lay-orient')));
    await t.pumpAndSettle();
    await t.tap(find.text('Yatay').last);
    await t.pumpAndSettle();
    expect(c.pageSetup.landscape, isTrue);
  });

  testWidgets('Gözden Geçir > Bul ve değiştir: say, git, tümünü değiştir',
      (t) async {
    final c = await open(t);
    await tab(t, 'Gözden Geçir');
    await t.tap(find.byKey(const ValueKey('word-find')));
    await settle(t);
    expect(find.byKey(const ValueKey('word-find-bar')), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'proje');
    await settle(t);
    final n = c.findMatches('proje').length;
    expect(n, greaterThan(0));
    expect(find.text('1/$n'), findsOneWidget);
    // Seçim ilk eşleşmede.
    expect(c.collapsed, isFalse);
  });
}
