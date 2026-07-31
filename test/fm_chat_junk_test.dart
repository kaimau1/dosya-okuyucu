import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/chat_junk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı sorusu 2026-07-31: *"WhatsApp'tan 10 bin fotoğraf var, %90'ı
/// gereksiz, bunu nasıl çözeriz?"* Çözüm 10 bin kararı birkaç kovaya indirmek.
/// Bu testler kovalama kurallarını kilitler: burada bir hata **kullanıcının
/// fotoğrafını siler**, o yüzden sınıflandırma saf tutulup teste bağlandı.
const _gun = 24 * 60 * 60 * 1000;

/// Gerçekçi bir "şimdi" (2026-07-31). Küçük bir sayı kullanmak, `now - 400
/// gün`ü NEGATİF yapıp "eski" kuralını sessizce devre dışı bırakıyordu.
const now = 1785456000000;

FsEntry file(
  String path, {
  int size = 500 * 1024,
  int? modifiedMs,
}) =>
    FsEntry(
      path: path,
      name: path.split('/').last,
      isDir: false,
      sizeBytes: size,
      // Varsayılan DÜN: aksi hâlde her dosya "eski" kovasına düşer ve
      // testler yanlış sebeple geçerdi.
      modifiedMs: modifiedMs ?? now - _gun,
      accessedMs: 0,
    );

