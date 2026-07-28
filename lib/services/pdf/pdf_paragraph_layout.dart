/// Düzenlenmiş paragraf metnini **yeniden dizer** ve içerik akışına yazar.
///
/// Word'de yazarken satırın akması budur; PDF'te kendiliğinden olmaz. Metin
/// mutlak koordinatlarla çizildiği için bir kelime uzayınca ya da kısalınca
/// satırın kalanı yerinde kalır — üstüne biner ya da arada boşluk kalır.
/// Burada paragrafın TAMAMI belgenin kendi glif genişlikleriyle ölçülüp
/// yeniden sarılıyor: font, punto, renk, satır aralığı, sol/sağ kenar ve iki
/// yana yaslama korunur.
library;

import 'pdf_paragraph.dart';
import 'pdf_syntax.dart';

/// Paragrafın kapladığı bayt aralığında bulunmasına izin verilen operatörler.
///
/// Niye allowlist (ve niye reddediyoruz): aralığı komple yeniden yazıyoruz.
/// İçinde `q`/`Q` (grafik durumu yığını), `cm` (dönüşüm), `Do` (görsel) ya da
/// bir yol operatörü varsa onu silmek akışı DENGESİZ bırakır ve belge bozulur.
/// Anlamadığımız bir şey varsa yazmaktansa reddetmek.
const _allowedInSpan = {
  // Metin gösterme
  'Tj', 'TJ', "'", '"',
  // Konumlandırma
  'Td', 'TD', 'Tm', 'T*',
  // Metin durumu
  'Tf', 'Tc', 'Tw', 'Tz', 'TL', 'Ts', 'Tr',
  // Renk / grafik durumu (yeniden yazarken koşularla taşınır)
  'g', 'rg', 'k', 'sc', 'scn', 'cs', 'G', 'RG', 'K', 'CS', 'SC', 'SCN', 'gs',
};

/// Bir çıktı satırındaki tek biçimli metin parçası.
class _Segment {
  final PdfParagraphRun run;
  final String text;

  /// Metin uzayındaki ilerleyişi (ölçülmüş).
  final double advance;

  const _Segment(this.run, this.text, this.advance);
}

/// Bir kelime: bir ya da birden çok biçim parçası.
class _Word {
  final List<_Segment> segments;
  const _Word(this.segments);

  double get advance =>
      segments.fold<double>(0, (sum, s) => sum + s.advance);

  PdfParagraphRun get firstRun => segments.first.run;
}

/// Dizilmiş bir çıktı satırı.
class _LaidLine {
  final List<_Word> words;

  /// Kelimeler arası boşluğun ilerleyişi (yaslama burada büyür).
  final double spaceAdvance;

  final double startX;

  const _LaidLine(this.words, this.spaceAdvance, this.startX);
}

/// [paragraph]'ın metnini [newText] ile değiştirip içerik akışını döndürür.
///
/// Paragrafın DIŞINDAKİ baytlara dokunulmaz. Yapılamıyorsa açıklamalı bir
/// [PdfParagraphRefused] atar — çağıran mesajı doğrudan kullanıcıya gösterir.
List<int> rewriteParagraph({
  required List<int> content,
  required PdfParagraph paragraph,
  required String newText,
  required PdfFontAccess fonts,
}) {
  if (newText.trim().isEmpty) {
    throw const PdfParagraphRefused(
        'Paragraf boş bırakılamaz. Silmek için nesne silme aracını kullanın.');
  }

  _checkSpan(content, paragraph);

  final matrix = paragraph.lines.first.matrix;
  final scaleX = matrix[0];
  if (scaleX <= 0) {
    throw const PdfParagraphRefused(
        'Bu paragrafın metin matrisi alışılmadık (aynalanmış ya da sıfır '
        'ölçekli). Yeniden dizmek yazıyı bozardı.');
  }

  final runs = paragraph.runs;
  if (runs.any((r) => r.fontName == null)) {
    throw const PdfParagraphRefused(
        'Paragrafın yazı tipi kaynağı belirsiz; yeniden yazmak yazı tipini '
        'değiştirirdi.');
  }

  // 1) Hangi harf hangi biçimi alacak? Dokunulmayan kısımlar kendi biçimini
  //    korur (bkz. [_mapRuns]).
  final runOfChar = _mapRuns(paragraph.text, paragraph.runOfChar, newText);

  // 2) Kelimelere böl ve ölç.
  final words = _splitWords(newText, runOfChar, runs, fonts);
  if (words.isEmpty) {
    throw const PdfParagraphRefused('Paragraf boş bırakılamaz.');
  }

  // 3) Satırlara sar.
  final spaceAdvance = _spaceAdvance(runs.first, fonts);
  final laid = _wrap(
    words: words,
    paragraph: paragraph,
    scaleX: scaleX,
    spaceAdvance: spaceAdvance,
  );

  // 4) Satır sayısı arttıysa altta yer var mı?
  final extra = laid.length - paragraph.lineCount;
  if (extra > 0) {
    final needed = extra * paragraph.leading;
    if (needed > paragraph.roomBelow) {
      final fits = (paragraph.roomBelow / paragraph.leading).floor();
      final missing = extra - (fits < 0 ? 0 : fits);
      throw PdfParagraphRefused(
        'Metin sayfaya sığmıyor: $missing satır fazla geliyor ve altta yer '
        'yok. Sayfa düzenini bozmamak için değişiklik yapılmadı — metni biraz '
        'kısaltıp yeniden deneyin.',
      );
    }
  }

  // 5) Operatörleri üret ve aralığı değiştir.
  final generated = _emit(
    laid: laid,
    paragraph: paragraph,
    matrix: matrix,
    fonts: fonts,
  );

  final out = List<int>.of(content)
    ..replaceRange(paragraph.spanStart, paragraph.spanEnd, generated);
  return out;
}

