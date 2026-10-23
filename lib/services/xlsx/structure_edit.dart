part of '../xlsx_editor.dart';

/// Satır/sütun ekle-silin **model** tarafı (Faz 25 / X3): formüller (bütün
/// sayfalar), birleştirmeler, koşullu biçim, doğrulama, not, köprü, süzgeç
/// ve oturum biçim haritaları kaydırılır; işlem kayda yazılır ki
/// kaydetmede özgün XML parçaları da aynı kaydırmayı görsün
/// (`XlsxPackageWriter`). Kurallar: `services/sheet_structure.dart`.
extension XlsxStructureEdit on XlsxEditor {
  void _applyStructural(XlsxSheet sheet, SheetShift op) {
    final name = sheet.name;
    // Formüller: her sayfada, bu sayfaya giden başvurular.
    for (final s in sheets) {
      for (final row in s.rows) {
        for (var c = 0; c < row.length; c++) {
          final v = row[c];
          if (v.length < 2 || !v.startsWith('=')) continue;
          final shifted = shiftFormulaStructural(v.substring(1), op,
              currentSheet: s.name, targetSheet: name);
          if (shifted != v.substring(1)) row[c] = '=$shifted';
        }
      }
    }
    // Birleştirmeler.
    final merges = <XlsxMerge>[];
    for (final m in sheet.merges) {
      final r = shiftRange(XlsxRange(m.rowStart, m.colStart, m.rowEnd, m.colEnd), op);
      if (r == null) continue;
      if (r.r1 == r.r2 && r.c1 == r.c2) continue; // tek hücreye indi
      merges.add(XlsxMerge(r.r1, r.c1, r.r2, r.c2));
    }
    sheet.merges
      ..clear()
      ..addAll(merges);
    final l = sheet.layout;
    // Koşullu biçim (görünüm modeli).
    final rules = <XlsxCondRule>[];
    for (final rule in l.condFormats) {
      final ranges = [
        for (final r in rule.ranges) shiftRange(r, op),
      ].whereType<XlsxRange>().toList();
      if (ranges.isEmpty) continue;
      rules.add(XlsxCondRule(
        ranges: ranges,
        type: rule.type,
        formulas: [
          for (final f in rule.formulas)
            shiftAnchoredFormula(
                f, rule.ranges.first.r1, rule.ranges.first.c1, op, name),
        ],
        priority: rule.priority,
        operator: rule.operator,
        text: rule.text,
        dxfId: rule.dxfId,
        scaleColors: rule.scaleColors,
        scaleValues: rule.scaleValues,
        barColorArgb: rule.barColorArgb,
      ));
    }
    l.condFormats
      ..clear()
      ..addAll(rules);
    // Bu oturumda eklenen kurallar (kaydetmede yazılacak olanlar).
    final edits = <XlsxCondRuleWrite>[];
    for (final e in sheet.condRuleEdits) {
      final sq = shiftSqref(e.sqref, op);
      if (sq == null) continue;
      edits.add(XlsxCondRuleWrite(
        sqref: sq,
        type: e.type,
        operator: e.operator,
        formulas: [
          for (final f in e.formulas)
            () {
              final a = sqrefAnchor(e.sqref);
              return a == null
                  ? shiftFormulaStructural(f, op,
                      currentSheet: name, targetSheet: name)
                  : shiftAnchoredFormula(f, a.$1, a.$2, op, name);
            }(),
        ],
        text: e.text,
        fillArgb: e.fillArgb,
        fontArgb: e.fontArgb,
      ));
    }
    sheet.condRuleEdits
      ..clear()
      ..addAll(edits);
    // Doğrulamalar.
    final dvs = <XlsxDataValidation>[];
    for (final v in l.validations) {
      final ranges = [
        for (final r in v.ranges) shiftRange(r, op),
      ].whereType<XlsxRange>().toList();
      if (ranges.isEmpty) continue;
      dvs.add(XlsxDataValidation(
        type: v.type,
        ranges: ranges,
        formula1: v.formula1 == null
            ? null
            : shiftAnchoredFormula(
                v.formula1!, v.ranges.first.r1, v.ranges.first.c1, op, name),
        options: v.options,
        promptTitle: v.promptTitle,
        prompt: v.prompt,
      ));
    }
    l.validations
      ..clear()
      ..addAll(dvs);
    // Hücre anahtarlı haritalar: not, köprü, oturum biçimleri.
    _shiftCellKeys(l.comments, op);
    _shiftCellKeys(l.hyperlinks, op);
    _shiftCellKeys(sheet._overrides, op);
    _shiftPairKeys(sheet.numberFormatEdits, op);
    _shiftPairKeys(sheet.styleEdits, op);
    final copies = <(int, int), (int, int)>{};
    sheet.styleCopies.forEach((k, v) {
      final nk = _shiftPair(k, op), nv = _shiftPair(v, op);
      if (nk != null && nv != null) copies[nk] = nv;
    });
    sheet.styleCopies
      ..clear()
      ..addAll(copies);
    sheet._styleCache.clear();
    sheet.autoRowHeights.clear();
    // Süzgeç aralığı.
    final af = XlsxRange.parse(l.autoFilterRef);
    if (af != null) {
      final r = shiftRange(af, op);
      l.autoFilterRef = r == null ? null : XlsxSheet._rangeRef(r);
    }
    if (!op.rows) sheet.filterHidden.clear();
    sheet.structuralOps.add(op);
    sheet._touched();
    calcLog.bulk();
  }

