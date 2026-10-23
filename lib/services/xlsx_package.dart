import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'formula_engine.dart';
import 'sheet_structure.dart';
import 'xlsx_reader.dart';

/// Bir sayfanın kaydedilecek içeriği — [XlsxPackageWriter]'ın girdisi.
///
/// `XlsxEditor`in modelinden kurulur; yazıcı editörü tanımaz (saf veri),
/// böylece birim testinde elle kurulabilir.
class XlsxPackageSheet {
  final String name;

  /// Özgün paketteki parça yolu (`xl/worksheets/sheet3.xml`). `null` ise
  /// sayfa bu oturumda eklendi → yeni parça yazılır.
  final String? partPath;

  /// Ham hücre metinleri (`=SUM(A1:A3)`, `1234.5`, `metin`).
  final List<List<String>> rows;
  final XlsxSheetLayout layout;
  final List<XlsxRange> merges;

  /// Sekme gizli mi (`<sheet state="hidden">`).
  final bool hidden;

  /// Bu oturumdaki satır/sütun ekle-sil işlemleri (Faz 25): özgün XML'deki
  /// koşullu biçim, doğrulama, köprü, not ve tanımlı adlar da kaydırılır.
  final List<SheetShift> shifts;

  const XlsxPackageSheet({
    required this.name,
    required this.partPath,
    required this.rows,
    required this.layout,
    required this.merges,
    this.hidden = false,
    this.shifts = const [],
  });
}

/// **Özgün paketi koruyarak** .xlsx yazar (Faz 7 / D6, 2026-10-21).
///
/// KÖK NEDEN: kaydetme `excel 4.0.6` paketinin `encode()`una dayanıyordu.
/// Paket dosyayı kendi modelinden BAŞTAN üretiyordu: hizalama, kenarlık, tema
/// renkleri, sayı biçimleri, boş satır yükseklikleri… düşüyor, `XlsxSavePatch`
/// her birini zip üretildikten sonra geri yamalıyordu. Paket ayrıca `archive
/// ^3`e bağlıydı ve bu kilit pdfrx 2.x, `image` 4.4+ ve Flutter yükseltmesinin
/// önünü kesiyordu.
///
/// Şimdi yaklaşım tersine döndü: **özgün zip olduğu gibi kalır**; yalnız
/// değişmesi gereken parçalar yeniden yazılır:
/// * her sayfanın `<sheetData>`, `<dimension>`, `<cols>`, `<mergeCells>`
///   öğeleri (sayfanın geri kalanı — koşullu biçim, doğrulama, çizim, köprü,
///   sayfa düzeni — baytı baytına korunur);
/// * `workbook.xml`in `<sheets>` listesi (ekleme, silme, yeniden adlandırma,
///   **sıra değiştirme**) ve yerel ad (`localSheetId`) eşlemesi;
/// * `sharedStrings.xml` (bütün sayfalar yeniden yazıldığı için baştan kurulur);
/// * `calcChain.xml` SİLİNİR ve `fullCalcOnLoad` açılır — bayat hesap zinciri
///   Excel'de "dosyayı onaralım mı?" sorusuna yol açar.
///
/// `styles.xml`, tema, grafikler, resimler, notlar dokunulmadan taşınır.
/// Uygulama içi biçim düzenlemeleri bundan SONRA `XlsxSavePatch` ile yazılır.
class XlsxPackageWriter {
  static const _nsMain =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _nsRel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _relWorksheet =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet';
  static const _relShared =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings';
  static const _ctWorksheet =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml';
  static const _ctShared =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml';

