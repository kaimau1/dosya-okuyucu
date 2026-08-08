import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Tek slaytın içeriği: bir başlık, madde listesi ve konuşmacı notu.
class SlideDraft {
  final String title;
  final List<String> bullets;

  /// Konuşmacı notu (sunum modunda görünür, slaytta değil). Boşsa slayt için
  /// `notesSlide` parçası hiç yazılmaz — boş bir not parçası paketi
  /// gereksiz büyütür.
  final String notes;

  const SlideDraft(this.title, this.bullets, {this.notes = ''});
}

/// **Sıfırdan geçerli .pptx üretir** (PDF/metin → düzenlenebilir sunum).
///
/// **Neden gerçek .pptx, neden "slayt görünümlü PDF" değil:** elde zaten
/// `textToSlidesPdf` vardı ve çıktısı PDF'ti — yani kullanıcı sonucu
/// düzenleyemiyordu. "PDF'ten slayta" isteğinin karşılığı düzenlenebilir bir
/// sunumdur; üretilen dosya hem bizim slayt düzenleyicimizde hem PowerPoint /
/// Google Slaytlar'da açılır.
///
/// **Neden elle XML, neden bir paket değil:** pub'da bakımlı bir PPTX YAZICI
/// yok (`pptx` paketleri okumaya odaklı ya da terk edilmiş). Paket, tema ve
/// yerleşim parçalarıyla birlikte ~7 küçük XML dosyasıdır; elle yazmak hem
/// bağımlılık eklemiyor hem çıktının içine tam olarak ne koyduğumuzu bilmemizi
/// sağlıyor.
///
/// **TUZAK — PowerPoint ilişkilerde katıdır.** Eksik bir `slideLayout` ya da
/// `theme` ilişkisi dosyayı "onarılması gerekiyor" uyarısıyla açtırır; bu
/// yüzden master → layout → slide zinciri ve tema eksiksiz yazılıyor. Kendi
/// okuyucumuzun daha hoşgörülü olması yeterli DEĞİL: dosya dışarıda da açılmalı.
class PptxWriter {
  /// 16:9 slayt (13.333in × 7.5in), PowerPoint'in kendi varsayılanı.
  /// EMU = punto × 12700; yani 960 × 540 punto.
  static const _slideW = 12192000;
  static const _slideH = 6858000;

  /// Başlık ve gövde kutularının yeri — PowerPoint'in 16:9 varsayılanlarıyla
  /// aynı. Yerleşimden MİRAS almak yerine her şekle açıkça yazılıyor: miras
  /// zinciri okuyucuya göre farklı yorumlanabiliyor, açık `a:xfrm` ise her
  /// yerde aynı sonucu veriyor.
  static const _titleX = 838200, _titleY = 365125;
  static const _titleW = 10515600, _titleH = 1325563;
  static const _bodyX = 838200, _bodyY = 1825625;
  static const _bodyW = 10515600, _bodyH = 4351338;

