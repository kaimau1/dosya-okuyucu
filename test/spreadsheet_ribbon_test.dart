import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/office_ribbon.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Excel şeridi (2026-08-07 kullanıcı turu): sekmeler, yazı tipi/punto ve
/// **görünür zoom** — pinch'ten başka bir yol olmadığı için kullanıcı "zoom
/// yok" diyordu.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    dir = await Directory.systemTemp.createTemp('ribbon_test');
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
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SpreadsheetEditorScreen(
          path: path, name: 'rich_sheet.xlsx', plainText: ''),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('şerit Excel sekmelerini gösterir', (tester) async {
    await pump(tester);
    expect(find.byType(OfficeRibbon), findsOneWidget);
    for (final tab in ['Giriş', 'Ekle', 'Veri', 'Görünüm']) {
      // "Veri" hem sekme hem sayfa adı olabilir → şeridin İÇİNDE aranır.
      expect(
        find.descendant(
            of: find.byType(OfficeRibbon), matching: find.text(tab)),
        findsOneWidget,
        reason: '$tab sekmesi yok',
      );
    }
    // Giriş sekmesi açık: kalın/italik simgeleri şeritte durur.
    expect(find.byIcon(OfficeIcons.bold), findsOneWidget);
    expect(find.byIcon(OfficeIcons.italic), findsOneWidget);
  });

  testWidgets('Görünüm sekmesindeki + / − düğmeleri ızgarayı ölçekler',
      (tester) async {
    await pump(tester);
    double cellWidth() =>
        tester.widget<SheetCell>(find.byType(SheetCell).first).width;
    final before = cellWidth();

    await tester.tap(find.descendant(
        of: find.byType(OfficeRibbon), matching: find.text('Görünüm')));
    await tester.pumpAndSettle();
    // %100 hem şeritte hem (sönük) zoom rozetinde yazar.
    expect(
        find.descendant(
            of: find.byType(OfficeRibbon), matching: find.text('%100')),
        findsOneWidget);

    await tester.tap(find.byIcon(OfficeIcons.zoomIn));
    await tester.pumpAndSettle();
    expect(cellWidth(), greaterThan(before));
    // Yüzde göstergesi de güncellenmeli (kullanıcının tek geri bildirimi).
    expect(
        find.descendant(
            of: find.byType(OfficeRibbon), matching: find.text('%125')),
        findsOneWidget);

    await tester.tap(find.byIcon(OfficeIcons.zoomOut));
    await tester.pumpAndSettle();
    expect(cellWidth(), closeTo(before, 0.01));
  });

  testWidgets('yazı puntosu şeritten büyütülür ve geri alınır', (tester) async {
    await pump(tester);
    double? sizeOfA1() =>
        tester.widget<SheetCell>(find.byType(SheetCell).first).style?.fontSize;
    final before = sizeOfA1();

    // A1 seçili açılır. Punto büyütme düğmesi Giriş sekmesinde.
    await tester.ensureVisible(find.byIcon(OfficeIcons.fontGrow));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(OfficeIcons.fontGrow));
    await tester.pumpAndSettle();
    expect(sizeOfA1(), (before ?? 11) + 1);

    await tester.tap(find.byIcon(OfficeIcons.undo));
    await tester.pumpAndSettle();
    expect(sizeOfA1(), before);
  });
}
