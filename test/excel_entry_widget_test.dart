import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
import 'support/xlsx_fixture.dart';

/// Faz 25 — Excel mobil gibi veri girişi: hücre üstünde yüzer editör (100 %
/// yakınlaştırmada da), iki dokunuş dili, klavye üstü çubuk (✓ ↵ ⇥ oklar),
/// uygulama içi tuş takımı, işaret kipi + renkli başvurular, Türkçe formül
/// dili, akıllı giriş, bağlam menüsü.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('excel_entry');
    path = '${dir.path}/giris.xlsx';
    await File(path).writeAsBytes(xlsxFrom({
      'A1': 11,
      'A2': 22,
      'A3': 33,
      'B1': 'Elma',
      'B2': 'Armut',
      'C1': '=SUM(A1:A3)',
    }));
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> pump(WidgetTester t, {bool keyboard = true}) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    // Klavye açık benzetimi: klavye üstü çubuk yalnız klavye varken çıkar.
    if (keyboard) t.view.viewInsets = const FakeViewPadding(bottom: 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(path: path, name: 'giris.xlsx', plainText: ''),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  // Hücrenin ORTASINA dokunulur (sağa yaslı sayının metnine değil — sağ alt
  // köşede seçim tutamağı var).
  Finder cellText(String s) => find
      .ancestor(of: find.text(s), matching: find.byType(SheetCell))
      .first;

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.tap(f);
    await t.pump();
    // FAB / panel geçiş animasyonları bitsin (kullanıcı da bekler).
    await t.pump(const Duration(milliseconds: 400));
  }

  String bar(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField).first).controller!.text;

  Finder editor() => find.byKey(const ValueKey('floating-cell-editor'));

  TextField editorField(WidgetTester t) => t.widget<TextField>(
      find.descendant(of: editor(), matching: find.byType(TextField)));

  testWidgets('100 %de seçiliye ikinci dokunuş hücrede yüzer editör açar; ✓ yazar',
      (t) async {
    await pump(t);
    await tap(t, cellText('Elma'));
    expect(editor(), findsNothing, reason: 'ilk dokunuş yalnız seçer');
    await tap(t, cellText('Elma'));
    expect(editor(), findsOneWidget);
    expect(editorField(t).style!.fontSize, greaterThanOrEqualTo(16));
    await t.enterText(find.descendant(of: editor(), matching: find.byType(TextField)), 'Kiraz');
    await t.pump();
    await tap(t, find.byKey(const ValueKey('acc-ok')));
    expect(editor(), findsNothing);
    expect(cellText('Kiraz'), findsOneWidget);
  });

  testWidgets('↵ aşağı iner ve "Giriş" kipinde açar; ⇥ sonrası ↵ satır başına döner',
      (t) async {
    await pump(t);
    await tap(t, cellText('Elma'));
    await tap(t, cellText('Elma'));
    await tap(t, find.byKey(const ValueKey('acc-enter')));
    // B2 seçili, metin tümüyle seçili: yazmak içeriği DEĞİŞTİRİR.
    expect(bar(t), 'Armut');
    final sel = editorField(t).controller!.selection;
    expect((sel.start, sel.end), (0, 'Armut'.length));
    await tap(t, find.byKey(const ValueKey('acc-tab'))); // C2
    await tap(t, find.byKey(const ValueKey('acc-tab'))); // D2
    await tap(t, find.byKey(const ValueKey('acc-enter'))); // → B3
    await t.enterText(find.descendant(of: editor(), matching: find.byType(TextField)), 'x');
    await tap(t, find.byKey(const ValueKey('acc-ok')));
    expect(cellText('x'), findsOneWidget);
    // B3'e yazıldı mı: B sütununda Elma, Armut, x alt alta.
    final ys = [for (final s in ['Elma', 'Armut', 'x']) t.getRect(cellText(s))];
    expect(ys[0].left, ys[2].left);
    expect(ys[2].top, greaterThan(ys[1].top));
  });

  testWidgets('sayı hücresinde uygulama tuş takımı; tuşlar yazar; ABC geçer', (t) async {
    await pump(t, keyboard: false);
    await tap(t, cellText('22'));
    await tap(t, cellText('22'));
    expect(find.byKey(const ValueKey('excel-keypad')), findsOneWidget);
    expect(editorField(t).keyboardType, TextInputType.none);
    // İkinci dokunuş imleci sona koyar: "22" → iki kez sil.
    await tap(t, find.byKey(const ValueKey('key-bs')));
    await tap(t, find.byKey(const ValueKey('key-bs')));
    await tap(t, find.byKey(const ValueKey('key-7')));
    await tap(t, find.byKey(const ValueKey('key-,')));
    await tap(t, find.byKey(const ValueKey('key-5')));
    expect(editorField(t).controller!.text, '7,5');
    await tap(t, find.byKey(const ValueKey('key-enter')));
    // Akıllı giriş: 7,5 sayıdır (Türkçe ızgara virgülle çizer).
    expect(cellText('7,5'), findsOneWidget);
  });

  testWidgets('işaret kipi: formülde hücreye dokunmak başvuru ekler, renkli çerçeve',
      (t) async {
    await pump(t);
    await tap(t, cellText('Armut'));
    await tap(t, cellText('Armut'));
    await t.enterText(find.descendant(of: editor(), matching: find.byType(TextField)), '=');
    await t.pump();
    await tap(t, cellText('11'));
    expect(editorField(t).controller!.text, '=A1');
    await tap(t, cellText('33'));
    expect(editorField(t).controller!.text, '=A3',
        reason: 'ardından dokunmak başvuruyu DEĞİŞTİRİR');
    final colored = t.widgetList<SheetCell>(find.byType(SheetCell))
        .where((c) => c.refColor != null);
    expect(colored, isNotEmpty);
    await tap(t, find.byKey(const ValueKey('acc-ok')));
    expect(cellText('33'), findsWidgets);
  });

  testWidgets('Türkçe arayüzde formül Türkçe gösterilir, dosyaya İngilizce gider',
      (t) async {
    await pump(t);
    await tap(t, cellText('66')); // C1 = SUM(A1:A3)
    expect(bar(t), '=TOPLA(A1:A3)');
    await tap(t, cellText('66'));
    await t.enterText(find.descendant(of: editor(), matching: find.byType(TextField)),
        '=TOPLA(A1;A2)*0,5');
    await tap(t, find.byKey(const ValueKey('acc-ok')));
    expect(cellText('16,5'), findsOneWidget);
    expect(bar(t), '=TOPLA(A1;A2)*0,5');
  });

  testWidgets('akıllı giriş: %15 yüzde biçimiyle çizilir, ham değer 0.15', (t) async {
    await pump(t);
    await tap(t, cellText('Elma'));
    await tap(t, cellText('Elma'));
    await t.enterText(find.descendant(of: editor(), matching: find.byType(TextField)), '%15');
    await tap(t, find.byKey(const ValueKey('acc-ok')));
    expect(cellText('%15'), findsOneWidget);
    expect(bar(t), '0.15');
  });

  testWidgets('uzun bas (sürüklemeden) bağlam menüsünü açar', (t) async {
    await pump(t, keyboard: false);
    await t.longPress(cellText('Elma'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('cellmenu-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('cellmenu-paste_values')), findsOneWidget);
  });
}
