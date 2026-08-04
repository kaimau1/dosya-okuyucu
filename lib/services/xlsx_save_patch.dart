import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/excel_format.dart' show builtinNumberFormats;

/// Bir sayfa için kaydetme sonrası düzeltilecek nitelikler.
///
/// Satır/sütun indeksleri **0 tabanlıdır** (uygulamanın her yerinde olduğu
/// gibi); XML'e yazılırken 1 tabanlıya çevrilir.
class XlsxSheetPatch {
  final String name;

  /// Sayfa sağdan sola mı çiziliyor (`<sheetView rightToLeft="1"/>`).
  final bool rightToLeft;

  final Set<int> hiddenRows;
  final Set<int> hiddenCols;

  /// Satır yükseklikleri (punto). YALNIZ `excel` paketinin yazamadığı —
  /// yani hiç hücresi olmayan — satırlar için gerekir; var olan `<row>`
  /// zaten `ht`/`customHeight` ile yazılıyor.
  final Map<int, double> rowHeightsPt;

  /// Dondurulmuş bölme: üstte sabit kalan satır ve solda sabit kalan sütun
  /// sayısı (`<pane state="frozen" xSplit="…" ySplit="…"/>`). 0 = bölme yok.
  final int frozenRows;
  final int frozenCols;

  /// Sayfada ızgara çizgileri görünüyor mu (`<sheetView showGridLines="0"/>`).
  /// Excel varsayılanı AÇIK; yalnız kapalıysa yazılır.
  final bool showGridLines;

  /// Otomatik süzgeç aralığı (`<autoFilter ref="A1:D20"/>`). null = süzgeç yok.
  final String? autoFilterRef;

  /// Kullanıcının verdiği **sayı biçimleri**: `(satır, sütun)` → biçim kodu
  /// (`'#,##0.00 ₺'`, `'0%'`, `'dd.mm.yyyy'`…).
  ///
  /// **Neden pakete değil buraya:** `excel 4.0.6` biçim kodunu hücrenin
  /// TİPİYLE eşleştirmeye çalışıyor ve uymazsa `save()` sırasında **istisna
  /// fırlatıyor** ("CustomDateTimeNumFormat does not work for IntCellValue").
  /// Excel'de tarihler sayı (seri numarası) olarak saklandığı için bu, en sık
  /// istenen biçimlendirmede dosyayı kaydedilemez hâle getiriyordu. Yama
  /// `styles.xml`i doğrudan yazdığından böyle bir tip polisi yok.
  final Map<(int, int), String> numberFormats;

  /// Kullanıcının verdiği **görünüm** değişiklikleri: dolgu rengi, yazı rengi,
  /// kalın/italik/altı çizili, kenarlık ve metin kaydırma. Sayı biçimiyle aynı
  /// nedenle burada (excel 4.0.6 bunların çoğunu yazamıyor; renkleri yazan
  /// API'si de tema/indeks renklerini düşürüyor).
  final Map<(int, int), XlsxStyleEdit> styleEdits;

  /// **Biçim yapıştırma**: hedef hücre → kaynak hücre. Yama, üretilen dosyada
  /// kaynağın `s="…"` indeksini okuyup hedefe yazar. Stil tablosuna hiç
  /// dokunulmaz — kaynak ve hedef aynı dosyada olduğu için indeks zaten
  /// geçerlidir; yeni `<xf>` üretmek gereksiz şişme olurdu.
  final Map<(int, int), (int, int)> styleCopies;

  /// Kullanıcının bu oturumda eklediği **koşullu biçimlendirme** kuralları.
  /// Sıra önemli: `dxf` kayıtları bu sırayla `styles.xml`e ekleniyor ve
  /// ekrandaki modelin kullandığı indekslerle birebir örtüşmesi gerekiyor.
  final List<XlsxCondRuleWrite> condRules;

  const XlsxSheetPatch({
    required this.name,
    this.rightToLeft = false,
    this.hiddenRows = const {},
    this.hiddenCols = const {},
    this.rowHeightsPt = const {},
    this.frozenRows = 0,
    this.frozenCols = 0,
    this.showGridLines = true,
    this.autoFilterRef,
    this.numberFormats = const {},
    this.styleEdits = const {},
    this.styleCopies = const {},
    this.condRules = const [],
  });

  bool get isEmpty =>
      !rightToLeft &&
      hiddenRows.isEmpty &&
      hiddenCols.isEmpty &&
      rowHeightsPt.isEmpty &&
      frozenRows == 0 &&
      frozenCols == 0 &&
      showGridLines &&
      autoFilterRef == null &&
      numberFormats.isEmpty &&
      styleEdits.isEmpty &&
      styleCopies.isEmpty &&
      condRules.isEmpty;
}

/// Dosyaya yazılacak tek bir koşullu biçimlendirme kuralı.
///
/// Excel'de kuralın **koşulu** sayfada (`<cfRule>`), **görünümü** ise stil
/// tablosunda (`<dxfs><dxf>`) durur; sayfa yalnız `dxfId` ile ona işaret eder.
/// İki parça bu yüzden birlikte yazılıyor.
class XlsxCondRuleWrite {
  /// Kuralın uygulandığı aralık (`A1:D20`).
  final String sqref;

  /// `cellIs` | `containsText` | `beginsWith` | `endsWith` …
  final String type;

  /// `cellIs` için: `greaterThan`, `lessThan`, `equal`, `between`…
  final String? operator;

  /// `cellIs` için formül(ler), metin kuralları için aranan metin.
  final List<String> formulas;
  final String? text;

  /// Eşleşen hücrenin dolgusu / yazı rengi (0xAARRGGBB, null = dokunma).
  final int? fillArgb;
  final int? fontArgb;

  const XlsxCondRuleWrite({
    required this.sqref,
    required this.type,
    this.operator,
    this.formulas = const [],
    this.text,
    this.fillArgb,
    this.fontArgb,
  });
}

/// Tek hücrenin görünüm değişikliği. Verilmeyen (null) alan **dokunulmaz**:
/// hücrenin dosyadaki mevcut yazı tipi/dolgusu/kenarlığı korunur.
class XlsxStyleEdit {
  /// Dolgu rengi (0xAARRGGBB). `null` = dokunma, [noFill] = dolguyu kaldır.
  final int? fillArgb;

  /// Yazı rengi (0xAARRGGBB). `null` = dokunma.
  final int? fontArgb;

  final bool? bold;
  final bool? italic;
  final bool? underline;

  /// Metin kaydırma (`<alignment wrapText="1"/>`).
  final bool? wrap;

  /// Kenarlık: kenar adı (`left`/`right`/`top`/`bottom`) → çizgi biçimi
  /// (`thin`, `medium`, `thick`, `double`…). Değer `null` ise o kenar SİLİNİR.
  /// Haritada olmayan kenara dokunulmaz.
  final Map<String, String?> borders;

