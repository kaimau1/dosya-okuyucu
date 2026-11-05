@Tags(['perf'])
library;

import 'dart:ui';

import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:dosya_okuyucu/services/scan_export.dart';
import 'package:dosya_okuyucu/services/scan_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Faz 35 — tarayıcı kıyas testleri (performans anayasası k.8a). Eşikler
/// debug/JIT için gevşek; sayılar `PERF` satırıyla günlüğe düşer. Ağır görsel
/// işleri üründe izolatta koşar — burada yalnız tek çağrının süresi ölçülür.
void main() {
  test('tablo algılama: 30 sayfa × 120 satır ≤ 1,5 sn', () {
    final pages = [
      for (var p = 0; p < 30; p++)
        [
          for (var r = 0; r < 120; r++)
            for (var c = 0; c < 4; c++)
              OcrLine('h$r$c', Rect.fromLTWH(20.0 + c * 180, 20.0 + r * 26, 90, 18)),
        ],
    ];
    final sw = Stopwatch()..start();
    final bytes = ScanExport.toXlsx(pages);
    sw.stop();
    // ignore: avoid_print
    print('PERF scan_xlsx_30p_ms=${sw.elapsedMilliseconds}');
    expect(bytes, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });

  test('kalite ölçümü (2480 px sayfa) ≤ 1,2 sn', () {
    final page = img.Image(width: 1754, height: 2480, numChannels: 3);
    img.fill(page, color: img.ColorRgb8(240, 240, 240));
    for (var y = 100; y < 2400; y += 40) {
      img.fillRect(page, x1: 120, y1: y, x2: 1600, y2: y + 6,
          color: img.ColorRgb8(20, 20, 20));
    }
    final sw = Stopwatch()..start();
    final r = ScanQualityCheck.measureImage(page);
    sw.stop();
    // ignore: avoid_print
    print('PERF scan_quality_ms=${sw.elapsedMilliseconds}');
    expect(r.hint, isNull);
    expect(sw.elapsedMilliseconds, lessThan(1200));
  });
}
