import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// `flutter drive` sürücüsü (Faz 42 / 6): her `traceAction` anahtarı için
/// `build/<anahtar>.timeline_summary.json` (kare build/raster p90/p99,
/// en kötü kare, kaçan kare sayısı). Özet tablosu `tool/perf_senaryo.sh`.
/// Test kırmızı bitse de toplanan senaryolar yazılır (T1).
Future<void> main() => integrationDriver(
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        if (data == null) return;
        for (final entry in data.entries) {
          final timeline =
              driver.Timeline.fromJson(entry.value as Map<String, dynamic>);
          // Kare olayı olmayan çizelge (boşta bekleme) özetlenemez —
          // `TimelineSummary._averageInMillis` boş listede StateError atar
          // (T1, Huawei 2026-11-20). Yalnız o senaryo atlanır.
          try {
            final summary = driver.TimelineSummary.summarize(timeline);
            await summary.writeTimelineToFile(entry.key,
                pretty: true, includeSummary: true);
          } on StateError {
            print('PERF ${entry.key}: kare yok, atlandı');
          }
        }
      },
    );
