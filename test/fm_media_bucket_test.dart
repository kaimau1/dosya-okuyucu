import 'package:dosya_okuyucu/models/file_age.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:dosya_okuyucu/services/fm/installed_apps_service.dart';
import 'package:dosya_okuyucu/services/fm/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('medya kaynağı sınıflandırma', () {
    test('gerçek Android klasör düzenleri doğru kaynağa düşer', () {
      const root = '/storage/emulated/0';
      expect(bucketForPath('$root/DCIM/Camera/IMG_20260724_101010.jpg'),
          MediaBucket.camera);
      expect(bucketForPath('$root/DCIM/100ANDRO/DSC_0001.JPG'),
          MediaBucket.camera);
      expect(bucketForPath('$root/Pictures/Screenshots/Screenshot_2026.png'),
          MediaBucket.screenshot);
      // Ekran görüntüsü DCIM altında da olabilir → kameradan ÖNCE bakılmalı.
      expect(bucketForPath('$root/DCIM/Screenshots/Screenshot_2026.png'),
          MediaBucket.screenshot);
      expect(
        bucketForPath('$root/WhatsApp/Media/WhatsApp Images/IMG-WA0001.jpg'),
        MediaBucket.whatsapp,
      );
      // Android 11+ düzeni (uygulamanın kendi medya klasörü)
      expect(
        bucketForPath(
            '$root/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/VID-20260724-WA0008.mp4'),
        MediaBucket.whatsapp,
      );
      expect(bucketForPath('$root/Telegram/Telegram Video/video.mp4'),
          MediaBucket.telegram);
      expect(
          bucketForPath('$root/Android/media/org.telegram.messenger/a.jpg'),
          MediaBucket.telegram);
      expect(bucketForPath('$root/Pictures/Instagram/reel.mp4'),
          MediaBucket.instagram);
      expect(bucketForPath('$root/Download/kitap.jpg'), MediaBucket.download);
      expect(bucketForPath('$root/Bluetooth/gelen.jpg'), MediaBucket.bluetooth);
      expect(bucketForPath('$root/Belgeler/tarama.jpg'), MediaBucket.other);
    });

    test('büyük/küçük harf farkı önemsiz', () {
      expect(bucketForPath('/sd/DCIM/Camera/a.JPG'), MediaBucket.camera);
      expect(bucketForPath('/sd/WHATSAPP/Media/x.jpg'), MediaBucket.whatsapp);
    });

    test('bucketCounts: filtre çipi sayıları', () {
      final counts = bucketCounts(const [
        '/a/DCIM/Camera/1.jpg',
        '/a/DCIM/Camera/2.jpg',
        '/a/WhatsApp/Media/3.jpg',
        '/a/rastgele/4.jpg',
      ]);
      expect(counts[MediaBucket.camera], 2);
      expect(counts[MediaBucket.whatsapp], 1);
      expect(counts[MediaBucket.other], 1);
      expect(counts[MediaBucket.telegram], isNull);
    });
  });

  group('uygulama kullanılmama seviyesi', () {
    test('gün sayısına göre renk seviyesi', () {
      expect(idleLevelFor(0, usageKnown: true), AppIdleLevel.active);
      expect(idleLevelFor(6, usageKnown: true), AppIdleLevel.active);
      expect(idleLevelFor(7, usageKnown: true), AppIdleLevel.quiet);
      expect(idleLevelFor(29, usageKnown: true), AppIdleLevel.quiet);
      expect(idleLevelFor(30, usageKnown: true), AppIdleLevel.stale);
      expect(idleLevelFor(89, usageKnown: true), AppIdleLevel.stale);
      expect(idleLevelFor(90, usageKnown: true), AppIdleLevel.forgotten);
      // Hiç açılmamış (kullanım kaydı yok ama izin var) → unutulmuş sayılır.
      expect(idleLevelFor(null, usageKnown: true), AppIdleLevel.forgotten);
      // İzin yoksa renklendirme yapılmaz.
      expect(idleLevelFor(200, usageKnown: false), AppIdleLevel.unknown);
    });

    test('idleDays: son kullanım zamanından gün farkı', () {
      const day = 86400000;
      final now = DateTime.now().millisecondsSinceEpoch;
      final app = InstalledAppEntry(
        name: 'Test',
        packageName: 'com.test',
        versionName: '1.0',
        icon: null,
        installedAtMs: 0,
        lastUsedMs: now - 10 * day,
        usageKnown: true,
      );
      expect(app.idleDays(now), 10);

      const unknown = InstalledAppEntry(
        name: 'Test',
        packageName: 'com.test',
        versionName: '1.0',
        icon: null,
        installedAtMs: 0,
        lastUsedMs: 0,
        usageKnown: true,
      );
      expect(unknown.idleDays(now), isNull);
    });

    test('parseLastUsed: UsageStats metin zaman damgası', () {
      expect(InstalledAppsService.parseLastUsed('1750000000000'),
          1750000000000);
      expect(InstalledAppsService.parseLastUsed(null), 0);
      expect(InstalledAppsService.parseLastUsed(''), 0);
      expect(InstalledAppsService.parseLastUsed('abc'), 0);
      expect(InstalledAppsService.parseLastUsed('0'), 0);
    });
  });

  group('video küçük resmi önbelleği', () {
    test('anahtar yola + değişiklik zamanına + boya bağlı', () {
      final a = ThumbnailCache.cacheName('/a/v.mp4', 100, 256);
      final same = ThumbnailCache.cacheName('/a/v.mp4', 100, 256);
      final otherTime = ThumbnailCache.cacheName('/a/v.mp4', 200, 256);
      final otherSize = ThumbnailCache.cacheName('/a/v.mp4', 100, 128);
      final otherPath = ThumbnailCache.cacheName('/a/w.mp4', 100, 256);

      expect(a, same);
      expect(a, isNot(otherTime)); // dosya değişince küçük resim tazelenir
      expect(a, isNot(otherSize));
      expect(a, isNot(otherPath));
      expect(a, endsWith('.jpg'));
    });
  });

  group('dosya yaşı (İndirilenler temizliği)', () {
    test('gün sayısına göre seviye', () {
      expect(ageLevelFor(0), AgeLevel.fresh);
      expect(ageLevelFor(6), AgeLevel.fresh);
      expect(ageLevelFor(7), AgeLevel.recent);
      expect(ageLevelFor(29), AgeLevel.recent);
      expect(ageLevelFor(30), AgeLevel.old);
      expect(ageLevelFor(179), AgeLevel.old);
      expect(ageLevelFor(180), AgeLevel.ancient);
      expect(ageLevelFor(null), AgeLevel.unknown);
      expect(ageLevelFor(-3), AgeLevel.unknown);
    });

    test('daysBetween: geçersiz değerlerde null', () {
      const day = 86400000;
      expect(daysBetween(1000, 1000 + 3 * day), 3);
      expect(daysBetween(0, 1000), isNull);
      expect(daysBetween(2000, 1000), isNull); // gelecek tarih
    });

    test('relativeDays: kısa Türkçe ifade', () {
      expect(relativeDays(0), 'bugün');
      expect(relativeDays(1), 'dün');
      expect(relativeDays(5), '5 gün önce');
      expect(relativeDays(60), '2 ay önce');
      expect(relativeDays(400), '1 yıl önce');
      expect(relativeDays(null), '—');
    });

    test('FsEntry: erişim zamanı ancak yazmadan SONRAysa bilgi sayılır', () {
      const written = FsEntry(
        path: '/a/x.pdf',
        name: 'x.pdf',
        isDir: false,
        sizeBytes: 10,
        modifiedMs: 5000,
        accessedMs: 4000, // atime güncellenmemiş (noatime) → güvenilmez
      );
      expect(written.hasAccessInfo, isFalse);
      expect(written.lastTouchedMs, 5000);

      const opened = FsEntry(
        path: '/a/x.pdf',
        name: 'x.pdf',
        isDir: false,
        sizeBytes: 10,
        modifiedMs: 5000,
        accessedMs: 9000,
      );
      expect(opened.hasAccessInfo, isTrue);
      expect(opened.lastTouchedMs, 9000);
    });
  });
}
