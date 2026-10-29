/// **Word belge modeli** (Faz 22, 2026-10-23 — K18 = (b-ii) kendi ince
/// çekirdeğimiz).
///
/// Mobil görünüm editörü belgeyi bu modelle düzenler; WebView'ın
/// `contenteditable` yolu (indeks eşlemesi, Android klavye hataları) burada
/// yok. İlkeler:
/// * **Dokunulmaz ada:** tanımadığımız ya da metni düzenlenmeyen her şey
///   (köprü, alan, dipnot başvurusu, resim, içerik denetimi, izlenen değişiklik,
///   sayfa sonu) paragrafın içinde TEK karakterlik bir "atom" (`U+FFFC`) olur
///   ve kaydette ÖZGÜN düğümü yerine konur. Sıfır genişlikli işaretler (yer
///   imi, yorum aralığı, yazım hatası işareti) "çapa" olarak konumlarıyla
///   taşınır. Bilinmeyen = korunur.
/// * **Yalnız değişen yazılır:** paragraf nesneleri değişmez (immutable); her
///   düzenleme yeni nesne üretir. Kaydedici her `w:p` için en son hangi nesneyi
///   yazdığını bilir ([_writtenAs]); nesne aynıysa paragrafa dokunmaz. El
///   değmemiş belge kaydedilince `document.xml` BAYTI BAYTINA aynıdır.
/// * **Geri al ucuz:** durum = paragraf listesinin sığ kopyası.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/edit/save_coordinator.dart';
import '../../core/symbol_fonts.dart';
import 'docx_styles.dart';

part 'docx_insert.dart';
part 'docx_table.dart';
part 'docx_review.dart';
part 'docx_media.dart';

/// Atom karakteri (Flutter `WidgetSpan` yer tutucusuyla aynı).
const String kDocxAtom = '￼';

/// Satır içi satır sonu (`w:br`).
const String kDocxLineBreak = ' ';

enum DocxAtomKind { image, link, field, note, comment, pageBreak, inline }

/// Satır içi dokunulmaz öğe.
class DocxAtom {
  final DocxAtomKind kind;

  /// Paragrafa aynen geri konan düğümler (`w:r`, `w:hyperlink` …).
  final List<XmlElement> nodes;

  /// Ekranda gösterilen metin (resimde boş).
  final String display;
  final Uint8List? image;
  final double widthPt, heightPt;

  const DocxAtom(this.kind, this.nodes, this.display,
      {this.image, this.widthPt = 0, this.heightPt = 0});
}

/// Kullanıcının harfe uyguladığı doğrudan biçim (Faz 23). `null` alan =
/// dokunulmadı (özgün run'ın/stilin biçimi geçerli).
class DocxRunPatch {
  final bool? bold, italic, underline, strike;

  /// ARGB; [autoColor] = otomatik (tema metin rengi).
  final int? color;

  /// Word vurgu adı (`yellow` …); `''` = vurgu yok.
  final String? highlight;
  final double? sizePt;
  final String? font;

  /// `superscript` | `subscript` | `''` (taban çizgisi).
  final String? vertAlign;

  static const int autoColor = 0;
  static const none = DocxRunPatch();

  const DocxRunPatch({
    this.bold,
    this.italic,
    this.underline,
    this.strike,
    this.color,
    this.highlight,
    this.sizePt,
    this.font,
    this.vertAlign,
  });

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      strike == null &&
      color == null &&
      highlight == null &&
      sizePt == null &&
      font == null &&
      vertAlign == null;

  /// [o]'nun dolu alanları bunun üstüne.
  DocxRunPatch merge(DocxRunPatch o) => DocxRunPatch(
        bold: o.bold ?? bold,
        italic: o.italic ?? italic,
        underline: o.underline ?? underline,
        strike: o.strike ?? strike,
        color: o.color ?? color,
        highlight: o.highlight ?? highlight,
        sizePt: o.sizePt ?? sizePt,
        font: o.font ?? font,
        vertAlign: o.vertAlign ?? vertAlign,
      );

  /// Görünüşe uygulanmış hâli.
  DocxRunLook apply(DocxRunLook l) => isEmpty
      ? l
      : DocxRunLook(
          bold: bold ?? l.bold,
          italic: italic ?? l.italic,
          underline: underline ?? l.underline,
          strike: strike ?? l.strike,
          sizePt: sizePt ?? l.sizePt,
          color: color == null ? l.color : (color == autoColor ? null : color),
          highlight: highlight == null
              ? l.highlight
              : (highlight!.isEmpty ? null : DocxStyles.highlightArgb(highlight!)),
          font: font ?? l.font,
          vertAlign: vertAlign == null
              ? l.vertAlign
              : (vertAlign!.isEmpty ? null : vertAlign),
        );

  @override
  bool operator ==(Object other) =>
      other is DocxRunPatch &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color &&
      other.highlight == highlight &&
      other.sizePt == sizePt &&
      other.font == font &&
      other.vertAlign == vertAlign;

  @override
  int get hashCode => Object.hash(bold, italic, underline, strike, color,
      highlight, sizePt, font, vertAlign);
}

/// Bir harfin biçimi: özgün run (+ özgün metni) ve kullanıcı örtmeleri.
class DocxCharStyle {
  /// Özgün `w:r` (yeni yazıda ve paragraf işaretinde null).
  final XmlElement? run;

  /// Run'ın özgün metni — aynı metin aynı biçimle kaldıysa run aynen kullanılır.
  final String? runText;

  /// Yeni run'ın `w:rPr` şablonu.
  final XmlElement? rPr;

  /// Stil + `rPr`'den çözülmüş görünüş (örtmeler HARİÇ — bkz. [effective]).
  final DocxRunLook look;
  final DocxRunPatch patch;

  const DocxCharStyle(this.run, this.runText, this.rPr, this.look,
      {this.patch = DocxRunPatch.none});

  bool? get bold => patch.bold;
  bool? get italic => patch.italic;
  bool? get underline => patch.underline;

  bool get plain => patch.isEmpty;

  /// Ekranda görünen (örtmeler uygulanmış) görünüş.
  DocxRunLook get effective =>
      plain ? look : (_effective[this] ??= patch.apply(look));
  static final _effective = Expando<DocxRunLook>('docxEffective');

  bool get isBold => effective.bold;
  bool get isItalic => effective.italic;
  bool get isUnderline => effective.underline;

  DocxCharStyle merge(
          {bool? bold,
          bool? italic,
          bool? underline,
          DocxRunPatch patch = DocxRunPatch.none}) =>
      DocxCharStyle(run, runText, rPr, look,
          patch: this.patch.merge(patch).merge(
              DocxRunPatch(bold: bold, italic: italic, underline: underline)));

