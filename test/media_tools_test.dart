import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/exif_reader.dart';
import 'package:dosya_okuyucu/services/fm/image_rotate.dart';
import 'package:dosya_okuyucu/services/fm/playlist_m3u.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-06 denetim turu: fotoğrafın künyesi (EXIF), çalma listesi (M3U)
/// ve döndürme.
///
/// EXIF testi **elle kurulmuş** bir JPEG başlığı kullanıyor: gerçek bir
/// fotoğrafı depoya koymak hem yüzlerce KB hem de içindeki cihaz/konum
/// bilgisiyle gereksiz bir kişisel veri olurdu.
void main() {
  group('EXIF', () {
    test('küçük-endian JPEG başlığından marka, model ve tarih okunur', () {
      final bytes = _jpegWithExif(little: true, tags: [
        _Tag.ascii(0x010F, 'Samsung'),
        _Tag.ascii(0x0110, 'SM-G991B'),
        _Tag.ascii(0x9003, '2026:09:06 14:32:10'),
        _Tag.short(0x0112, 6),
        _Tag.short(0x8827, 200),
      ]);
      final exif = ExifReader.parse(bytes);
      expect(exif.make, 'Samsung');
      expect(exif.model, 'SM-G991B');
      expect(exif.taken, DateTime(2026, 9, 6, 14, 32, 10));
      expect(exif.orientation, 6);
      expect(exif.iso, 200);
      expect(exif.camera, 'Samsung SM-G991B');
    });

    test('büyük-endian (Motorola) düzen de okunur', () {
      final bytes = _jpegWithExif(little: false, tags: [
        _Tag.ascii(0x0110, 'Canon EOS'),
      ]);
      expect(ExifReader.parse(bytes).model, 'Canon EOS');
    });

    test('marka modelin başında geçiyorsa iki kez YAZILMAZ', () {
      final bytes = _jpegWithExif(little: true, tags: [
        _Tag.ascii(0x010F, 'Apple'),
        _Tag.ascii(0x0110, 'Apple iPhone 13'),
      ]);
      expect(ExifReader.parse(bytes).camera, 'Apple iPhone 13');
    });

    test('EXIF yoksa boş döner (çökmez)', () {
      final plain = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      expect(ExifReader.parse(plain).isEmpty, isTrue);
      expect(ExifReader.parse(Uint8List(0)).isEmpty, isTrue);
      expect(ExifReader.parse(Uint8List.fromList([1, 2, 3])).isEmpty, isTrue);
    });

    test('kesilmiş/bozuk EXIF ÇÖKMEZ', () {
      final bytes = _jpegWithExif(little: true, tags: [
        _Tag.ascii(0x0110, 'Nokia'),
      ]);
      for (var cut = 12; cut < bytes.length; cut += 3) {
        expect(() => ExifReader.parse(bytes.sublist(0, cut)), returnsNormally,
            reason: '$cut baytta kesilmiş dosya');
      }
    });

    test('saati ayarsız cihazın 1970 tarihi gösterilmez', () {
      final bytes = _jpegWithExif(little: true, tags: [
        _Tag.ascii(0x9003, '1970:01:01 00:00:00'),
      ]);
      expect(ExifReader.parse(bytes).taken, isNull);
    });

    test('poz süresi okunur biçime çevrilir', () {
      const fast = ExifData(exposureSeconds: 0.004);
      expect(fast.exposureLabel, '1/250 sn');
      const slow = ExifData(exposureSeconds: 2.5);
      expect(slow.exposureLabel, '2,5 sn');
      expect(const ExifData().exposureLabel, isNull);
    });
  });

  group('Döndürme', () {
    test('yalnız yazabildiğimiz biçimler döndürülebilir', () {
      expect(ImageRotate.canRotate('/a/foto.JPG'), isTrue);
      expect(ImageRotate.canRotate('/a/foto.png'), isTrue);
      // Çözebildiğimiz ama YAZAMADIĞIMIZ biçim: sessizce JPEG'e çevirmek
      // yerine hiç sunulmuyor.
      expect(ImageRotate.canRotate('/a/foto.heic'), isFalse);
      expect(ImageRotate.canRotate('/a/belge.pdf'), isFalse);
    });

    test('EXIF yönelimi çeyrek dönüşe çevrilir', () {
      expect(ImageRotate.turnsForOrientation(1), 0);
      expect(ImageRotate.turnsForOrientation(6), 1);
      expect(ImageRotate.turnsForOrientation(3), 2);
      expect(ImageRotate.turnsForOrientation(8), 3);
      expect(ImageRotate.turnsForOrientation(null), 0);
    });
  });

  group('M3U çalma listesi', () {
    test('göreli yollar liste klasörüne göre çözülür', () {
      const content = '#EXTM3U\n'
          '#EXTINF:215,Sezen Aksu - Şarkı\n'
          'Muzik/parca.mp3\n'
          '#EXTINF:-1,Diğer\n'
          '/storage/emulated/0/Music/b.mp3\n';
      final list = PlaylistM3u.parse(content, baseDir: '/depo/Listeler');
      expect(list, hasLength(2));
      expect(list[0].path, '/depo/Listeler/Muzik/parca.mp3');
      expect(list[0].title, 'Sezen Aksu - Şarkı');
      expect(list[0].seconds, 215);
      expect(list[1].path, '/storage/emulated/0/Music/b.mp3');
      expect(list[1].seconds, -1);
    });

    test('başlıksız satırda dosya adı kullanılır', () {
      final list = PlaylistM3u.parse('a/b/Şarkım.mp3', baseDir: '/kök');
      expect(list.single.title, 'Şarkım');
    });

    test('file:// ön eki temizlenir (masaüstü oynatıcıları)', () {
      final list =
          PlaylistM3u.parse('file:///music/a.mp3', baseDir: '/kök');
      expect(list.single.path, '/music/a.mp3');
    });

    test('yazarken yollar GÖRELİ olur (liste taşınabilir kalsın)', () {
      const entries = [
        PlaylistEntry(path: '/depo/Muzik/a.mp3', title: 'A', seconds: 100),
        PlaylistEntry(path: '/depo/Listeler/b.mp3', title: 'B'),
      ];
      final text = PlaylistM3u.build(entries, baseDir: '/depo/Listeler');
      expect(text, contains('../Muzik/a.mp3'));
      expect(text, contains('#EXTINF:100,A'));
      expect(text, contains('\nb.mp3'));
    });

    test('başka birimdeki dosya MUTLAK kalır', () {
      const entries = [
        PlaylistEntry(path: '/storage/A1B2-C3D4/Muzik/a.mp3', title: 'A'),
      ];
      final text = PlaylistM3u.build(entries, baseDir: '/storage/emulated/0/L');
      expect(text, contains('/storage/A1B2-C3D4/Muzik/a.mp3'));
    });

    test('gidiş-dönüş: yazılan liste aynen okunur', () {
      const entries = [
        PlaylistEntry(path: '/depo/L/x.mp3', title: 'X', seconds: 12),
      ];
      final text = PlaylistM3u.build(entries, baseDir: '/depo/L');
      final back = PlaylistM3u.parse(text, baseDir: '/depo/L');
      expect(back.single.path, '/depo/L/x.mp3');
      expect(back.single.title, 'X');
      expect(back.single.seconds, 12);
    });

    test('boş satırlar ve yorumlar atlanır', () {
      final list = PlaylistM3u.parse(
          '#EXTM3U\n\n# yorum\n\na.mp3\n\n', baseDir: '/k');
      expect(list, hasLength(1));
    });
  });
}