  /// "Dolguyu kaldır" işareti — `fillArgb`da 0 ile karıştırılmasın diye ayrı
  /// bir sabit (0x00000000 saydam siyah da geçerli bir renk olabilirdi).
  static const int noFill = -1;

  const XlsxStyleEdit({
    this.fillArgb,
    this.fontArgb,
    this.bold,
    this.italic,
    this.underline,
    this.wrap,
    this.borders = const {},
  });

  bool get isEmpty =>
      fillArgb == null &&
      fontArgb == null &&
      bold == null &&
      italic == null &&
      underline == null &&
      wrap == null &&
      borders.isEmpty;

  /// Aynı hücreye art arda verilen düzenlemeleri birleştirir (sonraki kazanır).
  XlsxStyleEdit merge(XlsxStyleEdit other) => XlsxStyleEdit(
        fillArgb: other.fillArgb ?? fillArgb,
        fontArgb: other.fontArgb ?? fontArgb,
        bold: other.bold ?? bold,
        italic: other.italic ?? italic,
        underline: other.underline ?? underline,
        wrap: other.wrap ?? wrap,
        borders: {...borders, ...other.borders},
      );
}

/// `excel` paketinin **yazamadığı** sayfa niteliklerini, üretilen .xlsx
/// baytları üzerinde XML yaması ile geri koyar.
///
/// **Neden gerekiyor:** `excel 4.0.6`'nın yazma yolunda karşılığı olmayan üç
/// bilgi kaydetmede sessizce kayboluyordu (HAFIZA 2026-07-28 §B "Kapatılamayan"):
/// 1. **Gizli satır/sütun** — `_createNewRow` yalnız `r`/`ht`/`customHeight`
///    yazıyor, `hidden` diye bir alanı yok; `<cols>` de her kayıtta paketin
///    kendi haritasından baştan kuruluyor. Kullanıcı gizlediği sütunu kaydedip
///    dosyayı Excel'de açtığında sütun geri geliyordu.
/// 2. **Boş satırın yüksekliği** — `<row>` etiketi yalnız hücresi olan satır
///    için üretiliyor, bu yüzden ayırıcı olarak kullanılan boş satırların
///    özel yüksekliği kayboluyordu.
/// 3. **Sayfa yönü** (`rightToLeft`) — okunuyordu ama yazılmıyordu; Arapça/
///    İbranice bir sayfa bizde kaydedilince Excel'de soldan sağa açılıyordu.
/// 4. **Dondurulmuş bölme** (`<pane state="frozen"/>`), **ızgara çizgisi**
///    (`showGridLines="0"`) ve **otomatik süzgeç** (`<autoFilter>`) — üçü de
///    okunup ekranda uygulanıyordu ama pakette yazma karşılığı yok: başlık
///    satırı donmuş bir tabloyu bizde tek hücre düzenleyip kaydeden kullanıcı
///    dosyayı Excel'de açtığında bölmenin çözülmüş, süzgeç oklarının kaybolmuş
///    olduğunu görüyordu (2026-08-01).
///
/// **Neden yama, neden paketi değiştirmek değil:** `excel` paketini çatallamak
/// bakım borcu; buradaki yama girdi olarak yalnız zip baytlarını alıyor, saf
/// Dart ve birim testli (`test/xlsx_save_patch_test.dart`). Yamanın
/// dokunmadığı hiçbir bayt değişmez.
class XlsxSavePatch {
  /// Yamayı uygular. Bir sorun çıkarsa (bozuk zip, beklenmedik XML) **girdi
  /// baytları olduğu gibi** döner: kaydetmeyi kırmaktansa yamayı atlamak
  /// doğru — kullanıcının verisi yamadan daha değerli.
  static Uint8List apply(Uint8List bytes, List<XlsxSheetPatch> patches) {
    final todo = patches.where((p) => !p.isEmpty).toList();
    if (todo.isEmpty) return bytes;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final targets = _sheetTargets(archive);
      if (targets.isEmpty) return bytes;

      // Sayı biçimleri `styles.xml`de yaşar, hücre yalnız `s="<indeks>"` ile
      // ona işaret eder → stil tablosu sayfalardan ÖNCE açılır, sayfalar
      // yamalanırken indeks ondan istenir, en son (değiştiyse) geri yazılır.
      final stylesFile = _fileAt(archive, 'xl/styles.xml');
      final styles = stylesFile == null
          ? null
          : _StyleTable.parse(_textOf(stylesFile));

      final replacements = <String, String>{};
      for (final patch in todo) {
        final path = targets[patch.name];
        if (path == null) continue;
        final file = _fileAt(archive, path);
        if (file == null) continue;
        final patched = _patchSheetXml(_textOf(file), patch, styles);
        if (patched != null) replacements[path] = patched;
      }
      if (styles != null && styles.changed) {
        replacements['xl/styles.xml'] = styles.toXmlString();
      }
      if (replacements.isEmpty) return bytes;

      // `Archive.files` DEĞİŞTİRİLEMEZ bir liste (archive 3.6.1) — yerinde
      // yazmak `UnmodifiableListMixin` hatası verir ve buradaki try/catch
      // yamayı sessizce yutardı. Yeni arşiv kurulur, dokunulmayan dosyalar
      // baytı baytına taşınır.
      final rebuilt = Archive();
      for (final f in archive.files) {
        final text = replacements[f.name];
        if (text == null) {
          rebuilt.addFile(f);
          continue;
        }
        final data = utf8.encode(text);
        rebuilt.addFile(ArchiveFile(f.name, data.length, data)
          ..compress = f.compress);
      }
      final out = ZipEncoder().encode(rebuilt);
      if (out == null || out.isEmpty) return bytes;
      return Uint8List.fromList(out);
    } catch (_) {
      return bytes;
    }
  }

  // ── zip / ilişki çözümü ─────────────────────────────────────────────────

  /// Sayfa adı → `xl/worksheets/sheetN.xml`.
  ///
  /// Sıra ADA göre değil **ilişki kimliğine** (`r:id`) göre çözülür: dosyadaki
  /// `sheet1.xml`in birinci sayfa olduğu garanti DEĞİL (Excel sayfa silip
  /// ekledikçe numaralar karışır).
  static Map<String, String> _sheetTargets(Archive archive) {
    final wb = _fileAt(archive, 'xl/workbook.xml');
    final rels = _fileAt(archive, 'xl/_rels/workbook.xml.rels');
    if (wb == null || rels == null) return const {};

    final relTargets = <String, String>{};
    for (final r in XmlDocument.parse(_textOf(rels))
        .findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) relTargets[id] = target;
    }

    final result = <String, String>{};
    for (final sheet in XmlDocument.parse(_textOf(wb)).findAllElements('sheet')) {
      final name = sheet.getAttribute('name');
      final rid = sheet.getAttribute('r:id') ??
          sheet.getAttribute('id', namespace: '*');
      if (name == null || rid == null) continue;
      final target = relTargets[rid];
      if (target == null) continue;
      result[name] = _normalizeTarget(target);
    }
    return result;
  }

  /// İlişki hedefi `worksheets/sheet1.xml`, `/xl/worksheets/sheet1.xml` ya da
  /// `../worksheets/sheet1.xml` biçiminde olabilir; hepsi zip içi yola indirilir.
  static String _normalizeTarget(String target) {
    var t = target.replaceAll('\\', '/');
    if (t.startsWith('/')) return t.substring(1);
    while (t.startsWith('../')) {
      t = t.substring(3);
    }
    return t.startsWith('xl/') ? t : 'xl/$t';
  }

  static ArchiveFile? _fileAt(Archive archive, String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  static String _textOf(ArchiveFile f) =>
      utf8.decode(f.content as List<int>, allowMalformed: true);

  // ── sayfa XML'i ─────────────────────────────────────────────────────────

  /// Yamalanmış XML metni; değişiklik gerekmediyse null.
  static String? _patchSheetXml(
      String xmlText, XlsxSheetPatch patch, _StyleTable? styles) {
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;
    var changed = false;

    if (_applyView(root, patch)) changed = true;
    if (_applyHiddenCols(root, patch.hiddenCols)) changed = true;
    if (_applyRows(root, patch)) changed = true;
    if (_applyAutoFilter(root, patch.autoFilterRef)) changed = true;
    // Sıra önemli: önce biçim YAPIŞTIRMA (hedefin taban stili kaynağınki olur),
    // sonra kullanıcının açık görünüm değişiklikleri, en sonra sayı biçimi —
    // her adım bir öncekinin bıraktığı `s`yi taban alır, böylece üst üste
    // binen işlemler birbirini silmez.
    if (_applyStyleCopies(root, patch.styleCopies)) changed = true;
    if (_applyStyleEdits(root, patch.styleEdits, styles)) changed = true;
    if (_applyNumberFormats(root, patch.numberFormats, styles)) changed = true;
    if (_applyCondRules(root, patch.condRules, styles)) changed = true;

    return changed ? doc.toXmlString() : null;
  }

  /// Koşullu biçimlendirme kurallarını yazar.
  ///
  /// Öncelik (`priority`) 1'den başlar ve KÜÇÜK olan üstündür; kullanıcının
  /// yeni eklediği kural dosyadaki tüm kuralların ÖNÜNE geçmeli (Excel de yeni
  /// kuralı listenin başına koyar), o yüzden var olan en küçük önceliğin
  /// altından numaralanır.
  static bool _applyCondRules(
    XmlElement root,
    List<XlsxCondRuleWrite> rules,
    _StyleTable? styles,
  ) {
    if (rules.isEmpty || styles == null) return false;
    // `priority` 1'den başlar ve POZİTİF olmak zorundadır; var olan kurallar
    // yeni kuralların sayısı kadar yukarı kaydırılır, yenilere 1..n verilir.
    for (final cf in root.descendants.whereType<XmlElement>()) {
      if (cf.name.local != 'cfRule') continue;
      final p = int.tryParse(cf.getAttribute('priority') ?? '');
      if (p != null) cf.setAttribute('priority', '${p + rules.length}');
    }

    var priority = 0;
    for (final rule in rules) {
      final dxfId = styles.addDxf(rule.fillArgb, rule.fontArgb);
      final cfRule = XmlElement(XmlName('cfRule'), [
        XmlAttribute(XmlName('type'), rule.type),
        XmlAttribute(XmlName('dxfId'), '$dxfId'),
        XmlAttribute(XmlName('priority'), '${++priority}'),
        if (rule.operator != null)
          XmlAttribute(XmlName('operator'), rule.operator!),
        if (rule.text != null) XmlAttribute(XmlName('text'), rule.text!),
      ], [
        for (final f in rule.formulas)
          XmlElement(XmlName('formula'), [], [XmlText(f)]),
      ]);
      _insertOrdered(
        root,
        XmlElement(
          XmlName('conditionalFormatting'),
          [XmlAttribute(XmlName('sqref'), rule.sqref)],
          [cfRule],
        ),
      );
    }
    return true;
  }

  /// Biçim yapıştırma: kaynak hücrenin `s` indeksi hedefe kopyalanır.
  static bool _applyStyleCopies(
      XmlElement root, Map<(int, int), (int, int)> copies) {
    if (copies.isEmpty) return false;
    final data = _firstChild(root, 'sheetData');
    if (data == null) return false;

    // Kaynakların `s`si ÖNCE toplanır: hedeflerden biri başka bir kopyalamanın
    // kaynağıysa, aradaki yazma sırası sonucu değiştirmesin.
    final sourceStyles = <(int, int), String?>{};
    for (final src in copies.values) {
      sourceStyles.putIfAbsent(src, () {
        final row = _findRow(data, src.$1 + 1);
        if (row == null) return null;
        final ref = '${_colLetters(src.$2)}${src.$1 + 1}';
        return _findCell(row, ref)?.getAttribute('s');
      });
    }

    var changed = false;
    for (final entry in copies.entries) {
      final style = sourceStyles[entry.value];
      final (r, c) = entry.key;
      final rowNumber = r + 1;
      final ref = '${_colLetters(c)}$rowNumber';
      // Kaynağın stili yoksa (varsayılan) hedefte de varsayılana dönmeli;
      // ama yok olan hücreyi biçim vermek için ÜRETMEYE değmez.
      if (style == null) {
        final row = _findRow(data, rowNumber);
        final cell = row == null ? null : _findCell(row, ref);
        if (cell == null || cell.getAttribute('s') == null) continue;
        cell.removeAttribute('s');
        changed = true;
        continue;
      }
      final cell = _cellElement(_rowElement(data, rowNumber), ref, c);
      if (cell.getAttribute('s') == style) continue;
      cell.setAttribute('s', style);
      changed = true;
    }
    return changed;
  }

  /// Dolgu/yazı rengi, kalın-italik-altı çizili, kenarlık ve metin kaydırma.
  static bool _applyStyleEdits(
    XmlElement root,
    Map<(int, int), XlsxStyleEdit> edits,
    _StyleTable? styles,
  ) {
    if (edits.isEmpty || styles == null) return false;
    final data = _firstChild(root, 'sheetData');
    if (data == null) return false;

    var changed = false;
    final byRow = <int, List<int>>{};
    for (final key in edits.keys) {
      byRow.putIfAbsent(key.$1, () => []).add(key.$2);
    }
    for (final entry in byRow.entries) {
      final rowNumber = entry.key + 1;
      final row = _rowElement(data, rowNumber);
      for (final col in entry.value..sort()) {
        final edit = edits[(entry.key, col)]!;
        if (edit.isEmpty) continue;
        final ref = '${_colLetters(col)}$rowNumber';
        final cell = _cellElement(row, ref, col);
        final baseXf = int.tryParse(cell.getAttribute('s') ?? '') ?? 0;
        final xf = styles.xfWithEdit(baseXf, edit);
        if (cell.getAttribute('s') == '$xf') continue;
        cell.setAttribute('s', '$xf');
        changed = true;
      }
    }
    return changed;
  }

  /// `<row r="N">` — yoksa null (üretmez).
  static XmlElement? _findRow(XmlElement data, int number) {
    for (final row in data.children.whereType<XmlElement>()) {
      if (row.name.local != 'row') continue;
      if (int.tryParse(row.getAttribute('r') ?? '') == number) return row;
    }
    return null;
  }

  /// `<c r="REF">` — yoksa null (üretmez).
  static XmlElement? _findCell(XmlElement row, String ref) {
    for (final c in row.children.whereType<XmlElement>()) {
      if (c.name.local == 'c' && c.getAttribute('r') == ref) return c;
    }
    return null;
  }

  /// Sayı biçimlerini hücrelere bağlar: her hücre için `styles.xml`de uygun
  /// bir `<xf>` bulunur/oluşturulur ve hücreye `s="<indeks>"` yazılır.
  static bool _applyNumberFormats(
    XmlElement root,
    Map<(int, int), String> formats,
    _StyleTable? styles,
  ) {
    if (formats.isEmpty || styles == null) return false;
    final data = _firstChild(root, 'sheetData');
    if (data == null) return false;

    var changed = false;
    // Satır satır gruplanır: aynı satırdaki hücreler tek geçişte bulunur.
    final byRow = <int, List<int>>{};
    for (final key in formats.keys) {
      byRow.putIfAbsent(key.$1, () => []).add(key.$2);
    }

    for (final entry in byRow.entries) {
      final rowNumber = entry.key + 1;
      final row = _rowElement(data, rowNumber);
      for (final col in entry.value..sort()) {
        final ref = '${_colLetters(col)}$rowNumber';
        final cell = _cellElement(row, ref, col);
        final baseXf = int.tryParse(cell.getAttribute('s') ?? '') ?? 0;
        final xf = styles.xfWithNumberFormat(baseXf, formats[(entry.key, col)]!);
        if (cell.getAttribute('s') == '$xf') continue;
        cell.setAttribute('s', '$xf');
        changed = true;
      }
    }
    return changed;
  }

  /// `<row r="N">` — yoksa sıralı yerine oluşturulur.
  static XmlElement _rowElement(XmlElement data, int number) {
    for (final row in data.children.whereType<XmlElement>()) {
      if (row.name.local != 'row') continue;
      if (int.tryParse(row.getAttribute('r') ?? '') == number) return row;
    }
    final created =
        XmlElement(XmlName('row'), [XmlAttribute(XmlName('r'), '$number')]);
    _insertRowSorted(data, created, number);
    return created;
  }

  /// `<c r="B3">` — yoksa SÜTUN SIRASINA göre oluşturulur. Değeri olmayan
  /// hücreye de biçim verilebilir (Excel `<c r="B3" s="5"/>` yazar); sıra
  /// bozulursa Excel dosyayı onarılamaz sayar.
  static XmlElement _cellElement(XmlElement row, String ref, int col) {
    for (final c in row.children.whereType<XmlElement>()) {
      if (c.name.local != 'c') continue;
      if (c.getAttribute('r') == ref) return c;
    }
    final created =
        XmlElement(XmlName('c'), [XmlAttribute(XmlName('r'), ref)]);
    for (var i = 0; i < row.children.length; i++) {
      final node = row.children[i];
      if (node is! XmlElement || node.name.local != 'c') continue;
      final other = _colOfRef(node.getAttribute('r') ?? '');
      if (other > col) {
        row.children.insert(i, created);
        return created;
      }
    }
    row.children.add(created);
    return created;
  }

  /// "B3" → 1 (0 tabanlı sütun). Çözülemezse en sona düşsün diye çok büyük.
  static int _colOfRef(String ref) {
    var n = 0;
    for (final u in ref.codeUnits) {
      if (u >= 65 && u <= 90) {
        n = n * 26 + (u - 64);
      } else if (u >= 97 && u <= 122) {
        n = n * 26 + (u - 96);
      } else {
        break;
      }
    }
    return n == 0 ? 1 << 30 : n - 1;
  }

  static String _colLetters(int index) {
    var n = index + 1;
    final out = <int>[];
    while (n > 0) {
      out.add(65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return String.fromCharCodes(out.reversed);
  }

  /// `<sheetViews><sheetView …/></sheetViews>` — yön, ızgara çizgisi ve
  /// dondurulmuş bölme aynı düğümde durur, hepsi tek geçişte yazılır.
  static bool _applyView(XmlElement root, XlsxSheetPatch patch) {
    final needsView =
        patch.rightToLeft || !patch.showGridLines || _hasFreeze(patch);
    var views = _firstChild(root, 'sheetViews');
    if (views == null) {
      if (!needsView) return false;
      views = XmlElement(XmlName('sheetViews'));
      _insertOrdered(root, views);
    }
    var view = _firstChild(views, 'sheetView');
    if (view == null) {
      if (!needsView) return false;
      view = XmlElement(XmlName('sheetView'), [
        XmlAttribute(XmlName('workbookViewId'), '0'),
      ]);
      views.children.add(view);
    }

    var changed = false;
    if (_applyDirection(view, patch.rightToLeft)) changed = true;
    if (_applyGridLines(view, patch.showGridLines)) changed = true;
    if (_applyPane(view, patch)) changed = true;

    // Hiçbir şey yazılmadıysa boş kabuk bırakma (dosyayı gereksiz değiştirir).
    if (!changed && view.attributes.length <= 1 && view.children.isEmpty) {
      views.children.remove(view);
      if (views.children.isEmpty) views.parent?.children.remove(views);
    }
    return changed;
  }

  static bool _hasFreeze(XlsxSheetPatch p) => p.frozenRows > 0 || p.frozenCols > 0;

  static bool _applyDirection(XmlElement view, bool rtl) {
    final current = view.getAttribute('rightToLeft');
    final already = current == '1' || current == 'true';
    if (already == rtl) return false;
    if (rtl) {
      view.setAttribute('rightToLeft', '1');
    } else {
      view.removeAttribute('rightToLeft');
    }
    return true;
  }

  /// Izgara çizgisi Excel'de VARSAYILAN olarak açıktır; nitelik yalnız
  /// kapalıyken yazılır, açıkken (varsa) kaldırılır.
  static bool _applyGridLines(XmlElement view, bool show) {
    final current = view.getAttribute('showGridLines');
    final already = !(current == '0' || current == 'false');
    if (already == show) return false;
    if (show) {
      view.removeAttribute('showGridLines');
    } else {
      view.setAttribute('showGridLines', '0');
    }
    return true;
  }

  /// Dondurulmuş bölme. `<pane>` **sheetView'ın İLK çocuğu** olmalıdır
  /// (CT_SheetView sırası: pane → selection → …); yanlış sıra Excel'de
  /// "onarılamayan içerik" uyarısı demek.
  ///
  /// `topLeftCell` bölmenin ALTINDA/SAĞINDA kalan ilk hücredir; `activePane`
  /// hangi bölmenin etkin olduğunu söyler (Excel'in kendi yazdığı değerler:
  /// yalnız satır donmuşsa `bottomLeft`, yalnız sütun donmuşsa `topRight`,
  /// ikisi birdense `bottomRight`).
  static bool _applyPane(XmlElement view, XlsxSheetPatch patch) {
    final existing = _firstChild(view, 'pane');
    if (!_hasFreeze(patch)) {
      if (existing == null) return false;
      // Kullanıcı bölmeyi kaldırdıysa düğüm de gitmeli.
      view.children.remove(existing);
      return true;
    }
    final rows = patch.frozenRows;
    final cols = patch.frozenCols;
    final activePane = rows > 0 && cols > 0
        ? 'bottomRight'
        : (rows > 0 ? 'bottomLeft' : 'topRight');
    final pane = XmlElement(XmlName('pane'), [
      if (cols > 0) XmlAttribute(XmlName('xSplit'), '$cols'),
      if (rows > 0) XmlAttribute(XmlName('ySplit'), '$rows'),
      XmlAttribute(XmlName('topLeftCell'), _cellRef(rows, cols)),
      XmlAttribute(XmlName('activePane'), activePane),
      XmlAttribute(XmlName('state'), 'frozen'),
    ]);
    if (existing != null) {
      if (_sameAttributes(existing, pane)) return false;
      final at = view.children.indexOf(existing);
      view.children[at] = pane;
      return true;
    }
    view.children.insert(0, pane);
    return true;
  }

  static bool _sameAttributes(XmlElement a, XmlElement b) {
    if (a.attributes.length != b.attributes.length) return false;
    for (final attr in b.attributes) {
      if (a.getAttribute(attr.name.qualified) != attr.value) return false;
    }
    return true;
  }

  /// 0 tabanlı satır/sütun → "B2" biçiminde A1 başvurusu.
  static String _cellRef(int row, int col) {
    var n = col + 1;
    final letters = <int>[];
    while (n > 0) {
      letters.add(65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return '${String.fromCharCodes(letters.reversed)}${row + 1}';
  }

  /// `<autoFilter ref="A1:D20"/>` — `sheetData`dan SONRA gelir.
  static bool _applyAutoFilter(XmlElement root, String? ref) {
    final existing = _firstChild(root, 'autoFilter');
    if (ref == null || ref.isEmpty) {
      if (existing == null) return false;
      root.children.remove(existing);
      return true;
    }
    if (existing != null) {
      if (existing.getAttribute('ref') == ref) return false;
      existing.setAttribute('ref', ref);
      return true;
    }
    _insertOrdered(
      root,
      XmlElement(XmlName('autoFilter'), [XmlAttribute(XmlName('ref'), ref)]),
    );
    return true;
  }

  /// Gizli sütunlar. Var olan `<col>` aralığı indeksi kapsıyorsa aralık
  /// BÖLÜNÜR (genişlik bilgisi komşularda korunsun); kapsamıyorsa yeni bir
  /// `<col>` eklenir.
  static bool _applyHiddenCols(XmlElement root, Set<int> hidden) {
    if (hidden.isEmpty) return false;
    var cols = _firstChild(root, 'cols');
    if (cols == null) {
      cols = XmlElement(XmlName('cols'));
      _insertOrdered(root, cols);
    }
    var changed = false;
    for (final index in hidden.toList()..sort()) {
      if (_hideColumn(cols, index + 1)) changed = true;
    }
    if (cols.children.isEmpty) {
      cols.parent?.children.remove(cols);
      return changed;
    }
    return changed;
  }

  static bool _hideColumn(XmlElement cols, int number) {
    for (final col in cols.children.whereType<XmlElement>().toList()) {
      if (col.name.local != 'col') continue;
      final min = int.tryParse(col.getAttribute('min') ?? '');
      final max = int.tryParse(col.getAttribute('max') ?? '');
      if (min == null || max == null || number < min || number > max) continue;
      final already = col.getAttribute('hidden');
      if (min == max) {
        if (already == '1' || already == 'true') return false;
        col.setAttribute('hidden', '1');
        return true;
      }
      // Aralığı üçe böl: [min, number-1] · [number] · [number+1, max]
      final at = cols.children.indexOf(col);
      final pieces = <XmlElement>[];
      if (number > min) {
        pieces.add(_cloneCol(col, min, number - 1, hidden: false));
      }
      pieces.add(_cloneCol(col, number, number, hidden: true));
      if (number < max) {
        pieces.add(_cloneCol(col, number + 1, max, hidden: false));
      }
      cols.children.removeAt(at);
      cols.children.insertAll(at, pieces);
      return true;
    }
    cols.children.add(XmlElement(XmlName('col'), [
      XmlAttribute(XmlName('min'), '$number'),
      XmlAttribute(XmlName('max'), '$number'),
      XmlAttribute(XmlName('width'), '0'),
      XmlAttribute(XmlName('hidden'), '1'),
      XmlAttribute(XmlName('customWidth'), '1'),
    ]));
    return true;
  }

  static XmlElement _cloneCol(XmlElement src, int min, int max,
      {required bool hidden}) {
    final attrs = <XmlAttribute>[
      for (final a in src.attributes)
        if (a.name.local != 'min' &&
            a.name.local != 'max' &&
            a.name.local != 'hidden')
          XmlAttribute(XmlName(a.name.qualified), a.value),
    ];
    return XmlElement(XmlName('col'), [
      XmlAttribute(XmlName('min'), '$min'),
      XmlAttribute(XmlName('max'), '$max'),
      ...attrs,
      if (hidden) XmlAttribute(XmlName('hidden'), '1'),
    ]);
  }

  /// Gizli satırlar + `excel` paketinin yazamadığı boş satır yükseklikleri.
  static bool _applyRows(XmlElement root, XlsxSheetPatch patch) {
    if (patch.hiddenRows.isEmpty && patch.rowHeightsPt.isEmpty) return false;
    final data = _firstChild(root, 'sheetData');
    if (data == null) return false;

    final existing = <int, XmlElement>{};
    for (final row in data.children.whereType<XmlElement>()) {
      if (row.name.local != 'row') continue;
      final r = int.tryParse(row.getAttribute('r') ?? '');
      if (r != null) existing[r] = row;
    }

    final wanted = <int>{...patch.hiddenRows, ...patch.rowHeightsPt.keys};
    var changed = false;
    for (final index in wanted.toList()..sort()) {
      final number = index + 1;
      final hide = patch.hiddenRows.contains(index);
      final height = patch.rowHeightsPt[index];
      final row = existing[number];
      if (row != null) {
        // Var olan satırın yüksekliğini paket zaten yazıyor; burada yalnız
        // gizlilik eklenir (fazladan yazmak dosyayı gereksiz değiştirir).
        final already = row.getAttribute('hidden');
        if (hide && already != '1' && already != 'true') {
          row.setAttribute('hidden', '1');
          changed = true;
        }
        continue;
      }
      if (!hide && height == null) continue;
      final created = XmlElement(XmlName('row'), [
        XmlAttribute(XmlName('r'), '$number'),
        if (height != null) ...[
          XmlAttribute(XmlName('ht'), height.toStringAsFixed(2)),
          XmlAttribute(XmlName('customHeight'), '1'),
        ],
        if (hide) XmlAttribute(XmlName('hidden'), '1'),
      ]);
      _insertRowSorted(data, created, number);
      existing[number] = created;
      changed = true;
    }
    return changed;
  }

  static void _insertRowSorted(XmlElement data, XmlElement row, int number) {
    for (var i = 0; i < data.children.length; i++) {
      final node = data.children[i];
      if (node is! XmlElement || node.name.local != 'row') continue;
      final r = int.tryParse(node.getAttribute('r') ?? '');
      if (r != null && r > number) {
        data.children.insert(i, row);
        return;
      }
    }
    data.children.add(row);
  }

  // ── yardımcılar ─────────────────────────────────────────────────────────

  static XmlElement? _firstChild(XmlElement parent, String local) {
    for (final e in parent.children.whereType<XmlElement>()) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  /// ECMA-376 `CT_Worksheet` çocuk SIRASI zorunludur; yeni öğe kendinden
  /// sonra gelmesi gereken ilk kardeşin ÖNÜNE konur. Yanlış sıra Excel'de
  /// "onarılamayan içerik" uyarısı demek.
  static const _worksheetOrder = [
    'sheetPr',
    'dimension',
    'sheetViews',
    'sheetFormatPr',
    'cols',
    'sheetData',
    // `sheetData`dan SONRAKİ kardeşler de listede: `autoFilter` sona eklenseydi
    // `mergeCells`/`pageMargins`in ARKASINA düşerdi — şema sırası bozulurdu.
    'sheetCalcPr',
    'sheetProtection',
    'protectedRanges',
    'scenarios',
    'autoFilter',
    'sortState',
    'dataConsolidate',
    'customSheetViews',
    'mergeCells',
    'phoneticPr',
    'conditionalFormatting',
    'dataValidations',
    'hyperlinks',
    'printOptions',
    'pageMargins',
    'pageSetup',
    'headerFooter',
  ];

  static void _insertOrdered(XmlElement root, XmlElement child) {
    insertOrderedIn(root, child, _worksheetOrder);
  }

  /// Şema sırasını koruyarak ekler (sayfa ve stil tablosu ortak kullanır).
  static void insertOrderedIn(
      XmlElement root, XmlElement child, List<String> order) {
    final rank = order.indexOf(child.name.local);
    if (rank < 0) {
      root.children.add(child);
      return;
    }
    for (var i = 0; i < root.children.length; i++) {
      final node = root.children[i];
      if (node is! XmlElement) continue;
      final other = order.indexOf(node.name.local);
      // Listede olmayan öğe (`drawing`, `legacyDrawing`, `extLst`…) şemada
      // listedekilerin tamamından SONRA gelir → önüne konur.
      if (other < 0 || other > rank) {
        root.children.insert(i, child);
        return;
      }
    }
    root.children.add(child);
  }
}

/// `xl/styles.xml` üzerinde **sayı biçimi** tahsisi.
///
/// Excel'de hücre biçimi hücrede DEĞİL, stil tablosunda durur: hücre yalnız
/// `s="<cellXfs indeksi>"` yazar. Bir hücreye yeni bir sayı biçimi vermek bu
/// yüzden üç adımdır:
/// 1. biçim kodu için bir `numFmtId` bul (yerleşikse hazır id, değilse
///    `<numFmts>`e 164'ten başlayan yeni bir kayıt),
/// 2. hücrenin ŞU ANKİ `<xf>`ini kopyalayıp `numFmtId`ini değiştir (yazı tipi,
///    dolgu, kenarlık, hizalama korunsun — yoksa biçim vermek hücrenin
///    görünümünü sıfırlardı),
/// 3. aynı `<xf>` zaten varsa onun indeksini kullan, yoksa ekle.
///
/// Adım 3 şart: her hücre için yeni bir `<xf>` eklemek büyük bir tabloda stil
/// tablosunu şişirir ve Excel'in sınırlarına dayanır.
class _StyleTable {
  final XmlDocument doc;
  final XmlElement root;
  bool changed = false;

  /// Biçim kodu → numFmtId (yerleşikler + dosyadaki özel kayıtlar).
  final Map<String, int> _idByCode = {};
  int _nextCustomId = 164;

  _StyleTable._(this.doc) : root = doc.rootElement;

  static _StyleTable? parse(String xml) {
    try {
      final table = _StyleTable._(XmlDocument.parse(xml));
      table._index();
      return table;
    } catch (_) {
      // Bozuk stil tablosu yüzünden kaydetmeyi kırma; biçim yazılamaz, o kadar.
      return null;
    }
  }

  void _index() {
    builtinNumberFormats.forEach((id, code) => _idByCode.putIfAbsent(code, () => id));
    final numFmts = _child(root, 'numFmts');
    if (numFmts == null) return;
    for (final nf in numFmts.childElements) {
      if (nf.name.local != 'numFmt') continue;
      final id = int.tryParse(nf.getAttribute('numFmtId') ?? '');
      final code = nf.getAttribute('formatCode');
      if (id == null || code == null) continue;
      _idByCode[code] = id;
      if (id >= _nextCustomId) _nextCustomId = id + 1;
    }
  }

  /// [baseXf] biçimini koruyup sayı biçimini [formatCode] yapan `<xf>`in
  /// `cellXfs` indeksi.
  int xfWithNumberFormat(int baseXf, String formatCode) {
    final cellXfs = _childOrCreate(root, 'cellXfs');
    final xfs = cellXfs.childElements
        .where((e) => e.name.local == 'xf')
        .toList(growable: false);

    final numFmtId = _numFmtIdFor(formatCode);
    final base = baseXf >= 0 && baseXf < xfs.length ? xfs[baseXf] : null;
    final wanted = base == null
        ? XmlElement(XmlName('xf'), [
            XmlAttribute(XmlName('numFmtId'), '$numFmtId'),
            XmlAttribute(XmlName('fontId'), '0'),
            XmlAttribute(XmlName('fillId'), '0'),
            XmlAttribute(XmlName('borderId'), '0'),
            XmlAttribute(XmlName('xfId'), '0'),
            XmlAttribute(XmlName('applyNumberFormat'), '1'),
          ])
        : _cloneXf(base, numFmtId);

    return _indexOfOrAdd(cellXfs, wanted);
  }

  /// [baseXf]'in her şeyini koruyup [edit]'teki görünüm alanlarını değiştiren
  /// `<xf>`in `cellXfs` indeksi.
  ///
  /// Yazı tipi, dolgu ve kenarlık `<xf>`in İÇİNDE durmaz — `<fonts>`,
  /// `<fills>`, `<borders>` listelerinde durur ve `<xf>` onlara indeksle
  /// işaret eder. Bu yüzden her biri için önce "aynısı var mı" diye bakılır,
  /// yoksa listeye eklenir; sonra `<xf>` yeni indekslerle klonlanır.
  int xfWithEdit(int baseXf, XlsxStyleEdit edit) {
    final cellXfs = _childOrCreate(root, 'cellXfs');
    final xfs = cellXfs.childElements
        .where((e) => e.name.local == 'xf')
        .toList(growable: false);
    final base = baseXf >= 0 && baseXf < xfs.length ? xfs[baseXf] : null;

    final wanted = base == null
        ? XmlElement(XmlName('xf'), [
            XmlAttribute(XmlName('numFmtId'), '0'),
            XmlAttribute(XmlName('fontId'), '0'),
            XmlAttribute(XmlName('fillId'), '0'),
            XmlAttribute(XmlName('borderId'), '0'),
            XmlAttribute(XmlName('xfId'), '0'),
          ])
        : XmlElement(
            XmlName('xf'),
            [
              for (final a in base.attributes)
                XmlAttribute(XmlName(a.name.qualified), a.value),
            ],
            [for (final c in base.childElements) c.copy()],
          );

    if (edit.bold != null ||
        edit.italic != null ||
        edit.underline != null ||
        edit.fontArgb != null) {
      final baseFont = int.tryParse(wanted.getAttribute('fontId') ?? '') ?? 0;
      wanted.setAttribute('fontId', '${_fontIdWith(baseFont, edit)}');
      wanted.setAttribute('applyFont', '1');
    }
    if (edit.fillArgb != null) {
      wanted.setAttribute('fillId', '${_fillIdFor(edit.fillArgb!)}');
      wanted.setAttribute('applyFill', '1');
    }
    if (edit.borders.isNotEmpty) {
      final baseBorder = int.tryParse(wanted.getAttribute('borderId') ?? '') ?? 0;
      wanted.setAttribute(
          'borderId', '${_borderIdWith(baseBorder, edit.borders)}');
      wanted.setAttribute('applyBorder', '1');
    }
    if (edit.wrap != null) {
      final align = _childOrAppend(wanted, 'alignment');
      if (edit.wrap!) {
        align.setAttribute('wrapText', '1');
      } else {
        align.removeAttribute('wrapText');
      }
      wanted.setAttribute('applyAlignment', '1');
    }

    return _indexOfOrAdd(cellXfs, wanted);
  }

  /// Koşullu biçimlendirmenin görünümü (`<dxfs><dxf>`) — **daima SONA
  /// eklenir** ve indeksi döner.
  ///
  /// Tekilleştirme bilinçli olarak YOK: ekrandaki model de aynı sırayla kendi
  /// `dxfs` listesine ekliyor, indekslerin birebir örtüşmesi gerekiyor. Aynı
  /// rengi paylaştırmak indeksleri kaydırıp ekranla dosyayı ayrıştırırdı.
  int addDxf(int? fillArgb, int? fontArgb) {
    final dxfs = _childOrCreate(root, 'dxfs');
    final index = dxfs.childElements.where((e) => e.name.local == 'dxf').length;
    dxfs.children.add(XmlElement(XmlName('dxf'), const [], [
      // CT_Dxf sırası: font, numFmt, fill, alignment, border, protection.
      if (fontArgb != null)
        XmlElement(XmlName('font'), const [], [
          XmlElement(XmlName('color'),
              [XmlAttribute(XmlName('rgb'), _argbHex(fontArgb))]),
        ]),
      if (fillArgb != null)
        XmlElement(XmlName('fill'), const [], [
          // `<dxf>` dolgusunda Excel rengi **bgColor**a yazar (hücre
          // stilindeki `fgColor`un aksine) — ters yazılırsa dolgu görünmez.
          XmlElement(XmlName('patternFill'), const [], [
            XmlElement(XmlName('bgColor'),
                [XmlAttribute(XmlName('rgb'), _argbHex(fillArgb))]),
          ]),
        ]),
    ]));
    _setCount(dxfs, index + 1);
    changed = true;
    return index;
  }

  /// [baseFontId]'i klonlayıp kalın/italik/altı çizili/renk alanlarını uygular.
  int _fontIdWith(int baseFontId, XlsxStyleEdit edit) {
    final fonts = _childOrCreate(root, 'fonts');
    final list = fonts.childElements
        .where((e) => e.name.local == 'font')
        .toList(growable: false);
    final base = baseFontId >= 0 && baseFontId < list.length
        ? list[baseFontId]
        : (list.isNotEmpty ? list.first : null);

    final children = <XmlElement>[
      if (base != null) for (final c in base.childElements) c.copy(),
    ];
    void setFlag(String local, bool? on) {
      if (on == null) return;
      children.removeWhere((e) => e.name.local == local);
      if (on) children.add(XmlElement(XmlName(local)));
    }

    setFlag('b', edit.bold);
    setFlag('i', edit.italic);
    setFlag('u', edit.underline);
    if (edit.fontArgb != null) {
      children.removeWhere((e) => e.name.local == 'color');
      children.add(XmlElement(XmlName('color'),
          [XmlAttribute(XmlName('rgb'), _argbHex(edit.fontArgb!))]));
    }

    final font = XmlElement(XmlName('font'), const [], _ordered(children, _fontOrder));
    return _indexOfOrAdd(fonts, font);
  }

  /// Düz (solid) dolgu. [XlsxStyleEdit.noFill] verilirse Excel'in ayırdığı
  /// **0 numaralı** boş dolguya döner — yeni bir "none" dolgusu eklemek
  /// gereksiz, her dosyada zaten var.
  int _fillIdFor(int argb) {
    if (argb == XlsxStyleEdit.noFill) return 0;
    final fills = _childOrCreate(root, 'fills');
    final fill = XmlElement(XmlName('fill'), const [], [
      XmlElement(
        XmlName('patternFill'),
        [XmlAttribute(XmlName('patternType'), 'solid')],
        [
          XmlElement(XmlName('fgColor'),
              [XmlAttribute(XmlName('rgb'), _argbHex(argb))]),
          // Excel `bgColor indexed="64"` (= "otomatik") yazar; bırakılırsa
          // bazı sürümler dolguyu desen sanıp farklı çiziyor.
          XmlElement(XmlName('bgColor'),
              [XmlAttribute(XmlName('indexed'), '64')]),
        ],
      ),
    ]);
    return _indexOfOrAdd(fills, fill);
  }

  /// [baseBorderId]'i klonlayıp verilen kenarları değiştirir (`null` = sil).
  int _borderIdWith(int baseBorderId, Map<String, String?> sides) {
    final borders = _childOrCreate(root, 'borders');
    final list = borders.childElements
        .where((e) => e.name.local == 'border')
        .toList(growable: false);
    final base = baseBorderId >= 0 && baseBorderId < list.length
        ? list[baseBorderId]
        : (list.isNotEmpty ? list.first : null);

    final children = <XmlElement>[
      if (base != null) for (final c in base.childElements) c.copy(),
    ];
    sides.forEach((side, style) {
      children.removeWhere((e) => e.name.local == side);
      if (style == null) {
        // Boş kenar da YAZILIR: `<left/>` "çizgi yok" demektir ve taban
        // kenarlıktan miras kalan çizgiyi bastırır.
        children.add(XmlElement(XmlName(side)));
      } else {
        children.add(XmlElement(
          XmlName(side),
          [XmlAttribute(XmlName('style'), style)],
          [
            XmlElement(XmlName('color'),
                [XmlAttribute(XmlName('indexed'), '64')]),
          ],
        ));
      }
    });

    final border =
        XmlElement(XmlName('border'), const [], _ordered(children, _borderOrder));
    return _indexOfOrAdd(borders, border);
  }

  /// ECMA-376 `CT_Font` çocuk sırası.
  static const _fontOrder = [
    'b', 'i', 'strike', 'condense', 'extend', 'outline', 'shadow', 'u',
    'vertAlign', 'sz', 'color', 'name', 'family', 'charset', 'scheme',
  ];

  /// ECMA-376 `CT_Border` çocuk sırası.
  static const _borderOrder = [
    'start', 'end', 'left', 'right', 'top', 'bottom', 'diagonal',
    'vertical', 'horizontal',
  ];

  static List<XmlElement> _ordered(List<XmlElement> items, List<String> order) {
    final out = <XmlElement>[];
    for (final name in order) {
      out.addAll(items.where((e) => e.name.local == name));
    }
    // Tanımadığımız çocuklar (uzantılar) sıranın sonunda korunur.
    out.addAll(items.where((e) => !order.contains(e.name.local)));
    return out;
  }

  /// [wanted]'ın aynısı [container] içinde varsa indeksi, yoksa ekleyip
  /// yeni indeksi. Karşılaştırma **kanonik anahtar** üzerinden yapılır:
  /// nitelik SIRASI dosyadan dosyaya değişir, anlamı değişmez.
  int _indexOfOrAdd(XmlElement container, XmlElement wanted) {
    final itemName = wanted.name.local;
    final list = container.childElements
        .where((e) => e.name.local == itemName)
        .toList(growable: false);
    final key = _canonical(wanted);
    for (var i = 0; i < list.length; i++) {
      if (_canonical(list[i]) == key) return i;
    }
    container.children.add(wanted);
    _setCount(container, list.length + 1);
    changed = true;
    return list.length;
  }

  /// Etiketin anlamsal parmak izi: ad + SIRALI nitelikler + çocukların aynısı.
  static String _canonical(XmlElement e) {
    final attrs = [
      for (final a in e.attributes) '${a.name.local}=${a.value}',
    ]..sort();
    final kids = [for (final c in e.childElements) _canonical(c)];
    return '${e.name.local}[${attrs.join(',')}](${kids.join(',')})';
  }

  static String _argbHex(int argb) =>
      argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase();

  static XmlElement _childOrAppend(XmlElement parent, String local) {
    final existing = _child(parent, local);
    if (existing != null) return existing;
    final created = XmlElement(XmlName(local));
    parent.children.add(created);
    return created;
  }

  int _numFmtIdFor(String code) {
    final existing = _idByCode[code];
    if (existing != null) return existing;
    final id = _nextCustomId++;
    final numFmts = _childOrCreate(root, 'numFmts');
    numFmts.children.add(XmlElement(XmlName('numFmt'), [
      XmlAttribute(XmlName('numFmtId'), '$id'),
      XmlAttribute(XmlName('formatCode'), code),
    ]));
    _setCount(numFmts, numFmts.childElements.length);
    _idByCode[code] = id;
    changed = true;
    return id;
  }

  static XmlElement _cloneXf(XmlElement src, int numFmtId) {
    final el = XmlElement(XmlName('xf'), [
      for (final a in src.attributes)
        if (a.name.local != 'numFmtId' && a.name.local != 'applyNumberFormat')
          XmlAttribute(XmlName(a.name.qualified), a.value),
      XmlAttribute(XmlName('numFmtId'), '$numFmtId'),
      XmlAttribute(XmlName('applyNumberFormat'), '1'),
    ]);
    // `<alignment>` / `<protection>` alt düğümleri de taşınmalı.
    for (final child in src.childElements) {
      el.children.add(child.copy());
    }
    return el;
  }

  static void _setCount(XmlElement el, int n) =>
      el.setAttribute('count', '$n');

  static XmlElement? _child(XmlElement parent, String local) {
    for (final e in parent.childElements) {
      if (e.name.local == local) return e;
    }
    return null;
  }

  /// ECMA-376 `CT_Stylesheet` çocuk sırası zorunludur; yanlış yere konan
  /// `<numFmts>` Excel'de "onarılamayan içerik" demek.
  static const _order = [
    'numFmts',
    'fonts',
    'fills',
    'borders',
    'cellStyleXfs',
    'cellXfs',
    'cellStyles',
    'dxfs',
    'tableStyles',
    'colors',
    'extLst',
  ];

  XmlElement _childOrCreate(XmlElement parent, String local) {
    final existing = _child(parent, local);
    if (existing != null) return existing;
    final created = XmlElement(XmlName(local));
    XlsxSavePatch.insertOrderedIn(parent, created, _order);
    changed = true;
    return created;
  }

  String toXmlString() => doc.toXmlString();
}
