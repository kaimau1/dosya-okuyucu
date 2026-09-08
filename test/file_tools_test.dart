import 'dart:io';

import 'package:dosya_okuyucu/services/fm/empty_folders.dart';
import 'package:dosya_okuyucu/services/fm/file_digest.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/file_split.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2026-09-06 denetim turu: dosya özeti, bölme/birleştirme ve boş klasör
/// temizliği. Üçü de gerçek diskle çalışıyor — "kopyaladım, gitti mi?"
/// sorusunun cevabı ancak baytlar karşılaştırılınca verilebilir.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('ft-test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Dosya özeti', () {
    test('SHA-256 bilinen değeri üretir', () async {
      final file = File(p.join(temp.path, 'abc.txt'))..writeAsStringSync('abc');
      expect(
        await FileDigest.sha256Of(file.path),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('MD5 bilinen değeri üretir', () async {
      final file = File(p.join(temp.path, 'abc.txt'))..writeAsStringSync('abc');
      expect(await FileDigest.md5Of(file.path),
          '900150983cd24fb0d6963f7d28e17f72');
    });

    test('boş dosyanın özeti de hesaplanır', () async {
      final file = File(p.join(temp.path, 'bos.bin'))..writeAsBytesSync([]);
      expect(
        await FileDigest.sha256Of(file.path),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('blok sınırını aşan dosya doğru özetlenir (akış hâlinde okuma)',
        () async {
      // 1 MB'lık blok sınırının ötesine geçen içerik: parçalı okuma yanlış
      // birleştirilirse özet tutmaz.
      final bytes = List<int>.generate(3 * 1024 * 1024 + 7, (i) => i % 251);
      final file = File(p.join(temp.path, 'buyuk.bin'))
        ..writeAsBytesSync(bytes);
      final digest = await FileDigest.sha256Of(file.path);
      expect(digest, hasLength(64));
      // Aynı içerik → aynı özet (kararlılık).
      final copy = File(p.join(temp.path, 'kopya.bin'))
        ..writeAsBytesSync(bytes);
      expect(await FileDigest.sha256Of(copy.path), digest);
    });

    test('tek bayt değişince özet DEĞİŞİR', () async {
      final a = File(p.join(temp.path, 'a.bin'))..writeAsBytesSync([1, 2, 3]);
      final b = File(p.join(temp.path, 'b.bin'))..writeAsBytesSync([1, 2, 4]);
      expect(await FileDigest.sha256Of(a.path),
          isNot(await FileDigest.sha256Of(b.path)));
    });

    test('yapıştırılan özet boşluk/büyük harf farkına takılmaz', () {
      expect(
        FileDigest.sameDigest('BA7816BF 8F01CFEA', 'ba7816bf8f01cfea'),
        isTrue,
      );
      expect(FileDigest.sameDigest('abc', 'abd'), isFalse);
    });

    test('ilerleme bildirilir', () async {
      final file = File(p.join(temp.path, 'p.bin'))
        ..writeAsBytesSync(List.filled(1000, 7));
      var last = 0;
      var total = 0;
      await FileDigest.sha256Of(file.path, onProgress: (d, t) {
        last = d;
        total = t;
      });
      expect(last, 1000);
      expect(total, 1000);
    });
  });

  group('Dosya böl / birleştir', () {
    test('bölünen parçalar birleşince ÖZGÜN dosyayı verir', () async {
      final bytes = List<int>.generate(10000, (i) => i % 256);
      final source = File(p.join(temp.path, 'video.mp4'))
        ..writeAsBytesSync(bytes);
      final original = await FileDigest.sha256Of(source.path);

      final parts = await FileSplit.split(source.path, partBytes: 3000);
      expect(parts, hasLength(4)); // 3000+3000+3000+1000
      expect(p.basename(parts.first), 'video.mp4.001');
      expect(File(parts[0]).lengthSync(), 3000);
      expect(File(parts[3]).lengthSync(), 1000);

      source.deleteSync(); // birleştirme özgün adı yeniden kullanabilsin
      final joined = await FileSplit.join(parts.first);
      expect(p.basename(joined), 'video.mp4');
      expect(await FileDigest.sha256Of(joined), original);
    });

    test('hangi parçadan başlatılırsa başlatılsın tamamı birleşir', () async {
      final source = File(p.join(temp.path, 'a.bin'))
        ..writeAsBytesSync(List.filled(2500, 3));
      final parts = await FileSplit.split(source.path, partBytes: 1024);
      source.deleteSync();
      // Ortadaki parçadan başlatılıyor.
      final joined = await FileSplit.join(parts[1]);
      expect(File(joined).lengthSync(), 2500);
    });

    test('EKSİK parça sessizce bozuk dosya üretmez', () async {
      final source = File(p.join(temp.path, 'b.bin'))
        ..writeAsBytesSync(List.filled(2500, 3));
      final parts = await FileSplit.split(source.path, partBytes: 1024);
      File(parts[1]).deleteSync(); // .002 kayboldu
      source.deleteSync();
      expect(() => FileSplit.join(parts.first), throwsFormatException);
    });

    test('parça olmayan dosyada anlaşılır hata', () async {
      final file = File(p.join(temp.path, 'düz.txt'))..writeAsStringSync('x');
      expect(() => FileSplit.join(file.path), throwsFormatException);
    });

    test('1 KB altı parça boyutu REDDEDİLİR (4 milyar dosya tuzağı)', () {
      expect(
        () => FileSplit.split('/yok', partBytes: 10),
        throwsArgumentError,
      );
    });

    test('iptal edilen bölme YARIM parça bırakmaz', () async {
      final source = File(p.join(temp.path, 'c.bin'))
        ..writeAsBytesSync(List.filled(50000, 1));
      var calls = 0;
      final parts = await FileSplit.split(source.path,
          partBytes: 1024, isCancelled: () => calls++ > 3);
      expect(parts, isEmpty);
      final leftovers = temp
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.00'));
      expect(leftovers, isEmpty);
    });

    test('mevcut dosyanın üzerine YAZMAZ', () async {
      final source = File(p.join(temp.path, 'd.bin'))
        ..writeAsBytesSync(List.filled(1024, 9));
      final parts = await FileSplit.split(source.path, partBytes: 1024);
      // Kaynak duruyor: birleştirme "d (1).bin" üretmeli.
      final joined = await FileSplit.join(parts.first);
      expect(p.basename(joined), 'd (1).bin');
      expect(source.lengthSync(), 1024);
    });

    test('parça adı çözümlemesi', () {
      expect(FileSplit.partName('video.mp4', 7), 'video.mp4.007');
      expect(FileSplit.baseNameOf('/a/b/video.mp4.012'), 'video.mp4');
      expect(FileSplit.baseNameOf('/a/b/video.mp4'), isNull);
    });
  });

  group('Kopyalamada TARİH korunur (2026-09-06)', () {
    // `File.copy` hedefe "şimdi"yi yazıyordu: 800 fotoğrafı USB belleğe
    // kopyalayan kullanıcı hepsinin tarihini bugün buluyor, tarihe göre
    // sıralama ve galeri gruplaması anlamını yitiriyordu.
    test('kopyalanan dosyanın tarihi kaynağınkiyle aynı', () async {
      final src = File(p.join(temp.path, 'eski.txt'))
        ..writeAsStringSync('içerik');
      final when = DateTime(2019, 7, 14, 10, 30);
      src.setLastModifiedSync(when);
      final destDir = Directory(p.join(temp.path, 'hedef'))..createSync();

      final result = await FileOps.copyAll([src.path], destDir.path);
      expect(result.succeeded, 1);
      final copy = File(p.join(destDir.path, 'eski.txt'));
      expect(copy.existsSync(), isTrue);
      expect(copy.lastModifiedSync().millisecondsSinceEpoch,
          when.millisecondsSinceEpoch);
    });

    test('klasör kopyalarken içindekilerin tarihi de korunur', () async {
      final dir = Directory(p.join(temp.path, 'Albüm'))..createSync();
      final photo = File(p.join(dir.path, 'foto.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final when = DateTime(2021, 3, 2, 8, 15);
      photo.setLastModifiedSync(when);
      final destDir = Directory(p.join(temp.path, 'usb'))..createSync();

      await FileOps.copyAll([dir.path], destDir.path);
      final copy = File(p.join(destDir.path, 'Albüm', 'foto.jpg'));
      expect(copy.existsSync(), isTrue);
      expect(copy.lastModifiedSync().millisecondsSinceEpoch,
          when.millisecondsSinceEpoch);
    });
  });

  group('Boş klasörler', () {
    test('iç içe boş klasörler İÇTEN DIŞA bulunur', () async {
      Directory(p.join(temp.path, 'Yedek', '2024', 'Ocak'))
          .createSync(recursive: true);
      final found = await EmptyFolders.find(temp.path);
      expect(found.map((f) => p.basename(f)), ['Ocak', '2024', 'Yedek']);
    });

    test('içinde dosya olan klasör boş SAYILMAZ', () async {
      final dir = Directory(p.join(temp.path, 'Belgeler'))..createSync();
      File(p.join(dir.path, 'not.txt')).writeAsStringSync('x');
      expect(await EmptyFolders.find(temp.path), isEmpty);
    });

    test('gizli dosya da dosyadır (.nomedia korunur)', () async {
      final dir = Directory(p.join(temp.path, 'Kamera'))..createSync();
      File(p.join(dir.path, '.nomedia')).writeAsStringSync('');
      expect(await EmptyFolders.find(temp.path), isEmpty);
    });

    test('kökün KENDİSİ listeye girmez', () async {
      final root = Directory(p.join(temp.path, 'İndirilenler'))..createSync();
      expect(await EmptyFolders.find(root.path), isEmpty);
    });

    test('silme gerçekten siler ve sayıyı döner', () async {
      Directory(p.join(temp.path, 'A', 'B')).createSync(recursive: true);
      final found = await EmptyFolders.find(temp.path);
      expect(await EmptyFolders.deleteAll(found), 2);
      expect(Directory(p.join(temp.path, 'A')).existsSync(), isFalse);
    });

    test('tarama ile silme arasında DOLAN klasör silinmez', () async {
      final dir = Directory(p.join(temp.path, 'C'))..createSync();
      final found = await EmptyFolders.find(temp.path);
      expect(found, hasLength(1));
      // Arada bir indirme bitti:
      File(p.join(dir.path, 'yeni.bin')).writeAsBytesSync([1]);
      expect(await EmptyFolders.deleteAll(found), 0);
      expect(dir.existsSync(), isTrue);
    });
  });
}