// ── Test için EXIF taşıyan en küçük JPEG ────────────────────────────────────

class _Tag {
  final int id;
  final int type;
  final List<int> payload;
  final int count;
  _Tag(this.id, this.type, this.payload, this.count);

  factory _Tag.ascii(int id, String value) {
    final bytes = [...value.codeUnits, 0];
    return _Tag(id, 2, bytes, bytes.length);
  }

  factory _Tag.short(int id, int value) => _Tag(id, 3, [value], 1);
}

Uint8List _jpegWithExif({required bool little, required List<_Tag> tags}) {
  final body = BytesBuilder();
  // TIFF başlığı
  body.add(little ? [0x49, 0x49, 0x2A, 0x00] : [0x4D, 0x4D, 0x00, 0x2A]);
  body.add(_u32(8, little)); // IFD0 ofseti

  final entries = BytesBuilder();
  final extra = BytesBuilder();
  // Değer alanı IFD'nin hemen ardında başlıyor.
  var extraAt = 8 + 2 + tags.length * 12 + 4;

  entries.add(_u16(tags.length, little));
  for (final tag in tags) {
    entries.add(_u16(tag.id, little));
    entries.add(_u16(tag.type, little));
    entries.add(_u32(tag.count, little));
    if (tag.type == 3) {
      // SHORT: değer 4 baytlık alana sığar (kalan iki bayt dolgu).
      entries.add(_u16(tag.payload.first, little));
      entries.add([0, 0]);
    } else if (tag.payload.length <= 4) {
      final padded = [...tag.payload, 0, 0, 0, 0].take(4).toList();
      entries.add(padded);
    } else {
      entries.add(_u32(extraAt, little));
      extra.add(tag.payload);
      extraAt += tag.payload.length;
    }
  }
  entries.add(_u32(0, little)); // sonraki IFD yok

  body.add(entries.toBytes());
  body.add(extra.toBytes());

  final exif = <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...body.toBytes()];
  final size = exif.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, (size >> 8) & 0xFF, size & 0xFF,
    ...exif,
    0xFF, 0xD9, // EOI
  ]);
}

List<int> _u16(int v, bool little) =>
    little ? [v & 0xFF, (v >> 8) & 0xFF] : [(v >> 8) & 0xFF, v & 0xFF];

List<int> _u32(int v, bool little) => little
    ? [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]
    : [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
