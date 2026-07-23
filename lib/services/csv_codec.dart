/// Bağımlılıksız CSV/TSV çözümleyici + üretici (RFC 4180).
///
/// *Niye:* CSV bir "Office" biçimidir ama uygulamada düz metin olarak açılıyordu
/// (satır/sütun yok). Burada CSV gerçek bir tabloya ([parse]) çözülür ve
/// tablodan geri üretilir ([encode]) — böylece elektronik tablo ızgarasında
/// gösterilebilir ve dışa aktarılabilir. Türkçe Excel çoğu zaman `;` ayracı
/// kullandığından ayraç [detectDelimiter] ile otomatik seçilir.
class CsvCodec {
  /// İlk dolu satıra bakarak ayracı tahmin eder: `,` `;` veya sekme.
  /// Tırnak içi ayraçlar sayılmaz. Hiçbiri yoksa `,` döner.
  static String detectDelimiter(String source) {
    // İlk gerçek (tırnak-dışı satır sonuyla biten) satırı al.
    final line = _firstRecordLine(source);
    final counts = <String, int>{',': 0, ';': 0, '\t': 0};
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && counts.containsKey(ch)) {
        counts[ch] = counts[ch]! + 1;
      }
    }
    var best = ',';
    var bestN = 0;
    counts.forEach((d, n) {
      if (n > bestN) {
        bestN = n;
        best = d;
      }
    });
    return best;
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
  static String encode(List<List<String>> rows, {String delimiter = ','}) {
    final sb = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final cells = rows[r];
      for (var c = 0; c < cells.length; c++) {
        if (c > 0) sb.write(delimiter);
        sb.write(_escape(cells[c], delimiter));
      }
      if (r < rows.length - 1) sb.write('\r\n');
    }
    return sb.toString();
  }

  static String _escape(String value, String delimiter) {
    final needs = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needs) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _firstRecordLine(String source) {
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      if (ch == '"') inQuotes = !inQuotes;
      if (!inQuotes && (ch == '\n' || ch == '\r')) {
        if (sb.isEmpty) continue; // baştaki boş satırları atla
        break;
      }
      sb.write(ch);
    }
    return sb.toString();
  }
}
