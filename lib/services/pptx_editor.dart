import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart' show Color, TextAlign;
import 'package:xml/xml.dart';

import '../core/edit/save_coordinator.dart';

import 'pptx_render.dart';
import 'pptx_rich_text.dart';

part 'pptx_objects.dart';

/// Bir slayttaki düzenlenebilir paragraf (a:p) — orijinal XML düğümüne bağlı.
class PptxParagraph {
  String text;
  final XmlElement element; // <a:p>

  /// XML'e en son yazılan (ya da okunan) metin — kaydetme yalnız DEĞİŞEN
  /// paragrafa dokunur; yoksa el değmemiş paragrafların karışık biçimi
  /// (ikinci run'daki kalın kelime) her kayıtta ilk run'a toplanırdı.
  String _written;

  PptxParagraph(this.text, this.element) : _written = text;
}

/// [PptxEditor.snapshot] sonucu — yalnız [PptxEditor.restore] okur.
class PptxSnapshot {
  final List<(String, String)> slides;
  final String? contentTypes, presentation, presRels;
  final Map<String, ArchiveFile> files;
  final Set<String> removed;
  final Map<String, String> notes;

  const PptxSnapshot._({
    required this.slides,
    required this.contentTypes,
    required this.presentation,
    required this.presRels,
    required this.files,
    required this.removed,
    required this.notes,
  });
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
      paras.add(PptxParagraph(_textOf(p), p));
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
    var relsXml = srcRels != null
        ? utf8.decode(srcRels, allowMalformed: true)
        : '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>';
    // Konuşmacı notu kopyaya TAŞINMAZ (Faz 28): iki slayt aynı not sayfasını
    // paylaşırsa PowerPoint dosyayı onarmak ister; kopyanın notu boş başlar.
    try {
      final rels = XmlDocument.parse(relsXml);
      _removeElems(rels.rootElement,
          (e) => (e.getAttribute('Type') ?? '').endsWith('/notesSlide'));
      relsXml = rels.toXmlString();
    } catch (_) {
      // Bozuk ilişki tablosu olduğu gibi kopyalanır.
    }

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
    // Slaydın not sayfası da gider (sahipsiz not, silinmiş slayda işaret
    // eden bir ilişki taşırdı).
    final notes = _notesFileOf(slide);
    if (notes != null) {
      _removeContentOverride(notes);
      _removed.add(notes);
      _removed.add(_relsPathOf(notes));
    }
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
  ///
  /// Faz 28: paragraf çizim modelinde bulunursa yazım zengin modelden geçer —
  /// yalnız değişen aralık yeniden yazılır, öbür run'ların biçimi (ikinci
  /// run'daki kalın kelime) korunur (SL2). `\n` paragraf içi satır sonudur.
  void updateParagraph(PptxSlide slide, PptxParagraph para, String text) {
    final shape = shapeOfParagraph(slide, para);
    if (shape != null) {
      final idx = shape.paragraphs
          .indexWhere((p) => identical(p.source, para.element));
      final rich = SlideRichText.fromParagraphs(shape.paragraphs);
      final ranges = rich.paragraphRanges();
      if (idx >= 0 && idx < ranges.length) {
        final (start, end) = ranges[idx];
        final next = text.replaceAll('\n', kSlideLineBreak);
        if (rich.text.substring(start, end) != next) {
          rich.applyText(rich.text.replaceRange(start, end, next));
          writeRichText(slide, shape, rich);
        }
        return;
      }
    }
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
    // Şema sırası latin → ea → cs ve hepsi `a:hlinkClick`'ten ÖNCE (Faz 28:
    // eskiden sona ekleniyordu; köprülü run'da şema dışı sıra oluşuyordu).
    for (final tag in const ['a:latin', 'a:ea', 'a:cs']) {
      var node = _firstOrNull(rPr.findElements(tag));
      if (node == null) {
        node = XmlElement(XmlName(tag));
        _insertBefore(rPr, node, _afterFontTags);
      }
      node.setAttribute('typeface', typeface);
    }
  }

  static const _afterFontTags = {
    'a:sym',
    'a:hlinkClick',
    'a:hlinkMouseOver',
    'a:rtl',
    'a:extLst',
  };

  /// [child]'ı [parent]'ın içinde, adı [before] kümesinde olan ilk çocuğun
  /// önüne (yoksa sona) koyar.
  static void _insertBefore(
      XmlElement parent, XmlElement child, Set<String> before) {
    final kids = parent.children;
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      if (k is XmlElement && before.contains(k.name.qualified)) {
        kids.insert(i, child);
        return;
      }
    }
    kids.add(child);
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

