/// Excel'in **düzenleme çekirdeği**: geri al/yinele, aralık panosu, doldurma
/// serisi (fill handle) ve otomatik toplam.
///
/// **Neden ayrı ve saf Dart:** bu davranışların hepsi "gerçek Excel gibi mi"
/// sorusunun cevabı, yani kural yoğun ve kenar durumu bol. Ekrandan
/// (`spreadsheet_editor_screen`) ayrı tutulunca kuralların tamamı birim
/// testiyle kilitlenebiliyor (`test/sheet_edit_test.dart`); widget testinde
/// sürükle-bırak taklidiyle uğraşmak gerekmiyor.
library;

import 'dart:math' as math;

import '../core/undo_stack.dart';

export '../core/undo_stack.dart';

/// Bir hücrenin konumu (0 tabanlı).
class CellRef {
  final int row;
  final int col;
  const CellRef(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is CellRef && other.row == row && other.col == col;

  @override
  int get hashCode => row * 16384 + col;

  @override
  String toString() => '${colName(col)}${row + 1}';

  /// 0 tabanlı sütun indeksi → "A", "B", … "AA".
  static String colName(int index) {
    var n = index + 1;
    final out = <int>[];
    while (n > 0) {
      out.add(65 + (n - 1) % 26);
      n = (n - 1) ~/ 26;
    }
    return String.fromCharCodes(out.reversed);
  }
}

/// Dikdörtgen hücre aralığı (her iki uç dahil, 0 tabanlı).
class CellRange {
  final int top, left, bottom, right;
  const CellRange(this.top, this.left, this.bottom, this.right);

  /// İki köşeden normalleştirilmiş aralık (hangi köşenin çapa olduğu fark etmez).
  factory CellRange.between(int r1, int c1, int r2, int c2) => CellRange(
        math.min(r1, r2),
        math.min(c1, c2),
        math.max(r1, r2),
        math.max(c1, c2),
      );

  int get rows => bottom - top + 1;
  int get cols => right - left + 1;
  int get cellCount => rows * cols;
  bool contains(int r, int c) =>
      r >= top && r <= bottom && c >= left && c <= right;

  @override
  bool operator ==(Object other) =>
      other is CellRange &&
      other.top == top &&
      other.left == left &&
      other.bottom == bottom &&
      other.right == right;

  @override
  int get hashCode => Object.hash(top, left, bottom, right);

  @override
  String toString() =>
      '${CellRef(top, left)}:${CellRef(bottom, right)}';
}

// ─────────────────────────────────────────────────────────────────────────
// Formül başvurusu kaydırma
// ─────────────────────────────────────────────────────────────────────────

/// Formüldeki **göreli** A1 başvurularını [dRow]/[dCol] kadar kaydırır.
///
/// Excel'de bir formülü kopyalayıp başka hücreye yapıştırmak başvuruları
/// taşır (`=A1+B1` bir sağa yapıştırılınca `=B1+C1` olur); `$` ile
/// sabitlenmiş kısım taşınmaz. Doldurma tutamağı da aynı kuralı kullanır.
///
/// Metin sabitleri (`"A1"`) ve `SAYFA!A1` gibi sayfa nitelemeleri korunur;
/// nitelemedeki başvuru da kaydırılır (Excel öyle yapar). Kaydırma sayfayı
/// terk ederse (negatif satır/sütun) başvuru `#BAŞV!` olur.
String shiftFormula(String formula, int dRow, int dCol) {
  if (dRow == 0 && dCol == 0) return formula;
  final src = formula;
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final ch = src[i];
    // Metin sabiti: içine dokunma.
    if (ch == '"') {
      final end = _closingQuote(src, i);
      out.write(src.substring(i, end));
      i = end;
      continue;
    }
    // Tek tırnaklı sayfa adı ('Ocak Ayı'!A1) — adın içi başvuru değildir.
    if (ch == "'") {
      final end = _closingQuote(src, i, quote: "'");
      out.write(src.substring(i, end));
      i = end;
      continue;
    }
    final ref = _matchRef(src, i);
    if (ref == null) {
      out.write(ch);
      i++;
      continue;
    }
    out.write(_shiftOne(ref, dRow, dCol));
    i += ref.text.length;
  }
  return out.toString();
}

