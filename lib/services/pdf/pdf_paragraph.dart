/// **Paragraf bazlı** PDF metin düzenleme: sayfadaki paragrafları bulur,
/// düzenlenebilir düz metin verir ve düzenlenmiş metni belgenin KENDİ yazı
/// tipi/punto/konumuyla yeniden dizer.
///
/// Niye kelime değil paragraf (2026-07-27 kullanıcı kararı):
/// Kelime bazlı değiştirme metni içerik akışında ARAMAK zorundaydı; PDF
/// üreticileri bir cümleyi kerning yüzünden onlarca parçaya böldüğü ve kodlama
/// tahmin edildiği için gerçek belgelerin çoğunda "bulunamadı" diyordu.
/// Paragraf birimi aramayı tamamen kaldırıyor: kullanıcı sayfada bir yere
/// dokunuyor, o noktadaki paragrafın hangi operatörler olduğunu koordinattan
/// biliyoruz, o baytları komple yeniden yazıyoruz. Daha az kod, daha az
/// başarısızlık noktası — ve satır sarma (Word'deki gibi akış) doğal olarak
/// geliyor, çünkü paragrafı zaten baştan diziyoruz.
///
/// Korunan şeyler: yazı tipi, punto, renk, satır aralığı, sol/sağ kenar,
/// iki yana yaslama ve sayfanın geri kalanı (bayt bayt — paragrafın dışına
/// HİÇ dokunulmaz).
///
/// Korunmayan tek şey: düzenlenen paragrafın satır içi kerning ayarları
/// yeniden hesaplanır. Metin zaten değiştiği için özgün harf aralığı korunamaz.
library;

import 'pdf_font_map.dart';
import 'pdf_font_metrics.dart';
import 'pdf_syntax.dart';

/// Paragraf işlemi yapılamadı — mesaj doğrudan kullanıcıya gösterilebilir.
class PdfParagraphRefused implements Exception {
  final String message;
  const PdfParagraphRefused(this.message);
  @override
  String toString() => message;
}

/// Sayfanın font kaynaklarına erişim: kodlama (kod ↔ harf) + glif genişlikleri.
///
/// İkisi birden şart: kodlama olmadan yeni metni belgenin özgün yazı tipiyle
/// YAZAMAYIZ, genişlik olmadan satırı nerede saracağımızı ÖLÇEMEYİZ.
class PdfFontAccess {
  final Map<String, PdfFontEncoding> encodings;
  final Map<String, PdfFontMetrics> metrics;

  const PdfFontAccess({this.encodings = const {}, this.metrics = const {}});

  /// Ham baytları metne çevirir (tablo yoksa [PdfFontEncoding.fallback]).
  String decode(String? font, List<int> bytes) =>
      encodings[font]?.decode(bytes) ??
      PdfFontEncoding.fallback.decode(bytes);

  /// Metni fontun kodlarına çevirir; tek harf bile karşılanamıyorsa null.
  ///
  /// TUZAK (test yakaladı): `encodings[font]?.encode(text) ?? latin1(...)`
  /// yazılamaz. `?.` ile `??` birlikte "font tablosu YOK" ile "tablo var ama
  /// bu harf İÇİNDE yok" durumlarını birbirine karıştırır ve ikincisinde
  /// sessizce Latin-1'e düşer — belgeye yanlış glif yazılır. Fontun kendi
  /// tablosu varsa cevabı yalnız o verir.
  List<int>? encode(String? font, String text) {
    final encoding = encodings[font];
    if (encoding != null) return encoding.encode(text);
    return PdfFontEncoding.fallback.encode(text);
  }

  int codeBytes(String? font) => encodings[font]?.codeBytes ?? 1;

  /// [text]'in glif genişliği (1/1000 em) ve sayımları; ölçülemiyorsa null.
  PdfGlyphRun? measure(String? font, String text) {
    final bytes = encode(font, text);
    if (bytes == null) return null;
    return measureBytes(font, bytes);
  }

  PdfGlyphRun? measureBytes(String? font, List<int> bytes) {
    final table = metrics[font];
    if (table == null) return null;
    final width = codeBytes(font);
    if (width <= 0 || bytes.length % width != 0) return null;
    final codes = <int>[];
    var spaces = 0;
    for (var i = 0; i + width <= bytes.length; i += width) {
      var code = 0;
      for (var b = 0; b < width; b++) {
        code = (code << 8) | bytes[i + b];
      }
      codes.add(code);
      if (width == 1 && code == 32) spaces++;
    }
    final total = table.widthOfCodes(codes);
    if (total == null) return null;
    return PdfGlyphRun(
        width1000: total, glyphCount: codes.length, spaceCount: spaces);
  }