  /// Paragraf metni: `a:t`'ler sırayla, `a:br` (satır sonu) `\n` olarak.
  static String _textOf(XmlElement p) {
    final sb = StringBuffer();
    for (final e in p.descendantElements) {
      switch (e.name.qualified) {
        case 'a:t':
          sb.write(e.innerText);
        case 'a:br':
          sb.write('\n');
      }
    }
    return sb.toString();
  }

  /// Paragraf metnini XML'e yazar (Faz 20 / SL1, 2026-10-23).
  ///
  /// Eskiden `\n` `a:t` içine ham yazılıyordu (PowerPoint satır sonu
  /// göstermez) ve `a:t`'si olmayan boş paragrafa yazılan metin hiç
  /// kaydedilmiyordu. Şimdi: tek satırlık değişiklik ilk `a:t`'ye (run
  /// yapısı korunur); çok satırlı ya da `a:t`'siz paragrafta run'lar
  /// yeniden kurulur — satır arası `a:br`, biçim ilk run'ın `a:rPr`'inden,
  /// yoksa `a:endParaRPr`'den.
  void _writeText(PptxParagraph para) {
    if (para.text == para._written) return;
    final el = para.element;
    final tNodes = el.findAllElements('a:t').toList();
    if (!para.text.contains('\n') &&
        tNodes.isNotEmpty &&
        !el.findElements('a:br').any((_) => true)) {
      tNodes.first.children
        ..clear()
        ..add(XmlText(para.text));
      for (final extra in tNodes.skip(1)) {
        extra.children.clear();
      }
      para._written = para.text;
      return;
    }
    XmlElement? template;
    for (final r in el.findElements('a:r')) {
      template = _firstOrNull(r.findElements('a:rPr'));
      if (template != null) break;
    }
    final end = _firstOrNull(el.findElements('a:endParaRPr'));
    XmlElement makeRPr() {
      if (template != null) return template.copy();
      final rPr = XmlElement(XmlName('a:rPr'));
      if (end != null) {
        for (final a in end.attributes) {
          rPr.setAttribute(a.name.qualified, a.value);
        }
        for (final c in end.childElements) {
          rPr.children.add(c.copy());
        }
      }
      return rPr;
    }

    el.children.removeWhere((n) =>
        n is XmlElement &&
        const {'a:r', 'a:br', 'a:fld'}.contains(n.name.qualified));
    final nodes = <XmlNode>[];
    final lines = para.text.split('\n');
    for (var k = 0; k < lines.length; k++) {
      if (k > 0) {
        nodes.add(XmlElement(XmlName('a:br'), [], [makeRPr()]));
      }
      if (lines[k].isEmpty) continue;
      nodes.add(XmlElement(XmlName('a:r'), [], [
        makeRPr(),
        XmlElement(XmlName('a:t'), [], [XmlText(lines[k])]),
      ]));
    }
    final at = end == null ? el.children.length : el.children.indexOf(end);
    el.children.insertAll(at, nodes);
    para._written = para.text;
  }

  // ── Zengin metin (Faz 28) ───────────────────────────────────────────────

