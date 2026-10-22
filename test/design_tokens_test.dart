import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Tasarım tokenı bekçisi** (Faz 15, 2026-10-22).
///
/// Ekran kodunda ham simge (`Icons.*`), sabit renk (`Color(0x…)`,
/// `Colors.*`), sabit punto (`fontSize:`) ve sabit animasyon süresi
/// (`Duration(milliseconds: N)`) ile elle kurulan iletişim penceresi/levha
/// (`showDialog`, `showModalBottomSheet`) sayılır. Sayımlar
/// `test/design_tokens_baseline.json`daki dosya başı tavanı GEÇEMEZ; yeni
/// dosyada tavan 0'dır. Böylece:
/// * yeni kod tokenları kullanmak zorunda (`AppIcons`, `AppColors`/`AppHues`,
///   `TextTheme`, `Motion`);
/// * eski kod taşındıkça tavan düşer ("izin listesi faz boyunca küçülür").
///
/// Bir dosyayı taşıdıktan sonra tavanı düşürmek için:
///   UPDATE_DESIGN_BASELINE=1 flutter test test/design_tokens_test.dart
/// (yalnız AZALAN sayıları yazar; artışı asla kabul etmez).
///
/// Bilinçli sabitler (belge içi renkler, görsel düzenleyici kalem paleti,
/// zamanlayıcılar) tavanda kalır — onlar "tasarım" değil "içerik".
const _baselinePath = 'test/design_tokens_baseline.json';

/// Token dosyalarının kendisi sayılmaz.
const _tokenFiles = {
  'lib/core/app_icons.dart',
  'lib/core/app_colors.dart',
  'lib/core/motion.dart',
  'lib/core/theme.dart',
  'lib/core/skin.dart',
  'lib/widgets/app_dialog.dart',
};

final _metrics = <String, RegExp>{
  // `AppIcons.` / `CupertinoIcons.` değil, çıplak `Icons.`.
  'icons': RegExp(r'(?<![A-Za-z0-9_])Icons\.[a-z0-9_]+'),
  // Tek glif ailesi: `_rounded` dışı (çizgi/keskin/dolu eski aile).
  'glyph_family': RegExp(r'(?<![A-Za-z0-9_])Icons\.(?![a-z0-9_]*_rounded\b)[a-z0-9_]+'),
  'hex_colors': RegExp(r'Color\(0x'),
  // `Colors.transparent` renk değil "renk yok"; sayılmaz.
  'material_colors': RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)[a-zA-Z0-9]+'),
  'font_size': RegExp(r'\bfontSize:'),
  'durations': RegExp(r'Duration\(milliseconds: \d+\)'),
  // Ortak bileşen: `showAppConfirm` / `showAppSheet` (widgets/app_dialog.dart).
  'dialogs': RegExp(r'\bshowDialog\b'),
  'sheets': RegExp(r'\bshowModalBottomSheet\b'),
};

Map<String, Map<String, int>> _measure() {
  final out = <String, Map<String, int>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => !_tokenFiles.contains(p))
      .toList()
    ..sort();
  for (final path in files) {
    final counts = <String, int>{};
    for (final raw in File(path).readAsLinesSync()) {
      // Yorumdaki söz (`/// Icons.folder` gibi) sayılmaz.
      final i = raw.indexOf('//');
      final line = i < 0 ? raw : raw.substring(0, i);
      _metrics.forEach((k, re) {
        final n = re.allMatches(line).length;
        if (n > 0) counts[k] = (counts[k] ?? 0) + n;
      });
    }
    if (counts.isNotEmpty) out[path] = counts;
  }
  return out;
}

void main() {
  test('tasarım tokenı tavanları aşılmıyor', () {
    final now = _measure();
    final baseFile = File(_baselinePath);
    if (!baseFile.existsSync() &&
        Platform.environment['UPDATE_DESIGN_BASELINE'] == '1') {
      // İlk kurulum: bugünkü sayımlar tavan olur.
      baseFile.writeAsStringSync(
          '${const JsonEncoder.withIndent(' ').convert(now)}\n');
    }
    final base =(jsonDecode(baseFile.readAsStringSync()) as Map)
        .map((k, v) => MapEntry(k as String, (v as Map).cast<String, int>()));

    final over = <String>[];
    now.forEach((path, counts) {
      counts.forEach((metric, n) {
        final cap = base[path]?[metric] ?? 0;
        if (n > cap) over.add('$path $metric: $n > tavan $cap');
      });
    });

    if (Platform.environment['UPDATE_DESIGN_BASELINE'] == '1' && over.isEmpty) {
      // Yalnız düşüş: tavan = min(tavan, şimdi).
      final next = <String, Map<String, int>>{};
      for (final path in {...base.keys, ...now.keys}.toList()..sort()) {
        final m = <String, int>{};
        for (final metric in _metrics.keys) {
          final n = now[path]?[metric] ?? 0;
          if (n > 0) m[metric] = n;
        }
        if (m.isNotEmpty) next[path] = m;
      }
      baseFile.writeAsStringSync(
          '${const JsonEncoder.withIndent(' ').convert(next)}\n');
    }

    expect(over, isEmpty,
        reason: 'Yeni kod tokenları kullanmalı: AppIcons, AppColors/AppHues, '
            'TextTheme rolleri, Motion. (bkz. test/design_tokens_test.dart)');
  });

  test('toplam sayımlar raporu (Faz 15 / §3.14.3)', () {
    final totals = <String, int>{};
    for (final c in _measure().values) {
      c.forEach((k, n) => totals[k] = (totals[k] ?? 0) + n);
    }
    // Rapor için yazdırılır; HAFIZA'daki "önce → sonra" sayıları buradan.
    // ignore: avoid_print
    print('design tokens: $totals');
    expect(totals, isNotEmpty);
  });
}
