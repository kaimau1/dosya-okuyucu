import 'package:shared_preferences/shared_preferences.dart';

/// **Hassas veri maskesi** (Güvenlik G10.2, 2026-11-12).
///
/// Yapay zekâya giden metinde TC kimlik no, IBAN, kart no, cep telefonu ve
/// e-posta yer tutucuyla değiştirilir: `[TC]`, `[IBAN]`, `[KART]`, `[TEL]`,
/// `[EPOSTA]`. Yanlış alarmı az tutmak için sağlamalar denetlenir (TC
/// algoritması, IBAN mod 97, kart Luhn) — sıradan uzun sayı (ölçüm, sipariş
/// no) maskelenmez.
///
/// Günlük temizleyicisi (`LogScrub`) AYRI kalır: o her uzun sayıyı ve yolu
/// siler (tanı raporunda içerik gerekmez); burada belge anlamı korunmalı.
abstract final class Pii {
  static final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  // TR IBAN: TR + 24 hane, 4'lü boşluklu da yazılır.
  static final _iban = RegExp(r'\bTR\d{2}(?:[ ]?\d{4}){5}[ ]?\d{2}\b',
      caseSensitive: false);
  // 13–19 hane, boşluk/tire ile gruplu olabilir.
  static final _card = RegExp(r'(?<![\d-])\d(?:[ -]?\d){12,18}(?![\d-])');
  static final _tc = RegExp(r'(?<!\d)[1-9]\d{10}(?!\d)');
  // Türkiye cep: +90 / 0 / 90 önekli ya da öneksiz 5xx xxx xx xx.
  static final _phone = RegExp(
      r'(?<![\d+])(?:\+?90[ -]?|0)?\(?5\d{2}\)?[ -]?\d{3}[ -]?\d{2}[ -]?\d{2}(?!\d)');

  /// [s]'deki hassas parçaları maskeler.
  static String mask(String s) {
    if (s.isEmpty) return s;
    var out = s.replaceAll(_email, '[EPOSTA]');
    out = out.replaceAllMapped(
        _iban, (m) => ibanValid(m[0]!) ? '[IBAN]' : m[0]!);
    out = out.replaceAllMapped(_card, (m) {
      final digits = m[0]!.replaceAll(RegExp(r'[ -]'), '');
      // 11 haneli TC aşağıda; kart 13+ hane.
      return luhnValid(digits) ? '[KART]' : m[0]!;
    });
    out = out.replaceAllMapped(_tc, (m) => tcValid(m[0]!) ? '[TC]' : m[0]!);
    out = out.replaceAll(_phone, '[TEL]');
    return out;
  }

  /// TC kimlik no sağlaması (10. ve 11. hane).
  static bool tcValid(String s) {
    if (s.length != 11 || s[0] == '0') return false;
    final d = [for (final c in s.codeUnits) c - 48];
    if (d.any((x) => x < 0 || x > 9)) return false;
    final odd = d[0] + d[2] + d[4] + d[6] + d[8];
    final even = d[1] + d[3] + d[5] + d[7];
    final d10 = ((odd * 7 - even) % 10 + 10) % 10;
    if (d10 != d[9]) return false;
    final sum = d.sublist(0, 10).fold<int>(0, (a, b) => a + b);
    return sum % 10 == d[10];
  }

  static bool luhnValid(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;
    var sum = 0;
    var dbl = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 48;
      if (n < 0 || n > 9) return false;
      if (dbl) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      dbl = !dbl;
    }
    return sum % 10 == 0;
  }

  /// IBAN mod 97 = 1 (ISO 13616).
  static bool ibanValid(String raw) {
    final s = raw.replaceAll(' ', '').toUpperCase();
    if (s.length < 15) return false;
    final r = s.substring(4) + s.substring(0, 4);
    var rem = 0;
    for (final c in r.codeUnits) {
      final v = c >= 65 && c <= 90 ? '${c - 55}' : String.fromCharCode(c);
      for (final ch in v.codeUnits) {
        final n = ch - 48;
        if (n < 0 || n > 9) return false;
        rem = (rem * 10 + n) % 97;
      }
    }
    return rem == 1;
  }
}

/// Maskenin açık/kapalı ayarı (`ai_pii_mask`, varsayılan AÇIK).
abstract final class PiiMaskSetting {
  static const key = 'ai_pii_mask';

  static Future<bool> enabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? true;
    } catch (_) {
      return true; // Bilinçli: okunamazsa güvenli taraf — maskele.
    }
  }

  static Future<void> set(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, on);
  }
}

/// İstek gövdesindeki (Gemini JSON) her `text` alanını maskeler; görsel
/// verisi (`inlineData`) dokunulmaz. JSON değilse metin olduğu gibi döner.
Object? maskJsonTexts(Object? node) {
  if (node is Map) {
    return {
      for (final e in node.entries)
        e.key: e.key == 'text' && e.value is String
            ? Pii.mask(e.value as String)
            : maskJsonTexts(e.value),
    };
  }
  if (node is List) return [for (final v in node) maskJsonTexts(v)];
  return node;
}
