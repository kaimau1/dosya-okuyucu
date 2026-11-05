/// **Faz 37 madde 3 — tablo: hücre birleştir/böl, kenarlık, otomatik sığdır,
/// sıralama.** İmleç paragrafı dizininden hücre bulunur (paket düzeyi).
library;

import 'package:xml/xml.dart';

import 'docx_package.dart';
import 'docx_style_ops.dart' show DocxOp;

/// İşlem yapılamadığında (ör. birleşik satırlı tabloyu sıralama).
class DocxTableException implements Exception {
  final String code;
  const DocxTableException(this.code);
  @override
  String toString() => 'DocxTableException($code)';
}

class _Cell {
  final XmlElement tbl, tr, tc;
  const _Cell(this.tbl, this.tr, this.tc);
}

abstract final class DocxTableTools {
  static _Cell? _at(DocxPackage pkg, int i) {
    final paras = pkg.modelParagraphs();
    if (i < 0 || i >= paras.length) return null;
    XmlNode? n = paras[i];
    XmlElement? tc;
    while (n != null) {
      if (n is XmlElement && n.name.local == 'tc' && tc == null) tc = n;
      if (n is XmlElement && n.name.local == 'tbl' && tc != null) {
        return _Cell(n, tc.parent as XmlElement, tc);
      }
      n = n.parent;
    }
    return null;
  }

  static int _span(XmlElement tc) =>
      int.tryParse(attrOf(kid(kid(tc, 'tcPr'), 'gridSpan')) ?? '') ?? 1;

  static void _setSpan(XmlElement tc, int span) {
    final pr = ensureKid(tc, 'tcPr', order: const ['tcPr']);
    if (pr.parent == tc && tc.children.indexOf(pr) != 0) {
      pr.remove();
      tc.children.insert(0, pr);
    }
    kid(pr, 'gridSpan')?.remove();
    if (span > 1) _put(pr, wv('gridSpan', '$span'), kTcPrOrder);
  }

  static void _put(XmlElement parent, XmlElement el, List<String> order) {
    final rank = order.indexOf(el.name.local);
    for (final c in parent.childElements) {
      if (order.indexOf(c.name.local) > rank) {
        parent.children.insert(parent.children.indexOf(c), el);
        return;
      }
    }
    parent.children.add(el);
  }

  /// Satırdaki hücrenin ızgara sütunu.
  static int _gridCol(XmlElement tr, XmlElement tc) {
    var col = 0;
    for (final c in kids(tr, 'tc')) {
      if (identical(c, tc)) return col;
      col += _span(c);
    }
    return -1;
  }

  static XmlElement? _cellAtCol(XmlElement tr, int col) {
    var c0 = 0;
    for (final c in kids(tr, 'tc')) {
      if (c0 == col) return c;
      c0 += _span(c);
    }
    return null;
  }

  static bool _empty(XmlElement tc) => tc.innerText.trim().isEmpty &&
      !tc.descendantElements.any((e) => e.name.local == 'drawing');

  /// İçerik taşıma: [from]'un paragrafları [to]'nun sonuna (boşsa atlanır).
  static void _moveContent(XmlElement from, XmlElement to) {
    if (_empty(from)) return;
    if (_empty(to)) {
      to.children.removeWhere((n) => n is XmlElement && n.name.local == 'p');
    }
    for (final p in from.childElements.where((e) => e.name.local != 'tcPr').toList()) {
      p.remove();
      to.children.add(p);
    }
    if (!from.childElements.any((e) => e.name.local == 'p')) from.children.add(w('p'));
  }

  /// Sağdaki hücreyle birleştir (yatay).
  static DocxOp mergeRight(int i) => (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        final cells = kids(c.tr, 'tc').toList();
        final k = cells.indexOf(c.tc);
        if (k < 0 || k + 1 >= cells.length) throw const DocxTableException('no_neighbor');
        final next = cells[k + 1];
        _moveContent(next, c.tc);
        _setSpan(c.tc, _span(c.tc) + _span(next));
        next.remove();
      };

