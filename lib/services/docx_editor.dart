import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/edit/save_coordinator.dart';

part 'docx/live_edit.dart';

/// Canlı düzenlemeden gelen tek biçimli metin parçası.
///
/// [font] ve [sizePt] **null bırakılabilir**: o zaman parça şablon
/// çalıştırmanın (`w:rPr`) yazı tipini/puntosunu miras alır. Görünümden gelen
/// hesaplanmış değeri koşulsuz yazmak, dosyada stilden gelen fontu her
/// düzenlemede satır içi bir `w:rFonts`e dönüştürür ve belge stilini
/// sessizce dondururdu.
class RunSeg {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// Yazı tipi ailesi (`w:rFonts`). null = şablondakini koru.
  final String? font;

  /// Punto (`w:sz`, dosyada yarım-punto). null = şablondakini koru.
  final double? sizePt;

  /// Yazı rengi `RRGGBB` (`w:color`). null = şablondakini koru.
  final String? color;

  /// Vurgu (fosforlu kalem) rengi `RRGGBB`. Word'ün adlandırılmış vurgu
  /// paletinde karşılığı varsa `w:highlight`, yoksa `w:shd` dolgusu olarak
  /// yazılır. null = şablondakini koru.
  final String? highlight;

  /// Üstü çizili (`w:strike`).
  final bool strike;

  /// Dokunulmaz ada (köprü, alan, dipnot başvurusu, sekme, resim …) —
  /// metni `\uFFFC`, kendisi XML'de özgün düğüm olarak kalır (Faz 21 / W4).
  final int? island;

  const RunSeg(
    this.text,
    this.bold,
    this.italic,
    this.underline, {
    this.font,
    this.sizePt,
    this.color,
    this.highlight,
    this.strike = false,
    this.island,
  });

  const RunSeg.island(int id)
      : this('\uFFFC', false, false, false, island: id);

  RunSeg withText(String t) => RunSeg(t, bold, italic, underline,
      font: font,
      sizePt: sizePt,
      color: color,
      highlight: highlight,
      strike: strike,
      island: island);
}

/// Düzenlenebilir bir Word paragrafı (orijinal XML düğümüne bağlı).
///
/// Yedek editördeki biçim bayrakları (kalın/italik/altı çizili/hizalama)
/// paragrafın tamamına uygulanır — orta sadakat. Canlı düzenleme ise
/// [DocxEditor.setRuns] ile segment bazlı yazar.
class DocxParagraph {
  String text;
  final bool heading;
  final int level;
  bool bold;
  bool italic;
  bool underline;

  /// 'left' | 'center' | 'right' | 'both' (iki yana yasla).
  String align;

  /// Paragraf **sağdan sola** mı akıyor (`<w:pPr><w:bidi/>`)?
  ///
  /// Arapça/İbranice/Farsça belgelerin taşıyıcı özelliği: Word'de metin sağda
  /// başlar, noktalama ve karışık (Arapça + Latin) satırlar buna göre dizilir.
  /// Yedek metin düzenleyici bunu uygulamazsa Arapça bir belge soldan sola
  /// çizilir ve karışık satırlarda kelime sırası GÖRÜNÜR biçimde bozulur.
  ///
  /// Salt okunur: `save()` paragrafın XML'ine dokunmadığı sürece `w:bidi`
  /// olduğu yerde kalır, ayrıca yazmak gerekmez.
  final bool rtl;

  /// Ayrıştırırken paragrafın açık bir hizalaması (`<w:jc>`) var mıydı — 'left'
  /// varsayılanına dönerken gereksiz düğüm eklememek için.
  final bool _hadJc;

  /// Dosyada AÇIK bir `<w:jc>` var mıydı? [align] yoksa 'left' döndürür, ama
  /// bu "sola yaslı" demek değil "hizalama yazılmamış" demektir — sağdan sola
  /// bir paragrafta yazılmamış hizalamanın karşılığı SAĞDIR. Görüntüleyen
  /// tarafın ikisini ayırabilmesi için açılıyor.
  bool get hasExplicitAlign => _hadJc;
  final XmlElement _element;

  /// true ise çalıştırmalar [DocxEditor.setRuns] ile XML'e zaten yazıldı;
  /// [DocxEditor.save] bu paragrafın run'larını yalnız o yazımdan SONRA
  /// (yedek editörde) değiştiyse yeniden yazar.
  bool get rich => _richText != null;

  /// setRuns anındaki metin + B/I/U — Faz 20 / W11: canlı kipte yazılmış
  /// paragraf sonra yedek editörde değiştirilince kayıtta ATLANIYORDU.
  String? _richText;
  (bool, bool, bool)? _richBiu;

  void _markRich() {
    _richText = text;
    _richBiu = (bold, italic, underline);
  }

  bool get _richTextChanged => _richText != null && text != _richText;
  bool get _richBiuChanged =>
      _richBiu != null && (bold, italic, underline) != _richBiu;

  // Açılıştaki değerler: save() yalnız DEĞİŞEN paragrafa dokunur, böylece
  // el değmeyen paragrafların run yapısı/biçimi olduğu gibi korunur.
  final String _text0;
  final bool _bold0, _italic0, _underline0;
  final String _align0;