  /// Aynı run, başka görünüş (paragraf stili değişti).
  DocxCharStyle withLook(DocxRunLook l) =>
      DocxCharStyle(run, runText, rPr, l, patch: patch);

  /// Run'dan kopmuş hâli (yazılan yeni metin özgün run'ı "aynen" sayılmasın).
  /// Aynı biçim için hep AYNI nesne: ardışık yazılan harfler tek run olur.
  DocxCharStyle detached() => run == null
      ? this
      : (_detached[this] ??=
          DocxCharStyle(null, null, rPr, look, patch: patch));

  static final _detached = Expando<DocxCharStyle>('docxDetached');
}

/// Tablo hücresindeki paragrafın yeri.
class DocxCellRef {
  final XmlElement table;
  final XmlElement cell;
  final int row, col;
  final int gridSpan;
  const DocxCellRef(this.table, this.cell, this.row, this.col, this.gridSpan);
}

/// Paragraf (değişmez). Düzenleme işlemleri yeni nesne döndürür.
class DocxPara {
  /// Özgün `w:p` (yeni paragrafta null).
  final XmlElement? source;

  /// Üst düğüm (`w:body`, `w:tc` …) — yeni paragraf buraya konur.
  final XmlElement container;

  /// Paragraf özellikleri (paylaşılır; değişirse kopyası).
  final XmlElement? pPr;
  final String text;
  final List<DocxCharStyle> styles;
  final List<DocxAtom?> atoms;

  /// Sıfır genişlikli çapalar: (konum, düğüm).
  final List<(int, XmlElement)> anchors;
  final DocxParaLook look;

  /// Paragraf işaretinin biçimi (boş paragrafa yazılan ilk harf).
  final DocxCharStyle mark;

  /// Düzenlenemeyen blok (içerik denetimi, iç içe tablo …).
  final bool opaque;
  final DocxCellRef? cell;

  const DocxPara({
    required this.source,
    required this.container,
    required this.pPr,
    required this.text,
    required this.styles,
    required this.atoms,
    required this.anchors,
    required this.look,
    required this.mark,
    this.opaque = false,
    this.cell,
  });

  int get length => text.length;

  DocxPara copyWith({
    XmlElement? source,
    bool clearSource = false,
    XmlElement? pPr,
    bool clearPPr = false,
    String? text,
    List<DocxCharStyle>? styles,
    List<DocxAtom?>? atoms,
    List<(int, XmlElement)>? anchors,
    DocxParaLook? look,
    DocxCharStyle? mark,
    DocxCellRef? cell,
  }) =>
      DocxPara(
        source: clearSource ? null : (source ?? this.source),
        container: container,
        pPr: clearPPr ? null : (pPr ?? this.pPr),
        text: text ?? this.text,
        styles: styles ?? this.styles,
        atoms: atoms ?? this.atoms,
        anchors: anchors ?? this.anchors,
        look: look ?? this.look,
        mark: mark ?? this.mark,
        opaque: opaque,
        cell: cell ?? this.cell,
      );

  /// [offset]'e yazılacak harfin biçimi.
  DocxCharStyle typingStyleAt(int offset) {
    for (var k = offset - 1; k >= 0; k--) {
      if (atoms[k] == null && text[k] != kDocxLineBreak) {
        return styles[k].detached();
      }
    }
    for (var k = offset; k < text.length; k++) {
      if (atoms[k] == null) return styles[k].detached();
    }
    return mark;
  }

  /// [from, to) aralığının yerine [insert] yazar.
  DocxPara replace(int from, int to, String insert, DocxCharStyle style) {
    final a = from.clamp(0, text.length), b = to.clamp(a, text.length);
    final st = [...styles]..replaceRange(a, b, List.filled(insert.length, style));
    final at = [...atoms]..replaceRange(a, b, List.filled(insert.length, null));
    final delta = insert.length - (b - a);
    final an = [
      for (final (o, e) in anchors)
        (o <= a ? o : (o >= b ? o + delta : a), e),
    ];
    return copyWith(
      text: text.substring(0, a) + insert + text.substring(b),
      styles: st,
      atoms: at,
      anchors: an,
    );
  }

  /// [offset]'te ikiye böler: (sol, sağ). Sağ yeni paragraftır (özgün
  /// düğümsüz, pPr'nin kopyası [nextPPr] verilmezse aynısı).
  (DocxPara, DocxPara) split(int offset, {XmlElement? nextPPr, DocxParaLook? nextLook}) {
    final o = offset.clamp(0, text.length);
    final left = copyWith(
      text: text.substring(0, o),
      styles: styles.sublist(0, o),
      atoms: atoms.sublist(0, o),
      anchors: [for (final x in anchors) if (x.$1 <= o) x],
    );
    final right = DocxPara(
      source: null,
      container: container,
      pPr: nextPPr ?? pPr,
      text: text.substring(o),
      styles: styles.sublist(o),
      atoms: atoms.sublist(o),
      anchors: [for (final (k, e) in anchors) if (k > o) (k - o, e)],
      look: nextLook ?? look,
      mark: mark,
      cell: cell,
    );
    return (left, right);
  }

  /// [next]'i bu paragrafın sonuna katar.
  DocxPara join(DocxPara next) => copyWith(
        text: text + next.text,
        styles: [...styles, ...next.styles],
        atoms: [...atoms, ...next.atoms],
        anchors: [
          ...anchors,
          for (final (k, e) in next.anchors) (k + text.length, e),
        ],
      );

  /// Aralıktaki harflere biçim uygular (atomlar hariç).
  DocxPara format(int from, int to,
      {bool? bold,
      bool? italic,
      bool? underline,
      DocxRunPatch patch = DocxRunPatch.none}) {
    final st = [...styles];
    // Aynı kaynak biçim aynı sonuca gider: run grupları bölünmesin.
    final memo = <DocxCharStyle, DocxCharStyle>{};
    for (var k = from.clamp(0, length); k < to.clamp(0, length); k++) {
      if (atoms[k] != null) continue;
      st[k] = memo[st[k]] ??= st[k].merge(
          bold: bold, italic: italic, underline: underline, patch: patch);
    }
    return copyWith(styles: st);
  }

  /// Aralıktaki harflerin biçimini [map] ile değiştirir (atomlar hariç).
  DocxPara mapStyles(
      int from, int to, DocxCharStyle Function(DocxCharStyle) map) {
    final st = [...styles];
    final memo = <DocxCharStyle, DocxCharStyle>{};
    for (var k = from.clamp(0, length); k < to.clamp(0, length); k++) {
      if (atoms[k] != null) continue;
      st[k] = memo[st[k]] ??= map(st[k]);
    }
    return copyWith(styles: st);
  }
}

/// Word belgesi.
class DocxDocument {
  final Archive _archive;
  final XmlDocument doc;
  final XmlElement body;
  final DocxStyles styles;
  DocxNumbering numbering;
  final Map<String, String> _rels;

