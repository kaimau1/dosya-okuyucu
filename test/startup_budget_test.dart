import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Faz 42 / 1 — **açılış bütçesi bekçisi** (performans anayasası kural 2).
///
/// Soğuk açılış ~430–630 ms (docs/perf/2026-10-21.md). İlk kareden önce
/// BEKLENEN (`await`) her iş açılışı doğrudan uzatır; bu yüzden `main()`
/// içindeki `await` çağrıları onaylı bir listeyle sınırlı. Yeni bir iş
/// gerekiyorsa `unawaited(...)` ya da `StartupQueue` (ilk 2 sn sonra, tek
/// sıra) kullanılır; gerçekten ilk kareden önce gerekiyorsa gerekçesi
/// HAFIZA'ya yazılıp aşağıdaki listeye eklenir.
void main() {
  const allowed = <String>{
    'SystemChrome.setEnabledSystemUIMode', // kenardan kenara: ilk kare zıplamasın
    'NativeExtras.loadSystemAccent', // tema rengi ilk karede doğru
    'pickerState.init', // yalnız dosya seçici girişi
    'DeviceProfile.load', // PerfBudget ilk kareden önce
    'appState.init',
    // Taşıma geri çağrısı içinde (açılışta koşmaz):
    'FileTags.movePath',
    'OpenHistory.movePath',
    'FmColorsStore.moveFolder',
  };

  String mainBody() {
    final src = File('lib/main.dart').readAsStringSync();
    // main() artık tek satır: _main'i çevrimdışı kip bölgesinde koşturur (offline_mode.dart).
    final start = src.indexOf('Future<void> _main() async {');
    expect(start, isNonNegative, reason: 'main() imzası bulunamadı');
    final end = src.indexOf('\n}\n', start);
    return src.substring(start, end);
  }

  test('main() yalnız onaylı işleri bekler (açılış bütçesi)', () {
    final awaited = RegExp(r'await\s+([\w.]+)\(')
        .allMatches(mainBody())
        .map((m) => m.group(1)!)
        .toList();
    final extra = awaited.where((n) => !allowed.contains(n)).toList();
    expect(extra, isEmpty,
        reason: 'İlk kareden önce yeni bekleyen iş: $extra — unawaited/'
            'StartupQueue kullan ya da gerekçeyle listeye ekle (Faz 42 / 1).');
    // Aynı iş iki kez beklenmesin diye toplam sayı da tavanlı.
    expect(awaited.length, lessThanOrEqualTo(allowed.length + 1));
  });

  // B12 m.5 (2026-11-18): `runApp` öncesi beklenen iş sayısı (taşıma geri
  // çağrısındakiler hariç; seçici ve ana yol birlikte) — MANDAL, yalnız
  // düşer. 7 → 6 (AppHaptics.load beklenmiyor). Kalanlar her yolda 4:
  // kenardan kenara, sistem rengi, durum init, cihaz profili.
  const preRunAppCeiling = 6;
  const inCallback = {
    'FileTags.movePath',
    'OpenHistory.movePath',
    'FmColorsStore.moveFolder',
  };

  test('runApp öncesi await sayısı tavanı (mandal)', () {
    final n = RegExp(r'await\s+([\w.]+)\(')
        .allMatches(mainBody())
        .where((m) => !inCallback.contains(m.group(1)))
        .length;
    expect(n, lessThanOrEqualTo(preRunAppCeiling),
        reason: 'İlk kareden önce yeni bekleyen iş ($n > $preRunAppCeiling).');
    expect(n, preRunAppCeiling,
        reason: 'Tavan düştü ($n): preRunAppCeiling\'ı da düşür.');
  });

  test('StartupQueue ilk kareden sonra başlar', () {
    final body = mainBody();
    final queue = body.lastIndexOf('StartupQueue.instance.start(');
    final run = body.lastIndexOf('runApp(');
    expect(queue, isNonNegative);
    expect(queue, lessThan(run),
        reason: 'kuyruk runApp öncesi kurulur, gecikmeyle (DeviceProfile) başlar');
    expect(body.substring(queue, run), contains('startupDelay'));
  });
}
