import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

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
  });

  bool get isEmpty =>
      !rightToLeft &&
      hiddenRows.isEmpty &&
      hiddenCols.isEmpty &&
      rowHeightsPt.isEmpty &&
      frozenRows == 0 &&
      frozenCols == 0 &&
      showGridLines &&
      autoFilterRef == null;
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

      final replacements = <String, String>{};
      for (final patch in todo) {
        final path = targets[patch.name];
        if (path == null) continue;
        final file = _fileAt(archive, path);
        if (file == null) continue;
        final patched = _patchSheetXml(_textOf(file), patch);
        if (patched != null) replacements[path] = patched;
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
  static String? _patchSheetXml(String xmlText, XlsxSheetPatch patch) {
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;
    var changed = false;

    if (_applyView(root, patch)) changed = true;
    if (_applyHiddenCols(root, patch.hiddenCols)) changed = true;
    if (_applyRows(root, patch)) changed = true;
    if (_applyAutoFilter(root, patch.autoFilterRef)) changed = true;

    return changed ? doc.toXmlString() : null;
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
    final rank = _worksheetOrder.indexOf(child.name.local);
    if (rank < 0) {
      root.children.add(child);
      return;
    }
    for (var i = 0; i < root.children.length; i++) {
      final node = root.children[i];
      if (node is! XmlElement) continue;
      final other = _worksheetOrder.indexOf(node.name.local);
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
