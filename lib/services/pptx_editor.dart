import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'pptx_render.dart';

/// Bir slayttaki düzenlenebilir paragraf (a:p) — orijinal XML düğümüne bağlı.
class PptxParagraph {
  String text;
  final XmlElement element; // <a:p>
  PptxParagraph(this.text, this.element);
}

class PptxSlide {
  /// 1 tabanlı görüntü sırası; slayt ekle/sil/taşı sonrası yeniden numaralanır.
  int index;
  final List<PptxParagraph> paragraphs;
  final XmlDocument doc;
  final String fileName;

  /// Slaytın çizilebilir görünümü (tasarım + biçimli metin).
  SlideVM? view;

  PptxSlide(this.index, this.paragraphs, this.doc, this.fileName, this.view);

  /// Çizim modelindeki `<a:p>` düğümünü düzenlenebilir paragrafa bağlar.
  PptxParagraph? paragraphOf(XmlElement? element) {
    if (element == null) return null;
    for (final p in paragraphs) {
      if (identical(p.element, element)) return p;
    }
    return null;
  }
}

/// .pptx dosyasını metin bazında düzenler ve slayt ekle/sil/taşı yapar; orijinal
/// tasarımı (arka plan, düzen, biçim) tamamen korur — yalnızca `<a:t>` metin
/// düğümleri ve slayt yapısı (sunum ilişkileri) güncellenir.
class PptxEditor {
  static const _slideContentType =
      'application/vnd.openxmlformats-officedocument.presentationml.slide+xml';
  static const _slideRelType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';

  final Archive _archive;
  final PptxRender _render;
  final List<PptxSlide> slides;

  // Slayt ekle/sil/taşı için gereken yapısal parçalar (yoksa yapısal düzenleme
  // kapalı — ör. sentetik/eksik dosyalarda metin düzenleme yine çalışır).
  final XmlDocument? _contentTypes;
  final XmlDocument? _presentation;
  final XmlDocument? _presRels;

  /// Silinen parça adları — `Archive.files` değiştirilemez olduğundan (removeWhere
  /// "unmodifiable list" atar) silme, kaydetme sırasında bu kümedeki dosyaların
  /// atlanmasıyla yapılır.
  final Set<String> _removed = {};

  PptxEditor._(
    this._archive,
    this._render,
    this.slides,
    this._contentTypes,
    this._presentation,
    this._presRels,
  );

  /// Slayt ekleme/silme/taşıma bu dosyada mümkün mü? (Sunum yapısı tam olmalı.)
  bool get canEditStructure =>
      _contentTypes != null &&
      _presentation != null &&
      _presRels != null &&
      _sldIdLst != null;

  XmlElement? get _sldIdLst =>
      _firstOrNull(_presentation?.findAllElements('p:sldIdLst') ?? const []);

  static PptxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final render = PptxRender(archive);
    final contentTypes = _tryParse(archive, '[Content_Types].xml');
    final presentation = _tryParse(archive, 'ppt/presentation.xml');
    final presRels = _tryParse(archive, 'ppt/_rels/presentation.xml.rels');