  /// [slides] boşsa tek boş slayt üretilir — sıfır slaytlı bir sunum
  /// PowerPoint'te geçersizdir.
  static Uint8List build(List<SlideDraft> slides) {
    final list = slides.isEmpty ? const [SlideDraft('', [])] : slides;

    final noteIndexes = <int>[
      for (var i = 0; i < list.length; i++)
        if (list[i].notes.trim().isNotEmpty) i + 1,
    ];

    final files = <String, String>{
      '[Content_Types].xml': _contentTypes(list.length, noteIndexes),
      '_rels/.rels': _rootRels,
      'ppt/presentation.xml': _presentation(list.length, noteIndexes.isNotEmpty),
      'ppt/_rels/presentation.xml.rels':
          _presentationRels(list.length, noteIndexes.isNotEmpty),
      'ppt/theme/theme1.xml': _theme,
      'ppt/slideMasters/slideMaster1.xml': _slideMaster,
      'ppt/slideMasters/_rels/slideMaster1.xml.rels': _slideMasterRels,
      'ppt/slideLayouts/slideLayout1.xml': _slideLayout,
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels': _slideLayoutRels,
    };
    if (noteIndexes.isNotEmpty) {
      files['ppt/notesMasters/notesMaster1.xml'] = _notesMaster;
      files['ppt/notesMasters/_rels/notesMaster1.xml.rels'] = _notesMasterRels;
    }

    for (var i = 0; i < list.length; i++) {
      final n = i + 1;
      final notes = list[i].notes.trim();
      files['ppt/slides/slide$n.xml'] = _slide(list[i]);
      files['ppt/slides/_rels/slide$n.xml.rels'] = _slideRels(notes.isEmpty ? null : n);
      if (notes.isNotEmpty) {
        files['ppt/notesSlides/notesSlide$n.xml'] = _notesSlide(notes);
        files['ppt/notesSlides/_rels/notesSlide$n.xml.rels'] = _notesSlideRels(n);
      }
    }
    return _zip(files);
  }

  // ── Paket iskeleti ────────────────────────────────────────────────────────

