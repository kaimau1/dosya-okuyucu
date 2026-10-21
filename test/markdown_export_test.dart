import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/markdown_export.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Üretilen .docx paketinden `word/document.xml`i çıkarır.
String _documentXml(List<int> docx) {
  final archive = ZipDecoder().decodeBytes(docx);
  final file = archive.files.firstWhere((f) => f.name == 'word/document.xml');
  return utf8.decode(file.content as List<int>);
}

void main() {
  group('MarkdownExport.toDocx', () {
    test('geçerli OOXML paket üretir (üç zorunlu parça)', () {
      final docx = MarkdownExport.toDocx('Merhaba');
      final archive = ZipDecoder().decodeBytes(docx);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('_rels/.rels'));
      expect(names, contains('word/document.xml'));
    });

    test('paragraf metni belgede yer alır, ham işaret kalmaz', () {
      final xml = _documentXml(MarkdownExport.toDocx('bu **kalın** yazı'));
      expect(xml, contains('kalın'));
      expect(xml, contains('<w:b/>')); // kalın run biçimi
      expect(xml.contains('**'), isFalse); // ham yıldız yok
    });

    test('başlık kalın + büyük punto olur', () {
      final xml = _documentXml(MarkdownExport.toDocx('# Başlık'));
      expect(xml, contains('Başlık'));
      expect(xml, contains('<w:b/>'));
      expect(xml, contains('<w:sz w:val="36"/>'));
    });

    test('madde listesi bullet paragrafları üretir', () {
      final xml = _documentXml(MarkdownExport.toDocx('- bir\n- iki'));
      expect(xml, contains('bir'));
      expect(xml, contains('iki'));
      expect(xml, contains('•')); // bullet karakteri
      expect(xml, contains('<w:ind w:left="360"/>'));
    });

    test('tablo gerçek w:tbl olarak üretilir', () {
      const md = '| Ad | Yaş |\n| --- | --- |\n| Ali | 30 |';
      final xml = _documentXml(MarkdownExport.toDocx(md));
      expect(xml, contains('<w:tbl>'));
      expect(xml, contains('<w:tr>'));
      expect(xml, contains('Ali'));
      expect(xml, contains('30'));
    });

    test('XML özel karakterleri kaçırılır (bozuk paket olmaz)', () {
      final xml = _documentXml(MarkdownExport.toDocx('5 < 6 & 7 > 3'));
      expect(xml, contains('&lt;'));
      expect(xml, contains('&amp;'));
      expect(xml, contains('&gt;'));
    });

    test('başlık parametresi ilk paragraf olur', () {
      final xml = _documentXml(
          MarkdownExport.toDocx('içerik', title: 'Rapor Başlığı'));
      expect(xml, contains('Rapor Başlığı'));
      expect(xml, contains('içerik'));
    });
  });

  group('MarkdownExport.toXlsx', () {
    XlsxSheetLayout sheetOf(List<int> bytes) =>
        XlsxReader.read(Uint8List.fromList(bytes)).sheets.first;

    // Hücrenin düz metni (sayı tam sayıysa ondalıksız).
    String txt(XlsxSheetLayout s, int r, int c) {
      final cell = s.cellAt(r, c);
      if (cell == null) return '';
      if (cell.number != null) {
        final n = cell.number!;
        return n == n.roundToDouble() ? n.toInt().toString() : '$n';
      }
      return cell.text ?? '';
    }

    test('Markdown tablosu gerçek satır/sütuna açılır', () {
      const md = '| Ad | Yaş |\n| --- | --- |\n| Ali | 30 |\n| Ay | 25 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      expect(sheet.rowCount, 3); // başlık + 2 satır
      expect(txt(sheet, 0, 0), 'Ad');
      expect(txt(sheet, 2, 0), 'Ay');
    });

    test('sayısal hücre gerçek sayı olur (metin değil)', () {
      const md = '| Ürün | Adet |\n| --- | --- |\n| Kalem | 12 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      final adet = sheet.cellAt(1, 1)!;
      expect(adet.isNumeric, isTrue);
      expect(adet.number, 12);
    });

    test('baştaki sıfırlı dizi metin kalır', () {
      const md = '| Kod |\n| --- |\n| 007 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      expect(sheet.cellAt(1, 0)!.isNumeric, isFalse);
      expect(txt(sheet, 1, 0), '007');
    });

    test('tablo dışı içerik tek sütunlu satır olur', () {
      final sheet = sheetOf(MarkdownExport.toXlsx('# Başlık\n\n- madde bir'));
      final texts = [for (var r = 0; r < sheet.rowCount; r++) txt(sheet, r, 0)];
      expect(texts, contains('Başlık'));
      expect(texts, contains('madde bir'));
    });

    test('boş girdi bile geçerli xlsx üretir', () {
      final bytes = MarkdownExport.toXlsx('');
      expect(bytes, isNotEmpty);
      expect(XlsxReader.read(Uint8List.fromList(bytes)).sheets, hasLength(1));
    });
  });

  group('MarkdownExport.toCsv', () {
    test('Markdown tablosu ; ayraçlı CSV olur', () {
      const md = '| Ad | Yaş |\n| --- | --- |\n| Ali | 30 |';
      final csv = MarkdownExport.toCsv(md);
      expect(csv, 'Ad;Yaş\r\nAli;30');
    });

    test('ham Markdown işareti kalmaz', () {
      final csv = MarkdownExport.toCsv('**kalın** metin');
      expect(csv.contains('*'), isFalse);
      expect(csv, contains('kalın metin'));
    });
  });
}
