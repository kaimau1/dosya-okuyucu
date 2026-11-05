/// **Faz 37 madde 8 + 11 — artımlı sayfa tahmini.**
///
/// Mobil görünüm sayfa çizmez; gezinti/küçük resim/sayaç için "kaç sayfa,
/// paragraf hangi sayfada" tahmini gerekir. Paragraf yüksekliği punto, satır
/// aralığı, girinti ve harf sayısından kestirilir (Word ile ±%10).
///
/// **Artımlı (anayasa: sayfa düzeni yalnız değişen paragraf ve sonrası):**
/// paragraflar değişmez nesne; yükseklik nesneye [Expando] ile bağlı, el
/// değmemiş paragraf yeniden ölçülmez. Önceki çalıştırmayla ortak önek
/// (aynı nesneler) korunur; yalnız ilk farklı paragraftan sonrası yeniden
/// dizilir.
library;

import '../docx_document.dart';

class DocxPageGeometry {
  final double widthPt, heightPt;
  const DocxPageGeometry(this.widthPt, this.heightPt);

  /// A4, 2,54 cm kenar boşluğu.
  static const a4 = DocxPageGeometry(451.3, 697.9);
}

class DocxPaginator {
  DocxPageGeometry geometry;
  DocxPaginator([this.geometry = DocxPageGeometry.a4]);

  static final _height = Expando<double>('docxParaHeight');

  List<DocxPara> _last = const [];
  List<int> _pageOf = const [];
  final List<double> _usedAfter = [];

  /// Son çalıştırmada yeniden ölçülen paragraf sayısı (test/perf için).
  int measured = 0;

  /// Paragraf → sayfa (0 tabanlı) listesi.
  List<int> layout(List<DocxPara> paras) {
    measured = 0;
    var start = 0;
    final n = paras.length;
    while (start < n &&
        start < _last.length &&
        identical(paras[start], _last[start])) {
      start++;
    }
    // Önek korunur; önekin son paragrafının dolduğu yerden devam.
    final pageOf = List<int>.filled(n, 0);
    for (var i = 0; i < start; i++) {
      pageOf[i] = _pageOf[i];
    }
    if (_usedAfter.length > start) _usedAfter.removeRange(start, _usedAfter.length);
    var page = start == 0 ? 0 : pageOf[start - 1];
    var used = start == 0 ? 0.0 : _usedAfter[start - 1];
    for (var i = start; i < n; i++) {
      final p = paras[i];
      final h = heightOf(p);
      if (p.look.pageBreakBefore && used > 0) {
        page++;
        used = 0;
      }
      if (used + h > geometry.heightPt && used > 0) {
        // Uzun paragraf sayfalara bölünür.
        var rest = used + h - geometry.heightPt;
        page++;
        while (rest > geometry.heightPt) {
          rest -= geometry.heightPt;
          page++;
        }
        used = rest;
        pageOf[i] = page;
      } else {
        used += h;
        pageOf[i] = page;
      }
      if (p.text.contains(kDocxAtom) &&
          p.atoms.any((a) => a?.kind == DocxAtomKind.pageBreak)) {
        page++;
        used = 0;
      }
      _usedAfter.add(used);
    }
    _last = List.of(paras);
    _pageOf = pageOf;
    return pageOf;
  }

  int get pageCount => _pageOf.isEmpty ? 1 : _pageOf.last + 1;

  /// Sayfanın ilk paragrafı.
  int firstParaOf(int page) {
    for (var i = 0; i < _pageOf.length; i++) {
      if (_pageOf[i] >= page) return i;
    }
    return _pageOf.isEmpty ? 0 : _pageOf.length - 1;
  }

  double heightOf(DocxPara p) {
    final have = _height[p];
    if (have != null) return have;
    measured++;
    final h = _measure(p);
    _height[p] = h;
    return h;
  }

  double _measure(DocxPara p) {
    final look = p.look;
    final size = p.styles.isEmpty
        ? p.mark.effective.sizePt
        : p.styles[p.styles.length ~/ 2].effective.sizePt;
    final pt = size <= 0 ? 11.0 : size;
    var width = geometry.widthPt - look.indentLeftPt.clamp(0, geometry.widthPt * 0.6);
    // Tablo hücresi: sütun sayısı kadar dar (satır yüksekliği hücreler
    // arasında paylaşılır → hücre başı yükseklik / sütun).
    var share = 1.0;
    if (p.cell != null) {
      final cols = (p.cell!.col + p.cell!.gridSpan).clamp(1, 12);
      width = width / cols;
      share = 1 / cols;
    }
    final charsPerLine = (width / (pt * 0.5)).clamp(8, 400);
    var lines = 0;
    var imageH = 0.0;
    for (final segment in p.text.split('\n')) {
      lines += (segment.length / charsPerLine).ceil().clamp(1, 100000);
    }
    for (final a in p.atoms) {
      if (a != null && a.kind == DocxAtomKind.image) imageH += a.heightPt;
    }
    final line = pt * 1.2 * (look.lineMultiple ?? 1.08);
    return (lines * line + imageH + look.spaceBeforePt + look.spaceAfterPt) * share;
  }
}

/// Sayaçlar + okuma süresi (madde 8).
class DocxStats {
  final int words, chars, charsNoSpace, paragraphs, pages, headings;
  const DocxStats(this.words, this.chars, this.charsNoSpace, this.paragraphs,
      this.pages, this.headings);

  /// Sessiz okuma ~200 sözcük/dk, sesli ~130 sözcük/dk (Türkçe için de
  /// yaygın kabul).
  Duration get reading => Duration(seconds: (words * 60 / 200).round());
  Duration get speaking => Duration(seconds: (words * 60 / 130).round());

  static DocxStats of(List<DocxPara> paras, {int pages = 1}) {
    var words = 0, chars = 0, ns = 0, count = 0, heads = 0;
    final word = RegExp(r'\S*[\p{L}\p{N}]\S*', unicode: true);
    for (final p in paras) {
      final t = p.text.replaceAll(kDocxAtom, '');
      if (t.trim().isNotEmpty) count++;
      if (p.look.headingLevel > 0) heads++;
      words += word.allMatches(t).length;
      chars += t.length;
      ns += t.replaceAll(RegExp(r'\s'), '').length;
    }
    return DocxStats(words, chars, ns, count, pages, heads);
  }
}
