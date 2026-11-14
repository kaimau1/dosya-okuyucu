/// **PDF Pro §6 gecikme logu** (cihaz kapısı 2026-11-13: bütçeler zaman damgası
/// olmadığı için ölçülemedi). Yalnız debug/profil derlemesinde logcat'e
/// `PDFPRO_PERF faz=<ad> ms=<n>` yazar — kişisel içerik YOK (yalnız faz adı +
/// süre). Okuma: `adb logcat -s flutter | grep PDFPRO_PERF`; biçim
/// `docs/perf/2026-11-pdfpro-55-65.md` "PDFPRO_PERF".
///
/// **PDF açılış zaman damgaları** (Ferrari H0.3): dokunuştan itibaren
/// `acilis_ekran` (görüntüleyici kuruldu), `acilis_belge` (`PdfDocument`
/// hazır), `acilis_ilk_sayfa` (ilk sayfanın bitmap'i önbellekte — pdfrx
/// `onDocumentLoadFinished` bunu bekler), `acilis_kucuk_resim` (yan şeridin
/// ilk küçük resmi çizime istendi; şerit kapalıysa yazılmaz). Her faz bir
/// açılışta bir kez; `tool/ab_olcum.sh` bu satırları toplar.
library;

import 'package:flutter/foundation.dart';

abstract final class PdfProPerf {
  /// Yayın derlemesinde null (sabit — ölçüm kodu ağaçtan silinir).
  static Stopwatch? start() => kReleaseMode ? null : (Stopwatch()..start());

  static void end(String phase, Stopwatch? sw) {
    if (sw == null) return;
    debugPrint('PDFPRO_PERF faz=$phase ms=${sw.elapsedMilliseconds}');
  }

  static Stopwatch? _open;
  static final _openLogged = <String>{};

  /// Kullanıcı dosyaya dokundu: açılış saati sıfırdan başlar.
  static void openTap() {
    _open = start();
    _openLogged.clear();
  }

  /// Görüntüleyici kuruldu. Dokunuş yoksa (dış uygulamadan açılış) saat burada
  /// başlar.
  static void openScreen() {
    if (_open == null) openTap();
    openMark('ekran');
  }

  /// `acilis_<faz>` satırı — açılış başına bir kez.
  static void openMark(String phase) {
    final sw = _open;
    if (sw == null || !_openLogged.add(phase)) return;
    end('acilis_$phase', sw);
  }

  /// Görüntüleyici kapandı: sonraki açılış yeni dokunuş bekler.
  static void openDone() {
    _open = null;
    _openLogged.clear();
  }
}
