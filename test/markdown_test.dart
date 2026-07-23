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
}
