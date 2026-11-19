import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Sabit satır yüksekliği cırcırı** (B12 m.6, 2026-11-18).
///
/// `itemExtent` / `prototypeItem` / `itemExtentBuilder` verilen liste
/// satırları ÖLÇMEDEN konumlar: uzun listede yukarı kaydırmada her giren
/// satırın ölçülüp ofsetin tahminle düzeltilmesi (G14: 5.000 öğede p99
/// 50 ms) olmaz. Bu sayı yalnız ARTAR: bir listeden kaldırdıysan gerekçesini
/// koda yaz ve tabanı bilerek düşür (yükseklik artık değişkense doğru olan
/// kaldırmaktır — değişken satıra sabit boy KIRPAR).
///
/// Kural: sabit sayı (`itemExtent: 64`) yalnız yüksekliği yazı ölçeğinden
/// bağımsız satırda (ör. `Container(height: …)`); metinli satırda
/// `prototypeItem` (gerçek satır → 2× yazıda da birebir).
const _floor = 11; // B12 m.6: 9 → 11 (tablo görünümü, çalma listesi)

/// Dosya başına beklenen en az kullanım — biri kaybolursa adıyla yakalanır.
const _required = {
  'lib/screens/editors/spreadsheet/grid.dart': 2,
  'lib/screens/viewer/pdf_reading_pro.dart': 1,
  'lib/screens/viewer/widgets.dart': 1,
  'lib/screens/fm/smart_bench_screen.dart': 1,
  'lib/screens/fm/audio_player_screen.dart': 1,
  'lib/screens/fm/photos_screen.dart': 1,
  'lib/screens/fm/dual_pane_screen.dart': 1,
  'lib/screens/pdf_reorder_screen.dart': 1,
  'lib/widgets/fm/fm_file_list_view.dart': 2,
};

final _extent =
    RegExp(r'\b(itemExtent|prototypeItem|itemExtentBuilder)\s*:');

void main() {
  test('sabit satır yükseklikli listeler azalmaz', () {
    final perFile = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        final n = _extent.allMatches(code).length;
        if (n > 0) perFile[path] = (perFile[path] ?? 0) + n;
      }
    }
    final total = perFile.values.fold<int>(0, (a, b) => a + b);
    final missing = [
      for (final e in _required.entries)
        if ((perFile[e.key] ?? 0) < e.value)
          '${e.key}: ${perFile[e.key] ?? 0} < ${e.value}',
    ];
    expect(missing, isEmpty,
        reason: 'Sabit satır yüksekliği kaldırıldı:\n${missing.join('\n')}');
    expect(total, greaterThanOrEqualTo(_floor),
        reason: 'Sabit satırlı liste sayısı düştü ($total < $_floor).');
  });
}
