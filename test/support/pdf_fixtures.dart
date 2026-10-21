import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Örnek PDF seti** (Faz 8 — `docs/FAZ_PLANI.md` §Faz 8 madde 6).
///
/// İkili dosya yerine KOD: her örnek burada belirlenimci (deterministik)
/// olarak kurulur. Böylece (a) depo şişmez, (b) bir örneğin NE taşıdığı
/// okunabilir (CropBox kaydırması kaç nokta, hangi glif adı hangi koda),
/// (c) yeni bir tuzak çıkınca örnek bir satırla genişler.
/// `tool/write_pdf_fixtures_test.dart` bunları `test/fixtures/pdf/` altına
/// yazar — telefonda elle denemek için.
///
/// Elle kurulan belgeler gerçek üreticilerin yapısını taklit eder: tek
/// baytlık TrueType font, `/Widths` tablosu, `/Encoding /Differences` ile
/// Türkçe harfler (EBYS çıktılarındaki gibi; `/ToUnicode` YOK — AGL yolu).
abstract final class PdfFixtures {
  /// Fontun `/Differences` dizisi: CP1254'teki Türkçe harfler glif ADIYLA.
  static const _differences =
      '[ 208 /Gbreve 221 /Idotaccent /Scedilla 240 /gbreve 253 /dotlessi '
      '/scedilla ]';

  /// Harf → tek baytlık kod (WinAnsi + yukarıdaki farklar).
  static int _code(String ch) {
    const turkish = {
      'Ğ': 208,
      'İ': 221,
      'Ş': 222,
      'ğ': 240,
      'ı': 253,
      'ş': 254,
    };
    final t = turkish[ch];
    if (t != null) return t;
    final c = ch.codeUnitAt(0);
    if (c < 256) return c;
    throw ArgumentError('Örnek fontta yok: $ch');
  }

  /// Metni içerik akışına hex dize olarak yazar (`<...>`).
  static String _hex(String text) {
    final b = StringBuffer('<');
    for (final ch in text.split('')) {
      b.write(_code(ch).toRadixString(16).padLeft(2, '0'));
    }
    b.write('>');
    return b.toString();
  }

