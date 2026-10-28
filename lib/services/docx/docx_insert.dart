part of 'docx_document.dart';

/// Faz 24 — Ekle / Düzen işlemleri (tablo, bağlantı, sayfa sonu, sayfa
/// ayarı). `part`: modelin özel üyelerine (`_parts`, `_rels`, `_newTables`)
/// erişir. İlke Faz 22'dekiyle aynı: model değişmez nesnelerle çalışır, XML'e
/// yazım `commit()`te olur — Geri al yalnız paragraf listesini geri alır.

const _wMain =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Sayfa ayarı özeti (twip; 1 pt = 20 twip).
class DocxPageSetup {
  final int width, height;
  final bool landscape;
  final int top, right, bottom, left;
  final int columns;
  const DocxPageSetup(this.width, this.height, this.landscape, this.top,
      this.right, this.bottom, this.left, this.columns);

  /// `a4`, `a5`, `letter`, `legal` ya da `custom`.
  String get paper {
    final w = landscape ? height : width, h = landscape ? width : height;
    bool near(int a, int b) => (a - b).abs() <= 40;
    for (final e in kDocxPaperSizes.entries) {
      if (near(w, e.value.$1) && near(h, e.value.$2)) return e.key;
    }
    return 'custom';
  }

  /// `normal`, `narrow`, `moderate`, `wide` ya da `custom`.
  String get marginPreset {
    bool near(int a, int b) => (a - b).abs() <= 20;
    for (final e in kDocxMarginPresets.entries) {
      final (t, r) = e.value;
      if (near(top, t) && near(bottom, t) && near(left, r) && near(right, r)) {
        return e.key;
      }
    }
    return 'custom';
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

int _i(XmlElement? e, String attr, int dflt) {
  if (e == null) return dflt;
  for (final a in e.attributes) {
    if (a.name.local == attr) return int.tryParse(a.value) ?? dflt;
  }
  return dflt;
}

const Map<String, (int, int)> kDocxPaperSizes = {
  'a4': (11906, 16838),
  'a5': (8391, 11906),
  'letter': (12240, 15840),
  'legal': (12240, 20160),
};

/// (üst/alt, sol/sağ) twip.
const Map<String, (int, int)> kDocxMarginPresets = {
  'normal': (1440, 1440),
  'narrow': (720, 720),
  'moderate': (1440, 1080),
  'wide': (1440, 2880),
};

const _sectOrder = [
  'headerReference', 'footerReference', 'footnotePr', 'endnotePr', 'type',
  'pgSz', 'pgMar', 'paperSrc', 'pgBorders', 'lnNumType', 'pgNumType',
  'cols', 'formProt', 'vAlign', 'noEndnote', 'titlePg', 'textDirection',
  'bidi', 'rtlGutter', 'docGrid', 'printerSettings', 'sectPrChange',
];

void _set(XmlElement e, String attr, Object v) {
  for (final a in e.attributes) {
    if (a.name.local == attr) {
      a.value = '$v';
      return;
    }
  }
  e.attributes.add(XmlAttribute(XmlName.fromString('w:$attr'), '$v'));
}


extension DocxInsert on DocxDocument {
  // ── bağlantı ve sayfa sonu ──────────────────────────────────────────────

  /// Yeni dış bağlantı atomu: görünen [text], hedef [url]. İlişki
  /// `document.xml.rels`e eklenir (kullanılmazsa zararsız).
  DocxAtom newLinkAtom(String text, String url) {
    final rels = _relsPart();
    var maxId = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) maxId = math.max(maxId, int.parse(m[1]!));
    }
    final id = 'rId${maxId + 1}';
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), id),
      XmlAttribute(XmlName('Type'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink'),
      XmlAttribute(XmlName('Target'), url),
      XmlAttribute(XmlName('TargetMode'), 'External'),
    ]));
    _dirtyParts.add('word/_rels/document.xml.rels');
    // `r:` ad alanı kökte tanımlı değilse tanımla.
    final root = doc.rootElement;
    if (root.getAttribute('xmlns:r') == null) {
      root.attributes.add(XmlAttribute(XmlName.fromString('xmlns:r'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships'));
    }
    final node = XmlDocument.parse(
            '<w:hyperlink $_wMain xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="$id" w:history="1">'
            '<w:r><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr>'
            '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:hyperlink>')
        .rootElement
        .copy();
    return DocxAtom(DocxAtomKind.link, [node], text);
  }

  DocxAtom newPageBreakAtom() {
    final node = XmlDocument.parse('<w:r $_wMain><w:br w:type="page"/></w:r>')
        .rootElement
        .copy();
    return DocxAtom(DocxAtomKind.pageBreak, [node], '');
  }

  XmlDocument _relsPart() {
    const name = 'word/_rels/document.xml.rels';
    final have = _parts[name] ?? _partReader?.call(name);
    final rels = have ??
        XmlDocument.parse(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>');
    _parts[name] = rels;
    return rels;
  }

  /// [p]'nin [offset]'ine tek karakterlik [atom] koyar.
  DocxPara insertAtom(
      DocxPara p, int offset, DocxAtom atom, DocxCharStyle style) {
    final o = offset.clamp(0, p.length);
    final next = p.replace(o, o, kDocxAtom, style);
    final at = [...next.atoms]..[o] = atom;
    return next.copyWith(atoms: at);
  }

  // ── tablo ───────────────────────────────────────────────────────────────

  /// [afterPara]'dan sonra [rows]×[cols] boş tablo ekler (hücre paragrafları
  /// `paras`a girer; XML `commit()`te bağlanır). Tablonun ardına boş bir
  /// gövde paragrafı konur (Word, gövdenin tablo ile bitmesini istemez).
  /// İlk hücrenin paragraf sırasını döndürür; geçerli değilse -1.
  int insertTable(int afterPara, int rows, int cols) {
    if (rows < 1 || cols < 1 || rows > 50 || cols > 20) return -1;
    final i = afterPara.clamp(0, paras.length - 1);
    // Hücre içine tablo eklenmez (iç içe tablo desteklenmiyor).
    final at = paras[i];
    final top = at.cell == null ? i : _lastOfTable(at.cell!.table);
    const w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
    final colW = (8800 / cols).floor();
    final b = StringBuffer('<w:tbl $w><w:tblPr>')
      ..write('<w:tblW w:w="0" w:type="auto"/>')
      ..write('<w:tblBorders>');
    for (final side in const ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
      b.write('<w:$side w:val="single" w:sz="4" w:space="0" w:color="808080"/>');
    }
    b.write('</w:tblBorders><w:tblLook w:val="04A0" w:firstRow="1" '
        'w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>'
        '</w:tblPr><w:tblGrid>');
    for (var c = 0; c < cols; c++) {
      b.write('<w:gridCol w:w="$colW"/>');
    }
    b.write('</w:tblGrid>');
    for (var r = 0; r < rows; r++) {
      b.write('<w:tr>');
      for (var c = 0; c < cols; c++) {
        b.write('<w:tc><w:tcPr><w:tcW w:w="$colW" w:type="dxa"/></w:tcPr></w:tc>');
      }
      b.write('</w:tr>');
    }
    b.write('</w:tbl>');
    final tbl = XmlDocument.parse(b.toString()).rootElement.copy();
    _newTables.add(tbl);
    final cellParas = <DocxPara>[];
    var r = 0;
    for (final tr in tbl.childElements.where((e) => e.name.local == 'tr')) {
      var c = 0;
      for (final tc in tr.childElements.where((e) => e.name.local == 'tc')) {
        cellParas.add(_emptyPara(tc, cell: DocxCellRef(tbl, tc, r, c, 1)));
        c++;
      }
      r++;
    }
    final after = _emptyPara(body);
    paras.insertAll(top + 1, [...cellParas, after]);
    return top + 1;
  }

  int _lastOfTable(XmlElement tbl) {
    var last = 0;
    for (var k = 0; k < paras.length; k++) {
      if (identical(paras[k].cell?.table, tbl)) last = k;
    }
    return last;
  }

  /// `commit()` sonunda: yönetilen tabloları paragraf modeline eşitler —
  /// modelde hiç paragrafı kalmayanı söker, geri gelmiş (geri al/yinele)
  /// olanı yerine bağlar, satır/hücre sırasını ve ızgarayı düzeltir.
  bool _syncNewTables() {
    var changed = false;
    for (final tbl in _newTables) {
      final first = paras.indexWhere((p) => identical(p.cell?.table, tbl));
      if (first < 0) {
        if (tbl.parent != null) {
          tbl.parent!.children.remove(tbl);
          changed = true;
        }
        continue;
      }
      if (tbl.parent == null) {
        // Önceki üst düzey öğeyi bul: gövde paragrafı ya da başka tablo.
        XmlElement? prev;
        for (var j = first - 1; j >= 0; j--) {
          final q = paras[j];
          if (q.cell != null) {
            prev = q.cell!.table;
            break;
          }
          if (identical(q.container, body) && q.source?.parent != null) {
            prev = q.source;
            break;
          }
        }
        final kids = body.children;
        if (prev != null && identical(prev.parent, body)) {
          kids.insert(kids.indexOf(prev) + 1, tbl);
        } else {
          kids.insert(0, tbl);
        }
        changed = true;
      }
      if (_reconcileTable(tbl)) changed = true;
    }
    return changed;
  }

  // ── sayfa ayarı (w:sectPr) ──────────────────────────────────────────────

  List<XmlElement> get _sections => [
        for (final e in doc.rootElement.descendantElements)
          if (e.name.local == 'sectPr') e,
      ];

  XmlElement _mainSect() {
    for (final k in body.childElements.toList().reversed) {
      if (k.name.local == 'sectPr') return k;
    }
    final s = XmlDocument.parse('<w:sectPr $_wMain/>').rootElement.copy();
    body.children.add(s);
    return s;
  }

  DocxPageSetup pageSetup() {
    final s = _mainSect();
    XmlElement? c(String n) {
      for (final k in s.childElements) {
        if (k.name.local == n) return k;
      }
      return null;
    }

    final sz = c('pgSz'), mar = c('pgMar'), cols = c('cols');
    final orient = sz?.getAttribute('w:orient');
    final w = _i(sz, 'w', 11906), h = _i(sz, 'h', 16838);
    return DocxPageSetup(
      w,
      h,
      orient == 'landscape' || w > h,
      _i(mar, 'top', 1440),
      _i(mar, 'right', 1440),
      _i(mar, 'bottom', 1440),
      _i(mar, 'left', 1440),
      _i(cols, 'num', 1),
    );
  }

  /// Geri al için anlık görüntü: bölümler + izlenen özellik düğümleri.
  String sectSnapshot() =>
      '${_sections.map((e) => e.toXmlString()).join('\u0000')}'
      '\u0001${_tracked.map((e) => e.toXmlString()).join('\u0000')}';

  void restoreSect(String snap) {
    if (snap == sectSnapshot()) return;
    final halves = snap.split('\u0001');
    final secs = halves[0];
    final now = _sections;
    final parts = secs.isEmpty ? const <String>[] : secs.split('\u0000');
    for (var k = 0; k < now.length && k < parts.length; k++) {
      final fresh = XmlDocument.parse(parts[k]).rootElement.copy();
      final parent = now[k].parent!;
      parent.children[parent.children.indexOf(now[k])] = fresh;
    }
    final props = halves.length > 1 && halves[1].isNotEmpty
        ? halves[1].split('\u0000')
        : const <String>[];
    for (var k = 0; k < _tracked.length && k < props.length; k++) {
      final fresh = XmlDocument.parse(props[k]).rootElement;
      final el = _tracked[k];
      el.attributes
        ..clear()
        ..addAll(fresh.attributes.map((a) => a.copy()));
      el.children
        ..clear()
        ..addAll(fresh.children.map((c) => c.copy()));
    }
    _xmlDirty = true;
  }

  void _editSections(void Function(XmlElement s) edit) {
    final all = _sections;
    if (all.isEmpty) _mainSect();
    for (final s in _sections) {
      edit(s);
    }
    _xmlDirty = true;
  }

  XmlElement _sectChild(XmlElement s, String name) {
    for (final k in s.childElements) {
      if (k.name.local == name) return k;
    }
    final el = XmlElement(XmlName.fromString('w:$name'));
    final rank = _sectOrder.indexOf(name);
    var at = s.children.length;
    for (var k = 0; k < s.children.length; k++) {
      final x = s.children[k];
      if (x is XmlElement && _sectOrder.indexOf(x.name.local) > rank) {
        at = k;
        break;
      }
    }
    s.children.insert(at, el);
    return el;
  }

  void setPaperSize(String key) {
    final size = kDocxPaperSizes[key];
    if (size == null) return;
    _editSections((s) {
      final sz = _sectChild(s, 'pgSz');
      final land = _i(sz, 'w', 0) > _i(sz, 'h', 0) ||
          sz.getAttribute('w:orient') == 'landscape';
      _set(sz, 'w', land ? size.$2 : size.$1);
      _set(sz, 'h', land ? size.$1 : size.$2);
    });
  }

  void setLandscape(bool landscape) {
    _editSections((s) {
      final sz = _sectChild(s, 'pgSz');
      final w = _i(sz, 'w', 11906), h = _i(sz, 'h', 16838);
      final isLand = w > h;
      if (isLand != landscape) {
        _set(sz, 'w', h);
        _set(sz, 'h', w);
      }
      if (landscape) {
        _set(sz, 'orient', 'landscape');
      } else {
        sz.attributes.removeWhere((a) => a.name.local == 'orient');
      }
    });
  }

  void setMarginPreset(String key) {
    final m = kDocxMarginPresets[key];
    if (m == null) return;
    _editSections((s) {
      final mar = _sectChild(s, 'pgMar');
      _set(mar, 'top', m.$1);
      _set(mar, 'bottom', m.$1);
      _set(mar, 'left', m.$2);
      _set(mar, 'right', m.$2);
      for (final a in const ['header', 'footer', 'gutter']) {
        if (mar.getAttribute('w:$a') == null) {
          _set(mar, a, a == 'gutter' ? 0 : 708);
        }
      }
    });
  }

  void setColumns(int n) {
    if (n < 1 || n > 3) return;
    _editSections((s) {
      final cols = _sectChild(s, 'cols');
      _set(cols, 'num', n);
      if (cols.getAttribute('w:space') == null) _set(cols, 'space', 720);
    });
  }
}
