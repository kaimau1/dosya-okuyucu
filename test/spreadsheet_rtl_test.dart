import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arapça bir tablo üretir; [rtl] ise `<sheetView rightToLeft="1"/>` yazılır.
Uint8List _book({required bool rtl}) {
  final excel = Excel.createExcel();
  final s = excel['Sheet1'];
  s.updateCell(CellIndex.indexByString('A1'), TextCellValue('الاسم'));
  s.updateCell(CellIndex.indexByString('B1'), TextCellValue('المبلغ'));
  s.updateCell(CellIndex.indexByString('A2'), TextCellValue('أحمد'));
  s.updateCell(CellIndex.indexByString('B2'), const DoubleCellValue(120));
  final bytes = Uint8List.fromList(excel.encode()!);
  if (!rtl) return bytes;

  final archive = ZipDecoder().decodeBytes(bytes);
  final rebuilt = Archive();
  for (final f in archive.files) {
    if (f.name != 'xl/worksheets/sheet1.xml') {
      rebuilt.addFile(f);
      continue;
    }
    final xml = utf8
        .decode(f.content as List<int>, allowMalformed: true)
        .replaceFirst('<sheetView ', '<sheetView rightToLeft="1" ');
    final data = utf8.encode(xml);
    rebuilt.addFile(ArchiveFile(f.name, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(rebuilt)!);
}

/// Üründeki (main.dart) delege listesi — Türkçe/Arapça'da MaterialLocalizations
/// bulunmazsa TextField'lar iddiayla düşer.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  group('XlsxSheet.rightToLeft', () {
    test('dosyadaki sayfa yönü okunur', () {
      expect(XlsxEditor.parse(_book(rtl: true)).sheets.first.rightToLeft,
          isTrue);
      expect(XlsxEditor.parse(_book(rtl: false)).sheets.first.rightToLeft,
          isFalse);
    });
  });

  group('genel (general) hizalama aynalanır', () {
    const style = XlsxCellStyle(); // hAlign varsayılan = general
    test('soldan sağa sayfada metin sola, sayı sağa', () {
      expect(style.alignFor(false), TextAlign.left);
      expect(style.alignFor(true), TextAlign.right);
    });

    test('sağdan sola sayfada metin sağa, sayı sola', () {
      expect(style.alignFor(false, rightToLeft: true), TextAlign.right);
      expect(style.alignFor(true, rightToLeft: true), TextAlign.left);
    });

    test('AÇIK hizalama aynalanmaz (dosyada yazan mutlaktır)', () {
      const left = XlsxCellStyle(hAlign: XlsxHAlign.left);
      expect(left.alignFor(false, rightToLeft: true), TextAlign.left);
      const right = XlsxCellStyle(hAlign: XlsxHAlign.right);
      expect(right.alignFor(false, rightToLeft: true), TextAlign.right);
    });
  });

  group('ızgara yönü', () {
    late Directory dir;

    setUp(() async {
      SpreadsheetEditorScreen.parseInIsolate = false;
      dir = await Directory.systemTemp.createTemp('sheet_rtl');
    });

    tearDown(() {
      SpreadsheetEditorScreen.parseInIsolate = true;
      dir.deleteSync(recursive: true);
    });

    Future<TextDirection> directionOf(WidgetTester tester,
        {required bool sheetRtl, required Locale locale}) async {
      final path = '${dir.path}/${sheetRtl ? 'rtl' : 'ltr'}_$locale.xlsx';
      File(path).writeAsBytesSync(_book(rtl: sheetRtl));
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: SpreadsheetEditorScreen(
          path: path,
          name: 'x.xlsx',
          plainText: '',
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return Directionality.of(tester.element(find.byType(SheetCell).first));
    }

    testWidgets('sağdan sola sayfa sağdan sola çizilir', (tester) async {
      expect(
        await directionOf(tester, sheetRtl: true, locale: const Locale('tr')),
        TextDirection.rtl,
      );
    });

    testWidgets('soldan sağa sayfa ARAPÇA arayüzde de soldan sağa kalır',
        (tester) async {
      // Yön BELGENİN özelliği. Arayüz dilinden miras alınsaydı Arapça
      // arayüzde her Excel dosyası ters çizilirdi — Excel de böyle davranmaz.
      expect(
        await directionOf(tester, sheetRtl: false, locale: const Locale('ar')),
        TextDirection.ltr,
      );
    });

    testWidgets('yön ⋮ menüsünden değiştirilebilir ve kaydetmeye girer',
        (tester) async {
      final path = '${dir.path}/toggle.xlsx';
      File(path).writeAsBytesSync(_book(rtl: false));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: SpreadsheetEditorScreen(
            path: path, name: 'x.xlsx', plainText: ''),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // Metnin kendisine değil MENÜ ÖĞESİNE dokunulur: CheckedPopupMenuItem'da
      // metin, onay simgesinin yanında dar bir kutuda durur ve merkezine
      // yapılan dokunuş menü katmanına düşebiliyor ("would not hit test").
      await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, 'Sayfa sağdan sola'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(SheetCell).first)),
        TextDirection.rtl,
      );
    });
  });
}
