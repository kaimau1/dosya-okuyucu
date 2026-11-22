part of 'docx_document.dart';

/// Faz 24 (kalan) — resim, yorum, dipnot, yatay çizgi.
///
/// * **Resim:** satır içi `wp:inline` (yeni parça `word/media/imageN.ext` +
///   ilişki + içerik türü). Boyutlandırma oran kilitli: atomun düğümlerinin
///   KOPYASINDA `wp:extent` + `a:xfrm/a:ext` güncellenir — değişmez model
///   bozulmaz, geri al bedava.
/// * **Yorum:** `comments.xml` (+ çözüldü / yanıt için `commentsExtended.xml`).
///   Belgedeki iz: `commentRangeStart/End` çapaları + `commentReference` atomu.
///   Silme yalnız modeldeki izi kaldırır; başvurusu kalmayan yorum kaydette
///   parçadan budanır ([_pruneNotes]) — böylece geri al yorumu geri getirir.
/// * **Dipnot / sonnot:** `footnotes.xml` / `endnotes.xml` (yoksa Word'ün
///   ayırıcılarıyla yaratılır). Numara belge sırasıyla ([DocxMedia.noteLabels]);
///   silinen notun başvurusu modelden kalkar, not kaydedilen kopyadan budanır.

const _wpNs =
    'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _picNs = 'http://schemas.openxmlformats.org/drawingml/2006/picture';
const _w14Ns = 'http://schemas.microsoft.com/office/word/2010/wordml';
const _w15Ns = 'http://schemas.microsoft.com/office/word/2012/wordml';
const _relBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ctBase = 'application/vnd.openxmlformats-officedocument.wordprocessingml';

const _imageMimes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'webp': 'image/webp',
};

/// Bir yorum (yanıtlar [parentId] ile bağlı).
class DocxComment {
  final String id;
  final String author;
  final String date;
  final String text;
  final bool done;
  final String? parentId;
  const DocxComment(this.id, this.author, this.date, this.text, this.done,
      this.parentId);
}

/// Oturumda yorum/dipnot parçasına dokunuldu mu (kaydette budama).
final _commentsTouched = Expando<bool>('docxCommentsTouched');

/// Oturumda dipnot/sonnot eklendi ya da silindi mi (kaydette budama).
final _notesTouched = Expando<bool>('docxNotesTouched');

/// Sonnot anahtarı öneki: dipnot anahtarı = `w:id`, sonnot = `e:<w:id>`.
const kDocxEndnoteKey = 'e:';

/// Not numarası Word biçiminde: `decimal`, `lowerRoman`/`upperRoman`,
/// `lowerLetter`/`upperLetter`, `chicago` (* † ‡ §); bilinmeyen → onluk.
String docxNoteNumber(String fmt, int n) {
  if (n < 1) return '$n';
  switch (fmt) {
    case 'lowerRoman' || 'upperRoman':
      const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
      const r = ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i'];
      final sb = StringBuffer();
      var m = n;
      for (var i = 0; i < v.length; i++) {
        while (m >= v[i]) {
          sb.write(r[i]);
          m -= v[i];
        }
      }
      return fmt == 'upperRoman' ? sb.toString().toUpperCase() : sb.toString();
    case 'lowerLetter' || 'upperLetter':
      // Word: a … z, aa … zz, aaa …
      final ch = String.fromCharCode(0x61 + (n - 1) % 26) * ((n - 1) ~/ 26 + 1);
      return fmt == 'upperLetter' ? ch.toUpperCase() : ch;
    case 'chicago':
      const s = ['*', '†', '‡', '§'];
      return s[(n - 1) % 4] * ((n - 1) ~/ 4 + 1);
    default:
      return '$n';
  }
}

extension DocxMedia on DocxDocument {
  // ── paket yardımcıları ──────────────────────────────────────────────────

