import 'package:flutter/widgets.dart';

/// Hücre metinlerinin **gerçek ölçüsü** — Excel'in iki temel davranışı bunu
/// bilmeden taklit edilemez:
///
/// * **Taşma:** kaydırılmayan metin, sağındaki (ya da hizalamaya göre
///   solundaki) hücreler boşsa onların üstüne sarkar. Sarkma miktarı metnin
///   sütundan ne kadar taştığıdır.
/// * **Otomatik satır yüksekliği:** metin kaydırma açıkken satır, sarılan
///   satır sayısı kadar yükselir.
///
/// Ölçüm `TextPainter` ile yapılır — yani ekranda çizilecek yazı tipiyle
/// birebir aynı sonuç. Karakter sayısından tahmin etmek (`uzunluk × ortalama
/// genişlik`) Türkçe metinde ve kalın/italik kesitlerde tutarsız: "İĞÜŞÇÖ" ile
/// "illlli" aynı karakter sayısında bambaşka genişliktedir.
///
/// **Önbellek şart:** aynı metin her karede yeniden ölçülürse kaydırma
/// takılır. Anahtar metin + ölçü taşıyan stil; sınır aşılınca önbellek
/// tamamen boşaltılır (LRU tutmak bu boyutta kazandırdığından çok karmaşıklık
/// getirir).
class SheetTextMeasure {
  final Map<String, double> _widths = {};
  final Map<String, double> _heights = {};

  /// Önbellekte tutulacak en çok kayıt (her iki tablo için ayrı).
  static const int limit = 4000;

  /// [text]in tek satırdaki genişliği (px), verilen stille.
  double widthOf(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final key = _key(text, style);
    final hit = _widths[key];
    if (hit != null) return hit;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final value = painter.width;
    painter.dispose();
    if (_widths.length >= limit) _widths.clear();
    _widths[key] = value;
    return value;
  }

  /// [text]in [maxWidth] genişliğinde **sarıldığında** kapladığı yükseklik
  /// (px). Satır sonu karakterleri de hesaba katılır.
  double heightOf(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty || maxWidth <= 0) return 0;
    final key = '${maxWidth.round()}|${_key(text, style)}';
    final hit = _heights[key];
    if (hit != null) return hit;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final value = painter.height;
    painter.dispose();
    if (_heights.length >= limit) _heights.clear();
    _heights[key] = value;
    return value;
  }

  void clear() {
    _widths.clear();
    _heights.clear();
  }

  /// Anahtar yalnız **ölçüyü etkileyen** alanlardan kurulur; renk değişince
  /// yeniden ölçmek boşuna olurdu.
  static String _key(String text, TextStyle style) =>
      '${style.fontSize}|${style.fontWeight?.index}|${style.fontStyle?.index}|'
      '${style.fontFamily}|${style.height}|$text';
}