void main() {

  group('isChatMediaPath', () {
    test('WhatsApp ve Telegram yolları tanınır', () {
      expect(isChatMediaPath('/depo/WhatsApp/Media/WhatsApp Images/a.jpg'),
          isTrue);
      expect(isChatMediaPath('/depo/Telegram/Telegram Images/b.jpg'), isTrue);
    });

    test('kamera ve indirilenler sohbet medyası DEĞİL', () {
      expect(isChatMediaPath('/depo/DCIM/Camera/IMG_1.jpg'), isFalse);
      expect(isChatMediaPath('/depo/Download/fatura.pdf'), isFalse);
    });
  });

  group('classifyChatJunk kovaları', () {
    test('çıkartma, GIF ve profil fotoğrafı kendi kovasına gider', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/WhatsApp/Media/WhatsApp Stickers/s.webp'),
          file('/depo/WhatsApp/Media/WhatsApp Animated Gifs/g.mp4'),
          file('/depo/WhatsApp/Media/WhatsApp Profile Photos/p.jpg'),
        ],
        nowMs: now,
      );

      final kinds = {for (final b in report.buckets) b.kind: b.count};
      expect(kinds[ChatJunkKind.sticker], 1);
      expect(kinds[ChatJunkKind.gif], 1);
      expect(kinds[ChatJunkKind.profilePhoto], 1);
    });

    test('eşiğin altındaki görüntü "küçük", üstündeki dokunulmaz', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/WhatsApp/Media/WhatsApp Images/mem.jpg',
              size: 40 * 1024),
          file('/depo/WhatsApp/Media/WhatsApp Images/foto.jpg',
              size: 900 * 1024),
        ],
        nowMs: now,
        tinyBytes: 150 * 1024,
      );

      final tiny = report.buckets
          .firstWhere((b) => b.kind == ChatJunkKind.tiny);
      expect(tiny.files.single.name, 'mem.jpg');
      expect(report.junkFiles, 1);
      expect(report.scannedFiles, 2);
    });

    test('Sent klasörü "gönderdiklerim"e girer', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/WhatsApp/Media/WhatsApp Images/Sent/ben.jpg'),
        ],
        nowMs: now,
      );
      expect(report.buckets.single.kind, ChatJunkKind.sent);
    });

    test('aylardır dokunulmamış dosya "eski" olur, yenisi olmaz', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/WhatsApp/Media/WhatsApp Images/eski.jpg',
              modifiedMs: now - 400 * _gun),
          file('/depo/WhatsApp/Media/WhatsApp Images/yeni.jpg',
              modifiedMs: now - 3 * _gun),
        ],
        nowMs: now,
        staleDays: 180,
      );

      final stale =
          report.buckets.firstWhere((b) => b.kind == ChatJunkKind.stale);
      expect(stale.files.single.name, 'eski.jpg');
    });

    /// Açılmış dosya "unutulmuş" değildir: kullanıcı ona bakmış.
    test('açılmış eski dosya "eski" kovasına GİRMEZ', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/WhatsApp/Media/WhatsApp Images/bakilmis.jpg',
              modifiedMs: now - 400 * _gun),
        ],
        nowMs: now,
        wasOpened: (path) => path.endsWith('bakilmis.jpg'),
      );
      expect(report.buckets, isEmpty);
    });

    test('sohbet dışındaki dosyalar hiç taranmaz', () {
      final report = classifyChatJunk(
        entries: [
          file('/depo/DCIM/Camera/IMG_1.jpg', size: 10 * 1024),
        ],
        nowMs: now,
      );
      expect(report.scannedFiles, 0);
      expect(report.buckets, isEmpty);
    });
  });

  group('birebir kopyalar', () {
    test('en eski kopya KORUNUR, kalanı kovaya girer', () {
      final a = file('/depo/WhatsApp/Media/WhatsApp Images/a.jpg',
          modifiedMs: now - 10 * _gun);
      final b = file('/depo/WhatsApp/Media/WhatsApp Images/b.jpg',
          modifiedMs: now - 5 * _gun);
      final c = file('/depo/WhatsApp/Media/WhatsApp Images/c.jpg',
          modifiedMs: now - _gun);

      final report = classifyChatJunk(
        entries: [a, b, c],
        nowMs: now,
        duplicateGroups: [
          [a, b, c]
        ],
      );

      final dupes =
          report.buckets.firstWhere((b) => b.kind == ChatJunkKind.duplicate);
      expect(dupes.files.map((e) => e.name), ['b.jpg', 'c.jpg']);
    });

    /// Kümenin bir parçası sohbet klasörünün DIŞINDAysa buradakilerin hepsini
    /// silmek dosyayı tümden yok edebilirdi — en az biri kalmalı.
    test('kapsam içinde tek kopya varsa hiçbiri silinmez', () {
      final chat = file('/depo/WhatsApp/Media/WhatsApp Images/a.jpg');
      final camera = file('/depo/DCIM/Camera/a.jpg');

      final report = classifyChatJunk(
        entries: [chat, camera],
        nowMs: now,
        duplicateGroups: [
          [chat, camera]
        ],
      );

      expect(
        report.buckets.where((b) => b.kind == ChatJunkKind.duplicate),
        isEmpty,
      );
    });

    /// Aynı dosya iki kovada sayılsaydı "şu kadar yer açılacak" toplamı yalan
    /// olurdu ve kullanıcı aynı dosyayı iki kez silmeye çalışırdı.
    test('bir dosya en çok BİR kovada görünür', () {
      final a = file('/depo/WhatsApp/Media/WhatsApp Images/Sent/a.jpg',
          size: 20 * 1024, modifiedMs: now - 900 * _gun);
      final b = file('/depo/WhatsApp/Media/WhatsApp Images/Sent/b.jpg',
          size: 20 * 1024, modifiedMs: now - 900 * _gun);

      final report = classifyChatJunk(
        entries: [a, b],
        nowMs: now,
        duplicateGroups: [
          [a, b]
        ],
      );

      final seen = <String>{};
      for (final bucket in report.buckets) {
        for (final f in bucket.files) {
          expect(seen.add(f.path), isTrue, reason: '${f.name} iki kovada');
        }
      }
      // b: kopya kovasında (a en eski, korunuyor). a: kopya kovasında DEĞİL
      // ama kendisi de 20 KB'lık iletilmiş bir görüntü → "küçük" kovasında.
      // İkisi de gereksiz, ama her biri TEK bir sebeple sayılıyor.
      expect(report.junkFiles, 2);
      expect(
        report.buckets.firstWhere((b) => b.kind == ChatJunkKind.duplicate)
            .files.single.name,
        'b.jpg',
      );
      expect(
        report.buckets.firstWhere((b) => b.kind == ChatJunkKind.tiny)
            .files.single.name,
        'a.jpg',
      );
    });
  });

  group('özet sayıları', () {
    test('yüzde taranan yığına göre hesaplanır', () {
      final entries = [
        for (var i = 0; i < 8; i++)
          file('/depo/WhatsApp/Media/WhatsApp Stickers/s$i.webp',
              size: 10 * 1024),
        for (var i = 0; i < 2; i++)
          file('/depo/WhatsApp/Media/WhatsApp Images/f$i.jpg',
              size: 900 * 1024, modifiedMs: now),
      ];

      final report = classifyChatJunk(entries: entries, nowMs: now);

      expect(report.scannedFiles, 10);
      expect(report.junkFiles, 8);
      expect(report.junkPercent, 80);
      expect(report.junkBytes, 8 * 10 * 1024);
    });

    test('boş yığında yüzde 0 (sıfıra bölme yok)', () {
      final report = classifyChatJunk(entries: const [], nowMs: now);
      expect(report.junkPercent, 0);
      expect(report.buckets, isEmpty);
    });
  });

  group('varsayılan seçim', () {
    /// Fotoğraf içeren hiçbir kova varsayılan seçili gelmez; yanlışlıkla
    /// silinen anı geri gelmez. Yalnız kopyalar güvenli (bir kopya kalıyor).
    test('yalnız kopyalar güvenli sayılır', () {
      expect(ChatJunkKind.duplicate.safeByDefault, isTrue);
      for (final kind in ChatJunkKind.values) {
        if (kind == ChatJunkKind.duplicate) continue;
        expect(kind.safeByDefault, isFalse, reason: '$kind');
      }
    });

    test('her kovanın etiketi ve gerekçesi vardır', () {
      for (final kind in ChatJunkKind.values) {
        expect(kind.labelKey, startsWith('cj.kind_'));
        expect(kind.reasonKey, startsWith('cj.why_'));
      }
    });
  });
}