  /// Kutunun zengin metnini XML'e yazar: yalnız DEĞİŞEN paragraflar
  /// yeniden kurulur, onlarda da el değmemiş run'lar özgün düğümün kopyası
  /// olarak yazılır (köprü, alan, dil özniteliği korunur). Enter ile doğan
  /// paragraflar öncekinin `a:pPr`'ini taşır; birleşen paragrafların
  /// düğümleri kalkar. Metin gövdesi olmayan yer tutucuya gövde açılır.
  /// Dönen değer: bir şey yazıldı mı.
  bool writeRichText(PptxSlide slide, ShapeVM shape, SlideRichText rich) {
    if (!rich.touched) return false;
    final orig = [
      for (final p in shape.paragraphs)
        if (p.source != null) p.source!,
    ];
    XmlElement? body = orig.isEmpty ? null : orig.first.parent as XmlElement?;
    if (body == null) {
      if (rich.text.isEmpty) return false; // boş yer tutucu boş kaldı
      final sp = shape.element;
      if (sp == null || sp.name.qualified != 'p:sp') return false;
      body = _ensureTxBody(sp);
    }
    final txBody = body;

    final ranges = rich.paragraphRanges();
    final targets = <XmlElement>[];
    final used = <XmlElement>{};
    for (var k = 0; k < rich.paras.length; k++) {
      final ps = rich.paras[k];
      var el = ps.source;
      if (el == null || used.contains(el) || !identical(el.parent, txBody)) {
        el = _newParagraph(ps.cloneOf ??
            (targets.isEmpty ? _firstOrNull(txBody.findElements('a:p')) : targets.last));
        ps.touched = true;
      }
      used.add(el);
      targets.add(el);
      if (!ps.touched) continue;
      final (start, end) = k < ranges.length ? ranges[k] : (0, 0);
      _writeRuns(el, rich.groupsIn(start, end));
      _writeParaProps(el, ps);
    }

    // Yapı: birleşen paragrafların düğümleri kalkar, yeniler yerine girer.
    for (final el in txBody.findElements('a:p').toList()) {
      if (!used.contains(el)) txBody.children.remove(el);
    }
    for (var i = 0; i < targets.length; i++) {
      final el = targets[i];
      if (el.parent != null) continue;
      if (i == 0) {
        final first = _firstOrNull(txBody.findElements('a:p'));
        if (first != null) {
          txBody.children.insert(txBody.children.indexOf(first), el);
        } else {
          _insertBefore(txBody, el, const {'a:extLst'});
        }
      } else {
        final prev = targets[i - 1];
        txBody.children.insert(txBody.children.indexOf(prev) + 1, el);
      }
    }

    _refreshParagraphs(slide);
    _render.forget(slide.fileName);
    slide.view = _tryRender(_render, slide.fileName, slide.doc) ?? slide.view;
    return true;
  }

  /// `p:sp`'ye boş metin gövdesi ekler (şema: spPr → style → txBody).
  XmlElement _ensureTxBody(XmlElement sp) {
    final existing = _firstOrNull(sp.findElements('p:txBody'));
    if (existing != null) return existing;
    final body = XmlElement(XmlName('p:txBody'), [], [
      XmlElement(XmlName('a:bodyPr')),
      XmlElement(XmlName('a:lstStyle')),
    ]);
    _insertBefore(sp, body, const {'p:extLst'});
    return body;
  }

  /// [model]'in `a:pPr` ve `a:endParaRPr`'ini taşıyan boş paragraf.
  static XmlElement _newParagraph(XmlElement? model) {
    final p = XmlElement(XmlName('a:p'));
    final pPr = model == null ? null : _firstOrNull(model.findElements('a:pPr'));
    if (pPr != null) p.children.add(pPr.copy());
    final end =
        model == null ? null : _firstOrNull(model.findElements('a:endParaRPr'));
    if (end != null) p.children.add(end.copy());
    return p;
  }

  /// Paragrafın run'larını gruplardan yeniden kurar.
  void _writeRuns(XmlElement p, List<(String, RunStyle)> groups) {
    XmlElement? template;
    for (final r in p.findElements('a:r')) {
      template = _firstOrNull(r.findElements('a:rPr'));
      if (template != null) break;
    }
    final end = _firstOrNull(p.findElements('a:endParaRPr'));
    XmlElement baseRPr(RunStyle st) {
      final src = st.source;
      final own = src == null ? null : _firstOrNull(src.findElements('a:rPr'));
      if (own != null) return own.copy();
      if (src == null && template != null) return template.copy();
      final rPr = XmlElement(XmlName('a:rPr'));
      if (end != null && (src == null || own == null)) {
        for (final a in end.attributes) {
          rPr.setAttribute(a.name.qualified, a.value);
        }
        for (final c in end.childElements) {
          rPr.children.add(c.copy());
        }
      }
      return rPr;
    }

    final nodes = <XmlNode>[];
    for (final (text, st) in groups) {
      if (text == kSlideLineBreak) {
        nodes.add(XmlElement(
            XmlName('a:br'), [], [_withOverrides(baseRPr(st), st)]));
        continue;
      }
      final src = st.source;
      if (st.plain &&
          src != null &&
          (src.name.qualified == 'a:r' || src.name.qualified == 'a:fld') &&
          _runText(src) == text) {
        nodes.add(src.copy());
        continue;
      }
      nodes.add(XmlElement(XmlName('a:r'), [], [
        _withOverrides(baseRPr(st), st),
        XmlElement(XmlName('a:t'), [], [XmlText(text)]),
      ]));
    }
    p.children.removeWhere((n) =>
        n is XmlElement &&
        const {'a:r', 'a:br', 'a:fld'}.contains(n.name.qualified));
    final at = end == null ? p.children.length : p.children.indexOf(end);
    p.children.insertAll(at, nodes);
  }

