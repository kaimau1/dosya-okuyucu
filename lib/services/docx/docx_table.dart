part of 'docx_document.dart';

/// Faz 24b — tablo yapısı işlemleri (satır/sütun ekle-sil, başlık satırı,
/// bantlı satır, hücre gölgesi). Model ilkesi Faz 24a'dakiyle aynı: işlem
/// yalnız paragraf listesini ve hücre başvurularını değiştirir; `w:tr`/`w:tc`
/// sırası `commit()`te `_reconcileTable` ile modele eşitlenir — bu yüzden
/// geri al/yinele ek iş gerektirmez.

/// Tablonun bir satırının satır-düğümü.
XmlElement? _rowOf(DocxCellRef c) {
  final p = c.cell.parent;
  return p is XmlElement ? p : null;
}

extension DocxTableOps on DocxDocument {
  /// [i]. paragrafın tablosu (hücrede değilse null).
  XmlElement? tableAt(int i) =>
      i >= 0 && i < paras.length ? paras[i].cell?.table : null;

  List<int> _idx(bool Function(DocxCellRef c) test) => [
        for (var k = 0; k < paras.length; k++)
          if (paras[k].cell != null && test(paras[k].cell!)) k,
      ];

  /// Tablonun satır sayısı / sütun sayısı (ızgara).
  (int, int) tableSize(XmlElement tbl) {
    var rows = 0, cols = 0;
    for (final p in paras) {
      final c = p.cell;
      if (c == null || !identical(c.table, tbl)) continue;
      rows = math.max(rows, c.row + 1);
      cols = math.max(cols, c.col + c.gridSpan);
    }
    return (rows, cols);
  }

  void _manage(XmlElement tbl) {
    if (!_newTables.any((t) => identical(t, tbl))) _newTables.add(tbl);
  }

  /// Hücre başvurularının satır/sütun numaralarını belge sırasına göre yeniler.
  void _renumber(XmlElement tbl) {
    final rowIds = <XmlElement>[];
    final colAt = <XmlElement, int>{};
    for (var k = 0; k < paras.length; k++) {
      final c = paras[k].cell;
      if (c == null || !identical(c.table, tbl)) continue;
      final tr = _rowOf(c);
      if (tr == null) continue;
      var r = rowIds.indexWhere((x) => identical(x, tr));
      if (r < 0) {
        rowIds.add(tr);
        r = rowIds.length - 1;
      }
    }
    // Her satırda hücreleri ilk görülme sırasıyla say.
    final seen = <XmlElement, List<XmlElement>>{};
    for (final p in paras) {
      final c = p.cell;
      if (c == null || !identical(c.table, tbl)) continue;
      final tr = _rowOf(c);
      if (tr == null) continue;
      final cells = seen.putIfAbsent(tr, () => []);
      if (!cells.any((x) => identical(x, c.cell))) cells.add(c.cell);
    }
    for (final tr in seen.keys) {
      var col = 0;
      for (final tc in seen[tr]!) {
        colAt[tc] = col;
        col += _spanOf(tc);
      }
    }
    for (var k = 0; k < paras.length; k++) {
      final p = paras[k];
      final c = p.cell;
      if (c == null || !identical(c.table, tbl)) continue;
      final r = rowIds.indexWhere((x) => identical(x, _rowOf(c)));
      final nc = DocxCellRef(tbl, c.cell, r, colAt[c.cell] ?? c.col, c.gridSpan);
      if (nc.row == c.row && nc.col == c.col) continue;
      final next = p.copyWith(cell: nc);
      final src = p.source;
      if (src != null && identical(_writtenAs[src], p)) _writtenAs[src] = next;
      paras[k] = next;
    }
  }

  static int _spanOf(XmlElement tc) {
    for (final k in tc.childElements) {
      if (k.name.local != 'tcPr') continue;
      for (final g in k.childElements) {
        if (g.name.local == 'gridSpan') {
          return int.tryParse(g.getAttribute('w:val') ?? '') ?? 1;
        }
      }
    }
    return 1;
  }

