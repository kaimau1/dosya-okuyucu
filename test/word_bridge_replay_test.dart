import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/office_fixtures.dart';

/// Faz 21a — Playwright'ta GERÇEK Chromium'da kaydedilen köprü mesajları
/// (tool/check_word_bridge.js → view/bridge_messages.jsonl) Dart modeline
/// aynen oynatılır: devam parçasına yazım, Enter, geri silme, geri al /
/// yinele, adalı paragrafa yazım. Sonuç dosya yeniden açılınca doğru ve
/// LibreOffice onu onarımsız açıyor (varsa).
void main() {
  test('köprü mesaj dizisi modele uygulanır, dosya sağlam', () async {
    final e = DocxEditor.parse(OfficeFixtures.docxWordSaved());
    e.viewBytes(); // ada kimlikleri görünümdekiyle aynı sırada verilir
    final lines = File('test/fixtures/office/view/bridge_messages.jsonl')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty);
    for (final l in lines) {
      expect(e.applyLiveMessage(jsonDecode(l) as Map), isTrue, reason: l);
    }
    final bytes = e.save();
    final back = DocxEditor.parse(bytes);
    expect(back.paragraphs.length, 31);
    final texts = back.paragraphs.map((p) => p.text).toList();
    expect(texts, contains('Sayfa sonunda başlayan ve sonraki sayfada biten paragraf.!'));
    expect(texts, contains('Giriş paragrafı.'));
    expect(texts.firstWhere((t) => t.startsWith('Bağlantı')), endsWith(' son. X'));
    final xml = utf8.decode(ZipDecoder()
        .decodeBytes(bytes)
        .files
        .firstWhere((f) => f.name == 'word/document.xml')
        .content as List<int>);
    expect(xml, isNot(contains('_fkp')));

    final soffice = Process.runSync('which', ['soffice']);
    if (soffice.exitCode != 0) return;
    final dir = Directory.systemTemp.createTempSync('lo');
    final f = File('${dir.path}/rapor.docx')..writeAsBytesSync(bytes);
    final r = await Process.run('soffice',
        ['--headless', '--convert-to', 'txt:Text (encoded):UTF8', '--outdir', dir.path, f.path]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect('${r.stdout}', contains('rapor.txt'), reason: '${r.stdout} ${r.stderr}');
    final txt = File('${dir.path}/rapor.txt').readAsStringSync();
    expect(txt, contains('sonraki sayfada biten paragraf.!'));
    expect(txt, contains('örnek site'));
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
