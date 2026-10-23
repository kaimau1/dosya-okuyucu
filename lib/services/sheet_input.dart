/// Hücreye yazılan metnin **akıllı girişi** (Faz 25 / madde 11, 2026-10-23).
///
/// Türkçe yerel ayarda Excel yazılanı yorumlar: `1.234,56` sayıdır, `%15`
/// yüzde biçimli 0,15'tir, `₺100` / `100 TL` para biçimlidir, `23.10.2026`
/// tarihtir, `14:30` saattir. Model hücrede HAM değeri tutar (`1234.56`,
/// tarih için Excel seri numarası) — biçim ayrı katmanda. Eskiden bunların
/// hepsi metin olarak kalıyor, formüllerde `#DEĞER!` veriyordu.
library;

/// Yorumun sonucu.
class SmartInput {
  /// Modele yazılacak ham değer.
  final String raw;

  /// Hücre biçimi General iken verilecek sayı biçimi (null = dokunma).
  final String? numberFormat;

  /// Kullanıcıya söylenecek bir şey (i18n anahtarı) — ör. `1/2` tarihe
  /// çevrilmedi.
  final String? noteKey;

  const SmartInput(this.raw, {this.numberFormat, this.noteKey});
}

const _monthsTr = {
  'oca': 1, 'şub': 2, 'sub': 2, 'mar': 3, 'nis': 4, 'may': 5, 'haz': 6,
  'tem': 7, 'ağu': 8, 'agu': 8, 'eyl': 9, 'eki': 10, 'kas': 11, 'ara': 12,
};

/// [text]'i yorumlar. [turkish]: Türkçe yerel ayar (ondalık `,`, binlik `.`).
/// Formül (`=`), boş metin ve baştaki sıfırı önemli diziler (`007`) olduğu
/// gibi kalır.
SmartInput parseSmartInput(String text, {bool turkish = true, DateTime? today}) {
  final t = text.trim();
  if (t.isEmpty || t.startsWith('=') || t.startsWith("'")) {
    return SmartInput(text);
  }
  // Baştaki sıfır: kod/numara (posta kodu, telefon) — metin kalır.
  if (RegExp(r'^0\d+$').hasMatch(t)) return SmartInput(text);

  String num(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    return v.toString();
  }

  double? number(String s) {
    var x = s.replaceAll(' ', '').replaceAll(' ', '');
    if (x.isEmpty) return null;
    if (turkish) {
      // 1.234.567,89 · 1234,5 · 1.234 (binlik) · 1.5 (İngilizce de kabul)
      if (RegExp(r'^[-+]?\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(x)) {
        x = x.replaceAll('.', '').replaceAll(',', '.');
      } else if (RegExp(r'^[-+]?\d+,\d+$').hasMatch(x)) {
        x = x.replaceAll(',', '.');
      } else if (!RegExp(r'^[-+]?\d+(\.\d+)?([eE][-+]?\d+)?$').hasMatch(x)) {
        return null;
      }
    } else {
      x = x.replaceAll(',', '');
      if (!RegExp(r'^[-+]?\d+(\.\d+)?([eE][-+]?\d+)?$').hasMatch(x)) return null;
    }
    return double.tryParse(x);
  }

  // Yüzde: %15 · 15% · %12,5
  final pm = RegExp(r'^(%\s*([-+]?[\d.,]+)|([-+]?[\d.,]+)\s*%)$').firstMatch(t);
  if (pm != null) {
    final v = number(pm.group(2) ?? pm.group(3)!);
    if (v != null) {
      final decimals = (pm.group(2) ?? pm.group(3)!).contains(RegExp('[.,]'));
      return SmartInput(num(v / 100), numberFormat: decimals ? '0.00%' : '0%');
    }
  }
  // Para: ₺100 · 100 ₺ · 100 TL · 1.250,50 TL
  final cm = RegExp(r'^(₺\s*([-+]?[\d.,]+)|([-+]?[\d.,]+)\s*(₺|TL|tl))$')
      .firstMatch(t);
  if (cm != null) {
    final v = number(cm.group(2) ?? cm.group(3)!);
    if (v != null) {
      return SmartInput(num(v), numberFormat: r'#,##0.00\ ₺');
    }
  }
  // Saat: 14:30 · 9:05:30
  final tm = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(t);
  if (tm != null) {
    final h = int.parse(tm.group(1)!), m = int.parse(tm.group(2)!);
    final sec = int.tryParse(tm.group(3) ?? '') ?? 0;
    if (h < 24 && m < 60 && sec < 60) {
      final frac = (h * 3600 + m * 60 + sec) / 86400;
      return SmartInput(_trimNum(frac),
          numberFormat: tm.group(3) == null ? 'hh:mm' : 'hh:mm:ss');
    }
  }
  // Tarih: 23.10.2026 · 23.10.26 · 23/10/2026 · 23 Eki (2026)
  final dm = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})$').firstMatch(t);
  if (dm != null) {
    var y = int.parse(dm.group(3)!);
    if (y < 100) y += y < 30 ? 2000 : 1900;
    final serial = _serial(y, int.parse(dm.group(2)!), int.parse(dm.group(1)!));
    if (serial != null) return SmartInput('$serial', numberFormat: 'dd.mm.yyyy');
  }
  final dn = RegExp(r'^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]{3,})\.?(?:\s+(\d{4}))?$')
      .firstMatch(t);
  if (dn != null) {
    final mon = _monthsTr[dn.group(2)!.toLowerCase().substring(0, 3)];
    if (mon != null) {
      final y = int.tryParse(dn.group(3) ?? '') ?? (today ?? DateTime.now()).year;
      final serial = _serial(y, mon, int.parse(dn.group(1)!));
      if (serial != null) {
        return SmartInput('$serial',
            numberFormat: dn.group(3) == null ? 'd mmm' : 'dd.mm.yyyy');
      }
    }
  }
  // 1/2 gibi kesir yazımı: Excel bunu SESSİZCE tarihe çevirir (1 Şubat) —
  // biz metin bırakıp söyleriz.
  if (RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(t)) {
    return SmartInput(text, noteKey: 'excel.input_kept_text');
  }
  final n = number(t);
  if (n != null) {
    // 1.234 Türkçe'de bin iki yüz otuz dörttür — binlik ayırıcılı yazım
    // binlik biçimini de alır.
    final grouped = turkish && t.contains('.') && RegExp(r'\d\.\d{3}').hasMatch(t);
    return SmartInput(num(n),
        numberFormat: grouped ? (t.contains(',') ? '#,##0.00' : '#,##0') : null);
  }
  return SmartInput(text);
}

String _trimNum(double v) {
  final s = v.toStringAsFixed(10);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Excel 1900 tarih seri numarası (1 = 1900-01-01; 1900 artık yıl hatası
/// dahil — Excel'le aynı sayı).
int? _serial(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime.utc(y, m, d);
  if (date.month != m || date.day != d) return null;
  final base = DateTime.utc(1899, 12, 30);
  return date.difference(base).inDays;
}
