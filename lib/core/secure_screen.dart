import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/fm/native_extras.dart';

/// **Ekran görüntüsü / ekran kaydı / son uygulamalar önizlemesi engeli**
/// (G1.4, B10) — Android `FLAG_SECURE`, **tek kapı**.
///
/// Kasa, PIN/parola girişi, uygulama kilidi, AI anahtarı ve uzak bağlantı
/// parolası ekranları [SecureScreen] ile sarılır. İç içe ekranlarda biri
/// kapanınca bayrak erken kalkmasın diye **sayaçlıdır** ([ScreenAwake] ile
/// aynı desen): bayrak yalnız ilk sahip gelince açılır, sonuncusu bırakınca kapanır.
abstract final class SecureScreenGate {
  static int _holders = 0;

  /// Yalnız test: native çağrı yerine buraya yönlendirir.
  @visibleForTesting
  static Future<void> Function(bool secure)? debugOverride;

  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static void debugReset() {
    _holders = 0;
    debugOverride = null;
  }

  /// Bayrağı ister; dönen işlev bırakır (birden çok çağrılsa da sayaç bir kez düşer).
  static VoidCallback request() {
    _holders++;
    if (_holders == 1) unawaited(_apply(true));
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_holders > 0) _holders--;
      if (_holders == 0) unawaited(_apply(false));
    };
  }

  static Future<void> _apply(bool secure) async {
    try {
      final o = debugOverride;
      if (o != null) {
        await o(secure);
      } else {
        await NativeExtras.setSecure(secure);
      }
    } catch (_) {}
  }
}

/// Alt ağacı görünür olduğu sürece ekran görüntüsünü engeller.
class SecureScreen extends StatefulWidget {
  final Widget child;
  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    _release = SecureScreenGate.request();
  }

  @override
  void dispose() {
    _release?.call();
    _release = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
