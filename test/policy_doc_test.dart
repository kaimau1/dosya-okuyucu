import 'dart:io';

import 'package:dosya_okuyucu/core/policy_doc.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Gizlilik politikası — 2026-08-28.**
///
/// Metin üç dilde `assets/privacy/` altında duruyor ve hem uygulamada hem
/// depoda AYNI dosya. Bu testler iki şeyi kilitler: (1) ayrıştırıcı belgenin
/// kullandığı işaretlemeyi gerçekten çiziyor, (2) **üç dosya da var ve
/// taşıyıcı bölümleri içeriyor** — bir dil unutulursa o dildeki kullanıcı
/// politikayı hiç göremezdi.
void main() {
  group('ayrıştırıcı', () {
    test('başlık düzeyleri ve paragraf', () {
      final blocks = PolicyDoc.parse('# Başlık\n\nBir **paragraf** metni.\n');
      expect(blocks.first.kind, PolicyBlockKind.heading);
      expect(blocks.first.level, 1);
      expect(blocks[1].kind, PolicyBlockKind.paragraph);
      expect(blocks[1].text, 'Bir paragraf metni.',
          reason: 'yıldızlar düz metne indirgenmeli');
    });

    test('maddeler', () {
      final blocks = PolicyDoc.parse('- bir\n- iki\n');
      expect(blocks.map((b) => b.kind),
          everyElement(PolicyBlockKind.bullet));
      expect(blocks.last.text, 'iki');
    });

    test('tablo: BAŞLIK satırı düşer, veri satırları hücrelere ayrılır', () {
      final blocks = PolicyDoc.parse(
          '| İşlem | Nereye |\n|---|---|\n| Gemini | Google |\n');
      expect(blocks, hasLength(1), reason: 'başlık satırı çizilmemeli');
      expect(blocks.first.kind, PolicyBlockKind.tableRow);
      expect(blocks.first.cells, ['Gemini', 'Google']);
    });

    test('bağlantılar okunur metne çevrilir', () {
      expect(PolicyDoc.inline('[Türkçe](../a.md)'), 'Türkçe (../a.md)');
      expect(PolicyDoc.inline('<https://x.dev/y>'), 'https://x.dev/y');
    });

    test('bilinmeyen işaretleme METNİ KAYBETMEZ', () {
      final blocks = PolicyDoc.parse('> alıntı satırı\n');
      expect(blocks.single.text, 'alıntı satırı');
    });
  });

  group('politika dosyaları', () {
    for (final code in ['tr', 'en', 'ar']) {
      test('$code.md var, ayrıştırılıyor ve taşıyıcı bölümleri içeriyor', () {
        final file = File('assets/privacy/$code.md');
        expect(file.existsSync(), isTrue,
            reason: 'assets/privacy/$code.md bulunmalı (pubspec varlığı)');
        final blocks = PolicyDoc.parse(file.readAsStringSync());
        expect(blocks.length, greaterThan(30));
        // **Yapı** kilitleniyor, metin değil: politikanın yedi numaralı
        // bölümü var (özet + 7 başlık = en az 8 ikinci düzey başlık).
        // Rakamlara BAKILMIYOR — Arapça metin Hint-Arap rakamları (١، ٧)
        // kullanıyor; '1.' araması orada boş dönerdi.
        final sections = blocks
            .where((b) => b.kind == PolicyBlockKind.heading && b.level == 2)
            .toList();
        expect(sections.length, greaterThanOrEqualTo(8),
            reason: 'yedi bölümün hepsi $code için çevrilmiş olmalı');
        // Gemini uç noktası politikada AÇIKÇA yazılı olmalı: uygulamanın
        // ağa çıktığı ana yer orası.
        expect(file.readAsStringSync(), contains('generativelanguage'));
      });
    }

    test('pubspec varlık olarak kaydetmiş', () {
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/privacy/'));
    });
  });
}
