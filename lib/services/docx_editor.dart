import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Canlı düzenlemeden gelen tek biçimli metin parçası.
typedef RunSeg = (String text, bool bold, bool italic, bool underline);

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

  /// Ayrıştırırken paragrafın açık bir hizalaması (`<w:jc>`) var mıydı — 'left'
  /// varsayılanına dönerken gereksiz düğüm eklememek için.
  final bool _hadJc;
  final XmlElement _element;

  /// true ise çalıştırmalar [DocxEditor.setRuns] ile XML'e zaten yazıldı;
  /// [DocxEditor.save] bu paragrafa bir daha dokunmaz.
  bool rich = false;

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
    bool hadJc = false,
  })  : _hadJc = hadJc,
        _text0 = text,
        _bold0 = bold,
        _italic0 = italic,
        _underline0 = underline,
        _align0 = align;

  bool get _textChanged => text != _text0;
  bool get _formatChanged =>
      bold != _bold0 ||
      italic != _italic0 ||
      underline != _underline0 ||
      align != _align0;
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

  static DocxEditor parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException('document.xml bulunamadı'),
    );
    final xml = XmlDocument.parse(
      utf8.decode(docFile.content as List<int>, allowMalformed: true),
    );

    final paras = <DocxParagraph>[];
    for (final p in xml.findAllElements('w:p')) {
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
      paras.add(DocxParagraph(
        text,
        isHeading,
        level,
        p,
        bold: rPr != null && _rprHas(rPr, 'w:b'),
        italic: rPr != null && _rprHas(rPr, 'w:i'),
        underline: rPr != null && _rprHas(rPr, 'w:u'),
        align: _normalizeAlign(jc?.getAttribute('w:val')),
        hadJc: jc != null,
      ));
    }
    return DocxEditor._(archive, xml, paras);
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

  /// Canlı düzenlemeden gelen paragrafı zengin (B/I/U) çalıştırmalar olarak
  /// XML'e yazar. İlk run'ın `w:rPr`'i şablon alınır → font/boyut/renk korunur;
  /// kalın/italik/altçizgi her segmente göre ayarlanır. Paragraf stilleri (pPr)
  /// yerinde kalır. Köprü/işaretçi gibi run-dışı içerik sadeleşir (ORTA sadakat).
  void setRuns(int index, List<RunSeg> segs) {
    if (index < 0 || index >= paragraphs.length) return;
    final para = paragraphs[index];
    final el = para._element;

    XmlElement? templateRPr;
    for (final r in el.findAllElements('w:r')) {
      final rPr = r.findElements('w:rPr').toList();
      if (rPr.isNotEmpty) templateRPr = rPr.first;
      break; // şablon = İLK run'ın biçimi (varsa)
    }

    el.children.removeWhere(
        (n) => !(n is XmlElement && n.name.qualified == 'w:pPr'));

    for (final (text, bold, italic, underline) in segs) {
      if (text.isEmpty) continue;
      final run = XmlElement(XmlName('w:r'));
      final rPr = templateRPr == null
          ? XmlElement(XmlName('w:rPr'))
          : (templateRPr.copy());
      _setToggle(rPr, 'w:b', bold);
      _setToggle(rPr, 'w:i', italic);
      _setUnderline(rPr, underline);
      run.children.add(rPr);
      // '\n' canlı düzenlemedeki satır sonudur (Enter → <br>) → w:br yazılır.
      final parts = text.split('\n');
      for (var k = 0; k < parts.length; k++) {
        if (k > 0) run.children.add(XmlElement(XmlName('w:br')));
        if (parts[k].isEmpty) continue;
        final t = XmlElement(XmlName('w:t'));
        t.setAttribute('xml:space', 'preserve');
        t.children.add(XmlText(parts[k]));
        run.children.add(t);
      }
      el.children.add(run);
    }

    para.text = segs.map((s) => s.$1).join();
    para.rich = true;
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

  /// Paragrafı belgeden ve modelden siler.
  void deleteParagraph(DocxParagraph p) {
    p._element.parent?.children.remove(p._element);
    paragraphs.remove(p);
  }

  /// Değişen paragrafları geri yazıp yeni .docx byte'larını üretir.
  /// El değmeyen paragraflar (metin + biçim aynı) hiç dokunulmadan kalır;
  /// setRuns ile yazılmış (rich) paragraflar da atlanır.
  Uint8List save() {
    for (final para in paragraphs) {
      if (para.rich) continue; // çalıştırmalar setRuns ile zaten yazıldı
      if (para._textChanged) _writeText(para);
      if (para._formatChanged) _applyFormat(para);
    }

    final newXml = _doc.toXmlString();
    final out = Archive();
    for (final f in _archive.files) {
      if (f.name == 'word/document.xml') {
        final data = utf8.encode(newXml);
        out.addFile(ArchiveFile(f.name, data.length, data));
      } else {
        out.addFile(f);
      }
    }
    final List<int>? encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded ?? const <int>[]);
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

  /// Kalın/italik/altı çizili bayraklarını paragraftaki her çalıştırmaya,
  /// hizalamayı da paragraf özelliklerine (`<w:pPr>/<w:jc>`) uygular.
  void _applyFormat(DocxParagraph para) {
    for (final run in para._element.findAllElements('w:r')) {
      final rPr = _ensureRPr(run);
      _setToggle(rPr, 'w:b', para.bold);
      _setToggle(rPr, 'w:i', para.italic);
      _setUnderline(rPr, para.underline);
    }
    if (para.align != 'left' || para._hadJc) {
      final pPr = _ensurePPr(para._element);
      _setJc(pPr, para.align);
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
    if (on) rPr.children.insert(0, XmlElement(XmlName(name)));
  }

  void _setUnderline(XmlElement rPr, bool on) {
    _removeElems(rPr, (e) => e.name.qualified == 'w:u');
    if (on) {
      final u = XmlElement(XmlName('w:u'))..setAttribute('w:val', 'single');
      rPr.children.add(u);
    }
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
