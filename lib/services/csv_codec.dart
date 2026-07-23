/// Bağımlılıksız CSV/TSV çözümleyici + üretici (RFC 4180).
///
/// *Niye:* CSV bir "Office" biçimidir ama uygulamada düz metin olarak açılıyordu
/// (satır/sütun yok). Burada CSV gerçek bir tabloya ([parse]) çözülür ve
/// tablodan geri üretilir ([encode]) — böylece elektronik tablo ızgarasında
/// gösterilebilir ve dışa aktarılabilir. Türkçe Excel çoğu zaman `;` ayracı
/// kullandığından ayraç [detectDelimiter] ile otomatik seçilir.
class CsvCodec {
  /// Ayracı tahmin eder: `,` `;` sekme veya `|`. İlk ~5 satırdaki tırnak-dışı
  /// ayraç sayısına bakar (tek satır yanıltıcı olabilir — başlıkta tırnaklı
  /// virgül gibi). Hiçbiri yoksa `,`. Türkçe Excel çoğu zaman `;` kullanır.
  static String detectDelimiter(String source) {
    final lines = _firstRecordLines(source, 5);
    const cands = [',', ';', '\t', '|'];
    var best = ',';
    var bestScore = -1.0;
    for (final d in cands) {
      final counts = [for (final l in lines) _countOutsideQuotes(l, d)];
      final total = counts.fold<int>(0, (a, b) => a + b);
      if (total == 0) continue;
      // Tutarlılık: her satırda aynı sayıda ayraç varsa gerçek ayraç odur.
      final first = counts.first;
      final consistent =
          counts.where((n) => n == first).length / counts.length;
      final score = total + consistent * 10;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  static int _countOutsideQuotes(String line, String delim) {
    var n = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && ch == delim) {
        n++;
      }
    }
    return n;
  }

  /// CSV metnini satır/sütun tablosuna çözer. [delimiter] verilmezse otomatik
  /// saptanır. RFC 4180: tırnaklı alan, `""` kaçışı, alan içinde ayraç/yeni satır.
  static List<List<String>> parse(String source, {String? delimiter}) {
    final delim = delimiter ?? detectDelimiter(source);
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    var fieldStarted = false;

    void endField() {
      row.add(field.toString());
      field = StringBuffer();
      fieldStarted = false;
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    final n = source.length;
    var i = 0;
    while (i < n) {
      final ch = source[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < n && source[i + 1] == '"') {
            field.write('"'); // kaçırılmış tırnak
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.write(ch);
        i++;
        continue;
      }

      if (ch == '"' && !fieldStarted) {
        inQuotes = true;
        fieldStarted = true;
        i++;
        continue;
      }
      if (ch == delim) {
        endField();
        i++;
        continue;
      }
      if (ch == '\r') {
        // \r\n veya tek \r satır sonu.
        endRow();
        if (i + 1 < n && source[i + 1] == '\n') i++;
        i++;
        continue;
      }
      if (ch == '\n') {
        endRow();
        i++;
        continue;
      }
      field.write(ch);
      fieldStarted = true;
      i++;
    }

    // Son alan/satır (dosya yeni satırla bitmiyorsa).
    if (field.isNotEmpty || row.isNotEmpty || inQuotes) {
      endRow();
    }

    // Tümüyle boş sondaki satırı (yalnız tek boş hücre) at.
    if (rows.isNotEmpty &&
        rows.last.length == 1 &&
        rows.last.first.isEmpty) {
      rows.removeLast();
    }
    return rows;
  }

  /// Tabloyu CSV metnine çevirir. Ayraç/tırnak/yeni satır içeren alanlar
  /// otomatik tırnaklanır (`"` → `""`). Satır sonu `\r\n` (Excel uyumu).
  ///
  /// [sanitizeFormulas] açıkken `=`/`@` (ve sayı olmayan `+`/`-`) ile başlayan
  /// hücreler başına `'` konur → Excel bunu formül sanıp çalıştırmaz (CSV
  /// enjeksiyonu önlemi). Güvenilmez kaynaktan (ör. AI çıktısı) üretimde açılır;
  /// kullanıcının kendi formüllerini korumak için varsayılan kapalı.
  static String encode(
    List<List<String>> rows, {
    String delimiter = ',',
    bool sanitizeFormulas = false,
  }) {
    final sb = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final cells = rows[r];
      for (var c = 0; c < cells.length; c++) {
        if (c > 0) sb.write(delimiter);
        final v = sanitizeFormulas ? _sanitize(cells[c]) : cells[c];
        sb.write(_escape(v, delimiter));
      }
      if (r < rows.length - 1) sb.write('\r\n');
    }
    return sb.toString();
  }

  static String _sanitize(String v) {
    if (v.isEmpty) return v;
    final c = v[0];
    final risky = c == '=' ||
        c == '@' ||
        c == '\t' ||
        c == '\r' ||
        ((c == '+' || c == '-') && double.tryParse(v) == null);
    return risky ? "'$v" : v;
  }

  static String _escape(String value, String delimiter) {
    final needs = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needs) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// İlk [max] mantıksal satırı (tırnak-dışı satır sonuyla ayrılan) döndürür.
  static List<String> _firstRecordLines(String source, int max) {
    final lines = <String>[];
    var sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < source.length && lines.length < max; i++) {
      final ch = source[i];
      if (ch == '"') inQuotes = !inQuotes;
      if (!inQuotes && (ch == '\n' || ch == '\r')) {
        if (sb.isEmpty) continue; // baştaki/ardışık boş satırları atla
        lines.add(sb.toString());
        sb = StringBuffer();
        continue;
      }
      sb.write(ch);
    }
    if (sb.isNotEmpty && lines.length < max) lines.add(sb.toString());
    return lines.isEmpty ? [''] : lines;
  }
}
