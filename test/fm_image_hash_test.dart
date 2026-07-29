import 'package:dosya_okuyucu/services/fm/image_hash.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** benzer görüntü bulma tamamen bu saf matematiğe
/// dayanıyor. Eşik bir bit kayarsa ya "hiç benzer bulunamadı" olur ya da
/// alakasız fotoğraflar aynı gruba düşer ve kullanıcı yanlışlıkla anılarını
/// siler. Gruplamanın geçişliliği ve büyük listelerdeki aday üretimi
/// (blok indeksi) burada kilitleniyor.
void main() {
  /// Soldan sağa artan gri değerler → her karşılaştırmada sol < sağ.
  List<int> ramp() => [
        for (var y = 0; y < hashGridHeight; y++)
          for (var x = 0; x < hashGridWidth; x++) x * 20,
      ];

  group('dHash', () {
    test('artan ızgarada tüm bitler 0 (sol asla sağdan büyük değil)', () {
      expect(dHashFromGray(ramp()), 0);
    });

    test('azalan ızgarada tüm 64 bit 1', () {
      final gray = [
        for (var y = 0; y < hashGridHeight; y++)
          for (var x = 0; x < hashGridWidth; x++) (hashGridWidth - x) * 20,
      ];
      // 64 bitin hepsi 1 → -1 değil, çünkü 64. bit işaret bitine denk gelir.
      expect(hamming(dHashFromGray(gray), 0), 64);
    });

    test('eksik ızgara hata verir (sessizce yanlış hash üretmez)', () {
      expect(() => dHashFromGray(List.filled(10, 0)), throwsArgumentError);
    });

    test('tek pikselin değişmesi tek bit değiştirir', () {
      final base = ramp();
      final tweaked = [...base];
      // İlk satırın ilk pikselini komşusundan büyük yap → yalnız o bit döner.
      tweaked[0] = 999;
      expect(hamming(dHashFromGray(base), dHashFromGray(tweaked)), 1);
    });

    test('parlaklık toptan artarsa hash DEĞİŞMEZ (sıkıştırma dayanıklılığı)',
        () {
      final base = ramp();
      final brighter = [for (final v in base) (v + 30).clamp(0, 255)];
      expect(dHashFromGray(brighter), dHashFromGray(base));
    });
  });

  group('grayFromRgba', () {
    test('RGBA baytlarını insan gözü ağırlıklarıyla griye çevirir', () {
      // Saf kırmızı → 0.299*255 ≈ 76
      final gray = grayFromRgba([255, 0, 0, 255, 0, 255, 0, 255], 2);
      expect(gray[0], 76);
      expect(gray[1], 149); // 0.587*255 ≈ 149
    });
  });

  group('groupSimilar', () {
    test('eşiği aşmayanlar gruplanır, aşanlar ayrı kalır', () {
      // 0 ile 1 arasında 1 bit fark; 0 ile 0xFF arasında 8 bit.
      final groups = groupSimilar([0, 1, 0xFF], maxDistance: 2);
      expect(groups.length, 1);
      expect(groups.first..sort(), [0, 1]);
    });

    test('tek kalan girdiler grup olmaz', () {
      expect(groupSimilar([0, 0xFFFF], maxDistance: 2), isEmpty);
    });

    test('birleştirme GEÇİŞLİdir: A~B, B~C ise üçü tek grup', () {
      // 0b000, 0b001, 0b011 → 0 ile 3 arası 2 bit; eşik 1 olsa bile zincir
      // üzerinden tek gruba düşerler.
      final groups = groupSimilar([0, 1, 3], maxDistance: 1);
      expect(groups.length, 1);
      expect(groups.first.length, 3);
    });

    test('gruplar büyükten küçüğe sıralanır', () {
      final groups = groupSimilar([0, 1, 2, 0xFF00, 0xFF01], maxDistance: 2);
      expect(groups.first.length, 3);
      expect(groups.last.length, 2);
    });

    test('blok indeksi yolu (büyük liste) aynı sonucu verir', () {
      // exactLimit'i düşürerek MIH yolunu zorla; sonuç kesin yolla aynı olmalı.
      final hashes = [
        0,
        1,
        0xFF00,
        0xFF01,
        0x0F0F0F0F,
        for (var i = 0; i < 20; i++) 1 << (i + 20),
      ];
      final exact = groupSimilar(hashes, maxDistance: 2, exactLimit: 1000);
      final mih = groupSimilar(hashes, maxDistance: 2, exactLimit: 2);
      String key(List<List<int>> g) =>
          (g.map((x) => (x..sort()).join(',')).toList()..sort()).join('|');
      expect(key(mih), key(exact));
    });

    test('tek girdi ya da boş liste güvenli', () {
      expect(groupSimilar(const []), isEmpty);
      expect(groupSimilar(const [5]), isEmpty);
    });
  });

  group('duyarlılık kademeleri', () {
    test('eşikler sıkıdan gevşeğe artar', () {
      expect(SimilarityLevel.strict.maxDistance,
          lessThan(SimilarityLevel.normal.maxDistance));
      expect(SimilarityLevel.normal.maxDistance,
          lessThan(SimilarityLevel.loose.maxDistance));
    });

    test('her kademenin kullanıcıya yazılan bir açıklaması var', () {
      for (final level in SimilarityLevel.values) {
        expect(level.label, isNotEmpty);
        expect(level.description, isNotEmpty);
      }
    });
  });
}
