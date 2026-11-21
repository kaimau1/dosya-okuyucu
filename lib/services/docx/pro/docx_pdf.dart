/// **Faz 37 madde 2 + 7 — Word → PDF (baskı önizleme ve dışa aktarım).**
///
/// Editör modelinden ([DocxDocument]) `pdf` paketiyle sayfa kurar: bölüm
/// ölçüsü/kenar boşluğu, sütun, başlık düzeyleri, harf biçimi (kalın, eğik,
/// altı çizili, üstü çizili, renk, vurgu, punto, üst/alt simge), hizalama,
/// girinti, aralık, liste etiketleri, tablolar, resimler (PNG/JPEG), sayfa sonu
/// / `pageBreakBefore`, başlığın sonraki paragraftan kopmaması (keepNext) ve
/// sayfa numarası. **Yazı tipleri gömülüdür** (Carlito / Tinos — metrik
/// uyumlu, Türkçe karakterli; base-14 Helvetica `ğ ş ı İ`yi sessizce
/// bozuyordu, bkz. `conversion_service`).
///
/// Üretim izolatta ([DocxPdf.renderInBackground]; anayasa k.1); yazı tipi
/// baytları ana izlekte bir kez okunur ([DocxPdfFonts.load]).
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../docx_document.dart';
import '../docx_styles.dart';
import 'docx_package.dart';

/// Gömülecek yazı tipi baytları (izolata gönderilebilir).
class DocxPdfFonts {
  final Map<String, Uint8List> files;
  const DocxPdfFonts(this.files);

  static DocxPdfFonts? _cache;

  static const _names = [
    'Carlito-Regular', 'Carlito-Bold', 'Carlito-Italic', 'Carlito-BoldItalic',
    'Tinos-Regular', 'Tinos-Bold', 'Tinos-Italic', 'Tinos-BoldItalic',
  ];

  static Future<DocxPdfFonts> load() async {
    final have = _cache;
    if (have != null) return have;
    final out = <String, Uint8List>{};
    for (final n in _names) {
      final d = await rootBundle.load('assets/fonts/$n.ttf');
      out[n] = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    }
    return _cache = DocxPdfFonts(out);
  }
}

/// Sayfa ölçüsü (pt) + kenar boşlukları + sütun.
class DocxPdfPage {
  final double width, height, top, right, bottom, left;
  final int columns;
  final bool titlePage;
  const DocxPdfPage(this.width, this.height, this.top, this.right,
      this.bottom, this.left, this.columns, this.titlePage);

  static DocxPdfPage of(DocxPackage pkg) {
    final s = kid(pkg.body, 'sectPr');
    double tw(XmlElement? e, String a, double def) {
      final v = double.tryParse(attrOf(e, a) ?? '');
      return v == null ? def : v / 20;
    }

    final sz = kid(s, 'pgSz');
    final mar = kid(s, 'pgMar');
    final cols = int.tryParse(attrOf(kid(s, 'cols'), 'num') ?? '') ?? 1;
    return DocxPdfPage(
      tw(sz, 'w', 595.3),
      tw(sz, 'h', 841.9),
      tw(mar, 'top', 72).abs(),
      tw(mar, 'right', 72),
      tw(mar, 'bottom', 72).abs(),
      tw(mar, 'left', 72),
      cols.clamp(1, 4),
      kid(s, 'titlePg') != null,
    );
  }
}

abstract final class DocxPdf {
  static Future<Uint8List> renderInBackground(Uint8List docx,
      {required DocxPdfFonts fonts, bool pageNumbers = true}) {
    Future<Uint8List> work() =>
        render(docx, fonts: fonts, pageNumbers: pageNumbers);
    return DocxPro.inIsolate ? Isolate.run(work) : work();
  }

