import 'package:dosya_okuyucu/services/csv_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvCodec.parse', () {
    test('basit satır/sütun', () {
      final rows = CsvCodec.parse('a,b,c\n1,2,3');
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('tırnaklı alanda ayraç literal kalır', () {
      final rows = CsvCodec.parse('ad,not\n"Ali, Veli",merhaba');
      expect(rows[1][0], 'Ali, Veli');
      expect(rows[1][1], 'merhaba');
    });

    test('kaçırılmış tırnak ("" → ")', () {
      final rows = CsvCodec.parse('"o ""dedi""",x');
      expect(rows[0][0], 'o "dedi"');
      expect(rows[0][1], 'x');
    });

    test('alan içi yeni satır', () {
      final rows = CsvCodec.parse('"satır1\nsatır2",b');
      expect(rows[0][0], 'satır1\nsatır2');
      expect(rows[0][1], 'b');
    });

    test('\\r\\n satır sonu', () {
      final rows = CsvCodec.parse('a,b\r\nc,d');
      expect(rows, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('noktalı virgül ayracı otomatik saptanır', () {
      final rows = CsvCodec.parse('a;b;c\n1;2;3');
      expect(rows[0], ['a', 'b', 'c']);
      expect(rows[1], ['1', '2', '3']);
    });

    test('sekme (TSV) otomatik saptanır', () {
      final rows = CsvCodec.parse('a\tb\n1\t2');
      expect(rows[0], ['a', 'b']);
      expect(rows[1], ['1', '2']);
    });

    test('boru | ayracı otomatik saptanır', () {
      final rows = CsvCodec.parse('a|b|c\n1|2|3');
      expect(rows[0], ['a', 'b', 'c']);
      expect(rows[1], ['1', '2', '3']);
    });

    test('çok satırlı tutarlılık tek satır belirsizliğini çözer', () {
      // Başlıkta hem `,` hem `;` var; ikinci satır gerçek ayracı (`;`) ele verir.
      final rows = CsvCodec.parse('a;b,c\n1;2');
      expect(rows[0], ['a', 'b,c']);
      expect(rows[1], ['1', '2']);
    });

    test('sondaki boş satır atılır', () {
      final rows = CsvCodec.parse('a,b\n1,2\n');
      expect(rows.length, 2);
    });

    test('boş alanlar korunur', () {
      final rows = CsvCodec.parse('a,,c');
      expect(rows[0], ['a', '', 'c']);
    });
  });

  group('CsvCodec.encode', () {
    test('ayraç/tırnak/yeni satır içeren alan tırnaklanır', () {
      final out = CsvCodec.encode([
        ['a,b', 'x"y', 'çok\nsatır'],
      ]);
      expect(out, '"a,b","x""y","çok\nsatır"');
    });

    test('sade alanlar tırnaksız', () {
      expect(CsvCodec.encode([
        ['a', 'b'],
        ['1', '2'],
      ]), 'a,b\r\n1,2');
    });

    test('noktalı virgül ayracıyla üretim', () {
      expect(CsvCodec.encode([
        ['a', 'b']
      ], delimiter: ';'), 'a;b');
    });

    test('sanitizeFormulas: formül hücresi başına tırnak konur', () {
      final out = CsvCodec.encode([
        ['=1+1', '@cmd', '-5', 'normal']
      ], sanitizeFormulas: true);
      expect(out, contains("'=1+1"));
      expect(out, contains("'@cmd"));
      expect(out, contains('-5')); // negatif sayı korunur, tırnaklanmaz
      expect(out, isNot(contains("'-5")));
    });

    test('sanitize kapalıyken formül hücresi değişmez', () {
      final out = CsvCodec.encode([
        ['=1+1']
      ]);
      expect(out, '=1+1');
    });
  });

  group('parse ↔ encode round-trip', () {
    test('özel karakterli tablo aynen döner', () {
      final table = [
        ['Ad', 'Açıklama'],
        ['Ali, Veli', 'o "dedi"'],
        ['çok\nsatır', 'normal'],
      ];
      final encoded = CsvCodec.encode(table);
      final decoded = CsvCodec.parse(encoded);
      expect(decoded, table);
    });
  });
}
