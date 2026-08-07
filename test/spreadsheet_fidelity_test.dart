import 'dart:io';

import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Gerçek Excel gibi görünme** turu (kullanıcı ekran görüntüsü 2026-08-07:
/// bir rotasyon planı dosyası Excel'de başlığı komşuya sarkmış ve satırları
/// içeriğe göre yükselmiş hâlde görünüyordu; bizde ikisi de yoktu).
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    dir = await Directory.systemTemp.createTemp('sheet_fidelity');
    path = '${dir.path}/plan.xlsx';

    // Gerçek dosyanın küçük kopyası: A1'de sütuna sığmayan başlık (B1 boş),
    // A2'de satır sonu taşıyan çok satırlı bir hücre — İKİSİNDE DE dosya
    // satır yüksekliği vermiyor (üreticilerin çoğu vermez; yüksekliği açan
    // Excel'in kendisidir).
    final bytes = XlsxWriter.build(
      [
        XlsxWriteSheet(
          name: 'Plan',
          cells: {
            0: {0: const XlsxWriteCell(text: 'Rotasyon Planı 2026-2027')},
            1: {
              0: const XlsxWriteCell(
                text: '15.02.2027 - 14.03.2027 Kardiyoloji\n'
                    '15.03.2027 - 14.04.2027 FTR\n'
                    '15.04.2027 - 14.05.2027 Acil',
                style: 1,
              ),
            },
            2: {
              0: const XlsxWriteCell(text: 'Uzun bir açıklama satırı burada'),
              1: const XlsxWriteCell(text: 'Dolu'),
            },
          },
          colWidths: {0: 10, 1: 10, 2: 10},
        ),
      ],
      styles: const [
        XlsxWriteStyle(),
        XlsxWriteStyle(wrap: true, vAlign: 'top'),
      ],
    );
    await File(path).writeAsBytes(bytes);
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    dir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpreadsheetEditorScreen(
        path: path,
        name: 'plan.xlsx',
        plainText: '',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  SheetCell cellAt(WidgetTester tester, int row, int col) =>
      tester.widgetList<SheetCell>(find.byType(SheetCell)).firstWhere(
            (c) => c.row == row && c.col == col,
            orElse: () => throw StateError('hücre $row,$col çizilmedi'),
          );

  testWidgets('sütuna sığmayan başlık boş komşunun üstüne sarkar',
      (tester) async {
    await pump(tester);

    final title = cellAt(tester, 0, 0);
    expect(title.spillRight, greaterThan(0),
        reason: 'A1 başlığı B1 boşken kırpılmamalı');
    // Sarkmanın altındaki hücre kendi ızgara çizgisini çizmez.
    expect(cellAt(tester, 0, 1).showGridLines, isFalse);

    // A3'ün komşusu DOLU (B3) → taşma yok, kırpılır.
    expect(cellAt(tester, 2, 0).spillRight, 0);
  });

  testWidgets('çok satırlı hücre satırı yükseltir (otomatik yükseklik)',
      (tester) async {
    await pump(tester);

    final normal = cellAt(tester, 0, 0).height;
    final wrapped = cellAt(tester, 1, 0).height;
    expect(wrapped, greaterThan(normal * 2),
        reason: 'üç satırlık içerik tek satır yüksekliğinde kalmamalı');
  });
}
