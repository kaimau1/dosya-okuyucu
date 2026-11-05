import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/batch_rename.dart';
import 'package:flutter_test/flutter_test.dart';

FsEntry _f(String path) => FsEntry(
    path: path,
    name: path.split('/').last,
    isDir: false,
    sizeBytes: 1,
    modifiedMs: DateTime(2026, 11, 5).millisecondsSinceEpoch);

/// Faz 41 / 1: kaydedilen kalıplar + yeni yer tutucular.
void main() {
  test('büyük/küçük harf Türkçe kurallı, klasör adı', () {
    final out = planBatchRename([_f('/x/Tatil/istanbul ılık.jpg')],
        pattern: '{klasor}-{AD}');
    expect(out.single.newName, 'Tatil-İSTANBUL ILIK.jpg');
    final low = planBatchRename([_f('/x/A/IŞIK İzmir.png')],
        pattern: '{ad_kucuk}');
    expect(low.single.newName, 'ışık izmir.png');
  });

  test('kalıp listesi: en yeni başta, tekrar yok, tavan', () {
    var l = <String>[];
    l = BatchRenameTemplates.add(l, '{ad}-{n}');
    l = BatchRenameTemplates.add(l, '{tarih}');
    l = BatchRenameTemplates.add(l, '{ad}-{n}');
    expect(l, ['{ad}-{n}', '{tarih}']);
    l = BatchRenameTemplates.add(l, '   ');
    expect(l, hasLength(2));
    for (var i = 0; i < 20; i++) {
      l = BatchRenameTemplates.add(l, 'k$i');
    }
    expect(l, hasLength(BatchRenameTemplates.max));
    expect(BatchRenameTemplates.remove(l, 'k19'), isNot(contains('k19')));
  });
}