  XmlElement _newCellLike(XmlElement ref) {
    final tc = XmlElement(XmlName.fromString('w:tc'));
    XmlElement? w;
    for (final k in ref.childElements) {
      if (k.name.local != 'tcPr') continue;
      for (final g in k.childElements) {
        if (g.name.local == 'tcW' || g.name.local == 'gridSpan') {
          (w ??= XmlElement(XmlName.fromString('w:tcPr'))).children.add(g.copy());
        }
      }
    }
    if (w != null) tc.children.add(w);
    return tc;
  }

  // ── satır ───────────────────────────────────────────────────────────────

  /// [at]'in satırının üstüne/altına boş satır ekler; yeni satırın ilk
  /// hücresinin paragraf sırasını döndürür (-1: hücrede değil).
  int insertTableRow(int at, {required bool below}) {
    final ref = at >= 0 && at < paras.length ? paras[at].cell : null;
    if (ref == null) return -1;
    final tr = _rowOf(ref);
    if (tr == null) return -1;
    final tbl = ref.table;
    _manage(tbl);
    final rowIdx = _idx((c) => identical(_rowOf(c), tr));
    final newTr = XmlElement(XmlName.fromString('w:tr'));
    final cells = <XmlElement>[];
    for (final tc in tr.childElements.where((e) => e.name.local == 'tc')) {
      final n = _newCellLike(tc);
      newTr.children.add(n);
      cells.add(n);
    }
    final fresh = [
      for (final tc in cells)
        _emptyPara(tc, cell: DocxCellRef(tbl, tc, 0, 0, _spanOf(tc))),
    ];
    final insertAt = below ? rowIdx.last + 1 : rowIdx.first;
    paras.insertAll(insertAt, fresh);
    _renumber(tbl);
    return insertAt;
  }

  /// [at]'in satırını siler; yalnız tek satır varsa tabloyu siler. İmleç
  /// için yeni paragraf sırasını döndürür.
  int deleteTableRow(int at) {
    final ref = at >= 0 && at < paras.length ? paras[at].cell : null;
    if (ref == null) return at;
    final (rows, _) = tableSize(ref.table);
    if (rows <= 1) return deleteTable(at);
    final tr = _rowOf(ref);
    final gone = _idx((c) => identical(_rowOf(c), tr));
    _manage(ref.table);
    for (final k in gone.reversed) {
      paras.removeAt(k);
    }
    _renumber(ref.table);
    return math.min(gone.first, paras.length - 1);
  }

  // ── sütun ───────────────────────────────────────────────────────────────

