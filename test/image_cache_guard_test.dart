import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B12 madde 4 (PLAN §1.12) — görsel çözme bütçesi bekçisi.
///
/// Bellekten çözülen görsel (`Image.memory`, `MemoryImage`) çözme boyu
/// almalı: `cacheWidth`/`cacheHeight` ya da `ResizeImage` sarmalayıcısı.
/// Yoksa 12 MP'lik bir fotoğraf ekrandaki 100 dp'lik kutu için 48 MB bitmap
/// olur. (Dosyadan çözme zaten yalnız `FmFileImage` ile — G7.7 bekçisi.)
///
/// Tavanlı istisnalar (YALNIZ DÜŞER) gerekçeli; yeni dosyada 0.
void main() {
  const ceilings = <String, int>{
    // Süzgeç önizlemeleri izolatta `longEdge`e küçültülmüş bayt
    // (ScanEnhance.previews) — kaynakta tavanlı.
    'lib/screens/scan_result/widgets.dart': 1,
    // PDF nesne katmanı: PDF kabuğu sıcak yolu (ÖLÇÜM KAPISI) — cihaz A/B
    // ile C2'de; bulutta dokunulmaz.
    'lib/widgets/pdf_object_layer.dart': 1,
  };

  /// [open] konumundaki `(`'in kapanışına kadar olan argüman metni.
  String argsAt(String s, int open) {
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) return s.substring(open, i + 1);
      }
    }
    return s.substring(open);
  }

  String stripLineComments(String src) {
    final out = StringBuffer();
    for (final raw in src.split('\n')) {
      final c = raw.indexOf('//');
      out.writeln(c < 0 ? raw : raw.substring(0, c));
    }
    return out.toString();
  }

  test('bellekten çözülen görselde çözme boyu var (mandal)', () {
    final counts = <String, int>{};
    final hits = <String>[];
    final memory = RegExp(r'\bImage\.memory\(');
    // `pw.MemoryImage` (pdf paketi) ekran görseli değil — hariç.
    final provider = RegExp(r'(?<![\w.])MemoryImage\(');
    for (final root in ['lib/screens', 'lib/widgets', 'lib/core']) {
      for (final f in Directory(root).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll('\\', '/');
        final src = stripLineComments(f.readAsStringSync());
        var n = 0;
        for (final m in memory.allMatches(src)) {
          final args = argsAt(src, m.end - 1);
          if (!args.contains('cacheWidth') && !args.contains('cacheHeight')) {
            n++;
            hits.add('$path: Image.memory');
          }
        }
        for (final m in provider.allMatches(src)) {
          final before = src.substring(m.start < 40 ? 0 : m.start - 40, m.start);
          if (!before.contains('ResizeImage(')) {
            n++;
            hits.add('$path: MemoryImage');
          }
        }
        if (n > 0) counts[path] = n;
      }
    }
    final over = [
      for (final e in counts.entries)
        if (e.value > (ceilings[e.key] ?? 0))
          '${e.key}: ${e.value} > ${ceilings[e.key] ?? 0}',
    ];
    expect(over, isEmpty,
        reason: 'cacheWidth (ImageBudget.decodeWidth / fmThumbWidth) ya da '
            'ResizeImage ver: ${hits.join(', ')}');
    final stale = [
      for (final e in ceilings.entries)
        if ((counts[e.key] ?? 0) < e.value)
          '${e.key}: ${counts[e.key] ?? 0} < ${e.value}',
    ];
    expect(stale, isEmpty, reason: 'tavanı düşür');
  });
}
