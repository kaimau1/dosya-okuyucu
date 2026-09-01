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