  String _addRel(String type, String target) {
    final rels = _relsPart();
    var maxId = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) maxId = math.max(maxId, int.parse(m[1]!));
    }
    final id = 'rId${maxId + 1}';
    rels.rootElement.children.add(XmlElement(const XmlName.qualified('Relationship'), [
      XmlAttribute(const XmlName.qualified('Id'), id),
      XmlAttribute(const XmlName.qualified('Type'), type),
      XmlAttribute(const XmlName.qualified('Target'), target),
    ]));
    _dirtyParts.add('word/_rels/document.xml.rels');
    return id;
  }

  XmlDocument? _contentTypes() {
    final ct = _parts['[Content_Types].xml'] ??
        _partReader?.call('[Content_Types].xml');
    if (ct != null) _parts['[Content_Types].xml'] = ct;
    return ct;
  }

  void _ensureDefault(String ext, String mime) {
    final ct = _contentTypes();
    if (ct == null) return;
    final has = ct.rootElement.childElements.any((e) =>
        e.name.local == 'Default' &&
        (e.getAttribute('Extension') ?? '').toLowerCase() == ext);
    if (has) return;
    ct.rootElement.children.insert(
        0,
        XmlElement(const XmlName.qualified('Default'), [
          XmlAttribute(const XmlName.qualified('Extension'), ext),
          XmlAttribute(const XmlName.qualified('ContentType'), mime),
        ]));
    _dirtyParts.add('[Content_Types].xml');
  }

  void _ensureOverride(String name, String contentType) {
    final ct = _contentTypes();
    if (ct == null) return;
    final has = ct.rootElement.childElements.any((e) =>
        e.name.local == 'Override' && e.getAttribute('PartName') == '/$name');
    if (has) return;
    ct.rootElement.children.add(XmlElement(const XmlName.qualified('Override'), [
      XmlAttribute(const XmlName.qualified('PartName'), '/$name'),
      XmlAttribute(const XmlName.qualified('ContentType'), contentType),
    ]));
    _dirtyParts.add('[Content_Types].xml');
  }

  bool _exists(String name) =>
      _parts.containsKey(name) ||
      _binParts.containsKey(name) ||
      _archive.files.any((f) => f.name == name);

  /// İlişki türüyle bağlı parçanın adı (yoksa null).
  String? _partByRel(String typeSuffix) {
    for (final r in _relsPart().rootElement.childElements) {
      if ((r.getAttribute('Type') ?? '').endsWith(typeSuffix)) {
        final t = r.getAttribute('Target') ?? '';
        return t.startsWith('/') ? t.substring(1) : 'word/$t';
      }
    }
    return null;
  }

  /// İlişkiyle bağlı yan parça; yoksa [root] kökle yaratılır.
  XmlDocument _sidePart(String relSuffix, String relType, String defaultName,
      String contentType, String rootXml) {
    final name = _partByRel(relSuffix);
    if (name != null) {
      final have = _parts[name] ?? _partReader?.call(name);
      if (have != null) {
        _parts[name] = have;
        return have;
      }
    }
    final x = XmlDocument.parse(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n$rootXml');
    _parts[defaultName] = x;
    _dirtyParts.add(defaultName);
    if (name == null) {
      _addRel(relType, defaultName.substring('word/'.length));
    }
    _ensureOverride(defaultName, contentType);
    return x;
  }

  String _sidePartName(String relSuffix, String fallback) =>
      _partByRel(relSuffix) ?? fallback;

  // ── resim ───────────────────────────────────────────────────────────────

  int _nextDocPrId() {
    var m = 0;
    for (final e in doc.rootElement.descendantElements) {
      if (e.name.local == 'docPr') {
        m = math.max(m, int.tryParse(e.getAttribute('id') ?? '') ?? 0);
      }
    }
    for (final p in paras) {
      for (final a in p.atoms) {
        if (a?.kind != DocxAtomKind.image) continue;
        for (final n in a!.nodes) {
          for (final e in n.descendantElements) {
            if (e.name.local == 'docPr') {
              m = math.max(m, int.tryParse(e.getAttribute('id') ?? '') ?? 0);
            }
          }
        }
      }
    }
    return m + 1;
  }

  String _addMedia(Uint8List bytes, String ext) {
    final e = ext.toLowerCase() == 'jpeg' ? 'jpg' : ext.toLowerCase();
    _ensureDefault(e, _imageMimes[e] ?? 'image/$e');
    var n = 1;
    while (_exists('word/media/image$n.$e')) {
      n++;
    }
    final name = 'word/media/image$n.$e';
    _binParts[name] = bytes;
    final rid = _addRel('$_relBase/image', 'media/image$n.$e');
    _rels[rid] = name;
    return rid;
  }

  /// Satır içi yeni resim atomu. [widthPt] verilmezse en çok 432 pt (6 inç).
  DocxAtom newImageAtom(Uint8List bytes, String ext,
      {required int pixelWidth,
      required int pixelHeight,
      double? widthPt,
      String alt = ''}) {
    final rid = _addMedia(bytes, ext);
    final pw = math.max(1, pixelWidth), ph = math.max(1, pixelHeight);
    final natural = pw * 0.75; // 96 dpi
    final w = widthPt ?? math.min(432.0, natural);
    final h = w * ph / pw;
    final cx = (w * 12700).round(), cy = (h * 12700).round();
    final id = _nextDocPrId();
    final root = doc.rootElement;
    if (root.getAttribute('xmlns:r') == null) {
      root.attributes.add(XmlAttribute(const XmlName.qualified('xmlns:r'), _relBase));
    }
    final node = XmlDocument.parse(
            '<w:r $_wMain xmlns:r="$_relBase"><w:drawing>'
            '<wp:inline xmlns:wp="$_wpNs" distT="0" distB="0" distL="0" distR="0">'
            '<wp:extent cx="$cx" cy="$cy"/>'
            '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
            '<wp:docPr id="$id" name="Resim $id" descr="${_esc(alt)}"/>'
            '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="$_aNs" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
            '<a:graphic xmlns:a="$_aNs"><a:graphicData uri="$_picNs">'
            '<pic:pic xmlns:pic="$_picNs"><pic:nvPicPr>'
            '<pic:cNvPr id="0" name="image$id.$ext"/><pic:cNvPicPr/></pic:nvPicPr>'
            '<pic:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
            '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>')
        .rootElement
        .copy();
    return DocxAtom(DocxAtomKind.image, [node], '',
        image: bytes, widthPt: w, heightPt: h);
  }

  /// Oran kilitli yeni boyut ([widthPt]); düğümler kopyalanır.
  DocxAtom resizedImage(DocxAtom a, double widthPt) {
    final w = widthPt.clamp(8.0, 1584.0);
    final ratio = a.widthPt > 0 ? a.heightPt / a.widthPt : 1.0;
    final h = w * ratio;
    final cx = '${(w * 12700).round()}', cy = '${(h * 12700).round()}';
    final nodes = [for (final n in a.nodes) n.copy()];
    for (final n in nodes) {
      for (final e in n.descendantElements) {
        final parent = e.parent;
        final isXfrmExt = e.name.local == 'ext' &&
            parent is XmlElement &&
            parent.name.local == 'xfrm';
        if (e.name.local == 'extent' || isXfrmExt) {
          e.setAttribute('cx', cx);
          e.setAttribute('cy', cy);
        }
      }
    }
    return DocxAtom(DocxAtomKind.image, nodes, '',
        image: a.image, widthPt: w, heightPt: h);
  }

  /// Resmin alternatif metni (`wp:docPr@descr`).
  String imageAlt(DocxAtom a) {
    for (final n in a.nodes) {
      for (final e in n.descendantElements) {
        if (e.name.local == 'docPr') return e.getAttribute('descr') ?? '';
      }
    }
    return '';
  }

  DocxAtom withImageAlt(DocxAtom a, String alt) {
    final nodes = [for (final n in a.nodes) n.copy()];
    for (final n in nodes) {
      for (final e in n.descendantElements) {
        if (e.name.local == 'docPr') e.setAttribute('descr', alt);
      }
    }
    return DocxAtom(DocxAtomKind.image, nodes, '',
        image: a.image, widthPt: a.widthPt, heightPt: a.heightPt);
  }

  /// Resmi değiştirir: genişlik korunur, yükseklik yeni oranla.
  DocxAtom replacedImage(DocxAtom a, Uint8List bytes, String ext,
      {required int pixelWidth, required int pixelHeight}) {
    final rid = _addMedia(bytes, ext);
    final nodes = [for (final n in a.nodes) n.copy()];
    for (final n in nodes) {
      for (final e in n.descendantElements) {
        if (e.name.local != 'blip') continue;
        for (final at in e.attributes) {
          if (at.name.local == 'embed') at.value = rid;
        }
      }
    }
    final w = a.widthPt > 0 ? a.widthPt : math.min(432.0, pixelWidth * 0.75);
    final fresh = DocxAtom(DocxAtomKind.image, nodes, '',
        image: bytes,
        widthPt: w,
        heightPt: w * math.max(1, pixelHeight) / math.max(1, pixelWidth));
    // Oranı ayarla (resizedImage heightPt/widthPt oranını kullanır).
    return resizedImage(fresh, w);
  }

  // ── yatay çizgi ─────────────────────────────────────────────────────────

  /// Alt kenarlıklı boş paragraf (Word'deki "yatay çizgi" / `---`).
  DocxPara horizontalRulePara(DocxPara near) {
    final base = _emptyPara(near.container, cell: near.cell);
    return editPPr(base, (pPr) {
      DocxDocument._putP(
          pPr,
          DocxDocument._w('pBdr')
            ..children.add(DocxDocument._w('bottom', {
              'val': 'single',
              'sz': '6',
              'space': '1',
              'color': 'auto',
            })));
    });
  }

  // ── dipnot / sonnot ─────────────────────────────────────────────────────

  XmlDocument _notesPart(bool end) {
    final tag = end ? 'endnote' : 'footnote';
    const sep = '<w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>';
    return _sidePart(
      '/${tag}s',
      '$_relBase/${tag}s',
      'word/${tag}s.xml',
      '$_ctBase.${tag}s+xml',
      '<w:${tag}s $_wMain>'
          '<w:$tag w:type="separator" w:id="-1"><w:p>$sep<w:r><w:separator/></w:r></w:p></w:$tag>'
          '<w:$tag w:type="continuationSeparator" w:id="0"><w:p>$sep<w:r><w:continuationSeparator/></w:r></w:p></w:$tag>'
          '</w:${tag}s>',
    );
  }

  /// Yeni dipnot: parçaya yazılır, başvuru atomu döner.
  DocxAtom newFootnoteAtom(String text) => _newNoteAtom(false, text);

  /// Yeni sonnot (belge sonunda toplanan not).
  DocxAtom newEndnoteAtom(String text) => _newNoteAtom(true, text);

  DocxAtom _newNoteAtom(bool end, String text) {
    final tag = end ? 'endnote' : 'footnote';
    final x = _notesPart(end);
    var maxId = 0;
    for (final f in x.rootElement.childElements) {
      maxId = math.max(maxId, int.tryParse(f.getAttribute('w:id') ?? '') ?? 0);
    }
    final id = maxId + 1;
    x.rootElement.children.add(XmlDocument.parse(
            '<w:$tag $_wMain w:id="$id"><w:p>'
            '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:${tag}Ref/></w:r>'
            '<w:r><w:t xml:space="preserve"> ${_esc(text)}</w:t></w:r>'
            '</w:p></w:$tag>')
        .rootElement
        .copy());
    _dirtyParts.add(_sidePartName('/${tag}s', 'word/${tag}s.xml'));
    _notesTouched[this] = true;
    final node = XmlDocument.parse('<w:r $_wMain>'
            '<w:rPr><w:vertAlign w:val="superscript"/></w:rPr>'
            '<w:${tag}Reference w:id="$id"/></w:r>')
        .rootElement
        .copy();
    return DocxAtom(DocxAtomKind.note, [node], '$id');
  }

  /// Not atomunun başvurusu (dipnot/sonnot, kimlik, özel işaret); değilse null.
  ({bool end, String id, bool custom})? noteRef(DocxAtom a) {
    if (a.kind != DocxAtomKind.note) return null;
    for (final n in a.nodes) {
      for (final e in [n, ...n.descendantElements]) {
        final l = e.name.local;
        if (l != 'footnoteReference' && l != 'endnoteReference') continue;
        final c = DocxDocument._attr(e, 'customMarkFollows');
        return (
          end: l == 'endnoteReference',
          id: DocxDocument._attr(e, 'id') ?? '',
          custom: c == '1' || c == 'true' || c == 'on',
        );
      }
    }
    return null;
  }

  /// Not anahtarı ([footnoteText] / [setFootnoteText] / [deleteNote] için):
  /// dipnotta `w:id`, sonnotta [kDocxEndnoteKey] + `w:id`.
  String noteKey(DocxAtom a) {
    final r = noteRef(a);
    if (r == null) return a.display;
    return r.end ? '$kDocxEndnoteKey${r.id}' : r.id;
  }

  /// Bölüm ayarındaki numara biçimi + başlangıç (yoksa Word varsayılanı:
  /// dipnot 1, 2, 3 · sonnot i, ii, iii).
  (String, int) _noteFormat(bool end) {
    final sect = body.childElements.where((e) => e.name.local == 'sectPr').firstOrNull;
    final pr = sect?.childElements
        .where((e) => e.name.local == (end ? 'endnotePr' : 'footnotePr'))
        .firstOrNull;
    XmlElement? k(String l) => pr?.childElements.where((e) => e.name.local == l).firstOrNull;
    return (
      DocxDocument._attr(k('numFmt'), 'val') ?? (end ? 'lowerRoman' : 'decimal'),
      int.tryParse(DocxDocument._attr(k('numStart'), 'val') ?? '') ?? 1,
    );
  }

  /// Not numaraları belge sırasıyla (Word gibi `w:id`den bağımsız): araya
  /// eklenen ya da silinen not ötekileri kaydırır. Özel işaretli not boş.
  Map<DocxAtom, String> noteLabels() {
    final out = Map<DocxAtom, String>.identity();
    final (ff, fs) = _noteFormat(false);
    final (ef, es) = _noteFormat(true);
    var f = 0, e = 0;
    for (final p in paras) {
      var k = p.text.indexOf(kDocxAtom);
      while (k >= 0 && k < p.atoms.length) {
        final a = p.atoms[k];
        final r = a == null ? null : noteRef(a);
        if (a != null && r != null) {
          out[a] = r.custom
              ? ''
              : r.end
                  ? docxNoteNumber(ef, es + e++)
                  : docxNoteNumber(ff, fs + f++);
        }
        k = p.text.indexOf(kDocxAtom, k + 1);
      }
    }
    return out;
  }

  XmlElement? _noteEl(String key) {
    final end = key.startsWith(kDocxEndnoteKey);
    final id = end ? key.substring(kDocxEndnoteKey.length) : key;
    final tag = end ? 'endnote' : 'footnote';
    final name = _partByRel('/${tag}s');
    if (name == null) return null;
    final x = _parts[name] ?? _partReader?.call(name);
    if (x == null) return null;
    _parts[name] = x;
    for (final f in x.rootElement.childElements) {
      if (f.name.local == tag && f.getAttribute('w:id') == id) return f;
    }
    return null;
  }

  /// Notun düz metni (yoksa null). [key] = [noteKey].
  String? footnoteText(String key) {
    final f = _noteEl(key);
    if (f == null) return null;
    return DocxDocument._textOf(f).trim();
  }

  /// Not metnini değiştirir (yalnız tek paragraflı, resimsiz notta).
  bool setFootnoteText(String key, String text) {
    final f = _noteEl(key);
    if (f == null) return false;
    final ps = f.childElements.where((e) => e.name.local == 'p').toList();
    if (ps.length != 1 || DocxDocument._hasVisual(ps.first)) return false;
    final p = ps.first;
    final keep = p.childElements
        .where((e) =>
            e.name.local == 'pPr' ||
            (e.name.local == 'r' &&
                e.childElements.any((c) =>
                    c.name.local == 'footnoteRef' || c.name.local == 'endnoteRef')))
        .map((e) => e.copy())
        .toList();
    p.children
      ..clear()
      ..addAll(keep)
      ..add(XmlDocument.parse('<w:r $_wMain><w:t xml:space="preserve"> '
              '${_esc(text)}</w:t></w:r>')
          .rootElement
          .copy());
    final end = key.startsWith(kDocxEndnoteKey);
    _dirtyParts.add(_partByRel(end ? '/endnotes' : '/footnotes')!);
    return true;
  }

  /// Notun başvurularını modelden kaldırır (değişen paragraf sıraları).
  /// Not parçadan kaydette budanır — geri al notu geri getirir.
  List<int> deleteNote(String key) {
    final changed = <int>[];
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      final at = [
        for (var k = 0; k < p.atoms.length; k++)
          if (p.atoms[k] case final a?
              when a.kind == DocxAtomKind.note && noteKey(a) == key)
            k,
      ];
      if (at.isEmpty) continue;
      var q = p;
      for (final k in at.reversed) {
        q = q.replace(k, k + 1, '', q.mark);
      }
      paras[i] = q;
      changed.add(i);
    }
    if (changed.isNotEmpty) _notesTouched[this] = true;
    return changed;
  }

  /// Kaydetmeden önce: başvurusu kalmayan dipnot/sonnotlar budanmış not
  /// parçalarının KOPYASI (ayırıcılar kalır; bellekteki parça el değmez —
  /// kayıttan sonra geri al notu metniyle geri getirir). Yalnız oturumda not
  /// eklendi/silindiyse; değişmeyen parça dönmez.
  Map<String, XmlDocument> _prunedFootnotes() {
    final out = <String, XmlDocument>{};
    if (_notesTouched[this] != true) return out;
    final refs = <String>{};
    for (final e in doc.rootElement.descendantElements) {
      final l = e.name.local;
      if (l == 'footnoteReference' || l == 'endnoteReference') {
        refs.add('${l == 'endnoteReference' ? kDocxEndnoteKey : ''}'
            '${DocxDocument._attr(e, 'id')}');
      }
    }
    for (final end in const [false, true]) {
      final tag = end ? 'endnote' : 'footnote';
      final name = _partByRel('/${tag}s');
      if (name == null) continue;
      final have = _parts[name] ?? _partReader?.call(name);
      if (have == null) continue;
      final x = have.copy();
      final before = x.rootElement.children.length;
      x.rootElement.children.removeWhere((n) =>
          n is XmlElement &&
          n.name.local == tag &&
          n.getAttribute('w:type') == null &&
          !refs.contains('${end ? kDocxEndnoteKey : ''}${n.getAttribute('w:id')}'));
      if (x.rootElement.children.length != before) out[name] = x;
    }
    return out;
  }

  // ── yorumlar ────────────────────────────────────────────────────────────

  XmlDocument _commentsPart() => _sidePart(
        '/comments',
        '$_relBase/comments',
        'word/comments.xml',
        '$_ctBase.comments+xml',
        '<w:comments $_wMain xmlns:w14="$_w14Ns"/>',
      );

  XmlDocument? _commentsIfAny() {
    final name = _partByRel('/comments');
    if (name == null) return null;
    final x = _parts[name] ?? _partReader?.call(name);
    if (x != null) _parts[name] = x;
    return x;
  }

  XmlDocument _commentsExt() => _sidePart(
        '/commentsExtended',
        'http://schemas.microsoft.com/office/2011/relationships/commentsExtended',
        'word/commentsExtended.xml',
        '$_ctBase.commentsExtended+xml',
        '<w15:commentsEx xmlns:w15="$_w15Ns"/>',
      );

  XmlDocument? _commentsExtIfAny() {
    final name = _partByRel('/commentsExtended');
    if (name == null) return null;
    final x = _parts[name] ?? _partReader?.call(name);
    if (x != null) _parts[name] = x;
    return x;
  }

  /// Modelde başvurusu olan yorum kimlikleri (belge sırasıyla).
  List<String> _referencedComments() => [
        for (final p in paras)
          for (final a in p.atoms)
            if (a?.kind == DocxAtomKind.comment) a!.display,
      ];

  /// Yorumun son paragrafının `w14:paraId`'si (yoksa yazılır).
  String _paraIdOf(XmlElement comment) {
    final ps = comment.childElements.where((e) => e.name.local == 'p').toList();
    if (ps.isEmpty) {
      final p = XmlElement(const XmlName.qualified('w:p'));
      comment.children.add(p);
      ps.add(p);
    }
    final last = ps.last;
    for (final a in last.attributes) {
      if (a.name.local == 'paraId') return a.value;
    }
    final id = (0x10000000 + math.Random().nextInt(0x6FFFFFFF))
        .toRadixString(16)
        .toUpperCase();
    last.attributes.add(XmlAttribute(const XmlName.qualified('w14:paraId'), id));
    final root = comment.parent;
    if (root is XmlElement && root.getAttribute('xmlns:w14') == null) {
      root.attributes.add(XmlAttribute(const XmlName.qualified('xmlns:w14'), _w14Ns));
    }
    return id;
  }

  static final Expando<bool> _hasCommentsCache = Expando<bool>('hasComments');
  static final Expando<Map<String, (DocxComment, int)?>> _balloonMapCache =
      Expando<Map<String, (DocxComment, int)?>>('commentBalloonMap');

  void _invalidateCommentCaches() {
    _hasCommentsCache[this] = null;
    _balloonMapCache[this] = null;
  }

  /// B9b: belgede en az bir yorum var mı (tablette kenar sütunu açılır).
  /// Yalnız yorum parçasına bakar, gövde TARANMAZ; ilk yorumda durur.
  bool get hasComments {
    final cached = _hasCommentsCache[this];
    if (cached != null) return cached;
    final res = _commentsIfAny()
            ?.rootElement
            .childElements
            .any((e) => e.name.local == 'comment') ??
        false;
    _hasCommentsCache[this] = res;
    return res;
  }

  /// Kenar balonu (B9 m.4): [id]'li yorum + yanıt sayısı. Gövde TARANMAZ
  /// (yorumlu paragraf her çizildiğinde çağrılır; maliyet yorum sayısı
  /// kadar). Yanıtsa (balonu kökündedir) ya da yoksa null.
  (DocxComment, int)? commentBalloon(String id) {
    var cache = _balloonMapCache[this];
    if (cache != null && cache.containsKey(id)) return cache[id];
    final x = _commentsIfAny();
    if (x == null) return null;
    XmlElement? c;
    for (final e in x.rootElement.childElements) {
      if (e.name.local == 'comment' && e.getAttribute('w:id') == id) {
        c = e;
        break;
      }
    }
    if (c == null) {
      (cache ??= <String, (DocxComment, int)?>{})[id] = null;
      _balloonMapCache[this] = cache;
      return null;
    }
    String? pid;
    final ps = c.childElements.where((e) => e.name.local == 'p');
    if (ps.isNotEmpty) {
      for (final a in ps.last.attributes) {
        if (a.name.local == 'paraId') pid = a.value;
      }
    }
    var done = false, replies = 0;
    final ex = _commentsExtIfAny();
    if (ex != null && pid != null) {
      for (final e in ex.rootElement.childElements) {
        String? me, parent;
        for (final a in e.attributes) {
          if (a.name.local == 'paraId') me = a.value;
          if (a.name.local == 'paraIdParent') parent = a.value;
        }
        if (me == pid) {
          if (parent != null) {
            (cache ??= <String, (DocxComment, int)?>{})[id] = null;
            _balloonMapCache[this] = cache;
            return null;
          }
          done = e.attributes.any((a) => a.name.local == 'done' && a.value == '1');
        }
        if (parent == pid) replies++;
      }
    }
    final out = (
      DocxComment(id, c.getAttribute('w:author') ?? '',
          c.getAttribute('w:date') ?? '', DocxDocument._textOf(c).trim(), done, null),
      replies,
    );
    (cache ??= <String, (DocxComment, int)?>{})[id] = out;
    _balloonMapCache[this] = cache;
    return out;
  }

  /// Belgedeki (başvurusu olan) yorumlar.
  List<DocxComment> comments() {
    final x = _commentsIfAny();
    if (x == null) return const [];
    final refs = _referencedComments().toSet();
    final ext = <String, (bool, String?)>{};
    final ex = _commentsExtIfAny();
    if (ex != null) {
      for (final e in ex.rootElement.childElements) {
        String? pid, parent, done;
        for (final a in e.attributes) {
          switch (a.name.local) {
            case 'paraId':
              pid = a.value;
            case 'paraIdParent':
              parent = a.value;
            case 'done':
              done = a.value;
          }
        }
        if (pid != null) ext[pid] = (done == '1', parent);
      }
    }
    final byPara = <String, String>{};
    final out = <DocxComment>[];
    final raw = <(XmlElement, String)>[];
    for (final c in x.rootElement.childElements) {
      if (c.name.local != 'comment') continue;
      final id = c.getAttribute('w:id') ?? '';
      if (!refs.contains(id)) continue;
      String? pid;
      final ps = c.childElements.where((e) => e.name.local == 'p');
      if (ps.isNotEmpty) {
        for (final a in ps.last.attributes) {
          if (a.name.local == 'paraId') pid = a.value;
        }
      }
      if (pid != null) byPara[pid] = id;
      raw.add((c, pid ?? ''));
    }
    for (final (c, pid) in raw) {
      final info = ext[pid];
      out.add(DocxComment(
        c.getAttribute('w:id') ?? '',
        c.getAttribute('w:author') ?? '',
        c.getAttribute('w:date') ?? '',
        DocxDocument._textOf(c).trim(),
        info?.$1 ?? false,
        info?.$2 == null ? null : byPara[info!.$2],
      ));
    }
    return out;
  }

  XmlElement _newComment(String text, String author) {
    _invalidateCommentCaches();
    final x = _commentsPart();
    _commentsTouched[this] = true;
    var maxId = -1;
    for (final c in x.rootElement.childElements) {
      maxId = math.max(maxId, int.tryParse(c.getAttribute('w:id') ?? '') ?? -1);
    }
    for (final id in _referencedComments()) {
      maxId = math.max(maxId, int.tryParse(id) ?? -1);
    }
    final id = maxId + 1;
    final initials = author
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(3)
        .join();
    final date = DateTime.now().toUtc().toIso8601String().split('.').first;
    final c = XmlDocument.parse(
            '<w:comment $_wMain w:id="$id" w:author="${_esc(author)}" '
            'w:date="${date}Z" w:initials="${_esc(initials)}"><w:p>'
            '<w:r><w:annotationRef/></w:r>'
            '<w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r>'
            '</w:p></w:comment>')
        .rootElement
        .copy();
    x.rootElement.children.add(c);
    _dirtyParts.add(_sidePartName('/comments', 'word/comments.xml'));
    return c;
  }

  static XmlElement _commentNode(String local, String id) =>
      XmlDocument.parse('<w:$local $_wMain w:id="$id"/>').rootElement.copy();

  DocxAtom _commentRefAtom(String id) => DocxAtom(
      DocxAtomKind.comment,
      [
        XmlDocument.parse('<w:r $_wMain><w:commentReference w:id="$id"/></w:r>')
            .rootElement
            .copy(),
      ],
      id);

  /// [p]'nin [from, to) aralığına yorum ekler; yeni paragrafı döndürür.
  DocxPara addComment(
      DocxPara p, int from, int to, String text, String author) {
    final c = _newComment(text, author);
    final id = c.getAttribute('w:id')!;
    final a = from.clamp(0, p.length), b = to.clamp(a, p.length);
    final withRef = insertAtom(p, b, _commentRefAtom(id), p.mark);
    return withRef.copyWith(anchors: [
      ...withRef.anchors,
      (a, _commentNode('commentRangeStart', id)),
      (b, _commentNode('commentRangeEnd', id)),
    ]..sort((x, y) => x.$1.compareTo(y.$1)));
  }

  /// [parentId] yorumuna yanıt: başvurusu üst yorumunkinin hemen ardına.
  /// (paragraf sırası, yeni paragraf) döner; üst yorum bulunmazsa null.
  (int, DocxPara)? replyComment(String parentId, String text, String author) {
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      final k = p.atoms.indexWhere(
          (a) => a?.kind == DocxAtomKind.comment && a!.display == parentId);
      if (k < 0) continue;
      final parent = _commentEl(parentId);
      if (parent == null) return null;
      final c = _newComment(text, author);
      final id = c.getAttribute('w:id')!;
      final ext = _commentsExt();
      ext.rootElement.children.add(XmlElement(
          const XmlName.qualified('w15:commentEx'), [
        XmlAttribute(const XmlName.qualified('w15:paraId'), _paraIdOf(c)),
        XmlAttribute(const XmlName.qualified('w15:paraIdParent'), _paraIdOf(parent)),
        XmlAttribute(const XmlName.qualified('w15:done'), '0'),
      ]));
      _dirtyParts.add(_sidePartName('/commentsExtended', 'word/commentsExtended.xml'));
      _invalidateCommentCaches();
      return (i, insertAtom(p, k + 1, _commentRefAtom(id), p.styles[k]));
    }
    return null;
  }

  XmlElement? _commentEl(String id) {
    final x = _commentsIfAny();
    if (x == null) return null;
    for (final c in x.rootElement.childElements) {
      if (c.name.local == 'comment' && c.getAttribute('w:id') == id) return c;
    }
    return null;
  }

  /// Yorumu "çözüldü" işaretler ya da yeniden açar (geri alınamaz).
  bool setCommentDone(String id, bool done) {
    final c = _commentEl(id);
    if (c == null) return false;
    final pid = _paraIdOf(c);
    _dirtyParts.add(_sidePartName('/comments', 'word/comments.xml'));
    final ext = _commentsExt();
    XmlElement? row;
    for (final e in ext.rootElement.childElements) {
      for (final a in e.attributes) {
        if (a.name.local == 'paraId' && a.value == pid) row = e;
      }
    }
    if (row == null) {
      row = XmlElement(const XmlName.qualified('w15:commentEx'), [
        XmlAttribute(const XmlName.qualified('w15:paraId'), pid),
      ]);
      ext.rootElement.children.add(row);
    }
    row.attributes.removeWhere((a) => a.name.local == 'done');
    row.attributes
        .add(XmlAttribute(const XmlName.qualified('w15:done'), done ? '1' : '0'));
    _dirtyParts.add(_sidePartName('/commentsExtended', 'word/commentsExtended.xml'));
    _invalidateCommentCaches();
    return true;
  }

  /// Yorumu (ve yanıtlarını) modelden kaldırır; değişen paragraf sıralarını
  /// döndürür. Parçadan budama kaydette olur (geri al geri getirir).
  List<int> deleteComment(String id) {
    _invalidateCommentCaches();
    final ids = {id};
    for (final c in comments()) {
      if (c.parentId == id) ids.add(c.id);
    }
    _commentsTouched[this] = true;
    final changed = <int>[];
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      bool isOurs(XmlElement e) =>
          (e.name.local == 'commentRangeStart' ||
              e.name.local == 'commentRangeEnd') &&
          ids.contains(DocxDocument._attr(e, 'id'));
      final hasAnchor = p.anchors.any((x) => isOurs(x.$2));
      final refs = [
        for (var k = 0; k < p.length; k++)
          if (p.atoms[k]?.kind == DocxAtomKind.comment &&
              ids.contains(p.atoms[k]!.display))
            k,
      ];
      if (!hasAnchor && refs.isEmpty) continue;
      var q = p.copyWith(anchors: [
        for (final x in p.anchors)
          if (!isOurs(x.$2)) x,
      ]);
      for (final k in refs.reversed) {
        q = q.replace(k, k + 1, '', q.mark);
      }
      paras[i] = q;
      changed.add(i);
    }
    return changed;
  }

  /// Kaydetmeden önce: başvurusu kalmayan yorumları parçadan (ve
  /// `commentsExtended`ten) budar — yalnız oturumda yorumlara dokunulduysa.
  void _pruneNotes() {
    if (_commentsTouched[this] != true) return;
    final x = _commentsIfAny();
    if (x == null) return;
    final refs = <String>{};
    for (final e in doc.rootElement.descendantElements) {
      if (e.name.local == 'commentReference') {
        final id = DocxDocument._attr(e, 'id');
        if (id != null) refs.add(id);
      }
    }
    final gone = <String>{};
    x.rootElement.children.removeWhere((n) {
      if (n is! XmlElement || n.name.local != 'comment') return false;
      if (refs.contains(n.getAttribute('w:id'))) return false;
      for (final p in n.childElements) {
        for (final a in p.attributes) {
          if (a.name.local == 'paraId') gone.add(a.value);
        }
      }
      return true;
    });
    _dirtyParts.add(_sidePartName('/comments', 'word/comments.xml'));
    final ex = _commentsExtIfAny();
    if (ex != null && gone.isNotEmpty) {
      ex.rootElement.children.removeWhere((n) =>
          n is XmlElement &&
          n.attributes.any((a) => a.name.local == 'paraId' && gone.contains(a.value)));
      _dirtyParts.add(_sidePartName('/commentsExtended', 'word/commentsExtended.xml'));
    }
  }
}
