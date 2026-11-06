@Tags(['perf'])
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/device_profile.dart';
import 'package:dosya_okuyucu/services/xlsx/xlsx_stream.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 42 / 2 — büyük dosya: xlsx akış okuma + bellek tavanı testleri
/// (performans anayasası k.10). Cihazda 100 MB'lık gerçek dosya:
/// `python3 tool/make_test_tree.py <hedef> --buyuk` (CIHAZ_TESTI Faz 42).
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lf_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File writeXlsx(int rows, int cols) {
    final cells = <int, Map<int, XlsxWriteCell>>{};
    for (var r = 0; r < rows; r++) {
      final row = cells[r] = <int, XlsxWriteCell>{};
      for (var c = 0; c < cols - 1; c++) {
        row[c] = XlsxWriteCell(number: (r * cols + c).toDouble());
      }
      row[cols - 1] = XlsxWriteCell(text: 'Satır ${r + 1}');
    }
    final f = File('${tmp.path}/t.xlsx')
      ..writeAsBytesSync(
          XlsxWriter.build([XlsxWriteSheet(name: 'Veri', cells: cells)]));
    return f;
  }

  test('değerler: paylaşılan dize, satır içi dize, mantıksal, çok sayfa', () async {
    String x(String body) =>
        '<?xml version="1.0" encoding="UTF-8"?>$body';
    const ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"';
    const rns =
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
    final a = Archive()
      ..add(ArchiveFile.string('xl/workbook.xml',
          x('<workbook $ns $rns><sheets><sheet name="Bir" sheetId="1" r:id="rId1"/>'
              '<sheet name="İki" sheetId="2" r:id="rId2"/></sheets></workbook>')))
      ..add(ArchiveFile.string('xl/_rels/workbook.xml.rels',
          x('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Id="rId1" Target="worksheets/a.xml"/>'
              '<Relationship Id="rId2" Target="/xl/worksheets/b.xml"/></Relationships>')))
      ..add(ArchiveFile.string('xl/sharedStrings.xml',
          x('<sst $ns><si><t>merhaba</t></si><si><r><t>zengin </t></r><r><t>metin</t></r>'
              '<rPh><t>FONETİK</t></rPh></si><si/></sst>')))
      ..add(ArchiveFile.string('xl/worksheets/a.xml',
          x('<worksheet $ns><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c>'
              '<c r="C1"><v>3.5</v></c></row><row r="4"><c r="B4" t="s"><v>1</v></c>'
              '<c r="AA4" t="b"><v>1</v></c><c r="AB4" t="inlineStr"><is><t>iç</t></is></c>'
              '</row></sheetData></worksheet>')))
      ..add(ArchiveFile.string('xl/worksheets/b.xml',
          x('<worksheet $ns><sheetData><row><c><v>7</v></c><c><v>8</v></c></row>'
              '</sheetData></worksheet>')));
    final f = File('${tmp.path}/m.xlsx')..writeAsBytesSync(ZipEncoder().encodeBytes(a));
    final r = await XlsxStream.read(f.path, tempDir: tmp.path, maxCells: 1000);
    expect(r.truncated, isFalse);
    expect(r.sheets.map((s) => s.name), ['Bir', 'İki']);
    final s = r.sheets.first.cells;
    expect(s[0]![0], 'merhaba');
    expect(s[0]![2], '3.5');
    expect(s[3]![1], 'zengin metin');
    expect(s[3]![26], 'TRUE');
    expect(s[3]![27], 'iç');
    expect(r.sheets[1].cells[0], {0: '7', 1: '8'});
    expect(r.cellCount, 7);
    // Geçici açılmış XML'ler silindi.
    expect(tmp.listSync().whereType<Directory>(), isEmpty);
  });

  test('hücre tavanı: akış keser, truncated; düzenleyici kaydetmez', () async {
    final f = writeXlsx(20000, 5); // 100 bin hücre
    final r = await XlsxStream.read(f.path, tempDir: tmp.path, maxCells: 12000);
    expect(r.truncated, isTrue);
    expect(r.cellCount, 12000);
    final ed = XlsxEditor.fromStream(r);
    expect(ed.truncated, isTrue);
    expect(ed.sheets.first.rows[0][4], 'Satır 1');
  });

  test('bellek tavanı: 300 bin hücre akışla okunur, RSS artışı sınırlı', () async {
    final f = writeXlsx(60000, 5);
    final before = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    final r = await XlsxStream.read(f.path,
        tempDir: tmp.path, maxCells: const PerfBudget(DeviceTier.high).xlsxStreamMaxCells);
    sw.stop();
    final grew = (ProcessInfo.currentRss - before) >> 20;
    // ignore: avoid_print
    print('PERF xlsx_stream_300k_ms=${sw.elapsedMilliseconds} rss_delta_mb=$grew '
        'file_kb=${f.lengthSync() >> 10}');
    expect(r.truncated, isFalse);
    expect(r.cellCount, 300000);
    // Tam ayrıştırma bu dosyada yüzlerce MB tutar; akış yalnız hücre
    // haritası (+ GC payı). Gevşek tavan: CI gürültüsü.
    expect(grew, lessThan(400));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('bütçeler profile bağlı ve sıralı (anayasa k.3)', () {
    const low = PerfBudget(DeviceTier.low);
    const mid = PerfBudget(DeviceTier.mid);
    const high = PerfBudget(DeviceTier.high);
    expect(low.xlsxFullParseMaxBytes, lessThan(mid.xlsxFullParseMaxBytes));
    expect(mid.xlsxFullParseMaxBytes, lessThan(high.xlsxFullParseMaxBytes));
    expect(low.xlsxStreamMaxCells, lessThan(high.xlsxStreamMaxCells));
    expect(low.pdfInMemoryMaxBytes, lessThan(high.pdfInMemoryMaxBytes));
    // 100 MB xlsx hiçbir profilde tam ayrıştırılmaz (k.10).
    expect(high.xlsxFullParseMaxBytes, lessThan(100 << 20));
  });
}