  /// Belge sonu bölümünün varsayılan üst/alt bilgi metni; PAGE alanı
  /// `{p}`, NUMPAGES `{n}` yer tutucusu olur. Yoksa null.
  static String? headerFooterText(DocxPackage pkg, String refName) {
    final s = kid(pkg.body, 'sectPr');
    XmlElement? ref;
    for (final r in kids(s, refName)) {
      final t = attrOf(r, 'type') ?? 'default';
      if (t == 'default') ref = r;
    }
    final id = attrOf(ref, 'id');
    final target = id == null ? null : pkg.relTarget(id);
    if (target == null) return null;
    final part = pkg.read('word/${target.replaceFirst(RegExp(r'^/?word/'), '')}');
    if (part == null) return null;
    final lines = <String>[];
    for (final p in part.rootElement.descendantElements.where((e) => e.name.local == 'p')) {
      final sb = StringBuffer();
      var instr = '';
      for (final e in p.descendantElements) {
        switch (e.name.local) {
          case 't':
            if (instr.isEmpty) sb.write(e.innerText);
          case 'tab':
            sb.write('   ');
          case 'fldSimple':
            final code = (attrOf(e, 'instr') ?? '').trim().toUpperCase();
            sb.write(code.startsWith('NUMPAGES') ? '{n}' : code.startsWith('PAGE') ? '{p}' : '');
          case 'instrText':
            instr += e.innerText;
          case 'fldChar':
            final t = attrOf(e, 'fldCharType');
            if ((t == 'separate' || t == 'end') && instr != '\u0000') {
              final code = instr.trim().toUpperCase();
              if (code.startsWith('NUMPAGES')) sb.write('{n}');
              if (code.startsWith('PAGE')) sb.write('{p}');
            }
            if (t == 'separate') instr = '\u0000';
            if (t == 'end') instr = '';
        }
      }
      // fldSimple içindeki sonuç metni ayrıca yazılmasın.
      final line = sb
          .toString()
          .replaceAllMapped(RegExp(r'\{([pn])\}\d+'), (m) => '{${m[1]}}')
          .trim();
      if (line.isNotEmpty) lines.add(line);
    }
    return lines.isEmpty ? null : lines.join('  ·  ');
  }

  /// [compress] yalnız testte kapatılır (sayfa nesneleri metinde sayılsın).
  /// [notePages]: (testte) dipnot anahtarı → altına yazıldığı sayfa.
  ///
  /// Dipnot sayfa ALTINDA: `pdf` paketinde alt bilgi sayfa içeriğinden önce
  /// kurulur, hangi notun o sayfaya düştüğü bilinmez. Bu yüzden geçişli:
  /// her geçişte not başvurusu çizildiği sayfayı kaydeder ([_PageProbe]),
  /// sonraki geçiş notu o sayfanın altına koyar; yerleşim değişmeyince durur.
  /// Notsuz belgede tek geçiş. Sonnotlar belge sonunda kalır.
  static Future<Uint8List> render(Uint8List docx,
      {required DocxPdfFonts fonts,
      bool pageNumbers = true,
      bool compress = true,
      Map<String, int>? notePages}) async {
    final doc = DocxDocument.parse(docx);
    final pkg = DocxPackage.open(docx);
    final page = DocxPdfPage.of(pkg);
    final header = headerFooterText(pkg, 'headerReference');
    final footer = headerFooterText(pkg, 'footerReference');
    // ponytail: en çok 3 geçiş; yine oynarsa not, başvurusunun bir önceki
    // geçişteki sayfasının altında kalır (bir sayfa kayabilir).
    var placed = <String, int>{};
    for (var pass = 0;; pass++) {
      final r = _Renderer(doc, fonts)..footPage = placed;
      final bytes = await _renderPass(r, page, header, footer,
          pageNumbers: pageNumbers, compress: compress);
      final seen = r.refPage;
      if (pass == 2 || seen.isEmpty || _samePlaces(seen, placed)) {
        notePages?.addAll(placed);
        return bytes;
      }
      placed = seen;
    }
  }

