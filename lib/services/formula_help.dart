/// Formül yazarken yardım (Faz 25 / madde 5–6, 2026-10-23):
/// * **bağımsız değişken ipucu** — imlecin içinde bulunduğu işlev ve kaçıncı
///   bağımsız değişkende olduğu (`DÜŞEYARA(aranan_değer; **tablo_dizisi**; …)`);
/// * **işlev kitaplığı** — kategorili liste (fx düğmesi);
/// * **formüldeki başvurular** — her birinin metindeki yeri ve aralığı
///   (renkli başvurular + ızgarada aynı renkte çerçeve, Excel'in "aralık
///   bulucusu").
library;

import 'formula_engine.dart';
import 'xlsx_reader.dart' show XlsxRange;

/// İşlev kategorisi (Excel'in işlev kitaplığı sırasıyla).
enum FormulaCategory { recent, financial, logical, text, dateTime, lookup, math, statistical }

/// Bir işlevin imzası: bağımsız değişken adları (Türkçe / İngilizce) ve kısa
/// açıklama anahtarı. `[ad]` isteğe bağlı, `…` tekrarlanabilir.
class FormulaSignature {
  final String name; // İngilizce kanonik ad
  final FormulaCategory category;
  final List<String> argsTr;
  final List<String> argsEn;
  const FormulaSignature(this.name, this.category, this.argsTr, this.argsEn);
}

