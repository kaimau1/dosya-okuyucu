import 'package:dosya_okuyucu/models/chat_media.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** WhatsApp/Telegram klasör adları Android sürümüne göre
/// değişiyor ve birbirini KAPSIYOR ("WhatsApp Video Notes" hem video hem notes,
/// "Animated Gifs" bazı sürümlerde Images altında). Sıra bozulursa dosyalar
/// yanlış kovaya düşer ve kullanıcı "belge süzgecinde fotoğraflarım çıkıyor"
/// der. Kurallar burada kilitli.
void main() {
  const wa = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media';
  const waOld = '/storage/emulated/0/WhatsApp/Media';
  const tg = '/storage/emulated/0/Telegram';

  FsEntry entry(String path) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: 1000,
        modifiedMs: 0,
      );

  group('WhatsApp tür kırılımı', () {
    test('görüntü', () {
      expect(chatKindForPath('$wa/WhatsApp Images/IMG-20260729-WA0012.jpg'),
          ChatMediaKind.image);
    });

    test('video', () {
      expect(chatKindForPath('$wa/WhatsApp Video/VID-20260729-WA0003.mp4'),
          ChatMediaKind.video);
    });

    test('belge', () {
      expect(chatKindForPath('$wa/WhatsApp Documents/fatura.pdf'),
          ChatMediaKind.document);
    });

    test('ses', () {
      expect(chatKindForPath('$wa/WhatsApp Audio/AUD-0001.m4a'),
          ChatMediaKind.audio);
    });

    test('sesli not SESten önce sınanır (yoksa “ses” kovasına düşerdi)', () {
      expect(chatKindForPath('$wa/WhatsApp Voice Notes/202607/PTT-0001.opus'),
          ChatMediaKind.voice);
    });

    test('çıkartma', () {
      expect(chatKindForPath('$wa/WhatsApp Stickers/STK-0001.webp'),
          ChatMediaKind.sticker);
    });

    test('animasyon GÖRÜNTÜden önce sınanır', () {
      expect(chatKindForPath('$wa/WhatsApp Animated Gifs/VID-0001.mp4'),
          ChatMediaKind.gif);
    });

    test('yuvarlak video notu VİDEO sayılır, sesli not değil', () {
      expect(chatKindForPath('$wa/WhatsApp Video Notes/VID-0002.mp4'),
          ChatMediaKind.video);
    });

    test('eski (kök) WhatsApp yolu da tanınır', () {
      expect(chatKindForPath('$waOld/WhatsApp Images/IMG-0001.jpg'),
          ChatMediaKind.image);
    });
  });

  group('Telegram', () {
    test('görüntü ve video ayrı ayrı tanınır', () {
      expect(chatKindForPath('$tg/Telegram Images/photo_1.jpg'),
          ChatMediaKind.image);
      expect(chatKindForPath('$tg/Telegram Video/video_1.mp4'),
          ChatMediaKind.video);
      expect(chatKindForPath('$tg/Telegram Documents/rapor.docx'),
          ChatMediaKind.document);
    });
  });

  group('tanınmayan yol', () {
    test('mesajlaşma klasörü değilse null döner', () {
      expect(chatKindForPath('/storage/emulated/0/DCIM/Camera/IMG_0001.jpg'),
          isNull);
    });

    test('girdiye düşülünce dosyanın KENDİ türü kullanılır', () {
      // WhatsApp bazı sürümlerde dosyayı beklenmedik klasöre yazıyor;
      // "görüntü" süzgeci o fotoğrafı yine de bulmalı.
      expect(chatKindForEntry(entry('/depo/tuhaf/klasor/foto.jpg')),
          ChatMediaKind.image);
      expect(chatKindForEntry(entry('/depo/tuhaf/klasor/film.mkv')),
          ChatMediaKind.video);
      expect(chatKindForEntry(entry('/depo/tuhaf/klasor/rapor.pdf')),
          ChatMediaKind.document);
      expect(chatKindForEntry(entry('/depo/tuhaf/klasor/arsiv.zip')),
          ChatMediaKind.other);
    });

    test('klasör bilgisi dosyanın türünü EZER', () {
      // .webp bir görüntüdür ama Stickers klasöründeyse çıkartmadır.
      expect(chatKindForEntry(entry('$wa/WhatsApp Stickers/STK-1.webp')),
          ChatMediaKind.sticker);
    });
  });

  group('gelen / gönderilen', () {
    test('Sent klasörü gönderilen sayılır', () {
      expect(isSentByMe('$wa/WhatsApp Images/Sent/IMG-0001.jpg'), isTrue);
    });

    test('adında “sent” geçen dosya gönderilen SAYILMAZ (klasör aranır)', () {
      expect(isSentByMe('$wa/WhatsApp Images/sent-by-ayse.jpg'), isFalse);
    });

    test('sıradan gelen dosya gönderilen değil', () {
      expect(isSentByMe('$wa/WhatsApp Images/IMG-0001.jpg'), isFalse);
    });
  });

  group('sayımlar', () {
    test('tür başına dosya sayısı çıkarılır (süzgeç rozetleri)', () {
      final counts = chatKindCounts([
        entry('$wa/WhatsApp Images/a.jpg'),
        entry('$wa/WhatsApp Images/b.jpg'),
        entry('$wa/WhatsApp Video/c.mp4'),
      ]);
      expect(counts[ChatMediaKind.image], 2);
      expect(counts[ChatMediaKind.video], 1);
    });
  });

  group('etiketler', () {
    test('her tür ve yönün kullanıcıya yazılan bir adı var', () {
      for (final k in ChatMediaKind.values) {
        expect(k.label, isNotEmpty);
      }
      for (final d in ChatDirection.values) {
        expect(d.label, isNotEmpty);
      }
    });
  });
}
