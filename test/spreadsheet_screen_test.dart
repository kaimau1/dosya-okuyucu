import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Excel ekranının duman testi.
///
/// *Niye:* bu ekran dondurulmuş bölme için bağlı kaydırmalı DÖRT bölge çiziyor
/// ve satırları sabit uzantılı tembel listeye koyuyor. Buradaki bir yerleşim
/// hatası (RenderFlex taşması, ListView iddiası) yalnız cihazda görünürdü;
/// widget testi hatayı derlemeden önce yakalar.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    // `compute` izolatı flutter_test'te asılı kalıyor → testte ana izlekte çöz.
    SpreadsheetEditorScreen.parseInIsolate = false;
    dir = await Directory.systemTemp.createTemp('sheet_test');
    path = '${dir.path}/rich_sheet.xlsx';
    await File(path)
        .writeAsBytes(File('test/fixtures/rich_sheet.xlsx').readAsBytesSync());
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(
        path: path,
        name: 'rich_sheet.xlsx',
        plainText: '',
      ),
    ));
    // Testte çözümleme senkron (izolat kapalı, dosya `readAsBytesSync` ile
    // okunuyor) → tek kare yeter.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('dosya açılır, hücreler Excel gibi çizilir', (tester) async {
    await pump(tester);

    // Birleştirilmiş başlık + donmuş satırdaki metinler görünür.
    // (İki kez: hücrede ve formül çubuğunda — açılışta A1 seçilidir.)
    expect(find.text('Başlık'), findsNWidgets(2));
    expect(find.text('Ürün'), findsWidgets);
    // Sayı biçimleri uygulanmış hâlde çizilir.
    expect(find.text('1.234,50 ₺'), findsOneWidget);
    expect(find.text('%15'), findsOneWidget);
    expect(find.text('21.07.2026'), findsOneWidget);
    // Formül kendi motorumuzla hesaplanıp biçimlenir (SUM(B3:B4) = 1484,5).
    expect(find.text('1.484,50 ₺'), findsOneWidget);
    // Satır/sütun başlıkları sabit bölgede.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('hücreye dokununca seçilir ve formül çubuğu dolar',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('%15'));
    await tester.pump();

    // Ad kutusu seçili hücreyi gösterir (C3).
    expect(find.text('C3'), findsOneWidget);
    // Formül çubuğu HAM değeri gösterir (Excel de öyle yapar).
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, '0.15');
  });

  testWidgets('gizli satır ve gizli sütun çizilmez', (tester) async {
    await pump(tester);
    // 7. satır gizli (içinde 999 var) → hiç çizilmemeli.
    expect(find.text('999'), findsNothing);
    expect(find.text('7'), findsNothing); // satır başlığı da yok
  });

  testWidgets('sayfa sekmeleri gezilebilir', (tester) async {
    await pump(tester);
    expect(find.text('Diğer'), findsOneWidget);
    await tester.tap(find.text('Diğer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('5'), findsWidgets);
  });

  group('ekrandan geniş dondurulmuş bölme (wide_freeze.xlsx)', () {
    late Directory wideDir;
    late String widePath;

    setUp(() async {
      wideDir = await Directory.systemTemp.createTemp('sheet_wide');
      widePath = '${wideDir.path}/wide_freeze.xlsx';
      await File(widePath).writeAsBytes(
          File('test/fixtures/wide_freeze.xlsx').readAsBytesSync());
    });

    tearDown(() => wideDir.deleteSync(recursive: true));

    Future<void> pumpWide(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SpreadsheetEditorScreen(
          path: widePath,
          name: 'wide_freeze.xlsx',
          plainText: '',
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('sabit bölme ekranı yemez, sağ taraf kaydırılarak görünür',
        (tester) async {
      await pumpWide(tester);
      // Yerleşim taşmamalı: eski kod sabit bölmeye 1075 px verip kaydırılan
      // bölgeye 0 px bırakıyordu (RenderFlex overflow + "sağı göremiyorum").
      expect(tester.takeException(), isNull);

      // En sağdaki hücre başta görünmez…
      expect(find.text('SONSUTUN'), findsNothing);

      // …kaydırılan bölgede gerçekten yer var: C2 hücresi (30) çizilmiş ve
      // oradan yatay sürükleyince en sağa gidilebiliyor.
      expect(find.text('30'), findsOneWidget);
      await tester.drag(find.text('30'), const Offset(-4000, 0));
      await tester.pumpAndSettle();
      expect(find.text('SONSUTUN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desteklenmeyen fonksiyon Excel\'in sonucunu gösterir',
        (tester) async {
      await pumpWide(tester);
      // TREND() bizde yok → #AD? yerine Excel'in önbelleklediği sonuç.
      expect(find.text('4242'), findsOneWidget);
      // Excel'in hata sonucu Türkçe kodla görünür.
      expect(find.text('#SAYI/0!'), findsOneWidget);
      // Desteklediğimiz formül kendi motorumuzla hesaplanır (10+20=30… A2
      // metin değil sayı: 10, B2 20, C2 30 → 60).
      expect(find.text('60'), findsWidgets);
    });

    testWidgets('⋮ menüsünden bölmeler çözülebilir', (tester) async {
      await pumpWide(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Bölmeleri çöz (sabit satır/sütun)'), findsOneWidget);
      await tester.tap(find.text('Bölmeleri çöz (sabit satır/sütun)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Bölme kalkınca A sütunu artık kaydırılan bölgededir; ızgara çizilmeye
      // devam eder (S1 hem hücrede hem formül çubuğunda görünür).
      expect(find.text('S1'), findsWidgets);
    });
  });

  test('XlsxEditor gerçek dosyada okuma+gösterim zincirini kurar', () {
    final bytes = File('test/fixtures/rich_sheet.xlsx').readAsBytesSync();
    final editor = XlsxEditor.parse(Uint8List.fromList(bytes));
    final sheet = editor.sheets.firstWhere((s) => s.name == 'Veri');

    expect(sheet.frozenRows, 2);
    expect(sheet.frozenCols, 1);
    expect(sheet.isRowHidden(6), isTrue);
    expect(sheet.isColHidden(4), isTrue);

    // Ham değer formül motoruna gider, gösterim biçimlenir.
    expect(sheet.rawAt(2, 1), '1234.5');
    expect(sheet.viewAt(2, 1, '1234.5').text, '1.234,50 ₺');
    expect(sheet.rawAt(4, 1), '=SUM(B3:B4)');
    // Motorumuz hesaplayamasa bile Excel'in önbelleklediği sonuç var.
    expect(sheet.cachedResultAt(4, 1), '1484.5');

    final style = sheet.styleAt(0, 0)!;
    expect(style.bold, isTrue);
    expect(style.hAlign, XlsxHAlign.center);
    expect(style.background, isNotNull);

    expect(sheet.validationAt(2, 0)?.options, ['Kalem', 'Defter', 'Silgi']);
    expect(sheet.condRuleAt(2, 1)?.type, 'cellIs');
  });
}