/// Aralıkta yalnız metin/durum operatörleri olduğunu doğrular.
///
/// `BT`/`ET` ayrı ele alınır: belgelerin çoğu (resmi yazı üreticileri, EBYS)
/// paragrafın HER SATIRINI ayrı bir metin nesnesine yazar, dolayısıyla aralığın
/// ortasında zorunlu olarak `ET … BT` çiftleri bulunur. Bunları reddetmek çok
/// satırlı her paragrafı düzenlenemez yapıyordu. Silmek güvenli: aralık bir
/// metin nesnesinin İÇİNDE başlayıp İÇİNDE bittiği için kaldırılan `ET` ve `BT`
/// sayısı eşittir — dıştaki `BT` açık kalır, dıştaki `ET` kapatır, yığın
/// dengede kalır. Dengesiz bir dizi (aralık `BT` ile başlıyor ya da eksik
/// kapanıyor) yine reddedilir.
void _checkSpan(List<int> content, PdfParagraph paragraph) {
  const unbalanced = PdfParagraphRefused(
    'Bu paragrafın metin blokları beklenmedik biçimde iç içe. Yeniden dizmek '
    'sayfayı bozabileceği için yapılmadı.',
  );

  final scan = scanContent(content);
  // 0 = metin nesnesinin içindeyiz (başlangıç durumu), -1 = iki nesne arası.
  var depth = 0;
  for (final event in scan.events) {
    if (event.operatorStart < paragraph.spanStart ||
        event.operatorStart >= paragraph.spanEnd) {
      continue;
    }
    if (event.op == 'ET') {
      if (--depth < -1) throw unbalanced;
      continue;
    }
    if (event.op == 'BT') {
      if (++depth > 0) throw unbalanced;
      continue;
    }
    if (_allowedInSpan.contains(event.op)) continue;
    throw PdfParagraphRefused(
      'Bu paragrafın içinde metin dışı çizim var (`${event.op}`). Yeniden '
      'dizmek sayfayı bozabileceği için yapılmadı.',
    );
  }
  if (depth != 0) throw unbalanced;
}