  /// Biçim işlerinin dokunduğu yan parçalar (Faz 23): yalnız değişince
  /// yeniden yazılır; yoksa yaratılır (ilişki + içerik türüyle).
  final Map<String, XmlDocument> _parts = {};
  final Set<String> _dirtyParts = {};

  /// Bu oturumda eklenen ikili parçalar (resimler — Faz 24).
  final Map<String, Uint8List> _binParts = {};

  /// Belgenin düzenlenebilir akışı (gövde + tablo hücreleri, belge sırasıyla).
  List<DocxPara> paras;

  /// Her `w:p`'ye en son yazılan (ya da ondan okunan) paragraf nesnesi.
  final Map<XmlElement, DocxPara> _writtenAs = {};
  bool _xmlDirty = false;

  /// Faz 24: bu oturumda eklenen (henüz XML'e bağlanmamış olabilir) tablolar.
  /// Tablo yapısı işlemleriyle yönetilen tüm tablolar (yeni ya da var olan):
  /// `commit()` bunları paragraf modeline göre eşitler (Faz 24b).
  final List<XmlElement> _newTables = [];

  /// Geri alınabilir özellik düğümleri (`tblPr`, `tcPr`): anlık görüntüye girer.
  final List<XmlElement> _tracked = [];

  DocxDocument._(this._archive, this.doc, this.body, this.styles,
      this.numbering, this._rels, this.paras);

  /// Belge düzenlendi mi (kaydette `document.xml` yeniden yazılacak mı).
  bool get xmlDirty => _xmlDirty;

  XmlDocument? Function(String name)? _partReader;

  static DocxDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    XmlDocument? part(String name) {
      for (final f in archive.files) {
        if (f.name == name) {
          try {
            return XmlDocument.parse(
                utf8.decode(f.content as List<int>, allowMalformed: true));
          } catch (_) {
            return null;
          }
        }
      }
      return null;
    }

