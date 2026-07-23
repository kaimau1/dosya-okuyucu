/// Paragraf metnine madde/numara önekleri (saf Dart, test edilebilir).
///
/// *Niye:* gerçek Word listesi `numbering.xml` gerektirir ve yerelde
/// PowerPoint/Word'de doğrulanamadığından bozulma riski taşır (bkz. HAFIZA
/// araştırma kararı). Bunun yerine uygulamanın mevcut "literal önek"
/// felsefesi kullanılır: madde `• `, numara `N. ` düz metin olarak eklenir →
/// üretilen .docx her zaman geçerli kalır.
library;

const String _bullet = '• ';
final RegExp _numberRe = RegExp(r'^(\d+)\.\s+');

/// Paragraf madde işaretiyle mi başlıyor?
bool hasBullet(String text) => text.startsWith(_bullet);

/// Paragraf `N. ` numara önekiyle mi başlıyor?
bool hasNumber(String text) => _numberRe.hasMatch(text);

/// Baştaki madde/numara önekini (varsa) kaldırır.
String stripListPrefix(String text) {
  if (hasBullet(text)) return text.substring(_bullet.length);
  final m = _numberRe.firstMatch(text);
  if (m != null) return text.substring(m.end);
  return text;
}

/// Madde işaretini açar/kapatır (varsa kaldırır, yoksa ekler).
String toggleBullet(String text) =>
    hasBullet(text) ? stripListPrefix(text) : '$_bullet${stripListPrefix(text)}';

/// Numara önekini açar/kapatır; açarken [number] kullanılır.
String toggleNumber(String text, int number) => hasNumber(text)
    ? stripListPrefix(text)
    : '$number. ${stripListPrefix(text)}';