  static bool _samePlaces(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static Future<Uint8List> _renderPass(_Renderer r, DocxPdfPage page,
      String? header, String? footer,
      {required bool pageNumbers, required bool compress}) {
    String fill(String t, pw.Context ctx) => t
        .replaceAll('{p}', '${ctx.pageNumber}')
        .replaceAll('{n}', '${ctx.pagesCount}');
    final out = pw.Document(compress: compress);
    final format = PdfPageFormat(page.width, page.height,
        marginTop: page.top,
        marginBottom: page.bottom,
        marginLeft: page.left,
        marginRight: page.right);
    final body = r.build(format.availableWidth);
    // Sonnotlar (ve henüz sayfası bilinmeyen dipnotlar) belge sonunda liste.
    final notes = r.notesSection(format.availableWidth);
    if (notes.isNotEmpty) body.last.addAll(notes);
    pw.Widget pageFooter(pw.Context ctx) {
      final text = footer == null && !pageNumbers ||
              (page.titlePage && ctx.pageNumber == 1)
          ? null
          : pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                  footer == null ? '${ctx.pageNumber}' : fill(footer, ctx),
                  style: r.small));
      final foot = r.footNotes(ctx.pageNumber, format.availableWidth);
      if (foot.isEmpty) return text ?? pw.SizedBox();
      return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [...foot, ?text]);
    }
    // Sayfa sonu atomlarına göre bölümler: her bölüm yeni sayfada başlar.
    var first = true;
    for (final chunk in body) {
      out.addPage(pw.MultiPage(
        pageFormat: format,
        theme: r.theme,
        maxPages: 2000,
        header: header == null
            ? null
            : (ctx) => (page.titlePage && ctx.pageNumber == 1)
                ? pw.SizedBox()
                : pw.Container(
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(fill(header, ctx), style: r.small)),
        footer: footer == null && !pageNumbers && r.footPage.isEmpty
            ? null
            : pageFooter,
        // Çok sütunlu bölüm PDF'te tek sütun akar (pdf paketinde gazete
        // sütunu yok); sütun ayarı belgede korunur.
        build: (_) => chunk,
      ));
      first = false;
    }
    if (first) out.addPage(pw.Page(pageFormat: format, build: (_) => pw.SizedBox()));
    return out.save();
  }
}

class _Renderer {
  final DocxDocument doc;
  late final pw.ThemeData theme;
  late final pw.Font _sans, _sansB, _sansI, _sansBI, _serif, _serifB, _serifI, _serifBI;

  _Renderer(this.doc, DocxPdfFonts fonts) {
    pw.Font f(String n) => pw.Font.ttf(fonts.files[n]!.buffer.asByteData());
    _sans = f('Carlito-Regular');
    _sansB = f('Carlito-Bold');
    _sansI = f('Carlito-Italic');
    _sansBI = f('Carlito-BoldItalic');
    _serif = f('Tinos-Regular');
    _serifB = f('Tinos-Bold');
    _serifI = f('Tinos-Italic');
    _serifBI = f('Tinos-BoldItalic');
    theme = pw.ThemeData.withFont(
        base: _sans, bold: _sansB, italic: _sansI, boldItalic: _sansBI);
  }

  static bool _isSerif(String? font) {
    final f = (font ?? '').toLowerCase();
    return f.contains('times') ||
        f.contains('georgia') ||
        f.contains('cambria') ||
        f.contains('garamond') ||
        f.contains('antiqua') ||
        f.contains('serif') && !f.contains('sans');
  }

  pw.Font _font(DocxRunLook l) {
    final serif = _isSerif(l.font);
    if (l.bold && l.italic) return serif ? _serifBI : _sansBI;
    if (l.bold) return serif ? _serifB : _sansB;
    if (l.italic) return serif ? _serifI : _sansI;
    return serif ? _serif : _sans;
  }

  static PdfColor? _color(int? argb) =>
      argb == null ? null : PdfColor.fromInt(argb | 0xFF000000);

