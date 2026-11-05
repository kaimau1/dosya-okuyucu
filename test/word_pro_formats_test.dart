import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile/word_reader.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_export_formats.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 37 madde 11 — ODT/RTF/MD/TXT dışa aktarımı + okuma kipi.
DocxDocument _report() => DocxDocument.parse(
    DocxTemplates.build('report', now: DateTime(2026, 11, 5)));

void main() {
  test('Markdown: başlık, madde, tablo, alıntı', () {
    final md = DocxExportFormats.toMarkdown(_report());
    expect(md, contains('Rapor Başlığı'));
    expect(md, contains('# Özet'));
    expect(md, contains('## Ana bulgular'));
    expect(md, contains('- Birinci bulgu\n- İkinci bulgu'));
    expect(md, contains('| **Kalem** | **Değer** | **Pay** |'));
    expect(md, contains('> Öne çıkan'));
  });

  test('RTF: ASCII, Türkçe \\u kaçışı, tablo satırı', () {
    final rtf = DocxExportFormats.toRtf(_report());
    expect(rtf, startsWith('{\\rtf1'));
    expect(rtf.codeUnits.every((c) => c < 128), isTrue);
    expect(rtf, contains('\\u287?')); // ğ
    expect(rtf, contains('\\trowd'));
    expect(rtf.trim(), endsWith('}'));
  });

  test('ODT: mimetype ilk ve sıkıştırmasız, içerik geçerli XML', () {
    final odt = DocxExportFormats.toOdt(_report());
    final a = ZipDecoder().decodeBytes(odt);
    expect(a.files.first.name, 'mimetype');
    expect(utf8.decode(a.files.first.content as List<int>),
        'application/vnd.oasis.opendocument.text');
    final content = utf8.decode(a.files.firstWhere((f) => f.name == 'content.xml').content as List<int>);
    expect(content, contains('text:outline-level="1"'));
    expect(content, contains('<table:table '));
    final which = Process.runSync('which', ['soffice']);
    if (which.exitCode != 0) return;
    final dir = Directory.systemTemp.createTempSync('odt');
    try {
      final f = File('${dir.path}/r.odt')..writeAsBytesSync(odt);
      final r = Process.runSync('soffice',
          ['--headless', '--convert-to', 'txt:Text (encoded):UTF8', '--outdir', dir.path, f.path]);
      expect(r.exitCode, 0);
      expect(File('${dir.path}/r.txt').readAsStringSync(), contains('Bulgular'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('düz metin: liste etiketi ve tablo sekmeli', () {
    final t = DocxExportFormats.toText(_report());
    expect(t, contains('Kalem\tDeğer\tPay'));
  });

  testWidgets('okuma kipi: tembel liste, gece zemini', (t) async {
    SharedPreferences.setMockInitialValues({'word_reader_theme': 2});
    await t.pumpWidget(MaterialApp(
        home: WordReaderScreen(doc: _report(), title: 'Rapor')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-reader-list')), findsOneWidget);
    expect(find.textContaining('Özet'), findsWidgets);
    final scaffold = t.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(Colors.white));
    await t.tap(find.byKey(const ValueKey('word-reader-bigger')));
    await t.pump();
  });
}
