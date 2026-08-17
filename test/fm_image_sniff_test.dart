import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/image_sniff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

Uint8List _bytes(List<int> head, {int pad = 32}) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

void main() {
  group('imza baytlarından görsel tanıma', () {
    test('bilinen görsel imzaları tanınır', () {
      expect(ImageSniff.looksLikeImage(_bytes([0x89, 0x50, 0x4E, 0x47])), isTrue,
          reason: 'PNG');
      expect(ImageSniff.looksLikeImage(_bytes([0xFF, 0xD8, 0xFF])), isTrue,
          reason: 'JPEG');
      expect(ImageSniff.looksLikeImage(_bytes([0x47, 0x49, 0x46, 0x38])), isTrue,
          reason: 'GIF');
      expect(ImageSniff.looksLikeImage(_bytes([0x42, 0x4D])), isTrue,
          reason: 'BMP');
      // WEBP: RIFF....WEBP
      expect(
        ImageSniff.looksLikeImage(Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, //
          0x57, 0x45, 0x42, 0x50,
        ])),
        isTrue,
        reason: 'WEBP',
      );
      // HEIC: ....ftypheic
      expect(
        ImageSniff.looksLikeImage(Uint8List.fromList([
          0, 0, 0, 0, 0x66, 0x74, 0x79, 0x70, //
          0x68, 0x65, 0x69, 0x63,
        ])),
        isTrue,
        reason: 'HEIC',
      );
    });

    /// **mp4 de `ftyp` ile başlar.** Yalnız `ftyp`e bakılsaydı her video
    /// `Image.file`a verilip hata üretirdi.
    test('ftyp tek başına yetmez — mp4 görsel sayılmaz', () {
      final mp4 = Uint8List.fromList([
        0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, //
        0x69, 0x73, 0x6F, 0x6D, // "isom"
      ]);
      expect(ImageSniff.looksLikeImage(mp4), isFalse);
    });

    test('rastgele/kısa baytlar görsel sayılmaz', () {
      expect(ImageSniff.looksLikeImage(_bytes([0x50, 0x4B, 0x03, 0x04])), isFalse,
          reason: 'zip');
      expect(ImageSniff.looksLikeImage(_bytes([0x25, 0x50, 0x44, 0x46])), isFalse,
          reason: 'pdf — görsel değil');
      expect(ImageSniff.looksLikeImage(Uint8List.fromList([1, 2])), isFalse,
          reason: 'çok kısa');
    });
  });

  group('diskten okuma ve önbellek', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('sniff');
      ImageSniff.debugReset();
    });

    tearDown(() => removeTempDir(dir));

    /// Kullanıcı 2026-08-17: WhatsApp önbelleğinden gelen UZANTISIZ kopyalar
    /// "Birebir kopyalar" ekranında düz glifle görünüyordu.
    test('uzantısız JPEG dosyası görsel olarak tanınır', () async {
      final path = p.join(dir.path, '0dc1773b99bd9094f44c5c713c66b30f');
      File(path).writeAsBytesSync(_bytes([0xFF, 0xD8, 0xFF]));

      expect(ImageSniff.cached(path), isNull, reason: 'henüz bakılmadı');
      expect(await ImageSniff.check(path), isTrue);
      // İkinci kez diske gidilmez: sonuç akılda.
      expect(ImageSniff.cached(path), isTrue);
    });

    test('görsel olmayan uzantısız dosya için false önbelleklenir', () async {
      final path = p.join(dir.path, 'rastgele');
      File(path).writeAsBytesSync(_bytes([0x00, 0x01, 0x02, 0x03]));
      expect(await ImageSniff.check(path), isFalse);
      expect(ImageSniff.cached(path), isFalse);
    });

    test('olmayan dosya çökmez', () async {
      expect(await ImageSniff.check(p.join(dir.path, 'yok')), isFalse);
    });

    test('boş dosya çökmez', () async {
      final path = p.join(dir.path, 'bos');
      File(path).writeAsBytesSync(const []);
      expect(await ImageSniff.check(path), isFalse);
    });
  });
}