  /// [PdfContentScan] için ölçüm geri çağırımı.
  PdfMeasure get asMeasure => measureBytes;
}

/// Aynı biçimle (font + punto + renk + metin durumu) yazılmış bitişik metin.
///
/// Biçim koşusu tutmanın sebebi: kullanıcı paragrafın ortasındaki bir kelimeyi
/// değiştirdiğinde DOKUNMADIĞI kısımlar kendi biçimini korumalı. Paragrafı tek
/// fontla yeniden yazsaydık ortadaki kalın kelime düz olurdu.
class PdfParagraphRun {
  final String text;
  final String? fontName;
  final double fontSize;

  /// Metin matrisinin ölçek bileşenleri (`Tm`'in a ve d'si).
  ///
  /// **Niye ŞART (kullanıcı bulgusu 2026-09-01: "yazı puntosu tutmadı…
  /// ufacık yazdı"):** ekrandaki punto `Tf`nin sayısı DEĞİL, `Tf × Tm ölçeği`.
  /// HTML→PDF üreticilerinin (e-Nabız, e-Devlet çıktıları, fatura sistemleri)
  /// çoğu `/F1 1 Tf` yazıp puntoyu tamamen `Tm`e koyar. Ölçeği taşımayan eski
  /// kod bütün koşuları "1 punto" sanıyor, paragrafı tek ölçekte (ilk satırın
  /// ölçeğinde) yeniden yazıyordu: 9 puntoluk bir hücreye 6 puntoluk komşusunun
  /// ölçeği uygulanınca yazı küçülüyordu.
  final double scaleX;
  final double scaleY;

  /// O an geçerli renk operatörünün HAM baytları (`1 0 0 rg` gibi). Boşsa
  /// paragrafın başındaki renk geçerlidir ve yeniden yazmaya gerek yoktur.
  final List<int> colorBytes;

  /// Aralık/ölçek durumu — ölçüm bunlara bağlı, yeniden dizerken de gerekli.
  final PdfTextState state;

