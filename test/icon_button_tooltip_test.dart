import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Erişilebilirlik bekçisi** (2026-09-23 tasarım denetimi).
///
/// Metinsiz bir `IconButton` TalkBack'te yalnız "düğme" diye okunur ve uzun
/// basınca hiçbir şey söylemez: kullanıcı simgenin ne yaptığını tahmin etmek
/// zorunda kalır. Denetimde 33 tane bulundu. Eksiklik çalışırken hata
/// vermediği için kimse fark etmez; ancak kaynağa bakan bir test yakalar
/// (aynı gerekçe: `l10n_literals_test`).
///
/// Kural: her `IconButton` bir `tooltip:` taşır YA DA hemen bir
/// `Semantics(label: …)` sarmalının içindedir.
void main() {
  test('her IconButton bir tooltip ya da Semantics etiketi taşır', () {
    final missing = <String>[];
    final pattern = RegExp(r'IconButton(\.filled|\.outlined|\.filledTonal)?\(');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final body = _call(source, match.end - 1);
        if (body.contains('tooltip:')) continue;
        final before = source.substring(
            match.start > 160 ? match.start - 160 : 0, match.start);
        if (before.contains('Semantics(') && before.contains('label:')) {
          continue;
        }
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        missing.add('${entity.path}:${line + 1}');
      }
    }
    expect(missing, isEmpty,
        reason: 'tooltip eksik IconButton(lar):\n${missing.join('\n')}');
  });
}

/// `(`'dan eşleşen `)`'ye kadar olan çağrı gövdesi.
String _call(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}