/// Yeni metnin her harfine bir biçim koşusu atar.
///
/// Ortak ön ek ve ortak son ek DOKUNULMAMIŞ sayılır ve özgün biçimlerini
/// aynen korur; yalnız aradaki değişen bölge yeni biçim alır. Bu, kullanıcının
/// yaptığı düzeltmenin tipik biçimidir (bir harf, bir kelime, bir cümle).
///
/// Sınır: iki AYRI yeri aynı anda değiştirirsen aradaki bölge tek biçme
/// düşer. Pratikte görünmez, çünkü aradaki bölge zaten çoğunlukla tek biçimli.
List<int> _mapRuns(String oldText, List<int> oldRunOfChar, String newText) {
  if (oldRunOfChar.isEmpty) {
    return List<int>.filled(newText.length, 0);
  }

  var prefix = 0;
  while (prefix < oldText.length &&
      prefix < newText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }

  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText.codeUnitAt(oldText.length - 1 - suffix) ==
          newText.codeUnitAt(newText.length - 1 - suffix)) {
    suffix++;
  }

  // Değişen bölgenin biçimi: bir şey SİLİNDİYSE silinenin biçimi (kalın bir
  // kelimeyi değiştirince kalın kalsın), saf EKLEMEyse öncesinin biçimi.
  final deleted = oldText.length - prefix - suffix;
  final middleRun = deleted > 0
      ? oldRunOfChar[prefix.clamp(0, oldRunOfChar.length - 1)]
      : oldRunOfChar[(prefix - 1).clamp(0, oldRunOfChar.length - 1)];

  final out = <int>[];
  for (var i = 0; i < newText.length; i++) {
    if (i < prefix) {
      out.add(oldRunOfChar[i.clamp(0, oldRunOfChar.length - 1)]);
    } else if (i >= newText.length - suffix) {
      final oldIndex = oldText.length - (newText.length - i);
      out.add(oldRunOfChar[oldIndex.clamp(0, oldRunOfChar.length - 1)]);
    } else {
      out.add(middleRun);
    }
  }
  return out;
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;

/// Metni kelimelere böler; her kelimeyi biçim parçalarına ayırıp ölçer.
List<_Word> _splitWords(
  String text,
  List<int> runOfChar,
  List<PdfParagraphRun> runs,
  PdfFontAccess fonts,
) {
  final words = <_Word>[];
  var i = 0;
  while (i < text.length) {
    if (_isSpace(text.codeUnitAt(i))) {
      i++;
      continue;
    }
    final start = i;
    while (i < text.length && !_isSpace(text.codeUnitAt(i))) {
      i++;
    }
    words.add(_Word(_segmentsOf(text, start, i, runOfChar, runs, fonts)));
  }
  return words;
}

List<_Segment> _segmentsOf(
  String text,
  int start,
  int end,
  List<int> runOfChar,
  List<PdfParagraphRun> runs,
  PdfFontAccess fonts,
) {
  final out = <_Segment>[];
  var from = start;
  while (from < end) {
    final runIndex = runOfChar[from].clamp(0, runs.length - 1);
    var to = from + 1;
    while (to < end && runOfChar[to].clamp(0, runs.length - 1) == runIndex) {
      to++;
    }
    final run = runs[runIndex];
    final piece = text.substring(from, to);
    out.add(_Segment(run, piece, _advanceOf(run, piece, fonts)));
    from = to;
  }
  return out;
}

/// Bir metnin metin uzayındaki ilerleyişi. Ölçülemiyorsa reddedilir —
/// yanlış ölçüp sayfayı bozmaktansa dokunmamak.
double _advanceOf(PdfParagraphRun run, String text, PdfFontAccess fonts) {
  final glyphs = fonts.measure(run.fontName, text);
  if (glyphs == null) {
    if (fonts.encode(run.fontName, text) == null) {
      throw const PdfParagraphRefused(
        'Yazdığınız karakterlerden biri belgenin yazı tipinde yok. Bu yazı '
        'tipi belgeye yalnızca kullanılan harfleriyle gömülmüş; olmayan bir '
        'harfi eklemek yazıyı bozardı. Farklı bir sözcük deneyin.',
      );
    }
    throw const PdfParagraphRefused(
      'Bu paragrafın yazı tipi genişlik tablosu taşımıyor, metin ölçülemiyor. '
      'Yanlış ölçüp sayfayı bozmamak için değişiklik yapılmadı.',
    );
  }
  final state = run.state;
  final tx = glyphs.width1000 / 1000 * run.fontSize +
      glyphs.glyphCount * state.charSpacing +
      glyphs.spaceCount * state.wordSpacing;
  return tx * state.horizScale;
}

/// Kelime arası boşluğun ilerleyişi.
///
/// Boşluk KARAKTERİ yazmıyoruz (alt küme gömülü fontlarda boşluk glifi çoğu
/// zaman yok); her kelimeyi kendi `Tm`'iyle konumlandırıp araya bu kadar yer
/// bırakıyoruz. Ölçülemezse yarım em'in yarısı — tipik bir boşluk genişliği.
double _spaceAdvance(PdfParagraphRun run, PdfFontAccess fonts) {
  final glyphs = fonts.measure(run.fontName, ' ');
  if (glyphs == null || glyphs.width1000 <= 0) {
    return run.fontSize * 0.25 * run.state.horizScale;
  }
  return (glyphs.width1000 / 1000 * run.fontSize +
          glyphs.glyphCount * run.state.charSpacing +
          glyphs.spaceCount * run.state.wordSpacing) *
      run.state.horizScale;
}

