import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';

/// **Yanlış PIN beklemesi** (G3.2, 2026-11-11) — kalıcı.
///
/// Kasa, uygulama kilidi ve klasör kilidi AYNI PIN'i kullanır (tek PIN,
/// 2026-10-21); sayaç da tek: üç ayrı sayaç saldırgana üç kat deneme verirdi.
///
/// Kural: ilk [freeTries] yanlış serbest; sonra 30 sn, her yeni yanlışta iki
/// katı, en çok 1 saat. Doğru PIN sayacı sıfırlar. Sayaç diskte
/// (`pin_fail_count`, `pin_fail_at`): uygulamayı kapatıp açmak beklemeyi
/// atlatmaz. Saat geri alınırsa (şimdi < son yanlış) bekleme BAŞTAN başlar.
///
/// Eskiden yalnız uygulama kilidinde bellekte bir sayaç vardı (5 sn'den 60
/// sn'ye); uygulamayı yeniden açmak onu sıfırlıyordu, kasada hiç yoktu.
class PinBackoff {
  PinBackoff(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const kCount = 'pin_fail_count';
  static const kAt = 'pin_fail_at';
  static const freeTries = 5;
  static const firstWait = Duration(seconds: 30);
  static const maxWait = Duration(hours: 1);

  /// Widget testleri saati buradan ilerletir (sahte saat `DateTime.now`u
  /// ilerletmez).
  @visibleForTesting
  static DateTime Function()? debugClock;

  /// Uygulama geneli örnek (ekranlar bunu kullanır; tercihler önbellekli).
  static Future<PinBackoff> instance() async =>
      PinBackoff(await SharedPreferences.getInstance(), clock: debugClock);

  int get failures => _prefs.getInt(kCount) ?? 0;

  /// [failures] yanlıştan sonra beklenecek süre.
  static Duration waitFor(int failures) {
    if (failures < freeTries) return Duration.zero;
    final shift = failures - freeTries;
    if (shift >= 7) return maxWait; // 30 sn × 2^7 = 64 dk > 1 sa
    final secs = firstWait.inSeconds << shift;
    return secs >= maxWait.inSeconds ? maxWait : Duration(seconds: secs);
  }

  /// Şu an deneme yapılabilmesi için kalan süre (sıfır = serbest).
  Duration remaining() {
    final wait = waitFor(failures);
    if (wait == Duration.zero) return Duration.zero;
    final atMs = _prefs.getInt(kAt) ?? 0;
    final now = _clock();
    var at = DateTime.fromMillisecondsSinceEpoch(atMs);
    if (now.isBefore(at)) {
      // Saat geri alındı: bekleme şimdiden başlar (kısalmasın).
      at = now;
      _prefs.setInt(kAt, now.millisecondsSinceEpoch);
    }
    final left = at.add(wait).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool get blocked => remaining() > Duration.zero;

  Future<void> recordFailure() async {
    await _prefs.setInt(kCount, failures + 1);
    await _prefs.setInt(kAt, _clock().millisecondsSinceEpoch);
  }

  Future<void> recordSuccess() async {
    await _prefs.remove(kCount);
    await _prefs.remove(kAt);
  }
}

/// "Çok fazla yanlış deneme — 0:30 bekleyin" (dakika:saniye; dilden bağımsız).
String pinWaitText(AppStrings strings, Duration wait) {
  final secs = wait.inSeconds + (wait.inMilliseconds % 1000 > 0 ? 1 : 0);
  final m = secs ~/ 60;
  final s = (secs % 60).toString().padLeft(2, '0');
  return strings.t('pin.wait', {'t': '$m:$s'});
}
