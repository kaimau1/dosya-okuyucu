/// Belgelerde seçilebilen yazı tipleri — **tek kaynak**.
///
/// Word, Excel, slayt ve metin görüntüleyici aynı listeyi kullanır; eskiden
/// her ekranın kendi listesi vardı ve kullanıcı Excel'de bulduğu yazı tipini
/// slaytta hiç bulamıyordu (slaytta yazı tipi seçimi zaten YOKTU).
///
/// ## Ad ≠ çizilen font
/// Uygulamada üç aile GÖMÜLÜ (bkz. `pubspec.yaml`): Carlito (≈ Calibri),
/// Arimo (≈ Arial/Helvetica) ve Tinos (≈ Times New Roman). Android'de Arial,
/// Georgia, Verdana gibi adlar KURULU DEĞİLDİR — o adla çizmeye kalkmak
/// sessizce Roboto'ya düşerdi ve kullanıcı "seçtim ama değişmedi" derdi.
///
/// Bu yüzden her seçeneğin iki yüzü var:
/// - [name]: **dosyaya yazılan** ad. Belge Word/Excel/PowerPoint'te açıldığında
///   gerçek Arial/Georgia ile görünsün diye özgün ad korunur.
/// - [render]: **ekranda çizilen** gömülü aile (metrikçe en yakını).
class DocFont {
  final String name;
  final String render;

  const DocFont(this.name, this.render);
}

/// Sıra bilinçli: en sık kullanılan üç ofis yazı tipi başta.
const List<DocFont> kDocFonts = [
  DocFont('Calibri', 'Carlito'),
  DocFont('Arial', 'Arimo'),
  DocFont('Times New Roman', 'Tinos'),
  DocFont('Helvetica', 'Arimo'),
  DocFont('Verdana', 'Arimo'),
  DocFont('Tahoma', 'Arimo'),
  DocFont('Segoe UI', 'Arimo'),
  DocFont('Georgia', 'Tinos'),
  DocFont('Cambria', 'Tinos'),
  DocFont('Garamond', 'Tinos'),
  DocFont('Book Antiqua', 'Tinos'),
  DocFont('Courier New', 'monospace'),
  DocFont('Consolas', 'monospace'),
];

/// Punto kademeleri — Word/Excel/slayt aynı listeyi gösterir.
const List<double> kDocFontSizes = [
  8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 54, 66, 72, 88,
];

/// Verilen ada karşılık **çizilecek** aile. Bilinmeyen ad (belgeden gelen
/// üçüncü taraf bir font) adın kendisiyle denenir: cihazda varsa çizilir,
/// yoksa Flutter zaten varsayılana düşer.
String? renderFamilyFor(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final needle = name.trim().toLowerCase();
  for (final f in kDocFonts) {
    if (f.name.toLowerCase() == needle) return f.render;
  }
  return name;
}
