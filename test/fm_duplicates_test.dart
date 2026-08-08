import 'dart:io';
import 'dart:math';

import 'package:dosya_okuyucu/services/fm/duplicate_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

/// Yinelenen dosya bulucu: kullanıcının dosyasını sildirecek bir özellik
/// olduğu için "yanlış pozitif YOK" güvencesi testle sabitlenir.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('fm_dup_test'));
  tearDown(() => removeTempDir(tmp));

  /// Belirlenimci "rastgele" içerik (aynı tohum → aynı bayt dizisi).
  List<int> content(int seed, int length) {
    final rnd = Random(seed);
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  File write(String relative, List<int> bytes) {
    final f = File(p.join(tmp.path, relative));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    return f;
  }

  List<DuplicateGroup> scan({int minBytes = 16}) =>
      DuplicateFinder.scanSync([tmp.path], minBytes, 100);

  test('aynı içerikli dosyalar tek grupta toplanır (alt klasörler dahil)', () {
    final data = content(1, 5000);
    write('a.bin', data);
    write('alt/kopya.bin', data);
    write('alt/derin/ucuncu.bin', data);
    write('farkli.bin', content(2, 5000)); // aynı BOYUT, farklı içerik

    final groups = scan();

    expect(groups, hasLength(1));
    expect(groups.single.files.map((f) => f.name).toSet(),
        {'a.bin', 'kopya.bin', 'ucuncu.bin'});
    expect(groups.single.sizeBytes, 5000);
    expect(groups.single.wastedBytes, 10000); // 2 fazladan kopya
  });

  test('aynı boyutlu ama farklı içerik EŞLEŞMEZ (bayt bayt doğrulama)', () {
    write('x.bin', content(3, 4096));
    write('y.bin', content(4, 4096));
    // Yalnız son baytı farklı: parmak izi kuyruğu bunu yakalar, yakalamasa
    // bile bayt karşılaştırması eler.
    final base = content(5, 4096);
    write('z1.bin', base);
    write('z2.bin', [...base.sublist(0, 4095), (base.last + 1) % 256]);

    expect(scan(), isEmpty);
  });

  test('eşik altındaki küçük dosyalar sayılmaz', () {
    write('kucuk1.txt', List.filled(10, 65));
    write('kucuk2.txt', List.filled(10, 65));

    expect(DuplicateFinder.scanSync([tmp.path], 1024, 100), isEmpty);
    expect(DuplicateFinder.scanSync([tmp.path], 4, 100), hasLength(1));
  });

  test('gruplar kazanılacak yere göre azalan sıralanır', () {
    final small = content(6, 2000);
    write('s1.bin', small);
    write('s2.bin', small);
    final big = content(7, 40000);
    write('b1.bin', big);
    write('b2.bin', big);

    final groups = scan();
    expect(groups, hasLength(2));
    expect(groups.first.sizeBytes, 40000);
    expect(groups.first.wastedBytes, greaterThan(groups.last.wastedBytes));
  });

  test('sameContent: uzunluk farkı erken elenir, okunamayan dosya false', () {
    final a = write('a.txt', List.filled(100, 1));
    final b = write('b.txt', List.filled(101, 1));
    expect(DuplicateFinder.sameContent(a.path, a.path), isTrue);
    expect(DuplicateFinder.sameContent(a.path, b.path), isFalse);
    expect(DuplicateFinder.sameContent(a.path, p.join(tmp.path, 'yok')),
        isFalse);
  });

  test('fingerprint: aynı içerik aynı, farklı içerik farklı', () {
    final a = write('f1.bin', content(8, 3000));
    final b = write('f2.bin', content(8, 3000));
    final c = write('f3.bin', content(9, 3000));

    final pa = DuplicateFinder.fingerprint(a.path, 3000);
    final pb = DuplicateFinder.fingerprint(b.path, 3000);
    final pc = DuplicateFinder.fingerprint(c.path, 3000);

    expect(pa, isNotNull);
    expect(pa, pb);
    expect(pa, isNot(pc));
    expect(DuplicateFinder.fingerprint(p.join(tmp.path, 'yok'), 1), isNull);
  });
}
