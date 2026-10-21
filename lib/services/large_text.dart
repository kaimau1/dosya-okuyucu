import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'text_decode.dart';

/// Büyük metin dosyasının kodlaması (parça parça çözmek için önceden bilinmeli).
enum LargeTextEncoding { utf8, cp1254, utf16le, utf16be }

/// **Büyük metin dosyasını parça parça okuma** (Faz 9 — §3.10 "Metin").
///
/// Eskiden her metin dosyası TEK SEFERDE belleğe okunup tek bir `TextField`e
/// veriliyordu. 50 MB'lık bir kayıt dosyası = 50 MB bayt + ~100 MB UTF-16
/// dize + `TextField`in satır düzeni: düşük donanımlı telefonda donma ya da
/// bellekten çökme. [threshold]'u aşan dosyada artık yalnız **satır başı
/// konumları** çıkarılır (izolatta, akış hâlinde — dosya hiçbir an bütün
/// olarak bellekte değil) ve ekran yalnız görünen satırları diskten okur.
///
/// Bedeli bilinçli: büyük dosya **salt okunur** açılır. 5 MB'ı aşan bir
/// metni telefonda elle düzenlemek gerçekçi bir senaryo değil; yanlışlıkla
/// tek tuşla 50 MB'lık dosyanın üzerine yazmak ise gerçek bir risk.
class LargeTextFile {
  /// Bu boyuttan büyük metin dosyaları parçalı açılır.
  static const threshold = 5 * 1024 * 1024;

  final String path;
  final LargeTextEncoding encoding;
  final int length;

  /// Her satırın dosyadaki başlangıç baytı; son öğe dosya sonu (satır sayısı
  /// = `starts.length - 1`).
  final List<int> _starts;

  LargeTextFile._(this.path, this.encoding, this.length, this._starts);

  int get lineCount => _starts.length - 1;

  /// Kodlamanın ekranda gösterilecek adı.
  String get encodingLabel => switch (encoding) {
        LargeTextEncoding.utf8 => 'UTF-8',
        LargeTextEncoding.cp1254 => 'Windows-1254',
        LargeTextEncoding.utf16le => 'UTF-16 LE',
        LargeTextEncoding.utf16be => 'UTF-16 BE',
      };

  /// Dizini izolatta kurar (ana izlek disk G/Ç'si ve tarama görmez).
  static Future<LargeTextFile> open(String path) async {
    try {
      return await Isolate.run(() => openSync(path));
    } on IsolateSpawnException {
      return openSync(path);
    }
  }

  /// [open]'ın eşzamanlı gövdesi (testler ve izolat kurulamayan ortam için).
  static LargeTextFile openSync(String path) {
    final raf = File(path).openSync();
    try {
      final length = raf.lengthSync();
      final head = raf.readSync(length < 65536 ? length : 65536);
      final encoding = detectEncoding(head);
      final wide = encoding == LargeTextEncoding.utf16le ||
          encoding == LargeTextEncoding.utf16be;
      // BOM satırın parçası değil: ilk satır ondan SONRA başlar.
      var first = 0;
      if (wide && head.length >= 2) first = 2;
      if (!wide &&
          head.length >= 3 &&
          head[0] == 0xEF &&
          head[1] == 0xBB &&
          head[2] == 0xBF) {
        first = 3;
      }
      final starts = <int>[first];
      raf.setPositionSync(0);
      const chunk = 1 << 20;
      var offset = 0;
      // UTF-16'da satır sonu iki bayttır ve parça sınırına düşebilir: bir
      // önceki parçanın son baytı taşınır.
      int? carry;
      while (offset < length) {
        final data = raf.readSync(chunk);
        if (data.isEmpty) break;
        if (!wide) {
          for (var i = 0; i < data.length; i++) {
            if (data[i] == 0x0A) starts.add(offset + i + 1);
          }
        } else {
          var i = 0;
          if (carry != null) {
            final lo = encoding == LargeTextEncoding.utf16le ? carry : data[0];
            final hi = encoding == LargeTextEncoding.utf16le ? data[0] : carry;
            if (lo == 0x0A && hi == 0) starts.add(offset + 1);
            carry = null;
            i = 1;
          }
          // Kod birimleri `first`ten itibaren çift konumlarda.
          if ((offset + i - first).isOdd) i++;
          for (; i + 1 < data.length; i += 2) {
            final lo =
                encoding == LargeTextEncoding.utf16le ? data[i] : data[i + 1];
            final hi =
                encoding == LargeTextEncoding.utf16le ? data[i + 1] : data[i];
            if (lo == 0x0A && hi == 0) starts.add(offset + i + 2);
          }
          if (i < data.length) carry = data[i];
        }
        offset += data.length;
      }
      // Dosya satır sonuyla bitmiyorsa son satırın sonu dosya sonudur;
      // bitiyorsa sondaki boş "satır" sayılmaz.
      if (starts.last != length) {
        starts.add(length);
      }
      return LargeTextFile._(path, encoding, length, starts);
    } finally {
      raf.closeSync();
    }
  }