  /// Alttaki hücreyle birleştir (dikey, `w:vMerge`).
  static DocxOp mergeDown(int i) => (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        final rows = kids(c.tbl, 'tr').toList();
        final r = rows.indexOf(c.tr);
        final col = _gridCol(c.tr, c.tc);
        if (r + 1 >= rows.length) throw const DocxTableException('no_neighbor');
        // Birleşimin altındaki ilk serbest satır.
        var below = r + 1;
        while (below < rows.length) {
          final b = _cellAtCol(rows[below], col);
          final vm = kid(kid(b, 'tcPr'), 'vMerge');
          if (b == null) throw const DocxTableException('no_neighbor');
          if (vm == null || attrOf(vm) == 'restart') break;
          below++;
        }
        final target = below < rows.length ? _cellAtCol(rows[below], col) : null;
        if (target == null || _span(target) != _span(c.tc)) {
          throw const DocxTableException('shape');
        }
        final topPr = ensureKid(c.tc, 'tcPr');
        if (kid(topPr, 'vMerge') == null) {
          _put(topPr, wv('vMerge', 'restart'), kTcPrOrder);
        }
        _moveContent(target, c.tc);
        final pr = ensureKid(target, 'tcPr');
        if (target.children.indexOf(pr) != 0) {
          pr.remove();
          target.children.insert(0, pr);
        }
        kid(pr, 'vMerge')?.remove();
        _put(pr, w('vMerge'), kTcPrOrder);
      };

  /// Böl: yatay birleşik hücreyi tek tek, dikey birleşimi çöz.
  static DocxOp split(int i) => (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        final span = _span(c.tc);
        final vm = kid(kid(c.tc, 'tcPr'), 'vMerge');
        if (span <= 1 && vm == null) throw const DocxTableException('not_merged');
        if (span > 1) {
          _setSpan(c.tc, 1);
          final at = c.tr.children.indexOf(c.tc) + 1;
          c.tr.children.insertAll(at, [
            for (var k = 1; k < span; k++) w('tc', kids: [w('p')]),
          ]);
        }
        if (vm != null) {
          final rows = kids(c.tbl, 'tr').toList();
          final col = _gridCol(c.tr, c.tc);
          // Birleşimin başı (yukarı doğru restart).
          var top = rows.indexOf(c.tr);
          while (top > 0 &&
              attrOf(kid(kid(_cellAtCol(rows[top], col), 'tcPr'), 'vMerge')) != 'restart') {
            top--;
          }
          for (var r = top; r < rows.length; r++) {
            final cell = _cellAtCol(rows[r], col);
            final m = kid(kid(cell, 'tcPr'), 'vMerge');
            if (m == null || (r > top && attrOf(m) == 'restart')) break;
            m.remove();
          }
        }
      };

  /// Kenarlık hazırları: `all` | `outer` | `inner` | `none`.
  static DocxOp borders(int i, String preset) => (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        final pr = _tblPr(c.tbl);
        kid(pr, 'tblBorders')?.remove();
        XmlElement edge(String side, bool on) => w(side, attrs: on
            ? {'val': 'single', 'sz': '4', 'space': '0', 'color': 'auto'}
            : {'val': 'nil'});
        final outer = preset == 'all' || preset == 'outer';
        final inner = preset == 'all' || preset == 'inner';
        _put(pr, w('tblBorders', kids: [
          edge('top', outer), edge('left', outer), edge('bottom', outer),
          edge('right', outer), edge('insideH', inner), edge('insideV', inner),
        ]), kTblPrOrder);
        // Hücre düzeyi kenarlıklar tablo ayarını ezer — temizlenir.
        for (final tcb in c.tbl.descendantElements
            .where((e) => e.name.local == 'tcBorders')
            .toList()) {
          tcb.remove();
        }
      };

  static XmlElement _tblPr(XmlElement tbl) {
    final have = kid(tbl, 'tblPr');
    if (have != null) return have;
    final pr = w('tblPr');
    tbl.children.insert(0, pr);
    return pr;
  }