const _sig = <FormulaSignature>[
  FormulaSignature('SUM', FormulaCategory.math, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('AVERAGE', FormulaCategory.statistical, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('COUNT', FormulaCategory.statistical, ['değer1', '[değer2]', '…'], ['value1', '[value2]', '…']),
  FormulaSignature('COUNTA', FormulaCategory.statistical, ['değer1', '[değer2]', '…'], ['value1', '[value2]', '…']),
  FormulaSignature('MAX', FormulaCategory.statistical, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('MIN', FormulaCategory.statistical, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('MEDIAN', FormulaCategory.statistical, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('COUNTIF', FormulaCategory.statistical, ['aralık', 'ölçüt'], ['range', 'criteria']),
  FormulaSignature('COUNTIFS', FormulaCategory.statistical, ['ölçüt_aralığı1', 'ölçüt1', '…'], ['criteria_range1', 'criteria1', '…']),
  FormulaSignature('SUMIF', FormulaCategory.math, ['aralık', 'ölçüt', '[toplam_aralığı]'], ['range', 'criteria', '[sum_range]']),
  FormulaSignature('SUMIFS', FormulaCategory.math, ['toplam_aralığı', 'ölçüt_aralığı1', 'ölçüt1', '…'], ['sum_range', 'criteria_range1', 'criteria1', '…']),
  FormulaSignature('AVERAGEIF', FormulaCategory.statistical, ['aralık', 'ölçüt', '[ortalama_aralığı]'], ['range', 'criteria', '[average_range]']),
  FormulaSignature('ROUND', FormulaCategory.math, ['sayı', 'sayı_rakamlar'], ['number', 'num_digits']),
  FormulaSignature('ROUNDUP', FormulaCategory.math, ['sayı', 'sayı_rakamlar'], ['number', 'num_digits']),
  FormulaSignature('ROUNDDOWN', FormulaCategory.math, ['sayı', 'sayı_rakamlar'], ['number', 'num_digits']),
  FormulaSignature('ABS', FormulaCategory.math, ['sayı'], ['number']),
  FormulaSignature('SQRT', FormulaCategory.math, ['sayı'], ['number']),
  FormulaSignature('POWER', FormulaCategory.math, ['sayı', 'üs'], ['number', 'power']),
  FormulaSignature('MOD', FormulaCategory.math, ['sayı', 'bölen'], ['number', 'divisor']),
  FormulaSignature('INT', FormulaCategory.math, ['sayı'], ['number']),
  FormulaSignature('PRODUCT', FormulaCategory.math, ['sayı1', '[sayı2]', '…'], ['number1', '[number2]', '…']),
  FormulaSignature('SUMPRODUCT', FormulaCategory.math, ['dizi1', '[dizi2]', '…'], ['array1', '[array2]', '…']),
  FormulaSignature('IF', FormulaCategory.logical, ['mantıksal_sınama', '[eğer_doğruysa_değer]', '[eğer_yanlışsa_değer]'], ['logical_test', '[value_if_true]', '[value_if_false]']),
  FormulaSignature('IFS', FormulaCategory.logical, ['mantıksal_sınama1', 'doğruysa_değer1', '…'], ['logical_test1', 'value_if_true1', '…']),
  FormulaSignature('IFERROR', FormulaCategory.logical, ['değer', 'eğer_hataysa_değer'], ['value', 'value_if_error']),
  FormulaSignature('AND', FormulaCategory.logical, ['mantıksal1', '[mantıksal2]', '…'], ['logical1', '[logical2]', '…']),
  FormulaSignature('OR', FormulaCategory.logical, ['mantıksal1', '[mantıksal2]', '…'], ['logical1', '[logical2]', '…']),
  FormulaSignature('NOT', FormulaCategory.logical, ['mantıksal'], ['logical']),
  FormulaSignature('VLOOKUP', FormulaCategory.lookup, ['aranan_değer', 'tablo_dizisi', 'sütun_indis_sayısı', '[aralık_bak]'], ['lookup_value', 'table_array', 'col_index_num', '[range_lookup]']),
  FormulaSignature('HLOOKUP', FormulaCategory.lookup, ['aranan_değer', 'tablo_dizisi', 'satır_indis_sayısı', '[aralık_bak]'], ['lookup_value', 'table_array', 'row_index_num', '[range_lookup]']),
  FormulaSignature('XLOOKUP', FormulaCategory.lookup, ['aranan_değer', 'aranan_dizi', 'döndürülen_dizi', '[bulunamazsa]', '[eşleştirme_modu]', '[arama_modu]'], ['lookup_value', 'lookup_array', 'return_array', '[if_not_found]', '[match_mode]', '[search_mode]']),
  FormulaSignature('INDEX', FormulaCategory.lookup, ['dizi', 'satır_sayısı', '[sütun_sayısı]'], ['array', 'row_num', '[column_num]']),
  FormulaSignature('MATCH', FormulaCategory.lookup, ['aranan_değer', 'aranan_dizi', '[eşleştir_tür]'], ['lookup_value', 'lookup_array', '[match_type]']),
  FormulaSignature('LEN', FormulaCategory.text, ['metin'], ['text']),
  FormulaSignature('LEFT', FormulaCategory.text, ['metin', '[sayı_karakterler]'], ['text', '[num_chars]']),
  FormulaSignature('RIGHT', FormulaCategory.text, ['metin', '[sayı_karakterler]'], ['text', '[num_chars]']),
  FormulaSignature('MID', FormulaCategory.text, ['metin', 'başlangıç_sayısı', 'sayı_karakterler'], ['text', 'start_num', 'num_chars']),
  FormulaSignature('CONCATENATE', FormulaCategory.text, ['metin1', '[metin2]', '…'], ['text1', '[text2]', '…']),
  FormulaSignature('TEXTJOIN', FormulaCategory.text, ['sınırlayıcı', 'boşu_yoksay', 'metin1', '…'], ['delimiter', 'ignore_empty', 'text1', '…']),
  FormulaSignature('TRIM', FormulaCategory.text, ['metin'], ['text']),
  FormulaSignature('UPPER', FormulaCategory.text, ['metin'], ['text']),
  FormulaSignature('LOWER', FormulaCategory.text, ['metin'], ['text']),
  FormulaSignature('SUBSTITUTE', FormulaCategory.text, ['metin', 'eski_metin', 'yeni_metin', '[yineleme_sayısı]'], ['text', 'old_text', 'new_text', '[instance_num]']),
  FormulaSignature('TEXT', FormulaCategory.text, ['değer', 'biçim_metni'], ['value', 'format_text']),
  FormulaSignature('VALUE', FormulaCategory.text, ['metin'], ['text']),
  FormulaSignature('FIND', FormulaCategory.text, ['bul_metin', 'metin_içinde', '[başlangıç_sayısı]'], ['find_text', 'within_text', '[start_num]']),
  FormulaSignature('TODAY', FormulaCategory.dateTime, [], []),
  FormulaSignature('NOW', FormulaCategory.dateTime, [], []),
  FormulaSignature('DATE', FormulaCategory.dateTime, ['yıl', 'ay', 'gün'], ['year', 'month', 'day']),
  FormulaSignature('YEAR', FormulaCategory.dateTime, ['seri_no'], ['serial_number']),
  FormulaSignature('MONTH', FormulaCategory.dateTime, ['seri_no'], ['serial_number']),
  FormulaSignature('DAY', FormulaCategory.dateTime, ['seri_no'], ['serial_number']),
  FormulaSignature('WEEKDAY', FormulaCategory.dateTime, ['seri_no', '[döndür_tür]'], ['serial_number', '[return_type]']),
  FormulaSignature('DATEDIF', FormulaCategory.dateTime, ['başlangıç_tarihi', 'bitiş_tarihi', 'birim'], ['start_date', 'end_date', 'unit']),
  FormulaSignature('EOMONTH', FormulaCategory.dateTime, ['başlangıç_tarihi', 'aylar'], ['start_date', 'months']),
  FormulaSignature('NETWORKDAYS', FormulaCategory.dateTime, ['başlangıç_tarihi', 'bitiş_tarihi', '[tatiller]'], ['start_date', 'end_date', '[holidays]']),
  FormulaSignature('PMT', FormulaCategory.financial, ['oran', 'dönem_sayısı', 'bd', '[gd]', '[tür]'], ['rate', 'nper', 'pv', '[fv]', '[type]']),
  FormulaSignature('FV', FormulaCategory.financial, ['oran', 'dönem_sayısı', 'devresel_ödeme', '[bd]', '[tür]'], ['rate', 'nper', 'pmt', '[pv]', '[type]']),
  FormulaSignature('PV', FormulaCategory.financial, ['oran', 'dönem_sayısı', 'devresel_ödeme', '[gd]', '[tür]'], ['rate', 'nper', 'pmt', '[fv]', '[type]']),
  FormulaSignature('NPV', FormulaCategory.financial, ['oran', 'değer1', '…'], ['rate', 'value1', '…']),
  FormulaSignature('IRR', FormulaCategory.financial, ['değerler', '[tahmin]'], ['values', '[guess]']),
  FormulaSignature('RATE', FormulaCategory.financial, ['dönem_sayısı', 'devresel_ödeme', 'bd', '[gd]', '[tür]', '[tahmin]'], ['nper', 'pmt', 'pv', '[fv]', '[type]', '[guess]']),
];

final Map<String, FormulaSignature> _byName = {for (final s in _sig) s.name: s};

/// İmzası bilinen işlevler, kategoriye göre (fx kitaplığı).
Map<FormulaCategory, List<FormulaSignature>> formulaLibrary() {
  final out = <FormulaCategory, List<FormulaSignature>>{};
  for (final s in _sig) {
    out.putIfAbsent(s.category, () => []).add(s);
  }
  return out;
}

/// Kanonik (İngilizce) ad → imza; Türkçe adla da bulunur.
FormulaSignature? signatureOf(String name) {
  final canon = FormulaEngine.canonicalName(name);
  return _byName[canon];
}

/// İmlecin içinde bulunduğu işlev çağrısı: (ad, bağımsız değişken sırası).
/// Tırnak içi metin ve iç içe parantezler dikkate alınır.
(String, int)? activeCall(String formula, int caret) {
  final stack = <(String?, int)>[]; // (işlev adı | null=parantez, arg sırası)
  var i = 0;
  final end = caret.clamp(0, formula.length);
  while (i < end) {
    final ch = formula[i];
    if (ch == '"') {
      i++;
      while (i < end && formula[i] != '"') {
        i++;
      }
      i++;
      continue;
    }
    if (ch == '(') {
      var j = i - 1;
      while (j >= 0 && _nameChar(formula[j])) {
        j--;
      }
      final name = formula.substring(j + 1, i);
      stack.add((name.isEmpty ? null : name, 0));
    } else if (ch == ')') {
      if (stack.isNotEmpty) stack.removeLast();
    } else if ((ch == ';' || ch == ',') && stack.isNotEmpty) {
      final top = stack.removeLast();
      stack.add((top.$1, top.$2 + 1));
    }
    i++;
  }
  for (var k = stack.length - 1; k >= 0; k--) {
    final name = stack[k].$1;
    if (name != null) return (name, stack[k].$2);
  }
  return null;
}

bool _nameChar(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || (u >= 48 && u <= 57) ||
      u == 95 || u == 46 || u > 127;
}

/// Formüldeki bir başvuru: metindeki yeri, sayfası (null = aynı sayfa) ve
/// aralığı.
class FormulaRef {
  final int start, end;
  final String? sheet;
  final XlsxRange range;
  const FormulaRef(this.start, this.end, this.sheet, this.range);
}

final _refRe = RegExp(
    r"(?:('(?:[^']|'')+'|[A-Za-z_\u0080-￿][\w.\u0080-￿]*)!)?(\$?[A-Za-z]{1,3}\$?\d{1,7})(?::(\$?[A-Za-z]{1,3}\$?\d{1,7}))?");

/// Formül metnindeki hücre/aralık başvuruları (tırnak içi hariç).
List<FormulaRef> formulaRefs(String formula) {
  final out = <FormulaRef>[];
  var i = 0;
  while (i < formula.length) {
    final ch = formula[i];
    if (ch == '"') {
      i++;
      while (i < formula.length && formula[i] != '"') {
        i++;
      }
      i++;
      continue;
    }
    if (i > 0 && _nameChar(formula[i - 1]) && ch != r'$') {
      i++;
      continue;
    }
    final m = _refRe.matchAsPrefix(formula, i);
    if (m != null) {
      final after = m.end < formula.length ? formula[m.end] : '';
      if (after != '(' && !(after.isNotEmpty && _nameChar(after))) {
        final a = XlsxRange.cellRef(m.group(2));
        final b = m.group(3) == null ? a : XlsxRange.cellRef(m.group(3));
        if (a != null && b != null) {
          var sheet = m.group(1);
          if (sheet != null && sheet.startsWith("'")) {
            sheet = sheet.substring(1, sheet.length - 1).replaceAll("''", "'");
          }
          out.add(FormulaRef(
            m.start,
            m.end,
            sheet,
            XlsxRange(
              a.$1 < b.$1 ? a.$1 : b.$1,
              a.$2 < b.$2 ? a.$2 : b.$2,
              a.$1 > b.$1 ? a.$1 : b.$1,
              a.$2 > b.$2 ? a.$2 : b.$2,
            ),
          ));
          i = m.end;
          continue;
        }
      }
    }
    i++;
  }
  return out;
}

/// `A1 → $A$1 → A$1 → $A1 → A1` (masaüstü Excel'in F4'ü). Metindeki
/// [caret]'e değen başvuruyu çevirir; yeni metin ve imleç.
(String, int)? cycleAbsolute(String formula, int caret) {
  for (final r in formulaRefs(formula)) {
    if (caret < r.start || caret > r.end) continue;
    final text = formula.substring(r.start, r.end);
    final bang = text.lastIndexOf('!');
    final prefix = bang < 0 ? '' : text.substring(0, bang + 1);
    final body = bang < 0 ? text : text.substring(bang + 1);
    String cycle(String cell) {
      final m = RegExp(r'^(\$?)([A-Za-z]{1,3})(\$?)(\d+)$').firstMatch(cell)!;
      final c = m.group(2)!, n = m.group(4)!;
      final colAbs = m.group(1) == r'$', rowAbs = m.group(3) == r'$';
      if (!colAbs && !rowAbs) return '\$$c\$$n';
      if (colAbs && rowAbs) return '$c\$$n';
      if (!colAbs && rowAbs) return '\$$c$n';
      return '$c$n';
    }

    final next = prefix + body.split(':').map(cycle).join(':');
    final out = formula.replaceRange(r.start, r.end, next);
    return (out, r.start + next.length);
  }
  return null;
}