  /// Bir sayfanın içerik akışı: her satır ayrı paragraf (araları geniş).
  static String textContent(List<String> lines,
      {double x = 50, double top = 540, double size = 12}) {
    final b = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final y = top - i * size * 4;
      b.write('BT /F1 $size Tf 1 0 0 1 $x $y Tm ${_hex(lines[i])} Tj ET\n');
    }
    return b.toString();
  }

  /// Elle kurulan PDF: [pages] her sayfanın içerik akışı.
  ///
  /// [cropBox] verilirse her sayfaya yazılır (`[sol alt sağ üst]`);
  /// [rotate] `/Rotate` değeri; [image] true ise sayfalar 1×1 gri bir
  /// görseli tam sayfa çizer (taranmış sayfa taklidi).
  static List<int> hand(
    List<String> pages, {
    String mediaBox = '[0 0 400 600]',
    String? cropBox,
    int rotate = 0,
    bool image = false,
  }) {
    final out = BytesBuilder();
    final offsets = <int, int>{};
    void add(int number, List<int> body) {
      offsets[number] = out.length;
      out
        ..add(latin1.encode('$number 0 obj\n'))
        ..add(body)
        ..add(latin1.encode('\nendobj\n'));
    }

    List<int> s(String v) => latin1.encode(v);
    List<int> stream(String dict, List<int> data) => [
          ...s('<< $dict /Length ${data.length} >>\nstream\n'),
          ...data,
          ...s('\nendstream'),
        ];

    // 1 katalog, 2 sayfalar, 3 font, 4 kodlama, 5 görsel; sayfa i → 6+2i,
    // içeriği 7+2i.
    final kids = [for (var i = 0; i < pages.length; i++) '${6 + 2 * i} 0 R'];
    final widths = List.filled(224, '500').join(' ');
    out.add(s('%PDF-1.4\n'));
    add(1, s('<< /Type /Catalog /Pages 2 0 R >>'));
    add(2,
        s('<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>'));
    add(
        3,
        s('<< /Type /Font /Subtype /TrueType /BaseFont /Arial '
            '/FirstChar 32 /LastChar 255 /Widths [$widths] '
            '/Encoding 4 0 R >>'));
    add(
        4,
        s('<< /Type /Encoding /BaseEncoding /WinAnsiEncoding '
            '/Differences $_differences >>'));
    add(
        5,
        stream(
            '/Type /XObject /Subtype /Image /Width 1 /Height 1 '
            '/ColorSpace /DeviceGray /BitsPerComponent 8',
            [200]));
    for (var i = 0; i < pages.length; i++) {
      final crop = cropBox == null ? '' : ' /CropBox $cropBox';
      final rot = rotate == 0 ? '' : ' /Rotate $rotate';
      add(
          6 + 2 * i,
          s('<< /Type /Page /Parent 2 0 R /MediaBox $mediaBox$crop$rot '
              '/Resources << /Font << /F1 3 0 R >> '
              '/XObject << /Im1 5 0 R >> >> /Contents ${7 + 2 * i} 0 R >>'));
      final body = image
          ? 'q 400 0 0 600 0 0 cm /Im1 Do Q\n${pages[i]}'
          : pages[i];
      add(7 + 2 * i, stream('', s(body)));
    }

    final count = 6 + 2 * pages.length;
    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n0 $count\n0000000000 65535 f \n');
    for (var i = 1; i < count; i++) {
      xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    xref
      ..write('trailer\n<< /Size $count /Root 1 0 R >>\n')
      ..write('startxref\n$xrefOffset\n%%EOF\n');
    out.add(s(xref.toString()));
    return out.takeBytes();
  }

  // ── Adlandırılmış örnekler ────────────────────────────────────────────────

  static List<int> textual() => hand([
        textContent(['Genel Rapor 2026', 'Toplam tutar 1500 TL']),
      ]);

  static List<int> turkish() => hand([
        textContent(['İstanbul Şube Müdürlüğü', 'Ağaç ışık çiçek']),
      ]);

  /// Metin katmanı olmayan, yalnız görsel taşıyan sayfa.
  static List<int> scanned() => hand([''], image: true);

  static List<int> rotated(int degrees) => hand(
        [
          textContent(['Yatay sayfa metni'])
        ],
        rotate: degrees,
      );

  /// CropBox MediaBox'tan 40/60 nokta kaydırılmış (kırpılmış tarama çıktısı).
  static List<int> cropped() => hand(
        [
          textContent(['Kirpilmis sayfa'], x: 80, top: 500)
        ],
        mediaBox: '[0 0 400 600]',
        cropBox: '[40 60 360 560]',
      );

  static List<int> long({int pages = 320}) => hand([
        for (var i = 1; i <= pages; i++) textContent(['Sayfa $i metni']),
      ]);

  /// Kullanıcı parolalı (açarken parola soran) belge.
  static Future<List<int>> passwordProtected(String password) async {
    final doc = PdfDocument(inputBytes: textual());
    try {
      doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..userPassword = password
        ..ownerPassword = '$password-sahip';
      doc.fileStructure.incrementalUpdate = false;
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  /// İki metin alanı ve bir onay kutusu taşıyan form.
  static Future<List<int>> form() async {
    final doc = PdfDocument();
    try {
      final page = doc.pages.add();
      doc.form.fields
        ..add(PdfTextBoxField(page, 'ad', const Rect.fromLTWH(40, 40, 200, 24)))
        ..add(PdfTextBoxField(
            page, 'sehir', const Rect.fromLTWH(40, 80, 200, 24)))
        ..add(PdfCheckBoxField(
            page, 'onay', const Rect.fromLTWH(40, 120, 16, 16)));
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }
}

/// Syncfusion ile sayfa metni (yeniden açma doğrulaması — bizim
/// ayrıştırıcımızdan BAĞIMSIZ ikinci bir okuyucu).
String extractText(List<int> pdf, {int? page, String? password}) {
  final doc = PdfDocument(inputBytes: pdf, password: password);
  try {
    final ex = PdfTextExtractor(doc);
    return page == null
        ? ex.extractText()
        : ex.extractText(startPageIndex: page, endPageIndex: page);
  } finally {
    doc.dispose();
  }
}

int pageCountOf(List<int> pdf, {String? password}) {
  final doc = PdfDocument(inputBytes: pdf, password: password);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

/// Sayfanın satırları ve kutuları (Syncfusion; sol-üst kökenli, nokta).
List<TextLine> extractTextLines(List<int> pdf, {int page = 0}) {
  final doc = PdfDocument(inputBytes: pdf);
  try {
    return PdfTextExtractor(doc)
        .extractTextLines(startPageIndex: page, endPageIndex: page);
  } finally {
    doc.dispose();
  }
}