/// Kelimeleri özgün sütun genişliğine göre satırlara sarar (açgözlü — Word'ün
/// de yaptığı budur) ve iki yana yaslıysa boşlukları yeniden dağıtır.
List<_LaidLine> _wrap({
  required List<_Word> words,
  required PdfParagraph paragraph,
  required double scaleX,
  required double spaceAdvance,
}) {
  // Kullanılabilir genişlik ilerleyiş birimindedir (matris e-uzayı / scaleX).
  double availableFor(int lineIndex) {
    final startX =
        lineIndex == 0 ? paragraph.firstLineX : paragraph.bodyLeftX;
    return (paragraph.rightX - startX) / scaleX;
  }

  final rows = <List<_Word>>[];
  var current = <_Word>[];
  var used = 0.0;

  for (final word in words) {
    final extra = current.isEmpty ? word.advance : spaceAdvance + word.advance;
    final available = availableFor(rows.length);
    if (current.isNotEmpty && used + extra > available) {
      rows.add(current);
      current = [word];
      used = word.advance;
      continue;
    }
    current.add(word);
    used += extra;
  }
  if (current.isNotEmpty) rows.add(current);

  final out = <_LaidLine>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final startX = i == 0 ? paragraph.firstLineX : paragraph.bodyLeftX;
    var space = spaceAdvance;

    // İki yana yaslama: son satır ASLA yaslanmaz (Word de yaslamaz).
    final isLast = i == rows.length - 1;
    if (paragraph.justified && !isLast && row.length > 1) {
      final natural =
          row.fold<double>(0, (sum, w) => sum + w.advance) +
              spaceAdvance * (row.length - 1);
      final available = availableFor(i);
      final slack = available - natural;
      if (slack > 0) space = spaceAdvance + slack / (row.length - 1);
    }
    out.add(_LaidLine(row, space, startX));
  }
  return out;
}

/// Dizilmiş satırlardan içerik akışı operatörleri üretir.
///
/// Her kelime kendi `Tm`'iyle mutlak konumlandırılır. Niye kelime kelime:
/// konum hiçbir ilerleyiş birikimine bağlı kalmaz (yuvarlama hatası birikmez)
/// ve iki yana yaslama fazladan bir mekanizma gerektirmeden çıkar.
List<int> _emit({
  required List<_LaidLine> laid,
  required PdfParagraph paragraph,
  required List<double> matrix,
  required PdfFontAccess fonts,
}) {
  final buffer = <int>[];
  void write(String s) => buffer.addAll(s.codeUnits);

  final a = matrix[0];
  final b = matrix[1];
  final c = matrix[2];
  final d = matrix[3];
  final baseY = paragraph.lines.first.baselineY;

  String? lastFont;
  double? lastSize;
  List<int>? lastColor;

  for (var i = 0; i < laid.length; i++) {
    final line = laid[i];
    final y = baseY - i * paragraph.leading;
    var x = line.startX;

    for (var w = 0; w < line.words.length; w++) {
      final word = line.words[w];
      for (final segment in word.segments) {
        final run = segment.run;

        if (run.colorBytes.isNotEmpty &&
            (lastColor == null || !_sameBytes(lastColor, run.colorBytes))) {
          buffer.addAll(run.colorBytes);
          write('\n');
          lastColor = run.colorBytes;
        }

        if (run.fontName != lastFont || run.fontSize != lastSize) {
          write('/${run.fontName} ${writePdfNumber(run.fontSize)} Tf\n');
          lastFont = run.fontName;
          lastSize = run.fontSize;
        }

        write('${writePdfNumber(a)} ${writePdfNumber(b)} ${writePdfNumber(c)} '
            '${writePdfNumber(d)} ${writePdfNumber(x)} ${writePdfNumber(y)} Tm\n');

        final bytes = fonts.encode(run.fontName, segment.text);
        if (bytes == null) {
          throw const PdfParagraphRefused(
            'Yazdığınız karakterlerden biri belgenin yazı tipinde yok. '
            'Farklı bir sözcük deneyin.',
          );
        }
        buffer.addAll(fonts.codeBytes(run.fontName) > 1
            ? writeHexString(bytes)
            : writeLiteralString(bytes));
        write(' Tj\n');

        x += segment.advance * a;
      }
      if (w < line.words.length - 1) x += line.spaceAdvance * a;
    }
  }
  return buffer;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