    final doc = part('word/document.xml');
    if (doc == null) throw const FormatException('docx: word/document.xml yok');
    XmlElement? body;
    for (final e in doc.rootElement.childElements) {
      if (e.name.local == 'body') body = e;
    }
    if (body == null) throw const FormatException('docx: w:body yok');
    final styles = DocxStyles.parse(part('word/styles.xml'), part('word/theme/theme1.xml'));
    final numbering = DocxNumbering.parse(part('word/numbering.xml'));
    final rels = <String, String>{};
    final relDoc = part('word/_rels/document.xml.rels');
    if (relDoc != null) {
      for (final r in relDoc.rootElement.childElements) {
        final id = r.getAttribute('Id');
        final t = r.getAttribute('Target');
        if (id != null && t != null && r.getAttribute('TargetMode') != 'External') {
          rels[id] = t.startsWith('/') ? t.substring(1) : 'word/$t';
        }
      }
    }
    final d = DocxDocument._(archive, doc, body, styles, numbering, rels, []);
    for (final (name, x) in [
      ('word/styles.xml', part('word/styles.xml')),
      ('word/numbering.xml', part('word/numbering.xml')),
    ]) {
      if (x != null) d._parts[name] = x;
    }
    d._partReader = part;
    d.paras = d._readBody();
    return d;
  }

  // ── okuma ───────────────────────────────────────────────────────────────

  List<DocxPara> _readBody() {
    final out = <DocxPara>[];
    for (final e in body.childElements) {
      switch (e.name.local) {
        case 'p':
          out.add(_track(_readPara(e, body, null)));
        case 'tbl':
          _readTable(e, out);
        case 'sectPr':
          break;
        default:
          final t = _textOf(e);
          if (t.trim().isNotEmpty) out.add(_opaque(e, body, null, t));
      }
    }
    if (out.isEmpty) {
      // Boş gövde: yazılabilsin diye bir paragraf (kaydette eklenir).
      out.add(_emptyPara(body));
    }
    return out;
  }

  void _readTable(XmlElement tbl, List<DocxPara> out) {
    var r = 0;
    for (final tr in tbl.childElements) {
      if (tr.name.local != 'tr') continue;
      var c = 0;
      for (final tc in tr.childElements) {
        if (tc.name.local != 'tc') continue;
        final tcPr = _child(tc, 'tcPr');
        final span = int.tryParse(_attr(_child(tcPr, 'gridSpan'), 'val') ?? '') ?? 1;
        final ref = DocxCellRef(tbl, tc, r, c, span);
        var any = false;
        for (final e in tc.childElements) {
          if (e.name.local == 'p') {
            out.add(_track(_readPara(e, tc, ref)));
            any = true;
          } else if (e.name.local != 'tcPr') {
            final t = _textOf(e);
            if (t.trim().isNotEmpty) {
              out.add(_opaque(e, tc, ref, t));
              any = true;
            }
          }
        }
        if (!any) out.add(_emptyPara(tc, cell: ref));
        c += span;
      }
      r++;
    }
  }

  DocxPara _track(DocxPara p) {
    if (p.source != null) _writtenAs[p.source!] = p;
    return p;
  }

  DocxPara _opaque(XmlElement e, XmlElement container, DocxCellRef? cell,
          String text) =>
      DocxPara(
        source: e,
        container: container,
        pPr: null,
        text: text,
        styles: List.filled(text.length, _plainStyle),
        atoms: List.filled(text.length, null),
        anchors: const [],
        look: const DocxParaLook(),
        mark: _plainStyle,
        opaque: true,
        cell: cell,
      );

  late final DocxCharStyle _plainStyle =
      DocxCharStyle(null, null, null, styles.runLook(null, null));

  DocxPara _emptyPara(XmlElement container, {DocxCellRef? cell}) => DocxPara(
        source: null,
        container: container,
        pPr: null,
        text: '',
        styles: const [],
        atoms: const [],
        anchors: const [],
        look: styles.paraLook(null),
        mark: _plainStyle,
        cell: cell,
      );

  DocxPara _readPara(XmlElement p, XmlElement container, DocxCellRef? cell) {
    final pPr = _child(p, 'pPr');
    final markRPr = _child(pPr, 'rPr');
    final mark = DocxCharStyle(null, null, markRPr, styles.runLook(pPr, markRPr));
    final sb = StringBuffer();
    final st = <DocxCharStyle>[];
    final at = <DocxAtom?>[];
    final an = <(int, XmlElement)>[];

    void text(String s, DocxCharStyle style) {
      sb.write(s);
      st.addAll(List.filled(s.length, style));
      at.addAll(List.filled(s.length, null));
    }

    void atom(DocxAtom a, DocxCharStyle style) {
      sb.write(kDocxAtom);
      st.add(style);
      at.add(a);
    }

    // Karmaşık alan (fldChar begin … end) birden çok run'a yayılır: hepsi
    // tek atom.
    List<XmlElement>? field;
    var depth = 0;
    var fieldResult = StringBuffer();
    var afterSeparate = false;

    for (final e in p.childElements) {
      final local = e.name.local;
      if (local == 'pPr') continue;
      if (local == 'r') {
        final chars = _fieldChars(e);
        if (field != null || chars.contains('begin')) {
          field ??= [];
          field.add(e);
          for (final c in chars) {
            if (c == 'begin') depth++;
            if (c == 'separate' && depth == 1) afterSeparate = true;
            if (c == 'end') depth--;
          }
          if (afterSeparate && !chars.contains('separate')) {
            fieldResult.write(_runText(e));
          }
          if (depth <= 0) {
            atom(DocxAtom(DocxAtomKind.field, field, fieldResult.toString()),
                mark);
            field = null;
            depth = 0;
            fieldResult = StringBuffer();
            afterSeparate = false;
          }
          continue;
        }
        _readRun(e, pPr, text, atom, (x) => an.add((sb.length, x)));
        continue;
      }
      if (field != null) {
        field.add(e);
        continue;
      }
      final t = _textOf(e);
      switch (local) {
        case 'hyperlink':
          atom(DocxAtom(DocxAtomKind.link, [e], t), mark);
        case 'fldSimple':
          atom(DocxAtom(DocxAtomKind.field, [e], t), mark);
        default:
          if (t.isEmpty && !_hasVisual(e)) {
            an.add((sb.length, e));
          } else {
            atom(_visualAtom(e, [e], t), mark);
          }
      }
    }
    if (field != null) {
      // Kapanmamış alan: olduğu gibi atom.
      atom(DocxAtom(DocxAtomKind.field, field, fieldResult.toString()), mark);
    }
    return DocxPara(
      source: p,
      container: container,
      pPr: pPr,
      text: sb.toString(),
      styles: st,
      atoms: at,
      anchors: an,
      look: styles.paraLook(pPr),
      mark: mark,
      cell: cell,
    );
  }

  void _readRun(
    XmlElement r,
    XmlElement? pPr,
    void Function(String, DocxCharStyle) text,
    void Function(DocxAtom, DocxCharStyle) atom,
    void Function(XmlElement) anchor,
  ) {
    final rPr = _child(r, 'rPr');
    final look = styles.runLook(pPr, rPr);
    // Run yalnız metin üretiyorsa (atom/çapa yoksa) aynen yeniden kullanılabilir.
    var simple = true;
    final buf = StringBuffer();
    for (final c in r.childElements) {
      switch (c.name.local) {
        case 'rPr' || 'lastRenderedPageBreak':
          break;
        case 't':
          buf.write(c.innerText);
        case 'tab':
          buf.write('\t');
        case 'br' when _attr(c, 'type') == null || _attr(c, 'type') == 'textWrapping':
          buf.write(kDocxLineBreak);
        case 'cr':
          buf.write(kDocxLineBreak);
        case 'noBreakHyphen':
          buf.write('‑');
        case 'softHyphen':
          buf.write('­');
        default:
          simple = false;
      }
    }
    final style = DocxCharStyle(r, simple ? buf.toString() : null, rPr, look);
    if (simple) {
      text(buf.toString(), style);
      return;
    }
    XmlElement wrap(XmlElement child) => XmlElement(XmlName.fromString('w:r'), [], [
          if (rPr != null) rPr.copy(),
          child.copy(),
        ]);
    for (final c in r.childElements) {
      final local = c.name.local;
      switch (local) {
        case 'rPr' || 'lastRenderedPageBreak':
          break;
        case 't':
          text(c.innerText, style);
        case 'tab':
          text('\t', style);
        case 'br' when _attr(c, 'type') == null || _attr(c, 'type') == 'textWrapping':
          text(kDocxLineBreak, style);
        case 'cr':
          text(kDocxLineBreak, style);
        case 'noBreakHyphen':
          text('‑', style);
        case 'softHyphen':
          text('­', style);
        case 'br':
          atom(DocxAtom(DocxAtomKind.pageBreak, [wrap(c)], ''), style);
        case 'footnoteReference' || 'endnoteReference':
          atom(DocxAtom(DocxAtomKind.note, [wrap(c)], _attr(c, 'id') ?? '*'),
              style);
        case 'commentReference':
          atom(DocxAtom(DocxAtomKind.comment, [wrap(c)], _attr(c, 'id') ?? ''),
              style);
        case 'sym':
          atom(
              DocxAtom(
                  DocxAtomKind.inline,
                  [wrap(c)],
                  mapSymbolFont(
                      String.fromCharCode(
                          int.tryParse(_attr(c, 'char') ?? '', radix: 16) ??
                              0x2022),
                      _attr(c, 'font'))),
              style);
        default:
          final t = _textOf(c);
          if (t.isEmpty && !_hasVisual(c)) {
            anchor(wrap(c));
          } else {
            atom(_visualAtom(c, [wrap(c)], t), style);
          }
      }
    }
  }

  /// Resim ise resim atomu, değilse metinli satır içi atom.
  DocxAtom _visualAtom(XmlElement probe, List<XmlElement> nodes, String text) {
    for (final e in probe.descendantElements) {
      if (e.name.local != 'blip') continue;
      final rid = e.getAttribute('r:embed') ??
          e.getAttribute('embed',
              namespace:
                  'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
      final target = rid == null ? null : _rels[rid];
      Uint8List? bytes;
      if (target != null) {
        for (final f in _archive.files) {
          if (f.name == target) {
            bytes = Uint8List.fromList(f.content as List<int>);
            break;
          }
        }
      }
      double w = 0, h = 0;
      for (final x in probe.descendantElements) {
        if (x.name.local == 'extent') {
          w = (double.tryParse(x.getAttribute('cx') ?? '') ?? 0) / 12700;
          h = (double.tryParse(x.getAttribute('cy') ?? '') ?? 0) / 12700;
          break;
        }
      }
      return DocxAtom(DocxAtomKind.image, nodes, '',
          image: bytes, widthPt: w, heightPt: h);
    }
    return DocxAtom(DocxAtomKind.inline, nodes, text);
  }

  static bool _hasVisual(XmlElement e) => e.descendantElements.any((x) =>
      const {'drawing', 'pict', 'object', 'blip', 'oMath', 'footnoteReference'}
          .contains(x.name.local));

  static List<String> _fieldChars(XmlElement r) => [
        for (final c in r.childElements)
          if (c.name.local == 'fldChar') _attr(c, 'fldCharType') ?? '',
      ];

  static String _runText(XmlElement r) {
    final sb = StringBuffer();
    for (final c in r.childElements) {
      if (c.name.local == 't') sb.write(c.innerText);
      if (c.name.local == 'tab') sb.write('\t');
    }
    return sb.toString();
  }

  /// Bir düğümün görünen metni (`w:t`, sekme; silinmiş metin hariç).
  static String _textOf(XmlElement e) {
    final sb = StringBuffer();
    void walk(XmlElement x) {
      for (final c in x.childElements) {
        switch (c.name.local) {
          case 't':
            sb.write(c.innerText);
          case 'tab':
            sb.write('\t');
          case 'del' || 'delText' || 'instrText':
            break;
          case 'p':
            if (sb.isNotEmpty) sb.write('\n');
            walk(c);
          default:
            walk(c);
        }
      }
    }

    walk(e);
    return sb.toString();
  }

  // ── liste etiketleri ─────────────────────────────────────────────────────

  /// Paragrafların liste etiketleri (belge sırasıyla sayılır).
  List<String> listLabels() => numbering.labels([
        for (final p in paras) (p.opaque ? null : p.look.numId, p.look.ilvl),
      ]);

  /// Enter'da yeni paragrafın pPr'i: başlık stilinde `w:next` stili.
  (XmlElement?, DocxParaLook) nextParagraphProps(DocxPara p) {
    final id = p.look.styleId;
    final next = styles.nextStyleOf(id);
    if (p.look.headingLevel == 0 || next == null || next == id) {
      return (p.pPr, p.look);
    }
    final pPr = (p.pPr?.copy() ?? XmlElement(XmlName.fromString('w:pPr')));
    _setPStyle(pPr, next);
    return (pPr, styles.paraLook(pPr));
  }

  /// Boş liste öğesinde Enter: paragraf listeden çıkar (numPr kalkar).
  DocxPara withoutList(DocxPara p) {
    final pPr = p.pPr?.copy() ?? XmlElement(XmlName.fromString('w:pPr'));
    pPr.children.removeWhere((n) => n is XmlElement && n.name.local == 'numPr');
    // Stilden gelen liste de kapansın: numId 0. (Sınama KOPYADA: görünüş
    // pPr düğümü başına önbelleklenir.)
    if (styles.paraLook(pPr.copy()).numId != null) {
      pPr.children.add(XmlElement(XmlName.fromString('w:numPr'), [], [
        XmlElement(XmlName.fromString('w:numId'), [XmlAttribute(XmlName.fromString('w:val'), '0')]),
      ]));
    }
    return p.copyWith(pPr: pPr, look: styles.paraLook(pPr));
  }

  static void _setPStyle(XmlElement pPr, String id) {
    var ps = _child(pPr, 'pStyle');
    if (ps == null) {
      ps = XmlElement(XmlName.fromString('w:pStyle'));
      pPr.children.insert(0, ps);
    }
    ps.setAttribute('w:val', id);
  }


  // ── paragraf biçimi (Faz 23) ────────────────────────────────────────────

  /// `w:pPr` şema sırası (CT_PPr).
  static const _pPrOrder = [
    'pStyle', 'keepNext', 'keepLines', 'pageBreakBefore', 'framePr',
    'widowControl', 'numPr', 'suppressLineNumbers', 'pBdr', 'shd', 'tabs',
    'suppressAutoHyphens', 'kinsoku', 'wordWrap', 'overflowPunct',
    'topLinePunct', 'autoSpaceDE', 'autoSpaceDN', 'bidi', 'adjustRightInd',
    'snapToGrid', 'spacing', 'ind', 'contextualSpacing', 'mirrorIndents',
    'suppressOverlap', 'jc', 'textDirection', 'textAlignment',
    'textboxTightWrap', 'outlineLvl', 'divId', 'cnfStyle', 'rPr', 'sectPr',
    'pPrChange',
  ];

  static XmlElement _w(String local, [Map<String, String> attrs = const {}]) =>
      XmlElement(XmlName.fromString('w:$local'), [
        for (final MapEntry(:key, :value) in attrs.entries)
          XmlAttribute(XmlName.fromString('w:$key'), value),
      ]);

  static void _putP(XmlElement pPr, XmlElement el) {
    pPr.children.removeWhere(
        (n) => n is XmlElement && n.name.local == el.name.local);
    final rank = _pPrOrder.indexOf(el.name.local);
    final kids = pPr.children;
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      if (k is! XmlElement) continue;
      final r = _pPrOrder.indexOf(k.name.local);
      if (r > rank) {
        kids.insert(i, el);
        return;
      }
    }
    kids.add(el);
  }

  static void _dropP(XmlElement pPr, String local) => pPr.children
      .removeWhere((n) => n is XmlElement && n.name.local == local);

  /// pPr'nin kopyası üzerinde [edit]; görünüş yeniden çözülür. Paragraf
  /// stili değiştiyse harflerin görünüşü de (stilden gelen biçim).
  DocxPara editPPr(DocxPara p, void Function(XmlElement pPr) edit) {
    if (p.opaque) return p;
    final pPr = p.pPr?.copy() ?? XmlElement(XmlName.fromString('w:pPr'));
    edit(pPr);
    final look = styles.paraLook(pPr);
    if (look.styleId == p.look.styleId) {
      return p.copyWith(pPr: pPr, look: look);
    }
    final memo = <DocxCharStyle, DocxCharStyle>{};
    DocxCharStyle re(DocxCharStyle c) =>
        memo[c] ??= c.withLook(styles.runLook(pPr, c.rPr));
    return p.copyWith(
      pPr: pPr,
      look: look,
      styles: [for (final c in p.styles) re(c)],
      mark: re(p.mark),
    );
  }

  /// Hizalama: `left` | `center` | `right` | `both`.
  DocxPara setAlign(DocxPara p, String align) => editPPr(p, (pPr) {
        _putP(pPr, _w('jc', {'val': align}));
      });

  /// Satır aralığı çarpanı (1,0 / 1,15 / 1,5 / 2,0).
  DocxPara setLineSpacing(DocxPara p, double multiple) => editPPr(p, (pPr) {
        final sp = _child(pPr, 'spacing')?.copy() ?? _w('spacing');
        sp.setAttribute('w:line', '${(multiple * 240).round()}');
        sp.setAttribute('w:lineRule', 'auto');
        _putP(pPr, sp);
      });

  /// Paragraf öncesi / sonrası boşluk (punto).
  DocxPara setSpacing(DocxPara p, {double? beforePt, double? afterPt}) =>
      editPPr(p, (pPr) {
        final sp = _child(pPr, 'spacing')?.copy() ?? _w('spacing');
        if (beforePt != null) sp.setAttribute('w:before', '${(beforePt * 20).round()}');
        if (afterPt != null) sp.setAttribute('w:after', '${(afterPt * 20).round()}');
        _putP(pPr, sp);
      });

  /// Sağdan sola paragraf (`w:bidi`).
  DocxPara setBidi(DocxPara p, bool on) => editPPr(p, (pPr) {
        if (on) {
          _putP(pPr, _w('bidi'));
        } else if (styles.paraLook(p.pPr).bidi) {
          _putP(pPr, _w('bidi', {'val': '0'}));
        } else {
          _dropP(pPr, 'bidi');
        }
      });

  /// Girinti: listede düzey (0–8), değilse sol girinti ±0,5 inç.
  DocxPara indent(DocxPara p, int delta) {
    if (p.look.numId != null) {
      final lvl = (p.look.ilvl + delta).clamp(0, 8);
      return editPPr(p, (pPr) {
        _putP(
            pPr,
            _w('numPr')
              ..children.addAll([
                _w('ilvl', {'val': '$lvl'}),
                _w('numId', {'val': '${p.look.numId}'}),
              ]));
      });
    }
    final left = math.max(0.0, p.look.indentLeftPt + delta * 36);
    return editPPr(p, (pPr) {
      final ind = _child(pPr, 'ind')?.copy() ?? _w('ind');
      ind.removeAttribute('w:start');
      ind.setAttribute('w:left', '${(left * 20).round()}');
      _putP(pPr, ind);
    });
  }

  /// Paragraf stili uygular (`w:pStyle`). Stilden gelen biçim harflere
  /// GÖMÜLMEZ (yalnız görünüş yeniden çözülür); sanal yerleşik stil önce
  /// `styles.xml`'e yazılır.
  DocxPara applyStyle(DocxPara p, String styleId) {
    _materializeStyle(styleId);
    return editPPr(p, (pPr) {
      if (styleId == styles.defaultParagraphStyle) {
        _dropP(pPr, 'pStyle');
      } else {
        _putP(pPr, _w('pStyle', {'val': styleId}));
      }
    });
  }

  void _materializeStyle(String id) {
    if (!styles.isVirtual(id)) return;
    final el = styles.materialize(id);
    if (el == null) return;
    final x = _partOrCreate('word/styles.xml');
    x.rootElement.children.add(el.copy());
    _dirtyParts.add('word/styles.xml');
  }

  /// Doğrudan harf biçimini temizler ("Biçimi temizle"): run biçimi ve
  /// karakter stili kalkar, paragraf stilinin biçimi kalır.
  DocxPara clearFormatting(DocxPara p, int from, int to) {
    final plain = DocxCharStyle(null, null, null, styles.runLook(p.pPr, null));
    return p.mapStyles(from, to, (_) => plain);
  }

  /// Biçim boyacısı: [src]'nin harf biçimi (rPr şablonu + örtmeler) hedef
  /// paragrafın stiliyle yeniden çözülür.
  DocxPara paintFormat(DocxPara p, int from, int to, DocxCharStyle src) {
    final st = DocxCharStyle(null, null, src.rPr, styles.runLook(p.pPr, src.rPr),
        patch: src.patch);
    return p.mapStyles(from, to, (_) => st);
  }

  // ── listeler ─────────────────────────────────────────────────────────────

  /// Paragrafın liste türü: `bullet` | `number` | `multi` | null.
  String? listKind(DocxPara p) {
    final id = p.look.numId;
    if (id == null) return null;
    final k = _ourKinds[id];
    if (k != null) return k;
    return numbering.isBullet(id, p.look.ilvl) ? 'bullet' : 'number';
  }

  /// Bu oturumda yaratılan listeler (numId → tür).
  final Map<int, String> _ourKinds = {};

  /// [kind] listesini paragrafa uygular; komşusu aynı türde listeyse onun
  /// numarasını sürdürür (Word'deki "numaralandırmaya devam et").
  DocxPara setList(DocxPara p, String kind, {DocxPara? prev, DocxPara? next}) {
    int? reuse;
    for (final n in [prev, next]) {
      if (n != null && !n.opaque && listKind(n) == kind) {
        reuse = n.look.numId;
        break;
      }
    }
    final numId = reuse ?? _newList(kind);
    final lvl = p.look.numId != null ? p.look.ilvl : 0;
    return editPPr(p, (pPr) {
      _putP(
          pPr,
          _w('numPr')
            ..children.addAll([
              _w('ilvl', {'val': '$lvl'}),
              _w('numId', {'val': '$numId'}),
            ]));
    });
  }

  static const _wNs =
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

  int _newList(String kind) {
    final x = _partOrCreate('word/numbering.xml');
    final root = x.rootElement;
    int maxOf(String local, String attr) {
      var m = 0;
      for (final e in root.childElements) {
        if (e.name.local != local) continue;
        final v = int.tryParse(e.getAttribute('w:$attr') ?? '') ?? 0;
        if (v > m) m = v;
      }
      return m;
    }

    final abs = maxOf('abstractNum', 'abstractNumId') + 1;
    final numId = maxOf('num', 'numId') + 1;
    final lvls = StringBuffer();
    const bullets = ['•', 'o', '▪'];
    const fmts = ['decimal', 'lowerLetter', 'lowerRoman'];
    for (var i = 0; i < 9; i++) {
      final left = 720 * (i + 1);
      final String fmt, text;
      switch (kind) {
        case 'bullet':
          fmt = 'bullet';
          text = bullets[i % 3];
        case 'multi':
          fmt = 'decimal';
          text = '${[for (var k = 1; k <= i + 1; k++) '%$k'].join('.')}.';
        default:
          fmt = fmts[i % 3];
          text = '%${i + 1}.';
      }
      lvls.write('<w:lvl w:ilvl="$i"><w:start w:val="1"/>'
          '<w:numFmt w:val="$fmt"/><w:lvlText w:val="$text"/>'
          '<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="$left" '
          'w:hanging="360"/></w:pPr>'
          '${fmt == 'bullet' && text == 'o' ? '<w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/></w:rPr>' : ''}'
          '</w:lvl>');
    }
    final frag = XmlDocument.parse('<w:numbering $_wNs>'
            '<w:abstractNum w:abstractNumId="$abs">'
            '<w:multiLevelType w:val="${kind == 'bullet' ? 'hybridMultilevel' : 'multilevel'}"/>'
            '$lvls</w:abstractNum>'
            '<w:num w:numId="$numId"><w:abstractNumId w:val="$abs"/></w:num>'
            '</w:numbering>')
        .rootElement;
    final absEl = frag.childElements.first.copy();
    final numEl = frag.childElements.last.copy();
    // Şema: abstractNum'lar num'lardan önce.
    final kids = root.children;
    var firstNum = kids.indexWhere(
        (n) => n is XmlElement && n.name.local == 'num');
    if (firstNum < 0) {
      firstNum = kids.indexWhere(
          (n) => n is XmlElement && n.name.local == 'numIdMacAtCleanup');
    }
    if (firstNum < 0) {
      kids.add(absEl);
    } else {
      kids.insert(firstNum, absEl);
    }
    final cleanup = kids.indexWhere(
        (n) => n is XmlElement && n.name.local == 'numIdMacAtCleanup');
    if (cleanup < 0) {
      kids.add(numEl);
    } else {
      kids.insert(cleanup, numEl);
    }
    _dirtyParts.add('word/numbering.xml');
    numbering = DocxNumbering.parse(x);
    _ourKinds[numId] = kind;
    return numId;
  }

  // ── yan parçalar ─────────────────────────────────────────────────────────

  static const _partInfo = {
    'word/styles.xml': (
      'styles',
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml',
    ),
    'word/numbering.xml': (
      'numbering',
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml',
    ),
  };

  /// Parça yoksa yaratır: kökü + `document.xml.rels` ilişkisi + içerik türü.
  XmlDocument _partOrCreate(String name) {
    final have = _parts[name];
    if (have != null) return have;
    final (root, relType, contentType) = _partInfo[name]!;
    final x = XmlDocument.parse(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:$root $_wNs/>');
    _parts[name] = x;
    _dirtyParts.add(name);
    final rels = _parts['word/_rels/document.xml.rels'] ??
        _partReader?.call('word/_rels/document.xml.rels') ??
        XmlDocument.parse(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>');
    _parts['word/_rels/document.xml.rels'] = rels;
    var maxId = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) maxId = math.max(maxId, int.parse(m[1]!));
    }
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rId${maxId + 1}'),
      XmlAttribute(XmlName('Type'), relType),
      XmlAttribute(XmlName('Target'), name.substring('word/'.length)),
    ]));
    _dirtyParts.add('word/_rels/document.xml.rels');
    final ct = _parts['[Content_Types].xml'] ??
        _partReader?.call('[Content_Types].xml');
    if (ct != null) {
      ct.rootElement.children.add(XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), '/$name'),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]));
      _parts['[Content_Types].xml'] = ct;
      _dirtyParts.add('[Content_Types].xml');
    }
    return x;
  }

  // ── yazma ───────────────────────────────────────────────────────────────

  /// Modeli XML'e işler: yalnız değişen paragraflar yeniden kurulur, yeni
  /// paragraflar yerine konur, birleşip kaybolanlar çıkarılır.
  void commit() {
    final used = <XmlElement>{};
    final usedRuns = <XmlElement>{};
    final targets = List<XmlElement?>.filled(paras.length, null);
    var changed = false;
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      if (p.opaque) {
        targets[i] = p.source;
        if (p.source != null) used.add(p.source!);
        continue;
      }
      var el = p.source;
      final fresh = el == null || used.contains(el);
      if (fresh) el = XmlElement(XmlName.fromString('w:p'));
      final stale = fresh ||
          el.parent == null ||
          !identical(_writtenAs[el], p);
      if (stale) {
        _rebuild(el, p, usedRuns);
        changed = true;
      }
      used.add(el);
      targets[i] = el;
      if (!identical(p.source, el)) {
        paras[i] = p.copyWith(source: el);
      }
      _writtenAs[el] = paras[i];
    }
    // Birleşip ya da silinip modelden çıkan paragraflar XML'den de çıkar.
    for (final el in _writtenAs.keys.toList()) {
      if (used.contains(el)) continue;
      if (el.parent != null) {
        el.parent!.children.remove(el);
        changed = true;
      }
      _writtenAs.remove(el);
    }
    // Yerine konmamış (yeni ya da geri alınmış) paragraflar.
    for (var i = 0; i < paras.length; i++) {
      final el = targets[i];
      if (el == null || el.parent != null) continue;
      _place(el, i, targets);
      changed = true;
    }
    if (_syncNewTables()) changed = true;
    if (changed) _xmlDirty = true;
  }

  void _place(XmlElement el, int i, List<XmlElement?> targets) {
    final container = paras[i].container;
    for (var j = i - 1; j >= 0; j--) {
      final prev = targets[j];
      if (!identical(paras[j].container, container)) break;
      if (prev != null && identical(prev.parent, container)) {
        container.children.insert(container.children.indexOf(prev) + 1, el);
        return;
      }
    }
    for (var j = i + 1; j < paras.length; j++) {
      final next = targets[j];
      if (!identical(paras[j].container, container)) break;
      if (next != null && identical(next.parent, container)) {
        container.children.insert(container.children.indexOf(next), el);
        return;
      }
    }
    // Kapsayıcının sonuna (gövdede bölüm özelliklerinden önce).
    final kids = container.children;
    for (var k = 0; k < kids.length; k++) {
      final x = kids[k];
      if (x is XmlElement && x.name.local == 'sectPr') {
        kids.insert(k, el);
        return;
      }
    }
    kids.add(el);
  }

  void _rebuild(XmlElement el, DocxPara p, Set<XmlElement> usedRuns) {
    // pPr: başka paragrafa aitse kopyalanır.
    XmlElement? pPr = p.pPr;
    if (pPr != null && pPr.parent != null && !identical(pPr.parent, el)) {
      pPr = pPr.copy();
    }
    el.children.clear();
    void add(XmlElement n) {
      n.parent?.children.remove(n);
      el.children.add(n);
    }

    if (pPr != null) add(pPr);
    final anchorsAt = <int, List<XmlElement>>{};
    for (final (o, e) in p.anchors) {
      (anchorsAt[o.clamp(0, p.length)] ??= []).add(e);
    }
    var k = 0;
    while (k <= p.length) {
      for (final a in anchorsAt[k] ?? const <XmlElement>[]) {
        add(a);
      }
      if (k == p.length) break;
      final atom = p.atoms[k];
      if (atom != null) {
        for (final n in atom.nodes) {
          add(n);
        }
        k++;
        continue;
      }
      // Aynı YAZIM biçimli harf grubu (atom ya da çapa gelene dek): aynı
      // rPr şablonu + aynı örtmeler tek run olur — bir kelimenin ortasına
      // yazmak run'ı üçe bölmesin.
      final style = p.styles[k];
      var j = k + 1;
      var sameRun = true;
      while (j < p.length &&
          p.atoms[j] == null &&
          _sameWrite(p.styles[j], style) &&
          !anchorsAt.containsKey(j)) {
        sameRun &= identical(p.styles[j], style);
        j++;
      }
      final text = p.text.substring(k, j);
      final run = style.run;
      if (run != null &&
          sameRun &&
          style.plain &&
          style.runText == text &&
          !usedRuns.contains(run)) {
        usedRuns.add(run);
        add(run);
      } else {
        add(_newRun(style, text));
      }
      k = j;
    }
  }

  static bool _sameWrite(DocxCharStyle a, DocxCharStyle b) =>
      identical(a, b) ||
      (identical(a.rPr, b.rPr) && a.patch == b.patch);

  static XmlElement _newRun(DocxCharStyle style, String text) {
    final rPr = style.rPr?.copy() ?? XmlElement(XmlName.fromString('w:rPr'));
    // Paragraf işaretinin rPr'ine (`w:pPr/w:rPr`) özgü öğeler run'da geçersiz.
    rPr.children.removeWhere((n) =>
        n is XmlElement &&
        const {'ins', 'del', 'moveFrom', 'moveTo', 'rPrChange'}
            .contains(n.name.local));
    if (style.bold != null) _setToggle(rPr, 'b', style.bold!);
    if (style.italic != null) _setToggle(rPr, 'i', style.italic!);
    if (style.underline != null) {
      rPr.children.removeWhere((n) => n is XmlElement && n.name.local == 'u');
      _putOrdered(rPr,
          XmlElement(XmlName.fromString('w:u'), [XmlAttribute(XmlName.fromString('w:val'), style.underline! ? 'single' : 'none')]));
    }
    final pt = style.patch;
    if (pt.strike != null) _setToggle(rPr, 'strike', pt.strike!);
    void put(String local, Map<String, String>? attrs, {List<String> drop = const []}) {
      rPr.children.removeWhere((n) =>
          n is XmlElement &&
          (n.name.local == local || drop.contains(n.name.local)));
      if (attrs != null) _putOrdered(rPr, _w(local, attrs));
    }

    if (pt.color != null) {
      final c = pt.color!;
      put('color', {
        'val': c == DocxRunPatch.autoColor
            ? 'auto'
            : (c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase(),
      });
    }
    if (pt.highlight != null) {
      // Vurgu kaldırılınca gölgelendirme dolgusu da (o da vurgu gibi görünür).
      put('highlight', pt.highlight!.isEmpty ? null : {'val': pt.highlight!},
          drop: pt.highlight!.isEmpty ? const ['shd'] : const []);
    }
    if (pt.sizePt != null) {
      final hp = '${(pt.sizePt! * 2).round()}';
      put('sz', {'val': hp});
      put('szCs', {'val': hp});
    }
    if (pt.font != null) {
      final f = pt.font!;
      put('rFonts', {'ascii': f, 'hAnsi': f, 'cs': f});
    }
    if (pt.vertAlign != null) {
      put('vertAlign', pt.vertAlign!.isEmpty ? null : {'val': pt.vertAlign!});
    }
    final r = XmlElement(XmlName.fromString('w:r'));
    if (rPr.childElements.isNotEmpty || rPr.attributes.isNotEmpty) {
      r.children.add(rPr);
    }
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      final s = buf.toString();
      r.children.add(XmlElement(XmlName.fromString('w:t'), [
        if (s.trim() != s || s.contains('  '))
          XmlAttribute(XmlName.fromString('xml:space'), 'preserve'),
      ], [XmlText(s)]));
      buf.clear();
    }

    for (final ch in text.split('')) {
      switch (ch) {
        case '\t':
          flush();
          r.children.add(XmlElement(XmlName.fromString('w:tab')));
        case kDocxLineBreak:
          flush();
          r.children.add(XmlElement(XmlName.fromString('w:br')));
        case '‑':
          flush();
          r.children.add(XmlElement(XmlName.fromString('w:noBreakHyphen')));
        case '­':
          flush();
          r.children.add(XmlElement(XmlName.fromString('w:softHyphen')));
        default:
          buf.write(ch);
      }
    }
    flush();
    return r;
  }

  /// `w:rPr` şema sırası (yalnız bizim yazdıklarımız için gereken kısmı).
  static const _rPrOrder = [
    'rStyle', 'rFonts', 'b', 'bCs', 'i', 'iCs', 'caps', 'smallCaps', 'strike',
    'dstrike', 'outline', 'shadow', 'emboss', 'imprint', 'noProof',
    'snapToGrid', 'vanish', 'webHidden', 'color', 'spacing', 'w', 'kern',
    'position', 'sz', 'szCs', 'highlight', 'u', 'effect', 'bdr', 'shd',
    'fitText', 'vertAlign', 'rtl', 'cs', 'em', 'lang', 'eastAsianLayout',
    'specVanish', 'oMath',
  ];

  static void _putOrdered(XmlElement rPr, XmlElement el) {
    final rank = _rPrOrder.indexOf(el.name.local);
    final kids = rPr.children;
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      if (k is! XmlElement) continue;
      final r = _rPrOrder.indexOf(k.name.local);
      if (r > rank || r < 0) {
        kids.insert(i, el);
        return;
      }
    }
    kids.add(el);
  }

  static void _setToggle(XmlElement rPr, String name, bool on) {
    rPr.children.removeWhere((n) => n is XmlElement && n.name.local == name);
    _putOrdered(
        rPr,
        XmlElement(XmlName.fromString('w:$name'), [
          if (!on) XmlAttribute(XmlName.fromString('w:val'), '0'),
        ]));
  }

  /// Paket: `document.xml` yalnız değiştiyse yeniden yazılır.
  Archive buildArchive() {
    commit();
    _pruneNotes();
    final replaced = <String, List<int>>{
      ..._binParts,
      if (_xmlDirty) 'word/document.xml': utf8.encode(doc.toXmlString()),
      for (final name in _dirtyParts)
        name: utf8.encode(_parts[name]!.toXmlString()),
    };
    final out = Archive();
    for (final f in _archive.files) {
      final data = replaced.remove(f.name);
      out.addFile(data == null ? f : ArchiveFile(f.name, data.length, data));
    }
    // Yeni yaratılan parçalar (numbering.xml …).
    for (final MapEntry(key: name, value: data) in replaced.entries) {
      out.addFile(ArchiveFile(name, data.length, data));
    }
    return out;
  }

  Uint8List save() =>
      Uint8List.fromList(ZipEncoder().encode(buildArchive()) ?? const <int>[]);

  /// XML yazımı UI izleğinde (yalnız değişen paragraflar, hızlı), zip izolatta.
  Future<Uint8List> saveAsync() => SaveIsolate.encodeZip(buildArchive());

  /// Belgenin düz metni (paragraf başına satır; atomlar görünen metinleriyle).
  String plainText() => [
        for (final p in paras)
          [
            for (var k = 0; k < p.length; k++)
              p.atoms[k]?.display ?? p.text[k],
          ].join().replaceAll(kDocxLineBreak, '\n'),
      ].join('\n');

  // ── yardımcılar ─────────────────────────────────────────────────────────

  static XmlElement? _child(XmlElement? e, String local) {
    if (e == null) return null;
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  static String? _attr(XmlElement? e, String local) {
    if (e == null) return null;
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }
}
