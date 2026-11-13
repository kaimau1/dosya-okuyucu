/// **PDF Pro §6 gecikme logu** (cihaz kapısı 2026-11-13: bütçeler zaman damgası
/// olmadığı için ölçülemedi). Yalnız debug/profil derlemesinde logcat'e
/// `PDFPRO_PERF faz=<ad> ms=<n>` yazar — kişisel içerik YOK (yalnız faz adı +
/// süre). Okuma: `adb logcat -s flutter | grep PDFPRO_PERF`; biçim
/// `docs/perf/2026-11-pdfpro-55-65.md` "PDFPRO_PERF".
library;

import 'package:flutter/foundation.dart';

abstract final class PdfProPerf {
  /// Yayın derlemesinde null (sabit — ölçüm kodu ağaçtan silinir).
  static Stopwatch? start() => kReleaseMode ? null : (Stopwatch()..start());

  static void end(String phase, Stopwatch? sw) {
    if (sw == null) return;
    debugPrint('PDFPRO_PERF faz=$phase ms=${sw.elapsedMilliseconds}');
  }
}
