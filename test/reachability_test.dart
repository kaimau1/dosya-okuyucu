// Erişilebilirlik bekçisi (2026-11-02; HAFIZA aynı tarih).
//
// `lib/` altındaki her Dart dosyası `lib/main.dart`'tan import / export /
// part zinciriyle erişilebilir olmalı. 2026-11-01 taramasında üç dosya
// kopuk çıkmıştı (`qr_share_screen.dart` paylaş seçimi daralınca koptu,
// yalnız testi kullanıyordu); bundan sonra kopan ekran burada yakalanır.
// Yalnız örnek üretimi / test için gereken kod `test/support/`'a gider.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]([^;]*);''',
  multiLine: true,
);
// Koşullu import: `import 'a.dart' if (dart.library.io) 'b.dart';`
final _conditional = RegExp(r'''if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

String? _resolve(String fromFile, String uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    const own = 'package:dosya_okuyucu/';
    if (!uri.startsWith(own)) return null; // başka paket
    return p.normalize(p.join('lib', uri.substring(own.length)));
  }
  return p.normalize(p.join(p.dirname(fromFile), uri));
}

Set<String> reachableFrom(String entry) {
  final seen = <String>{};
  final queue = <String>[p.normalize(entry)];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!seen.add(file)) continue;
    final f = File(file);
    if (!f.existsSync()) continue;
    final src = f.readAsStringSync();
    for (final m in _directive.allMatches(src)) {
      final uris = [
        m.group(1)!,
        for (final c in _conditional.allMatches(m.group(2) ?? '')) c.group(1)!,
      ];
      for (final u in uris) {
        final r = _resolve(file, u);
        if (r != null && !seen.contains(r)) queue.add(r);
      }
    }
  }
  return seen;
}

void main() {
  test('lib/ altındaki her dosya main.dart\'tan erişilebilir', () {
    final reach = reachableFrom('lib/main.dart');
    final all = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.normalize(f.path))
        .where((f) => f.endsWith('.dart'))
        .toList()
      ..sort();
    final orphans = [for (final f in all) if (!reach.contains(f)) f];
    expect(orphans, isEmpty,
        reason: 'main.dart\'tan erişilemeyen dosya(lar) — bağla, '
            'test/support/\'a taşı ya da sil:\n${orphans.join('\n')}');
  });

  test('gezgin göreli, package: ve koşullu importu çözer', () {
    expect(_resolve('lib/a/b.dart', '../c.dart'), p.normalize('lib/c.dart'));
    expect(_resolve('lib/a/b.dart', 'package:dosya_okuyucu/x/y.dart'),
        p.normalize('lib/x/y.dart'));
    expect(_resolve('lib/a.dart', 'package:flutter/material.dart'), isNull);
    expect(_resolve('lib/a.dart', 'dart:io'), isNull);
    final m = _directive.firstMatch(
        "import 'a.dart' if (dart.library.html) 'b.dart';")!;
    expect(m.group(1), 'a.dart');
    expect(_conditional.firstMatch(m.group(2)!)!.group(1), 'b.dart');
  });
}
