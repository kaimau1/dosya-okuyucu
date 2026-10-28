import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 24 — Ekle (tablo, bağlantı, sayfa sonu), Düzen (sayfa ayarı), Bul/
/// Değiştir: gidiş-dönüş + geri al + LibreOffice açılabilirliği.
const _fixture = 'test/fixtures/office/stiller_basliklar.docx';

Uint8List _bytes() => File(_fixture).readAsBytesSync();

String _part(Uint8List bytes, String name) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == name)
    .content as List<int>);

DocxEditController _open() => DocxEditController(DocxDocument.parse(_bytes()));

/// LibreOffice belgeyi onarımsız açıp metne çevirebiliyor mu?
void _expectOpensInLibreOffice(Uint8List bytes) {
  final which = Process.runSync('which', ['soffice']);
  if (which.exitCode != 0) return;
  final dir = Directory.systemTemp.createTempSync('docx_insert');
  try {
    final f = File('${dir.path}/t.docx')..writeAsBytesSync(bytes);
    final r = Process.runSync('soffice', [
      '--headless',
      '--convert-to',
      'txt:Text',
      '--outdir',
      dir.path,
      f.path
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(File('${dir.path}/t.txt').existsSync(), isTrue);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  test('tablo ekle: kaydet → yeniden aç → hücreler yerinde, ardında paragraf',
      () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    expect(c.insertTable(2, 3), isTrue);
    final cellsBefore = c.paras.where((p) => p.cell != null).length;
    final out = c.doc.save();
    final again = DocxDocument.parse(out);
    final tables = XmlDocument.parse(_part(out, 'word/document.xml'))
        .findAllElements('w:tbl')
        .toList();
    expect(tables.length, 2); // fixture'daki + yeni
    expect(again.paras.where((p) => p.cell != null).length, cellsBefore);
    // Yeni tablo 2×3 ve tüm hücrelerde w:p var (Word zorunlu kılar).
    final fresh = tables.firstWhere(
        (t) => t.findAllElements('w:tr').length == 2 &&
            t.findAllElements('w:gridCol').length == 3);
    for (final tc in fresh.findAllElements('w:tc')) {
      expect(tc.findElements('w:p'), isNotEmpty);
    }
    // Tablo gövdede ilk paragraftan hemen sonra.
    final kids = XmlDocument.parse(_part(out, 'word/document.xml'))
        .findAllElements('w:body')
        .first
        .childElements
        .map((e) => e.name.local)
        .toList();
    expect(kids.sublist(0, 3), ['p', 'tbl', 'p']);
    _expectOpensInLibreOffice(out);
  });

  test('tablo ekle → geri al: kayıtta tablo YOK', () {
    final c = _open();
    c.insertTable(3, 3);
    c.undo();
    final out = c.doc.save();
    final n = XmlDocument.parse(_part(out, 'word/document.xml'))
        .findAllElements('w:tbl')
        .length;
    expect(n, 1);
  });

  test('bağlantı ekle: hyperlink + dış ilişki; yeniden açınca atom', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertLink('Site', 'https://example.com');
    final out = c.doc.save();
    final xml = _part(out, 'word/document.xml');
    expect(xml, contains('<w:hyperlink'));
    final rels = _part(out, 'word/_rels/document.xml.rels');
    expect(rels, contains('https://example.com'));
    expect(rels, contains('TargetMode="External"'));
    final again = DocxDocument.parse(out);
    expect(again.paras.first.atoms.any((a) => a?.kind == DocxAtomKind.link),
        isTrue);
    _expectOpensInLibreOffice(out);
  });

  test('sayfa sonu ekle', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertPageBreak();
    final xml = _part(c.doc.save(), 'word/document.xml');
    expect(xml, contains('w:type="page"'));
  });

  test('sayfa ayarı: boyut, yön, kenar boşluğu, sütun + geri al', () {
    final c = _open();
    final s0 = c.pageSetup;
    c.setPaper('letter');
    expect(c.pageSetup.paper, 'letter');
    c.setLandscape(true);
    expect(c.pageSetup.landscape, isTrue);
    expect(c.pageSetup.paper, 'letter');
    c.setMargins('narrow');
    expect(c.pageSetup.marginPreset, 'narrow');
    c.setColumns(2);
    expect(c.pageSetup.columns, 2);
    final out = c.doc.save();
    final again = DocxDocument.parse(out).pageSetup();
    expect(again.landscape, isTrue);
    expect(again.columns, 2);
    expect(again.marginPreset, 'narrow');
    _expectOpensInLibreOffice(out);
    // Geri al zinciri özgün ayara döner.
    for (var i = 0; i < 4; i++) {
      c.undo();
    }
    final back = c.pageSetup;
    expect(back.width, s0.width);
    expect(back.columns, s0.columns);
    expect(back.marginPreset, s0.marginPreset);
  });

  test('bul / tümünü değiştir (Türkçe katlama) tek geri al adımı', () {
    final c = _open();
    final hits = c.findMatches('PROJE');
    expect(hits, isNotEmpty);
    final n = c.replaceAllMatches('proje', 'Çalışma');
    expect(n, hits.length);
    expect(c.findMatches('proje'), isEmpty);
    expect(c.doc.paras.first.text, contains('Çalışma'));
    c.undo();
    expect(c.findMatches('proje'), isNotEmpty);
  });

  test('el değmemiş belge: yeni ekler tabloyu/ayarı kaydı bozmaz', () {
    final d = DocxDocument.parse(_bytes());
    d.pageSetup(); // salt okuma — XML'i kirletmemeli
    expect(d.xmlDirty, isFalse);
  });
}