  DocxParagraph(
    this.text,
    this.heading,
    this.level,
    this._element, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = 'left',
    this.rtl = false,
    bool hadJc = false,
  })  : _hadJc = hadJc,
        _text0 = text,
        _bold0 = bold,
        _italic0 = italic,
        _underline0 = underline,
        _align0 = align;

  bool get _textChanged => text != _text0;

  /// B/I/U ve hizalama ayrı izlenir: yalnız hizalama değiştiyse run'ların
  /// karma biçimi (tek kelimesi kalın paragraf gibi) EZİLMEZ.
  bool get _biuChanged =>
      bold != _bold0 || italic != _italic0 || underline != _underline0;
  bool get _alignChanged => align != _align0;
}

/// Bir paragrafın belgedeki konumu (XML ağacındaki yeri + model sırası).
/// Silmenin tersini alabilmek için gerekir.
class DocxParagraphSlot {
  final XmlNode? parent;
  final int xmlIndex;
  final int modelIndex;
  const DocxParagraphSlot(this.parent, this.xmlIndex, this.modelIndex);
}

/// .docx dosyasını paragraf bazında düzenler ve orijinal biçimi koruyarak kaydeder.
///
/// Metin, paragraf içindeki ilk `<w:t>` düğümüne yazılır; paragraf stilleri (pPr)
/// ve çalıştırmaların (run) biçimi (rPr) korunur. Kalın/italik/altı çizili/hizalama
/// değiştirilirse ilgili XML düğümleri güncellenir, gerisi el değmeden kalır.
class DocxEditor {
  final Archive _archive;
  final XmlDocument _doc;
  final List<DocxParagraph> paragraphs;

  DocxEditor._(this._archive, this._doc, this.paragraphs);

  /// Belgenin tamamı **sağdan sola** mı? (`<w:sectPr><w:bidi/>`)
  ///
  /// Word bunu bölüm özelliği olarak yazar; sütun sırası, tablo sütun sırası
  /// ve varsayılan paragraf yönü buna bağlıdır. Gömülü docx-preview motoru
  /// paragraf/çalıştırma düzeyindeki `w:bidi`yi uyguluyor ama **bölüm
  /// düzeyindekini yok sayıyor** (kendi ayrıştırıcısında `case "bidi": break`),
  /// bu yüzden değer buradan okunup görüntüleyiciye ayrıca veriliyor.
  ///
  /// Bölüm işareti hiç yoksa yedek ölçüt: paragrafların **çoğunluğu** sağdan
  /// solaysa belge sağdan soladır. Word'ün Arapça şablonlarında `w:bidi` her
  /// paragrafta durur ama `sectPr`de bulunmayabilir.
  bool get rightToLeft {
    for (final sect in _doc.findAllElements('w:sectPr')) {
      if (_isOn(_firstOrNull(sect.findElements('w:bidi')))) return true;
    }
    final withText = paragraphs.where((p) => p.text.trim().isNotEmpty).toList();
    if (withText.isEmpty) return false;
    final rtlCount = withText.where((p) => p.rtl).length;
    return rtlCount * 2 > withText.length;
  }

