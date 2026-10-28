import 'dart:io';

import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// Faz 27 — Excel ekranı: Veri sekmesi (yinelenenleri kaldır, metni
/// sütunlara böl) ve Görünüm > Bölmeleri dondur.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    dir = await Directory.systemTemp.createTemp('xl_data');
    path = '${dir.path}/veri.xlsx';
    final ed = XlsxEditor.blank();
    final n = ed.sheets.first.name;
    const rows = [
      ['Ad', 'Şehir'],
      ['Ayşe', 'İzmir'],
      ['ayşe', 'izmir'],
      ['Ali', 'Ankara'],
      ['a;b;c', ''],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 2; c++) {
        ed.setCell(n, r, c, rows[r][c]);
      }
    }
    File(path).writeAsBytesSync(ed.save());
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    removeTempDir(dir);
  });

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(path: path, name: 'veri.xlsx', plainText: ''),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> tab(WidgetTester t, String label) async {
    final f = find.text(label);
    await t.ensureVisible(f.last);
    await t.tap(f.last);
    await t.pump();
  }

  testWidgets('Veri > Yinelenenleri kaldır: ayşe satırı gider', (t) async {
    await pump(t);
    expect(find.text('ayşe'), findsOneWidget);
    await tab(t, 'Veri');
    await t.tap(find.byKey(const ValueKey('xl-dedup')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dup-run')));
    await t.pumpAndSettle();
    expect(find.text('ayşe'), findsNothing);
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('Görünüm > İlk satırı dondur menüsü çalışır', (t) async {
    await pump(t);
    await tab(t, 'Görünüm');
    await t.tap(find.byKey(const ValueKey('xl-freeze-menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('İlk satırı dondur'));
    await t.pumpAndSettle();
    expect(tester(t), isNull);
  });
}

Object? tester(WidgetTester t) => t.takeException();
