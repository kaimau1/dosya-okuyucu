import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Dosya işlemleri (kopyala/taşı/sil/yeniden adlandır) gerçek geçici klasörde
/// doğrulanır — bu mantık kullanıcının verisine dokunduğu için en kritik kısım.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fm_ops_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File touch(String relative, [String content = 'veri']) {
    final f = File(p.join(tmp.path, relative));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('uniquePath: dolu hedefe " (1)" eklenir, uzantı korunur', () {
    final f = touch('rapor.pdf');
    final unique = FileOps.uniquePath(f.path);
    expect(p.basename(unique), 'rapor (1).pdf');

    File(unique).writeAsStringSync('x');
    expect(p.basename(FileOps.uniquePath(f.path)), 'rapor (2).pdf');
  });

  test('uniquePath: boş hedef aynen döner', () {
    final path = p.join(tmp.path, 'yok.txt');
    expect(FileOps.uniquePath(path), path);
  });

  test('sanitizeName: yol ayracı ve kontrol karakteri temizlenir', () {
    expect(FileOps.sanitizeName(' a/b.txt '), 'a_b.txt');
    expect(FileOps.sanitizeName('..'), '');
  });

  test('copyAll: dosya kopyalanır, kaynak yerinde kalır', () async {
    final src = touch('a.txt', 'merhaba');
    final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

    final result = await FileOps.copyAll([src.path], dest.path);

    expect(result.hasError, isFalse);
    expect(src.existsSync(), isTrue);
    expect(File(p.join(dest.path, 'a.txt')).readAsStringSync(), 'merhaba');
  });

  test('copyAll: klasör özyinelemeli kopyalanır', () async {
    touch('klasor/ic/derin.txt', 'derin');
    touch('klasor/ust.txt');
    final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

    await FileOps.copyAll([p.join(tmp.path, 'klasor')], dest.path);

    expect(
        File(p.join(dest.path, 'klasor', 'ic', 'derin.txt')).readAsStringSync(),
        'derin');
    expect(File(p.join(dest.path, 'klasor', 'ust.txt')).existsSync(), isTrue);
  });

  test('copyAll: çakışmada varsayılan yeniden adlandırma (veri ezilmez)',
      () async {
    final src = touch('a.txt', 'yeni');
    final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();
    File(p.join(dest.path, 'a.txt')).writeAsStringSync('eski');

    await FileOps.copyAll([src.path], dest.path);

    expect(File(p.join(dest.path, 'a.txt')).readAsStringSync(), 'eski');
    expect(File(p.join(dest.path, 'a (1).txt')).readAsStringSync(), 'yeni');
  });

  test('copyAll: overwrite politikası hedefi ezer', () async {
    final src = touch('a.txt', 'yeni');
    final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();
    File(p.join(dest.path, 'a.txt')).writeAsStringSync('eski');

    await FileOps.copyAll([src.path], dest.path,
        conflict: FmConflict.overwrite);

    expect(File(p.join(dest.path, 'a.txt')).readAsStringSync(), 'yeni');
  });

  test('moveAll: kaynak silinir, hedefte oluşur', () async {
    final src = touch('tasi.txt', 'içerik');
    final dest = Directory(p.join(tmp.path, 'hedef'))..createSync();

    await FileOps.moveAll([src.path], dest.path);

    expect(src.existsSync(), isFalse);
    expect(File(p.join(dest.path, 'tasi.txt')).readAsStringSync(), 'içerik');
  });

  test('moveAll: klasör kendi içine taşınamaz', () async {
    final dir = Directory(p.join(tmp.path, 'ust', 'alt'))
      ..createSync(recursive: true);

    final result = await FileOps.moveAll([p.join(tmp.path, 'ust')], dir.path);

    expect(result.errors, isNotEmpty);
    expect(Directory(p.join(tmp.path, 'ust')).existsSync(), isTrue);
  });

  test('rename: yeni ad uygulanır, çakışmada hata', () async {
    final f = touch('eski.txt');
    final renamed = await FileOps.rename(f.path, 'yeni.txt');
    expect(p.basename(renamed), 'yeni.txt');
    expect(File(renamed).existsSync(), isTrue);

    touch('dolu.txt');
    // Not: async fonksiyonun hatası `expectLater` ile beklenir
    // (bkz. HAFIZA 2026-07-23 `.then(onError:)` tuzağı).
    await expectLater(FileOps.rename(renamed, 'dolu.txt'),
        throwsA(isA<FileSystemException>()));
  });

  test('createFolder / createFile: oluşturur, aynı ada izin vermez', () async {
    final dir = await FileOps.createFolder(tmp.path, 'Yeni Klasör');
    expect(Directory(dir).existsSync(), isTrue);
    await expectLater(FileOps.createFolder(tmp.path, 'Yeni Klasör'),
        throwsA(isA<FileSystemException>()));

    final file = await FileOps.createFile(tmp.path, 'not.txt', content: 'a');
    expect(File(file).readAsStringSync(), 'a');
  });

  test('deleteAll: dosya ve klasör silinir', () async {
    final f = touch('sil.txt');
    touch('silklasor/ic.txt');

    final result = await FileOps.deleteAll(
        [f.path, p.join(tmp.path, 'silklasor')]);

    expect(result.succeeded, 2);
    expect(f.existsSync(), isFalse);
    expect(Directory(p.join(tmp.path, 'silklasor')).existsSync(), isFalse);
  });
}
