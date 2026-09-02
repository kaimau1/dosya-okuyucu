import 'dart:io';

import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// **USB belleği SD karttan ayırmak** — kullanıcı isteği 2026-09-01:
/// *"harici USB taktığımda göremiyorum onu uygulamamızda görebilmeliyiz."*
///
/// İkisi de `/storage/<UUID>` altına bağlanıyor; tek ayırt edici, bağlama
/// tablosundaki AYGIT adı. Bu yüzden karar saf bir fonksiyona toplandı ve
/// gerçek `/proc/mounts` satırlarıyla test ediliyor.
void main() {
  group('kindOf', () {
    test('vold public:8 (SCSI disk) → USB', () {
      const mounts = [
        '/dev/block/vold/public:8,1 /storage/1A2B-3C4D vfat rw,dirsync 0 0',
      ];
      expect(StorageStats.kindOf('/storage/1A2B-3C4D', mounts),
          StorageKind.usb);
    });

    test('vold public:179 (MMC) → SD kart', () {
      const mounts = [
        '/dev/block/vold/public:179,65 /storage/AAAA-BBBB vfat rw 0 0',
      ];
      expect(StorageStats.kindOf('/storage/AAAA-BBBB', mounts),
          StorageKind.sdCard);
    });

    test('doğrudan /dev/block/sda1 → USB', () {
      const mounts = ['/dev/block/sda1 /mnt/media_rw/USB exfat rw 0 0'];
      expect(StorageStats.kindOf('/mnt/media_rw/USB', mounts), StorageKind.usb);
    });

    test('mmcblk aygıtı → SD kart', () {
      const mounts = ['/dev/block/mmcblk1p1 /storage/CARD vfat rw 0 0'];
      expect(StorageStats.kindOf('/storage/CARD', mounts), StorageKind.sdCard);
    });

    test('bağlama noktası TAM eşleşir (önek karışmaz)', () {
      // `/storage/1A2B` USB, `/storage/1A2B-3C4D` SD kart: önek eşleşmesi
      // yapılsaydı ikincisi de USB sanılırdı.
      const mounts = [
        '/dev/block/sda1 /storage/1A2B vfat rw 0 0',
        '/dev/block/vold/public:179,1 /storage/1A2B-3C4D vfat rw 0 0',
      ];
      expect(StorageStats.kindOf('/storage/1A2B', mounts), StorageKind.usb);
      expect(StorageStats.kindOf('/storage/1A2B-3C4D', mounts),
          StorageKind.sdCard);
    });

    test('tablo okunamadıysa /mnt/usb yolu USB sayılır', () {
      expect(StorageStats.kindOf('/mnt/usb/otg', const []), StorageKind.usb);
    });

    test('hiçbir ipucu yoksa SD kart varsayılır (eski davranış)', () {
      expect(StorageStats.kindOf('/storage/XYZ', const []),
          StorageKind.sdCard);
    });

    test('bozuk satırlar çökertmez', () {
      const mounts = ['', '   ', 'tek-alan', '/dev/block/sda1'];
      expect(StorageStats.kindOf('/storage/XYZ', mounts), StorageKind.sdCard);
    });
  });

  // **2026-09-02 ÇÖKME (kullanıcı: "verileri görmedi güncellemeden sonra").**
  // `/mnt/media_rw` telefonda VAR ama `media_rw` grubuna ait; uygulama `/mnt`
  // içinde gezinemediği için `Directory(...).existsSync()` false DÖNMÜYOR,
  // `FileSystemException: Exists failed … Permission denied (errno = 13)`
  // fırlatıyor. O çağrı `try`nin dışındaydı → `volumes()` çöktü,
  // `FmEnv.ensureInit` çöktü ve pano sonsuza dek "Depolama taranıyor…"
  // gösterdi. Sözleşme artık tek yerde: `entriesOf` HİÇBİR koşulda fırlatmaz.
  //
  // Not: izin hatası testte üretilemiyor (test kök kullanıcı olarak koşuyor ve
  // çekirdek kök için izin denetimini atlıyor); gerçek EACCES ile doğrulama
  // ayrıca `nobody` kullanıcısıyla derlenmiş bir ikilide yapıldı. Buradaki
  // durumlar aynı `try` bloğundan geçen ulaşılabilir olanlar.
  group('entriesOf — fırlatmaz', () {
    test('var olmayan kök boş liste verir', () {
      expect(StorageStats.entriesOf('/kesinlikle/olmayan/kok'), isEmpty);
    });

    test('araya dosya giren yol boş liste verir', () {
      expect(StorageStats.entriesOf('/etc/hostname/altinda'), isEmpty);
    });

    test('kök bir DOSYA ise boş liste verir (listeleme ENOTDIR atar)', () {
      final file = File('${Directory.systemTemp.path}/entries_probe.txt')
        ..writeAsStringSync('x');
      addTearDown(file.deleteSync);
      expect(StorageStats.entriesOf(file.path), isEmpty);
    });

    test('gerçek klasörün girdilerini verir', () {
      final dir = Directory.systemTemp.createTempSync('entries_ok');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/USB1').createSync();
      expect(StorageStats.entriesOf(dir.path), hasLength(1));
    });

    test('gerçek köklerin hiçbiri fırlatmaz', () {
      for (final root in StorageStats.removableRoots) {
        expect(() => StorageStats.entriesOf(root), returnsNormally);
      }
    });
  });

  group('StorageVolume', () {
    test('takılabilir birim ana bellekten ayrılır', () {
      const internal = StorageVolume(path: '/storage/emulated/0', isPrimary: true);
      const usb = StorageVolume(
          path: '/storage/1A2B-3C4D', isPrimary: false, kind: StorageKind.usb);
      expect(internal.isRemovable, isFalse);
      expect(usb.isRemovable, isTrue);
      expect(usb.iconName, 'usb');
      expect(internal.iconName, 'smartphone');
    });

    test('copyWith türü korur', () {
      const usb = StorageVolume(
          path: '/storage/X', isPrimary: false, kind: StorageKind.usb);
      expect(usb.copyWith(totalBytes: 100, freeBytes: 50).kind,
          StorageKind.usb);
    });
  });
}
