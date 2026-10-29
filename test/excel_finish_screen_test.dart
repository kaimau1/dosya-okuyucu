import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// Faz 27 kalanı — Excel ekranı: Hücreleri biçimlendir paneli, hücre
/// stilleri, süzgeç oluştur, veri doğrulama ("Durdur"), form görünümü,
/// kılavuz çizgileri, sekme çoğaltma ve CSV'nin ızgarada düzenlenmesi.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    SpreadsheetEditorScreen.exposeForTest = true;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('xl_finish');
    path = '${dir.path}/veri.xlsx';
    final ed = XlsxEditor.blank();
    final n = ed.sheets.first.name;
    const rows = [
      ['Ad', 'Puan', 'Durum'],
      ['Ayşe', '0.5', 'Evet'],
      ['Ali', '0.25', 'Hayır'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 3; c++) {
        ed.setCell(n, r, c, rows[r][c]);
      }
    }
    File(path).writeAsBytesSync(ed.save());
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    SpreadsheetEditorScreen.exposeForTest = false;
    SpreadsheetEditorScreen.testEditor = null;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> pump(WidgetTester t, {String? file, String name = 'veri.xlsx'}) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(path: file ?? path, name: name, plainText: ''),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> tab(WidgetTester t, String label) async {
    final f = find.text(label);
    // Sekme şeridi tembel liste: hedef kurulana dek sola kaydır.
    bool offscreen() =>
        f.evaluate().isEmpty || t.getCenter(f.last).dx > 360;
    for (var i = 0; i < 8 && offscreen(); i++) {
      await t.drag(
          find.byWidgetPredicate((w) =>
              w is ListView && w.scrollDirection == Axis.horizontal).first,
          const Offset(-120, 0));
      await t.pump();
    }
    await t.ensureVisible(f.last);
    await t.tap(f.last);
    await t.pump();
  }

  Future<void> button(WidgetTester t, String key) async {
    final f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// Modelin kaydedilmiş hâli (kaydetme hattı: paket + yamalar).
  Future<XlsxEditor> saved(WidgetTester t) async =>
      XlsxEditor.parse(SpreadsheetEditorScreen.testEditor!.save());

  testWidgets('Hücreleri biçimlendir: Yüzde + dikey hiza → dosyada', (t) async {
    await pump(t);
    await t.tap(find.text('Ayşe'));
    await t.pump();
    // Puan hücresine geç (B2).
    await t.tap(find.text('0.5').evaluate().isEmpty ? find.text('0,5') : find.text('0.5'));
    await t.pump();
    await button(t, 'xl-format-cells');
    await t.tap(find.byKey(const ValueKey('xl-fc-cat-percent')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('xl-fc-dec-0')));
    await t.pump();
    expect(find.textContaining('50'), findsWidgets, reason: 'canlı önizleme');
    await t.tap(find.byKey(const ValueKey('xl-fc-apply-number')));
    await t.pumpAndSettle();
    await t.tap(find.text('Hizalama').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('xl-fc-v-top')));
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byKey(const ValueKey('xl-fc-v-top')))).pop();
    await t.pumpAndSettle();
    final ed = await saved(t);
    final s = ed.sheets.first;
    expect(s.numFmtCode(1, 1), '0%');
    expect(s.styleAt(1, 1)!.vAlign, XlsxVAlign.top);
  });

  testWidgets('Veri > Süzgeç oluştur ve Veri doğrulama listesi', (t) async {
    await pump(t);
    await t.tap(find.text('Evet'));
    await t.pump();
    await tab(t, 'Veri');
    await button(t, 'xl-filter-toggle');
    await button(t, 'xl-validation');
    await t.enterText(find.byKey(const ValueKey('xl-val-list')), 'Evet, Hayır');
    await t.tap(find.byKey(const ValueKey('xl-val-ok')));
    await t.pumpAndSettle();
    final ed = await saved(t);
    final s = ed.sheets.first;
    expect(s.layout.autoFilterRef, isNotNull);
    expect(s.validationAt(1, 2)?.options, ['Evet', 'Hayır']);
  });

  testWidgets('Görünüm > Form görünümü: kayıt düzenle, Yeni kayıt', (t) async {
    await pump(t);
    await t.tap(find.text('Ayşe'));
    await t.pump();
    await tab(t, 'Görünüm');
    await button(t, 'xl-form-view');
    expect(find.text('Kayıt 1 / 2'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('xl-form-field-0')), 'Ayşe K.');
    await t.tap(find.byKey(const ValueKey('xl-form-new')));
    await t.pumpAndSettle();
    expect(find.text('Kayıt 3 / 3'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('xl-form-field-0')), 'Can');
    await t.tap(find.byKey(const ValueKey('xl-form-done')));
    await t.pumpAndSettle();
    final ed = await saved(t);
    final s = ed.sheets.first;
    expect(s.rawAt(1, 0), 'Ayşe K.');
    expect(s.rawAt(3, 0), 'Can');
  });

  testWidgets('Kılavuz çizgileri kapat → dosyada showGridLines=0', (t) async {
    await pump(t);
    await tab(t, 'Görünüm');
    await button(t, 'xl-gridlines');
    final ed = await saved(t);
    expect(ed.sheets.first.layout.showGridLines, isFalse);
  });

  testWidgets('CSV ızgarada açılır, düzenlenir, aynı ayraçla kaydedilir',
      (t) async {
    final csv = '${dir.path}/liste.csv';
    File(csv).writeAsStringSync('Ad;Şehir\r\nAyşe;İzmir\r\n');
    await pump(t, file: csv, name: 'liste.csv');
    expect(find.text('İzmir'), findsOneWidget);
    await t.tap(find.text('İzmir'));
    await t.pump();
    // Biçim düğmesi: "CSV'de saklanmaz" uyarısı.
    await button(t, 'xl-cell-styles');
    await t.tap(find.byKey(const ValueKey('xl-style-good')));
    await t.pump();
    expect(find.byKey(const ValueKey('xl-csv-warning')), findsOneWidget);
    expect(utf8.decode(SpreadsheetEditorScreen.testEditor!.save()),
        'Ad;Şehir\r\nAyşe;İzmir\r\n');
  });
}
