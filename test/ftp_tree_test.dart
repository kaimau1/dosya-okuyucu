import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

/// PC'de görünen **kategorili kök** (kullanıcı isteği 2026-08-29:
/// *"bilgisayarda açınca da telefondaki gibi Belgeler, Görüntüler, Videolar,
/// İndirilenler vs şeklinde aynı kategorizasyonda görelim"*).
///
/// Kutu içeriğini toplayan işlev testte enjekte ediliyor: gerçek toplayıcı
/// arama dizinine ve tüm diski taramaya bağlı, burada ölçülen şey AĞAÇ.
void main() {
  late Directory root;

  FsEntry file(String path, {int size = 10, int modified = 1}) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: modified,
      );

  FtpTree tree({
    List<FsEntry> images = const [],
    List<FsEntry> fresh = const [],
    List<String> lockedFolders = const [],
    bool showHidden = false,
  }) =>
      FtpTree(
        realRoot: root.path,
        showHidden: showHidden,
        lockedFolders: lockedFolders,
        collect: (category) async =>
            category == FmCategory.image ? images : const [],
        freshScan: () async => fresh,
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('ftp_tree');
    Directory('${root.path}/DCIM').createSync();
    Directory('${root.path}/Download').createSync();
    File('${root.path}/Download/a.pdf').writeAsStringSync('x');
  });

  tearDown(() => removeTempDir(root));

  group('kök', () {
    test('telefondaki kutuları listeler', () {
      final names = tree().rootItems().map((i) => i.name).toList();
      expect(names.first, FtpTree.storageFolder);
      expect(names, containsAll(['Indirilenler', 'Kamera', 'Belgeler',
          'Resimler', 'Videolar', 'Ses', 'Arsivler', 'Uygulamalar']));
    });

    test('EKRAN GÖRÜNTÜLERİ kendi kutusunda (kullanıcı isteği 2026-08-29)',
        () {
      // Klasör yokken kutu da yok.
      expect(tree().rootItems().map((i) => i.name),
          isNot(contains('Ekran Goruntuleri')));

      Directory('${root.path}/Pictures/Screenshots')
          .createSync(recursive: true);
      final item = tree()
          .rootItems()
          .firstWhere((i) => i.name == 'Ekran Goruntuleri');
      // GERÇEK klasör: her listelemede diskten okunur, yani bir saniye önce
      // alınan ekran görüntüsü anında görünür (sanal kutuların tersine).
      expect(item.realPath, '${root.path}/Pictures/Screenshots');
      expect(item.category, isNull);
    });

    test('ekran görüntüsü klasörü ROM\'a göre DCIM altında da olabilir', () {
      Directory('${root.path}/DCIM/Screenshots').createSync(recursive: true);
      final item = tree()
          .rootItems()
          .firstWhere((i) => i.name == 'Ekran Goruntuleri');
      expect(item.realPath, '${root.path}/DCIM/Screenshots');
    });

    test('cihazda OLMAYAN klasör kutusu listelenmez', () {
      Directory('${root.path}/Download').deleteSync(recursive: true);
      final names = tree().rootItems().map((i) => i.name).toList();
      expect(names, isNot(contains('Indirilenler')));
      // Kategori kutuları klasöre bağlı değil, hep duruyor.
      expect(names, contains('Belgeler'));
    });

    test('kutu adları ASCII — eski istemciler Türkçe karakteri bozuyor', () {
      for (final item in tree().rootItems()) {
        expect(item.name.codeUnits.every((c) => c < 128), isTrue,
            reason: item.name);
      }
    });
  });

  group('çözümleme', () {
    test('kök', () async {
      expect((await tree().resolve('/')).kind, FtpNodeKind.root);
    });

    test('"Telefon" gerçek kökün kendisi', () async {
      final node = await tree().resolve('/${FtpTree.storageFolder}');
      expect(node.kind, FtpNodeKind.real);
      expect(node.relative, '');
    });

    test('kutu altındaki gerçek yol köke GÖRE veriliyor', () async {
      final node =
          await tree().resolve('/${FtpTree.storageFolder}/DCIM/a.jpg');
      expect(node.relative, 'DCIM/a.jpg');
    });

    test('kısayol kutusu kendi klasörünün altını açar', () async {
      final node = await tree().resolve('/Indirilenler/a.pdf');
      expect(node.kind, FtpNodeKind.real);
      expect(node.relative, 'Download/a.pdf');
    });

    test('kökte OLMAYAN ad çözülmez', () async {
      // Kök seçilmiş kutulardan ibaret: gerçek klasörler kökte görünmüyor,
      // dolayısıyla oradan da açılamıyor.
      for (final path in ['/DCIM', '/etc', '/Android/data']) {
        expect((await tree().resolve(path)).relative, isNull, reason: path);
      }
    });

    test('kategori kutusu', () async {
      final node = await tree().resolve('/Resimler');
      expect(node.kind, FtpNodeKind.category);
      expect(node.category, 'Resimler');
    });

    test('kategori kutusu DÜZ — altında klasör yok', () async {
      final node = await tree().resolve('/Resimler/alt/a.jpg');
      expect(node.relative, isNull);
      expect(node.kind, isNot(FtpNodeKind.categoryFile));
    });
  });

  group('kategori içeriği', () {
    test('dosyalar telefonun her yerinden toplanır', () async {
      final t = tree(images: [
        file('${root.path}/DCIM/tatil.jpg'),
        file('${root.path}/Pictures/ekran.png'),
      ]);
      final files = await t.categoryEntries('Resimler');
      expect(files.keys, containsAll(['tatil.jpg', 'ekran.png']));

      final node = await t.resolve('/Resimler/ekran.png');
      expect(node.kind, FtpNodeKind.categoryFile);
      expect(node.realPath, '${root.path}/Pictures/ekran.png');
    });

    test('AYNI ADLI iki dosya kutuda birbirini yutmaz', () async {
      // FTP'de bir klasörde iki kez aynı ad olamaz; numaralandırma uzantıdan
      // ÖNCE ki dosya PC'de yine doğru programla açılsın.
      final t = tree(images: [
        file('${root.path}/DCIM/IMG_1.jpg'),
        file('${root.path}/Pictures/IMG_1.jpg'),
        file('${root.path}/Download/IMG_1.jpg'),
      ]);
      final files = await t.categoryEntries('Resimler');
      expect(files.length, 3);
      expect(files.keys, containsAll(['IMG_1.jpg', 'IMG_1 (2).jpg',
          'IMG_1 (3).jpg']));
      expect((await t.resolve('/Resimler/IMG_1 (2).jpg')).realPath,
          '${root.path}/Pictures/IMG_1.jpg');
    });

    test('gizli dosyalar varsayılan olarak kutuya girmez', () async {
      final images = [
        file('${root.path}/DCIM/.gizli.jpg'),
        file('${root.path}/DCIM/acik.jpg'),
      ];
      expect((await tree(images: images).categoryEntries('Resimler')).keys,
          ['acik.jpg']);
      expect(
          (await tree(images: images, showHidden: true)
                  .categoryEntries('Resimler'))
              .keys
              .length,
          2);
    });

    group('taze dosyalar (kullanıcı hatası 2026-08-29)', () {
      // *"Ağ paylaşımına dosyalar anlık düşmüyor, yeni bir ekran görüntüsü
      // aldım ama bulamadım."* Kök neden: sanal kutular arama dizininden
      // doluyor, dizin ise yalnız UYGULAMANIN kendi işlemlerinde bayat
      // işaretleniyor — ekran görüntüsünü alan sistem. Yeni dosya kutuda
      // 30 saniye değil, bir sonraki TAM TARAMAYA kadar görünmüyordu.

      test('dizinde olmayan YENİ dosya kutuya katılır', () async {
        final t = tree(
          images: [file('${root.path}/DCIM/eski.jpg')],
          fresh: [file('${root.path}/Pictures/Screenshots/yeni.png')],
        );
        final files = await t.categoryEntries('Resimler');
        expect(files.keys, containsAll(['eski.jpg', 'yeni.png']));
        // Çözümleme de çalışmalı: PC dosyayı listede görüp indirebilmeli.
        final node = await t.resolve('/Resimler/yeni.png');
        expect(node.kind, FtpNodeKind.categoryFile);
        expect(node.realPath, '${root.path}/Pictures/Screenshots/yeni.png');
      });

      test('başka kategorinin taze dosyası bu kutuya girmez', () async {
        final t = tree(
          images: const [],
          fresh: [file('${root.path}/Download/rapor.pdf')],
        );
        expect((await t.categoryEntries('Resimler')).keys, isEmpty);
      });

      test('dizinde ZATEN olan dosya iki kez görünmez', () async {
        final same = '${root.path}/DCIM/a.jpg';
        final t = tree(images: [file(same)], fresh: [file(same)]);
        expect((await t.categoryEntries('Resimler')).length, 1);
      });

      test('kilitli klasördeki taze dosya kutuya SIZMAZ', () async {
        // Kilit, dizinden gelen listede uygulanıyor; taze katman onu
        // atlatan bir arka kapı olmamalı.
        final t = tree(
          images: const [],
          fresh: [file('${root.path}/Ozel/gizli.jpg')],
          lockedFolders: ['${root.path}/Ozel'],
        );
        expect((await t.categoryEntries('Resimler')).keys, isEmpty);
      });

      test('gizli taze dosya varsayılan olarak katılmaz', () async {
        final t = tree(
          images: const [],
          fresh: [file('${root.path}/DCIM/.gizli.jpg')],
        );
        expect((await t.categoryEntries('Resimler')).keys, isEmpty);
      });

      test('taze dosya ÖNBELLEĞE yapışmaz', () async {
        // Taze liste her çağrıda yeniden karılıyor; önbellekteki haritaya
        // yazılsaydı dosya silindikten sonra da listede kalırdı.
        var fresh = [file('${root.path}/DCIM/gecici.jpg')];
        final t = FtpTree(
          realRoot: root.path,
          collect: (c) async => const [],
          freshScan: () async => fresh,
        );
        expect((await t.categoryEntries('Resimler')).keys, ['gecici.jpg']);
        fresh = const [];
        t.invalidate();
        expect((await t.categoryEntries('Resimler')).keys, isEmpty);
      });

      test('taze tarayıcı VERİLMEZSE eski davranış sürer', () async {
        final t = FtpTree(
          realRoot: root.path,
          collect: (c) async => [file('${root.path}/DCIM/a.jpg')],
        );
        expect((await t.categoryEntries('Resimler')).keys, ['a.jpg']);
      });
    });

    test('içerik önbellekten gelir, her komutta yeniden taranmaz', () async {
      var calls = 0;
      final t = FtpTree(
        realRoot: root.path,
        collect: (_) async {
          calls++;
          return [file('${root.path}/DCIM/a.jpg')];
        },
      );
      await t.categoryEntries('Resimler');
      await t.categoryEntries('Resimler');
      await t.resolve('/Resimler/a.jpg');
      expect(calls, 1);

      // Silme/yeniden adlandırma sonrası kutu tazelenir.
      t.invalidate();
      await t.categoryEntries('Resimler');
      expect(calls, 2);
    });

    test('eşzamanlı iki istek TEK tarama yapar', () async {
      var calls = 0;
      final t = FtpTree(
        realRoot: root.path,
        collect: (_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const <FsEntry>[];
        },
      );
      await Future.wait([
        t.categoryEntries('Belgeler'),
        t.categoryEntries('Belgeler'),
      ]);
      expect(calls, 1);
    });
  });

  test('benzersizleştirme uzantıdan önce numaralandırır', () {
    final taken = <String>{'a.pdf', 'a (2).pdf', 'notlar'};
    expect(FtpTree.uniqueName(taken.contains, 'a.pdf'), 'a (3).pdf');
    expect(FtpTree.uniqueName(taken.contains, 'notlar'), 'notlar (2)');
    expect(FtpTree.uniqueName(taken.contains, 'b.pdf'), 'b.pdf');
  });
}