/// Kapanış tırnağına kadar olan aralığın BİTİŞ indeksi (tırnak dahil).
/// Kapanış yoksa metnin sonu döner — bozuk formülde döngüye girmemek için.
int _closingQuote(String s, int start, {String quote = '"'}) {
  var i = start + 1;
  while (i < s.length) {
    if (s[i] == quote) {
      // Excel'de tırnak tırnakla kaçırılır ("" / '').
      if (i + 1 < s.length && s[i + 1] == quote) {
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return s.length;
}

class _Ref {
  final String text;
  final bool colAbs, rowAbs;
  final String colLetters;
  final int rowNumber;
  const _Ref(
      this.text, this.colAbs, this.colLetters, this.rowAbs, this.rowNumber);
}

/// [at] konumunda `$A$1` biçiminde bir başvuru başlıyor mu?
///
/// Başvurudan hemen önce harf/rakam/`_` varsa bu bir başvuru DEĞİLDİR
/// (`TOPLA` içindeki `A` ya da `LOG10` gibi) — işlev adlarının içi bozulmasın.
_Ref? _matchRef(String s, int at) {
  if (at > 0) {
    final prev = s.codeUnitAt(at - 1);
    final isWord = (prev >= 65 && prev <= 90) ||
        (prev >= 97 && prev <= 122) ||
        (prev >= 48 && prev <= 57) ||
        prev == 0x5F;
    if (isWord) return null;
  }
  var i = at;
  var colAbs = false;
  if (i < s.length && s[i] == r'$') {
    colAbs = true;
    i++;
  }
  final letterStart = i;
  while (i < s.length && _isLetter(s.codeUnitAt(i))) {
    i++;
  }
  final letters = s.substring(letterStart, i);
  // Excel'in son sütunu XFD: 4+ harf başvuru değil, ad/işlevdir.
  if (letters.isEmpty || letters.length > 3) return null;
  var rowAbs = false;
  if (i < s.length && s[i] == r'$') {
    rowAbs = true;
    i++;
  }
  final digitStart = i;
  while (i < s.length && _isDigit(s.codeUnitAt(i))) {
    i++;
  }
  if (i == digitStart) return null;
  // Rakamlardan sonra harf geliyorsa ("A1B") başvuru değil.
  if (i < s.length && (_isLetter(s.codeUnitAt(i)) || s[i] == '_')) return null;
  // **Ardından `(` geliyorsa İŞLEV ADIDIR.** `LOG10(...)` tam bir başvuru
  // gibi görünür (LOG geçerli bir sütun, 10 geçerli bir satır); Excel de
  // ayrımı buradan yapar. Bu denetim olmadan `LOG10` → `LOG11` oluyordu.
  var j = i;
  while (j < s.length && s[j] == ' ') {
    j++;
  }
  if (j < s.length && s[j] == '(') return null;
  final row = int.tryParse(s.substring(digitStart, i));
  if (row == null || row < 1) return null;
  // Excel'in son sütunu XFD (16383); ötesi ad olabilir, başvuru değil.
  if (_colIndex(letters.toUpperCase()) > 16383) return null;
  return _Ref(s.substring(at, i), colAbs, letters.toUpperCase(), rowAbs, row);
}

bool _isLetter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
bool _isDigit(int c) => c >= 48 && c <= 57;

String _shiftOne(_Ref ref, int dRow, int dCol) {
  final col = ref.colAbs ? _colIndex(ref.colLetters) : _colIndex(ref.colLetters) + dCol;
  final row = ref.rowAbs ? ref.rowNumber - 1 : ref.rowNumber - 1 + dRow;
  if (col < 0 || row < 0 || col > 16383 || row > 1048575) return '#BAŞV!';
  return '${ref.colAbs ? r'$' : ''}${CellRef.colName(col)}'
      '${ref.rowAbs ? r'$' : ''}${row + 1}';
}

int _colIndex(String letters) {
  var n = 0;
  for (final u in letters.codeUnits) {
    n = n * 26 + (u - 64);
  }
  return n - 1;
}

// ─────────────────────────────────────────────────────────────────────────
// Pano (kes / kopyala / yapıştır)
// ─────────────────────────────────────────────────────────────────────────

/// Panoya alınmış dikdörtgen bir blok.
class SheetClip {
  /// Satır satır ham hücre değerleri (formüller `=` ile).
  final List<List<String>> values;

  /// Kaynak aralığın sol üst köşesi — formül başvurularını yapıştırırken
  /// kaydırmak için gerekir.
  final CellRef origin;

  /// Kesme mi (yapıştırdıktan sonra kaynak temizlenir)?
  final bool cut;

  const SheetClip({
    required this.values,
    required this.origin,
    this.cut = false,
  });

  int get rows => values.length;
  int get cols => values.fold(0, (m, r) => math.max(m, r.length));
  bool get isEmpty => values.isEmpty || cols == 0;

  /// Sekme/satırsonu ile ayrılmış metin — sistem panosuna bu gider, böylece
  /// başka uygulamalara (Excel dahil) yapıştırılabilir.
  String toTsv() => values.map((r) => r.join('\t')).join('\n');

  /// Sistem panosundan gelen metni bloka çevirir (Excel de TSV üretir).
  /// Boş metinde null döner.
  static SheetClip? fromTsv(String text, {CellRef origin = const CellRef(0, 0)}) {
    if (text.isEmpty) return null;
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    // Sondaki tek boş satır ayraçtır, veri değil.
    if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
    if (lines.isEmpty) return null;
    return SheetClip(
      values: [for (final l in lines) l.split('\t')],
      origin: origin,
    );
  }
}

/// Yapıştırma sonucu: hangi hücreye ne yazılacak.
///
/// Excel'in kuralı: hedef seçim kaynaktan BÜYÜK ve tam katıysa blok
/// tekrarlanır (2x2'yi 4x4'e yapıştırmak dört kopya yapar); değilse blok
/// hedefin sol üst köşesinden bir kez yazılır.
Map<CellRef, String> pasteCells(SheetClip clip, CellRange target) {
  final out = <CellRef, String>{};
  if (clip.isEmpty) return out;
  final repeatRows = _repeatCount(target.rows, clip.rows);
  final repeatCols = _repeatCount(target.cols, clip.cols);
  for (var br = 0; br < repeatRows; br++) {
    for (var bc = 0; bc < repeatCols; bc++) {
      for (var r = 0; r < clip.rows; r++) {
        final srcRow = clip.values[r];
        for (var c = 0; c < clip.cols; c++) {
          final destR = target.top + br * clip.rows + r;
          final destC = target.left + bc * clip.cols + c;
          final raw = c < srcRow.length ? srcRow[c] : '';
          out[CellRef(destR, destC)] = _movedValue(
            raw,
            // Kesmede formül taşınmaz: Excel kesip yapıştırınca başvurular
            // olduğu gibi kalır (taşıma, kopyalama değil).
            clip.cut ? 0 : destR - (clip.origin.row + r),
            clip.cut ? 0 : destC - (clip.origin.col + c),
          );
        }
      }
    }
  }
  return out;
}

int _repeatCount(int targetSize, int clipSize) =>
    clipSize > 0 && targetSize > clipSize && targetSize % clipSize == 0
        ? targetSize ~/ clipSize
        : 1;

String _movedValue(String raw, int dRow, int dCol) =>
    raw.startsWith('=') && raw.length > 1
        ? '=${shiftFormula(raw.substring(1), dRow, dCol)}'
        : raw;

// ─────────────────────────────────────────────────────────────────────────
// Doldurma tutamağı (fill handle)
// ─────────────────────────────────────────────────────────────────────────

/// Excel'in doldurma tutamağı: kaynak hücrelerden **seri** üretir.
///
/// Sıra (Excel'in davranışı):
/// 1. **Formül** → göreli başvurular kaydırılarak kopyalanır.
/// 2. **Sayı** → iki+ hücrede sabit fark varsa aritmetik seri; tek hücrede
///    KOPYALANIR (Excel de öyle: 5'i sürüklemek 5,5,5 verir).
/// 3. **ISO tarih** (`2026-08-02`) → gün/ay adımıyla ilerler; tek hücrede +1 gün.
/// 4. **Ay/gün adı** (TR + EN) → listede döner (Ocak → Şubat…).
/// 5. **Sonu sayıyla biten metin** (`Ürün 3`) → sayı ilerler; tek hücrede +1.
/// 6. Hiçbiri değilse kaynak blok **tekrarlanır**.
class FillSeries {
  const FillSeries._();

  /// [source] hücrelerinden [count] adet devam değeri üretir.
  ///
  /// **Sözleşme:** [source] daima ızgara sırasındadır (yukarıdan aşağı /
  /// soldan sağa) ve dönen liste de ızgara sırasındadır:
  /// - [backwards] false → bloğun ARDINDAKİ hücreler (aşağı/sağa sürükleme),
  /// - [backwards] true → bloğun ÖNÜNDEKİ hücreler (yukarı/sola sürükleme);
  ///   liste yine yukarıdan aşağıya döner, yani ilk eleman en uzak hücredir.
  ///
  /// [horizontal] sürükleme ekseni: formül başvuruları satır yerine sütun
  /// yönünde kaydırılır.
  static List<String> extend(List<String> source, int count,
      {bool backwards = false, bool horizontal = false}) {
    if (count <= 0) return const [];
    if (source.isEmpty) return List.filled(count, '');
    // İç hesap "gidiş yönünde" yapılır: seq[0] sürüklemenin başladığı uçtur.
    final seq = backwards ? source.reversed.toList() : source;

    final formulas = _formulaFill(seq, count, backwards, horizontal);
    if (formulas != null) return _sign(formulas, backwards);

    final numeric = _numericFill(seq, count);
    if (numeric != null) return _sign(numeric, backwards);

    final dates = _dateFill(seq, count);
    if (dates != null) return _sign(dates, backwards);

    final names = _nameListFill(seq, count);
    if (names != null) return _sign(names, backwards);

    final texts = _textNumberFill(seq, count);
    if (texts != null) return _sign(texts, backwards);

    // Desen yok: kaynağı tekrarla.
    return [for (var i = 0; i < count; i++) seq[i % seq.length]];
  }

  /// Geriye doğru üretilen liste, sürükleme yönünde (yukarıdan aşağıya)
  /// gösterileceği için ters çevrilir.
  static List<String> _sign(List<String> v, bool backwards) =>
      backwards ? v.reversed.toList() : v;

  /// Formül kopyalama.
  ///
  /// Gidiş yönünde `seq[k]` k. konumdadır; üretilen i. hücre `n + i`
  /// konumundadır ve `seq[i % n]`den türetilir. Kaydırma miktarı bu yüzden
  /// `(n + i) - (i % n)`, işareti de sürükleme yönü.
  static List<String>? _formulaFill(
      List<String> seq, int count, bool backwards, bool horizontal) {
    if (!seq.every((s) => s.startsWith('=') && s.length > 1)) return null;
    final n = seq.length;
    final sign = backwards ? -1 : 1;
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final delta = sign * ((n + i) - (i % n));
      out.add(_movedValue(
          seq[i % n], horizontal ? 0 : delta, horizontal ? delta : 0));
    }
    return out;
  }

  static List<String>? _numericFill(List<String> seq, int count) {
    final nums = <double>[];
    for (final s in seq) {
      final v = double.tryParse(s.trim());
      if (v == null) return null;
      nums.add(v);
    }
    // Tek sayı KOPYALANIR — Excel'de 5'i sürüklemek 5,5,5 verir (artırmak
    // için Ctrl gerekir; dokunmatikte o kip yok).
    if (nums.length == 1) return List.filled(count, _fmt(nums.first));
    final step = nums[1] - nums[0];
    for (var k = 2; k < nums.length; k++) {
      if ((nums[k] - nums[k - 1] - step).abs() > 1e-9) {
        // Sabit fark yoksa Excel de seri kurmaz, bloğu tekrarlar.
        return [for (var i = 0; i < count; i++) seq[i % seq.length]];
      }
    }
    return [
      for (var i = 0; i < count; i++) _fmt(nums.last + step * (i + 1)),
    ];
  }

  /// 12.0 → "12" (Excel tam sayıyı ondalıksız yazar), 1.5 → "1.5".
  static String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    var s = v.toStringAsFixed(10);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static List<String>? _dateFill(List<String> seq, int count) {
    final dates = <DateTime>[];
    for (final s in seq) {
      final m = _isoDate.firstMatch(s.trim());
      if (m == null) return null;
      dates.add(DateTime(
          int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
    }
    // Adım: tek hücrede +1 gün; iki+ hücrede aradaki gün farkı.
    final stepDays = dates.length == 1
        ? 1
        : dates[1].difference(dates[0]).inDays;
    if (dates.length > 2) {
      for (var i = 2; i < dates.length; i++) {
        if (dates[i].difference(dates[i - 1]).inDays != stepDays) return null;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        _isoOf(dates.last.add(Duration(days: stepDays * (i + 1)))),
    ];
  }

  static String _isoOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Ay ve gün adları — Excel'in yerleşik "özel listeleri"nin karşılığı.
  /// Türkçe ve İngilizce, uzun ve kısa biçim.
  static const _lists = <List<String>>[
    ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz',
      'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
    ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki',
      'Kas', 'Ara'],
    ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
    ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    ['January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'],
    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
      'Nov', 'Dec'],
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'],
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  ];

  static List<String>? _nameListFill(List<String> seq, int count) {
    for (final list in _lists) {
      final idx = <int>[];
      for (final s in seq) {
        final at = list.indexWhere((e) => _eq(e, s.trim()));
        if (at < 0) {
          idx.clear();
          break;
        }
        idx.add(at);
      }
      if (idx.isEmpty) continue;
      final step = idx.length == 1
          ? 1
          : ((idx[1] - idx[0]) % list.length + list.length) % list.length;
      final effective = step == 0 ? 1 : step;
      return [
        for (var i = 0; i < count; i++)
          list[(idx.last + effective * (i + 1)) % list.length],
      ];
    }
    return null;
  }

  /// Türkçe'ye duyarlı karşılaştırma (İ/ı tuzağı): `toUpperCase` Türkçe
  /// harflerde İngilizce kuralı uygular, o yüzden karakter eşlemesi elle.
  static bool _eq(String a, String b) => _fold(a) == _fold(b);

  static String _fold(String s) {
    const map = {
      'I': 'ı', 'İ': 'i', 'Ş': 'ş', 'Ğ': 'ğ', 'Ü': 'ü', 'Ö': 'ö', 'Ç': 'ç',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch.toLowerCase());
    }
    return buf.toString();
  }

  /// "Ürün 3", "Q4", "Hafta-2" gibi sonu sayıyla biten metin.
  static final _trailingNumber = RegExp(r'^(.*?)(\d+)$');

  static List<String>? _textNumberFill(List<String> seq, int count) {
    String? prefix;
    final nums = <int>[];
    var pad = 0;
    for (final s in seq) {
      final m = _trailingNumber.firstMatch(s);
      if (m == null) return null;
      final p = m[1]!;
      if (prefix == null) {
        prefix = p;
        pad = m[2]!.length;
      } else if (p != prefix) {
        return null;
      }
      nums.add(int.parse(m[2]!));
    }
    if (prefix == null) return null;
    // Yalnız sayıdan ibaret metin sayısal dala aittir (buraya düşerse
    // ondalık olmayan bir şeydir; yine de öncelik sayıda).
    final step = nums.length == 1 ? 1 : nums[1] - nums[0];
    if (nums.length > 2) {
      for (var i = 2; i < nums.length; i++) {
        if (nums[i] - nums[i - 1] != step) return null;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        '$prefix${_padded(nums.last + step * (i + 1), pad)}',
    ];
  }

  /// Baştaki sıfırlar korunur ("Q01" → "Q02").
  static String _padded(int v, int pad) =>
      v < 0 ? '$v' : v.toString().padLeft(pad, '0');
}

// ─────────────────────────────────────────────────────────────────────────
// Otomatik toplam (Σ)
// ─────────────────────────────────────────────────────────────────────────

/// Σ düğmesinin toplayacağı aralığı tahmin eder — Excel'in kuralı:
/// önce ÜSTTEKİ bitişik sayı bloğuna, o yoksa SOLDAKİ bloğa bakılır.
///
/// [isNumeric] verilen hücrenin sayı içerip içermediğini söyler (boş hücre
/// false döner). Uygun blok bulunamazsa null döner ve çağıran `=TOPLA()`
/// yazıp imleci içine koyabilir.
CellRange? autoSumRange(
  int row,
  int col,
  bool Function(int r, int c) isNumeric,
) {
  // Yukarı: hedefin hemen üstünden başlayıp sayı olmayana kadar çık.
  var r = row - 1;
  while (r >= 0 && isNumeric(r, col)) {
    r--;
  }
  if (r < row - 1) return CellRange(r + 1, col, row - 1, col);

  // Sola: hedefin hemen solundan başlayıp sayı olmayana kadar git.
  var c = col - 1;
  while (c >= 0 && isNumeric(row, c)) {
    c--;
  }
  if (c < col - 1) return CellRange(row, c + 1, row, col - 1);

  return null;
}

// ─────────────────────────────────────────────────────────────────────────
// Geri al / yinele
// ─────────────────────────────────────────────────────────────────────────

/// Excel'in geri alma adımı — ortak [UndoStep]in takma adı. Excel tarafındaki
/// çağıranlar (ve testleri) bu adla yazıldı; çekirdek `core/undo_stack.dart`e
/// taşınınca isim korundu.
typedef SheetUndoStep = UndoStep;

/// Excel'in geri alma yığını — ortak [UndoStack]in takma adı.
typedef SheetUndoStack = UndoStack;

/// Değer/stil gibi "önce-sonra" çiftleriyle tarif edilen genel adım.
class SheetValueStep implements SheetUndoStep {
  @override
  final String label;

  final Map<CellRef, String> before;
  final Map<CellRef, String> after;
  final void Function(CellRef at, String value) write;

  SheetValueStep({
    required this.label,
    required this.before,
    required this.after,
    required this.write,
  });

  @override
  void apply() => after.forEach(write);

  @override
  void revert() => before.forEach(write);

  /// Hiçbir hücre gerçekten değişmiyorsa adım yığına konmamalı —
  /// yoksa "geri al" bir kez boşa basar.
  bool get isNoop {
    if (after.length != before.length) return false;
    for (final e in after.entries) {
      if (before[e.key] != e.value) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sayı biçimi yardımcıları
// ─────────────────────────────────────────────────────────────────────────

/// Excel'in "Ondalık artır / azalt" düğmeleri.
///
/// Biçim kodundaki **sayı bölümünün** ondalık basamak sayısını [delta] kadar
/// değiştirir: `#,##0.00` → `#,##0.000`. Kod `General` ise sayı biçimi
/// verilmemiş demektir; Excel bu durumda `0.00`/`0` üretir.
///
/// Metin (`@`), tarih ve saat biçimlerinde ondalık kavramı yok — kod
/// değiştirilmeden döner.
String bumpDecimals(String formatCode, int delta) {
  final code = formatCode.trim();
  if (code.isEmpty || code == 'General') {
    final n = delta > 0 ? delta : 0;
    return n == 0 ? 'General' : '0.${'0' * n}';
  }
  if (code == '@' || _looksLikeDateTimeCode(code)) return formatCode;

  // Yalnız İLK bölüm (pozitif sayı bölümü) yeter: Excel de artır/azaltı
  // oradan yürütür ve diğer bölümleri aynı basamakla hizalar.
  final parts = code.split(';');
  final updated = parts.map((p) => _bumpSection(p, delta)).toList();
  return updated.join(';');
}

String _bumpSection(String section, int delta) {
  final dot = section.indexOf('.');
  if (dot < 0) {
    if (delta <= 0) return section;
    // Ondalık yok: sayı kalıbının hemen ardına eklenir.
    final at = _numericEnd(section);
    if (at < 0) return section;
    return '${section.substring(0, at)}.${'0' * delta}${section.substring(at)}';
  }
  var end = dot + 1;
  while (end < section.length &&
      (section[end] == '0' || section[end] == '#')) {
    end++;
  }
  final digits = end - dot - 1 + delta;
  if (digits <= 0) {
    return section.substring(0, dot) + section.substring(end);
  }
  return section.substring(0, dot + 1) +
      '0' * digits +
      section.substring(end);
}

/// Sayı kalıbının (`0`, `#`, `,`) bittiği konum; yoksa -1.
int _numericEnd(String s) {
  var last = -1;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '0' || ch == '#') last = i;
  }
  return last < 0 ? -1 : last + 1;
}

/// Kod tarih/saat mi?
///
/// Yalnız **kalıp** bölümündeki `y`/`d`/`h`/`s` harfleri sayılır. Atlanması
/// gerekenler:
/// - tırnak içi sabit metin (`"adet"`),
/// - **köşeli parantezli belirteçler** (`[Red]`, `[Kırmızı]`, `[h]`) — `[Red]`
///   içindeki `d` yüzünden `#,##0.00;[Red]-#,##0.00` tarih sanılıyordu ve
///   ondalık artır/azalt o kodda hiç çalışmıyordu,
/// - ters eğik çizgiyle kaçırılmış tek karakter (`\d`).
bool _looksLikeDateTimeCode(String code) {
  var i = 0;
  while (i < code.length) {
    final ch = code[i];
    if (ch == '"') {
      i = _closingQuote(code, i);
      continue;
    }
    if (ch == '[') {
      final end = code.indexOf(']', i);
      i = end < 0 ? code.length : end + 1;
      continue;
    }
    if (ch == r'\') {
      i += 2;
      continue;
    }
    if ('ydhs'.contains(ch.toLowerCase())) return true;
    i++;
  }
  return false;
}
