import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Gerekçesiz boş `catch` cırcırı** (KALANLAR A4.3, 2026-11-11).
///
/// `catch (_) {}` hatayı iz bırakmadan yutar: kullanıcı "kaydettim" sanır,
/// tanı raporunda da hiçbir şey görünmez. Her boş yakalama ya
/// (a) BEKLENEN bir durumdur → gövdeye tek satır `// Bilinçli: …` gerekçe,
/// (b) gerçek bir arızadır → `CrashLog.record(...)`,
/// (c) kullanıcının bilmesi gereken bir sonuçtur → `UserError` / snack.
///
/// Yorumlu gövde (`catch (_) { // Bilinçli: … }`) sayılmaz. Tavan yalnız
/// AŞAĞI iner: yenisini ekleme; bir tanesini sınıflandırdıysan tavanı düşür.
const _ceiling = 0;

final _emptyCatch =
    RegExp(r'catch\s*\(\s*\w+\s*(,\s*\w+\s*)?\)\s*\{\s*\}');

void main() {
  test('lib içinde gerekçesiz boş catch tavanı aşılmaz', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final m in _emptyCatch.allMatches(text)) {
        final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
        hits.add('${f.path}:$line');
      }
    }
    expect(hits.length, lessThanOrEqualTo(_ceiling),
        reason: 'Gerekçesiz boş catch eklendi (${hits.length} > $_ceiling). '
            'Gövdeye "// Bilinçli: …" yaz ya da hatayı kaydet:\n'
            '${hits.join('\n')}');
  });
}
