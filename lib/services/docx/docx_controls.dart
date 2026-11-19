part of 'docx_document.dart';

/// B9 m.1 — Satır içi içerik denetimleri (`w:sdt`, form alanları).
///
/// Denetim paragrafta tek atomdur ([DocxAtomKind.control]); kabı (`w:sdtPr`:
/// başlık, etiket, kimlik, liste öğeleri, biçim) aynen kalır, doldurulunca
/// yalnız değer değişir: `w:sdtContent`in metni, onay kutusunun
/// `w14:checked`ı, tarihin `w:fullDate`i, yer tutucu işareti. Resim
/// denetimi, galeri (`w:docPartObj` — İçindekiler, sayfa numarası), alıntı,
/// denklem, grup, kilitli ve veri bağlı denetim doldurulmaz (eskisi gibi
/// dokunulmaz ada).

enum DocxControlType { text, checkbox, dropdown, combo, date }

/// Bir form denetiminin okunmuş hâli.
class DocxControl {
  final DocxControlType type;

  /// Denetimin başlığı (`w:alias`), yoksa ''.
  final String title;

  /// Görünen değer; yer tutucu gösteriliyorsa ''.
  final String value;

  /// Yer tutucu metni (değer boşken görünen, "Metin girin" gibi).
  final String placeholder;
  final bool checked;

  /// Açılır liste / birleşik kutu öğeleri: (görünen metin, değer).
  final List<(String, String)> items;
  final DateTime? date;

  /// Çok satırlı düz metin denetimi.
  final bool multiLine;

  const DocxControl({
    required this.type,
    this.title = '',
    this.value = '',
    this.placeholder = '',
    this.checked = false,
    this.items = const [],
    this.date,
    this.multiLine = false,
  });
}

/// Doldurulabilir denetimse okunmuş hâli; değilse null.
DocxControl? _controlOf(XmlElement sdt) {
  final pr = DocxDocument._child(sdt, 'sdtPr');
  final content = DocxDocument._child(sdt, 'sdtContent');
  if (content == null || DocxDocument._sdtLocked(pr)) return null;
  var type = DocxControlType.text;
  XmlElement? spec;
  for (final c in pr?.childElements ?? const <XmlElement>[]) {
    switch (c.name.local) {
      case 'text' || 'richText':
        type = DocxControlType.text;
        spec = c;
      case 'checkbox':
        type = DocxControlType.checkbox;
        spec = c;
      case 'dropDownList':
        type = DocxControlType.dropdown;
        spec = c;
      case 'comboBox':
        type = DocxControlType.combo;
        spec = c;
      case 'date':
        type = DocxControlType.date;
        spec = c;
      case 'picture' ||
            'docPartObj' ||
            'docPartList' ||
            'citation' ||
            'bibliography' ||
            'equation' ||
            'group':
        return null;
    }
  }
  // Satır içi denetim yalnız run'lardan oluşur; iç paragraf/tablo varsa blok.
  if (content.childElements.any((e) => e.name.local == 'p' || e.name.local == 'tbl')) {
    return null;
  }
  final shown = DocxDocument._textOf(content);
  final isPlaceholder =
      pr != null && DocxDocument._child(pr, 'showingPlcHdr') != null;
  final title = DocxDocument._attr(DocxDocument._child(pr, 'alias'), 'val') ?? '';
  switch (type) {
    case DocxControlType.checkbox:
      final v = DocxDocument._attr(DocxDocument._child(spec, 'checked'), 'val');
      return DocxControl(
          type: type, title: title, value: shown, checked: v == '1' || v == 'true');
    case DocxControlType.dropdown || DocxControlType.combo:
      return DocxControl(
        type: type,
        title: title,
        value: isPlaceholder ? '' : shown,
        placeholder: isPlaceholder ? shown : '',
        items: [
          for (final li in spec!.childElements)
            if (li.name.local == 'listItem')
              (
                DocxDocument._attr(li, 'displayText') ??
                    DocxDocument._attr(li, 'value') ??
                    '',
                DocxDocument._attr(li, 'value') ??
                    DocxDocument._attr(li, 'displayText') ??
                    '',
              ),
        ],
      );
    case DocxControlType.date:
      final full = DocxDocument._attr(spec, 'fullDate');
      return DocxControl(
        type: type,
        title: title,
        value: isPlaceholder ? '' : shown,
        placeholder: isPlaceholder ? shown : '',
        date: full == null || isPlaceholder ? null : DateTime.tryParse(full),
      );
    case DocxControlType.text:
      final multi = DocxDocument._attr(spec, 'multiLine');
      return DocxControl(
        type: type,
        title: title,
        value: isPlaceholder ? '' : shown,
        placeholder: isPlaceholder ? shown : '',
        multiLine: multi == '1' || multi == 'true',
      );
  }
}

