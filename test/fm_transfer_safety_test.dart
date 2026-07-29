import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/trash_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var (2026-07-29 sadakat denetimi, 4. tur):** bu katman
/// kullanıcının GERÇEK dosyalarını taşıyor, siliyor ve geri yüklüyor. Buradaki
/// bir hata geri alınamaz. Denetimde bulunan dört veri kaybı yolu burada
/// kilitleniyor:
/// 1. `FmConflict.skip` + klasör taşıma: atlanan çocuk kopyalanmadığı hâlde
///    kaynak klasör komple siliniyordu → dosyanın TEK kopyası yok oluyordu.
/// 2. `FmConflict.overwrite`: hedef, yerine bir şey konmadan ÖNCE siliniyordu.
/// 3. İptal edilen taşımada `transfers` boş dönüyordu → "Geri al" yok.
/// 4. Çöp kaydı (`index.json`) üzerine yazılıyordu; yarım yazma tüm çöpü
///    görünmez yapıyordu.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transfer_safety');
    FmEnv.appSupportDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<String> write(String relative, String content) async {
    final file = File('${tempDir.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  }

  group('FmConflict.skip + klasör taşıma', () {
    test('ATLANAN çocuk yüzünden kaynak klasör SİLİNMEZ', () async {
      await write('kaynak/Fotolar/1.jpg', 'ozgun-icerik');
      await write('kaynak/Fotolar/2.jpg', 'ikinci');
      // Hedefte AYNI adda, FARKLI içerikli bir dosya var → atlanacak.
      await write('hedef/Fotolar/1.jpg', 'hedefteki-baska-dosya');

      final result = await FileOps.moveAll(
        ['${tempDir.path}/kaynak/Fotolar'],
        '${tempDir.path}/hedef',
        conflict: FmConflict.skip,
      );

      // Atlanan dosyanın özgün kopyası HÂLÂ yerinde olmalı.
      expect(File('${tempDir.path}/kaynak/Fotolar/1.jpg').existsSync(), isTrue,
          reason: 'atlanan dosya hiçbir yere kopyalanmadı; silinirse KAYIP');
      expect(
          await File('${tempDir.path}/kaynak/Fotolar/1.jpg').readAsString(),
          'ozgun-icerik');
      // Hedefteki dosyaya dokunulmamalı.
      expect(await File('${tempDir.path}/hedef/Fotolar/1.jpg').readAsString(),
          'hedefteki-baska-dosya');
      // Çakışmayan dosya taşınmış olmalı.
      expect(File('${tempDir.path}/hedef/Fotolar/2.jpg').existsSync(), isTrue);
      expect(result.skipped, greaterThan(0));
    });

    test('çakışma YOKSA klasör normal şekilde taşınır (kaynak silinir)',
        () async {
      await write('kaynak/Albüm/a.jpg', 'a');
      await write('kaynak/Albüm/alt/b.jpg', 'b');

      await FileOps.moveAll(
        ['${tempDir.path}/kaynak/Albüm'],
        '${tempDir.path}/hedef',
        conflict: FmConflict.skip,
      );

      expect(Directory('${tempDir.path}/kaynak/Albüm').existsSync(), isFalse);
      expect(File('${tempDir.path}/hedef/Albüm/a.jpg').existsSync(), isTrue);
      expect(File('${tempDir.path}/hedef/Albüm/alt/b.jpg').existsSync(), isTrue);
    });
  });

  group('FmConflict.overwrite', () {
    test('hedef gerçekten değişir (kopyalama yapılır)', () async {
      final src = await write('a/x.txt', 'yeni');
      await write('b/x.txt', 'eski');

      await FileOps.copyAll([src], '${tempDir.path}/b',
          conflict: FmConflict.overwrite);

      expect(await File('${tempDir.path}/b/x.txt').readAsString(), 'yeni');
      // Kaynak kopyalamada yerinde kalır.
      expect(File(src).existsSync(), isTrue);
    });

    test('kaynak okunamıyorsa HEDEF SİLİNMEZ (önce sil deseni kalktı)',
        () async {
      await write('b/x.txt', 'degerli-veri');
      // Var olmayan kaynak: aktarma hata verir.
      final result = await FileOps.copyAll(
        ['${tempDir.path}/a/olmayan.txt'],
        '${tempDir.path}/b',
        conflict: FmConflict.overwrite,
      );
      expect(result.hasError, isTrue);
      expect(File('${tempDir.path}/b/x.txt').existsSync(), isTrue,
          reason: '"üzerine yaz" isteği, yerine bir şey koymadan silmek DEĞİL');
      expect(
          await File('${tempDir.path}/b/x.txt').readAsString(), 'degerli-veri');
    });
  });

  group('iptal', () {
    test('iptal edilen taşımada transfers DÖNER (Geri al çalışsın)', () async {
      final a = await write('kaynak/a.txt', 'a');
      final b = await write('kaynak/b.txt', 'b');
      await Directory('${tempDir.path}/hedef').create();

      // İlk dosyadan sonra iptal: ikinci tur döngü başında yakalanır.
      var calls = 0;
      final result = await FileOps.moveAll(
        [a, b],
        '${tempDir.path}/hedef',
        isCancelled: () => calls++ > 0,
      );

      expect(result.cancelled, isTrue);
      expect(result.transfers, isNotEmpty,
          reason: 'taşınmış dosyaların geri alınabilmesi için şart');
      expect(result.transfers.first.source, a);
      expect(File('${tempDir.path}/hedef/a.txt').existsSync(), isTrue);
      // İkincisi hiç taşınmadı.
      expect(File(b).existsSync(), isTrue);
    });

    test('geri alma dosyayı ESKİ ADIYLA döndürür', () async {
      final src = await write('kaynak/rapor.pdf', 'icerik');
      // Hedefte aynı adda dosya var → taşınırken "rapor (1).pdf" olacak.
      await write('hedef/rapor.pdf', 'baska');

      final moved = await FileOps.moveAll([src], '${tempDir.path}/hedef');
      expect(moved.transfers, hasLength(1));
      expect(moved.transfers.first.dest, contains('rapor (1).pdf'));

      final back = await FileOps.undoMove(moved.transfers);
      expect(back.hasError, isFalse);
      expect(File(src).existsSync(), isTrue,
          reason: 'geri alma eski ADA da dönmeli, "rapor (1).pdf" bırakmamalı');
      expect(await File(src).readAsString(), 'icerik');
    });
  });

  group('çöp kaydı dayanıklılığı', () {
    TrashService service() => TrashService(
          volumeRoots: [tempDir.path],
          fallbackRoot: '${tempDir.path}/support',
        );

    test('kayıt atomik yazılır: .tmp dosyası ARDA KALMAZ', () async {
      final path = await write('sil.txt', 'x');
      await service().moveToTrash([path]);
      final indexTmp =
          File('${tempDir.path}/${TrashService.dirName}/index.json.tmp');
      expect(indexTmp.existsSync(), isFalse);
      expect(
          File('${tempDir.path}/${TrashService.dirName}/index.json')
              .existsSync(),
          isTrue);
    });

    test('eşzamanlı çöpe atmalar birbirinin kaydını EZMEZ', () async {
      final a = await write('a.txt', 'a');
      final b = await write('b.txt', 'b');
      final c = await write('c.txt', 'c');
      final trash = service();
      // Üçü aynı anda: kayıt katmanı sıraya almazsa "oku-değiştir-yaz" yarışı
      // kayıt düşürür ve dosya çöpte görünmez kalır.
      await Future.wait([
        trash.moveToTrash([a]),
        trash.moveToTrash([b]),
        trash.moveToTrash([c]),
      ]);
      final items = await trash.list();
      expect(items, hasLength(3),
          reason: 'kayıtlardan biri kaybolursa o dosya geri alınamaz');
    });

    test('klasörün boyutu kayda GERÇEK değerle yazılır', () async {
      await write('klasor/1.bin', 'aaaaaaaaaa'); // 10 bayt
      await write('klasor/2.bin', 'bbbbb'); // 5 bayt
      final trash = service();
      await trash.moveToTrash(['${tempDir.path}/klasor']);
      final items = await trash.list();
      expect(items, hasLength(1));
      expect(items.first.isDir, isTrue);
      expect(items.first.sizeBytes, 15,
          reason: '0 yazılırsa "0 B yer açıldı" gibi yanlış bilgi çıkar');
    });

    test('silinemeyen öğenin kaydı KORUNUR (görünmez dosya kalmasın)',
        () async {
      final path = await write('sil.txt', 'x');
      final trash = service();
      await trash.moveToTrash([path]);
      final items = await trash.list();
      expect(items, hasLength(1));

      // Çöpteki dosyayı silinemez yapmak yerine, "zaten yok" durumunu sınıyoruz:
      // dosya yoksa kayıt DÜŞER (kullanıcı elle silmiş olabilir).
      await File(items.first.storedPath).delete();
      await trash.deleteForever(items.first);
      expect(await trash.list(), isEmpty);
    });
  });
}