  /// [sup]: üst simge boyu (not numarası) — run biçiminde olmasa da.
  pw.TextStyle _style(DocxRunLook l, {bool sup = false}) {
    final small = sup || l.vertAlign != null;
    return pw.TextStyle(
      font: _font(l),
      fontSize: (l.sizePt <= 0 ? 11 : l.sizePt) * (small ? 0.65 : 1),
      color: _color(l.color) ?? PdfColors.black,
      background: l.highlight == null
          ? null
          : pw.BoxDecoration(color: _color(l.highlight)),
      decoration: pw.TextDecoration.combine([
        if (l.underline) pw.TextDecoration.underline,
        if (l.strike) pw.TextDecoration.lineThrough,
      ]),
    );
  }

  static pw.TextAlign _align(String a, bool bidi) => switch (a) {
        'center' => pw.TextAlign.center,
        'right' || 'end' => pw.TextAlign.right,
        'both' || 'distribute' => pw.TextAlign.justify,
        _ => bidi ? pw.TextAlign.right : pw.TextAlign.left,
      };

  late final pw.TextStyle small = pw.TextStyle(font: _sans, fontSize: 9, color: PdfColors.grey700);

  late final List<String> _labels = doc.listLabels();
  late final Map<DocxAtom, String> _noteNos = doc.noteLabels();

  /// Çizilen notlar (anahtar → numara), belge sırasıyla.
  final Map<String, String> _notesSeen = {};

  /// Önceki geçişte dipnot başvurusunun düştüğü sayfa (anahtar → sayfa):
  /// bu geçişte not o sayfanın altına yazılır.
  Map<String, int> footPage = const {};

  /// Bu geçişte başvurunun çizildiği sayfa (çizimde dolar).
  final Map<String, int> refPage = {};

  /// Not anahtarı → numara (çizilen başvurular).
  final Map<String, String> _noteNo = {};

  /// [page]. sayfanın altına: ayırıcı + o sayfadaki dipnotlar.
  List<pw.Widget> footNotes(int page, double width) {
    final here = {
      for (final e in footPage.entries)
        if (e.value == page) e.key: _noteNo[e.key] ?? '',
    };
    return here.isEmpty ? const [] : _noteLines(here, width, top: 6);
  }

  /// Belge sonuna: ayırıcı çizgi + "numara  metin" satırları.
  List<pw.Widget> notesSection(double width) {
    if (_notesSeen.isEmpty) return const [];
    return _noteLines(_notesSeen, width, top: 18);
  }

