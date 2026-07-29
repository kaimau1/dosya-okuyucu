import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/file_tags.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/open_history.dart';
import 'package:dosya_okuyucu/services/fm/path_side_index.dart';
import 'package:dosya_okuyucu/services/fm/trash_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var (2026-07-29 sadakat denetimi):** etiketler ve açılma
/// geçmişi dosyayı **yolundan** tanıyor. `movePath` yazılmıştı ama HİÇBİR YERDEN
/// ÇAĞRILMIYORDU — yani kullanıcı "Ayşe" diye etiketlediği fotoğrafı bizim
/// uygulamamızla başka klasöre taşıyınca etiketi sessizce kayboluyordu. Üstelik
/// etiket sayfasında ona *"başka bir uygulamayla taşırsan etiket onunla
/// gitmez"* yazıyordu, yani uygulama içinde korunacağı söylenmiş oluyordu.
/// Bu testler o sözü kilitler: taşı / yeniden adlandır / çöpe at + geri al.
void main() {
  late Directory tempDir;
  late Directory support;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('side_index_test');
    support = await Directory('${tempDir.path}/support').create();
    FmEnv.appSupportDir = support.path;
    FileTags.resetForTest();
    OpenHistory.resetForTest();
    PathSideIndex.resetForTest();
    // Üretimde `main` bağlıyor; test kendi bağlar (bkz. path_side_index.dart).
    PathSideIndex.register((from, to) async {
      await FileTags.movePath(from, to);
      await OpenHistory.movePath(from, to);
    });
  });

  tearDown(() async {
    PathSideIndex.resetForTest();
    await tempDir.delete(recursive: true);
  });

  Future<String> makeFile(String relative) async {
    final file = File('${tempDir.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString('icerik');
    return file.path;
  }

  group('kanca', () {
    test('kayıt yoksa sessizce geçer', () async {
      await PathSideIndex.moved('/yok/a.txt', '/yok/b.txt');
      // Çökmediyse geçti.
    });

    test('aynı yol verilirse hiçbir şey yapmaz', () async {
      var calls = 0;
      PathSideIndex.register((from, to) async => calls++);
      await PathSideIndex.moved('/a', '/a');
      expect(calls, 0);
    });

    test('kanca patlarsa dosya işlemi ETKİLENMEZ', () async {
      PathSideIndex.register((from, to) async => throw StateError('patladı'));
      await PathSideIndex.moved('/a', '/b'); // atmamalı
    });
  });

  group('yeniden adlandırma', () {
    test('etiket ve açılma geçmişi yeni ada taşınır', () async {
      final path = await makeFile('foto.jpg');
      await FileTags.add([path], 'Ayşe');
      await OpenHistory.record(path);

      final renamed = await FileOps.rename(path, 'tatil.jpg');

      expect(FileTags.forPath(path), isEmpty);
      expect(FileTags.forPath(renamed), {'Ayşe'});
      expect(OpenHistory.forPath(path), isNull);
      expect(OpenHistory.forPath(renamed), isNotNull);
    });
  });

  group('taşıma', () {
    test('TAŞIMADA etiket dosyayla birlikte gider', () async {
      final path = await makeFile('kaynak/foto.jpg');
      final destDir = Directory('${tempDir.path}/hedef');
      await destDir.create();
      await FileTags.add([path], 'İş grubu');

      final result = await FileOps.moveAll([path], destDir.path);
      expect(result.succeeded, 1);

      final moved = '${destDir.path}/foto.jpg';
      expect(File(moved).existsSync(), isTrue);
      expect(FileTags.forPath(path), isEmpty);
      expect(FileTags.forPath(moved), {'İş grubu'});
    });

    test('KOPYALAMADA etiket kaynakta KALIR, kopyaya yapışmaz', () async {
      // Bilinçli karar: kopyaya da etiket yapıştırmak kullanıcının vermediği
      // bir karar olurdu ("iki dosyada aynı kişi etiketi").
      final path = await makeFile('kaynak/foto.jpg');
      final destDir = Directory('${tempDir.path}/hedef');
      await destDir.create();
      await FileTags.add([path], 'Ayşe');

      await FileOps.copyAll([path], destDir.path);

      expect(FileTags.forPath(path), {'Ayşe'});
      expect(FileTags.forPath('${destDir.path}/foto.jpg'), isEmpty);
    });
  });

  // ── KLASÖR taşıma: alt kayıtlar (2026-07-29 denetimi, 2. tur) ──────────────
  // `movePath` yalnız TAM anahtara bakıyordu. Kanca klasörler için de
  // çağrıldığı hâlde, bir klasörü yeniden adlandırmak içindeki tüm dosyaların
  // etiketini "ölü" bir yola çiviliyordu: süzgeç çipi "Ayşe (40)" yazarken
  // liste boş dönüyor, kayıtlar da (`_shouldKeep` eski üst klasörü göremediği
  // için) sonsuza dek temizlenmiyordu.
  group('movedPathFor (saf yol hesabı)', () {
    test('tam eşleşme yeni yolu verir', () {
      expect(movedPathFor(path: '/a/b.jpg', from: '/a/b.jpg', to: '/a/c.jpg'),
          '/a/c.jpg');
    });

    test('klasörün ALTINDAKİ yol yeniden yazılır', () {
      expect(
          movedPathFor(
              path: '/DCIM/Tatil/foto.jpg',
              from: '/DCIM/Tatil',
              to: '/DCIM/Tatil 2025'),
          '/DCIM/Tatil 2025/foto.jpg');
      expect(
          movedPathFor(
              path: '/DCIM/Tatil/alt/derin/foto.jpg',
              from: '/DCIM/Tatil',
              to: '/Yeni/Yer'),
          '/Yeni/Yer/alt/derin/foto.jpg');
    });

    test('AD ÖNEKİ eşleşmesi yeniden yazılmaz (Tatil ≠ Tatil 2025)', () {
      expect(
          movedPathFor(
              path: '/DCIM/Tatil 2025/foto.jpg',
              from: '/DCIM/Tatil',
              to: '/DCIM/Gezi'),
          isNull,
          reason: 'sınır ayırıcıda olmalı, yoksa komşu klasör de taşınır');
    });

    test('ilgisiz yol null döner', () {
      expect(movedPathFor(path: '/x/y.jpg', from: '/a', to: '/b'), isNull);
    });

    test('ayırıcıyla biten kaynak yolu da çalışır', () {
      expect(movedPathFor(path: '/a/b/c.jpg', from: '/a/b/', to: '/z/'),
          '/z/c.jpg');
    });

    test('ters bölü (Windows) ayırıcısı da sınır sayılır', () {
      expect(
          movedPathFor(
              path: r'C:\Fotolar\Tatil\a.jpg',
              from: r'C:\Fotolar\Tatil',
              to: r'C:\Fotolar\Gezi'),
          r'C:\Fotolar\Gezi\a.jpg');
    });
  });

  group('klasör yeniden adlandırma', () {
    test('KLASÖRÜ adlandırınca İÇİNDEKİ etiketler de taşınır', () async {
      final a = await makeFile('DCIM/Tatil/bir.jpg');
      final b = await makeFile('DCIM/Tatil/alt/iki.jpg');
      final disari = await makeFile('DCIM/Baska/uc.jpg');
      await FileTags.add([a, b], 'Ayşe');
      await FileTags.add([disari], 'Kalsın');
      await OpenHistory.record(a);

      final renamed =
          await FileOps.rename('${tempDir.path}/DCIM/Tatil', 'Tatil 2025');
      expect(renamed, '${tempDir.path}/DCIM/Tatil 2025');

      final newA = '${tempDir.path}/DCIM/Tatil 2025/bir.jpg';
      final newB = '${tempDir.path}/DCIM/Tatil 2025/alt/iki.jpg';
      expect(File(newA).existsSync(), isTrue);
      expect(FileTags.forPath(a), isEmpty);
      expect(FileTags.forPath(newA), {'Ayşe'});
      expect(FileTags.forPath(newB), {'Ayşe'});
      expect(OpenHistory.forPath(newA), isNotNull);
      // Kapsam dışı dosya olduğu yerde kalmalı.
      expect(FileTags.forPath(disari), {'Kalsın'});
      // Çip sayısı listeyle tutarlı: 2 taşınan + 1 dışarıdaki.
      expect(FileTags.counts()['Ayşe'], 2);
    });
  });

  group('çöp kutusu turu', () {
    test('çöpe at + geri al turunda etiket KAYBOLMAZ', () async {
      final path = await makeFile('foto.jpg');
      await FileTags.add([path], 'Ayşe');
      await OpenHistory.record(path);

      final trash = TrashService(
        volumeRoots: [tempDir.path],
        fallbackRoot: support.path,
      );
      final result = await trash.moveToTrash([path]);
      expect(result.succeeded, 1);
      // Dosya artık eski yolunda değil; etiket de orada olmamalı.
      expect(FileTags.forPath(path), isEmpty);

      final items = await trash.list();
      expect(items, hasLength(1));
      final restored = await trash.restore(items.first);

      expect(File(restored).existsSync(), isTrue);
      expect(FileTags.forPath(restored), {'Ayşe'},
          reason: 'çöp turundan sonra etiket geri gelmeli');
      expect(OpenHistory.forPath(restored), isNotNull);
    });
  });
}
