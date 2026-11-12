import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/webview_guard.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/office_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// **G6.6 — kötü niyetli DOCX** (Güvenlik planı, 2026-11-12).
///
/// İçinde dış görsel (`http://…`, `TargetMode="External"`), `javascript:`
/// bağlantısı ve `<script>` içeren altChunk HTML parçası olan belge
/// (testte üretilir — depoya ikili dosya girmez). Beklenen: açarken ağ
/// isteği yok, betik HTML çıktısına girmez, `javascript:` gezintisi yok.
void main() {
  Uint8List evilDocx() {
    final base = ZipDecoder().decodeBytes(BlankDocs.blankDocx());
    final out = Archive();
    for (final f in base.files) {
      if (!f.isFile) continue;
      var bytes = f.content as List<int>;
      if (f.name == 'word/_rels/document.xml.rels') {
        bytes = utf8.encode(utf8.decode(bytes).replaceFirst(
            '</Relationships>',
            '<Relationship Id="rIdEvilImg" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
                'Target="http://evil.example/beacon.png" TargetMode="External"/>'
                '<Relationship Id="rIdEvilJs" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
                'Target="javascript:alert(1)" TargetMode="External"/>'
                '<Relationship Id="rIdEvilAlt" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/aFChunk" '
                'Target="evil.html"/>'
                '</Relationships>'));
      } else if (f.name == 'word/document.xml') {
        final xml = utf8.decode(bytes).replaceFirst('<w:document ',
            '<w:document xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ');
        final i = xml.indexOf('<w:body>') + '<w:body>'.length;
        bytes = utf8.encode('${xml.substring(0, i)}'
            '<w:p><w:hyperlink r:id="rIdEvilJs"><w:r><w:t>tikla</w:t></w:r></w:hyperlink></w:p>'
            '<w:p><w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
            '<wp:extent cx="100" cy="100"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<a:graphicData><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            '<pic:blipFill><a:blip r:link="rIdEvilImg"/></pic:blipFill></pic:pic></a:graphicData></a:graphic>'
            '</wp:inline></w:drawing></w:r></w:p>'
            '<w:altChunk r:id="rIdEvilAlt"/>'
            '<w:p><w:r><w:t>govde</w:t></w:r></w:p>'
            '${xml.substring(i)}');
      }
      out.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }
    const html = '<html><body><script>fetch("http://evil.example")</script>x</body></html>';
    out.addFile(ArchiveFile('word/evil.html', html.length, utf8.encode(html)));
    return Uint8List.fromList(ZipEncoder().encode(out));
  }

  test('açma ve HTML\'e çevirme ağa dokunmaz, betik çıktıya girmez', () async {
    final bytes = evilDocx();
    var httpClients = 0;
    await HttpOverrides.runZoned(() async {
      final editor = DocxEditor.parse(bytes);
      expect(editor.paragraphs.map((p) => p.text), contains('govde'));
      final doc = DocxDocument.parse(bytes);
      expect(doc.paras, isNotEmpty);
      final html = OfficeHtml.docx(bytes);
      expect(html.toLowerCase(), isNot(contains('<script')));
      expect(html, isNot(contains('evil.example')));
      expect(html, isNot(contains('javascript:')));
    }, createHttpClient: (_) {
      httpClients++;
      throw StateError('ağ isteği yapılmamalı');
    });
    expect(httpClients, 0);
  });

  test('javascript: ve file: gezintisi WebView\'da açılmaz', () {
    const page = '/assets/word/viewer.html';
    expect(WebViewGuard.allowNavigation('javascript:alert(1)', page), isFalse);
    expect(WebViewGuard.allowNavigation('file:///sdcard/evil.html', page), isFalse);
    expect(WebViewGuard.externalSchemes, isNot(contains('javascript')));
  });
}
