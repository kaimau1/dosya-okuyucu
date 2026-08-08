import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

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
    removeTempDir(dir);
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

    tearDown(() => removeTempDir(wideDir));

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

    testWidgets('Görünüm sekmesinden bölmeler çözülebilir', (tester) async {
      await pumpWide(tester);
      // Bölme düğmesi artık şeridin "Görünüm" sekmesinde (2026-08-07 şerit
      // turu); eskiden ⋮ menüsündeydi.
      await tester.tap(find.text('Görünüm'));
      await tester.pumpAndSettle();
      final freeze = find.byIcon(Icons.push_pin_outlined);
      expect(freeze, findsOneWidget);
      await tester.ensureVisible(freeze);
      await tester.tap(freeze);
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

  testWidgets('Bul çubuğu eşleşmeyi bulup seçimi oraya taşır', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(find.text('Bu sayfada ara'), findsOneWidget);

    // Excel'in "Bul"u gibi HAM değerde arar: ekranda "1.234,50 ₺" yazan
    // hücrenin ham değeri 1234.5'tir ve B3'tedir.
    await tester.enterText(find.byType(TextField).first, '1234.5');
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('B3'), findsOneWidget); // ad kutusu eşleşmeye taşındı

    await tester.enterText(find.byType(TextField).first, 'zzzyok');
    await tester.pump();
    expect(find.text('yok'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Bu sayfada ara'), findsNothing);
  });

  testWidgets('sütun başlığına uzun basınca genişlik diyaloğu açılır',
      (tester) async {
    await pump(tester);

    await tester.longPress(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('A sütun genişliği'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('A sütun genişliği'), findsNothing);
  });

  // ── düzenleme çekirdeği (gerçek Excel gibi) ─────────────────────────────

  /// Ekrandaki hücreyi bulup ona dokunur (aynı metin formül çubuğunda da
  /// çıkabildiği için ızgaradaki `SheetCell` içindeki eşleşme aranır).
  Future<void> tapCell(WidgetTester tester, String text) async {
    await tester.tap(find
        .descendant(of: find.byType(SheetCell), matching: find.text(text))
        .first);
    await tester.pump();
  }


  /// "Daha fazla" sayfasını açıp etiketli bir eyleme dokunur.
  Future<void> tapMore(WidgetTester tester, String label) async {
    await tester.tap(find.text('Daha fazla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('geri al/yinele düğmeleri düzenlemeyi geri sarar',
      (tester) async {
    await pump(tester);

    // Başlangıçta yapacak bir şey yok → düğmeler kapalı.
    IconButton buttonFor(IconData icon) => tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton))
            .first);
    expect(buttonFor(Icons.undo).onPressed, isNull);
    expect(buttonFor(Icons.redo).onPressed, isNull);

    await tapCell(tester, '%15');
    await tester.enterText(find.byType(TextField).first, '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('42'), findsWidgets);

    expect(buttonFor(Icons.undo).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    // Eski değer geri geldi (yüzde biçimiyle çizilir).
    expect(find.text('%15'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(find.text('%15'), findsNothing);
  });

  testWidgets('İçeriği temizle seçili hücreyi boşaltır, geri al geri getirir',
      (tester) async {
    await pump(tester);
    await tapCell(tester, '%15');

    await tapMore(tester, 'İçeriği temizle');
    expect(find.text('%15'), findsNothing);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(find.text('%15'), findsOneWidget);
  });

  /// Geri al düğmesi etkin mi (yani gerçekten bir değişiklik kaydedildi mi)?
  bool undoEnabled(WidgetTester tester) =>
      tester
          .widget<IconButton>(find
              .ancestor(
                  of: find.byIcon(Icons.undo), matching: find.byType(IconButton))
              .first)
          .onPressed !=
      null;

  /// Formül çubuğundaki ham değer (ızgara HESAPLANMIŞ değeri gösterir,
  /// formülün kendisini değil).
  String formulaBar(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller?.text ??
      '';

  testWidgets('kopyala + yapıştır ham değeri başka hücreye taşır',
      (tester) async {
    await pump(tester);
    await tapCell(tester, '%15');
    expect(formulaBar(tester), '0.15');
    await tapMore(tester, 'Kopyala');

    // Metin içeren bir hücreye yapıştır.
    await tapCell(tester, 'Ürün');
    expect(formulaBar(tester), 'Ürün');
    await tapMore(tester, 'Yapıştır');
    // **Yapıştırma yalnız DEĞERİ taşır, biçimi değil** (bilinçli sınır):
    // hedef hücrede yüzde biçimi olmadığı için "%15" değil ham 0,15 çizilir.
    expect(formulaBar(tester), '0.15');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(formulaBar(tester), 'Ürün');
  });

  testWidgets('Σ seçili hücreye TOPLA formülü yazar', (tester) async {
    await pump(tester);
    await tapCell(tester, '1.234,50 ₺');
    // Şerit yatay kayar: düğme dar ekranda görünür alanın dışında kalabilir.
    await tester.ensureVisible(find.byIcon(Icons.functions));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.functions));
    await tester.pumpAndSettle();
    // Izgara sonucu gösterir; formülün kendisi formül çubuğundadır.
    expect(formulaBar(tester), startsWith('=TOPLA('));

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(find.text('1.234,50 ₺'), findsOneWidget);
    expect(formulaBar(tester), '1234.5');
  });

  testWidgets('doldurma tutamağı sürüklenince seri yazılır', (tester) async {
    await pump(tester);
    await tapCell(tester, '%15'); // ham değeri 0.15 — tek sayı → kopyalanır
    expect(undoEnabled(tester), isFalse);

    // Tutamak `RawGestureDetector` — kaydırılabilir ızgaranın içinde arenayı
    // KAYBETMEMESİ gereken tek yer burası, o yüzden test gerçek sürükleme
    // yapar (kod yolunu değil davranışı sınar).
    final handle = find.byKey(SpreadsheetEditorScreen.fillHandleKey);
    expect(handle, findsOneWidget, reason: 'doldurma tutamağı çizilmedi');

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, 22)); // ~bir satır
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Sürükleme gerçekten doldurmaya dönüştü: değişiklik kaydedildi ve
    // seçim doldurulan alanı kapsayacak şekilde büyüdü (durum çubuğu artık
    // aralık istatistiği gösterir).
    expect(undoEnabled(tester), isTrue, reason: 'sürükleme doldurmaya dönmedi');
    expect(find.textContaining('Toplam'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(undoEnabled(tester), isFalse);
  });

  testWidgets('Bul çubuğunda Tümünü değiştir çalışır ve geri alınır',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Ürün');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Mal');
    await tester.pump();

    // Izgaradaki hücrelerde ara — "Mal" metni değiştir ALANINDA da duruyor,
    // `find.text` onu da sayardı.
    final malCells = find.descendant(
        of: find.byType(SheetCell), matching: find.text('Mal'));
    expect(malCells, findsNothing);

    await tester.tap(find.text('Tümünü değiştir'));
    await tester.pumpAndSettle();
    expect(malCells, findsWidgets);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(malCells, findsNothing);
    expect(
        find.descendant(
            of: find.byType(SheetCell), matching: find.text('Ürün')),
        findsWidgets);
  });

  test('okunmaz yazı rengi zemine göre çevrilir, bilinçli gri korunur', () {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    const darkSurface = Color(0xFF121212);

    // Koyu temada dosyadan gelen SİYAH yazı kayboluyordu → açık renge döner.
    expect(readableOn(black, darkSurface), isNot(black));
    // Dosyadan gelen beyaz dolgu üstünde açık tema yazısı da kurtarılır.
    expect(readableOn(white, white), isNot(white));
    // Beyaz üstünde siyah zaten okunur — dokunulmaz.
    expect(readableOn(black, white), black);
    // Beyaz üstünde gri BİLİNÇLİ bir seçim (oran ~3.9) — bozulmaz.
    const gray = Color(0xFF808080);
    expect(readableOn(gray, white), gray);
  });
}
