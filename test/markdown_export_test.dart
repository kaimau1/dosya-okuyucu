import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/markdown_export.dart';
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
}
