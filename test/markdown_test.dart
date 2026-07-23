import 'package:dosya_okuyucu/core/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bir bloğun düz metnini toplar (span birleştirme).
String _text(MdBlock b) => b.spans.map((s) => s.text).join();

void main() {
  group('parseMarkdown — bloklar', () {
    test('düz paragraf', () {
      final blocks = parseMarkdown('Merhaba dünya');
      expect(blocks, hasLength(1));
      expect(blocks.first.type, MdBlockType.paragraph);
      expect(_text(blocks.first), 'Merhaba dünya');
    });

    test('başlık düzeyi çözülür ve # kaldırılır', () {
      final blocks = parseMarkdown('## Başlık burada');
      expect(blocks.first.type, MdBlockType.heading);
      expect(blocks.first.level, 2);
      expect(_text(blocks.first), 'Başlık burada');
    });

    test('madde işaretli liste ardışık toplanır', () {
      final blocks = parseMarkdown('- bir\n- iki\n- üç');
      expect(blocks, hasLength(1));
      expect(blocks.first.type, MdBlockType.bullet);
      expect(blocks.first.items, hasLength(3));
      expect(blocks.first.items[1].map((s) => s.text).join(), 'iki');
    });

    test('numaralı liste başlangıç numarasını korur', () {
      final blocks = parseMarkdown('3. üç\n4. dört');
      expect(blocks.first.type, MdBlockType.numbered);
      expect(blocks.first.start, 3);
      expect(blocks.first.items, hasLength(2));
    });

    test('alıntı > işareti kaldırılır', () {
      final blocks = parseMarkdown('> bir alıntı\n> devamı');
      expect(blocks.first.type, MdBlockType.quote);
      expect(_text(blocks.first), 'bir alıntı devamı');
    });

    test('yatay çizgi', () {
      final blocks = parseMarkdown('---');
      expect(blocks.first.type, MdBlockType.rule);
    });

    test('kod bloğu ham korunur', () {
      final blocks = parseMarkdown('```\nvar x = 1;\nprint(x);\n```');
      expect(blocks.first.type, MdBlockType.code);
      expect(blocks.first.rawCode, 'var x = 1;\nprint(x);');
    });

    test('tablo başlık + satır çözülür', () {
      final md = '| Ad | Yaş |\n| --- | --- |\n| Ali | 30 |\n| Ay | 25 |';
      final blocks = parseMarkdown(md);
      expect(blocks.first.type, MdBlockType.table);
      expect(blocks.first.rows, hasLength(3)); // başlık + 2 satır
      expect(blocks.first.rows[0][0].map((s) => s.text).join(), 'Ad');
      expect(blocks.first.rows[2][1].map((s) => s.text).join(), '25');
    });

    test('boş satır blokları ayırır', () {
      final blocks = parseMarkdown('İlk paragraf\n\nİkinci paragraf');
      expect(blocks, hasLength(2));
      expect(_text(blocks[0]), 'İlk paragraf');
      expect(_text(blocks[1]), 'İkinci paragraf');
    });
  });

  group('parseMarkdown — satır içi biçim', () {
    List<MdSpan> spansOf(String md) => parseMarkdown(md).first.spans;

    test('kalın ** işaretsiz biçimlenir', () {
      final spans = spansOf('bu **kalın** metin');
      final bold = spans.firstWhere((s) => s.bold);
      expect(bold.text, 'kalın');
      // Ham yıldız hiçbir span metninde kalmaz.
      expect(spans.every((s) => !s.text.contains('*')), isTrue);
    });

    test('italik * biçimlenir', () {
      final spans = spansOf('bu *italik* metin');
      expect(spans.any((s) => s.italic && s.text == 'italik'), isTrue);
    });

    test('kalın+italik ***', () {
      final spans = spansOf('***çok önemli***');
      expect(spans.any((s) => s.bold && s.italic), isTrue);
      expect(spans.every((s) => !s.text.contains('*')), isTrue);
    });

    test('satır içi kod ` biçimlenir', () {
      final spans = spansOf('şu `kod` böyle');
      expect(spans.any((s) => s.code && s.text == 'kod'), isTrue);
    });

    test('üstü çizili ~~', () {
      final spans = spansOf('~~silindi~~');
      expect(spans.any((s) => s.strike && s.text == 'silindi'), isTrue);
    });

    test('bağlantı [metin](url) yalnız metni gösterir', () {
      final spans = spansOf('bkz [Google](https://google.com) sitesi');
      final joined = spans.map((s) => s.text).join();
      expect(joined, contains('Google'));
      expect(joined, isNot(contains('http')));
      expect(joined, isNot(contains('](')));
    });

    test('snake_case alt çizgisi italik yapmaz', () {
      final spans = spansOf('değişken my_var_name burada');
      expect(spans.every((s) => !s.italic), isTrue);
      expect(spans.map((s) => s.text).join(), contains('my_var_name'));
    });

    test('ters bölü kaçışı işareti düz metin yapar', () {
      final spans = spansOf(r'fiyat 5 \* 3 = 15');
      expect(spans.every((s) => !s.italic && !s.bold), isTrue);
      // `\*` düz `*` olur, italik başlamaz; önekle birlikte tam metin.
      expect(spans.map((s) => s.text).join(), 'fiyat 5 * 3 = 15');
    });

    test('görsel ![alt](url) yalnız alt metni gösterir', () {
      final spans = spansOf('bak ![kedi resmi](kedi.png) burada');
      final joined = spans.map((s) => s.text).join();
      expect(joined, contains('kedi resmi'));
      expect(joined, isNot(contains('kedi.png')));
      expect(joined, isNot(contains('![')));
    });

    test('otomatik bağlantı <url> içeriği gösterir', () {
      final spans = spansOf('site <https://ornek.com> adresinde');
      final joined = spans.map((s) => s.text).join();
      expect(joined, contains('https://ornek.com'));
      expect(joined, isNot(contains('<')));
    });

    test('küçüktür işareti (url değil) düz kalır', () {
      final spans = spansOf('a < b ve c > d');
      expect(spans.map((s) => s.text).join(), 'a < b ve c > d');
    });
  });

  group('parseMarkdown — GFM eklemeler', () {
    test('başlıkta kapanış diyezleri atılır', () {
      final b = parseMarkdown('## Başlık ##').first;
      expect(b.type, MdBlockType.heading);
      expect(_text(b), 'Başlık');
    });

    test('görev listesi onay kutusuna çevrilir', () {
      final b = parseMarkdown('- [ ] yapılacak\n- [x] bitti').first;
      expect(b.type, MdBlockType.bullet);
      expect(b.items[0].map((s) => s.text).join(), startsWith('☐'));
      expect(b.items[0].map((s) => s.text).join(), contains('yapılacak'));
      expect(b.items[1].map((s) => s.text).join(), startsWith('☑'));
      expect(b.items[1].map((s) => s.text).join(), contains('bitti'));
    });
  });

  group('vurgu flanking (CommonMark)', () {
    List<MdSpan> spansOf(String md) => parseMarkdown(md).first.spans;

    test('boşlukla çevrili * çarpım işareti italik yapmaz', () {
      final spans = spansOf('2 * 3 = 6 ve 4 * 5 = 20');
      expect(spans.every((s) => !s.italic && !s.bold), isTrue);
      expect(spans.map((s) => s.text).join(), '2 * 3 = 6 ve 4 * 5 = 20');
    });

    test('gerçek **kalın** yine biçimlenir', () {
      final spans = spansOf('bu **kalın** yazı');
      expect(spans.any((s) => s.bold && s.text == 'kalın'), isTrue);
    });

    test('gerçek *italik* yine biçimlenir', () {
      final spans = spansOf('bu *italik* yazı');
      expect(spans.any((s) => s.italic && s.text == 'italik'), isTrue);
    });
  });

  group('kod bloğu + tablo hizalama + sert satır sonu', () {
    test('kod bloğu dil etiketini yakalar', () {
      final b = parseMarkdown('```dart\nvoid main() {}\n```').first;
      expect(b.type, MdBlockType.code);
      expect(b.codeLang, 'dart');
      expect(b.rawCode, 'void main() {}');
    });

    test('tablo sütun hizaları çözülür (:--, :-:, --:)', () {
      const md = '| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |';
      final b = parseMarkdown(md).first;
      expect(b.type, MdBlockType.table);
      expect(b.aligns, [0, 1, 2]); // sol, orta, sağ
    });

    test('iki boşlukla biten satır sert satır sonu (\\n) üretir', () {
      final b = parseMarkdown('birinci satır  \nikinci satır').first;
      expect(b.type, MdBlockType.paragraph);
      expect(b.spans.map((s) => s.text).join(), contains('\n'));
    });

    test('normal sarma boşlukla birleşir (satır sonu yok)', () {
      final b = parseMarkdown('birinci satır\nikinci satır').first;
      expect(b.spans.map((s) => s.text).join(), 'birinci satır ikinci satır');
    });
  });

  group('stripMarkdown — düz metin', () {
    test('kalın işareti kaldırılır', () {
      expect(stripMarkdown('bu **kalın** yazı'), 'bu kalın yazı');
    });

    test('başlık # kaldırılır', () {
      expect(stripMarkdown('# Başlık'), 'Başlık');
    });

    test('madde • işaretine döner', () {
      final out = stripMarkdown('- bir\n- iki');
      expect(out, contains('• bir'));
      expect(out, contains('• iki'));
    });

    test('numaralı liste numarası korunur', () {
      final out = stripMarkdown('1. ilk\n2. son');
      expect(out, contains('1. ilk'));
      expect(out, contains('2. son'));
    });

    test('karışık içerikte hiç yıldız/diyez kalmaz', () {
      const md = '# Rapor\n\n**Özet:** çok *iyi* bir `sonuç`.\n\n- madde 1\n- madde 2';
      final out = stripMarkdown(md);
      expect(out.contains('**'), isFalse);
      expect(out.contains('#'), isFalse);
      expect(out, contains('Özet:'));
      expect(out, contains('iyi'));
    });
  });

  group('stripInlineMarkdown — tek satır', () {
    test('baştaki madde işareti + kalın kaldırılır', () {
      expect(stripInlineMarkdown('- **Önemli** nokta'), 'Önemli nokta');
    });

    test('başlık # kaldırılır', () {
      expect(stripInlineMarkdown('## Bölüm başlığı'), 'Bölüm başlığı');
    });

    test('numaralı madde işareti kaldırılır', () {
      expect(stripInlineMarkdown('3. üçüncü madde'), 'üçüncü madde');
    });

    test('düz satır değişmeden döner', () {
      expect(stripInlineMarkdown('sıradan bir cümle'), 'sıradan bir cümle');
    });
  });
}
