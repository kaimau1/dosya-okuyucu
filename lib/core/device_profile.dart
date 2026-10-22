import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihaz sınıfı (Faz 4, 2026-10-21 — FAZ_PLANI P1).
///
/// Eskiden 2 GB'lık telefon da 16 GB'lık telefonla AYNI bütçeyle
/// çalışıyordu: 160 MB görsel önbelleği, iki eşzamanlı küçük resim, 120 Hz,
/// otomatik tam tarama. Artık açılışta yerel kanaldan (`Extras.deviceClass`)
/// RAM / çekirdek / `isLowRamDevice` / medya başarım sınıfı okunur ve
/// bütçeler buna göre seçilir.
enum DeviceTier { low, mid, high }

/// Kullanıcının seçimi (Ayarlar > Depolama ve hız > Başarım).
enum PerfMode { auto, light, full }

/// Yerelden okunan ham bilgi. Kanal yoksa (test, eski kurulum) boş.
@immutable
class DeviceInfo {
  final int totalRamMb;
  final bool lowRam;
  final int cores;

  /// `Build.VERSION.MEDIA_PERFORMANCE_CLASS` (Android 12+; yoksa 0).
  final int perfClass;

  const DeviceInfo({
    this.totalRamMb = 0,
    this.lowRam = false,
    this.cores = 0,
    this.perfClass = 0,
  });

  bool get isKnown => totalRamMb > 0 || cores > 0;

  static DeviceInfo fromMap(Map<Object?, Object?>? map) {
    if (map == null) return const DeviceInfo();
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return DeviceInfo(
      totalRamMb: asInt(map['totalRamMb']),
      lowRam: map['lowRam'] == true,
      cores: asInt(map['cores']),
      perfClass: asInt(map['perfClass']),
    );
  }
}

/// Saf sınıflandırma (birim testli).
///
/// - **low**: sistem "düşük RAM" diyor, ya da RAM ≤ 3 GB, ya da ≤ 4 çekirdek.
/// - **high**: RAM ≥ 6 GB ve ≥ 8 çekirdek, ya da medya başarım sınıfı ≥ 12
///   (Android 12 "yüksek başarım" sertifikası).
/// - Bilinmiyorsa **mid** — eski davranışa en yakın, güvenli orta yol.
DeviceTier classifyDevice(DeviceInfo info) {
  if (!info.isKnown) return DeviceTier.mid;
  if (info.lowRam) return DeviceTier.low;
  if (info.totalRamMb > 0 && info.totalRamMb <= 3200) return DeviceTier.low;
  if (info.cores > 0 && info.cores <= 4) return DeviceTier.low;
  if (info.perfClass >= 31) return DeviceTier.high;
  if (info.totalRamMb >= 5800 && info.cores >= 8) return DeviceTier.high;
  return DeviceTier.mid;
}

/// Seçime göre etkin profil: "Otomatik" cihazınkini, "Hafif" daima low,
/// "Tam" daima high.
DeviceTier effectiveTier(PerfMode mode, DeviceTier detected) => switch (mode) {
      PerfMode.auto => detected,
      PerfMode.light => DeviceTier.low,
      PerfMode.full => DeviceTier.high,
    };

/// Profile bağlı bütçeler — tek yerde, sayılar burada.
@immutable
class PerfBudget {
  final DeviceTier tier;
  const PerfBudget(this.tier);

  bool get isLight => tier == DeviceTier.low;

  /// Görsel önbelleği tavanı (P2). Sistem bellek baskısında Flutter zaten
  /// boşaltır; bu yalnız tavan.
  ///
  /// **2026-10-23 telefonda A/B (Xiaomi 13T, 2.764 fotoğraflı klasör):** GPU
  /// belleği bu tavanın ~2-3 katına çıkıyor ve uygulama ön plandayken GERİ
  /// VERİLMİYOR (bellek baskısı sinyali düşürmüyor; Impeller ve Skia'da
  /// aynı). 160 MB / 1000 → GL 496 MB, PSS 696 MB; 64 MB / 300 → GL 233 MB,
  /// PSS 441 MB — kaydırmada ek takılma YOK (Flutter kare ölçümü).
  int get imageCacheBytes => switch (tier) {
        DeviceTier.low => 56 << 20,
        DeviceTier.mid => 64 << 20,
        DeviceTier.high => 64 << 20,
      };

  /// Önbellekteki en çok görsel sayısı (varsayılan 1000).
  int get imageCacheCount => switch (tier) {
        DeviceTier.low => 300,
        DeviceTier.mid => 300,
        DeviceTier.high => 300,
      };

  /// Aynı anda çözülen video/PDF küçük resmi (yerel kanal işleri).
  int get thumbConcurrency => isLight ? 1 : 2;

  /// Süs animasyonları (iskelet nabzı, giriş kaymaları) — hafifte kapalı.
  bool get decorativeAnimations => !isLight;

  /// Yüksek tazeleme hızı ve otomatik tam tarama için VARSAYILAN (kullanıcı
  /// açıkça seçtiyse onun seçimi geçerli).
  bool get highRefreshDefault => !isLight;
  bool get autoRescanDefault => !isLight;

  /// Takılabilir bellek yoklama aralığı (P6) — asıl haber dizin izleme ve
  /// USB yayınından gelir; yoklama yalnız yedek.
  Duration get volumePoll =>
      isLight ? const Duration(seconds: 30) : const Duration(seconds: 15);

  /// Açılış kuyruğunun ilk kareden sonra bekleme süresi (P11).
  Duration get startupDelay =>
      isLight ? const Duration(seconds: 3) : const Duration(seconds: 2);
}

/// Süreç geneli profil. `main` açılışta [load] eder; ayar değişince
/// [setMode] çağrılır. Testlerde [debugOverride] ile sabitlenir.
abstract final class DeviceProfile {
  static const _ch = MethodChannel('dosya/extras');

  static DeviceInfo _info = const DeviceInfo();
  static DeviceTier _detected = DeviceTier.mid;
  static PerfMode _mode = PerfMode.auto;

  /// Değişim bildirimi (ayar ekranı ve önbellek tavanı dinler).
  static final ValueNotifier<DeviceTier> tier =
      ValueNotifier<DeviceTier>(DeviceTier.mid);

  static DeviceInfo get info => _info;
  static DeviceTier get detected => _detected;
  static PerfMode get mode => _mode;
  static PerfBudget get budget => PerfBudget(tier.value);

  /// Yerelden cihaz bilgisini okur. Kanal yoksa sessizce orta profil.
  static Future<void> load(PerfMode mode) async {
    _mode = mode;
    try {
      final map =
          await _ch.invokeMethod<Map<Object?, Object?>>('deviceClass');
      _info = DeviceInfo.fromMap(map);
    } on MissingPluginException {
      _info = const DeviceInfo();
    } catch (_) {
      // Bilgi yoksa orta profil: eski davranışa en yakın güvenli seçim.
      _info = const DeviceInfo();
    }
    _detected = classifyDevice(_info);
    tier.value = effectiveTier(_mode, _detected);
  }

  static void setMode(PerfMode mode) {
    _mode = mode;
    tier.value = effectiveTier(_mode, _detected);
  }

  @visibleForTesting
  static void debugOverride(DeviceTier value, {PerfMode mode = PerfMode.auto}) {
    _mode = mode;
    _detected = value;
    tier.value = effectiveTier(mode, value);
  }
}
