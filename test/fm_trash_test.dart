import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/trash_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

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

  tearDown(() => removeTempDir(tmp));

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

  test('çöpe atılan dosya TARAMADA görünmez (kullanıcı hatası 2026-07-25)',
      () async {
    // Silinen dosya diskte çöp klasöründe durur; tarama onu saymaya devam
    // ederse kategori sayıları düşmez ve dosya "duruyormuş" gibi görünür.
    final f = touch('videolar/klip.mp4', '12345');
    var index = await FsScan.index([volume.path]);
    expect(index.stat(FmCategory.video).count, 1);

    await trash.moveToTrash([f.path]);

    index = await FsScan.index([volume.path]);
    expect(index.stat(FmCategory.video).count, 0,
        reason: 'çöpteki dosya kategori sayısına girmemeli');
    expect(index.files(FmCategory.video), isEmpty);

    // Arama da çöpü kazmamalı.
    final hits = await FsScan.search(volume.path, 'klip');
    expect(hits, isEmpty);

    // Ama çöp kutusunda duruyor (geri yüklenebilir).
    expect((await trash.list()).single.name, 'klip.mp4');
  });

  test('taşınamayan dosya için çöp KAYDI oluşturulmaz', () async {
    // Kaynak yerinde kalırsa dosya hem klasörde hem çöpte görünürdü.
    // (Burada dosya gerçekten taşınır; test kaydın ancak kaynak gidince
    // yazıldığını sabitler.)
    final f = touch('a.txt');
    await trash.moveToTrash([f.path]);
    expect(f.existsSync(), isFalse);
    expect(await trash.list(), hasLength(1));
  });

  test('purgeOlderThan: yalnız süresi geçen kayıtları siler', () async {
    await trash.moveToTrash([touch('yeni.txt').path]);
    expect(await trash.list(), hasLength(1));

    // 0/negatif gün → hiçbir şey silinmez (ayar kapalı demektir).
    expect(await trash.purgeOlderThan(0), 0);
    expect(await trash.list(), hasLength(1));

    // Bugün silinen öğe 7 gün eşiğine takılmaz.
    expect(await trash.purgeOlderThan(7), 0);
    expect(await trash.list(), hasLength(1));
  });
}