  static String _runText(XmlElement r) {
    final t = _firstOrNull(r.findElements('a:t'));
    return t?.innerText ?? '';
  }

  /// Kullanıcı biçimini `a:rPr`'e yazar.
  static XmlElement _withOverrides(XmlElement rPr, RunStyle st) {
    if (st.bold != null) rPr.setAttribute('b', st.bold! ? '1' : '0');
    if (st.italic != null) rPr.setAttribute('i', st.italic! ? '1' : '0');
    if (st.underline != null) {
      rPr.setAttribute('u', st.underline! ? 'sng' : 'none');
    }
    if (st.sizePt != null) {
      rPr.setAttribute('sz', '${(st.sizePt! * 100).round()}');
    }
    if (st.color != null) _setSolidFill(rPr, st.color!);
    if (st.font != null && st.font!.isNotEmpty) _setTypeface(rPr, st.font!);
    return rPr;
  }

  static const _fillTags = {
    'a:noFill',
    'a:solidFill',
    'a:gradFill',
    'a:blipFill',
    'a:pattFill',
    'a:grpFill',
  };

  /// Run rengini düz dolgu olarak yazar (şemada `a:ln`'den hemen sonra).
  static void _setSolidFill(XmlElement rPr, Color color) {
    rPr.children.removeWhere(
        (n) => n is XmlElement && _fillTags.contains(n.name.qualified));
    final hex = (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    final fill = XmlElement(XmlName('a:solidFill'), [], [
      XmlElement(XmlName('a:srgbClr'), [XmlAttribute(XmlName('val'), hex)]),
    ]);
    final ln = _firstOrNull(rPr.findElements('a:ln'));
    if (ln != null) {
      rPr.children.insert(rPr.children.indexOf(ln) + 1, fill);
    } else {
      rPr.children.insert(0, fill);
    }
  }

  /// Paragraf özellikleri: hizalama, düzey, madde işareti.
  static void _writeParaProps(XmlElement p, ParaStyle ps) {
    if (ps.align == null && ps.bullet == null && ps.level == null) return;
    var pPr = _firstOrNull(p.findElements('a:pPr'));
    if (pPr == null) {
      pPr = XmlElement(XmlName('a:pPr'));
      p.children.insert(0, pPr);
    }
    if (ps.align != null) {
      pPr.setAttribute(
          'algn',
          switch (ps.align!) {
            TextAlign.center => 'ctr',
            TextAlign.right || TextAlign.end => 'r',
            TextAlign.justify => 'just',
            _ => 'l',
          });
    }
    if (ps.level != null) {
      if (ps.level! > 0) {
        pPr.setAttribute('lvl', '${ps.level}');
      } else {
        pPr.removeAttribute('lvl');
      }
      // Düzeyin girintisi şablondan gelsin (elle marL düzeyi gölgelerdi).
      pPr.removeAttribute('marL');
      pPr.removeAttribute('indent');
    }
    if (ps.bullet != null) {
      pPr.children.removeWhere((n) =>
          n is XmlElement &&
          const {'a:buNone', 'a:buAutoNum', 'a:buChar', 'a:buBlip', 'a:buFont'}
              .contains(n.name.qualified));
      final XmlElement bu = switch (ps.bullet!) {
        'char' => XmlElement(XmlName('a:buChar'), [
            XmlAttribute(XmlName('char'), '•'),
          ]),
        'num' => XmlElement(XmlName('a:buAutoNum'), [
            XmlAttribute(XmlName('type'), 'arabicPeriod'),
          ]),
        _ => XmlElement(XmlName('a:buNone')),
      };
      _insertBefore(pPr, bu, const {'a:tabLst', 'a:defRPr', 'a:extLst'});
      if (ps.bullet != 'none' && pPr.getAttribute('marL') == null) {
        // Asılı girinti: madde işareti solda, metin hizalı.
        final lvl = ps.effLevel;
        pPr.setAttribute('marL', '${342900 + lvl * 457200}');
        pPr.setAttribute('indent', '-342900');
      }
    }
  }

  /// Slaydın paragraf listesini XML'den tazeler; var olan nesneler korunur.
  void _refreshParagraphs(PptxSlide slide) {
    final byEl = {for (final p in slide.paragraphs) p.element: p};
    final next = <PptxParagraph>[];
    for (final el in slide.doc.findAllElements('a:p')) {
      final text = _textOf(el);
      final old = byEl[el];
      if (old != null) {
        old.text = text;
        old._written = text;
        next.add(old);
      } else {
        next.add(PptxParagraph(text, el));
      }
    }
    slide.paragraphs
      ..clear()
      ..addAll(next);
  }

  /// [para]'nın çizim modelindeki karşılığı (zengin yazım için).
  ShapeVM? shapeOfParagraph(PptxSlide slide, PptxParagraph para) {
    for (final sh in slide.view?.shapes ?? const <ShapeVM>[]) {
      for (final p in sh.paragraphs) {
        if (identical(p.source, para.element)) return sh;
      }
    }
    return null;
  }

  // ── Şekil işlemleri (Faz 28 / madde 1) ──────────────────────────────────

  /// Şekil slaydın kendi ağacında mı (sil/çoğalt/sırala yalnız onlarda).
  static bool canArrange(ShapeVM shape) {
    final el = shape.element;
    final parent = el?.parent;
    return el != null &&
        parent is XmlElement &&
        (parent.name.qualified == 'p:spTree' ||
            parent.name.qualified == 'p:grpSp');
  }

  void _rerender(PptxSlide slide) {
    _render.forget(slide.fileName);
    _refreshParagraphs(slide);
    slide.view = _tryRender(_render, slide.fileName, slide.doc) ?? slide.view;
  }

  /// Şekli siler.
  bool deleteShape(PptxSlide slide, ShapeVM shape) {
    if (!canArrange(shape)) return false;
    final el = shape.element!;
    (el.parent! as XmlElement).children.remove(el);
    _rerender(slide);
    return true;
  }

  /// Şeklin kopyasını biraz kaydırarak hemen üstüne ekler (yeni kimlikle).
  bool duplicateShape(PptxSlide slide, ShapeVM shape) {
    if (!canArrange(shape)) return false;
    final el = shape.element!;
    final copy = el.copy();
    _renumberShape(slide, copy);
    final off = _firstOrNull(copy.findAllElements('a:off'));
    if (off != null) {
      for (final a in const ['x', 'y']) {
        final v = int.tryParse(off.getAttribute(a) ?? '');
        if (v != null) off.setAttribute(a, '${v + 228600}'); // 0,25 inç
      }
    }
    final parent = el.parent! as XmlElement;
    parent.children.insert(parent.children.indexOf(el) + 1, copy);
    _rerender(slide);
    return true;
  }

  /// Şekli en öne (true) ya da en arkaya (false) alır.
  bool reorderShape(PptxSlide slide, ShapeVM shape, {required bool front}) {
    if (!canArrange(shape)) return false;
    final el = shape.element!;
    final parent = el.parent! as XmlElement;
    parent.children.remove(el);
    if (front) {
      _insertBefore(parent, el, const {'p:extLst'});
    } else {
      // Ağacın başındaki grup özellikleri (nvGrpSpPr, grpSpPr) önde kalır.
      var at = 0;
      for (var i = 0; i < parent.children.length; i++) {
        final k = parent.children[i];
        if (k is XmlElement &&
            const {'p:nvGrpSpPr', 'p:grpSpPr'}.contains(k.name.qualified)) {
          at = i + 1;
        }
      }
      parent.children.insert(at, el);
    }
    _rerender(slide);
    return true;
  }

  /// Şeklin XML'i (iç pano için).
  String? shapeXml(ShapeVM shape) =>
      canArrange(shape) ? shape.element!.toXmlString() : null;

  /// İç panodaki şekli slayda yapıştırır (yeni kimlikle, kaydırarak).
  bool pasteShape(PptxSlide slide, String xml) {
    final tree = _firstOrNull(slide.doc.findAllElements('p:spTree'));
    if (tree == null) return false;
    XmlElement el;
    try {
      el = XmlDocumentFragment.parse(_withNs(xml)).firstElementChild!.copy();
    } catch (_) {
      return false;
    }
    el.removeAttribute('xmlns:p');
    el.removeAttribute('xmlns:a');
    el.removeAttribute('xmlns:r');
    _renumberShape(slide, el);
    _insertBefore(tree, el, const {'p:extLst'});
    _rerender(slide);
    return true;
  }

  static String _withNs(String xml) {
    final i = xml.indexOf(RegExp(r'[\s/>]'));
    if (i < 0) return xml;
    return '${xml.substring(0, i)} '
        'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
        'xmlns:a="$_nsA" xmlns:r="$_nsR"${xml.substring(i)}';
  }

  /// Kopyadaki bütün `p:cNvPr` kimliklerini slaytta kullanılmayanlarla
  /// değiştirir (çakışan kimlik PowerPoint'te onarım ister).
  void _renumberShape(PptxSlide slide, XmlElement el) {
    var next = 1;
    for (final c in slide.doc.findAllElements('p:cNvPr')) {
      final v = int.tryParse(c.getAttribute('id') ?? '') ?? 0;
      if (v >= next) next = v + 1;
    }
    for (final c in el.findAllElements('p:cNvPr')) {
      c.setAttribute('id', '${next++}');
    }
  }

  // ── Konuşmacı notu yazma (Faz 28 / madde 8) ─────────────────────────────

  static const _notesSlideType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide';
  static const _notesMasterType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster';
  static const _themeType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme';
  static const _nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';

  XmlDocument _relsDocOf(String part) {
    final bytes = _fileByName(_archive, _relsPathOf(part));
    if (bytes != null && !_removed.contains(_relsPathOf(part))) {
      try {
        return XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
      } catch (_) {}
    }
    return XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
        'standalone="yes"?>\n<Relationships xmlns="$_relsNs"/>');
  }