  static (int, int)? _shiftPair((int, int) k, SheetShift op) {
    final x = op.point(op.rows ? k.$1 : k.$2);
    if (x == null) return null;
    return op.rows ? (x, k.$2) : (k.$1, x);
  }

  static void _shiftPairKeys<T>(Map<(int, int), T> map, SheetShift op) {
    final copy = <(int, int), T>{};
    map.forEach((k, v) {
      final nk = _shiftPair(k, op);
      if (nk != null) copy[nk] = v;
    });
    map
      ..clear()
      ..addAll(copy);
  }

  static void _shiftCellKeys<T>(Map<int, T> map, SheetShift op) {
    final copy = <int, T>{};
    map.forEach((k, v) {
      final nk = _shiftPair((k ~/ 16384, k % 16384), op);
      if (nk != null) copy[cellKey(nk.$1, nk.$2)] = v;
    });
    map
      ..clear()
      ..addAll(copy);
  }

  /// Yapısal işlemden ÖNCE: geri almanın tam olarak geri koyacağı her şey
  /// (bütün sayfaların formülleri + bu sayfanın aralıklı nesneleri).
  StructureSnapshot captureStructure(String sheetName) {
    final sheet = _modelSheet(sheetName);
    final formulas = <String, Map<(int, int), String>>{};
    for (final s in sheets) {
      final m = <(int, int), String>{};
      for (var r = 0; r < s.rows.length; r++) {
        final row = s.rows[r];
        for (var c = 0; c < row.length; c++) {
          if (row[c].startsWith('=')) m[(r, c)] = row[c];
        }
      }
      formulas[s.name] = m;
    }
    return StructureSnapshot._(
      sheetName,
      formulas,
      sheet == null ? const [] : List.of(sheet.merges),
      sheet == null ? const [] : List.of(sheet.layout.condFormats),
      sheet == null ? const [] : List.of(sheet.condRuleEdits),
      sheet == null ? const [] : List.of(sheet.layout.validations),
      sheet == null ? const {} : Map.of(sheet.layout.comments),
      sheet == null ? const {} : Map.of(sheet.layout.hyperlinks),
      sheet?.layout.autoFilterRef,
      sheet?.structuralOps.length ?? 0,
    );
  }

  /// [captureStructure] anındaki hâli geri koyar (ters yapısal işlem
  /// UYGULANDIKTAN sonra çağrılır).
  void restoreStructure(StructureSnapshot snap) {
    final sheet = _modelSheet(snap.sheet);
    calcLog.bulk();
    for (final s in sheets) {
      final m = snap.formulas[s.name];
      if (m == null) continue;
      // Hücreler kendi formülleriyle birlikte yer değiştirir; ters işlemden
      // sonra konumlar eskisiyle aynıdır — formül metinleri aynen geri.
      m.forEach((k, v) {
        while (s.rows.length <= k.$1) {
          s.rows.add(<String>[]);
        }
        final row = s.rows[k.$1];
        while (row.length <= k.$2) {
          row.add('');
        }
        row[k.$2] = v;
      });
    }
    if (sheet == null) return;
    sheet._touched();
    sheet.merges
      ..clear()
      ..addAll(snap.merges);
    sheet.layout.condFormats
      ..clear()
      ..addAll(snap.condFormats);
    sheet.condRuleEdits
      ..clear()
      ..addAll(snap.condRuleEdits);
    sheet.layout.validations
      ..clear()
      ..addAll(snap.validations);
    sheet.layout.comments
      ..clear()
      ..addAll(snap.comments);
    sheet.layout.hyperlinks
      ..clear()
      ..addAll(snap.hyperlinks);
    sheet.layout.autoFilterRef = snap.autoFilterRef;
    // Kayıttaki işlem günlüğü: işlem + tersi birbirini götürür.
    if (sheet.structuralOps.length > snap.opCount) {
      sheet.structuralOps.removeRange(snap.opCount, sheet.structuralOps.length);
    }
  }
}

/// [XlsxStructureEdit.captureStructure] sonucu.
class StructureSnapshot {
  final String sheet;
  final Map<String, Map<(int, int), String>> formulas;
  final List<XlsxMerge> merges;
  final List<XlsxCondRule> condFormats;
  final List<XlsxCondRuleWrite> condRuleEdits;
  final List<XlsxDataValidation> validations;
  final Map<int, XlsxComment> comments;
  final Map<int, String> hyperlinks;
  final String? autoFilterRef;
  final int opCount;
  const StructureSnapshot._(
    this.sheet,
    this.formulas,
    this.merges,
    this.condFormats,
    this.condRuleEdits,
    this.validations,
    this.comments,
    this.hyperlinks,
    this.autoFilterRef,
    this.opCount,
  );
}
