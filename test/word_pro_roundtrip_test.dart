import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 ölçütü: gerçek docx'ler düzen kaybı olmadan açılıp kaydedilir —
/// pro paketi dokunmadığı parçayı baytı baytına korur, editör modeli el
/// değmemiş belgede document.xml'i aynen yazar.
const _files = [
  'stiller_basliklar', 'tablo', 'tablo_duzenlendi', 'liste_duzeyli',
  'madde_imleri', 'arapca_rtl', 'word_kaydedilmis_cok_sayfa', 'eski_doc_donusturuldu',
];

Map<String, List<int>> _parts(List<int> b) => {
      for (final f in ZipDecoder().decodeBytes(b).files)
        if (f.isFile) f.name: f.content as List<int>,
    };

void main() {
  for (final n in _files) {
    test(n, () {
      final b = File('test/fixtures/office/$n.docx').readAsBytesSync();
      final before = _parts(b);
      final viaPkg = _parts(DocxPackage.open(b).save());
      expect(viaPkg.keys.toSet(), before.keys.toSet());
      for (final k in before.keys) {
        expect(viaPkg[k], before[k], reason: '$n: $k');
      }
      final viaModel = _parts(DocxDocument.parse(b).save());
      expect(utf8.decode(viaModel['word/document.xml']!),
          utf8.decode(before['word/document.xml']!));
    });
  }
}