    final ordered = _orderedSlideFiles(archive, presentation, presRels);
    final slides = <PptxSlide>[];
    var slideNo = 1;
    for (final name in ordered) {
      final content = _fileByName(archive, name);
      if (content == null) continue;
      final doc = XmlDocument.parse(utf8.decode(content, allowMalformed: true));
      slides.add(PptxSlide(
        slideNo,
        _paragraphsOf(doc),
        doc,
        name,
        _tryRender(render, name, doc),
      ));
      slideNo++;
    }
    return PptxEditor._(
        archive, render, slides, contentTypes, presentation, presRels);
  }

  static List<PptxParagraph> _paragraphsOf(XmlDocument doc) {
    final paras = <PptxParagraph>[];
    for (final p in doc.findAllElements('a:p')) {
      final text = p.findAllElements('a:t').map((e) => e.innerText).join();
      paras.add(PptxParagraph(text, p));
    }
    return paras;
  }

  static SlideVM? _tryRender(PptxRender render, String name, XmlDocument doc) {
    try {
      return render.slide(name, doc);
    } catch (_) {
      return null; // çizilemezse metin listesine düşülür
    }
  }

  /// Slaytın **konuşmacı notu** (yoksa boş). İlk istekte okunup saklanır:
  /// not sayfası ayrı bir XML dosyası, her karede açmak pahalı olurdu.
  final Map<String, String> _notesCache = {};

  String notesOf(PptxSlide slide) => _notesCache.putIfAbsent(slide.fileName, () {
        try {
          return _render.notes(slide.fileName);
        } catch (_) {
          return '';
        }
      });

  /// Slaytları sunumdaki gerçek sıraya (sldIdLst) göre, yoksa dosya numarasına
  /// göre sıralar. Sentetik/eksik dosyalar için dosya numarası yedeği çalışır.
  static List<String> _orderedSlideFiles(
      Archive archive, XmlDocument? presentation, XmlDocument? presRels) {
    final globbed = archive.files
        .map((f) => f.name)
        .where((n) => n.startsWith('ppt/slides/slide') && n.endsWith('.xml'))
        .toList()
      ..sort((a, b) => _idx(a).compareTo(_idx(b)));

    if (presentation == null || presRels == null) return globbed;
    final lst = _firstOrNull(presentation.findAllElements('p:sldIdLst'));
    if (lst == null) return globbed;

    final relMap = _relTargets(presRels);
    final ordered = <String>[];
    for (final sldId in lst.findElements('p:sldId')) {
      final rid = sldId.getAttribute('r:id');
      final target = rid == null ? null : relMap[rid];
      if (target != null && globbed.contains(target) && !ordered.contains(target)) {
        ordered.add(target);
      }
    }
    for (final g in globbed) {
      if (!ordered.contains(g)) ordered.add(g);
    }
    return ordered.isEmpty ? globbed : ordered;
  }

  // ── Yapısal işlemler ────────────────────────────────────────────────────

  /// [slide]'ı çoğaltır (tasarım + metin birebir); kopya hemen ardına eklenir.
  /// Yapı desteklenmiyorsa null döner.
  PptxSlide? duplicateSlide(PptxSlide slide) {
    if (!canEditStructure) return null;
    final num = _nextSlideNumber();
    final newName = 'ppt/slides/slide$num.xml';
    final newRelsName = 'ppt/slides/_rels/slide$num.xml.rels';
    final newDoc = XmlDocument.parse(slide.doc.toXmlString());

    // rels kopyası: hedefler görece (../media, ../slideLayouts) → aynı klasörden
    // geçerli, olduğu gibi kopyalanır. Render bunu _archive'dan okur.
    final srcRels = _fileByName(_archive, _relsPathOf(slide.fileName));
    final relsXml = srcRels != null
        ? utf8.decode(srcRels, allowMalformed: true)
        : '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>';

    _addFile(newName, newDoc.toXmlString());
    _addFile(newRelsName, relsXml);
    _addContentOverride(newName, _slideContentType);

    final newRid = _nextRelId();
    _addPresRel(newRid, _slideRelType, 'slides/slide$num.xml');
    _appendSldId(_nextSldId(), newRid);

    final newSlide = PptxSlide(
      0,
      _paragraphsOf(newDoc),
      newDoc,
      newName,
      _tryRender(_render, newName, newDoc),
    );
    final i = slides.indexOf(slide);
    slides.insert(i < 0 ? slides.length : i + 1, newSlide);
    _syncSldIdOrder();
    _reindex();
    return newSlide;
  }

  /// [slide]'ı siler (en az bir slayt kalmalı). Başarısızsa false.
  bool deleteSlide(PptxSlide slide) {
    if (!canEditStructure || slides.length <= 1) return false;
    final rid = _ridOfSlide(slide.fileName);
    if (rid != null) {
      _removeSldId(rid);
      _removePresRel(rid);
    }
    _removeContentOverride(slide.fileName);
    _removed.add(slide.fileName);
    _removed.add(_relsPathOf(slide.fileName));
    slides.remove(slide);
    _reindex();
    return true;
  }

  /// [slide]'ı [delta] kadar taşır (-1 yukarı, +1 aşağı). Sınır dışıysa false.
  bool moveSlide(PptxSlide slide, int delta) {
    final i = slides.indexOf(slide);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= slides.length) return false;
    slides.removeAt(i);
    slides.insert(j, slide);
    _syncSldIdOrder();
    _reindex();
    return true;
  }

  // ── Görsel ekleme ───────────────────────────────────────────────────────

  static const _nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _relsNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  /// Slaytın ölçüsü (EMU); sunumda yoksa 16:9 varsayılanı.
  (int, int) get _slideSizeEmu {
    final sz = _firstOrNull(
        _presentation?.findAllElements('p:sldSz') ?? const <XmlElement>[]);
    final cx = int.tryParse(sz?.getAttribute('cx') ?? '') ?? 12192000;
    final cy = int.tryParse(sz?.getAttribute('cy') ?? '') ?? 6858000;
    return (cx, cy);
  }

  /// [slide]'ın ortasına bir **görsel** ekler (eski yol haritası: "slayta
  /// görsel ekleme"). Görsel oranı korunarak slaytın %60'ına sığdırılır;
  /// PowerPoint'te taşınıp boyutlandırılabilir bir `p:pic` olur. [ext]
  /// `png` | `jpg` | `jpeg` | `gif`.
  ///
  /// Dokunulan parçalar: yeni medya dosyası, slaytın ilişki tablosu, içerik
  /// türleri (uzantı ilk kez geliyorsa) ve slayt XML'i. Çizim modeli hemen
  /// yeniden kurulur — görsel düzenleyicide anında görünür.
  void addImage(
    PptxSlide slide,
    List<int> bytes, {
    required String ext,
    required int widthPx,
    required int heightPx,
  }) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    final mime = switch (e) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      _ => throw ArgumentError('Desteklenmeyen resim türü: $ext'),
    };
    final spTree = _firstOrNull(slide.doc.findAllElements('p:spTree'));
    if (spTree == null) throw StateError('Slaytta şekil ağacı yok');

    // Medya: pakette kullanılmayan ilk numara.
    final names = {for (final f in _archive.files) f.name};
    var n = 1;
    while (names.contains('ppt/media/fkimage$n.$e')) {
      n++;
    }
    final media = 'ppt/media/fkimage$n.$e';
    _archive.addFile(ArchiveFile(media, bytes.length, bytes));
    _removed.remove(media);
    _ensureDefault(e, mime);

    // Slaytın ilişki tablosuna görsel ilişkisi.
    final relsName = _relsPathOf(slide.fileName);
    final relsBytes = _fileByName(_archive, relsName);
    final rels = relsBytes != null
        ? XmlDocument.parse(utf8.decode(relsBytes, allowMalformed: true))
        : XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
            'standalone="yes"?>\n<Relationships xmlns="$_relsNs"/>');
    var maxRid = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) maxRid = maxRid < int.parse(m[1]!) ? int.parse(m[1]!) : maxRid;
    }
    final rid = 'rId${maxRid + 1}';
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'))
      ..setAttribute('Id', rid)
      ..setAttribute('Type', '$_nsR/image')
      ..setAttribute('Target', '../media/fkimage$n.$e'));
    _addFile(relsName, rels.toXmlString());

    // Ölçü: piksel → EMU (96 dpi), slaytın %60'ına sığdır, ortala.
    final (sw, sh) = _slideSizeEmu;
    var cx = (widthPx <= 0 ? 400 : widthPx) * 9525.0;
    var cy = (heightPx <= 0 ? 300 : heightPx) * 9525.0;
    final fit = [sw * 0.6 / cx, sh * 0.6 / cy, 1.0].reduce((a, b) => a < b ? a : b);
    cx *= fit;
    cy *= fit;
    final x = ((sw - cx) / 2).round(), y = ((sh - cy) / 2).round();

    var id = 1;
    for (final el in slide.doc.findAllElements('p:cNvPr')) {
      final v = int.tryParse(el.getAttribute('id') ?? '') ?? 0;
      if (v >= id) id = v + 1;
    }
    final root = slide.doc.rootElement;
    if (root.getAttribute('xmlns:r') == null) {
      root.setAttribute('xmlns:r', _nsR);
    }
    final pic = XmlDocumentFragment.parse(
      '<p:pic xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
      'xmlns:a="$_nsA" xmlns:r="$_nsR">'
      '<p:nvPicPr><p:cNvPr id="$id" name="Görsel $id"/>'
      '<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/>'
      '</p:nvPicPr>'
      '<p:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch>'
      '</p:blipFill>'
      '<p:spPr><a:xfrm><a:off x="$x" y="$y"/>'
      '<a:ext cx="${cx.round()}" cy="${cy.round()}"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
      '</p:pic>',
    ).firstElementChild!;
    // Fragmanın kendi ad alanı bildirimleri kopyada gereksiz — köke bırak.
    final node = pic.copy();
    node.removeAttribute('xmlns:p');
    node.removeAttribute('xmlns:a');
    node.removeAttribute('xmlns:r');
    spTree.children.add(node);

    _render.forget(slide.fileName);
    slide.view = _tryRender(_render, slide.fileName, slide.doc);
  }

  /// İçerik türlerinde uzantı için `Default` yoksa ekler.
  void _ensureDefault(String ext, String mime) {
    final ct = _contentTypes;
    if (ct == null) return;
    final has = ct.rootElement.childElements.any((el) =>
        el.name.qualified == 'Default' &&
        (el.getAttribute('Extension') ?? '').toLowerCase() == ext);
    if (has) return;
    ct.rootElement.children.insert(
        0,
        XmlElement(XmlName('Default'))
          ..setAttribute('Extension', ext)
          ..setAttribute('ContentType', mime));
  }

  void _reindex() {
    for (var i = 0; i < slides.length; i++) {
      slides[i].index = i + 1;
    }
  }

  /// sldIdLst içindeki `<p:sldId>` sırasını slides listesinin sırasına eşitler.
  void _syncSldIdOrder() {
    final lst = _sldIdLst;
    if (lst == null) return;
    final byRid = <String, XmlElement>{};
    for (final e in lst.findElements('p:sldId')) {
      final rid = e.getAttribute('r:id');
      if (rid != null) byRid[rid] = e;
    }
    // Kopya ekleriz (orijinaller kaldırılınca ana düğüm çakışması olmasın).
    final ordered = <XmlNode>[];
    for (final s in slides) {
      final rid = _ridOfSlide(s.fileName);
      final el = rid == null ? null : byRid[rid];
      if (el != null) ordered.add(el.copy());
    }
    if (ordered.isEmpty) return;
    _removeElems(lst, (e) => e.name.qualified == 'p:sldId');
    lst.children.addAll(ordered);
  }

  // ── Metin düzenleme ─────────────────────────────────────────────────────

  /// Paragraf metnini günceller, XML'e yazar ve slaytın görünümünü tazeler.
  void updateParagraph(PptxSlide slide, PptxParagraph para, String text) {
    para.text = text;
    _writeText(para);
    slide.view = _tryRender(_render, slide.fileName, slide.doc) ?? slide.view;
  }

  /// Paragrafın tüm çalıştırmalarına (a:r → a:rPr) biçim uygular; verilmeyen
  /// özellik el değmeden kalır. Punto `sz` yüzde-punto (pt × 100) yazılır.
  /// rPr yoksa oluşturulur — şema gereği `a:t`'den ÖNCE (ilk çocuk) durmalı.
  void formatParagraph(
    PptxSlide slide,
    PptxParagraph para, {
    bool? bold,
    bool? italic,
    bool? underline,
    double? sizePt,
    String? fontFamily,
  }) {
    if (bold == null &&
        italic == null &&
        underline == null &&
        sizePt == null &&
        fontFamily == null) {
      return;
    }
    for (final r in para.element.findElements('a:r')) {
      var rPr = _firstOrNull(r.findElements('a:rPr'));
      if (rPr == null) {
        rPr = XmlElement(XmlName('a:rPr'));
        r.children.insert(0, rPr);
      }
      if (bold != null) rPr.setAttribute('b', bold ? '1' : '0');
      if (italic != null) rPr.setAttribute('i', italic ? '1' : '0');
      if (underline != null) rPr.setAttribute('u', underline ? 'sng' : 'none');
      if (sizePt != null) {
        rPr.setAttribute('sz', '${(sizePt * 100).round()}');
      }
      if (fontFamily != null) _setTypeface(rPr, fontFamily);
    }
    slide.view = _tryRender(_render, slide.fileName, slide.doc) ?? slide.view;
  }

  /// Çalıştırmanın yazı tipini yazar.
  ///
  /// Üç ayrı düğüm var çünkü PowerPoint her yazı sistemi için ayrısına bakar:
  /// `a:latin` (Latin), `a:cs` (karmaşık yazılar — Arapça belgeler bunu okur),
  /// `a:ea` (Doğu Asya). Yalnız `a:latin` yazmak Arapça metinde hiçbir şeyi
  /// değiştirmezdi. Var olan düğüm güncellenir, yoksa eklenir — `a:latin`
  /// şema gereği rPr'nin İÇİNDE, `a:t`'nin dışındadır.
  static void _setTypeface(XmlElement rPr, String typeface) {
    for (final tag in const ['a:latin', 'a:cs', 'a:ea']) {
      var node = _firstOrNull(rPr.findElements(tag));
      if (node == null) {
        node = XmlElement(XmlName(tag));
        rPr.children.add(node);
      }
      node.setAttribute('typeface', typeface);
    }
  }

  /// Paragrafın ilk çalıştırmasında yazılı yazı tipi (yoksa null).
  ///
  /// Çizim modelindeki ad DEĞİL, XML'deki ÖZGÜN ad okunur: çizim modeli adı
  /// gömülü aileye eşliyor (Arial → Arimo) ve o eşlemeden geri dönülemez —
  /// çubukta "Arimo" yazsaydı kullanıcı hiç seçmediği bir font görürdü.
  static String? fontOfParagraph(PptxParagraph para) {
    for (final r in para.element.findElements('a:r')) {
      final rPr = _firstOrNull(r.findElements('a:rPr'));
      if (rPr == null) continue;
      final tf = _firstOrNull(rPr.findElements('a:latin'))
          ?.getAttribute('typeface');
      if (tf != null && tf.isNotEmpty) return tf;
    }
    return null;
  }

  void _writeText(PptxParagraph para) {
    final tNodes = para.element.findAllElements('a:t').toList();
    if (tNodes.isEmpty) return;
    tNodes.first.children
      ..clear()
      ..add(XmlText(para.text));
    for (final extra in tNodes.skip(1)) {
      extra.children.clear();
    }
  }

  /// Düzenlenmiş metinleri ve yapısal değişiklikleri geri yazıp yeni .pptx
  /// byte'larını üretir.
  Uint8List save() {
    final updated = <String, String>{};
    for (final slide in slides) {
      for (final para in slide.paragraphs) {
        _writeText(para);
      }
      updated[slide.fileName] = slide.doc.toXmlString();
    }
    if (_contentTypes != null) {
      updated['[Content_Types].xml'] = _contentTypes.toXmlString();
    }
    if (_presentation != null) {
      updated['ppt/presentation.xml'] = _presentation.toXmlString();
    }
    if (_presRels != null) {
      updated['ppt/_rels/presentation.xml.rels'] = _presRels.toXmlString();
    }

    final out = Archive();
    for (final f in _archive.files) {
      if (_removed.contains(f.name)) continue; // silinen slayt/parça atlanır
      if (updated.containsKey(f.name)) {
        _addTo(out, f.name, updated[f.name]!);
      } else {
        out.addFile(f);
      }
    }
    final List<int>? encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────

  void _addFile(String name, String xml) {
    _removed.remove(name); // yeniden eklenen ad artık "silinmiş" sayılmaz
    final data = utf8.encode(xml);
    _archive.addFile(ArchiveFile(name, data.length, data));
  }

  static void _addTo(Archive out, String name, String xml) {
    final data = utf8.encode(xml);
    out.addFile(ArchiveFile(name, data.length, data));
  }

  void _addContentOverride(String fileName, String contentType) {
    final ct = _contentTypes;
    if (ct == null) return;
    final o = XmlElement(XmlName('Override'))
      ..setAttribute('PartName', '/$fileName')
      ..setAttribute('ContentType', contentType);
    ct.rootElement.children.add(o);
  }

  void _removeContentOverride(String fileName) {
    final ct = _contentTypes;
    if (ct == null) return;
    _removeElems(
        ct.rootElement,
        (e) =>
            e.name.qualified == 'Override' &&
            e.getAttribute('PartName') == '/$fileName');
  }

  void _addPresRel(String rid, String type, String target) {
    final r = XmlElement(XmlName('Relationship'))
      ..setAttribute('Id', rid)
      ..setAttribute('Type', type)
      ..setAttribute('Target', target);
    _presRels?.rootElement.children.add(r);
  }

  void _removePresRel(String rid) {
    final rels = _presRels;
    if (rels == null) return;
    _removeElems(
        rels.rootElement,
        (e) =>
            e.name.qualified == 'Relationship' && e.getAttribute('Id') == rid);
  }

  void _appendSldId(int id, String rid) {
    final lst = _sldIdLst;
    if (lst == null) return;
    final e = XmlElement(XmlName('p:sldId'))
      ..setAttribute('id', '$id')
      ..setAttribute('r:id', rid);
    lst.children.add(e);
  }

  void _removeSldId(String rid) {
    final lst = _sldIdLst;
    if (lst == null) return;
    _removeElems(
        lst,
        (e) =>
            e.name.qualified == 'p:sldId' && e.getAttribute('r:id') == rid);
  }

  String? _ridOfSlide(String fileName) {
    final rels = _presRels;
    if (rels == null) return null;
    for (final e in _relTargets(rels).entries) {
      if (e.value == fileName) return e.key;
    }
    return null;
  }

  int _nextSlideNumber() {
    var max = 0;
    for (final f in _archive.files) {
      final m = RegExp(r'ppt/slides/slide(\d+)\.xml$').firstMatch(f.name);
      if (m != null) {
        final v = int.parse(m.group(1)!);
        if (v > max) max = v;
      }
    }
    return max + 1;
  }

  String _nextRelId() {
    var max = 0;
    for (final r
        in _presRels?.findAllElements('Relationship') ?? const <XmlElement>[]) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null) {
        final v = int.parse(m.group(1)!);
        if (v > max) max = v;
      }
    }
    return 'rId${max + 1}';
  }

  int _nextSldId() {
    var max = 255; // OOXML: slayt kimlikleri 256'dan başlar
    for (final e in _sldIdLst?.findElements('p:sldId') ?? const <XmlElement>[]) {
      final v = int.tryParse(e.getAttribute('id') ?? '');
      if (v != null && v > max) max = v;
    }
    return max + 1;
  }

  static String _relsPathOf(String fileName) {
    final slash = fileName.lastIndexOf('/');
    final dir = fileName.substring(0, slash + 1);
    final base = fileName.substring(slash + 1);
    return '${dir}_rels/$base.rels';
  }

  /// presentation.xml.rels'teki rId → ppt/ köküne göre normalize edilmiş hedef.
  static Map<String, String> _relTargets(XmlDocument presRels) {
    final out = <String, String>{};
    for (final r in presRels.findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id == null || target == null) continue;
      if (r.getAttribute('TargetMode') == 'External') continue;
      out[id] = _normTarget(target);
    }
    return out;
  }

  static String _normTarget(String t) {
    if (t.startsWith('/')) return t.substring(1);
    var s = t;
    var base = 'ppt/';
    while (s.startsWith('../')) {
      s = s.substring(3);
      base = '';
    }
    return '$base$s';
  }

  static XmlDocument? _tryParse(Archive archive, String name) {
    final content = _fileByName(archive, name);
    if (content == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(content, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  static List<int>? _fileByName(Archive archive, String name) {
    for (final f in archive.files) {
      if (f.name == name) return f.content as List<int>;
    }
    return null;
  }

  static int _idx(String name) {
    final m = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  static XmlElement? _firstOrNull(Iterable<XmlElement> it) {
    final list = it.toList();
    return list.isEmpty ? null : list.first;
  }

  /// Eşleşen çocuk elemanları tek tek [XmlNodeList.remove] ile siler
  /// (removeWhere'in üst-düğüm çakışması riski olmadan).
  static void _removeElems(XmlElement parent, bool Function(XmlElement) test) {
    final gone =
        parent.children.whereType<XmlElement>().where(test).toList();
    for (final e in gone) {
      parent.children.remove(e);
    }
  }
}
