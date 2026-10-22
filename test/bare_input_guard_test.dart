import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Bekçi (2026-10-22, kullanıcı ekran görüntüsü — Excel hücresi):**
/// Temanın `InputDecorationTheme`i `enabledBorder`/`focusedBorder` ve
/// `filled: true` tanımlıyor. Bir `InputDecoration` yalnız
/// `border: InputBorder.none` derse bu üçü TEMADAN gelir → yerinde
/// düzenleyicide (hücre, slayt kutusu, Word sayfası) yazı küçük, yuvarlak,
/// mavi bir çerçeveye alınıyordu. "Çerçevesiz" alan dört anahtarı birlikte
/// söylemeli.
void main() {
  test('çerçevesiz giriş alanları temanın çerçevesini/dolgusunu almaz', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final t = f.readAsStringSync();
      var from = 0;
      while (true) {
        final i = t.indexOf('border: InputBorder.none', from);
        if (i < 0) break;
        from = i + 1;
        final start = t.lastIndexOf('InputDecoration(', i);
        var depth = 0, j = start + 'InputDecoration'.length;
        for (; j < t.length; j++) {
          if (t[j] == '(') depth++;
          if (t[j] == ')' && --depth == 0) break;
        }
        final block = t.substring(start, j);
        for (final k in ['enabledBorder:', 'focusedBorder:', 'filled:']) {
          if (!block.contains(k)) {
            bad.add('${f.path}:${'\n'.allMatches(t.substring(0, i)).length + 1} ($k yok)');
          }
        }
      }
    }
    expect(bad, isEmpty);
  });
}
