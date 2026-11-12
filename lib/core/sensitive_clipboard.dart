import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/fm/native_extras.dart';

/// **Hassas pano** (Güvenlik G2.6, 2026-11-12): parola, anahtar, eşleştirme
/// kodu panoya böyle kopyalanır.
/// * Android 13+: `EXTRA_IS_SENSITIVE` — sistem pano önizlemesi metni göstermez.
/// * [clearAfter] sonra pano HÂLÂ aynı metni tutuyorsa temizlenir (kullanıcı
///   arada başka bir şey kopyaladıysa dokunulmaz). Android 10+ arka planda
///   panoyu okutmaz → okunamazsa dokunulmaz.
abstract final class SensitiveClipboard {
  static const clearAfter = Duration(seconds: 60);
  static Timer? _timer;

  static Future<void> copy(String text) async {
    if (!await NativeExtras.copySensitive(text)) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _timer?.cancel();
    _timer = Timer(clearAfter, () => unawaited(clearIfSame(text)));
  }

  /// Pano [text] ise boşaltır; boşalttıysa true.
  @visibleForTesting
  static Future<bool> clearIfSame(String text) async {
    try {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text != text) return false;
      await Clipboard.setData(const ClipboardData(text: ''));
      return true;
    } catch (_) {
      // Bilinçli: pano okunamıyorsa (arka plan kısıtı) temizlik atlanır.
      return false;
    }
  }
}