/// Word tarih biçimi (`w:dateFormat`: d, dd, M, MM, MMM, MMMM, ddd, dddd,
/// yy, yyyy, tırnaklı yazı) — dil Türkçe ya da İngilizce ad.
String docxFormatDate(DateTime d, String format, {String lang = 'tr'}) {
  const trMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz',
    'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  const enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  const trDays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];
  const enDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  final tr = lang.toLowerCase().startsWith('tr');
  final months = tr ? trMonths : enMonths;
  final days = tr ? trDays : enDays;
  String two(int n) => n.toString().padLeft(2, '0');
  final f = format.isEmpty ? 'dd.MM.yyyy' : format;
  return f.replaceAllMapped(
      RegExp(r"yyyy|yy|MMMM|MMM|MM|M|dddd|ddd|dd|d|'[^']*'"), (m) {
    final t = m[0]!;
    switch (t) {
      case 'yyyy':
        return d.year.toString().padLeft(4, '0');
      case 'yy':
        return two(d.year % 100);
      case 'MMMM':
        return months[d.month - 1];
      case 'MMM':
        return months[d.month - 1].substring(0, 3);
      case 'MM':
        return two(d.month);
      case 'M':
        return '${d.month}';
      case 'dddd':
        return days[d.weekday - 1];
      case 'ddd':
        return days[d.weekday - 1].substring(0, 3);
      case 'dd':
        return two(d.day);
      case 'd':
        return '${d.day}';
      default:
        return t.substring(1, t.length - 1);
    }
  });
}

extension DocxControls on DocxDocument {
  /// Atom bir form denetimiyse okunmuş hâli.
  DocxControl? controlOf(DocxAtom? atom) =>
      atom == null || atom.kind != DocxAtomKind.control || atom.nodes.isEmpty
          ? null
          : _controlOf(atom.nodes.first);