  /// Slaydın not sayfasının paket yolu (yoksa null).
  String? _notesFileOf(PptxSlide slide) {
    final rels = _relsDocOf(slide.fileName);
    for (final r in rels.rootElement.childElements) {
      if (r.getAttribute('Type') != _notesSlideType) continue;
      final t = r.getAttribute('Target');
      if (t == null) continue;
      return _resolve(slide.fileName, t);
    }
    return null;
  }

  /// Parçaya göre görece hedefi paket yoluna çevirir.
  static String _resolve(String part, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = part.split('/')..removeLast();
    for (final seg in target.split('/')) {
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (seg != '.') {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }

  static String _nextRid(XmlDocument rels) {
    var max = 0;
    for (final r in rels.rootElement.childElements) {
      final m = RegExp(r'^rId(\d+)$').firstMatch(r.getAttribute('Id') ?? '');
      if (m != null && int.parse(m[1]!) > max) max = int.parse(m[1]!);
    }
    return 'rId${max + 1}';
  }

  static void _addRel(XmlDocument rels, String id, String type, String target) {
    rels.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), id),
      XmlAttribute(XmlName('Type'), type),
      XmlAttribute(XmlName('Target'), target),
    ]));
  }

  String _freeName(String prefix, String ext) {
    final names = {for (final f in _archive.files) f.name};
    var n = 1;
    while (names.contains('$prefix$n.$ext') && !_removed.contains('$prefix$n.$ext')) {
      n++;
    }
    return '$prefix$n.$ext';
  }

  /// Slaydın konuşmacı notunu [text] yapar. Not sayfası yoksa oluşturulur;
  /// sunumda not şablonu da yoksa asgari bir şablon (+ tema kopyası) eklenir.
  /// Yapı desteklenmiyorsa false.
  bool setNotes(PptxSlide slide, String text) {
    var notesFile = _notesFileOf(slide);
    XmlDocument? doc;
    if (notesFile != null) {
      final bytes = _fileByName(_archive, notesFile);
      if (bytes != null) {
        try {
          doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
        } catch (_) {}
      }
    }
    if (doc == null) {
      if (text.trim().isEmpty) {
        _notesCache[slide.fileName] = '';
        return true;
      }
      if (!canEditStructure) return false;
      final master = _ensureNotesMaster();
      if (master == null) return false;
      notesFile = _freeName('ppt/notesSlides/notesSlide', 'xml');
      doc = XmlDocument.parse(_notesSlideXml);
      final slideName = slide.fileName.split('/').last;
      final nrels = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
          'standalone="yes"?>\n<Relationships xmlns="$_relsNs"/>');
      _addRel(nrels, 'rId1', _notesMasterType,
          '../notesMasters/${master.split('/').last}');
      _addRel(nrels, 'rId2', '$_nsR/slide', '../slides/$slideName');
      _addFile(_relsPathOf(notesFile), nrels.toXmlString());
      _addContentOverride(notesFile,
          'application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml');
      final srels = _relsDocOf(slide.fileName);
      _addRel(srels, _nextRid(srels), _notesSlideType,
          '../notesSlides/${notesFile.split('/').last}');
      _addFile(_relsPathOf(slide.fileName), srels.toXmlString());
      _render.forget(slide.fileName);
    }

    // Gövde yer tutucusu (yoksa eklenir).
    XmlElement? body;
    for (final sp in doc.findAllElements('p:sp')) {
      final ph = _firstOrNull(sp.findAllElements('p:ph'));
      if (ph != null && ph.getAttribute('type') == 'body') {
        body = sp;
        break;
      }
    }
    if (body == null) {
      final tree = _firstOrNull(doc.findAllElements('p:spTree'));
      if (tree == null) return false;
      body = XmlDocumentFragment.parse(_withNs(_notesBodySp))
          .firstElementChild!
          .copy();
      body.removeAttribute('xmlns:p');
      body.removeAttribute('xmlns:a');
      body.removeAttribute('xmlns:r');
      tree.children.add(body);
    }
    final txBody = _ensureTxBody(body);
    final model = _firstOrNull(txBody.findElements('a:p'));
    XmlElement? rPr;
    for (final r in txBody.findAllElements('a:r')) {
      rPr = _firstOrNull(r.findElements('a:rPr'));
      if (rPr != null) break;
    }
    txBody.children.removeWhere(
        (n) => n is XmlElement && n.name.qualified == 'a:p');
    final lines = text.split('\n');
    for (final line in lines) {
      final p = _newParagraph(model);
      if (line.isNotEmpty) {
        final r = XmlElement(XmlName('a:r'), [], [
          rPr?.copy() ?? XmlElement(XmlName('a:rPr')),
          XmlElement(XmlName('a:t'), [], [XmlText(line)]),
        ]);
        final end = _firstOrNull(p.findElements('a:endParaRPr'));
        if (end == null) {
          p.children.add(r);
        } else {
          p.children.insert(p.children.indexOf(end), r);
        }
      }
      _insertBefore(txBody, p, const {'a:extLst'});
    }
    _addFile(notesFile!, doc.toXmlString());
    _render.forget(notesFile);
    _notesCache[slide.fileName] = text;
    return true;
  }

  /// Sunumun not şablonu; yoksa oluşturur. Paket yolu ya da null.
  String? _ensureNotesMaster() {
    final rels = _presRels;
    final pres = _presentation;
    if (rels == null || pres == null) return null;
    for (final r in rels.rootElement.childElements) {
      if (r.getAttribute('Type') == _notesMasterType) {
        final t = r.getAttribute('Target');
        if (t != null) return _normTarget(t);
      }
    }
    // Tema kopyası (not şablonu kendi temasını ister).
    String? themeSrc;
    for (final f in _archive.files) {
      if (RegExp(r'^ppt/theme/theme\d+\.xml$').hasMatch(f.name) &&
          !_removed.contains(f.name)) {
        themeSrc = f.name;
        break;
      }
    }
    if (themeSrc == null) return null;
    final theme = _freeName('ppt/theme/theme', 'xml');
    final themeBytes = _fileByName(_archive, themeSrc)!;
    _addFile(theme, utf8.decode(themeBytes, allowMalformed: true));
    _addContentOverride(
        theme, 'application/vnd.openxmlformats-officedocument.theme+xml');

    final master = _freeName('ppt/notesMasters/notesMaster', 'xml');
    _addFile(master, _notesMasterXml);
    final mrels = XmlDocument.parse('<?xml version="1.0" encoding="UTF-8" '
        'standalone="yes"?>\n<Relationships xmlns="$_relsNs"/>');
    _addRel(mrels, 'rId1', _themeType, '../theme/${theme.split('/').last}');
    _addFile(_relsPathOf(master), mrels.toXmlString());
    _addContentOverride(master,
        'application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml');

    final rid = _nextRelId();
    _addPresRel(rid, _notesMasterType, 'notesMasters/${master.split('/').last}');
    // `p:notesMasterIdLst` şemada `p:sldMasterIdLst`'ten hemen sonra.
    final root = pres.rootElement;
    final lst = XmlElement(XmlName('p:notesMasterIdLst'), [], [
      XmlElement(XmlName('p:notesMasterId'), [XmlAttribute(XmlName('r:id'), rid)]),
    ]);
    if (root.getAttribute('xmlns:r') == null) root.setAttribute('xmlns:r', _nsR);
    final sm = _firstOrNull(root.findElements('p:sldMasterIdLst'));
    if (sm != null) {
      root.children.insert(root.children.indexOf(sm) + 1, lst);
    } else {
      root.children.insert(0, lst);
    }
    return master;
  }

  static const _notesBodySp =
      '<p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/>'
      '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
      '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/>'
      '<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>';

  static const _notesSlideXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<p:notes xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP">'
      '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/>'
      '<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
      '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/>'
      '<p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/>'
      '</p:cNvSpPr><p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr>'
      '<p:spPr/></p:sp>'
      '$_notesBodySp'
      '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
      '</p:notes>';

  static const _notesMasterXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<p:notesMaster xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP">'
      '<p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef>'
      '</p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/>'
      '<p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
      '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 1"/>'
      '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
      '<p:nvPr><p:ph type="body" sz="quarter" idx="1"/></p:nvPr></p:nvSpPr>'
      '<p:spPr><a:xfrm><a:off x="685800" y="4400550"/>'
      '<a:ext cx="5486400" cy="3600450"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
      '<p:txBody><a:bodyPr vert="horz" lIns="91440" tIns="45720" rIns="91440" '
      'bIns="45720" rtlCol="0"/><a:lstStyle/><a:p><a:endParaRPr lang="tr-TR"/>'
      '</a:p></p:txBody></p:sp></p:spTree></p:cSld>'
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
      'accent2="accent2" accent3="accent3" accent4="accent4" '
      'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
      '<p:notesStyle><a:lvl1pPr marL="0" algn="l" defTabSz="914400" rtl="0" '
      'eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:defRPr sz="1200" '
      'kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
      '<a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/>'
      '<a:cs typeface="+mn-cs"/></a:defRPr></a:lvl1pPr></p:notesStyle>'
      '</p:notesMaster>';

  // ── Geri al anlık görüntüsü (Faz 28 / madde 9) ──────────────────────────

  /// Destenin geri alınabilir durumu: canlı XML belgeleri metin olarak,
  /// paket parçaları BAŞVURU olarak (kopyalanmaz — parçalar değiştirilmez,
  /// yenisiyle yer değiştirir).
  PptxSnapshot snapshot() {
    for (final s in slides) {
      for (final p in s.paragraphs) {
        _writeText(p);
      }
    }
    return PptxSnapshot._(
      slides: [for (final s in slides) (s.fileName, s.doc.toXmlString())],
      contentTypes: _contentTypes?.toXmlString(),
      presentation: _presentation?.toXmlString(),
      presRels: _presRels?.toXmlString(),
      files: {for (final f in _archive.files) f.name: f},
      removed: {..._removed},
      notes: Map.of(_notesCache),
    );
  }

  /// [snap] durumuna döner. Yalnız değişen slaytlar yeniden çizilir.
  void restore(PptxSnapshot snap) {
    void replace(XmlDocument? doc, String? xml) {
      if (doc == null || xml == null) return;
      final fresh = XmlDocument.parse(xml);
      doc.children
        ..clear()
        ..addAll(fresh.children.map((n) => n.copy()));
    }

    replace(_contentTypes, snap.contentTypes);
    replace(_presentation, snap.presentation);
    replace(_presRels, snap.presRels);

    for (final f in _archive.files.toList()) {
      final was = snap.files[f.name];
      if (was == null) {
        _removed.add(f.name);
      } else if (!identical(was, f)) {
        _archive.addFile(was);
      }
    }
    for (final e in snap.files.entries) {
      if (_fileByName(_archive, e.key) == null) _archive.addFile(e.value);
    }
    _removed
      ..clear()
      ..addAll(snap.removed);
    for (final f in _archive.files) {
      if (!snap.files.containsKey(f.name)) _removed.add(f.name);
    }
    _render.forgetAll();
    _notesCache
      ..clear()
      ..addAll(snap.notes);

    final current = {for (final s in slides) s.fileName: s};
    final next = <PptxSlide>[];
    for (final (name, xml) in snap.slides) {
      final cur = current[name];
      if (cur != null && cur.doc.toXmlString() == xml) {
        next.add(cur);
        continue;
      }
      final doc = XmlDocument.parse(xml);
      next.add(PptxSlide(0, _paragraphsOf(doc), doc, name,
          _tryRender(_render, name, doc)));
    }
    slides
      ..clear()
      ..addAll(next);
    _reindex();
  }

  /// Düzenlenmiş metinleri ve yapısal değişiklikleri geri yazıp yeni .pptx
  /// byte'larını üretir.
  Archive buildArchive() {
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
    return out;
  }

  /// Dosyayı UI izleğinde üretir (testler, dışa aktarım).
  Uint8List save() {
    final List<int>? encoded = ZipEncoder().encode(buildArchive());
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  /// Faz 20 / ED3: XML serileştirme UI izleğinde (hızlı), zip sıkıştırma
  /// (asıl yük) ayrı izolatta.
  Future<Uint8List> saveAsync() => SaveIsolate.encodeZip(buildArchive());

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
