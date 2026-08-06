/// PDF seciminden PANOYA giden metni temizler (kullanici bulgusu 2026-08-06:
/// "kopyalayip yapistirinca arada anlamsiz bir karakter cikti" ve
/// "Fizik / Muayene iki satir olmus, tek satira duzeltilmeli").
///
/// pdfium'un `fullText`'i satir sonlarini CR+LF olarak verir ve eslemesi
/// olmayan glifler icin U+FFFE gibi gorunmez karakterler birakabilir. Bunlar
/// panoya aynen kopyalaninca hedef uygulamada "tofu" kutulari ve istenmeyen
/// satir kirilmalari gorunuyordu.
///
/// Kurallar:
/// * CR+LF / CR once LF olur; TEK satir sonu bosluga cevrilir (PDF'teki
///   satir kirilmasi gorsel kaygidir, metnin parcasi degildir); 2+ ardisik
///   satir sonu paragraf sayilir ve TEK satir sonu olarak korunur.
/// * Kontrol ve gorunmez karakterler (C0/C1, soft hyphen, sifir genislikli
///   bosluklar, BOM, yon isaretleri, U+FFFD..U+FFFF) atilir.
/// * Satir sonunda tireyle bolunmus kelime birlestirilir: "muaye-" + satir
///   sonu + "ne" -> "muayene" (yalniz iki taraf da harfse ve devam kucuk
///   harfle basliyorsa -- "Is-Kur" gibi gercek tireli adlar bozulmaz).
/// * Bosluk kosulari teke iner, satir basi/sonu kirpilir.
///
/// YALNIZ pano/paylasim yolunda kullanilir -- secim katmaninin ham metni
/// (yerinde duzenlemenin gecis eslestirmesi icin) oldugu gibi kalir.
String cleanPdfCopyText(String raw) {
  if (raw.isEmpty) return raw;
  var s =
      raw.replaceAll('\u000D\u000A', '\u000A').replaceAll('\u000D', '\u000A');

  // Gorunmez/kontrol karakterleri (satir sonu haric). U+FFFE pdfium'un
  // "unicode karsiligi yok" isaretidir -- kullanicinin gordugu tofu buydu.
  s = s.replaceAll(_invisible, '');
  s = s.replaceAll('\u00A0', ' '); // kirilmaz bosluk -> normal bosluk

  // Tireyle bolunmus kelimeyi birlestir (satir sonu bosluga donmeden ONCE).
  s = s.replaceAllMapped(
    RegExp(r'(\p{L})-\n(\p{Ll})', unicode: true),
    (m) => '${m[1]}${m[2]}',
  );

  // Paragraf sinirini (2+ satir sonu) koru, tek satir sonunu bosluk yap.
  // U+0001 guvenli ayrac: kontrol karakterleri yukarida zaten atildi.
  s = s.replaceAll(RegExp(r'\n[ \t]*\n[\n \t]*'), '\u0001');
  s = s.replaceAll('\u000A', ' ');
  s = s.replaceAll('\u0001', '\u000A');

  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  return s.split('\u000A').map((line) => line.trim()).join('\u000A').trim();
}

/// Panoya gitmemesi gereken karakterler: C0 kontrolleri (satir sonu haric),
/// DEL+C1, soft hyphen, sifir genislikli bosluk/birlestiriciler ve yon
/// isaretleri, kelime birlestirici, BOM, interlinear ekleri ve Unicode'un
/// "karakter degil" noktalari (U+FFFD dahil -- bozuk glifin tofusu).
final RegExp _invisible = RegExp(
  '['
  '\u0000-\u0008\u000B\u000C\u000E-\u001F' // C0 (satir sonu haric)
  '\u007F-\u009F' // DEL + C1
  '\u00AD' // soft hyphen
  '\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F'
  '\uFEFF\uFFF9-\uFFFB\uFFFD-\uFFFF'
  ']',
);
