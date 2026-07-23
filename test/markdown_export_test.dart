import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/markdown_export.dart';
import 'package:excel/excel.dart';
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
    Sheet sheetOf(List<int> bytes) {
      final excel = Excel.decodeBytes(bytes);
      return excel.tables[excel.tables.keys.first]!;
    }

    // Hücrenin düz metnini üretir (xlsx_editor'daki kanıtlı dönüşüm deseni).
    String txt(Data? d) {
      final v = d?.value;
      if (v is TextCellValue) return v.value.toString();
      if (v is IntCellValue) return '${v.value}';
      if (v is DoubleCellValue) return '${v.value}';
      return v?.toString() ?? '';
    }

    test('Markdown tablosu gerçek satır/sütuna açılır', () {
      const md = '| Ad | Yaş |\n| --- | --- |\n| Ali | 30 |\n| Ay | 25 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      expect(sheet.rows.length, 3); // başlık + 2 satır
      expect(txt(sheet.rows[0][0]), 'Ad');
      expect(txt(sheet.rows[2][0]), 'Ay');
    });

    test('sayısal hücre gerçek sayı olur (metin değil)', () {
      const md = '| Ürün | Adet |\n| --- | --- |\n| Kalem | 12 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      final adet = sheet.rows[1][1]!.value;
      expect(adet, isA<IntCellValue>());
      expect((adet as IntCellValue).value, 12);
    });

    test('baştaki sıfırlı dizi metin kalır', () {
      const md = '| Kod |\n| --- |\n| 007 |';
      final sheet = sheetOf(MarkdownExport.toXlsx(md));
      expect(sheet.rows[1][0]!.value, isA<TextCellValue>());
      expect(txt(sheet.rows[1][0]), '007');
    });

    test('tablo dışı içerik tek sütunlu satır olur', () {
      final sheet = sheetOf(MarkdownExport.toXlsx('# Başlık\n\n- madde bir'));
      final texts = sheet.rows.map((r) => r.isNotEmpty ? txt(r[0]) : '').toList();
      expect(texts, contains('Başlık'));
      expect(texts, contains('madde bir'));
    });

    test('boş girdi bile geçerli xlsx üretir', () {
      final bytes = MarkdownExport.toXlsx('');
      expect(bytes, isNotEmpty);
      expect(() => Excel.decodeBytes(bytes), returnsNormally);
    });
  });
}