  List<pw.Widget> _noteLines(Map<String, String> notes, double width,
      {required double top}) {
    final st = small.copyWith(color: PdfColors.black);
    return [
      pw.Container(
        width: width / 3,
        margin: pw.EdgeInsets.only(top: top, bottom: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.5))),
      ),
      for (final e in notes.entries)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: e.value, style: st, baseline: 3),
              pw.TextSpan(text: ' ${doc.footnoteText(e.key) ?? ''}', style: st),
            ]),
          ),
        ),
    ];
  }

  late final Map<DocxPara, int> _index = Map.identity()
    ..addAll({for (var i = 0; i < doc.paras.length; i++) doc.paras[i]: i});

  /// Yeni sayfada başlayan bölümlerin ilk paragrafları: paragraf sectPr'si
  /// bir bölümü bitirir; sonraki bölümün türü `continuous` değilse yeni sayfa.
  late final Set<int> _sectionStartsPage = () {
    final out = <int>{};
    final ends = <int>[];
    for (var i = 0; i < doc.paras.length; i++) {
      final pPr = doc.paras[i].pPr;
      if (pPr != null && pPr.childElements.any((e) => e.name.local == 'sectPr')) {
        ends.add(i);
      }
    }
    for (var k = 0; k < ends.length; k++) {
      XmlElement? next;
      if (k + 1 < ends.length) {
        next = doc.paras[ends[k + 1]].pPr!.childElements.firstWhere((e) => e.name.local == 'sectPr');
      } else {
        next = doc.body.childElements.where((e) => e.name.local == 'sectPr').firstOrNull;
      }
      final type = next?.childElements.where((e) => e.name.local == 'type').firstOrNull;
      final v = type?.attributes.where((a) => a.name.local == 'val').firstOrNull?.value;
      if (v != 'continuous') out.add(ends[k] + 1);
    }
    return out;
  }();

  /// Belge → sayfa sonu atomlarına göre bölünmüş widget dizileri.
  List<List<pw.Widget>> build(double width) {
    final chunks = <List<pw.Widget>>[[]];
    final paras = doc.paras;
    var i = 0;
    while (i < paras.length) {
      final p = paras[i];
      if (p.cell != null) {
        final table = p.cell!.table;
        var j = i;
        while (j < paras.length && identical(paras[j].cell?.table, table)) {
          j++;
        }
        chunks.last.add(_table(paras.sublist(i, j), width));
        i = j;
        continue;
      }
      if (p.look.pageBreakBefore && chunks.last.isNotEmpty) chunks.add([]);
      if (i > 0 && _sectionStartsPage.contains(i) && chunks.last.isNotEmpty) {
        chunks.add([]);
      }
      final parts = _paraParts(p, i, width);
      for (var k = 0; k < parts.length; k++) {
        if (k > 0) chunks.add([]);
        if (parts[k] case final w?) chunks.last.add(w);
      }
      // keepNext: başlık sayfa dibinde yalnız kalmasın — kısa sonraki
      // paragrafla tek blok (bölünmez widget sayfadan uzun olamaz).
      if (p.look.headingLevel > 0 &&
          parts.length == 1 &&
          parts.single != null &&
          i + 1 < paras.length &&
          paras[i + 1].cell == null &&
          !paras[i + 1].look.pageBreakBefore &&
          !_sectionStartsPage.contains(i + 1) &&
          paras[i + 1].length < 600 &&
          !paras[i + 1].text.contains(kDocxAtom)) {
        final next = _paraParts(paras[i + 1], i + 1, width);
        if (next.length == 1 && next.single != null) {
          chunks.last.removeLast();
          chunks.last.add(pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [parts.single!, next.single!]));
          i += 2;
          continue;
        }
      }
      i++;
    }
    return chunks;
  }

  /// Paragrafı sayfa sonlarından böler; her parça bir widget (boş → null).
  List<pw.Widget?> _paraParts(DocxPara p, int index, double width) {
    if (p.opaque) {
      return [pw.Text(p.text, style: pw.TextStyle(font: _sans, fontSize: 11))];
    }
    final look = p.look;
    final out = <pw.Widget?>[];
    var spans = <pw.InlineSpan>[];
    final label = index >= 0 && index < _labels.length ? _labels[index] : '';
    if (label.isNotEmpty) {
      spans.add(pw.TextSpan(
          text: '$label\t'.replaceAll('\t', '  '),
          style: _style(p.mark.effective)));
    }
    final sb = StringBuffer();
    DocxRunLook? cur;
    void flush() {
      if (sb.isEmpty || cur == null) return;
      final l = cur;
      spans.add(l.vertAlign == null
          ? pw.TextSpan(text: sb.toString(), style: _style(l))
          : pw.TextSpan(
              text: sb.toString(),
              style: _style(l),
              baseline: l.vertAlign == 'superscript' ? 4 : -2));
      sb.clear();
    }

    void close() {
      flush();
      out.add(_block(spans, look, p.mark.effective, width));
      spans = [];
    }

    for (var k = 0; k < p.length; k++) {
      final a = p.atoms[k];
      final l = p.styles[k].effective;
      if (a != null) {
        flush();
        switch (a.kind) {
          case DocxAtomKind.pageBreak:
            close();
          case DocxAtomKind.image:
            final img = a.image;
            if (img != null && _supported(img)) {
              final wPt = a.widthPt <= 0 ? 200.0 : a.widthPt;
              final hPt = a.heightPt <= 0 ? wPt * 0.75 : a.heightPt;
              final scale = wPt > width ? width / wPt : 1.0;
              spans.add(pw.WidgetSpan(
                  child: pw.Image(pw.MemoryImage(img),
                      width: wPt * scale, height: hPt * scale)));
            }
          case DocxAtomKind.note:
            final no = _noteNos[a] ?? a.display;
            if (no.isNotEmpty) {
              final key = doc.noteKey(a);
              _noteNo[key] = no;
              if (!footPage.containsKey(key)) _notesSeen[key] = no;
              spans.add(pw.TextSpan(
                  text: no, style: _style(l, sup: true), baseline: 4));
              if (!key.startsWith(kDocxEndnoteKey)) {
                spans.add(pw.WidgetSpan(
                    child: _PageProbe((p) => refPage[key] ??= p)));
              }
            }
          default:
            if (a.display.isNotEmpty) {
              spans.add(pw.TextSpan(
                  text: a.display,
                  style: _style(l).copyWith(
                      color: a.kind == DocxAtomKind.link ? PdfColors.blue800 : null)));
            }
        }
        cur = null;
        continue;
      }
      if (cur != null && !identical(cur, l) && !_same(cur, l)) flush();
      cur = l;
      final ch = p.text[k];
      sb.write(ch == '\t' ? '    ' : ch);
    }
    close();
    return out;
  }

  static bool _same(DocxRunLook a, DocxRunLook b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strike == b.strike &&
      a.sizePt == b.sizePt &&
      a.color == b.color &&
      a.highlight == b.highlight &&
      a.font == b.font &&
      a.vertAlign == b.vertAlign;

  static bool _supported(Uint8List b) =>
      b.length > 8 &&
      ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) ||
          (b[0] == 0xFF && b[1] == 0xD8));

  pw.Widget _block(List<pw.InlineSpan> spans, DocxParaLook look,
      DocxRunLook mark, double width) {
    final size = mark.sizePt <= 0 ? 11.0 : mark.sizePt;
    final lineSpacing = ((look.lineMultiple ?? 1.08) - 1).clamp(0, 2) * size;
    final text = spans.isEmpty
        ? pw.SizedBox(height: size * 1.2)
        : pw.RichText(
            text: pw.TextSpan(children: spans, style: pw.TextStyle(font: _sans, fontSize: size, lineSpacing: lineSpacing.toDouble())),
            textAlign: _align(look.align, look.bidi),
            textDirection: look.bidi ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          );
    final indent = look.indentLeftPt.clamp(0, width * 0.6).toDouble();
    return pw.Container(
      margin: pw.EdgeInsets.only(
          left: indent,
          top: look.spaceBeforePt.clamp(0, 72).toDouble(),
          bottom: look.spaceAfterPt.clamp(0, 72).toDouble()),
      decoration: look.borderBottom
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.75)))
          : null,
      child: text,
    );
  }

  pw.Widget _table(List<DocxPara> cells, double width) {
    var rows = 0, cols = 0;
    for (final p in cells) {
      final c = p.cell!;
      if (c.row + 1 > rows) rows = c.row + 1;
      if (c.col + c.gridSpan > cols) cols = c.col + c.gridSpan;
    }
    final grid = List.generate(rows, (_) => List<List<pw.Widget>>.generate(cols, (_) => []));
    for (final p in cells) {
      final c = p.cell!;
      final idx = _index[p] ?? -1;
      for (final w in _paraParts(p, idx, width / (cols == 0 ? 1 : cols))) {
        if (w != null) grid[c.row][c.col].add(w);
      }
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          for (final r in grid)
            pw.TableRow(children: [
              for (final cell in r)
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: cell)),
            ]),
        ],
      ),
    );
  }
}

/// Görünmez, boyutsuz: çizildiği sayfanın numarasını bildirir (dipnot
/// başvurusunun hangi sayfaya düştüğünü öğrenmek için).
class _PageProbe extends pw.Widget {
  _PageProbe(this.mark);
  final void Function(int page) mark;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.zero;
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    mark(context.pageNumber);
  }
}