  /// [p]'nin [k]. karakterindeki denetimi doldurur: düz metin / liste için
  /// [text], onay kutusu için [checked], tarih için [date]. Kabın kopyası
  /// değişir (özgün düğüm geri al için olduğu gibi kalır); denetim değilse
  /// [p] aynen döner.
  DocxPara fillControl(DocxPara p, int k,
      {String? text, bool? checked, DateTime? date}) {
    if (k < 0 || k >= p.length) return p;
    final atom = p.atoms[k];
    final c = controlOf(atom);
    if (c == null) return p;
    final sdt = atom!.nodes.first.copy();
    final pr = DocxDocument._child(sdt, 'sdtPr');
    final content = DocxDocument._child(sdt, 'sdtContent')!;
    String shown;
    switch (c.type) {
      case DocxControlType.checkbox:
        final on = checked ?? !c.checked;
        final box = DocxDocument._child(pr, 'checkbox')!;
        var mark = DocxDocument._child(box, 'checked');
        if (mark == null) {
          mark = XmlElement(const XmlName.qualified('w14:checked'),
              [XmlAttribute(const XmlName.qualified('w14:val'), '0')]);
          box.children.insert(0, mark);
        }
        _setAttr(mark, 'val', on ? '1' : '0', 'w14:val');
        final state =
            DocxDocument._child(box, on ? 'checkedState' : 'uncheckedState');
        final code = int.tryParse(
                DocxDocument._attr(state, 'val') ?? '', radix: 16) ??
            (on ? 0x2612 : 0x2610);
        shown = String.fromCharCode(code);
        _setContent(content, shown);
      case DocxControlType.date:
        if (date == null) return p;
        final spec = DocxDocument._child(pr, 'date')!;
        final iso =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}'
            '-${date.day.toString().padLeft(2, '0')}T00:00:00Z';
        _setAttr(spec, 'fullDate', iso, 'w:fullDate');
        final fmt = DocxDocument._attr(DocxDocument._child(spec, 'dateFormat'), 'val') ?? '';
        final lang = DocxDocument._attr(DocxDocument._child(spec, 'lid'), 'val') ?? 'tr';
        shown = docxFormatDate(date, fmt, lang: lang);
        _setContent(content, shown);
      case DocxControlType.dropdown || DocxControlType.combo:
        if (text == null) return p;
        shown = text;
        final spec = DocxDocument._child(
            pr, c.type == DocxControlType.dropdown ? 'dropDownList' : 'comboBox')!;
        if (DocxDocument._attr(spec, 'lastValue') != null) {
          final v = c.items.firstWhere((x) => x.$1 == text, orElse: () => (text, text)).$2;
          _setAttr(spec, 'lastValue', v, 'w:lastValue');
        }
        _setContent(content, shown);
      case DocxControlType.text:
        if (text == null) return p;
        shown = c.multiLine ? text : text.replaceAll('\n', ' ');
        _setContent(content, shown);
    }
    // Yer tutucu artık gösterilmiyor.
    final plc = DocxDocument._child(pr, 'showingPlcHdr');
    if (plc != null && shown.isNotEmpty) pr!.children.remove(plc);
    final at = [...p.atoms]..[k] = DocxAtom(DocxAtomKind.control, [sdt], shown);
    return p.copyWith(atoms: at);
  }

  static void _setAttr(XmlElement e, String local, String value, String qualified) {
    for (final a in e.attributes) {
      if (a.name.local == local) {
        a.value = value;
        return;
      }
    }
    e.attributes.add(XmlAttribute(XmlName.qualified(qualified), value));
  }

  /// `w:sdtContent`in metnini [text] yapar. Tek run + tek `w:t` ise yalnız o
  /// yazı değişir (XML farkı = değer); değilse içerik, ilk run'ın biçimini
  /// taşıyan tek run olur. Yer tutucu stili (`PlaceholderText`) düşer.
  static void _setContent(XmlElement content, String text) {
    final runs = content.childElements.where((e) => e.name.local == 'r').toList();
    XmlElement? rPr;
    for (final r in content.descendantElements) {
      if (r.name.local != 'r') continue;
      rPr = DocxDocument._child(r, 'rPr');
      break;
    }
    final st = DocxDocument._child(rPr, 'rStyle');
    if (st != null &&
        (DocxDocument._attr(st, 'val') ?? '').toLowerCase().contains('placeholder')) {
      rPr!.children.remove(st);
    }
    if (runs.length == 1 &&
        runs.length == content.childElements.length &&
        !text.contains('\n')) {
      final kids = runs.first.childElements
          .where((e) => e.name.local != 'rPr')
          .toList();
      if (kids.length == 1 && kids.first.name.local == 't') {
        final t = kids.first;
        t.children
          ..clear()
          ..add(XmlText(text));
        if (t.getAttribute('xml:space') == null && text.trim() != text) {
          t.attributes.add(
              XmlAttribute(const XmlName.qualified('xml:space'), 'preserve'));
        }
        return;
      }
    }
    final run = XmlElement(const XmlName.qualified('w:r'), [], [
      if (rPr != null &&
          (rPr.childElements.isNotEmpty || rPr.attributes.isNotEmpty))
        rPr.copy(),
    ]);
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) run.children.add(XmlElement(const XmlName.qualified('w:br')));
      run.children.add(XmlElement(const XmlName.qualified('w:t'),
          [XmlAttribute(const XmlName.qualified('xml:space'), 'preserve')],
          [XmlText(lines[i])]));
    }
    content.children
      ..clear()
      ..add(run);
  }
}
