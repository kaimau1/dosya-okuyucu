import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/docx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/sample_docs.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 40 / 4: örnek belgeler geçerli ve kendi editörlerimizde açılıyor.
void main() {
  for (final lang in const [AppLanguage.tr, AppLanguage.en, AppLanguage.ar]) {
    test('dört örnek yazılır ve açılır (${lang.name})', () async {
      final s = AppStrings(lang);
      final dir = Directory.systemTemp.createTempSync('smp');
      addTearDown(() => dir.deleteSync(recursive: true));
      final paths = await SampleDocs.create(s, into: dir);
      expect(paths, hasLength(4));
      for (final p in paths) {
        expect(File(p).lengthSync(), greaterThan(0));
      }
      Uint8List bytes(String ext) => File(paths.firstWhere((p) => p.endsWith(ext)))
          .readAsBytesSync();
      final docx = DocxEditor.parse(bytes('.docx'));
      expect(docx.paragraphs.first.text, s.t('smp.word_title'));
      expect(docx.paragraphs.length, 4);
      final xlsx = XlsxEditor.parse(bytes('.xlsx'));
      expect(xlsx, isNotNull);
      final pptx = PptxEditor.parse(bytes('.pptx'));
      expect(pptx.slides, hasLength(3));
      expect(String.fromCharCodes(bytes('.md')), isNotEmpty);
      // İkinci basış çoğaltmaz (aynı adların üzerine yazar).
      await SampleDocs.create(s, into: dir);
      expect(dir.listSync(), hasLength(4));
    });
  }
}
