import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// G7.2 — arşiv girdisi yol testleri (zip-slip).
void main() {
  const t = '/hedef/klasor';

  test('olağan girdiler hedefin içine', () {
    expect(safeArchiveJoin(t, 'a.txt'), '/hedef/klasor/a.txt');
    expect(safeArchiveJoin(t, 'alt/b.pdf'), '/hedef/klasor/alt/b.pdf');
    expect(safeArchiveJoin(t, 'alt/../c.txt'), '/hedef/klasor/c.txt');
    expect(safeArchiveJoin(t, 'ad sonu boşluk '), '/hedef/klasor/ad sonu boşluk ');
    expect(safeArchiveJoin(t, 'nokta.'), '/hedef/klasor/nokta.');
  });

  test('kök dışına çıkan girdiler reddedilir', () {
    for (final bad in [
      '../x',
      '../../etc/passwd',
      'a/../../x',
      '/etc/x',
      './../x',
    ]) {
      expect(safeArchiveJoin(t, bad), isNull, reason: bad);
    }
  });

  test('hedefin kendisi, NUL ve aşırı uzun ad reddedilir', () {
    expect(safeArchiveJoin(t, ''), isNull);
    expect(safeArchiveJoin(t, '.'), isNull);
    expect(safeArchiveJoin(t, 'a/..'), isNull);
    expect(safeArchiveJoin(t, 'a\u0000.txt'), isNull);
    expect(safeArchiveJoin(t, 'x' * 4097), isNull);
  });

  test("Windows biçimli yol POSIX'te tek ad olarak kalır (kaçamaz)", () {
    final r = safeArchiveJoin(t, r'C:\x');
    expect(r, isNotNull);
    expect(r!.startsWith('$t/'), isTrue);
  });
}
