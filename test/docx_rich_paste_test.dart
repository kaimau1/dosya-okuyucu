import 'dart:io';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 22/23 kalanı: kendi panomuzdan **biçimli yapıştırma** — kalın kelime
/// kalın gelir; sistem panosunda başka metin varsa düz yapıştırılır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? board;
  setUp(() {
    board = null;
    DocxEditController.richClip = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        board = (call.arguments as Map)['text'] as String?;
      } else if (call.method == 'Clipboard.getData') {
        return board == null ? null : {'text': board};
      }
      return null;
    });
  });

  DocxDocument open() => DocxDocument.parse(
      File('test/fixtures/office/word_kaydedilmis_cok_sayfa.docx')
          .readAsBytesSync());

  test('kalın kelime kopyala → başka yere yapıştır → kalın kalır', () async {
    final d = open();
    final c = DocxEditController(d);
    final i = d.paras.indexWhere((p) => p.text.startsWith('Giriş'));
    final k = d.paras[i].text.indexOf('paragrafı');
    c.select(DocPos(i, k), DocPos(i, k + 'paragrafı'.length));
    c.toggleBold();
    await c.copy();
    expect(board, 'paragrafı');
    // Paragrafın başına yapıştır.
    c.select(DocPos(i, 0), DocPos(i, 0));
    await c.paste();
    expect(d.paras[i].text, startsWith('paragrafıGiriş'));
    expect(d.paras[i].styles.first.isBold, isTrue,
        reason: 'biçim panodan geldi');
    // Kayıt → aç: kalın run dosyada.
    final back = DocxDocument.parse(d.save());
    final p = back.paras.firstWhere((p) => p.text.startsWith('paragrafıGiriş'));
    expect(p.styles.first.isBold, isTrue);
    final xml = p.source!.toXmlString();
    expect(XmlDocument.parse(xml).findAllElements('w:b'), isNotEmpty);
  });

  test('sistem panosu değiştiyse düz metin yapıştırılır', () async {
    final d = open();
    final c = DocxEditController(d);
    final i = d.paras.indexWhere((p) => p.text.startsWith('Giriş'));
    c.select(DocPos(i, 0), DocPos(i, 5));
    c.toggleBold();
    await c.copy();
    board = 'Dışarıdan';
    c.select(DocPos(i, 0), DocPos(i, 0));
    await c.paste();
    expect(d.paras[i].text, startsWith('DışarıdanGiriş'));
  });

  test('açılış önizlemesi: ilk dolu paragraflar, varlık çözülür, sınır', () {
    final bytes = File('test/fixtures/office/word_kaydedilmis_cok_sayfa.docx')
        .readAsBytesSync();
    final all = DocxDocument.parse(bytes)
        .paras
        .map((p) => p.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final preview = docxPreviewParagraphs(bytes, limit: 3);
    expect(preview, hasLength(3));
    expect(preview.first, all.first);
    expect(docxPreviewParagraphs(bytes).length, lessThanOrEqualTo(50));
  });
}
