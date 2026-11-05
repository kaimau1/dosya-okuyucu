import 'dart:io';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_templates.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 4 — şablonlar geçerli docx: editör açar, kaydeder,
/// LibreOffice (kuruluysa) onarımsız metne çevirir.
void main() {
  for (final id in kDocxTemplateIds) {
    for (final tr in [true, false]) {
      test('$id (${tr ? 'tr' : 'en'})', () {
        final b = DocxTemplates.build(id, turkish: tr, now: DateTime(2026, 11, 5));
        final doc = DocxDocument.parse(b);
        expect(doc.paras.length, greaterThan(5));
        expect(doc.plainText(), isNotEmpty);
        if (id == 'report') {
          expect(doc.paras.where((p) => p.look.headingLevel > 0), isNotEmpty);
        }
        expect(DocxDocument.parse(doc.save()).paras.length, doc.paras.length);
        final which = Process.runSync('which', ['soffice']);
        if (which.exitCode != 0) return;
        final dir = Directory.systemTemp.createTempSync('wt');
        try {
          final f = File('${dir.path}/t.docx')..writeAsBytesSync(b);
          final r = Process.runSync('soffice',
              ['--headless', '--convert-to', 'txt:Text (encoded):UTF8', '--outdir', dir.path, f.path]);
          expect(r.exitCode, 0);
          expect(File('${dir.path}/t.txt').readAsStringSync().trim(), isNotEmpty);
        } finally {
          dir.deleteSync(recursive: true);
        }
      });
    }
  }
}
