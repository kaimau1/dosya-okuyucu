import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../zip_carry.dart';
import '../../office_zip_guard.dart';

/// **Faz 38 — slayt pro işlemlerinin paket katmanı.** `PptxEditor` metin ve
/// şekil düzeyinde çalışır; ana slayt, tema, grafik parçası, medya, bölüm gibi
/// işlemler birden çok parçaya (rels, [Content_Types], presentation.xml)
/// dokunur. Bunlar burada, kaydedilmiş bayt üzerinde ve İZOLATTA koşar
/// ([PptxPro.run], anayasa k.1); sonuç editörde yeniden ayrıştırılır.
class PptxPackage {
  static const nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const nsC = 'http://schemas.openxmlformats.org/drawingml/2006/chart';
  static const nsP14 = 'http://schemas.microsoft.com/office/powerpoint/2010/main';
  static const relBase =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const relsNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  final Archive _archive;
  final Map<String, XmlDocument> _xml = {};
  final Map<String, Uint8List> _bin = {};
  final Set<String> _dirty = {};
  final Set<String> _removed = {};

  PptxPackage._(this._archive);

  static PptxPackage open(Uint8List bytes) =>
      PptxPackage._(OfficeZipGuard.decode(bytes));

  // ── Parça erişimi ─────────────────────────────────────────────────────────

  bool has(String name) =>
      !_removed.contains(name) &&
      (_xml.containsKey(name) ||
          _bin.containsKey(name) ||
          _archive.findFile(name) != null);

  Iterable<String> get names sync* {
    final seen = <String>{};
    for (final f in _archive.files) {
      if (f.isFile && !_removed.contains(f.name) && seen.add(f.name)) {
        yield f.name;
      }
    }
    for (final n in [..._xml.keys, ..._bin.keys]) {
      if (!_removed.contains(n) && seen.add(n)) yield n;
    }
  }

  XmlDocument? xml(String name) {
    if (_removed.contains(name)) return null;
    final cached = _xml[name];
    if (cached != null) return cached;
    final f = _archive.findFile(name);
    if (f == null) return null;
    try {
      final d = XmlDocument.parse(
          utf8.decode(f.content as List<int>, allowMalformed: true));
      _xml[name] = d;
      return d;
    } catch (_) {
      return null; // bozuk parça: işlem o parçayı atlar
    }
  }

  /// Var olan parçayı değiştirmek üzere alır (kaydederken yazılır).
  XmlDocument? edit(String name) {
    final d = xml(name);
    if (d != null) _dirty.add(name);
    return d;
  }

  void putXml(String name, String text) {
    _removed.remove(name);
    _xml[name] = XmlDocument.parse(text);
    _dirty.add(name);
  }

  Uint8List? bytes(String name) {
    if (_removed.contains(name)) return null;
    if (_bin[name] case final b?) return b;
    if (_xml.containsKey(name) && _dirty.contains(name)) {
      return Uint8List.fromList(utf8.encode(_xml[name]!.toXmlString()));
    }
    final f = _archive.findFile(name);
    return f == null ? null : Uint8List.fromList(f.content as List<int>);
  }

  void putBytes(String name, Uint8List data) {
    _removed.remove(name);
    _xml.remove(name);
    _bin[name] = data;
  }

  void remove(String name) {
    _removed.add(name);
    _xml.remove(name);
    _bin.remove(name);
  }

  /// [prefix]`N`.[ext] biçiminde boş ad (ör. `ppt/charts/chart`, `xml`).
  String freeName(String prefix, String ext) {
    var n = 1;
    while (has('$prefix$n.$ext')) {
      n++;
    }
    return '$prefix$n.$ext';
  }

  // ── İlişkiler ─────────────────────────────────────────────────────────────

  static String relsPathOf(String part) {
    final i = part.lastIndexOf('/');
    return '${part.substring(0, i + 1)}_rels/${part.substring(i + 1)}.rels';
  }

  /// Hedefi [part]'a göre çözer (`../media/a.png` → `ppt/media/a.png`).
  static String resolve(String part, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final segs = part.split('/')..removeLast();
    for (final s in target.split('/')) {
      if (s == '..') {
        if (segs.isNotEmpty) segs.removeLast();
      } else if (s != '.' && s.isNotEmpty) {
        segs.add(s);
      }
    }
    return segs.join('/');
  }

  /// [from]'dan [to]'ya göreli hedef (ikisi de paket kökünden).
  static String relative(String from, String to) {
    final a = from.split('/')..removeLast();
    final b = to.split('/');
    var i = 0;
    while (i < a.length && i < b.length - 1 && a[i] == b[i]) {
      i++;
    }
    return [for (var k = i; k < a.length; k++) '..', ...b.sublist(i)].join('/');
  }

