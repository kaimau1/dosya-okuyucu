part of 'docx_document.dart';

/// Faz 24b — Gözden Geçir (izlenen değişiklikler) ve üst/alt bilgi.

const _trackedNames = {
  'ins', 'del', 'moveFrom', 'moveTo', 'moveFromRangeStart', 'moveFromRangeEnd',
  'moveToRangeStart', 'moveToRangeEnd', 'rPrChange', 'pPrChange',
  'sectPrChange', 'tblPrChange', 'tcPrChange', 'trPrChange', 'tblGridChange',
  'numberingChange', 'cellIns', 'cellDel', 'cellMerge',
};

const _wRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

/// Üst/alt bilgi özeti (varsayılan tür).
class DocxHeaderFooter {
  final String text;
  final bool pageNumber;

  /// Düzenlenebilir mi (tek paragraf, resim/tablo yok).
  final bool editable;
  const DocxHeaderFooter(this.text, this.pageNumber, this.editable);
}

extension DocxReview on DocxDocument {
  // ── izlenen değişiklikler ───────────────────────────────────────────────

  Iterable<XmlElement> _trackedNodes() => doc.rootElement.descendantElements
      .where((e) => _trackedNames.contains(e.name.local));

  /// Bekleyen izlenen değişiklik sayısı (yerleşim öğeleri sayılmaz).
  int trackedChangeCount() => _trackedNodes()
      .where((e) => const {'ins', 'del', 'moveFrom', 'moveTo', 'rPrChange', 'pPrChange'}
          .contains(e.name.local))
      .length;

  /// Tüm izlenen değişiklikleri kabul eder ([accept]) ya da reddeder.
  /// Modeli yeniden okur — GERİ ALINAMAZ (çağıran geçmişi sıfırlar).
  /// Kabul edilen silinmiş paragraf işareti paragrafları birleştirmez.
  void resolveTrackedChanges({required bool accept}) {
    for (var pass = 0; pass < 8; pass++) {
      final nodes = _trackedNodes().toList();
      if (nodes.isEmpty) break;
      for (final e in nodes) {
        if (e.parent == null) continue;
        _resolveOne(e, accept);
      }
    }
    _writtenAs.clear();
    _newTables.clear();
    _tracked.clear();
    paras = _readBody();
    _xmlDirty = true;
  }

  void _unwrap(XmlElement e, {bool delTextToText = false}) {
    final parent = e.parent;
    if (parent == null) return;
    final at = parent.children.indexOf(e);
    final kids = e.children.map((c) => c.copy()).toList();
    if (delTextToText) {
      for (final k in kids) {
        if (k is! XmlElement) continue;
        for (final d in k.descendantElements.toList()) {
          if (d.name.local != 'delText') continue;
          final t = XmlElement(XmlName.fromString('w:t'),
              d.attributes.map((a) => a.copy()), d.children.map((c) => c.copy()));
          d.parent!.children[d.parent!.children.indexOf(d)] = t;
        }
      }
    }
    parent.children.removeAt(at);
    parent.children.insertAll(at, kids);
  }

  void _resolveOne(XmlElement e, bool accept) {
    final name = e.name.local;
    final parentName = e.parent is XmlElement ? (e.parent as XmlElement).name.local : '';
    void drop() => e.parent!.children.remove(e);
    switch (name) {
      case 'ins' || 'moveTo':
        if (parentName == 'rPr') {
          drop(); // paragraf işareti
        } else if (parentName == 'trPr') {
          if (accept) {
            drop();
          } else {
            e.parent!.parent?.parent?.children.remove(e.parent!.parent);
          }
        } else if (accept) {
          _unwrap(e);
        } else {
          drop();
        }
      case 'del' || 'moveFrom':
        if (parentName == 'rPr') {
          drop();
        } else if (parentName == 'trPr') {
          if (accept) {
            e.parent!.parent?.parent?.children.remove(e.parent!.parent);
          } else {
            drop();
          }
        } else if (accept) {
          drop();
        } else {
          _unwrap(e, delTextToText: true);
        }
      case 'rPrChange' || 'pPrChange':
        final owner = e.parent;
        if (!accept && owner != null) {
          // Eski özellikler: değişimin içindeki rPr/pPr çocukları.
          XmlElement? old;
          for (final k in e.childElements) {
            if (k.name.local == 'rPr' || k.name.local == 'pPr') old = k;
          }
          if (name == 'rPrChange') {
            owner.children.removeWhere((n) => !identical(n, e));
          } else {
            owner.children.removeWhere((n) =>
                !identical(n, e) &&
                !(n is XmlElement &&
                    (n.name.local == 'rPr' || n.name.local == 'sectPr')));
          }
          if (old != null) {
            owner.children.insertAll(0, old.children.map((c) => c.copy()));
          }
        }
        drop();
      default:
        drop();
    }
  }

  // ── üst / alt bilgi ─────────────────────────────────────────────────────

  String? _hfTarget(bool header) {
    final ref = header ? 'headerReference' : 'footerReference';
    final sect = _mainSect();
    for (final k in sect.childElements) {
      if (k.name.local != ref || k.getAttribute('w:type') != 'default') continue;
      String? id;
      for (final a in k.attributes) {
        if (a.name.local == 'id') id = a.value;
      }
      if (id == null) continue;
      final rels = _relsPart();
      for (final r in rels.rootElement.childElements) {
        if (r.getAttribute('Id') == id) {
          final t = r.getAttribute('Target') ?? '';
          return t.startsWith('/') ? t.substring(1) : 'word/$t';
        }
      }
    }
    return null;
  }

