import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/safe_write.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storage_safety_test');
  });

  tearDown(() {
    if (tmp.existsSync()) removeTempDir(tmp);
  });

  test('sanitizeFatName: FAT32 yasak karakterleri ve sondaki nokta/boşluğu temizler',
      () {
    expect(FileOps.sanitizeFatName('a<b>:c|d?e*f"g.txt'), 'a_b__c_d_e_f_g.txt');
    expect(FileOps.sanitizeFatName(' Rapor.txt. . '), 'Rapor.txt');
    expect(FileOps.sanitizeFatName('...'), '');
  });

  test('SafeWrite.bytes: hedefi atomik yazar ve geçici dosya bırakmaz', () async {
    final target = p.join(tmp.path, 'belge.txt');
    File(target).writeAsStringSync('eski veri');

    await SafeWrite.bytes(target, 'yeni icerik'.codeUnits);

    expect(File(target).readAsStringSync(), 'yeni icerik');
    final leftovers = tmp
        .listSync()
        .where((e) => p.basename(e.path).contains(SafeWrite.marker));
    expect(leftovers, isEmpty);
  });

  test('copyAll(overwrite): atomik kopya hedefi günceller, geçici bırakmaz',
      () async {
    final srcDir = Directory(p.join(tmp.path, 'src'))..createSync();
    final dstDir = Directory(p.join(tmp.path, 'dst'))..createSync();
    final src = File(p.join(srcDir.path, 'not.txt'))
      ..writeAsStringSync('guncel icerik');
    final dst = File(p.join(dstDir.path, 'not.txt'))
      ..writeAsStringSync('onceki icerik');

    final res = await FileOps.copyAll([src.path], dstDir.path,
        conflict: FmConflict.overwrite);

    expect(res.hasError, isFalse);
    expect(dst.readAsStringSync(), 'guncel icerik');
    final leftovers = dstDir
        .listSync()
        .where((e) => p.basename(e.path).contains(SafeWrite.marker));
    expect(leftovers, isEmpty);
  });

  test('moveAll: alt öğe çakışsa da ötekiler taşınır ve kaynak klasör korunur',
      () async {
    final srcFolder = Directory(p.join(tmp.path, 'album'))..createSync();
    final okFile = File(p.join(srcFolder.path, 'iyi.txt'))
      ..writeAsStringSync('saglam');
    final badFile = File(p.join(srcFolder.path, 'engel.txt'))
      ..writeAsStringSync('kaybolmamali');

    final dstRoot = Directory(p.join(tmp.path, 'hedef'))..createSync();
    // Hedefte dosya adıyla aynı adda bir KLASÖR varsa üzerine yazma hata verir.
    Directory(p.join(dstRoot.path, 'album', 'engel.txt'))
        .createSync(recursive: true);

    final res = await FileOps.moveAll([srcFolder.path], dstRoot.path,
        conflict: FmConflict.overwrite);

    expect(res.hasError, isTrue);
    expect(
      File(p.join(dstRoot.path, 'album', 'iyi.txt')).readAsStringSync(),
      'saglam',
    );
    expect(okFile.existsSync(), isFalse);
    expect(srcFolder.existsSync(), isTrue,
        reason: 'Hatalı alt öğesi olan kaynak klasör asla silinmez');
    expect(badFile.readAsStringSync(), 'kaybolmamali');
  });

  test('moveAll: klasör kendi alt klasörüne taşınamaz', () async {
    final parent = Directory(p.join(tmp.path, 'ana'))..createSync();
    final child = Directory(p.join(parent.path, 'alt'))..createSync();
    final f = File(p.join(parent.path, 'veri.txt'))..writeAsStringSync('123');

    final res = await FileOps.moveAll([parent.path], child.path);

    expect(res.hasError, isTrue);
    expect(f.existsSync(), isTrue);
  });
}