  XmlDocument _relsDoc(String part) {
    final path = relsPathOf(part);
    final d = edit(path);
    if (d != null) return d;
    putXml(path,
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="$relsNs"/>');
    return _xml[path]!;
  }

  /// `(id, type, target-çözülmüş, external)` listesi.
  List<({String id, String type, String target, bool external})> rels(
      String part) {
    final d = xml(relsPathOf(part));
    if (d == null) return const [];
    return [
      for (final r in d.findAllElements('Relationship'))
        (
          id: r.getAttribute('Id') ?? '',
          type: r.getAttribute('Type') ?? '',
          target: r.getAttribute('TargetMode') == 'External'
              ? r.getAttribute('Target') ?? ''
              : resolve(part, r.getAttribute('Target') ?? ''),
          external: r.getAttribute('TargetMode') == 'External',
        ),
    ];
  }

  String? relTarget(String part, String rid) {
    for (final r in rels(part)) {
      if (r.id == rid) return r.target;
    }
    return null;
  }

  /// İlişki ekler, yeni `rIdN` döner. [type] kısa ad (`chart`) ya da tam URI.
  String addRel(String part, String type, String target,
      {bool external = false}) {
    final d = _relsDoc(part);
    final used = {
      for (final r in d.findAllElements('Relationship')) r.getAttribute('Id')
    };
    var n = used.length + 1;
    while (used.contains('rId$n')) {
      n++;
    }
    final full = type.contains('://') ? type : '$relBase/$type';
    d.rootElement.children.add(XmlElement(const XmlName.qualified('Relationship'), [
      XmlAttribute(const XmlName.qualified('Id'), 'rId$n'),
      XmlAttribute(const XmlName.qualified('Type'), full),
      XmlAttribute(
          const XmlName.qualified('Target'), external ? target : relative(part, target)),
      if (external) XmlAttribute(const XmlName.qualified('TargetMode'), 'External'),
    ]));
    return 'rId$n';
  }

  void removeRel(String part, String rid) {
    final d = edit(relsPathOf(part));
    d?.rootElement.children.removeWhere(
        (n) => n is XmlElement && n.getAttribute('Id') == rid);
  }

  // ── İçerik türleri ────────────────────────────────────────────────────────

  void addOverride(String part, String contentType) {
    final d = edit('[Content_Types].xml');
    if (d == null) return;
    final name = '/$part';
    for (final o in d.findAllElements('Override')) {
      if (o.getAttribute('PartName') == name) return;
    }
    d.rootElement.children.add(XmlElement(const XmlName.qualified('Override'), [
      XmlAttribute(const XmlName.qualified('PartName'), name),
      XmlAttribute(const XmlName.qualified('ContentType'), contentType),
    ]));
  }

  void ensureDefault(String ext, String mime) {
    final d = edit('[Content_Types].xml');
    if (d == null) return;
    for (final o in d.findAllElements('Default')) {
      if (o.getAttribute('Extension')?.toLowerCase() == ext.toLowerCase()) {
        return;
      }
    }
    d.rootElement.children.insert(
        0,
        XmlElement(const XmlName.qualified('Default'), [
          XmlAttribute(const XmlName.qualified('Extension'), ext),
          XmlAttribute(const XmlName.qualified('ContentType'), mime),
        ]));
  }

  // ── Sunum yapısı ──────────────────────────────────────────────────────────

  static const presentation = 'ppt/presentation.xml';

  /// Sunum sırasıyla slayt parçaları.
  List<String> slideParts() {
    final pres = xml(presentation);
    if (pres == null) return const [];
    final out = <String>[];
    for (final id in pres.findAllElements('p:sldId')) {
      final t = relTarget(presentation, id.getAttribute('r:id') ?? '');
      if (t != null && has(t)) out.add(t);
    }
    return out;
  }

  String slidePart(int index) {
    final parts = slideParts();
    if (index < 0 || index >= parts.length) {
      throw RangeError.index(index, parts, 'slide');
    }
    return parts[index];
  }

  /// Slaytın `p:sldId@id` değeri (bölüm/özel gösteri bunu kullanır).
  List<int> slideIds() {
    final pres = xml(presentation);
    if (pres == null) return const [];
    return [
      for (final id in pres.findAllElements('p:sldId'))
        int.tryParse(id.getAttribute('id') ?? '') ?? 0,
    ];
  }

  /// Slaytın yerleşim parçası, yerleşimin ana slaytı, ana slaytın teması.
  String? layoutOf(String slide) => _firstRel(slide, 'slideLayout');
  String? masterOf(String layout) => _firstRel(layout, 'slideMaster');
  String? themeOf(String master) => _firstRel(master, 'theme');

  String? _firstRel(String part, String kind) {
    for (final r in rels(part)) {
      if (r.type.endsWith('/$kind')) return r.target;
    }
    return null;
  }

  /// Sunumdaki ana slaytlar (presentation.xml sırası).
  List<String> masters() {
    final pres = xml(presentation);
    if (pres == null) return const [];
    return [
      for (final m in pres.findAllElements('p:sldMasterId'))
        ?relTarget(presentation, m.getAttribute('r:id') ?? ''),
    ];
  }

  /// Ana slaytın yerleşimleri (`p:sldLayoutIdLst` sırası).
  List<String> layoutsOf(String master) {
    final d = xml(master);
    if (d == null) return const [];
    return [
      for (final l in d.findAllElements('p:sldLayoutId'))
        ?relTarget(master, l.getAttribute('r:id') ?? ''),
    ];
  }

  /// Slayt boyutu (EMU).
  (int, int) slideSize() {
    final sz = xml(presentation)?.findAllElements('p:sldSz').firstOrNull;
    return (
      int.tryParse(sz?.getAttribute('cx') ?? '') ?? 12192000,
      int.tryParse(sz?.getAttribute('cy') ?? '') ?? 6858000,
    );
  }

  // ── Şekil ağacı yardımcıları ──────────────────────────────────────────────

  static XmlElement? spTree(XmlDocument d) =>
      d.findAllElements('p:spTree').firstOrNull;

  /// Ağaçta kullanılan en büyük `cNvPr@id` + 1.
  static int nextShapeId(XmlDocument d) {
    var m = 1;
    for (final e in d.findAllElements('p:cNvPr')) {
      final v = int.tryParse(e.getAttribute('id') ?? '') ?? 0;
      if (v > m) m = v;
    }
    return m + 1;
  }

  /// [id] kimlikli üst düzey (ya da grup içi) şekil düğümü.
  static XmlElement? shapeById(XmlDocument d, int id) {
    for (final c in d.findAllElements('p:cNvPr')) {
      if (c.getAttribute('id') == '$id') {
        // cNvPr → nvSpPr/nvPicPr/... → şekil
        return c.parentElement?.parentElement;
      }
    }
    return null;
  }

  static XmlElement frag(String xml) => XmlDocument.parse(
          '<r xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP" xmlns:c="$nsC" '
          'xmlns:p14="$nsP14">$xml</r>')
      .rootElement
      .childElements
      .first
      .copy();

  static String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Yeni bayt dizisi. Değişmeyen girdiler sıkıştırılmış hâlleriyle taşınır.
  Uint8List save() {
    final out = Archive();
    final seen = <String>{};
    for (final f in _archive.files) {
      if (!f.isFile || _removed.contains(f.name) || !seen.add(f.name)) continue;
      if (_bin[f.name] case final b?) {
        out.addFile(ArchiveFile(f.name, b.length, b));
      } else if (_dirty.contains(f.name) && _xml[f.name] != null) {
        out.addFile(_text(f.name, _xml[f.name]!));
      } else {
        out.addFile(carryEntry(f));
      }
    }
    for (final MapEntry(:key, :value) in _xml.entries) {
      if (_dirty.contains(key) && !_removed.contains(key) && seen.add(key)) {
        out.addFile(_text(key, value));
      }
    }
    for (final MapEntry(:key, :value) in _bin.entries) {
      if (!_removed.contains(key) && seen.add(key)) {
        out.addFile(ArchiveFile(key, value.length, value));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(out));
  }

  static ArchiveFile _text(String name, XmlDocument d) {
    final b = utf8.encode(d.toXmlString());
    return ArchiveFile(name, b.length, b);
  }
}

/// Paket işlemi: bayt → bayt.
typedef PptxOp = void Function(PptxPackage pkg);

/// Pro işlemini izolatta koşturur (anayasa k.1). Test sahte saatinde izolat
/// beklenemez → [inIsolate] testte kapatılır.
abstract final class PptxPro {
  static bool inIsolate = true;

  static Future<Uint8List> run(Uint8List bytes, PptxOp op) async {
    Uint8List work() {
      final pkg = PptxPackage.open(bytes);
      op(pkg);
      return pkg.save();
    }

    if (inIsolate) return Isolate.run(work);
    return work();
  }

  /// Sonuç döndüren salt okuma işlemi.
  static Future<T> query<T>(
      Uint8List bytes, T Function(PptxPackage pkg) op) async {
    if (inIsolate) return Isolate.run(() => op(PptxPackage.open(bytes)));
    return op(PptxPackage.open(bytes));
  }
}
