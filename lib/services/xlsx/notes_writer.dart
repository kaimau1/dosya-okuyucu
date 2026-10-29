/// **Hücre notları yazımı** (Faz 27 madde 10, K24 — "Deneysel").
///
/// Excel'in klasik notu iki parçadır: metin `xl/commentsN.xml`de, kutunun
/// kendisi eski VML çiziminde (`xl/drawings/vmlDrawingN.vml`). VML şekli
/// olmayan not Excel'de görünmez; bu yüzden ikisi birlikte yazılır, sayfaya
/// `<legacyDrawing r:id>` bağlanır, ilişkiler + içerik türleri eklenir.
/// Var olan not parçası varsa güncellenir (yalnız düzenlenen hücreler).
///
/// Kayıt zincirinin EN SONUNDA koşar (paket yazıcı + yamalar + grafiklerden
/// sonra); bir sorun çıkarsa girdi baytları aynen döner — not yüzünden
/// kaydetme kırılmaz.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Bir sayfanın not düzenlemeleri: (satır, sütun) → metin (null = sil).
class XlsxNoteEdits {
  final String sheet;
  final Map<(int, int), String?> notes;
  final String author;
  const XlsxNoteEdits(this.sheet, this.notes, this.author);
}

class XlsxNotesWriter {
  static const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _relComments = '$_rel/comments';
  static const _relVml = '$_rel/vmlDrawing';
  static const _ctComments =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml';
  static const _ctVml = 'application/vnd.openxmlformats-officedocument.vmlDrawing';

  static Uint8List apply(Uint8List bytes, List<XlsxNoteEdits> edits) {
    if (edits.isEmpty) return bytes;
    try {
      final files = <String, List<int>>{};
      final order = <String>[];
      for (final f in ZipDecoder().decodeBytes(bytes).files) {
        if (!f.isFile) continue;
        files[f.name] = f.content as List<int>;
        order.add(f.name);
      }
      String? text(String n) =>
          files[n] == null ? null : utf8.decode(files[n]!, allowMalformed: true);
      void put(String n, String t) {
        if (!files.containsKey(n)) order.add(n);
        files[n] = utf8.encode(t);
      }

      final targets = _sheetTargets(text);
      for (final e in edits) {
        final part = targets[e.sheet];
        if (part == null) continue;
        _applySheet(part, e, text, put);
      }
      final out = Archive();
      for (final n in order) {
        out.addFile(ArchiveFile(n, files[n]!.length, files[n]!));
      }
      final z = ZipEncoder().encode(out);
      return z == null ? bytes : Uint8List.fromList(z);
    } catch (_) {
      return bytes;
    }
  }

  static Map<String, String> _sheetTargets(String? Function(String) text) {
    final wb = text('xl/workbook.xml');
    final rels = text('xl/_rels/workbook.xml.rels');
    if (wb == null || rels == null) return const {};
    final byId = <String, String>{};
    for (final r in XmlDocument.parse(rels).findAllElements('Relationship')) {
      final id = r.getAttribute('Id'), t = r.getAttribute('Target');
      if (id != null && t != null) byId[id] = _norm('xl', t);
    }
    final out = <String, String>{};
    for (final s in XmlDocument.parse(wb).findAllElements('sheet')) {
      String? rid;
      for (final a in s.attributes) {
        if (a.name.local == 'id') rid = a.value;
      }
      final name = s.getAttribute('name');
      if (name != null && rid != null && byId[rid] != null) {
        out[name] = byId[rid]!;
      }
    }
    return out;
  }