  const PdfParagraphRun({
    required this.text,
    required this.fontName,
    required this.fontSize,
    required this.colorBytes,
    required this.state,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  /// **Görünen** punto (sayfa birimi): `Tf` puntosu × matris ölçeği.
  double get sizeY => fontSize * scaleY.abs();

  /// Yatay em genişliği (sayfa birimi) — kelime arası eşiği bununla ölçülür.
  double get sizeX => fontSize * scaleX.abs();

  PdfParagraphRun withText(String value) => PdfParagraphRun(
        text: value,
        fontName: fontName,
        fontSize: fontSize,
        colorBytes: colorBytes,
        state: state,
        scaleX: scaleX,
        scaleY: scaleY,
      );

  /// Biçim aynı mı? (Metin hariç.)
  bool sameStyleAs(PdfParagraphRun other) =>
      fontName == other.fontName &&
      (fontSize - other.fontSize).abs() < 1e-6 &&
      (scaleX - other.scaleX).abs() < 1e-6 &&
      (scaleY - other.scaleY).abs() < 1e-6 &&
      _sameBytes(colorBytes, other.colorBytes) &&
      (state.charSpacing - other.state.charSpacing).abs() < 1e-6 &&
      (state.wordSpacing - other.state.wordSpacing).abs() < 1e-6 &&
      (state.horizScale - other.state.horizScale).abs() < 1e-6;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Paragrafın bir satırı (özgün belgedeki hâli).
class PdfParagraphLine {
  /// Satırın ilk metin operatörünün matrisi. `[a b c d e f]`.
  final List<double> matrix;

  /// Satırın sol ve sağ kenarı (matris e-uzayında, yani sayfa yatay ekseni).
  final double startX;
  final double endX;

  /// Taban çizgisi (matris f bileşeni).
  final double baselineY;

  final double fontSize;

  /// Bu satırdaki metin operatörlerinin [PdfContentScan.textOps] indeksleri.
  final List<int> opIndexes;

  const PdfParagraphLine({
    required this.matrix,
    required this.startX,
    required this.endX,
    required this.baselineY,
    required this.fontSize,
    required this.opIndexes,
  });

  /// **Görünen** punto: `Tf` puntosu × matris dikey ölçeği (bkz.
  /// [PdfParagraphRun.sizeY] — aynı tuzak).
  double get sizeY => fontSize * (matrix.length > 3 ? matrix[3].abs() : 1);
}

/// Sayfada bulunmuş bir paragraf.
class PdfParagraph {
  /// Paragrafın kaçıncı içerik akışında olduğu (sayfa birden çok akışa
  /// bölünmüş olabilir).
  final int streamIndex;

  /// İçerik akışında paragrafın kapladığı bayt aralığı — yeniden yazarken
  /// tam olarak burası değiştirilir, dışına dokunulmaz.
  final int spanStart;
  final int spanEnd;

  final List<PdfParagraphLine> lines;

  /// Biçim koşuları (satırlar arası kesintisiz akar).
  final List<PdfParagraphRun> runs;

  /// Düzenlenebilir düz metin (koşuların birleşimi).
  final String text;

  /// Metnin her karakterinin hangi koşuya ait olduğu (uzunluğu = text.length).
  final List<int> runOfChar;

  /// Sayfa (kullanıcı) uzayında sınırlar — dokunulan noktayı paragrafa
  /// eşlemek için.
  final double left;
  final double right;
  final double top;
  final double bottom;

  /// Ölçülmüş satır aralığı (tek satırlıysa punto × 1.2).
  final double leading;

  /// İki yana yaslı mı? (Son satır hariç bütün satırlar sağ kenarda bitiyor.)
  final bool justified;

  /// Sayfaya ORTALI mı? (Kutusunun ortası sayfa ortasıyla çakışıyor ve
  /// paragraf sayfa genişliğinin küçük bir kısmını kaplıyor.)
  ///
  /// Niye gerek: yeniden dizerken sola yaslı düzen varsayılırsa ortalı bir
  /// başlık kısalınca sol kenarı sabit kalıp sağa büzülür — ortası kayar
  /// (kullanıcı bildirimi 2026-07-28: "yazı sayfaya ortalıydı, değiştirince
  /// ortalı kalmadı").
  final bool centered;

  /// Ortalı paragrafın ortalanacağı X (metin uzayı) — özgün kutusunun ortası.
  final double centerX;

  /// Sayfadaki metin sütununun genişliği (metin uzayı). Ortalı paragraf
  /// uzarsa buraya kadar sarılır; kendi dar kutusuna sıkıştırılmaz.
  final double columnWidth;

  /// Paragrafın satırlarını saran `q`/`Q` blokları birleştirilebilir mi?
  ///
  /// `Q` grafik durumunu — dönüşüm VE kırpma — geri alır. Farklı `cm`
  /// altındaki satırlar zaten aynı paragrafa girmiyor; geriye kırpma kalıyor:
  /// kırpmalı bir bloğu komşusuyla birleştirmek yazının bir kısmını kestirir,
  /// o yüzden kırpma varsa false ve aralıktaki `q`/`Q` reddedilir.
  final bool uniformGraphics;

  /// Gövde satırlarının sol kenarı ve ilk satırın sol kenarı (girinti/asılı
  /// girinti korunsun diye ayrı tutulur).
  final double bodyLeftX;
  final double firstLineX;

  /// Sağ kenar (satırların ulaştığı en sağ nokta) — sarma sınırı.
  final double rightX;

  /// Paragrafın hemen altındaki ilk içeriğe kalan dikey boşluk (metin uzayı).
  /// Satır sayısı artarsa buraya taşabiliriz; yetmezse işlem reddedilir.
  final double roomBelow;

  const PdfParagraph({
    required this.streamIndex,
    required this.spanStart,
    required this.spanEnd,
    required this.lines,
    required this.runs,
    required this.text,
    required this.runOfChar,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.leading,
    required this.justified,
    required this.centered,
    required this.centerX,
    required this.columnWidth,
    required this.uniformGraphics,
    required this.bodyLeftX,
    required this.firstLineX,
    required this.rightX,
    required this.roomBelow,
  });

  int get lineCount => lines.length;

  /// Sayfa uzayındaki bir nokta bu paragrafın içinde mi? [pad] dokunma payı.
  bool contains(double x, double y, {double pad = 2}) =>
      x >= left - pad && x <= right + pad && y >= bottom - pad && y <= top + pad;
}

/// Bir sayfadaki paragrafları bulur.
///
/// [contents] sayfanın içerik akışlarının ÇÖZÜLMÜŞ baytları (sırayla).
/// [pageBox] `[sol, alt, sağ, üst]` çizim kutusu — ortalı paragrafı tanımak
/// için gerekli; verilmezse hiçbir paragraf ortalı sayılmaz (eski davranış).
List<PdfParagraph> findParagraphs(
  List<List<int>> contents,
  PdfFontAccess fonts, {
  List<double>? pageBox,
}) {
  final out = <PdfParagraph>[];
  for (var s = 0; s < contents.length; s++) {
    out.addAll(_paragraphsInStream(contents[s], s, fonts, pageBox));
  }
  return out;
}

/// Satırların dikey/yatay eşleştirmesinde kullanılan paylar.
const _baselineTolerance = 0.35; // punto oranı — aynı satır sayılma payı
const _maxLineGapFactor = 2.2; // punto oranı — bundan büyük boşluk = yeni paragraf
const _leftEdgeTolerance = 0.6; // punto oranı — sol kenar hizası payı
const _wordGapEm = 0.18; // bundan büyük boşluk = kelime arası

List<PdfParagraph> _paragraphsInStream(
  List<int> content,
  int streamIndex,
  PdfFontAccess fonts,
  List<double>? pageBox,
) {
  final scan = scanContent(content, measure: fonts.asMeasure);
  if (scan.textOps.isEmpty) return const [];

  // Her metin operatörü için: sayfa uzayındaki konumu + o an geçerli renk.
  final infos = _describeOps(content, scan, fonts);
  final usable = [
    for (final info in infos)
      if (info.usable) info,
  ];
  if (usable.isEmpty) return const [];

  // 1) Aynı taban çizgisindekileri satıra topla.
  final lines = _groupIntoLines(usable);

  // 2) Bitişik satırları paragrafa topla.
  final groups = _groupIntoParagraphs(lines);

  final out = <PdfParagraph>[];
  for (final group in groups) {
    final paragraph = _buildParagraph(
      content: content,
      streamIndex: streamIndex,
      group: group,
      allLines: lines,
      fonts: fonts,
      pageBox: pageBox,
    );
    if (paragraph != null) out.add(paragraph);
  }
  return out;
}

/// Bir metin operatörünün yeniden dizmek için gereken bilgileri.
class _OpInfo {
  final PdfTextOp op;
  final int opIndex;
  final String text;
  final double startX;
  final double endX;
  final double baselineY;
  final List<int> colorBytes;

  /// O an geçerli dönüşüm matrisi (`cm` birikimi). Metin uzayı koordinatlarını
  /// sayfa koordinatına çevirmek için — dokunulan noktayı paragrafa eşlemek
  /// bunsuz yanlış çalışır (`cm` kullanan belgeler yaygın).
  final List<double> ctm;

  /// Çizim anında bir kırpma yolu (`W`/`W*`) geçerli miydi? Kırpmalı bir
  /// bloğu başkasıyla birleştirmek yazının bir kısmını kestirir.
  final bool clipped;

  /// Bu operatör güvenle yeniden dizilebilir mi? (Ölçülebilir, döndürülmemiş.)
  final bool usable;

  const _OpInfo({
    required this.op,
    required this.opIndex,
    required this.text,
    required this.startX,
    required this.endX,
    required this.baselineY,
    required this.colorBytes,
    required this.ctm,
    required this.clipped,
    required this.usable,
  });

  double get fontSize => op.state.fontSize;
  double get scaleX => op.matrix[0];
  double get scaleY => op.matrix[3];

  /// **Görünen** punto (sayfa birimi). Gruplama ve satır aralığı kararları
  /// bununla verilir; ham `Tf` puntosu tek başına yanıltıcıdır (bkz.
  /// [PdfParagraphRun.scaleX]).
  double get sizeY => fontSize * scaleY.abs();
  double get sizeX => fontSize * scaleX.abs();
}

/// Renk belirleyen operatörler — paragraf yeniden yazılırken koşuyla birlikte
/// taşınırlar, yoksa çok renkli bir paragraf tek renge düşerdi.
const _colorOps = {'g', 'rg', 'k', 'sc', 'scn', 'cs'};

List<_OpInfo> _describeOps(
    List<int> content, PdfContentScan scan, PdfFontAccess fonts) {
  // Olay sırasına göre son renk operatörünün baytları ve o an geçerli `cm`
  // dönüşümü (q/Q yığınıyla birlikte — `cm` yığından geri alınabilir).
  final colorAt = <int, List<int>>{};
  final ctmAt = <int, List<double>>{};
  final clipAt = <int, bool>{};
  var current = const <int>[];
  var ctm = <double>[1, 0, 0, 1, 0, 0];
  // Kırpma da grafik durumunun parçası: `q` ile yığına girer, `Q` ile kalkar.
  var clipped = false;
  final stack = <(List<double>, bool)>[];
  for (var e = 0; e < scan.events.length; e++) {
    final event = scan.events[e];
    switch (event.op) {
      case 'q':
        stack.add((List.of(ctm), clipped));
      case 'Q':
        if (stack.isNotEmpty) {
          final restored = stack.removeLast();
          ctm = restored.$1;
          clipped = restored.$2;
        }
      case 'cm':
        if (event.numbers.length >= 6) {
          ctm = multiplyMatrix(event.numbers.sublist(event.numbers.length - 6), ctm);
        }
      case 'W':
      case 'W*':
        clipped = true;
    }
    if (_colorOps.contains(event.op)) {
      current = content.sublist(event.operandStart, event.end);
    }
    colorAt[e] = current;
    ctmAt[e] = ctm;
    clipAt[e] = clipped;
  }

  final out = <_OpInfo>[];
  for (var i = 0; i < scan.textOps.length; i++) {
    final op = scan.textOps[i];
    final text = _textOfOp(op, fonts);
    final advance = advanceOf(op, op.allBytes, fonts.asMeasure);
    final usable = !op.event.isRotated &&
        op.xKnown &&
        advance != null &&
        op.state.fontSize > 0 &&
        op.matrix[0].abs() > 1e-9 &&
        op.matrix[3].abs() > 1e-9 &&
        text.trim().isNotEmpty;
    out.add(_OpInfo(
      op: op,
      opIndex: i,
      text: text,
      startX: op.matrix[4],
      endX: op.matrix[4] + (advance ?? 0) * op.matrix[0],
      baselineY: op.matrix[5],
      colorBytes: colorAt[op.eventIndex] ?? const [],
      ctm: ctmAt[op.eventIndex] ?? const [1, 0, 0, 1, 0, 0],
      clipped: clipAt[op.eventIndex] ?? false,
      usable: usable,
    ));
  }
  return out;
}

// Matris yardımcıları: `pdf_syntax.dart` (multiplyMatrix / applyMatrix).

/// Operatörün metni — `TJ` dizisindeki kerning boşlukları KELİME ARASI olarak
/// yorumlanır.
///
/// Niye şart: PDF'te iki kelime arasında çoğu zaman boşluk KARAKTERİ yoktur,
/// yerine `[(Merhaba) -250 (dünya)] TJ` gibi bir kaydırma sayısı bulunur.
/// Sayıyı yok sayarsak kullanıcıya "Merhabadünya" gösteririz.
String _textOfOp(PdfTextOp op, PdfFontAccess fonts) {
  final event = op.event;
  if (event.strings.isEmpty) return '';
  if (op.op != 'TJ' || event.numbers.isEmpty) {
    return fonts.decode(op.fontName, op.allBytes);
  }

  // Dizeleri ve sayıları BAYT SIRASINA göre iç içe geçir: tarayıcı ikisini
  // ayrı listelerde tutuyor, aradaki sıra ancak konumdan çıkar.
  final items = <(int, bool, int)>[]; // (bayt konumu, dize mi, indeks)
  for (var i = 0; i < event.strings.length; i++) {
    items.add((event.strings[i].start, true, i));
  }
  for (var i = 0; i < event.numberRanges.length; i++) {
    items.add((event.numberRanges[i][0], false, i));
  }
  items.sort((a, b) => a.$1.compareTo(b.$1));

  final buffer = StringBuffer();
  var pending = 0.0;
  for (final item in items) {
    if (!item.$2) {
      pending += event.numbers[item.$3];
      continue;
    }
    // Negatif kaydırma = sağa boşluk. Yeterince büyükse kelime arasıdır.
    if (buffer.isNotEmpty && -pending / 1000 >= _wordGapEm) {
      final s = buffer.toString();
      if (!s.endsWith(' ')) buffer.write(' ');
    }
    pending = 0;
    buffer.write(fonts.decode(op.fontName, event.strings[item.$3].bytes));
  }
  return buffer.toString();
}

/// Aynı taban çizgisindeki operatörleri satıra toplar (soldan sağa sıralı).
List<List<_OpInfo>> _groupIntoLines(List<_OpInfo> ops) {
  final sorted = [...ops]..sort((a, b) {
      final dy = b.baselineY.compareTo(a.baselineY); // yukarıdan aşağı
      return dy != 0 ? dy : a.startX.compareTo(b.startX);
    });

  final lines = <List<_OpInfo>>[];
  for (final op in sorted) {
    final last = lines.isEmpty ? null : lines.last;
    if (last != null) {
      final tolerance = last.first.sizeY * _baselineTolerance;
      if ((last.first.baselineY - op.baselineY).abs() <= tolerance) {
        last.add(op);
        continue;
      }
    }
    lines.add([op]);
  }
  for (final line in lines) {
    line.sort((a, b) => a.startX.compareTo(b.startX));
  }
  return lines;
}

/// Bitişik satırları paragrafa toplar.
///
/// Bir satır öncekiyle AYNI paragrafa girer ancak:
/// * dikey boşluk makul bir satır aralığıysa (çok büyükse yeni paragraf),
/// * yatay olarak ÖRTÜŞÜYORSA (yan sütun ya da tablo hücresi kaçsın diye),
/// * sol kenarı hizalıysa (ya da ilk satır girintisi/asılı girinti),
/// * aynı punto ise.
List<List<List<_OpInfo>>> _groupIntoParagraphs(List<List<_OpInfo>> lines) {
  final out = <List<List<_OpInfo>>>[];
  for (final line in lines) {
    if (out.isEmpty) {
      out.add([line]);
      continue;
    }
    final group = out.last;
    if (_continuesParagraph(group, line)) {
      group.add(line);
    } else {
      out.add([line]);
    }
  }
  return out;
}

bool _continuesParagraph(List<List<_OpInfo>> group, List<_OpInfo> line) {
  final previous = group.last;
  // Görünen punto (Tf × Tm ölçeği): `Tf 1` yazıp puntoyu matrise koyan
  // üreticilerde ham `Tf` puntosu her satırda 1'dir ve farklı boydaki
  // satırlar (tablo hücresi, dipnot) tek paragrafa girerdi.
  final fontSize = previous.first.sizeY;
  if ((line.first.sizeY - fontSize).abs() > 0.51) return false;

  // Farklı `cm` dönüşümü altındaki satırlar aynı koordinat uzayında değil;
  // tek paragraf sayılırlarsa hem sınırlar hem yeniden dizme yanlış olur.
  final a = previous.first.ctm;
  final b = line.first.ctm;
  for (var i = 0; i < 6; i++) {
    if ((a[i] - b[i]).abs() > 1e-6) return false;
  }

  final gap = previous.first.baselineY - line.first.baselineY;
  if (gap <= 0) return false;
  if (gap > fontSize * _maxLineGapFactor) return false;

  // Satır aralığı paragraf içinde tutarlı olmalı: ikinci satırdan sonra
  // aralığın birden büyümesi yeni paragrafın başladığını gösterir.
  if (group.length >= 2) {
    final previousGap =
        group[group.length - 2].first.baselineY - previous.first.baselineY;
    if (previousGap > 0 && (gap - previousGap).abs() > fontSize * 0.35) {
      return false;
    }
  }

  // Yatay örtüşme: iki sütunlu sayfada yan sütunun satırı buraya girmesin.
  final aLeft = _minStart(previous);
  final aRight = _maxEnd(previous);
  final bLeft = _minStart(line);
  final bRight = _maxEnd(line);
  final overlap =
      (aRight < bRight ? aRight : bRight) - (aLeft > bLeft ? aLeft : bLeft);
  if (overlap <= 0) return false;
  final narrower = (aRight - aLeft) < (bRight - bLeft)
      ? (aRight - aLeft)
      : (bRight - bLeft);
  if (narrower > 0 && overlap < narrower * 0.5) return false;

  // Sol kenar hizası: gövde satırları hizalı olmalı. İlk satır girintili
  // olabilir, o yüzden karşılaştırma ikinci satırdan itibaren sıkılaşır.
  final reference = group.length == 1 ? aLeft : _minStart(group[1]);
  if ((bLeft - reference).abs() > previous.first.sizeX * _leftEdgeTolerance) {
    // İlk satırdan sonraki ilk satır girinti/asılı girinti olabilir.
    if (group.length != 1) return false;
  }
  return true;
}

double _minStart(List<_OpInfo> line) =>
    line.map((o) => o.startX).reduce((a, b) => a < b ? a : b);

double _maxEnd(List<_OpInfo> line) =>
    line.map((o) => o.endX).reduce((a, b) => a > b ? a : b);

/// Sayfanın alt kenarında bırakılan pay (pt).
///
/// Sıfır yazılsaydı metin tam kâğıdın kenarına dayanabilirdi; yazıcıların
/// çoğu son 18 pt'yi zaten basmıyor.
const double _pageBottomMargin = 18;

PdfParagraph? _buildParagraph({
  required List<int> content,
  required int streamIndex,
  required List<List<_OpInfo>> group,
  required List<List<_OpInfo>> allLines,
  required PdfFontAccess fonts,
  required List<double>? pageBox,
}) {
  final flat = [for (final line in group) ...line];
  if (flat.isEmpty) return null;

  // Bayt aralığı: ilk operatörün operandlarından son operatörün sonuna.
  var spanStart = flat.first.op.operandStart;
  var spanEnd = flat.first.op.end;
  for (final info in flat) {
    if (info.op.operandStart < spanStart) spanStart = info.op.operandStart;
    if (info.op.end > spanEnd) spanEnd = info.op.end;
  }

  // Koşuları kur: satır satır, biçim değişince yeni koşu.
  final runs = <PdfParagraphRun>[];
  final buffer = StringBuffer();
  final runOfChar = <int>[];

  void push(String text, _OpInfo info) {
    if (text.isEmpty) return;
    final candidate = PdfParagraphRun(
      text: text,
      fontName: info.op.fontName,
      fontSize: info.fontSize,
      colorBytes: info.colorBytes,
      state: info.op.state,
      scaleX: info.scaleX,
      scaleY: info.scaleY,
    );
    if (runs.isNotEmpty && runs.last.sameStyleAs(candidate)) {
      runs[runs.length - 1] = runs.last.withText(runs.last.text + text);
    } else {
      runs.add(candidate);
    }
    for (var i = 0; i < text.length; i++) {
      runOfChar.add(runs.length - 1);
    }
    buffer.write(text);
  }

  for (var l = 0; l < group.length; l++) {
    final line = group[l];
    if (l > 0) push(' ', line.first); // satır sonu = kelime arası
    for (var o = 0; o < line.length; o++) {
      final info = line[o];
      if (o > 0) {
        // Aynı satırda iki operatör arası boşluk kelime arası mı?
        final gap = info.startX - line[o - 1].endX;
        final threshold = info.sizeX * _wordGapEm;
        final already = buffer.toString().endsWith(' ');
        if (!already && gap > threshold) push(' ', info);
      }
      push(info.text, info);
    }
  }

  final text = buffer.toString();
  if (text.trim().isEmpty) return null;

  final lines = <PdfParagraphLine>[
    for (final line in group)
      PdfParagraphLine(
        matrix: List.of(line.first.op.matrix),
        startX: _minStart(line),
        endX: _maxEnd(line),
        baselineY: line.first.baselineY,
        fontSize: line.first.fontSize,
        opIndexes: [for (final o in line) o.opIndex],
      ),
  ];

  // Satır aralığı: ölçülmüş gerçek değer (TL operatörüne güvenmiyoruz —
  // üreticiler çoğu zaman satırı mutlak Tm ile koyar, TL'yi hiç yazmaz).
  var leading = lines.first.sizeY * 1.2;
  if (lines.length >= 2) {
    var total = 0.0;
    for (var i = 1; i < lines.length; i++) {
      total += lines[i - 1].baselineY - lines[i].baselineY;
    }
    leading = total / (lines.length - 1);
  }

  final firstLineX = lines.first.startX;
  final bodyLeftX = lines.length >= 2
      ? lines.skip(1).map((l) => l.startX).reduce((a, b) => a < b ? a : b)
      : firstLineX;
  final rightX = lines.map((l) => l.endX).reduce((a, b) => a > b ? a : b);

  // İki yana yaslı mı? Son satır hariç hepsi sağ kenarda bitiyorsa evet.
  var justified = false;
  if (lines.length >= 2) {
    final width = rightX - bodyLeftX;
    justified = width > 0 &&
        lines
            .take(lines.length - 1)
            .every((l) => (rightX - l.endX).abs() <= width * 0.02);
  }

  // Altta ne kadar yer var? Paragrafın altındaki EN YAKIN satırın tepesine
  // kadar. Satır sayısı artarsa buraya taşabiliriz; yetmezse reddedilir.
  final bottomBaseline = lines.last.baselineY;
  var nextTop = double.negativeInfinity;
  for (final other in allLines) {
    final y = other.first.baselineY;
    if (y >= bottomBaseline - 1e-6) continue;
    if (group.any((l) => identical(l, other))) continue;
    final top = y + other.first.sizeY * 0.75;
    if (top > nextTop) nextTop = top;
  }
  // **Sayfanın SON paragrafında da sınır var** (2026-08-30 bulgusu,
  // 2026-09-04'te kapandı): altında başka satır yoksa eskiden
  // `double.infinity` veriliyordu ve paragraf uzayınca (çeviri özgününden
  // %20 uzun olabiliyor) yazı sayfa kenarının ALTINA taşıyor, hiçbir uyarı
  // çıkmıyordu. Sınır artık çizim kutusunun ALT kenarı; kutu bilinmiyorsa
  // (eski çağıranlar) eski davranış korunuyor.
  final floorY = pageBox != null && pageBox.length >= 4
      ? pageBox[1] + _pageBottomMargin
      : double.negativeInfinity;
  final limitY = nextTop > floorY ? nextTop : floorY;
  final roomBelow = limitY == double.negativeInfinity
      ? double.infinity
      : (bottomBaseline - lines.last.sizeY * 0.25) - limitY;

  // Aralıktaki `q`/`Q` çiftlerinin silinebilmesinin ön koşulu. Aynı dönüşüm
  // koşulunu burada TEKRAR aramıyoruz: farklı `cm` altındaki satırlar zaten
  // aynı paragrafa girmiyor (`_continuesParagraph`). Geriye kırpma kalıyor —
  // kırpmalı bir bloğu komşusuyla birleştirmek yazıyı kestirir.
  final uniformGraphics = flat.every((o) => !o.clipped);

  final ascent = lines.first.sizeY * 0.85;
  final descent = lines.last.sizeY * 0.25;

  // Sınırlar SAYFA uzayında olmalı (dokunma eşlemesi için); düzen hesapları
  // ise metin uzayında kalır. Dört köşeyi de çevirip en küçük/en büyüğü almak,
  // döndürülmüş bir `cm` altında da doğru kutuyu verir.
  final ctm = flat.first.ctm;
  final textLeft = lines.map((l) => l.startX).reduce((a, b) => a < b ? a : b);
  final textTop = lines.first.baselineY + ascent;
  final textBottom = lines.last.baselineY - descent;
  final corners = [
    applyMatrix(ctm, textLeft, textBottom),
    applyMatrix(ctm, rightX, textBottom),
    applyMatrix(ctm, textLeft, textTop),
    applyMatrix(ctm, rightX, textTop),
  ];
  final xs = corners.map((c) => c.$1);
  final ys = corners.map((c) => c.$2);
  final pageLeft = xs.reduce((a, b) => a < b ? a : b);
  final pageRight = xs.reduce((a, b) => a > b ? a : b);

  // ORTALI MI? Sayfa uzayında kutusunun ortası sayfanın ortasıyla çakışıyor
  // ve paragraf sayfanın küçük bir kısmını kaplıyorsa evet.
  //
  // Genişlik koşulu şart: sayfayı baştan sona dolduran sıradan bir gövde
  // paragrafının ortası da tanım gereği sayfa ortasına denk gelir — onu
  // ortalı sayarsak sol kenarını bozardık. İki yana yaslı olan zaten hariç.
  var centered = false;
  if (pageBox != null && pageBox.length >= 4 && !justified) {
    final pageW = pageBox[2] - pageBox[0];
    final pageCenter = (pageBox[0] + pageBox[2]) / 2;
    centered = pageW > 0 &&
        (pageRight - pageLeft) <= pageW * 0.7 &&
        (((pageLeft + pageRight) / 2) - pageCenter).abs() <= pageW * 0.02;
  }

  // Sayfadaki metin sütunu (metin uzayı): ortalı paragraf uzarsa buraya kadar
  // sarılır. Kendi dar kutusuna sarsaydık kısa bir başlık uzayınca alt alta
  // birkaç kelimelik satırlara bölünürdü.
  var columnLeft = textLeft;
  var columnRight = rightX;
  for (final other in allLines) {
    final s = _minStart(other);
    final e = _maxEnd(other);
    if (s < columnLeft) columnLeft = s;
    if (e > columnRight) columnRight = e;
  }

  return PdfParagraph(
    streamIndex: streamIndex,
    spanStart: spanStart,
    spanEnd: spanEnd,
    lines: lines,
    runs: runs,
    text: text,
    runOfChar: runOfChar,
    left: pageLeft,
    right: pageRight,
    top: ys.reduce((a, b) => a > b ? a : b),
    bottom: ys.reduce((a, b) => a < b ? a : b),
    leading: leading,
    justified: justified,
    centered: centered,
    centerX: (textLeft + rightX) / 2,
    columnWidth: columnRight - columnLeft,
    uniformGraphics: uniformGraphics,
    bodyLeftX: bodyLeftX,
    firstLineX: firstLineX,
    rightX: rightX,
    roomBelow: roomBelow < 0 ? 0 : roomBelow,
  );
}
