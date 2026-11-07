import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// `flutter drive` sürücüsü (Faz 42 / 6): her `traceAction` anahtarı için
/// `build/<anahtar>.timeline_summary.json` (kare build/raster p90/p99,
/// en kötü kare, kaçan kare sayısı). Özet tablosu `tool/perf_senaryo.sh`.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        for (final entry in data.entries) {
          final timeline =
              driver.Timeline.fromJson(entry.value as Map<String, dynamic>);
          // Boş çizelge (o aralıkta hiç kare yok) özetlenemez → yalnız o
          // senaryo atlanır, ötekiler yazılır (Faz 44: tüm koşu düşüyordu).
          if (timeline.events?.isEmpty ?? true) {
            print('PERF ${entry.key}: kare yok, atlandı');
            continue;
          }
          final summary = driver.TimelineSummary.summarize(timeline);
          await summary.writeTimelineToFile(entry.key,
              pretty: true, includeSummary: true);
        }
      },
    );