  /// İlişki hedefini zip yoluna çevirir ([base] ilişkinin klasörü).
  static String _norm(String base, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = [...base.split('/'), ...target.split('/')];
    final out = <String>[];
    for (final p in parts) {
      if (p == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else if (p.isNotEmpty && p != '.') {
        out.add(p);
      }
    }
    return out.join('/');
  }

  static String _ref(int r, int c) {
    var n = c + 1;
    final letters = <int>[];
    while (n > 0) {
      letters.add(65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return '${String.fromCharCodes(letters.reversed)}${r + 1}';
  }

  static void _applySheet(String part, XlsxNoteEdits e,
      String? Function(String) text, void Function(String, String) put) {
    final slash = part.lastIndexOf('/');
    final dir = part.substring(0, slash);
    final relsName = '$dir/_rels/${part.substring(slash + 1)}.rels';
    final relsDoc = XmlDocument.parse(text(relsName) ??
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>');
    String? commentsPart, vmlPart, vmlRid;
    var maxId = 0;
    for (final r in relsDoc.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null && int.parse(m[1]!) > maxId) maxId = int.parse(m[1]!);
      final type = r.getAttribute('Type') ?? '';
      final t = _norm(dir, r.getAttribute('Target') ?? '');
      if (type == _relComments) commentsPart = t;
      if (type == _relVml) {
        vmlPart = t;
        vmlRid = r.getAttribute('Id');
      }
    }
    String fresh(String prefix, String ext) {
      var n = 1;
      while (text('$prefix$n.$ext') != null) {
        n++;
      }
      return '$prefix$n.$ext';
    }

    var relsChanged = false;
    void addRel(String type, String target, [String? id]) {
      relsDoc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), id ?? 'rId${++maxId}'),
        XmlAttribute(XmlName('Type'), type),
        XmlAttribute(XmlName('Target'), _relTarget(dir, target)),
      ]));
      relsChanged = true;
    }

    // ── comments ──────────────────────────────────────────────────────
    final cDoc = XmlDocument.parse(commentsPart == null
        ? '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<comments xmlns="$_ns"><authors/><commentList/></comments>'
        : text(commentsPart)!);
    XmlElement child(XmlElement p, String local) {
      for (final k in p.childElements) {
        if (k.name.local == local) return k;
      }
      final el = XmlElement(XmlName(local));
      p.children.add(el);
      return el;
    }

    final root = cDoc.rootElement;
    final authors = child(root, 'authors');
    final list = child(root, 'commentList');
    var authorId = authors.childElements
        .toList()
        .indexWhere((a) => a.innerText == e.author);
    if (authorId < 0) {
      authors.children.add(
          XmlElement(XmlName('author'), const [], [XmlText(e.author)]));
      authorId = authors.childElements.length - 1;
    }
    for (final MapEntry(key: (r, c), value: t) in e.notes.entries) {
      final ref = _ref(r, c);
      list.children.removeWhere(
          (n) => n is XmlElement && n.getAttribute('ref') == ref);
      if (t == null) continue;
      list.children.add(XmlElement(XmlName('comment'), [
        XmlAttribute(XmlName('ref'), ref),
        XmlAttribute(XmlName('authorId'), '$authorId'),
      ], [
        XmlElement(XmlName('text'), const [], [
          XmlElement(XmlName('r'), const [], [
            XmlElement(XmlName('t'), [XmlAttribute(XmlName('xml:space'), 'preserve')],
                [XmlText(t)]),
          ]),
        ]),
      ]));
    }
    commentsPart ??= () {
      final n = fresh('xl/comments', 'xml');
      addRel(_relComments, n);
      return n;
    }();
    put(commentsPart, cDoc.toXmlString());

    // ── VML ───────────────────────────────────────────────────────────
    final String vml;
    if (vmlPart != null && text(vmlPart) != null) {
      vml = text(vmlPart)!;
    } else {
      vml = '<xml xmlns:v="urn:schemas-microsoft-com:vml" '
          'xmlns:o="urn:schemas-microsoft-com:office:office" '
          'xmlns:x="urn:schemas-microsoft-com:office:excel">'
          '<o:shapelayout v:ext="edit"><o:idmap v:ext="edit" data="1"/></o:shapelayout>'
          '<v:shapetype id="_x0000_t202" coordsize="21600,21600" o:spt="202" '
          'path="m,l,21600r21600,l21600,xe"><v:stroke joinstyle="miter"/>'
          '<v:path gradientshapeok="t" o:connecttype="rect"/></v:shapetype></xml>';
    }
    put(vmlPart ?? (vmlPart = fresh('xl/drawings/vmlDrawing', 'vml')),
        _patchVml(vml, e.notes));
    if (vmlRid == null) {
      vmlRid = 'rId${++maxId}';
      addRel(_relVml, vmlPart, vmlRid);
    }
    if (relsChanged) put(relsName, relsDoc.toXmlString());

    // ── sayfa: <legacyDrawing r:id> ───────────────────────────────────
    final sheet = XmlDocument.parse(text(part)!);
    final ws = sheet.rootElement;
    final has = ws.childElements.any((x) => x.name.local == 'legacyDrawing');
    if (!has) {
      if (ws.getAttribute('xmlns:r') == null) {
        ws.attributes.add(XmlAttribute(XmlName('xmlns:r'), _rel));
      }
      final el = XmlElement(XmlName('legacyDrawing'),
          [XmlAttribute(XmlName('r:id'), vmlRid)]);
      // CT_Worksheet: … drawing, legacyDrawing, legacyDrawingHF, picture,
      // oleObjects, controls, webPublishItems, tableParts, extLst.
      const after = {
        'legacyDrawingHF', 'drawingHF', 'picture', 'oleObjects', 'controls',
        'webPublishItems', 'tableParts', 'extLst',
      };
      final kids = ws.children;
      var at = kids.length;
      for (var i = 0; i < kids.length; i++) {
        final k = kids[i];
        if (k is XmlElement && after.contains(k.name.local)) {
          at = i;
          break;
        }
      }
      kids.insert(at, el);
      put(part, sheet.toXmlString());
    }

    // ── içerik türleri ────────────────────────────────────────────────
    final ct = XmlDocument.parse(text('[Content_Types].xml')!);
    final types = ct.rootElement;
    var ctChanged = false;
    if (!types.childElements.any((x) =>
        x.name.local == 'Default' &&
        (x.getAttribute('Extension') ?? '').toLowerCase() == 'vml')) {
      types.children.insert(
          0,
          XmlElement(XmlName('Default'), [
            XmlAttribute(XmlName('Extension'), 'vml'),
            XmlAttribute(XmlName('ContentType'), _ctVml),
          ]));
      ctChanged = true;
    }
    if (!types.childElements.any((x) =>
        x.name.local == 'Override' &&
        x.getAttribute('PartName') == '/$commentsPart')) {
      types.children.add(XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), '/$commentsPart'),
        XmlAttribute(XmlName('ContentType'), _ctComments),
      ]));
      ctChanged = true;
    }
    if (ctChanged) put('[Content_Types].xml', ct.toXmlString());
  }

  /// [from] klasöründen [target] zip yoluna göreli hedef ("../comments1.xml").
  static String _relTarget(String from, String target) {
    final a = from.split('/'), b = target.split('/');
    var i = 0;
    while (i < a.length && i < b.length - 1 && a[i] == b[i]) {
      i++;
    }
    return [for (var k = i; k < a.length; k++) '..', ...b.sublist(i)].join('/');
  }

  /// VML'de not kutuları: düzenlenen hücrelerin şekilleri kaldırılır, metni
  /// olanlara yenisi eklenir (gizli kutu, Excel'in varsayılan ölçüsü).
  static String _patchVml(String vml, Map<(int, int), String?> notes) {
    final doc = XmlDocument.parse(vml);
    final root = doc.rootElement;
    var maxShape = 1024;
    for (final s in root.descendantElements) {
      if (s.name.local != 'shape') continue;
      final m = RegExp(r'_s(\d+)$').firstMatch(s.getAttribute('id') ?? '');
      if (m != null && int.parse(m[1]!) > maxShape) maxShape = int.parse(m[1]!);
    }
    int? childInt(XmlElement s, String local) {
      for (final d in s.descendantElements) {
        if (d.name.local == local) return int.tryParse(d.innerText.trim());
      }
      return null;
    }

    root.children.removeWhere((n) {
      if (n is! XmlElement || n.name.local != 'shape') return false;
      final r = childInt(n, 'Row'), c = childInt(n, 'Column');
      return r != null && c != null && notes.containsKey((r, c));
    });
    for (final MapEntry(key: (r, c), value: t) in notes.entries) {
      if (t == null) continue;
      maxShape++;
      root.children.add(XmlDocument.parse(
              '<v:shape xmlns:v="urn:schemas-microsoft-com:vml" '
              'xmlns:o="urn:schemas-microsoft-com:office:office" '
              'xmlns:x="urn:schemas-microsoft-com:office:excel" '
              'id="_x0000_s$maxShape" type="#_x0000_t202" '
              'style="position:absolute;margin-left:59.25pt;margin-top:1.5pt;'
              'width:108pt;height:59.25pt;z-index:1;visibility:hidden" '
              'fillcolor="#ffffe1" o:insetmode="auto">'
              '<v:fill color2="#ffffe1"/><v:shadow on="t" color="black" obscured="t"/>'
              '<v:path o:connecttype="none"/>'
              '<v:textbox style="mso-direction-alt:auto"><div style="text-align:left"/></v:textbox>'
              '<x:ClientData ObjectType="Note"><x:MoveWithCells/><x:SizeWithCells/>'
              '<x:Anchor>${c + 1}, 15, ${r == 0 ? 0 : r - 1}, 10, ${c + 3}, 15, ${r + 3}, 4</x:Anchor>'
              '<x:AutoFill>False</x:AutoFill><x:Row>$r</x:Row><x:Column>$c</x:Column>'
              '</x:ClientData></v:shape>')
          .rootElement
          .copy());
    }
    return doc.toXmlString();
  }
}
