import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_extras.dart';

/// Akıllı düzen turunun neden başlamadığı ya da yarıda durduğu (hata değil).
enum SmartHold {
  /// "Yalnız Wi-Fi'de" açık ve bağlantı ölçülü (mobil veri, paylaşılan ağ)
  /// ya da türü okunamadı.
  wifi,

  /// Bugünkü istek üst sınırı doldu.
  cap,
}

/// Bir günün sayımı: düzen isteği ve kota (HTTP 429) yanıtı.
class SmartQuotaDay {
  final String day;
  final int requests;
  final int limited;
  const SmartQuotaDay(this.day, this.requests, this.limited);

  String encode() => '$day,$requests,$limited';

  static SmartQuotaDay? decode(String raw) {
    final parts = raw.split(',');
    if (parts.length != 3) return null;
    final r = int.tryParse(parts[1]);
    final l = int.tryParse(parts[2]);
    if (r == null || l == null || r < 0 || l < 0) return null;
    return SmartQuotaDay(parts[0], r, l);
  }
}

/// **Akıllı düzen hız/kota** (PLAN §1.1 m.5, 2026-11-19).
///
/// * Her tur isteği sayılır; ücretsiz kota yanıtı (429) ayrıca sayılır.
///   Son [historyDays] günün sayımı saklanır (Akıllı düzen ekranında
///   görünür; varsayılan üst sınırın doğru olup olmadığı buradan ölçülür).
/// * **Günlük üst sınır** ([dailyCap], varsayılan [defaultCap]): dolunca tur
///   başlamaz/durur, kalanlar ertesi gün. Tek dosya ("AI ile ikinci ad")
///   kullanıcının açık isteği — sayılmaz, durdurulmaz.
/// * **Yalnız Wi-Fi'de** ([wifiOnly], varsayılan AÇIK — en güvenli: büyük
///   ses/video yüklemesi mobil veriyi yemesin; sabah bakılacak): bağlantı
///   ölçülüyse ya da türü okunamazsa tur başlamaz.
///
/// Gün yerel tarihe göre döner. Yazma beklenmez (en iyi çaba).
abstract final class SmartQuota {
  static const prefCap = 'smart_sort_cap';
  static const prefWifi = 'smart_sort_wifi';
  static const prefLog = 'smart_sort_quota_log';

  /// Seçilebilir günlük sınırlar.
  static const capChoices = [50, 100, 200, 500, 1000];
  static const defaultCap = 200;
  static const historyDays = 7;

  static int _cap = defaultCap;
  static bool _wifiOnly = true;
  static bool _read = false;
  static String _day = '';
  static int _requests = 0;
  static int _limited = 0;
  static final List<SmartQuotaDay> _history = [];

  /// Sayım ya da ayar değişince artar (arayüz dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Bugünün tarihi (testte sabitlenir).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Bağlantı ölçülü mü (mobil veri)? null = okunamadı (testte sahte).
  @visibleForTesting
  static Future<bool?> Function() metered = NativeExtras.isMetered;

  static int get dailyCap => _cap;
  static bool get wifiOnly => _wifiOnly;

  static String _today() {
    final d = now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Gün döndüyse dünkü sayım geçmişe geçer.
  static void _roll() {
    final t = _today();
    if (t == _day) return;
    if (_day.isNotEmpty && (_requests > 0 || _limited > 0)) {
      _history.insert(0, SmartQuotaDay(_day, _requests, _limited));
      if (_history.length > historyDays - 1) {
        _history.removeRange(historyDays - 1, _history.length);
      }
    }
    _day = t;
    _requests = 0;
    _limited = 0;
  }

  static Future<void> read() async {
    if (_read) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cap = prefs.getInt(prefCap);
      if (cap != null && capChoices.contains(cap)) _cap = cap;
      _wifiOnly = prefs.getBool(prefWifi) ?? true;
      final log = prefs.getStringList(prefLog) ?? const [];
      final days = [
        for (final raw in log) ?SmartQuotaDay.decode(raw),
      ];
      if (days.isNotEmpty) {
        _day = days.first.day;
        _requests = days.first.requests;
        _limited = days.first.limited;
        _history
          ..clear()
          ..addAll(days.skip(1).take(historyDays - 1));
      }
    } catch (_) {
      // Bilinçli: okunamazsa varsayılanlar (200/gün, yalnız Wi-Fi).
    }
    _read = true;
    _roll();
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefCap, _cap);
      await prefs.setBool(prefWifi, _wifiOnly);
      await prefs.setStringList(prefLog, [
        for (final d in days) d.encode(),
      ]);
    } catch (_) {
      // Bilinçli: yazılamazsa sayım yalnız bu oturumda.
    }
  }

  static void _changed() {
    revision.value++;
    unawaited(_save());
  }

  static Future<void> setSettings({int? cap, bool? wifiOnly}) async {
    await read();
    if (cap != null && capChoices.contains(cap)) _cap = cap;
    if (wifiOnly != null) _wifiOnly = wifiOnly;
    _changed();
  }

  /// Bugün yapılan istek.
  static int get usedToday {
    _roll();
    return _requests;
  }

  /// Bugün gelen kota (429) yanıtı.
  static int get limitedToday {
    _roll();
    return _limited;
  }

  static int get remaining => (_cap - usedToday).clamp(0, _cap);

  /// Bugün dahil son günler, en yeni önce (boş günler yok; bugün hep var).
  static List<SmartQuotaDay> get days {
    _roll();
    return [SmartQuotaDay(_day, _requests, _limited), ..._history];
  }

  /// Bir istek hakkı alır (sayar); sınır dolduysa false.
  static bool take() {
    _roll();
    if (_requests >= _cap) return false;
    _requests++;
    _changed();
    return true;
  }

  /// Kota (429) yanıtı geldi.
  static void noteLimited() {
    _roll();
    _limited++;
    _changed();
  }

  /// Tur başlayabilir mi? null = evet; değilse neden.
  static Future<SmartHold?> check() async {
    await read();
    if (remaining <= 0) return SmartHold.cap;
    if (_wifiOnly) {
      bool? m;
      try {
        m = await metered();
      } catch (_) {
        m = null;
      }
      // Bilinçli: türü okunamayan bağlantı ölçülü sayılır (en güvenli).
      if (m != false) return SmartHold.wifi;
    }
    return null;
  }

  @visibleForTesting
  static void debugReset() {
    _cap = defaultCap;
    _wifiOnly = true;
    _read = false;
    _day = '';
    _requests = 0;
    _limited = 0;
    _history.clear();
    now = DateTime.now;
    metered = NativeExtras.isMetered;
  }
}