  /// [at]'in sütununun soluna/sağına boş sütun ekler; yeni hücrenin
  /// paragraf sırasını döndürür.
  int insertTableColumn(int at, {required bool right}) {
    final ref = at >= 0 && at < paras.length ? paras[at].cell : null;
    if (ref == null) return -1;
    final tbl = ref.table;
    final (_, cols) = tableSize(tbl);
    if (cols >= 20) return -1;
    _manage(tbl);
    final target = right ? ref.col + ref.gridSpan - 1 : ref.col;
    // Satır başına: hedef sütunu içeren hücre.
    final rowCells = <XmlElement, XmlElement>{};
    final lastIdx = <XmlElement, int>{};
    final firstIdx = <XmlElement, int>{};
    for (var k = 0; k < paras.length; k++) {
      final c = paras[k].cell;
      if (c == null || !identical(c.table, tbl)) continue;
      if (c.col <= target && target < c.col + c.gridSpan) {
        final tr = _rowOf(c);
        if (tr == null) continue;
        rowCells[tr] = c.cell;
        lastIdx[tr] = k;
        firstIdx.putIfAbsent(tr, () => k);
      }
    }
    final inserts = <(int, DocxPara)>[];
    XmlElement? refNew;
    final refTr = _rowOf(ref);
    for (final tr in rowCells.keys) {
      final host = rowCells[tr]!;
      final n = _newCellLike(host);
      // gridSpan'lı hücre genişlemesin: yeni hücre tek sütun.
      for (final k in n.childElements.toList()) {
        if (k.name.local == 'tcPr') {
          k.children.removeWhere(
              (g) => g is XmlElement && g.name.local == 'gridSpan');
          if (k.children.isEmpty) n.children.remove(k);
        }
      }
      final hostTr = host.parent!;
      hostTr.children.insert(hostTr.children.indexOf(host) + (right ? 1 : 0), n);
      final cell = DocxCellRef(tbl, n, 0, 0, 1);
      if (identical(tr, refTr)) refNew = n;
      inserts.add((right ? lastIdx[tr]! + 1 : firstIdx[tr]!, _emptyPara(n, cell: cell)));
    }
    inserts.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (k, p) in inserts) {
      paras.insert(k, p);
    }
    // ızgara sütunu
    final grid = _gridOf(tbl);
    if (grid != null) {
      final cols = grid.childElements.where((e) => e.name.local == 'gridCol').toList();
      final w = cols.isEmpty ? '2000' : (cols[math.min(target, cols.length - 1)].getAttribute('w:w') ?? '2000');
      final el = XmlElement(XmlName.fromString('w:gridCol'),
          [XmlAttribute(XmlName.fromString('w:w'), w)]);
      final pos = math.min(right ? target + 1 : target, cols.length);
      if (pos >= cols.length) {
        grid.children.add(el);
      } else {
        grid.children.insert(grid.children.indexOf(cols[pos]), el);
      }
    }
    _renumber(tbl);
    final firstNew = paras.indexWhere((p) => identical(p.cell?.cell, refNew));
    _xmlDirty = true;
    return firstNew;
  }

  XmlElement? _gridOf(XmlElement tbl) {
    for (final k in tbl.childElements) {
      if (k.name.local == 'tblGrid') return k;
    }
    return null;
  }

  /// [at]'in sütununu siler (birleşik hücrede genişliği azaltır); tek
  /// sütunsa tabloyu siler. İmleç için yeni paragraf sırasını döndürür.
  int deleteTableColumn(int at) {
    final ref = at >= 0 && at < paras.length ? paras[at].cell : null;
    if (ref == null) return at;
    final tbl = ref.table;
    final (_, cols) = tableSize(tbl);
    if (cols <= 1) return deleteTable(at);
    _manage(tbl);
    final col = ref.col;
    final gone = <int>[];
    final narrowed = <XmlElement>{};
    for (var k = 0; k < paras.length; k++) {
      final c = paras[k].cell;
      if (c == null || !identical(c.table, tbl)) continue;
      if (c.col <= col && col < c.col + c.gridSpan) {
        if (c.gridSpan > 1) {
          narrowed.add(c.cell);
        } else {
          gone.add(k);
        }
      }
    }
    for (final tc in narrowed) {
      for (final k in tc.childElements) {
        if (k.name.local != 'tcPr') continue;
        for (final g in k.childElements.toList()) {
          if (g.name.local != 'gridSpan') continue;
          final n = (int.tryParse(g.getAttribute('w:val') ?? '') ?? 1) - 1;
          if (n <= 1) {
            k.children.remove(g);
          } else {
            _set(g, 'val', n);
          }
        }
      }
    }
    for (final k in gone.reversed) {
      paras.removeAt(k);
    }
    for (var k = 0; k < paras.length; k++) {
      final c = paras[k].cell;
      if (c != null && narrowed.any((x) => identical(x, c.cell))) {
        paras[k] = paras[k].copyWith(
            cell: DocxCellRef(tbl, c.cell, c.row, c.col, _spanOf(c.cell)));
      }
    }
    final grid = _gridOf(tbl);
    if (grid != null) {
      final cs = grid.childElements.where((e) => e.name.local == 'gridCol').toList();
      if (col < cs.length) grid.children.remove(cs[col]);
    }
    _renumber(tbl);
    _xmlDirty = true;
    return math.min(gone.isEmpty ? at : gone.first, paras.length - 1);
  }

  /// Tabloyu siler; imleç için yeni paragraf sırasını döndürür.
  int deleteTable(int at) {
    final tbl = tableAt(at);
    if (tbl == null) return at;
    _manage(tbl);
    final gone = _idx((c) => identical(c.table, tbl));
    for (final k in gone.reversed) {
      paras.removeAt(k);
    }
    if (paras.isEmpty) paras.add(_emptyPara(body));
    return math.min(gone.first, paras.length - 1);
  }

  /// Hücre içindeki iç içe olmayan tablonun belge sırasındaki ilk paragrafı.
  int firstParaOfTable(XmlElement tbl) =>
      paras.indexWhere((p) => identical(p.cell?.table, tbl));

  // ── görünüm (geri alınabilir) ───────────────────────────────────────────

  XmlElement _tblPr(XmlElement tbl) {
    for (final k in tbl.childElements) {
      if (k.name.local == 'tblPr') return k;
    }
    final el = XmlElement(XmlName.fromString('w:tblPr'));
    tbl.children.insert(0, el);
    return el;
  }

  void _trackProp(XmlElement e) {
    if (!_tracked.any((x) => identical(x, e))) _tracked.add(e);
  }

  XmlElement _look(XmlElement tbl) {
    final pr = _tblPr(tbl);
    for (final k in pr.childElements) {
      if (k.name.local == 'tblLook') return k;
    }
    final el = XmlElement(XmlName.fromString('w:tblLook'), [
      XmlAttribute(XmlName.fromString('w:val'), '04A0'),
      XmlAttribute(XmlName.fromString('w:firstRow'), '1'),
      XmlAttribute(XmlName.fromString('w:lastRow'), '0'),
      XmlAttribute(XmlName.fromString('w:firstColumn'), '1'),
      XmlAttribute(XmlName.fromString('w:lastColumn'), '0'),
      XmlAttribute(XmlName.fromString('w:noHBand'), '0'),
      XmlAttribute(XmlName.fromString('w:noVBand'), '1'),
    ]);
    pr.children.add(el);
    return el;
  }

  /// Geri al anlık görüntüsüne girmesi için, DEĞİŞİKLİKTEN ÖNCE çağrılır.
  void trackTableLook(XmlElement tbl) => _trackProp(_look(tbl));

  void trackCellProps(int at) {
    final tc = at >= 0 && at < paras.length ? paras[at].cell?.cell : null;
    if (tc == null) return;
    _trackProp(_cellPr(tc));
  }

  XmlElement _cellPr(XmlElement tc) {
    for (final k in tc.childElements) {
      if (k.name.local == 'tcPr') return k;
    }
    final pr = XmlElement(XmlName.fromString('w:tcPr'));
    tc.children.insert(0, pr);
    return pr;
  }

  bool tableHeaderRow(XmlElement tbl) =>
      _look(tbl).getAttribute('w:firstRow') != '0';

  bool tableBandedRows(XmlElement tbl) =>
      _look(tbl).getAttribute('w:noHBand') == '0';

  /// Başlık satırı: ilk satır kalın + `tblHeader` (sayfa geçişinde yinelenir).
  void setTableHeaderRow(XmlElement tbl, bool on) {
    final look = _look(tbl);
    _trackProp(look);
    _set(look, 'firstRow', on ? 1 : 0);
    _syncLookVal(look);
    _xmlDirty = true;
  }

  void setTableBandedRows(XmlElement tbl, bool on) {
    final look = _look(tbl);
    _trackProp(look);
    _set(look, 'noHBand', on ? 0 : 1);
    _syncLookVal(look);
    _xmlDirty = true;
  }

  void _syncLookVal(XmlElement look) {
    bool f(String n) => look.getAttribute('w:$n') == '1';
    final v = (f('firstRow') ? 0x20 : 0) |
        (f('lastRow') ? 0x40 : 0) |
        (f('firstColumn') ? 0x80 : 0) |
        (f('lastColumn') ? 0x100 : 0) |
        (look.getAttribute('w:noHBand') == '1' ? 0x200 : 0) |
        (look.getAttribute('w:noVBand') == '1' ? 0x400 : 0);
    _set(look, 'val', v.toRadixString(16).toUpperCase().padLeft(4, '0'));
  }

  /// [at] hücresinin gölgesi (null = yok), `0xRRGGBB` olarak.
  int? cellShade(int at) {
    final tc = at >= 0 && at < paras.length ? paras[at].cell?.cell : null;
    if (tc == null) return null;
    for (final k in tc.childElements) {
      if (k.name.local != 'tcPr') continue;
      for (final s in k.childElements) {
        if (s.name.local != 'shd') continue;
        final f = s.getAttribute('w:fill');
        if (f == null || f == 'auto') return null;
        return int.tryParse(f, radix: 16);
      }
    }
    return null;
  }

  /// [at] hücresine gölge verir (null = kaldır).
  void setCellShade(int at, int? rgb) {
    final tc = at >= 0 && at < paras.length ? paras[at].cell?.cell : null;
    if (tc == null) return;
    final pr = _cellPr(tc);
    _trackProp(pr);
    pr.children.removeWhere((n) => n is XmlElement && n.name.local == 'shd');
    if (rgb != null) {
      final shd = XmlElement(XmlName.fromString('w:shd'), [
        XmlAttribute(XmlName.fromString('w:val'), 'clear'),
        XmlAttribute(XmlName.fromString('w:color'), 'auto'),
        XmlAttribute(XmlName.fromString('w:fill'),
            (rgb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')),
      ]);
      // Şema sırası: tcW, gridSpan, vMerge, tcBorders, shd, …
      const before = {'cnfStyle', 'tcW', 'gridSpan', 'hMerge', 'vMerge', 'tcBorders'};
      var idx = 0;
      for (var k = 0; k < pr.children.length; k++) {
        final x = pr.children[k];
        if (x is XmlElement && before.contains(x.name.local)) idx = k + 1;
      }
      pr.children.insert(idx, shd);
    }
    _xmlDirty = true;
  }

  // ── eşitleme ────────────────────────────────────────────────────────────

  /// Tablonun `w:tr`/`w:tc` sırasını, ızgarasını modele eşitler.
  bool _reconcileTable(XmlElement tbl) {
    final rows = <XmlElement>[];
    final cells = <XmlElement, List<XmlElement>>{};
    for (final p in paras) {
      final c = p.cell;
      if (c == null || !identical(c.table, tbl)) continue;
      final tr = _rowOf(c);
      if (tr == null) continue;
      if (!rows.any((x) => identical(x, tr))) rows.add(tr);
      final l = cells.putIfAbsent(tr, () => []);
      if (!l.any((x) => identical(x, c.cell))) l.add(c.cell);
    }
    var changed = false;
    bool sameOrder(List<XmlNode> have, List<XmlElement> want) {
      if (have.length != want.length) return false;
      for (var k = 0; k < want.length; k++) {
        if (!identical(have[k], want[k])) return false;
      }
      return true;
    }

    final haveRows = tbl.children
        .where((n) => n is XmlElement && n.name.local == 'tr')
        .toList();
    if (!sameOrder(haveRows, rows)) {
      var at = tbl.children.indexWhere(
          (n) => n is XmlElement && n.name.local == 'tr');
      if (at < 0) at = tbl.children.length;
      tbl.children
          .removeWhere((n) => n is XmlElement && n.name.local == 'tr');
      at = math.min(at, tbl.children.length);
      tbl.children.insertAll(at, rows);
      changed = true;
    }
    var width = 0;
    for (final tr in rows) {
      final want = cells[tr]!;
      final have = tr.children
          .where((n) => n is XmlElement && n.name.local == 'tc')
          .toList();
      if (!sameOrder(have, want)) {
        var at = tr.children.indexWhere(
            (n) => n is XmlElement && n.name.local == 'tc');
        if (at < 0) at = tr.children.length;
        tr.children
            .removeWhere((n) => n is XmlElement && n.name.local == 'tc');
        at = math.min(at, tr.children.length);
        tr.children.insertAll(at, want);
        changed = true;
      }
      width = math.max(width, want.fold<int>(0, (a, tc) => a + _spanOf(tc)));
    }
    final grid = _gridOf(tbl);
    if (grid != null && width > 0) {
      final cs = grid.childElements.where((e) => e.name.local == 'gridCol').toList();
      if (cs.length < width) {
        final w = cs.isEmpty ? '2000' : (cs.last.getAttribute('w:w') ?? '2000');
        for (var k = cs.length; k < width; k++) {
          grid.children.add(XmlElement(XmlName.fromString('w:gridCol'),
              [XmlAttribute(XmlName.fromString('w:w'), w)]));
        }
        changed = true;
      } else if (cs.length > width) {
        for (var k = width; k < cs.length; k++) {
          grid.children.remove(cs[k]);
        }
        changed = true;
      }
    }
    return changed;
  }
}