  /// Baştaki örnekten kodlamayı sezer: BOM → UTF-16 / UTF-8; BOM yoksa
  /// katı UTF-8 denenir, olmazsa Windows-1254 (Türkçe — [TextDecode] ile aynı
  /// kural). Örnek bir çok-baytlı harfin ortasında kesilmiş olabilir: son
  /// satır sonuna kadar olan kısım denenir.
  static LargeTextEncoding detectEncoding(List<int> head) {
    if (head.length >= 2 && head[0] == 0xFF && head[1] == 0xFE) {
      return LargeTextEncoding.utf16le;
    }
    if (head.length >= 2 && head[0] == 0xFE && head[1] == 0xFF) {
      return LargeTextEncoding.utf16be;
    }
    var end = head.length;
    final nl = head.lastIndexOf(0x0A);
    if (nl > 0) end = nl;
    try {
      utf8.decode(head.sublist(0, end));
      return LargeTextEncoding.utf8;
    } on FormatException {
      return LargeTextEncoding.cp1254;
    }
  }

  /// [start]'tan itibaren en çok [count] satırı okur (satır sonları atılmış).
  Future<List<String>> lines(int start, int count) async {
    if (start < 0 || start >= lineCount || count <= 0) return const [];
    final end = (start + count).clamp(0, lineCount);
    final from = _starts[start];
    final to = _starts[end];
    final raf = await File(path).open();
    try {
      await raf.setPosition(from);
      final bytes = await raf.read(to - from);
      final out = <String>[];
      for (var k = start; k < end; k++) {
        out.add(_decodeLine(bytes, _starts[k] - from, _starts[k + 1] - from));
      }
      return out;
    } finally {
      await raf.close();
    }
  }

  String _decodeLine(Uint8List bytes, int a, int b) {
    switch (encoding) {
      case LargeTextEncoding.utf8:
      case LargeTextEncoding.cp1254:
        var e = b;
        if (e > a && bytes[e - 1] == 0x0A) e--;
        if (e > a && bytes[e - 1] == 0x0D) e--;
        final slice = Uint8List.sublistView(bytes, a, e);
        return encoding == LargeTextEncoding.utf8
            ? utf8.decode(slice, allowMalformed: true)
            : TextDecode.decodeCp1254(slice);
      case LargeTextEncoding.utf16le:
      case LargeTextEncoding.utf16be:
        final le = encoding == LargeTextEncoding.utf16le;
        final units = <int>[];
        for (var i = a; i + 1 < b; i += 2) {
          units.add(le
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1]);
        }
        if (units.isNotEmpty && units.last == 0x0A) units.removeLast();
        if (units.isNotEmpty && units.last == 0x0D) units.removeLast();
        return String.fromCharCodes(units);
    }
  }
}
