import 'dart:async';

import 'package:flutter/foundation.dart';

/// Açık bir belge görüntüleyici ilk karesini hazırlarken arka plan işlerini
/// (başlangıç kuyruğu, PDF küçük resim üretimi, sıcak klasör taraması)
/// geçici olarak duraklatan öncelik kapısı.
///
/// Böylece soğuk açılışta hemen PDF açıldığında PDFium tek işçisi ve disk
/// bant genişliği küçük resim/taramayla bölünmez. Emniyet zamanlayıcısı
/// ([maxHold]) tutan ekran serbest bırakmasa bile kilidi açar.
abstract final class ViewerPriority {
  static int _depth = 0;
  static Completer<void>? _idle;

  static bool get active => _depth > 0;

  /// Belge açılışı önceliği alır; dönen geri çağrı ilk kare çizilince ya da
  /// `dispose`'da çağrılır.
  static VoidCallback hold({Duration maxHold = const Duration(seconds: 4)}) {
    _depth++;
    var released = false;
    Timer? timer;
    void release() {
      if (released) return;
      released = true;
      timer?.cancel();
      if (_depth > 0) _depth--;
      if (_depth == 0) {
        final c = _idle;
        _idle = null;
        if (c != null && !c.isCompleted) c.complete();
      }
    }

    timer = Timer(maxHold, release);
    return release;
  }

  /// Etkin belge açılışı bitene dek bekler; yoksa anında tamamlanır.
  static Future<void> waitUntilIdle() {
    if (_depth == 0) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  @visibleForTesting
  static void debugReset() {
    _depth = 0;
    final c = _idle;
    _idle = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}
