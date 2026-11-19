import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/audiobook/doc_chapters.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';

/// B12 madde 2 (PLAN §1.12) — açılış çözümlemesi izolatta.
///
/// 1. **Kanıt (Stopwatch):** sentetik büyük Word/Excel/Slayt belgesinin
///    çözümlemesi tek bir kareyi (16 ms) aşar → ana izlekte koşamaz.
/// 2. **Bekçi (statik tarama, mandal):** ekranlarda ve açılış servislerinde
///    çıplak (izolatsız) çözümleme çağrısı dosya başına tavanı aşamaz. Tavan
///    yalnız düşer; yeni ekran `compute`/`Isolate.run` kullanır.
/// 3. İzolat yolu ana izlektekiyle aynı sonucu verir.
void main() {
  const frameMs = 16;

  Uint8List bigDocx() => Uint8List.fromList(BlankDocs.docxWithParagraphs([
        for (var i = 0; i < 6000; i++)
          'Paragraf $i — açılış çözümlemesi ölçümü için sentetik uzun bir '
              'satır; Türkçe karakterler: çğıöşü ÇĞİÖŞÜ.',
      ], heading: true));

  Uint8List bigXlsx() {
    final cells = <int, Map<int, XlsxWriteCell>>{};
    for (var r = 0; r < 3000; r++) {
      final row = cells[r] = <int, XlsxWriteCell>{};
      for (var c = 0; c < 9; c++) {
        row[c] = XlsxWriteCell(number: (r * 10 + c).toDouble());
      }
      row[9] = XlsxWriteCell(text: 'Satır ${r + 1}');
    }
    return XlsxWriter.build([XlsxWriteSheet(name: 'Sayfa1', cells: cells)]);
  }

  Uint8List bigPptx() => PptxWriter.build([
        for (var s = 0; s < 120; s++)
          SlideDraft('Slayt ${s + 1}', [
            for (var b = 0; b < 8; b++) 'Madde $b — slayt ${s + 1} gövde metni',
          ], notes: 'Not ${s + 1}'),
      ]);

  /// Isınmadan sonra tek koşunun süresi (ms) — JIT'in ilk derleme payı
  /// sayılmasın; yine de kareyi aşıyorsa cihazda (daha yavaş) kesin aşar.
  int mainThreadMs(String label, void Function() parse) {
    parse();
    final sw = Stopwatch()..start();
    parse();
    sw.stop();
    // ignore: avoid_print
    print('B12 m.2 ana izlek çözümleme · $label: ${sw.elapsedMilliseconds} ms');
    return sw.elapsedMilliseconds;
  }

  group('kanıt: büyük belgede çözümleme bir kareyi aşar', () {
    test('Word (sayfa görünümü + mobil editör)', () {
      final bytes = bigDocx();
      expect(
          mainThreadMs('DocxEditor.parse+viewBytes',
              () => DocxEditor.parse(bytes).viewBytes()),
          greaterThan(frameMs));
      expect(mainThreadMs('DocxDocument.parse', () => DocxDocument.parse(bytes)),
          greaterThan(frameMs));
    });

    test('Excel', () {
      final bytes = bigXlsx();
      expect(mainThreadMs('XlsxEditor.parse', () => XlsxEditor.parse(bytes)),
          greaterThan(frameMs));
    });

    test('Slayt', () {
      final bytes = bigPptx();
      expect(mainThreadMs('PptxEditor.parse', () => PptxEditor.parse(bytes)),
          greaterThan(frameMs));
    });
  });

  group('izolat yolu aynı sonucu verir', () {
    test('Word açılış/taslak: openForView izolatta', () async {
      final bytes = bigDocx();
      final opened = await DocxEditor.openForView(bytes);
      expect(DocxEditor.debugOpenedInIsolate, isTrue);
      expect(opened.editor.paragraphs.length,
          DocxEditor.parse(bytes).paragraphs.length);
    });

    test('sesli kitap bölümleri (docx/pptx) izolatta, ana izlekle aynı',
        () async {
      final dir = Directory.systemTemp.createTempSync('b12_chapters');
      addTearDown(() => dir.deleteSync(recursive: true));
      final docx = bigDocx();
      final pptx = bigPptx();
      final dPath = '${dir.path}/kitap.docx';
      final pPath = '${dir.path}/sunum.pptx';
      File(dPath).writeAsBytesSync(docx);
      File(pPath).writeAsBytesSync(pptx);

      String flat(List<AudioChapter> l) =>
          [for (final c in l) '${c.title}|${c.text}'].join('\n');
      expect(flat(await DocChapters.load(dPath)),
          flat(DocChapters.docxChapters((bytes: docx, name: 'kitap'))));
      expect(flat(await DocChapters.load(pPath)),
          flat(DocChapters.pptxChapters((bytes: pptx, notes: true))));
    });
  });

  group('bekçi: ekranlarda izolatsız çözümleme yok (mandal)', () {
    // Çıplak çağrı = `Ad.parse(` biçimi. `compute(PptxEditor.parse, b)` gibi
    // koparma (tear-off) eşleşmez — izolata giden yol odur.
    final call = RegExp(r'\b(DocxEditor\.parse|DocxDocument\.parse|'
        r'PptxEditor\.parse|XlsxEditor\.parse|XlsxEditor\.fromCsv|'
        r'XlsxReader\.read|XlsLegacy\.tryParse|LegacyText\.from(Doc|Ppt))\(');

    /// Dosya → izinli çıplak çağrı sayısı (YALNIZ DÜŞER). Her biri izolatta
    /// koşan statik yardımcının gövdesi ya da izolat kurulamazsa yedek yol.
    const ceilings = <String, int>{
      // _decodeLegacy (compute) 3 + _decodeSpreadsheet (compute) 1.
      'lib/services/file_service.dart': 4,
      // docxChapters / pptxChapters (compute).
      'lib/services/audiobook/doc_chapters.dart': 2,
      // _readAndParse 2 + _parseDraft 2 (ikisi de compute ile).
      'lib/screens/editors/spreadsheet_editor_screen.dart': 4,
      // _parse (compute ile; parseInIsolate=false yalnız testte).
      'lib/screens/editors/word_mobile_editor_screen.dart': 1,
      // _parseDeck: izolat kurulamazsa yedek.
      'lib/screens/editors/slides/pro.dart': 1,
      // Word `_rerender` (resim ekle/sil) B12 m.3'te openForView'a geçti → 0.
    };

    test('dosya başına tavan aşılmaz; tavan bayatlamaz', () {
      final files = <File>[
        for (final root in ['lib/screens', 'lib/widgets'])
          for (final f in Directory(root).listSync(recursive: true))
            if (f is File && f.path.endsWith('.dart')) f,
        File('lib/services/file_service.dart'),
        for (final f in Directory('lib/services/audiobook').listSync())
          if (f is File && f.path.endsWith('.dart')) f,
      ];
      final counts = <String, int>{};
      for (final f in files) {
        var n = 0;
        for (final raw in f.readAsLinesSync()) {
          final c = raw.indexOf('//');
          final code = c < 0 ? raw : raw.substring(0, c);
          n += call.allMatches(code).length;
        }
        if (n > 0) counts[f.path.replaceAll('\\', '/')] = n;
      }
      final over = [
        for (final e in counts.entries)
          if (e.value > (ceilings[e.key] ?? 0))
            '${e.key}: ${e.value} > ${ceilings[e.key] ?? 0}',
      ];
      expect(over, isEmpty,
          reason: 'Açılış/taslak çözümlemesi ana izlekte: compute(statikİşlev, '
              'bayt) ya da Isolate.run kullan (B12 m.2).');
      // Mandal: sayı düştüyse tavan da düşürülsün (bayat tavan gizli boşluk).
      final stale = [
        for (final e in ceilings.entries)
          if ((counts[e.key] ?? 0) < e.value)
            '${e.key}: ${counts[e.key] ?? 0} < ${e.value}',
      ];
      expect(stale, isEmpty, reason: 'tavanı düşür');
    });
  });
}
