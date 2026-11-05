import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';
import 'package:dosya_okuyucu/services/scan_export.dart';
import 'package:dosya_okuyucu/services/scan_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Faz 35 / madde 1 — belge türü kipleri: kimlik ön+arka tek A4, kitap çift
/// sayfa bölme, kartvizit → vCard.
void main() {
  img.Image solid(int w, int h, int v) {
    final i = img.Image(width: w, height: h, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(v, v, v));
    return i;
  }

  group('kip varsayılanları', () {
    test('fiş/fotoğraf/kartvizit A4 değil, ötekiler A4', () {
      expect(ScanKind.receipt.uniformA4, isFalse);
      expect(ScanKind.photo.uniformA4, isFalse);
      expect(ScanKind.businessCard.uniformA4, isFalse);
      expect(ScanKind.document.uniformA4, isTrue);
      expect(ScanKind.idCard.uniformA4, isTrue);
    });

    test('fotoğraf filtresiz, beyaz tahta gölgesiz, kimlik 2 sayfa', () {
      expect(ScanKind.photo.defaultFilter, ScanFilter.original);
      expect(ScanKind.whiteboard.defaultFilter, ScanFilter.shadowless);
      expect(ScanKind.idCard.maxPages, 2);
      expect(ScanKind.businessCard.maxPages, 1);
    });

    test('her kipin çeviri anahtarı ayrı', () {
      final keys = ScanKind.values.map((k) => k.labelKey).toSet();
      expect(keys.length, ScanKind.values.length);
    });

    test('kurulan anahtarların hepsi tabloda (kip, filtre, kalite)', () {
      final keys = [
        for (final k in ScanKind.values) k.labelKey,
        for (final f in ScanFilter.values) ...[f.labelKey, f.shortLabelKey],
        for (final q in ScanQuality.values) q.labelKey,
      ];
      expect(keys.where((k) => !AppStrings.keys.contains(k)), isEmpty);
    });
  });

  group('kimlik birleştirme', () {
    test('ön + arka tek A4 tuvalde, beyaz zemin, kartlar ortada', () {
      final out = ScanKindOps.combineIdImages(
          [solid(400, 250, 20), solid(400, 250, 60)],
          canvasWidth: 620);
      expect(out.width, 620);
      expect(out.height, (620 * ScanKindOps.a4Ratio).round());
      // Köşe beyaz, orta sütunda kart (koyu) var.
      expect(out.getPixel(2, 2).r, 255);
      var dark = 0;
      for (var y = 0; y < out.height; y++) {
        if (out.getPixel(out.width ~/ 2, y).r < 100) dark++;
      }
      expect(dark, greaterThan(100), reason: 'iki kart çizildi');
    });

    test('dikey çekilmiş kart yatay yerleşir', () {
      final out = ScanKindOps.combineIdImages([solid(250, 400, 0)],
          canvasWidth: 620);
      // Kart genişliği tuvalin ~%42'si; dikey kalsaydı yükseklik > genişlik.
      var top = -1, bottom = -1;
      for (var y = 0; y < out.height; y++) {
        if (out.getPixel(out.width ~/ 2, y).r < 100) {
          if (top < 0) top = y;
          bottom = y;
        }
      }
      expect(bottom - top, lessThan((620 * 0.42).round()));
    });
  });

  group('kitap bölme', () {
    test('yatay çift sayfa cilt çizgisinden ikiye bölünür', () {
      final book = solid(400, 300, 240);
      // Cilt gölgesi x = 220 civarı.
      for (var y = 0; y < 300; y++) {
        for (var x = 218; x < 223; x++) {
          book.setPixelRgb(x, y, 40, 40, 40);
        }
      }
      final gutter = ScanKindOps.findGutter(book);
      expect((gutter - 220).abs(), lessThanOrEqualTo(3));
      final parts = ScanKindOps.splitBookImage(book);
      expect(parts, hasLength(2));
      expect(parts[0].width + parts[1].width, 400);
      expect(parts[0].height, 300);
    });

    test('dikey (tek) sayfa bölünmez', () {
      expect(ScanKindOps.splitBookImage(solid(300, 400, 200)), hasLength(1));
    });
  });

  group('kartvizit', () {
    const text = 'Ayşe Yılmaz\n'
        'Kıdemli Mühendis\n'
        'Örnek Yazılım A.Ş.\n'
        'Tel: +90 532 123 45 67\n'
        'ayse.yilmaz@ornek.com.tr\n'
        'www.ornek.com.tr';

    test('ad, şirket, telefon, e-posta, web ayrışır', () {
      final card = BusinessCard.parse(text);
      expect(card.name, 'Ayşe Yılmaz');
      expect(card.company, 'Örnek Yazılım A.Ş.');
      expect(card.phones, ['+905321234567']);
      expect(card.emails, ['ayse.yilmaz@ornek.com.tr']);
      expect(card.web, 'www.ornek.com.tr');
      expect(card.isEmpty, isFalse);
    });

    test('vCard 3.0 biçimi', () {
      final vcf = BusinessCard.parse(text).toVcf();
      expect(vcf, startsWith('BEGIN:VCARD\r\nVERSION:3.0\r\n'));
      expect(vcf, contains('FN:Ayşe Yılmaz\r\n'));
      expect(vcf, contains('TEL;TYPE=CELL:+905321234567\r\n'));
      expect(vcf, contains('EMAIL:ayse.yilmaz@ornek.com.tr\r\n'));
      expect(vcf, endsWith('END:VCARD\r\n'));
    });

    test('kişi bilgisi yoksa boş', () {
      expect(BusinessCard.parse('lorem\n12').isEmpty, isTrue);
    });
  });
}