  static String _contentTypes(int count, List<int> noteIndexes) {
    final buf = StringBuffer(
      '$_xmlHead'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
      '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>'
      '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
      '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    );
    for (var i = 1; i <= count; i++) {
      buf.write('<Override PartName="/ppt/slides/slide$i.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    if (noteIndexes.isNotEmpty) {
      buf.write('<Override PartName="/ppt/notesMasters/notesMaster1.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"/>');
      for (final i in noteIndexes) {
        buf.write('<Override PartName="/ppt/notesSlides/notesSlide$i.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>');
      }
    }
    buf.write('</Types>');
    return buf.toString();
  }

  static const _rootRels = '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
      '</Relationships>';

  /// Slayt kimlikleri 256'dan başlar: ECMA-376 `p:sldId@id` için 256 alt
  /// sınırdır, daha küçük değer dosyayı geçersiz yapar.
  static String _presentation(int count, bool hasNotes) {
    final ids = StringBuffer();
    for (var i = 1; i <= count; i++) {
      ids.write('<p:sldId id="${255 + i}" r:id="rId${i + 1}"/>');
    }
    // ECMA-376 eleman SIRASI bağlayıcıdır: sldMasterIdLst → notesMasterIdLst
    // → sldIdLst → sldSz → notesSz. Sıra bozulursa dosya geçersiz olur.
    final notesMaster = hasNotes
        ? '<p:notesMasterIdLst><p:notesMasterId r:id="rId${count + 3}"/></p:notesMasterIdLst>'
        : '';
    return '$_xmlHead'
        '<p:presentation xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs">'
        '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
        '$notesMaster'
        '<p:sldIdLst>$ids</p:sldIdLst>'
        '<p:sldSz cx="$_slideW" cy="$_slideH"/>'
        '<p:notesSz cx="$_slideH" cy="$_slideW"/>'
        '</p:presentation>';
  }

  static String _presentationRels(int count, bool hasNotes) {
    final buf = StringBuffer(
      '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
    );
    for (var i = 1; i <= count; i++) {
      buf.write('<Relationship Id="rId${i + 1}" Type="$_relNs/slide" '
          'Target="slides/slide$i.xml"/>');
    }
    // Tema ilişkisi slaytlardan SONRA numaralanıyor; PowerPoint sıraya değil
    // Id'ye bakar ama çakışan bir Id dosyayı bozar.
    buf.write('<Relationship Id="rId${count + 2}" Type="$_relNs/theme" '
        'Target="theme/theme1.xml"/>');
    if (hasNotes) {
      // Id, `_presentation`daki `notesMasterId r:id` ile BİREBİR aynı olmalı.
      buf.write('<Relationship Id="rId${count + 3}" Type="$_relNs/notesMaster" '
          'Target="notesMasters/notesMaster1.xml"/>');
    }
    buf.write('</Relationships>');
    return buf.toString();
  }

  static const _slideMasterRels = '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
      '<Relationship Id="rId2" Type="$_relNs/theme" Target="../theme/theme1.xml"/>'
      '</Relationships>';

  static const _slideLayoutRels = '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/slideMaster" Target="../slideMasters/slideMaster1.xml"/>'
      '</Relationships>';

  /// [notesIndex] doluysa slayt kendi `notesSlide`ına da bağlanır.
  static String _slideRels(int? notesIndex) => '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
      '${notesIndex == null ? '' : '<Relationship Id="rId2" Type="$_relNs/notesSlide" Target="../notesSlides/notesSlide$notesIndex.xml"/>'}'
      '</Relationships>';

  static String _notesSlideRels(int index) => '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/notesMaster" Target="../notesMasters/notesMaster1.xml"/>'
      '<Relationship Id="rId2" Type="$_relNs/slide" Target="../slides/slide$index.xml"/>'
      '</Relationships>';

  static const _notesMasterRels = '$_xmlHead'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_relNs/theme" Target="../theme/theme1.xml"/>'
      '</Relationships>';

  /// Konuşmacı notu parçası. Kutu `type="body"` yer tutucusudur — hem
  /// PowerPoint hem bizim `PptxRender.notes` okuyucumuz notu orada arar.
  static String _notesSlide(String notes) {
    final paragraphs = StringBuffer();
    for (final line in notes.split('\n')) {
      paragraphs.write('<a:p><a:r><a:rPr lang="tr-TR" dirty="0"/>'
          '<a:t>${_esc(line)}</a:t></a:r></a:p>');
    }
    return '$_xmlHead'
        '<p:notes xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs">'
        '<p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '<p:sp>'
        '<p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 1"/>'
        '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>'
        '<p:spPr><a:xfrm><a:off x="685800" y="4343400"/>'
        '<a:ext cx="5486400" cy="4114800"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        '<p:txBody><a:bodyPr/><a:lstStyle/>$paragraphs</p:txBody>'
        '</p:sp>'
        '</p:spTree></p:cSld>'
        '</p:notes>';
  }

  static const _notesMaster = '$_xmlHead'
      '<p:notesMaster xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs">'
      '<p:cSld><p:spTree>'
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
      '</p:spTree></p:cSld>'
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
      'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
      'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
      '</p:notesMaster>';

  // ── Slayt ─────────────────────────────────────────────────────────────────

  static String _slide(SlideDraft draft) {
    final shapes = StringBuffer();
    shapes.write(_textShape(
      id: 2,
      name: 'Title 1',
      phType: ' type="title"',
      x: _titleX,
      y: _titleY,
      w: _titleW,
      h: _titleH,
      paragraphs: [draft.title],
      sizeHundredths: 4400,
      bold: true,
      bullet: false,
    ));
    if (draft.bullets.isNotEmpty) {
      shapes.write(_textShape(
        id: 3,
        name: 'Content 2',
        phType: ' type="body" idx="1"',
        x: _bodyX,
        y: _bodyY,
        w: _bodyW,
        h: _bodyH,
        paragraphs: draft.bullets,
        sizeHundredths: 2000,
        bold: false,
        bullet: true,
      ));
    }
    return '$_xmlHead'
        '<p:sld xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs">'
        '<p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '$shapes'
        '</p:spTree></p:cSld>'
        '<p:clrMapOvr><a:overrideClrMapping bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" '
        'accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" '
        'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/></p:clrMapOvr>'
        '</p:sld>';
  }

  static String _textShape({
    required int id,
    required String name,
    required String phType,
    required int x,
    required int y,
    required int w,
    required int h,
    required List<String> paragraphs,
    required int sizeHundredths,
    required bool bold,
    required bool bullet,
  }) {
    final body = StringBuffer();
    for (final text in paragraphs) {
      // Madde imi AÇIKÇA yazılıyor/kapatılıyor: yerleşimden miras alınsaydı
      // başlık kutusunda da madde imi çıkardı (PowerPoint'in gövde varsayılanı).
      final props = bullet
          ? '<a:pPr marL="285750" indent="-285750"><a:buChar char="•"/></a:pPr>'
          : '<a:pPr><a:buNone/></a:pPr>';
      body.write('<a:p>$props<a:r>'
          '<a:rPr lang="tr-TR" sz="$sizeHundredths"${bold ? ' b="1"' : ''} dirty="0"/>'
          '<a:t>${_esc(text)}</a:t>'
          '</a:r></a:p>');
    }
    return '<p:sp>'
        '<p:nvSpPr>'
        '<p:cNvPr id="$id" name="${_esc(name)}"/>'
        '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr><p:ph$phType/></p:nvPr>'
        '</p:nvSpPr>'
        '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$h"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        '<p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>'
        '$body'
        '</p:txBody>'
        '</p:sp>';
  }

  // ── Yerleşim / master / tema ──────────────────────────────────────────────

  static const _slideLayout = '$_xmlHead'
      '<p:sldLayout xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs" type="obj" preserve="1">'
      '<p:cSld name="Title and Content"><p:spTree>'
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
      '</p:spTree></p:cSld>'
      '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
      '</p:sldLayout>';

  static const _slideMaster = '$_xmlHead'
      '<p:sldMaster xmlns:a="$_aNs" xmlns:r="$_rNs" xmlns:p="$_pNs">'
      '<p:cSld><p:bg><p:bgPr><a:solidFill><a:schemeClr val="bg1"/></a:solidFill>'
      '<a:effectLst/></p:bgPr></p:bg>'
      '<p:spTree>'
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
      '</p:spTree></p:cSld>'
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
      'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
      'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
      '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
      '</p:sldMaster>';

  /// Tema: `clrScheme` + `fontScheme` + `fmtScheme`. Üçü de zorunlu ve
  /// `fmtScheme` içindeki listeler SABİT sayıda öğe ister (3 dolgu, 3 çizgi,
  /// 3 efekt, 3 arka plan) — eksik öğe PowerPoint'te onarım uyarısı çıkarır.
  static const _theme = '$_xmlHead'
      '<a:theme xmlns:a="$_aNs" name="Dosya Okuyucu">'
      '<a:themeElements>'
      '<a:clrScheme name="Office">'
      '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
      '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
      '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
      '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
      '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
      '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
      '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
      '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
      '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
      '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
      '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
      '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
      '</a:clrScheme>'
      '<a:fontScheme name="Office">'
      '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
      '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
      '</a:fontScheme>'
      '<a:fmtScheme name="Office">'
      '<a:fillStyleLst>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '</a:fillStyleLst>'
      '<a:lnStyleLst>'
      '<a:ln w="6350" cap="flat"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
      '<a:ln w="12700" cap="flat"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
      '<a:ln w="19050" cap="flat"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
      '</a:lnStyleLst>'
      '<a:effectStyleLst>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '</a:effectStyleLst>'
      '<a:bgFillStyleLst>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '</a:bgFillStyleLst>'
      '</a:fmtScheme>'
      '</a:themeElements>'
      '</a:theme>';

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  static const _xmlHead =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  static const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _rNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _pNs =
      'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const _relNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// XML kaçışı. `&` ÖNCE gelmeli, yoksa sonraki kaçışların `&`'i yeniden
  /// kaçırılır (`&lt;` → `&amp;lt;`).
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // XML 1.0'da yasak denetim karakterleri: PDF metninden gelebiliyor ve
      // dosyayı açılamaz hâle getirirdi.
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static Uint8List _zip(Map<String, String> files) {
    final archive = Archive();
    files.forEach((name, content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    });
    final out = ZipEncoder().encode(archive);
    return Uint8List.fromList(out ?? const <int>[]);
  }
}
