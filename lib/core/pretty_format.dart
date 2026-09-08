import 'dart:convert';

/// **JSON / XML güzelleştirme** — tek satırlık bir dosyayı okunabilir yapar.
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulama `.json` ve `.xml` dosyalarını açıyor ama bu dosyalar gerçek
/// hayatta **tek satır** olarak geliyor: bir API cevabı, bir yedek dosyası,
/// bir `AndroidManifest` dökümü. Ekranda tek bir upuzun satır görünüyor ve
/// kullanıcının yapabileceği hiçbir şey yoktu — okumak için bilgisayara
/// taşımak gerekiyordu.
///
/// Biçimlendirme **görüntüleme kolaylığı**, dosyayı değiştirmek değil:
/// düzenleyicide metin değişiyor, kullanıcı isterse kaydediyor. Kaydetmezse
/// dosya olduğu gibi kalıyor.
abstract final class PrettyFormat {
  /// Bu uzantı güzelleştirilebilir mi?
  static bool supports(String extension) {
    final ext = extension.replaceFirst('.', '').toLowerCase();
    return ext == 'json' || ext == 'xml' || ext == 'svg' || ext == 'plist';
  }

  /// Metni biçimlendirir. Çözümlenemezse **metin aynen döner** — bozuk bir
  /// JSON'u "düzeltmeye" çalışmak, kullanıcının veri kaybetmesi demek olurdu.
  static String pretty(String text, String extension) {
    final ext = extension.replaceFirst('.', '').toLowerCase();
    if (ext == 'json') return json(text);
    return xml(text);
  }

  /// İki boşluk girintili JSON.
  static String json(String text) {
    try {
      final decoded = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return text;
    }
  }

  /// Etiketleri satırlara ayırıp girintileyen basit XML biçimlendirici.
  ///
  /// **Kendi ayrıştırıcımız, `xml` paketi değil:** paket ayrıştırma
  /// başarısız olunca fırlatıyor ve gerçek dosyaların bir kısmı (eksik
  /// kapanış, birden çok kök, HTML parçası) geçerli XML değil. Buradaki
  /// yaklaşım metinsel: `<` ile başlayan her parçayı bir satıra koyup
  /// derinliğe göre girintiliyor. Bozuk dosyada da okunur bir sonuç veriyor.
  static String xml(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('<')) return text;
    final out = StringBuffer();
    var depth = 0;
    var i = 0;
    while (i < trimmed.length) {
      final open = trimmed.indexOf('<', i);
      if (open == -1) {
        final tail = trimmed.substring(i).trim();
        if (tail.isNotEmpty) out.writeln('${'  ' * depth}$tail');
        break;
      }
      // Etiketten önceki metin (düğüm içeriği) aynı satırda kalır.
      final between = trimmed.substring(i, open).trim();
      if (between.isNotEmpty) out.writeln('${'  ' * depth}$between');
      final close = trimmed.indexOf('>', open);
      if (close == -1) {
        out.writeln('${'  ' * depth}${trimmed.substring(open).trim()}');
        break;
      }
      final tag = trimmed.substring(open, close + 1);
      final isClosing = tag.startsWith('</');
      final isSelfClosing = tag.endsWith('/>') ||
          tag.startsWith('<?') ||
          tag.startsWith('<!');
      if (isClosing && depth > 0) depth--;
      out.writeln('${'  ' * depth}$tag');
      if (!isClosing && !isSelfClosing) depth++;
      i = close + 1;
    }
    return out.toString().trimRight();
  }
}