  XmlDocument? _hfPart(String name) {
    final have = _parts[name];
    if (have != null) return have;
    final read = _partReader?.call(name);
    if (read != null) _parts[name] = read;
    return read;
  }

  DocxHeaderFooter headerFooter({required bool header}) {
    final name = _hfTarget(header);
    final x = name == null ? null : _hfPart(name);
    if (x == null) return const DocxHeaderFooter('', false, true);
    final ps = x.rootElement.childElements.toList();
    final onlyOneP = ps.length == 1 && ps.first.name.local == 'p';
    final p = ps.where((e) => e.name.local == 'p').firstOrNull;
    final rich = p == null ||
        p.descendantElements.any((e) =>
            const {'drawing', 'pict', 'object', 'tab'}.contains(e.name.local));
    final sb = StringBuffer();
    var page = false;
    if (p != null) {
      for (final e in p.descendantElements) {
        switch (e.name.local) {
          case 't':
            sb.write(e.innerText);
          case 'instrText':
            if (e.innerText.toUpperCase().contains('PAGE')) page = true;
          case 'fldSimple':
            if ((e.getAttribute('w:instr') ?? '').toUpperCase().contains('PAGE')) {
              page = true;
            }
        }
      }
    }
    // Sayfa numarası alanının önbellek metni ("1") yazıya karışmasın.
    var text = sb.toString();
    if (page && RegExp(r'\d+$').hasMatch(text)) {
      text = text.replaceFirst(RegExp(r'\s*\d+$'), '');
    }
    return DocxHeaderFooter(text, page, onlyOneP && !rich);
  }

  /// Varsayılan üst/alt bilgiyi [text] (+ isteğe bağlı sayfa numarası) yapar;
  /// boşsa ve parça yoksa hiçbir şey yaratmaz. Düzenlenemeyen (zengin)
  /// içerikte false döner.
  bool setHeaderFooter(
      {required bool header,
      required String text,
      required bool pageNumber,
      String align = 'center'}) {
    var name = _hfTarget(header);
    var x = name == null ? null : _hfPart(name);
    if (x == null) {
      if (text.isEmpty && !pageNumber) return true;
      name = _createHf(header);
      x = _parts[name]!;
    } else if (!headerFooter(header: header).editable) {
      return false;
    }
    final root = x.rootElement;
    final old = root.childElements.where((e) => e.name.local == 'p').firstOrNull;
    final pPr = old?.childElements.where((e) => e.name.local == 'pPr').firstOrNull;
    final b = StringBuffer('<w:p $_wMain>');
    if (pPr == null) {
      b.write('<w:pPr><w:jc w:val="$align"/></w:pPr>');
    }
    if (text.isNotEmpty) {
      b.write('<w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r>');
    }
    if (pageNumber) {
      if (text.isNotEmpty) b.write('<w:r><w:t xml:space="preserve"> </w:t></w:r>');
      b.write('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
          '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
          '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
          '<w:r><w:t>1</w:t></w:r>'
          '<w:r><w:fldChar w:fldCharType="end"/></w:r>');
    }
    b.write('</w:p>');
    final fresh = XmlDocument.parse(b.toString()).rootElement.copy();
    if (pPr != null) fresh.children.insert(0, pPr.copy());
    root.children
      ..clear()
      ..add(fresh);
    _dirtyParts.add(name!);
    return true;
  }

  String _createHf(bool header) {
    final kind = header ? 'header' : 'footer';
    var n = 1;
    String part() => 'word/$kind$n.xml';
    bool exists(String nm) =>
        _parts.containsKey(nm) ||
        _archive.files.any((f) => f.name == nm);
    while (exists(part())) {
      n++;
    }
    final name = part();
    final rels = _relsPart();
    var maxId = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) maxId = math.max(maxId, int.parse(m[1]!));
    }
    final id = 'rId${maxId + 1}';
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), id),
      XmlAttribute(XmlName('Type'), '$_wRel/$kind'),
      XmlAttribute(XmlName('Target'), '$kind$n.xml'),
    ]));
    _dirtyParts.add('word/_rels/document.xml.rels');
    _parts[name] = XmlDocument.parse(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:${header ? 'hdr' : 'ftr'} $_wMain xmlns:r="$_wRel"><w:p/></w:${header ? 'hdr' : 'ftr'}>');
    final ct = _parts['[Content_Types].xml'] ??
        _partReader?.call('[Content_Types].xml');
    if (ct != null) {
      ct.rootElement.children.add(XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), '/$name'),
        XmlAttribute(XmlName('ContentType'),
            'application/vnd.openxmlformats-officedocument.wordprocessingml.$kind+xml'),
      ]));
      _parts['[Content_Types].xml'] = ct;
      _dirtyParts.add('[Content_Types].xml');
    }
    // `r:` ad alanı kökte tanımlı olsun.
    final root = doc.rootElement;
    if (root.getAttribute('xmlns:r') == null) {
      root.attributes.add(XmlAttribute(XmlName.fromString('xmlns:r'), _wRel));
    }
    final sect = _mainSect();
    final ref = XmlElement(XmlName.fromString('w:${kind}Reference'), [
      XmlAttribute(XmlName.fromString('w:type'), 'default'),
      XmlAttribute(XmlName.fromString('r:id'), id),
    ]);
    var at = 0;
    if (!header) {
      for (var k = 0; k < sect.children.length; k++) {
        final c = sect.children[k];
        if (c is XmlElement && c.name.local == 'headerReference') at = k + 1;
      }
    }
    sect.children.insert(at, ref);
    _xmlDirty = true;
    return name;
  }
}
