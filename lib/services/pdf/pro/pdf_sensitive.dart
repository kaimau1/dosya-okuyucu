/// **Kişisel veri desenleri** (PDF Pro Faz 64 / 2 — KVKK): metinde TC kimlik
/// numarası (sağlama algoritmalı), IBAN (mod 97), telefon, e-posta ve
/// kullanıcının verdiği sözcükler aranır. Saf Dart; bulunanlar karartma
/// önerisi olur (önizle → onayla), hiçbir şey kendiliğinden silinmez.
library;

enum PdfSensitiveKind { tckn, iban, phone, email, custom }

class PdfSensitiveMatch {
  final PdfSensitiveKind kind;

  /// Metindeki UTF-16 aralığı.
  final int start, end;
  const PdfSensitiveMatch(this.kind, this.start, this.end);
}

abstract final class PdfSensitive {
  /// TC kimlik no doğrulaması: 11 hane, ilk hane 0 değil; 10. hane
  /// ((1,3,5,7,9. haneler toplamı × 7) − (2,4,6,8. haneler toplamı)) mod 10,
  /// 11. hane ilk on hanenin toplamı mod 10.
  static bool validTckn(String digits) {
    if (digits.length != 11 || digits[0] == '0') return false;
    final d = [for (final c in digits.codeUnits) c - 0x30];
    if (d.any((x) => x < 0 || x > 9)) return false;
    final odd = d[0] + d[2] + d[4] + d[6] + d[8];
    final even = d[1] + d[3] + d[5] + d[7];
    if (((odd * 7 - even) % 10 + 10) % 10 != d[9]) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += d[i];
    }
    return sum % 10 == d[10];
  }

  /// IBAN doğrulaması (ISO 13616, mod 97 = 1). Boşluklar yok sayılır.
  static bool validIban(String raw) {
    final s = raw.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (s.length < 15 || s.length > 34) return false;
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(s)) return false;
    if (s.startsWith('TR') && s.length != 26) return false;
    final moved = s.substring(4) + s.substring(0, 4);
    var rem = 0;
    for (final c in moved.codeUnits) {
      final v = c >= 0x41 ? c - 55 : c - 0x30;
      rem = v > 9 ? (rem * 100 + v) % 97 : (rem * 10 + v) % 97;
    }
    return rem == 1;
  }

  static final _tckn = RegExp(r'(?<!\d)[1-9]\d{10}(?!\d)');
  static final _iban =
      RegExp(r'\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,4})?\b');
  static final _phone = RegExp(
      r'(?<![\d+])(?:\+90[\s.-]?|0)?\(?[2-5]\d{2}\)?[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}(?!\d)');
  static final _email =
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+');

  /// [text]'teki eşleşmeler (başlangıca göre sıralı, örtüşmesiz).
  static List<PdfSensitiveMatch> find(
    String text, {
    Set<PdfSensitiveKind> kinds = const {
      PdfSensitiveKind.tckn,
      PdfSensitiveKind.iban,
      PdfSensitiveKind.phone,
      PdfSensitiveKind.email,
    },
    List<String> custom = const [],
  }) {
    final out = <PdfSensitiveMatch>[];
    void add(PdfSensitiveKind k, int a, int b) {
      if (out.any((m) => a < m.end && b > m.start)) return;
      out.add(PdfSensitiveMatch(k, a, b));
    }

    if (kinds.contains(PdfSensitiveKind.iban)) {
      for (final m in _iban.allMatches(text)) {
        if (validIban(m.group(0)!)) add(PdfSensitiveKind.iban, m.start, m.end);
      }
    }
    if (kinds.contains(PdfSensitiveKind.tckn)) {
      for (final m in _tckn.allMatches(text)) {
        if (validTckn(m.group(0)!)) add(PdfSensitiveKind.tckn, m.start, m.end);
      }
    }
    if (kinds.contains(PdfSensitiveKind.email)) {
      for (final m in _email.allMatches(text)) {
        add(PdfSensitiveKind.email, m.start, m.end);
      }
    }
    if (kinds.contains(PdfSensitiveKind.phone)) {
      for (final m in _phone.allMatches(text)) {
        final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10 && digits.length <= 12) {
          add(PdfSensitiveKind.phone, m.start, m.end);
        }
      }
    }
    final lower = text.toLowerCase();
    for (final w in custom) {
      final q = w.trim().toLowerCase();
      if (q.length < 2) continue;
      var at = lower.indexOf(q);
      while (at >= 0) {
        add(PdfSensitiveKind.custom, at, at + q.length);
        at = lower.indexOf(q, at + q.length);
      }
    }
    return out..sort((a, b) => a.start.compareTo(b.start));
  }
}
