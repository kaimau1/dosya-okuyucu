import 'dart:io';

import 'package:dosya_okuyucu/services/fm/trash_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Çöp kutusu: sil → geri yükle → kalıcı sil döngüsü. Kullanıcı verisi
/// söz konusu olduğu için "geri yükleme gerçekten eski yere koyuyor mu"
/// sorusu testle sabitlenir.
void main() {
  late Directory tmp;
  late Directory volume;
  late TrashService trash;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fm_trash_test');
    volume = Directory(p.join(tmp.path, 'birim'))..createSync();
    trash = TrashService(
      volumeRoots: [volume.path],
      fallbackRoot: p.join(tmp.path, 'app'),
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  File touch(String relative, [String content = 'veri']) {
    final f = File(p.join(volume.path, relative));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('çöp klasörü dosyanın kendi biriminde açılır', () {
    expect(trash.trashDirFor(p.join(volume.path, 'a.txt')),
        p.join(volume.path, TrashService.dirName));
    // Bilinmeyen birim → yedek kök
    expect(trash.trashDirFor('/baska/yer/a.txt'),
        p.join(tmp.path, 'app', TrashService.dirName));
  });

  test('sil → listede görünür → geri yükle → eski yerine döner', () async {
    final f = touch('belgeler/rapor.txt', 'içerik');

    final result = await trash.moveToTrash([f.path]);
    expect(result.hasError, isFalse);
    expect(f.existsSync(), isFalse);

    final items = await trash.list();
    expect(items, hasLength(1));
    expect(items.first.name, 'rapor.txt');
    expect(items.first.originalPath, f.path);

    final restored = await trash.restore(items.first);
    expect(File(restored).readAsStringSync(), 'içerik');
    expect(restored, f.path);
    expect(await trash.list(), isEmpty);
  });

  test('eski yol doluysa geri yükleme " (1)" ile yapılır', () async {
    final f = touch('a.txt', 'eski');
    await trash.moveToTrash([f.path]);
    touch('a.txt', 'yeni'); // aynı ada yeni dosya

    final restored = await trash.restore((await trash.list()).first);

    expect(p.basename(restored), 'a (1).txt');
    expect(File(restored).readAsStringSync(), 'eski');
    expect(File(f.path).readAsStringSync(), 'yeni');
  });

  test('klasör çöpe atılır ve geri yüklenir', () async {
    touch('klasor/ic.txt', 'derin');

    await trash.moveToTrash([p.join(volume.path, 'klasor')]);
    expect(Directory(p.join(volume.path, 'klasor')).existsSync(), isFalse);

    final items = await trash.list();
    expect(items.single.isDir, isTrue);
    await trash.restore(items.single);
    expect(
        File(p.join(volume.path, 'klasor', 'ic.txt')).readAsStringSync(),
        'derin');
  });

  test('kalıcı sil ve boşalt', () async {
    await trash.moveToTrash([touch('x.txt').path, touch('y.txt').path]);
    expect(await trash.list(), hasLength(2));

    await trash.deleteForever((await trash.list()).first);
    expect(await trash.list(), hasLength(1));

    await trash.empty();
    expect(await trash.list(), isEmpty);
  });

  test('çöp klasöründe .nomedia bulunur (galeri göstermesin)', () async {
    await trash.moveToTrash([touch('foto.jpg').path]);
    expect(
        File(p.join(volume.path, TrashService.dirName, '.nomedia'))
            .existsSync(),
        isTrue);
  });
}
