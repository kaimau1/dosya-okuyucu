import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
import 'support/xlsx_fixture.dart';

/// Faz 33 — donanım klavyesiyle ızgara: ok, ⇧+ok, Ctrl+ok, yazmaya başla, ↵,
/// Delete, F2.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('excel_kbd');
    path = '${dir.path}/k.xlsx';
    await File(path).writeAsBytes(xlsxFrom({
      'A1': 11,
      'A2': 22,
      'A3': 33,
      'B1': 'Elma',
    }));
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(1600, 1200);
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(path: path, name: 'k.xlsx', plainText: ''),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Finder cellText(String s) => find
      .ancestor(of: find.text(s), matching: find.byType(SheetCell))
      .first;
  Finder editor() => find.byKey(const ValueKey('floating-cell-editor'));
  String bar(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField).first).controller!.text;

  Future<void> key(WidgetTester t, LogicalKeyboardKey k,
      {bool shift = false, bool ctrl = false}) async {
    if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(k);
    if (ctrl) await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
  }

  testWidgets('oklar seçimi yürütür; Ctrl+↓ veri kenarına; yaz → hücreye; ↵ yazar',
      (t) async {
    await pump(t);
    // A1 açılışta seçili: ona dokunmak düzenlemeyi açardı → önce B1.
    await t.tap(cellText('Elma'));
    await t.pump(const Duration(milliseconds: 400));
    expect(bar(t), 'Elma');
    await key(t, LogicalKeyboardKey.arrowLeft);
    expect(bar(t), '11');
    await key(t, LogicalKeyboardKey.arrowDown, ctrl: true);
    expect(bar(t), '33', reason: 'Ctrl+↓ dolu bloğun son hücresi');
    await key(t, LogicalKeyboardKey.arrowDown);
    expect(bar(t), '');
    // Yazmaya başla: editör açılır, içerik basılan harfle değişir.
    await t.sendKeyEvent(LogicalKeyboardKey.digit4, character: '4');
    await t.pump();
    expect(editor(), findsOneWidget);
    await t.enterText(
        find.descendant(of: editor(), matching: find.byType(TextField)), '44');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('44'), findsWidgets);
  });

  testWidgets('⇧+ok aralık seçer, Delete içeriği siler', (t) async {
    await pump(t);
    await t.tap(cellText('Elma'));
    await t.pump(const Duration(milliseconds: 400));
    await key(t, LogicalKeyboardKey.arrowLeft);
    await key(t, LogicalKeyboardKey.arrowDown, shift: true);
    await key(t, LogicalKeyboardKey.delete);
    await t.pump(const Duration(milliseconds: 100));
    Finder inCell(String v) =>
        find.ancestor(of: find.text(v), matching: find.byType(SheetCell));
    expect(inCell('11'), findsNothing);
    expect(inCell('22'), findsNothing);
    expect(cellText('33'), findsOneWidget);
  });

  testWidgets('Ctrl+/ kısayol yardım sayfasını açar (Excel ek tuşlarıyla)',
      (t) async {
    await pump(t);
    await t.tap(cellText('Elma'));
    await t.pump(const Duration(milliseconds: 400));
    await key(t, LogicalKeyboardKey.slash, ctrl: true);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('shortcut-help')), findsOneWidget);
    expect(find.text('Klavye kısayolları'), findsOneWidget);
    expect(find.text('F2'), findsOneWidget);
    expect(find.text('Ctrl+S'), findsOneWidget);
    // Geri alınacak bir şey yokken Ctrl+Z bağlı değil → listede de yok.
    expect(find.text('Ctrl+Z'), findsNothing);
  });
}