  /// Otomatik sığdır: `content` (içeriğe göre) | `window` (sayfa genişliği)
  /// | `fixed` (eşit sabit sütunlar).
  static DocxOp autofit(int i, String mode) => (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        final pr = _tblPr(c.tbl);
        kid(pr, 'tblW')?.remove();
        kid(pr, 'tblLayout')?.remove();
        final grid = kid(c.tbl, 'tblGrid');
        final cols = kids(grid, 'gridCol').toList();
        switch (mode) {
          case 'content':
            _put(pr, w('tblW', attrs: {'w': '0', 'type': 'auto'}), kTblPrOrder);
            _put(pr, w('tblLayout', attrs: {'type': 'autofit'}), kTblPrOrder);
            for (final tcw in c.tbl.descendantElements
                .where((e) => e.name.local == 'tcW')
                .toList()) {
              setW(tcw, 'type', 'auto');
              setW(tcw, 'w', '0');
            }
          case 'window':
            _put(pr, w('tblW', attrs: {'w': '5000', 'type': 'pct'}), kTblPrOrder);
            _put(pr, w('tblLayout', attrs: {'type': 'autofit'}), kTblPrOrder);
          default:
            final s = pkg.bodySectPr;
            final pw = int.tryParse(attrOf(kid(s, 'pgSz'), 'w') ?? '') ?? 11906;
            final mar = kid(s, 'pgMar');
            final avail = pw -
                (int.tryParse(attrOf(mar, 'left') ?? '') ?? 1440) -
                (int.tryParse(attrOf(mar, 'right') ?? '') ?? 1440);
            final n = cols.isEmpty ? 1 : cols.length;
            final each = (avail / n).floor();
            _put(pr, w('tblW', attrs: {'w': '${each * n}', 'type': 'dxa'}), kTblPrOrder);
            _put(pr, w('tblLayout', attrs: {'type': 'fixed'}), kTblPrOrder);
            for (final g in cols) {
              setW(g, 'w', '$each');
            }
            for (final tr in kids(c.tbl, 'tr')) {
              for (final tc in kids(tr, 'tc')) {
                final tp = ensureKid(tc, 'tcPr');
                if (tc.children.indexOf(tp) != 0) {
                  tp.remove();
                  tc.children.insert(0, tp);
                }
                kid(tp, 'tcW')?.remove();
                _put(tp, w('tcW', attrs: {'w': '${each * _span(tc)}', 'type': 'dxa'}), kTcPrOrder);
              }
            }
        }
      };

  /// Sırala: imlecin sütununa göre; [header] ilk satır yerinde kalır.
  static DocxOp sort(int i, {bool descending = false, bool header = true}) =>
      (pkg) {
        final c = _at(pkg, i);
        if (c == null) throw const DocxTableException('no_table');
        if (c.tbl.descendantElements.any((e) => e.name.local == 'vMerge')) {
          throw const DocxTableException('merged');
        }
        final col = _gridCol(c.tr, c.tc);
        final rows = kids(c.tbl, 'tr').toList();
        final fixed = header ? 1 : 0;
        if (rows.length - fixed < 2) return;
        final body = rows.sublist(fixed);
        String key(XmlElement tr) => _cellAtCol(tr, col)?.innerText.trim() ?? '';
        final sorted = [...body]..sort((a, b) {
            final r = compareCells(key(a), key(b));
            return descending ? -r : r;
          });
        final first = c.tbl.children.indexOf(body.first);
        for (final r in body) {
          r.remove();
        }
        c.tbl.children.insertAll(first, sorted);
      };

  /// Sayı (Türkçe ondalık virgül dahil) sayıca, metin Türkçe alfabe
  /// sırasıyla; boş hücreler sonda.
  static int compareCells(String a, String b) {
    if (a.isEmpty || b.isEmpty) return a.isEmpty ? (b.isEmpty ? 0 : 1) : -1;
    final na = _num(a), nb = _num(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return trKey(a).compareTo(trKey(b));
  }

  static double? _num(String s) {
    var t = s.replaceAll(RegExp(r'[\s₺$€%]'), '');
    if (RegExp(r'^-?\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(t)) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^-?\d+,\d+$').hasMatch(t)) {
      t = t.replaceAll(',', '.');
    }
    return double.tryParse(t);
  }

  /// Türkçe alfabe sırası anahtarı (c<ç, g<ğ, ı<i, o<ö, s<ş, u<ü).
  static String trKey(String s) {
    const order = 'aâbcçdefgğhıiîjklmnoöprsştuûüvyzqwx';
    final buf = StringBuffer();
    for (final r in s.runes) {
      var ch = String.fromCharCode(r);
      ch = switch (ch) {
        'I' => 'ı',
        'İ' => 'i',
        _ => ch.toLowerCase(),
      };
      final k = order.indexOf(ch);
      buf.writeCharCode(k < 0 ? 0x100 + r : 0x41 + k);
    }
    return buf.toString();
  }
}