  /// [source] boşsa (yeni belge) en küçük geçerli paket kurulur.
  static Uint8List write(Uint8List source, List<XlsxPackageSheet> sheets) {
    final files = <String, List<int>>{};
    final order = <String>[];
    if (source.isNotEmpty) {
      for (final f in ZipDecoder().decodeBytes(source).files) {
        if (!f.isFile) continue;
        files[f.name] = f.content as List<int>;
        order.add(f.name);
      }
    }
    void put(String name, String text) {
      if (!files.containsKey(name)) order.add(name);
      files[name] = utf8.encode(text);
    }

    String? text(String name) {
      final d = files[name];
      return d == null ? null : utf8.decode(d, allowMalformed: true);
    }

    // ── iskelet (yeni belge ya da bozuk paket) ─────────────────────────
    if (!files.containsKey('[Content_Types].xml')) {
      put('[Content_Types].xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '</Types>');
    }
    if (!files.containsKey('_rels/.rels')) {
      put('_rels/.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>');
    }
    if (!files.containsKey('xl/workbook.xml')) {
      put('xl/workbook.xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<workbook xmlns="$_nsMain" xmlns:r="$_nsRel"><sheets/></workbook>');
    }
    if (!files.containsKey('xl/_rels/workbook.xml.rels')) {
      put('xl/_rels/workbook.xml.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>');
    }
    if (!files.containsKey('xl/styles.xml')) {
      put('xl/styles.xml', _minimalStyles);
      _ensureRel(files, put, 'styles.xml',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles');
      _ensureOverride(files, put, '/xl/styles.xml',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml');
    }

    final wbDoc = XmlDocument.parse(text('xl/workbook.xml')!);
    final relsDoc = XmlDocument.parse(text('xl/_rels/workbook.xml.rels')!);
    final ctDoc = XmlDocument.parse(text('[Content_Types].xml')!);

    // rId → hedef parça (xl/ altına göre normalize edilmiş).
    final relById = <String, XmlElement>{};
    for (final r in relsDoc.rootElement.childElements) {
      final id = r.getAttribute('Id');
      if (id != null) relById[id] = r;
    }
    String norm(String target) {
      if (target.startsWith('/')) return target.substring(1);
      return target.startsWith('xl/')
          ? target
          : 'xl/${target.replaceFirst('./', '')}';
    }

    final sheetsEl = wbDoc.rootElement.childElements
        .firstWhere((e) => e.name.local == 'sheets', orElse: () {
      final el = XmlElement(XmlName('sheets'));
      wbDoc.rootElement.children.insert(0, el);
      return el;
    });
    final oldSheets = sheetsEl.childElements.toList();
    // Özgün sıra (localSheetId eşlemesi için) ve parça → <sheet> öğesi.
    final oldIndexByPart = <String, int>{};
    final oldElByPart = <String, XmlElement>{};
    var maxSheetId = 0;
    for (var i = 0; i < oldSheets.length; i++) {
      final el = oldSheets[i];
      final id = int.tryParse(el.getAttribute('sheetId') ?? '') ?? 0;
      if (id > maxSheetId) maxSheetId = id;
      final rid = _rid(el);
      final rel = rid == null ? null : relById[rid];
      final tgt = rel?.getAttribute('Target');
      if (tgt == null) continue;
      oldIndexByPart[norm(tgt)] = i;
      oldElByPart[norm(tgt)] = el;
    }
    var relSeq = 0;
    for (final id in relById.keys) {
      final n = int.tryParse(id.replaceFirst(RegExp(r'^rId'), '')) ?? 0;
      if (n > relSeq) relSeq = n;
    }
    var partSeq = 0;
    for (final name in files.keys) {
      final m = RegExp(r'^xl/worksheets/sheet(\d+)\.xml$').firstMatch(name);
      if (m != null) partSeq = int.parse(m[1]!) > partSeq ? int.parse(m[1]!) : partSeq;
    }

    // ── paylaşılan metin tablosu (baştan) ───────────────────────────────
    final shared = <String, int>{};
    final sharedRuns = <int, List<XlsxRichRun>>{};
    int sst(String s, List<XlsxRichRun>? runs) {
      final key = runs == null ? s : '\u0000r${shared.length}\u0000$s';
      final i = shared.putIfAbsent(key, () => shared.length);
      if (runs != null) sharedRuns[i] = runs;
      return i;
    }

    // ── sayfalar ────────────────────────────────────────────────────────
    final newSheetEls = <XmlElement>[];
    final oldToNew = <int, int>{};
    final keptParts = <String>{};
    // `<v>` önbellek değerleri için tek, paylaşılan hesap (Faz 26): Excel
    // dışı önizleyiciler (dosya yöneticisi, e-posta, Drive) formülün
    // sonucunu görsün. `fullCalcOnLoad` yine açık — Excel kendisi hesaplar.
    final calcSheets = {for (final s in sheets) s.name: s.rows};
    final calc = CalcState();
    for (var i = 0; i < sheets.length; i++) {
      final s = sheets[i];
      var part = s.partPath;
      if (part != null && !files.containsKey(part)) part = null;
      XmlElement el;
      if (part != null && oldElByPart[part] != null) {
        el = oldElByPart[part]!.copy();
        oldToNew[oldIndexByPart[part]!] = i;
      } else {
        // Yeni parça + ilişki + içerik türü.
        partSeq++;
        relSeq++;
        part = 'xl/worksheets/sheet$partSeq.xml';
        final rid = 'rId$relSeq';
        relsDoc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
          XmlAttribute(XmlName('Id'), rid),
          XmlAttribute(XmlName('Type'), _relWorksheet),
          XmlAttribute(XmlName('Target'), 'worksheets/sheet$partSeq.xml'),
        ]));
        _addOverride(ctDoc, '/$part', _ctWorksheet);
        maxSheetId++;
        el = XmlElement(XmlName('sheet'), [
          XmlAttribute(XmlName('name'), s.name),
          XmlAttribute(XmlName('sheetId'), '$maxSheetId'),
          XmlAttribute(XmlName('r:id'), rid),
        ]);
        put(part,
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<worksheet xmlns="$_nsMain" xmlns:r="$_nsRel">'
            '<dimension ref="A1"/><sheetViews><sheetView workbookViewId="0"/></sheetViews>'
            '<sheetFormatPr defaultRowHeight="15"/><sheetData/>'
            '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
            '</worksheet>');
      }
      el.setAttribute('name', s.name);
      if (s.hidden) {
        el.setAttribute('state', 'hidden');
      } else {
        el.removeAttribute('state');
      }
      keptParts.add(part);
      newSheetEls.add(el);
      var sheetXml = text(part)!;
      if (s.shifts.isNotEmpty) {
        sheetXml = _shiftSheetXml(sheetXml, s.shifts, s.name);
        _shiftSheetSideParts(part, s.shifts, text, put);
      }
      final engine =
          FormulaEngine(s.rows, sheetName: s.name, sheets: calcSheets, state: calc);
      put(part, _rewriteSheet(sheetXml, s, sst, engine));
    }
    sheetsEl.children
      ..clear()
      ..addAll(newSheetEls);

    // Silinen sayfaların ilişkisi kalkar (parça yetim kalır — OPC'de geçerli,
    // ama içerik türünü de kaldırıyoruz ki Excel "onar" demesin).
    for (final entry in oldElByPart.entries) {
      if (keptParts.contains(entry.key)) continue;
      final rid = _rid(entry.value);
      if (rid != null) relById[rid]?.parent?.children.remove(relById[rid]!);
      files.remove(entry.key);
      order.remove(entry.key);
      _removeOverride(ctDoc, '/${entry.key}');
    }

    _remapDefinedNames(wbDoc, oldToNew);
    for (final s in sheets) {
      if (s.shifts.isEmpty) continue;
      for (final dn in wbDoc.findAllElements('definedName')) {
        var f = dn.innerText;
        for (final op in s.shifts) {
          f = shiftFormulaStructural(f, op,
              currentSheet: '\u0000', targetSheet: s.name);
        }
        if (f != dn.innerText) {
          dn.children
            ..clear()
            ..add(XmlText(f));
        }
      }
    }
    _fixWorkbookView(wbDoc, sheets.length);
    _forceRecalc(wbDoc);

    // calcChain bayat → sil.
    for (final r in relsDoc.rootElement.childElements.toList()) {
      if ((r.getAttribute('Type') ?? '').endsWith('/calcChain')) {
        final tgt = norm(r.getAttribute('Target') ?? '');
        files.remove(tgt);
        order.remove(tgt);
        _removeOverride(ctDoc, '/$tgt');
        relsDoc.rootElement.children.remove(r);
      }
    }

    // sharedStrings.xml
    String? sharedPart;
    for (final r in relsDoc.rootElement.childElements) {
      if (r.getAttribute('Type') == _relShared) {
        sharedPart = norm(r.getAttribute('Target')!);
      }
    }
    if (sharedPart == null) {
      relSeq++;
      sharedPart = 'xl/sharedStrings.xml';
      relsDoc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), 'rId$relSeq'),
        XmlAttribute(XmlName('Type'), _relShared),
        XmlAttribute(XmlName('Target'), 'sharedStrings.xml'),
      ]));
      _addOverride(ctDoc, '/$sharedPart', _ctShared);
    }
    put(sharedPart, _sharedXml(shared, sharedRuns));

    put('xl/workbook.xml', wbDoc.toXmlString());
    put('xl/_rels/workbook.xml.rels', relsDoc.toXmlString());
    put('[Content_Types].xml', ctDoc.toXmlString());

    final out = Archive();
    for (final name in order) {
      final data = files[name];
      if (data == null) continue;
      out.addFile(ArchiveFile(name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  static String? _rid(XmlElement el) {
    for (final a in el.attributes) {
      if (a.name.local == 'id' && (a.name.prefix != null || a.name.qualified == 'r:id')) {
        return a.value;
      }
    }
    return el.getAttribute('r:id');
  }

  static void _ensureRel(Map<String, List<int>> files,
      void Function(String, String) put, String target, String type) {
    final doc = XmlDocument.parse(utf8.decode(files['xl/_rels/workbook.xml.rels']!));
    if (doc.rootElement.childElements.any((e) => e.getAttribute('Type') == type)) {
      return;
    }
    doc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rIdS${doc.rootElement.childElements.length + 1}'),
      XmlAttribute(XmlName('Type'), type),
      XmlAttribute(XmlName('Target'), target),
    ]));
    put('xl/_rels/workbook.xml.rels', doc.toXmlString());
  }

  static void _ensureOverride(Map<String, List<int>> files,
      void Function(String, String) put, String part, String type) {
    final doc = XmlDocument.parse(utf8.decode(files['[Content_Types].xml']!));
    _addOverride(doc, part, type);
    put('[Content_Types].xml', doc.toXmlString());
  }

  static void _addOverride(XmlDocument ct, String part, String type) {
    if (ct.rootElement.childElements
        .any((e) => e.getAttribute('PartName') == part)) {
      return;
    }
    ct.rootElement.children.add(XmlElement(XmlName('Override'), [
      XmlAttribute(XmlName('PartName'), part),
      XmlAttribute(XmlName('ContentType'), type),
    ]));
  }

  static void _removeOverride(XmlDocument ct, String part) {
    ct.rootElement.children.removeWhere(
        (n) => n is XmlElement && n.getAttribute('PartName') == part);
  }

  /// Yerel adların (`<definedName localSheetId="2">`) sayfa sırası değişince
  /// yeni indekse taşınması; silinen sayfanın yerel adı kalkar.
  static void _remapDefinedNames(XmlDocument wb, Map<int, int> oldToNew) {
    for (final dn in wb.findAllElements('definedName').toList()) {
      final local = dn.getAttribute('localSheetId');
      if (local == null) continue;
      final next = oldToNew[int.tryParse(local) ?? -1];
      if (next == null) {
        dn.parent?.children.remove(dn);
      } else {
        dn.setAttribute('localSheetId', '$next');
      }
    }
    for (final dns in wb.findAllElements('definedNames').toList()) {
      if (dns.childElements.isEmpty) dns.parent?.children.remove(dns);
    }
  }

  static void _fixWorkbookView(XmlDocument wb, int count) {
    for (final v in wb.findAllElements('workbookView')) {
      for (final a in ['activeTab', 'firstSheet']) {
        final n = int.tryParse(v.getAttribute(a) ?? '');
        if (n != null && n >= count) v.setAttribute(a, '0');
      }
    }
  }

  static void _forceRecalc(XmlDocument wb) {
    final root = wb.rootElement;
    var calc = root.childElements
        .where((e) => e.name.local == 'calcPr')
        .firstOrNull;
    if (calc == null) {
      calc = XmlElement(XmlName('calcPr'));
      // calcPr, sheets/definedNames'ten SONRA, oleSize/customWorkbookViews
      // vb.'den ÖNCE gelir.
      final after = {'sheets', 'functionGroups', 'externalReferences', 'definedNames'};
      var at = 0;
      for (var i = 0; i < root.children.length; i++) {
        final n = root.children[i];
        if (n is XmlElement && after.contains(n.name.local)) at = i + 1;
      }
      root.children.insert(at, calc);
    }
    calc.setAttribute('fullCalcOnLoad', '1');
  }

  // ── sayfa XML'i ─────────────────────────────────────────────────────

  static final _sheetDataRe = RegExp(
      r'<((?:\w+:)?)sheetData\b[^>]*?(?:/>|>[\s\S]*?</\1sheetData>)');

  /// Satır/sütun ekle-sil sonrası özgün sayfa XML'indeki aralıklı nesneler
  /// (Faz 25 / X3): koşullu biçim (x14 uzantısı dahil), veri doğrulama,
  /// köprüler. Tamamı silinen nesne kalkar.
  static String _shiftSheetXml(String xml, List<SheetShift> ops, String name) {
    final doc = XmlDocument.parse(xml);
    String? sq(String? v) {
      if (v == null) return null;
      String? cur = v;
      for (final op in ops) {
        if (cur == null) break;
        cur = shiftSqref(cur, op);
      }
      return cur;
    }

    void setText(XmlElement e, String t) {
      if (e.innerText == t) return;
      e.children
        ..clear()
        ..add(XmlText(t));
    }

    // Koşullu biçim / doğrulama formülleri çapalarına göre (bkz.
    // shiftAnchoredFormula); önce formüller, sonra aralıklar.
    String anchored(String v, String? sqrefBefore) {
      var cur = v;
      var ref = sqrefBefore;
      for (final op in ops) {
        final a = ref == null ? null : sqrefAnchor(ref);
        cur = a == null
            ? shiftFormulaStructural(cur, op, currentSheet: name, targetSheet: name)
            : shiftAnchoredFormula(cur, a.$1, a.$2, op, name);
        ref = ref == null ? null : shiftSqref(ref, op);
      }
      return cur;
    }

    String? ownerSqref(XmlElement e) {
      for (XmlNode? n = e.parent; n is XmlElement; n = n.parent) {
        final v = n.getAttribute('sqref');
        if (v != null) return v;
        final x = n.childElements.where((c) => c.name.local == 'sqref').firstOrNull;
        if (x != null) return x.innerText;
      }
      return null;
    }

    for (final e in doc.descendantElements.toList()) {
      switch (e.name.local) {
        case 'formula':
        case 'formula1':
        case 'formula2':
        case 'f':
          final par = e.parent;
          // Hücre formülleri sheetData'yla baştan yazılıyor.
          if (par is XmlElement && par.name.local == 'c') break;
          setText(e, anchored(e.innerText, ownerSqref(e)));
      }
    }
    for (final e in doc.descendantElements.toList()) {
      switch (e.name.local) {
        case 'conditionalFormatting':
        case 'dataValidation':
        case 'hyperlink':
          final attr = e.name.local == 'hyperlink' ? 'ref' : 'sqref';
          final v = e.getAttribute(attr);
          if (v != null) {
            final n = sq(v);
            if (n == null) {
              e.parent?.children.remove(e);
              continue;
            }
            e.setAttribute(attr, n);
          }
        case 'sqref':
          // x14 uzantısı: <xm:sqref>A1:B2</xm:sqref>
          final n = sq(e.innerText);
          if (n == null) {
            final owner = e.parent;
            owner?.parent?.children.remove(owner);
          } else {
            setText(e, n);
          }
      }
    }
    for (final c in doc.descendantElements
        .where((e) => const {'dataValidations', 'hyperlinks'}.contains(e.name.local))
        .toList()) {
      final n = c.childElements.length;
      if (n == 0) {
        c.parent?.children.remove(c);
      } else if (c.getAttribute('count') != null) {
        c.setAttribute('count', '$n');
      }
    }
    return doc.toXmlString();
  }

  /// Sayfanın notları (`commentsN.xml` + eski VML çizimi) da kaydırılır.
  static void _shiftSheetSideParts(String part, List<SheetShift> ops,
      String? Function(String) text, void Function(String, String) put) {
    final slash = part.lastIndexOf('/');
    final rels = '${part.substring(0, slash)}/_rels/${part.substring(slash + 1)}.rels';
    final relXml = text(rels);
    if (relXml == null) return;
    final base = part.substring(0, slash);
    for (final r in XmlDocument.parse(relXml).findAllElements('Relationship')) {
      final type = r.getAttribute('Type') ?? '';
      final target = r.getAttribute('Target') ?? '';
      if (r.getAttribute('TargetMode') == 'External') continue;
      final path = _resolve(base, target);
      final xml = text(path);
      if (xml == null) continue;
      if (type.endsWith('/comments')) {
        final doc = XmlDocument.parse(xml);
        for (final c in doc.findAllElements('comment').toList()) {
          String? ref = c.getAttribute('ref');
          for (final op in ops) {
            if (ref == null) break;
            ref = shiftSqref(ref, op);
          }
          if (ref == null) {
            c.parent?.children.remove(c);
          } else {
            c.setAttribute('ref', ref);
          }
        }
        put(path, doc.toXmlString());
      } else if (type.endsWith('/vmlDrawing')) {
        final doc = XmlDocument.parse(xml);
        for (final cd in doc.descendantElements
            .where((e) => e.name.local == 'ClientData')
            .toList()) {
          final row = cd.childElements.where((e) => e.name.local == 'Row').firstOrNull;
          final col = cd.childElements.where((e) => e.name.local == 'Column').firstOrNull;
          if (row == null || col == null) continue;
          int? rv = int.tryParse(row.innerText.trim());
          int? cv = int.tryParse(col.innerText.trim());
          for (final op in ops) {
            if (rv == null || cv == null) break;
            if (op.rows) {
              rv = op.point(rv);
            } else {
              cv = op.point(cv);
            }
          }
          if (rv == null || cv == null) {
            final shape = cd.parent;
            shape?.parent?.children.remove(shape);
            continue;
          }
          row.children
            ..clear()
            ..add(XmlText('$rv'));
          col.children
            ..clear()
            ..add(XmlText('$cv'));
        }
        put(path, doc.toXmlString());
      }
    }
  }

  static String _resolve(String base, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = base.split('/');
    for (final seg in target.split('/')) {
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (seg != '.') {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }

  static String _rewriteSheet(String xml, XlsxPackageSheet s,
      int Function(String, List<XlsxRichRun>?) sst, FormulaEngine engine) {
    final m = _sheetDataRe.firstMatch(xml);
    final prefix = m?[1] ?? '';
    final data = _sheetData(s, prefix, sst, engine);
    var out = m == null
        ? xml.replaceFirst(RegExp(r'</((?:\w+:)?)worksheet>'), '$data</${prefix}worksheet>')
        : xml.replaceRange(m.start, m.end, data);

    // <cols>: sheetData'dan hemen önce.
    out = out.replaceFirst(
        RegExp('<${RegExp.escape(prefix)}cols\\b[^>]*?(?:/>|>[\\s\\S]*?</${RegExp.escape(prefix)}cols>)'),
        '');
    final cols = _cols(s, prefix);
    if (cols.isNotEmpty) {
      final at = out.indexOf('<${prefix}sheetData');
      out = out.replaceRange(at, at, cols);
    }

    // <mergeCells>
    out = out.replaceFirst(
        RegExp('<${RegExp.escape(prefix)}mergeCells\\b[^>]*?(?:/>|>[\\s\\S]*?</${RegExp.escape(prefix)}mergeCells>)'),
        '');
    if (s.merges.isNotEmpty) {
      final b = StringBuffer('<${prefix}mergeCells count="${s.merges.length}">');
      for (final mg in s.merges) {
        b.write('<${prefix}mergeCell ref="${_ref(mg.r1, mg.c1)}:${_ref(mg.r2, mg.c2)}"/>');
      }
      b.write('</${prefix}mergeCells>');
      out = _insertBefore(out, prefix, _afterMerge, b.toString());
    }

    // <dimension>
    final dim = _dimension(s);
    final dimRe = RegExp('<${RegExp.escape(prefix)}dimension\\b[^>]*/>');
    out = dimRe.hasMatch(out)
        ? out.replaceFirst(dimRe, '<${prefix}dimension ref="$dim"/>')
        : out;
    return out;
  }

  /// `<mergeCells>`'ten SONRA gelebilecek öğeler (ECMA-376 sırası).
  static const _afterMerge = [
    'phoneticPr', 'conditionalFormatting', 'dataValidations', 'hyperlinks',
    'printOptions', 'pageMargins', 'pageSetup', 'headerFooter', 'rowBreaks',
    'colBreaks', 'customProperties', 'cellWatches', 'ignoredErrors',
    'smartTags', 'drawing', 'legacyDrawing', 'legacyDrawingHF', 'picture',
    'oleObjects', 'controls', 'webPublishItems', 'tableParts', 'extLst',
  ];

  static String _insertBefore(
      String xml, String prefix, List<String> names, String fragment) {
    var at = -1;
    for (final n in names) {
      final i = xml.indexOf(RegExp('<${RegExp.escape(prefix)}$n\\b'));
      if (i >= 0 && (at < 0 || i < at)) at = i;
    }
    if (at < 0) at = xml.lastIndexOf('</${prefix}worksheet>');
    return xml.replaceRange(at, at, fragment);
  }

  static String _dimension(XlsxPackageSheet s) {
    var maxR = -1, maxC = -1;
    for (var r = 0; r < s.rows.length; r++) {
      final row = s.rows[r];
      for (var c = row.length - 1; c >= 0; c--) {
        if (row[c].isNotEmpty) {
          if (r > maxR) maxR = r;
          if (c > maxC) maxC = c;
          break;
        }
      }
    }
    for (final key in s.layout.cells.keys) {
      final r = key ~/ 16384, c = key % 16384;
      if (r > maxR) maxR = r;
      if (c > maxC) maxC = c;
    }
    if (maxR < 0) return 'A1';
    return 'A1:${_ref(maxR, maxC < 0 ? 0 : maxC)}';
  }

  static String _cols(XlsxPackageSheet s, String prefix) {
    final l = s.layout;
    final keys = <int>{...l.colWidths.keys, ...l.hiddenCols, ...l.colStyles.keys}
        .where((c) => c >= 0)
        .toList()
      ..sort();
    if (keys.isEmpty) return '';
    final b = StringBuffer('<${prefix}cols>');
    var i = 0;
    while (i < keys.length) {
      final c = keys[i];
      final w = l.colWidths[c];
      final h = l.hiddenCols.contains(c);
      final st = l.colStyles[c];
      var j = i;
      // Ardışık ve aynı nitelikli sütunlar tek <col min max> olur.
      while (j + 1 < keys.length &&
          keys[j + 1] == keys[j] + 1 &&
          l.colWidths[keys[j + 1]] == w &&
          l.hiddenCols.contains(keys[j + 1]) == h &&
          l.colStyles[keys[j + 1]] == st) {
        j++;
      }
      b.write('<${prefix}col min="${c + 1}" max="${keys[j] + 1}"');
      b.write(' width="${_num(w ?? l.colWidthChars(c))}"');
      if (w != null) b.write(' customWidth="1"');
      if (st != null && st != 0) b.write(' style="$st"');
      if (h) b.write(' hidden="1"');
      b.write('/>');
      i = j + 1;
    }
    b.write('</${prefix}cols>');
    return b.toString();
  }

  static String _sheetData(XlsxPackageSheet s, String prefix,
      int Function(String, List<XlsxRichRun>?) sst, FormulaEngine engine) {
    final l = s.layout;
    // Satır → (sütun → yazılacak) birleşimi: modeldeki değerler + boş ama
    // biçimli hücre kayıtları.
    final byRow = <int, Set<int>>{};
    for (var r = 0; r < s.rows.length; r++) {
      final row = s.rows[r];
      for (var c = 0; c < row.length; c++) {
        if (row[c].isNotEmpty) (byRow[r] ??= <int>{}).add(c);
      }
    }
    l.cells.forEach((key, cell) {
      if (cell.styleIndex != 0) {
        (byRow[key ~/ 16384] ??= <int>{}).add(key % 16384);
      }
    });
    final rowKeys = <int>{
      ...byRow.keys,
      ...l.rowHeights.keys,
      ...l.hiddenRows,
      ...l.rowStyles.keys,
    }.where((r) => r >= 0).toList()
      ..sort();

    final b = StringBuffer('<${prefix}sheetData>');
    for (final r in rowKeys) {
      b.write('<${prefix}row r="${r + 1}"');
      final ht = l.rowHeights[r];
      if (ht != null && ht > 0) b.write(' ht="${_num(ht)}" customHeight="1"');
      if (l.hiddenRows.contains(r)) b.write(' hidden="1"');
      final rs = l.rowStyles[r];
      if (rs != null && rs != 0) b.write(' s="$rs" customFormat="1"');
      final cols = (byRow[r] ?? const <int>{}).toList()..sort();
      if (cols.isEmpty) {
        b.write('/>');
        continue;
      }
      b.write('>');
      for (final c in cols) {
        final raw = r < s.rows.length && c < s.rows[r].length ? s.rows[r][c] : '';
        final cell = l.cells[cellKey(r, c)];
        final style = cell?.styleIndex ?? l.rowStyles[r] ?? l.colStyles[c] ?? 0;
        b.write('<${prefix}c r="${_ref(r, c)}"');
        if (style != 0) b.write(' s="$style"');
        if (raw.isEmpty) {
          b.write('/>');
          continue;
        }
        if (raw.length > 1 && raw.startsWith('=')) {
          final f = '<${prefix}f>${_esc(FormulaEngine.toFileFormula(raw.substring(1)))}</${prefix}f>';
          b.write(_cachedValue(engine.displayValue(r, c), f, prefix));
          continue;
        }
        if (cell?.boolean != null && (raw == 'DOĞRU' || raw == 'YANLIŞ' ||
            raw == 'TRUE' || raw == 'FALSE')) {
          final v = raw == 'DOĞRU' || raw == 'TRUE' ? 1 : 0;
          b.write(' t="b"><${prefix}v>$v</${prefix}v></${prefix}c>');
          continue;
        }
        final err = _errorCode(raw);
        if (err != null) {
          b.write(' t="e"><${prefix}v>${_esc(err)}</${prefix}v></${prefix}c>');
          continue;
        }
        final n = double.tryParse(raw);
        if (n != null && n.isFinite && !looksLikeCode(raw)) {
          b.write('><${prefix}v>$raw</${prefix}v></${prefix}c>');
          continue;
        }
        final runs = cell?.runs != null && cell?.text == raw ? cell!.runs : null;
        b.write(' t="s"><${prefix}v>${sst(raw, runs)}</${prefix}v></${prefix}c>');
      }
      b.write('</${prefix}row>');
    }
    b.write('</${prefix}sheetData>');
    return b.toString();
  }

  /// Formül hücresinin gövdesi: `<f>` + hesaplanmış `<v>` (tür özniteliğiyle).
  /// Motorun Türkçe sonuç metinleri (DOĞRU, #SAYI/0!) dosyaya İngilizce
  /// kodla yazılır.
  static String _cachedValue(String v, String f, String prefix) {
    if (v.isEmpty) return '>$f</${prefix}c>';
    if (v == 'DOĞRU' || v == 'YANLIŞ') {
      return ' t="b">$f<${prefix}v>${v == 'DOĞRU' ? 1 : 0}</${prefix}v></${prefix}c>';
    }
    final err = _errorCode(v);
    if (err != null) {
      return ' t="e">$f<${prefix}v>${_esc(err)}</${prefix}v></${prefix}c>';
    }
    // Döngü: Excel'in kodu yok (0 gösterir) — değer yazılmaz.
    if (v == '#DÖNGÜ') return '>$f</${prefix}c>';
    final n = double.tryParse(v);
    if (n != null && n.isFinite) return '>$f<${prefix}v>$v</${prefix}v></${prefix}c>';
    return ' t="str">$f<${prefix}v>${_esc(v)}</${prefix}v></${prefix}c>';
  }

  /// "007", "0123" gibi baştaki sıfırı önemli olan diziler metin kalır.
  static bool looksLikeCode(String v) {
    if (v.length > 1 && v.startsWith('0') && !v.startsWith('0.')) return true;
    if (v.length > 15) return true;
    return false;
  }

  static const _errors = {
    '#DIV/0!', '#VALUE!', '#REF!', '#NAME?', '#N/A', '#NUM!', '#NULL!',
    '#SPILL!', '#CALC!', '#GETTING_DATA',
  };
  static const _errorsTr = {
    '#SAYI/0!': '#DIV/0!', '#DEĞER!': '#VALUE!', '#BAŞV!': '#REF!',
    '#AD?': '#NAME?', '#YOK': '#N/A', '#SAYI!': '#NUM!', '#BOŞ!': '#NULL!',
    '#TAŞMA!': '#SPILL!', '#HESAP!': '#CALC!',
  };

  static String? _errorCode(String raw) {
    final t = raw.trim();
    if (_errors.contains(t)) return t;
    return _errorsTr[t];
  }

  static String _sharedXml(Map<String, int> shared, Map<int, List<XlsxRichRun>> runs) {
    final b = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<sst xmlns="$_nsMain" count="${shared.length}" uniqueCount="${shared.length}">');
    final byIndex = List<String>.filled(shared.length, '');
    shared.forEach((k, i) {
      byIndex[i] = k.startsWith('\u0000r') ? k.substring(k.indexOf('\u0000', 2) + 1) : k;
    });
    for (var i = 0; i < byIndex.length; i++) {
      final rr = runs[i];
      if (rr == null || rr.isEmpty) {
        b.write('<si><t xml:space="preserve">${_esc(byIndex[i])}</t></si>');
        continue;
      }
      b.write('<si>');
      for (final run in rr) {
        b.write('<r>');
        if (run.bold || run.italic || run.underline || run.strike) {
          b.write('<rPr>');
          if (run.bold) b.write('<b/>');
          if (run.italic) b.write('<i/>');
          if (run.strike) b.write('<strike/>');
          if (run.underline) b.write('<u/>');
          b.write('</rPr>');
        }
        b.write('<t xml:space="preserve">${_esc(run.text)}</t></r>');
      }
      b.write('</si>');
    }
    b.write('</sst>');
    return b.toString();
  }

  static String _ref(int r, int c) {
    var n = c + 1;
    final out = <int>[];
    while (n > 0) {
      out.add(65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return '${String.fromCharCodes(out.reversed)}${r + 1}';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static String _esc(String s) {
    final b = StringBuffer();
    for (final ch in s.runes) {
      switch (ch) {
        case 0x26:
          b.write('&amp;');
        case 0x3C:
          b.write('&lt;');
        case 0x3E:
          b.write('&gt;');
        case 0x22:
          b.write('&quot;');
        default:
          // XML 1.0'da geçersiz denetim karakterleri atılır (Excel dosyayı
          // "bozuk" sayar).
          if (ch < 0x20 && ch != 0x09 && ch != 0x0A && ch != 0x0D) continue;
          b.writeCharCode(ch);
      }
    }
    return b.toString();
  }

  static const _minimalStyles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<styleSheet xmlns="$_nsMain">'
      '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