  static DocxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException('document.xml bulunamadı'),
    );
    final xml = XmlDocument.parse(
      utf8.decode(docFile.content as List<int>, allowMalformed: true),
    );

    final paras = [for (final p in xml.findAllElements('w:p')) _paraFrom(p)];
    return DocxEditor._(archive, xml, paras);
  }

  /// Bir `w:p` düğümünün düzenleme modeli (ayrıştırma ve canlı
  /// düzenlemede yeni paragraf).
  static DocxParagraph _paraFrom(XmlElement p) {
    final text = p.findAllElements('w:t').map((e) => e.innerText).join();
    final styleVal = p
        .findAllElements('w:pStyle')
        .map((e) => e.getAttribute('w:val') ?? '')
        .firstWhere((_) => true, orElse: () => '');
    final isHeading = styleVal.toLowerCase().contains('heading') ||
        styleVal.toLowerCase().contains('title');
    final level = _levelFromStyle(styleVal);
    final rPr = _firstRunProps(p);
    final jc = _firstOrNull(p.findAllElements('w:jc'));
    return DocxParagraph(
      text,
      isHeading,
      level,
      p,
      bold: rPr != null && _rprHas(rPr, 'w:b'),
      italic: rPr != null && _rprHas(rPr, 'w:i'),
      underline: rPr != null && _rprHas(rPr, 'w:u'),
      align: _normalizeAlign(jc?.getAttribute('w:val')),
      rtl: _paragraphRtl(p),
      hadJc: jc != null,
    );
  }

  /// `<w:pPr><w:bidi/>` — paragraf sağdan sola mı?
  ///
  /// **YALNIZ `w:pPr`nin doğrudan çocuğu** sayılır: bir `w:p`, bölüm sonu
  /// paragrafıysa içinde `w:pPr/w:sectPr/w:bidi` de bulunabilir; o BÖLÜMÜN
  /// yönüdür, paragrafın değil. `findAllElements` ile aransaydı soldan sağa
  /// bir paragraf sırf bölüm sonunu taşıdığı için sağdan sola görünürdü.
  static bool _paragraphRtl(XmlElement p) {
    final pPr = _firstOrNull(p.findElements('w:pPr'));
    if (pPr == null) return false;
    return _isOn(_firstOrNull(pPr.findElements('w:bidi')));
  }

  /// Word'ün aç/kapa öğesi: öğe varsa açık, `w:val="0"/"false"/"off"` ise kapalı.
  static bool _isOn(XmlElement? el) {
    if (el == null) return false;
    final v = el.getAttribute('w:val');
    return v == null || !(v == '0' || v == 'false' || v == 'none' || v == 'off');
  }

  static int _levelFromStyle(String style) {
    if (style.toLowerCase().contains('title')) return 0;
    final m = RegExp(r'(\d+)').firstMatch(style);
    if (m == null) return 1;
    final v = int.parse(m.group(1)!);
    return v < 1 ? 1 : (v > 6 ? 6 : v);
  }

  static String _normalizeAlign(String? v) {
    switch (v) {
      case 'center':
        return 'center';
      case 'right':
      case 'end':
        return 'right';
      case 'both':
      case 'distribute':
        return 'both';
      default:
        return 'left';
    }
  }

  /// Paragrafın ilk çalıştırmasının biçim özelliklerini (`<w:rPr>`) döndürür.
  static XmlElement? _firstRunProps(XmlElement p) {
    final run = _firstOrNull(p.findAllElements('w:r'));
    if (run == null) return null;
    return _firstOrNull(run.findElements('w:rPr'));
  }

  /// `<w:rPr>` içinde bir aç/kapa özelliği (b/i/u) etkin mi?
  /// `val="0"/"false"/"none"/"off"` kapalı sayılır; öznitelik yoksa açık.
  static bool _rprHas(XmlElement rPr, String name) {
    final el = _firstOrNull(rPr.findElements(name));
    if (el == null) return false;
    final v = el.getAttribute('w:val');
    return v == null || !(v == '0' || v == 'false' || v == 'none' || v == 'off');
  }

  static XmlElement? _firstOrNull(Iterable<XmlElement> it) {
    final list = it.toList();
    return list.isEmpty ? null : list.first;
  }

  /// Canlı düzenlemeden gelen paragrafı yazar (Faz 21: fark tabanlı, adaları
  /// koruyan yol — bkz. `docx/live_edit.dart`). [base] paragrafın düzenleme
  /// öncesi hâli (JS ilk düzenlemede yollar); verilmezse son bilinen hâl,
  /// o da yoksa ilk run'ı şablon alan yedek yol.
  void setRuns(int index, List<RunSeg> segs, {List<RunSeg>? base}) {
    if (index < 0 || index >= paragraphs.length) return;
    _applySegs(paragraphs[index], segs, base);
  }

  /// [ref] paragrafından sonra boş bir paragraf ekler (ref null ise belge sonuna,
  /// ama daima `<w:sectPr>`'den önce kalır çünkü onun kardeşi olarak eklenir).
  DocxParagraph addParagraphAfter(DocxParagraph? ref) {
    final newP = XmlElement(XmlName('w:p'));
    final run = XmlElement(XmlName('w:r'));
    final t = XmlElement(XmlName('w:t'))..setAttribute('xml:space', 'preserve');
    run.children.add(t);
    newP.children.add(run);
    final para = DocxParagraph('', false, 1, newP);

    if (ref != null && ref._element.parent != null) {
      final parent = ref._element.parent!;
      final idx = parent.children.indexOf(ref._element);
      parent.children.insert(idx + 1, newP);
      final pIdx = paragraphs.indexOf(ref);
      paragraphs.insert(pIdx < 0 ? paragraphs.length : pIdx + 1, para);
    } else {
      final body = _firstOrNull(_doc.findAllElements('w:body'));
      if (body != null) {
        // sectPr her zaman en sonda kalmalı → varsa ondan önceye ekle.
        final sect = _firstOrNull(body.findElements('w:sectPr'));
        if (sect != null) {
          final idx = body.children.indexOf(sect);
          body.children.insert(idx, newP);
        } else {
          body.children.add(newP);
        }
      }
      paragraphs.add(para);
    }
    return para;
  }

  // ── resim (Faz 9 / Y1) ─────────────────────────────────────────────────

  /// Resim ekleme/silmenin değiştirdiği metin parçaları (ilişkiler, içerik
  /// türleri) ve yeni medya dosyaları — kaydetmede pakete yazılır.
  final Map<String, String> _partEdits = {};
  final Map<String, List<int>> _newMedia = {};

  static const _nsW =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _nsWp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
  static const _nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _nsPic =
      'http://schemas.openxmlformats.org/drawingml/2006/picture';
  static const _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// En geniş resim: A4 metin genişliği (~16 cm). Telefon fotoğrafı
  /// (4000 px) sayfadan taşmasın; oran korunur.
  static const maxImageWidthEmu = 5760000;

  /// [ref]'ten SONRA, içinde yalnız resim olan yeni bir paragraf ekler
  /// (satır içi — `wp:inline`; Word'de "metinle aynı hizada"). [ref] null ise
  /// belge sonuna. [ext] `png` | `jpg` | `jpeg` | `gif`.
  ///
  /// Neden ayrı paragraf: canlı görünümde paragraf eşlemesi `<p>` sayısına
  /// bağlı; mevcut paragrafın içine çizim koymak yerine yeni paragraf
  /// eklemek ekleme sonrası yeniden çizimle eşlemeyi kendiliğinden kurar.
  DocxParagraph insertImageAfter(
    DocxParagraph? ref,
    List<int> bytes, {
    required String ext,
    required int widthPx,
    required int heightPx,
  }) {
    final run = imageRun(bytes, ext: ext, widthPx: widthPx, heightPx: heightPx);
    final para = addParagraphAfter(ref);
    final el = para._element;
    el.children
      ..clear()
      ..add(run);
    para._markRich();
    return para;
  }

  /// Satır içi resim run'ı (`w:drawing`) üretir: medya pakete, ilişki ve
  /// içerik türü yerine yazılır. Run belgeye eklenmez (çağıran yerleştirir).
  XmlElement imageRun(
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
    // Medya adı: pakette ve bu oturumda kullanılmayan ilk numara.
    final names = {
      for (final f in _archive.files) f.name,
      ..._newMedia.keys,
    };
    var n = 1;
    while (names.contains('word/media/fkimage$n.$e')) {
      n++;
    }
    final media = 'word/media/fkimage$n.$e';
    _newMedia[media] = bytes;

    final rid = _addDocRel(
        '$_nsR/image', 'media/fkimage$n.$e');
    _ensureDefaultContentType(e, mime);

    // Boyut: piksel → EMU (96 dpi), sayfa genişliğine sığdırılır.
    var cx = (widthPx <= 0 ? 400 : widthPx) * 9525;
    var cy = (heightPx <= 0 ? 300 : heightPx) * 9525;
    if (cx > maxImageWidthEmu) {
      cy = (cy * maxImageWidthEmu / cx).round();
      cx = maxImageWidthEmu;
    }
    var docPrId = _lastDocPr;
    for (final el in _doc.findAllElements('wp:docPr')) {
      final v = int.tryParse(el.getAttribute('id') ?? '') ?? 0;
      if (v > docPrId) docPrId = v;
    }
    docPrId++;
    _lastDocPr = docPrId;

    return XmlDocumentFragment.parse(
      '<w:r xmlns:w="$_nsW"><w:drawing>'
      '<wp:inline xmlns:wp="$_nsWp" distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="$cx" cy="$cy"/>'
      '<wp:docPr id="$docPrId" name="Resim $docPrId"/>'
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="$_nsA" '
      'noChangeAspect="1"/></wp:cNvGraphicFramePr>'
      '<a:graphic xmlns:a="$_nsA">'
      '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic xmlns:pic="$_nsPic"><pic:nvPicPr>'
      '<pic:cNvPr id="0" name="fkimage$n.$e"/><pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip xmlns:r="$_nsR" r:embed="$rid"/>'
      '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/>'
      '</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
      '</pic:pic></a:graphicData></a:graphic></wp:inline>'
      '</w:drawing></w:r>',
    ).firstElementChild!.copy();
  }

  /// Bu oturumda verilen son `wp:docPr` kimliği — henüz belgeye girmemiş
  /// (canlı görünümde bekleyen) resimler aynı kimliği almasın.
  int _lastDocPr = 0;

  /// Paragraftaki resim sayısı (`w:drawing` + eski `w:pict`).
  int imageCount(int index) {
    if (index < 0 || index >= paragraphs.length) return 0;
    final el = paragraphs[index]._element;
    return el.findAllElements('w:drawing').length +
        el.findAllElements('w:pict').length;
  }

  /// Paragraftaki resimleri siler; silinen sayıyı döner. Medya dosyası
  /// pakette kalır (Word kullanılmayan ilişkiyi sorun etmez) — silme geri
  /// alınırsa yeniden bağlanabilsin.
  int removeImages(int index) {
    if (index < 0 || index >= paragraphs.length) return 0;
    final el = paragraphs[index]._element;
    var removed = 0;
    for (final run in el.findAllElements('w:r').toList()) {
      final pics = run.findAllElements('w:drawing').length +
          run.findAllElements('w:pict').length;
      if (pics == 0) continue;
      removed += pics;
      run.parent?.children.remove(run);
    }
    return removed;
  }

  String _addDocRel(String type, String target) {
    const name = 'word/_rels/document.xml.rels';
    final doc = XmlDocument.parse(_partText(name) ??
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>');
    final rels = doc.rootElement.findElements('Relationship').toList();
    final used = rels.map((e) => e.getAttribute('Id')).toSet();
    var n = rels.length + 1;
    while (used.contains('rId$n')) {
      n++;
    }
    doc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rId$n'),
      XmlAttribute(XmlName('Type'), type),
      XmlAttribute(XmlName('Target'), target),
    ]));
    _partEdits[name] = doc.toXmlString();
    return 'rId$n';
  }

  void _ensureDefaultContentType(String ext, String mime) {
    const name = '[Content_Types].xml';
    final text = _partText(name);
    if (text == null) return;
    final doc = XmlDocument.parse(text);
    final has = doc.rootElement.findElements('Default').any(
        (e) => (e.getAttribute('Extension') ?? '').toLowerCase() == ext);
    if (has) return;
    doc.rootElement.children.insert(
        0,
        XmlElement(XmlName('Default'), [
          XmlAttribute(XmlName('Extension'), ext),
          XmlAttribute(XmlName('ContentType'), mime),
        ]));
    _partEdits[name] = doc.toXmlString();
  }

  /// Paragrafı belgeden ve modelden siler.
  void deleteParagraph(DocxParagraph p) {
    p._element.parent?.children.remove(p._element);
    paragraphs.remove(p);
  }

  /// Paragrafın belgedeki YERİ — silmeyi geri alabilmek için silmeden ÖNCE
  /// alınır. Silinen paragrafı sona eklemek yeterli değil: Word'de paragrafın
  /// yeri anlamının parçası (başlık altındaki madde başka yere düşemez).
  DocxParagraphSlot slotOf(DocxParagraph p) {
    final parent = p._element.parent;
    return DocxParagraphSlot(
      parent,
      parent == null ? -1 : parent.children.indexOf(p._element),
      paragraphs.indexOf(p),
    );
  }

  /// [slotOf] ile alınmış konuma paragrafı geri koyar.
  void restoreParagraph(DocxParagraph p, DocxParagraphSlot slot) {
    final parent = slot.parent;
    if (parent != null &&
        slot.xmlIndex >= 0 &&
        slot.xmlIndex <= parent.children.length) {
      parent.children.insert(slot.xmlIndex, p._element);
    }
    final at = slot.modelIndex;
    paragraphs.insert(
        at < 0 || at > paragraphs.length ? paragraphs.length : at, p);
  }

  /// Değişen paragrafları geri yazıp yeni .docx byte'larını üretir.
  /// El değmeyen paragraflar (metin + biçim aynı) hiç dokunulmadan kalır;
  /// setRuns ile yazılmış (rich) paragraflar da atlanır.
  Archive buildArchive() {
    for (final para in paragraphs) {
      if (!para.rich) {
        if (para._textChanged) _writeText(para);
        if (para._biuChanged) _applyRunFormat(para);
      } else {
        // rich: çalıştırmalar setRuns ile zaten yazıldı; yalnız o yazımdan
        // sonra (yedek editörde) değişen metin/biçim yeniden yazılır.
        if (para._richTextChanged) _writeText(para);
        if (para._richBiuChanged) _applyRunFormat(para);
      }
      // Hizalama pPr'de durur; rich paragrafta da ayrıca uygulanmalı
      // (canlı görünümdeki hizalama düğmesi buradan kalıcılaşır).
      if (para._alignChanged) _applyAlign(para);
    }

    // Liste kullanıldıysa numaralandırma tanımı, içerik türü ve ilişki de
    // yazılır (dosyada hiç yoksa üretilir).
    final extra = _numberingParts();

    final newXml = _doc.toXmlString();
    final out = Archive();
    final written = <String>{};
    void put(String name, String text) {
      final data = utf8.encode(text);
      out.addFile(ArchiveFile(name, data.length, data));
      written.add(name);
    }

    // Resim işlerinin değiştirdiği parçalar; numaralandırma aynı parçayı
    // (ilişkiler / içerik türleri) değiştirdiyse onun sürümü zaten bunların
    // üstüne kuruldu (`_partText` önce `_partEdits`e bakar).
    final parts = {..._partEdits, ...extra};
    for (final f in _archive.files) {
      if (f.name == 'word/document.xml') {
        put(f.name, newXml);
      } else if (parts.containsKey(f.name)) {
        put(f.name, parts[f.name]!);
      } else {
        out.addFile(f);
      }
    }
    // Dosyada hiç bulunmayan parçalar (ör. numbering.xml yoksa) sona eklenir.
    parts.forEach((name, text) {
      if (!written.contains(name)) put(name, text);
    });
    _newMedia.forEach((name, data) {
      out.addFile(ArchiveFile(name, data.length, data));
    });

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

  // ── madde işareti / numaralandırma ─────────────────────────────────────

  /// Bu oturumda kullanılan liste türleri. Boşsa hiçbir parça yazılmaz —
  /// liste vermeyen bir kaydetme dosyanın hiçbir baytını fazladan değiştirmez.
  final _usedLists = <String>{};

  /// Uygulamanın ürettiği numaralandırma kimlikleri. Belgede zaten kullanılan
  /// kimliklerle çakışmaması için yüksek ve sabit seçildi; `w:abstractNumId`
  /// ile aynı numarayı kullanmak Word'de sorun değil.
  static const _numIdBullet = 9101;
  static const _numIdNumber = 9102;

  /// Paragrafa madde işareti / numaralandırma verir.
  /// [kind]: `bullet` | `number` | `none`.
  void setListStyle(int index, String kind) {
    if (index < 0 || index >= paragraphs.length) return;
    final el = paragraphs[index]._element;
    final pPr = _ensurePPr(el);
    _removeElems(pPr, (e) => e.name.qualified == 'w:numPr');
    if (kind == 'none') return;

    final numId = kind == 'number' ? _numIdNumber : _numIdBullet;
    _usedLists.add(kind);
    final numPr = XmlElement(XmlName('w:numPr'), [], [
      XmlElement(XmlName('w:ilvl'))..setAttribute('w:val', '0'),
      XmlElement(XmlName('w:numId'))..setAttribute('w:val', '$numId'),
    ]);
    // CT_PPr sırasında `w:numPr`, `w:pStyle`den hemen sonra gelir.
    final style = _firstOrNull(pPr.findElements('w:pStyle'));
    final at = style == null ? 0 : pPr.children.indexOf(style) + 1;
    pPr.children.insert(at, numPr);
  }

  /// Liste kullanıldıysa güncellenmesi/eklenmesi gereken zip parçaları.
  ///
  /// Word'de madde işareti paragrafın kendisinde DEĞİL, `numbering.xml`deki
  /// bir tanımda durur; paragraf yalnız `w:numId` ile ona işaret eder. Bu
  /// yüzden liste vermek üç dosyaya dokunmayı gerektiriyor: tanımın kendisi,
  /// `[Content_Types].xml` (parçanın türü) ve `document.xml.rels` (belgenin
  /// tanıma bağlanması). Üçünden biri eksikse Word dosyayı "onarılamaz" sayar.
  Map<String, String> _numberingParts() {
    if (_usedLists.isEmpty) return const {};
    final out = <String, String>{};

    final existing = _partText('word/numbering.xml');
    final doc = existing == null
        ? XmlDocument.parse(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<w:numbering xmlns:w="http://schemas.openxmlformats.org/'
            'wordprocessingml/2006/main"/>')
        : XmlDocument.parse(existing);
    final root = doc.rootElement;

    for (final kind in _usedLists) {
      final numId = kind == 'number' ? _numIdNumber : _numIdBullet;
      // Aynı kimlik zaten varsa (ikinci kaydetme) yeniden eklenmez.
      final has = root
          .findElements('w:num')
          .any((e) => e.getAttribute('w:numId') == '$numId');
      if (has) continue;
      // `w:abstractNum` HEPSİNDEN ÖNCE, `w:num` ondan sonra gelmeli.
      root.children.insert(0, _abstractNum(numId, kind));
      root.children.add(XmlElement(XmlName('w:num'), [
        XmlAttribute(XmlName('w:numId'), '$numId'),
      ], [
        XmlElement(XmlName('w:abstractNumId'))..setAttribute('w:val', '$numId'),
      ]));
    }
    out['word/numbering.xml'] = doc.toXmlString();

    final types = _withNumberingContentType();
    if (types != null) out['[Content_Types].xml'] = types;
    final rels = _withNumberingRel();
    if (rels != null) out['word/_rels/document.xml.rels'] = rels;
    return out;
  }

  static XmlElement _abstractNum(int id, String kind) {
    final bullet = kind != 'number';
    return XmlElement(XmlName('w:abstractNum'), [
      XmlAttribute(XmlName('w:abstractNumId'), '$id'),
    ], [
      XmlElement(XmlName('w:multiLevelType'))
        ..setAttribute('w:val', 'hybridMultilevel'),
      XmlElement(XmlName('w:lvl'), [
        XmlAttribute(XmlName('w:ilvl'), '0'),
      ], [
        XmlElement(XmlName('w:start'))..setAttribute('w:val', '1'),
        XmlElement(XmlName('w:numFmt'))
          ..setAttribute('w:val', bullet ? 'bullet' : 'decimal'),
        XmlElement(XmlName('w:lvlText'))
          ..setAttribute('w:val', bullet ? '•' : '%1.'),
        XmlElement(XmlName('w:lvlJc'))..setAttribute('w:val', 'left'),
        XmlElement(XmlName('w:pPr'), [], [
          XmlElement(XmlName('w:ind'))
            ..setAttribute('w:left', '720')
            ..setAttribute('w:hanging', '360'),
        ]),
        if (bullet)
          XmlElement(XmlName('w:rPr'), [], [
            XmlElement(XmlName('w:rFonts'))
              ..setAttribute('w:ascii', 'Symbol')
              ..setAttribute('w:hAnsi', 'Symbol')
              ..setAttribute('w:hint', 'default'),
          ]),
      ]),
    ]);
  }

  /// `[Content_Types].xml`e numbering parçasının türünü ekler (varsa null).
  String? _withNumberingContentType() {
    const type = 'application/vnd.openxmlformats-officedocument.'
        'wordprocessingml.numbering+xml';
    final text = _partText('[Content_Types].xml');
    if (text == null) return null;
    final doc = XmlDocument.parse(text);
    final has = doc.rootElement.findElements('Override').any(
        (e) => e.getAttribute('PartName') == '/word/numbering.xml');
    if (has) return null;
    doc.rootElement.children.add(XmlElement(XmlName('Override'), [
      XmlAttribute(XmlName('PartName'), '/word/numbering.xml'),
      XmlAttribute(XmlName('ContentType'), type),
    ]));
    return doc.toXmlString();
  }

  /// `document.xml.rels`e numbering ilişkisini ekler (varsa null).
  String? _withNumberingRel() {
    const relType = 'http://schemas.openxmlformats.org/officeDocument/2006/'
        'relationships/numbering';
    final text = _partText('word/_rels/document.xml.rels');
    if (text == null) return null;
    final doc = XmlDocument.parse(text);
    final rels = doc.rootElement.findElements('Relationship').toList();
    if (rels.any((e) => e.getAttribute('Type') == relType)) return null;
    // Kullanılmayan bir rId bulunur (rId1, rId2… sırası dosyaya göre değişir).
    var n = rels.length + 1;
    final used = rels.map((e) => e.getAttribute('Id')).toSet();
    while (used.contains('rId$n')) {
      n++;
    }
    doc.rootElement.children.add(XmlElement(XmlName('Relationship'), [
      XmlAttribute(XmlName('Id'), 'rId$n'),
      XmlAttribute(XmlName('Type'), relType),
      XmlAttribute(XmlName('Target'), 'numbering.xml'),
    ]));
    return doc.toXmlString();
  }

  String? _partText(String name) {
    final edited = _partEdits[name];
    if (edited != null) return edited;
    for (final f in _archive.files) {
      if (f.name != name) continue;
      return utf8.decode(f.content as List<int>, allowMalformed: true);
    }
    return null;
  }

  void _writeText(DocxParagraph para) {
    final tNodes = para._element.findAllElements('w:t').toList();
    if (tNodes.isEmpty) {
      final runs = para._element.findElements('w:r').toList();
      final XmlElement run =
          runs.isNotEmpty ? runs.first : _appendRun(para._element);
      final t = XmlElement(XmlName('w:t'));
      t.setAttribute('xml:space', 'preserve');
      t.children.add(XmlText(para.text));
      run.children.add(t);
    } else {
      tNodes.first
        ..setAttribute('xml:space', 'preserve')
        ..children.clear();
      tNodes.first.children.add(XmlText(para.text));
      for (final extra in tNodes.skip(1)) {
        extra.children.clear();
      }
    }
  }

  /// Kalın/italik/altı çizili bayraklarını paragraftaki her çalıştırmaya uygular.
  void _applyRunFormat(DocxParagraph para) {
    for (final run in para._element.findAllElements('w:r')) {
      final rPr = _ensureRPr(run);
      _setToggle(rPr, 'w:b', para.bold);
      _setToggle(rPr, 'w:i', para.italic);
      _setUnderline(rPr, para.underline);
    }
  }

  /// Hizalamayı paragraf özelliklerine (`<w:pPr>/<w:jc>`) uygular.
  void _applyAlign(DocxParagraph para) {
    if (para.align != 'left' || para._hadJc) {
      final pPr = _ensurePPr(para._element);
      _setJc(pPr, para.align);
    } else {
      // 'left' + açık jc yoktu → varsa (arada eklendiyse) düğümü kaldır.
      final pPr = _firstOrNull(para._element.findElements('w:pPr'));
      if (pPr != null) _removeElems(pPr, (e) => e.name.qualified == 'w:jc');
    }
  }

  /// Çalıştırmanın `<w:rPr>` düğümünü döndürür; yoksa ilk çocuk olarak oluşturur
  /// (şema gereği rPr, `<w:t>`'den önce gelmeli).
  XmlElement _ensureRPr(XmlElement run) {
    final existing = _firstOrNull(run.findElements('w:rPr'));
    if (existing != null) return existing;
    final rPr = XmlElement(XmlName('w:rPr'));
    run.children.insert(0, rPr);
    return rPr;
  }

  XmlElement _ensurePPr(XmlElement p) {
    final existing = _firstOrNull(p.findElements('w:pPr'));
    if (existing != null) return existing;
    final pPr = XmlElement(XmlName('w:pPr'));
    p.children.insert(0, pPr); // pPr, paragrafın ilk çocuğu olmalı
    return pPr;
  }

  void _setToggle(XmlElement rPr, String name, bool on) {
    _removeElems(rPr, (e) => e.name.qualified == name);
    if (on) _putOrdered(rPr, XmlElement(XmlName(name)));
  }

  /// `w:rPr` çocuklarının şema sırası (CT_RPr). Word sıra dışı öğeyi
  /// "dosya bozuk" sayabildiği için yeni öğe DAİMA yerine konur.
  static const _rPrOrder = [
    'w:rStyle', 'w:rFonts', 'w:b', 'w:bCs', 'w:i', 'w:iCs', 'w:caps',
    'w:smallCaps', 'w:strike', 'w:dstrike', 'w:outline', 'w:shadow',
    'w:emboss', 'w:imprint', 'w:noProof', 'w:snapToGrid', 'w:vanish',
    'w:webHidden', 'w:color', 'w:spacing', 'w:w', 'w:kern', 'w:position',
    'w:sz', 'w:szCs', 'w:highlight', 'w:u', 'w:effect', 'w:bdr', 'w:shd',
    'w:fitText', 'w:vertAlign', 'w:rtl', 'w:cs', 'w:em', 'w:lang',
    'w:eastAsianLayout', 'w:specVanish', 'w:oMath',
  ];

  static void _putOrdered(XmlElement rPr, XmlElement el) {
    final rank = _rPrOrder.indexOf(el.name.qualified);
    if (rank < 0) {
      rPr.children.add(el);
      return;
    }
    var at = rPr.children.length;
    for (var k = 0; k < rPr.children.length; k++) {
      final c = rPr.children[k];
      if (c is! XmlElement) continue;
      final r = _rPrOrder.indexOf(c.name.qualified);
      if (r > rank || r < 0 && c.name.qualified == 'w:rPrChange') {
        at = k;
        break;
      }
    }
    rPr.children.insert(at, el);
  }

  /// Yazı tipi ailesi. Word dört ayrı alan tutar (ascii / hAnsi / cs / eastAsia);
  /// üçünü birden yazmak şart: yalnız `w:ascii` yazılsa Latin olmayan harfler
  /// (Türkçe'de sorun yok ama Arapça/Yunanca'da var) eski fontta kalırdı.
  void _setFont(XmlElement rPr, String font) {
    _removeElems(rPr, (e) => e.name.qualified == 'w:rFonts');
    final el = XmlElement(XmlName('w:rFonts'))
      ..setAttribute('w:ascii', font)
      ..setAttribute('w:hAnsi', font)
      ..setAttribute('w:cs', font);
    // CT_RPr sırası: rStyle → rFonts → b → i → …
    _putOrdered(rPr, el);
  }

  /// Punto. Dosyada **yarım punto** cinsindendir (12 pt → `w:sz w:val="24"`).
  /// `w:szCs` (karmaşık yazı) da yazılır, yoksa Arapça metin eski boyutta kalır.
  void _setSize(XmlElement rPr, double pt) {
    final half = (pt.clamp(1.0, 409.0) * 2).round();
    _removeElems(rPr,
        (e) => e.name.qualified == 'w:sz' || e.name.qualified == 'w:szCs');
    _putOrdered(rPr, XmlElement(XmlName('w:sz'))..setAttribute('w:val', '$half'));
    _putOrdered(
        rPr, XmlElement(XmlName('w:szCs'))..setAttribute('w:val', '$half'));
  }

  void _setUnderline(XmlElement rPr, bool on) {
    _removeElems(rPr, (e) => e.name.qualified == 'w:u');
    if (on) {
      final u = XmlElement(XmlName('w:u'))..setAttribute('w:val', 'single');
      _putOrdered(rPr, u);
    }
  }

  /// Yazı rengi (`w:color w:val="RRGGBB"`). `auto` da geçerli bir değerdir —
  /// "otomatik" (temadan gelen) renk demektir.
  void _setColor(XmlElement rPr, String hex) {
    _removeElems(rPr, (e) => e.name.qualified == 'w:color');
    _putOrdered(rPr,
        XmlElement(XmlName('w:color'))..setAttribute('w:val', hex.toUpperCase()));
  }

  /// Word'ün **adlandırılmış** vurgu paleti. `w:highlight` yalnız bu adları
  /// kabul eder; keyfi bir renk verilirse Word dosyayı bozuk sayar.
  static const _highlightNames = <String, String>{
    'FFFF00': 'yellow',
    '00FF00': 'green',
    '00FFFF': 'cyan',
    'FF00FF': 'magenta',
    'FF0000': 'red',
    '0000FF': 'blue',
    'C0C0C0': 'lightGray',
    '808080': 'darkGray',
    '008000': 'darkGreen',
    '800000': 'darkRed',
    '000080': 'darkBlue',
    '808000': 'darkYellow',
    'FFFFFF': 'white',
    '000000': 'black',
  };

  /// Vurgu. Palette karşılığı varsa `w:highlight` (Word'ün fosforlu kalemi,
  /// arayüzde "Vurgu rengi" olarak görünür), yoksa `w:shd` gölgelendirmesi —
  /// ikisi de Word'de aynı görünür ama `w:shd` keyfi rengi taşıyabilir.
  void _setHighlight(XmlElement rPr, String hex) {
    _removeElems(rPr,
        (e) => e.name.qualified == 'w:highlight' || e.name.qualified == 'w:shd');
    final upper = hex.toUpperCase();
    final named = _highlightNames[upper];
    if (named != null) {
      _putOrdered(rPr,
          XmlElement(XmlName('w:highlight'))..setAttribute('w:val', named));
      return;
    }
    _putOrdered(rPr, XmlElement(XmlName('w:shd'))
      ..setAttribute('w:val', 'clear')
      ..setAttribute('w:color', 'auto')
      ..setAttribute('w:fill', upper));
  }

  void _setJc(XmlElement pPr, String align) {
    _removeElems(pPr, (e) => e.name.qualified == 'w:jc');
    final jc = XmlElement(XmlName('w:jc'))..setAttribute('w:val', align);
    pPr.children.add(jc);
  }

  /// Eşleşen çocuk elemanları tek tek siler
  /// (removeWhere'in üst-düğüm çakışması riski olmadan).
  static void _removeElems(XmlElement parent, bool Function(XmlElement) test) {
    final gone =
        parent.children.whereType<XmlElement>().where(test).toList();
    for (final e in gone) {
      parent.children.remove(e);
    }
  }

  XmlElement _appendRun(XmlElement paragraph) {
    final run = XmlElement(XmlName('w:r'));
    paragraph.children.add(run);
    return run;
  }
}
