import 'dart:typed_data';

import 'ole_cfb.dart';

/// Eski **.doc / .ppt** ikili dosyalarından **en iyi çaba** metin çıkarır.
/// Tam düzen/biçim yok — bir telefonda "bana atılan dosyada ne yazıyor" sorusuna
/// cevap vermek için okunur metni gösterir.
///
/// Yöntem: OLE2 kabından ilgili ana stream'i alır, hem UTF-16LE hem CP1252
/// yazdırılabilir dizileri tarar, daha çok harf içeren sonucu döndürür. Yapısal
/// ayrıştırma (piece table / text atom) yapılmaz — bu yüzden sıra/boşluk kusurlu
/// olabilir; ama içerik okunur. Yetersizse null (çağıran "harici aç"a düşer).
class LegacyText {
  /// En az bu kadar harf çıkmazsa çıkarım başarısız sayılır.
  static const _minLetters = 8;

  static String? fromDoc(Uint8List fileBytes) {
    final ole = OleFile.tryParse(fileBytes);
    if (ole == null) return null;
    final wd = ole.stream('WordDocument');
    if (wd == null) return null;
    return _best(wd);
  }

  static String? fromPpt(Uint8List fileBytes) {
    final ole = OleFile.tryParse(fileBytes);
    if (ole == null) return null;
    final s = ole.firstOf(
        ['PowerPoint Document', 'PowerPoint Document Stream', 'Presentation']);
    if (s == null) return null;
    return _best(s);
  }

  /// Testler / genel kullanım: bir ham stream'den metin çıkarır.
  static String? extractFromStream(Uint8List stream) => _best(stream);

  static String? _best(Uint8List b) {
    final u16 = _utf16Runs(b);
    final u8 = _cp1252Runs(b);
    final pick = _letters(u16) >= _letters(u8) ? u16 : u8;
    final cleaned = pick.trim();
    return _letters(cleaned) >= _minLetters ? cleaned : null;
  }

  static int _letters(String s) {
    var n = 0;
    for (final r in s.runes) {
      if (_isLetter(r)) n++;
    }
    return n;
  }

  static bool _isLetter(int r) =>
      (r >= 0x41 && r <= 0x5A) ||
      (r >= 0x61 && r <= 0x7A) ||
      (r >= 0xC0 && r <= 0x24F); // Latin-1 ek + Latin genişletilmiş (Türkçe dahil)

  static bool _accept(int ch) {
    if (ch == 9 || ch == 10 || ch == 13) return true; // tab/newline
    if (ch >= 0x20 && ch <= 0x7E) return true; // ASCII yazdırılabilir
    if (ch >= 0xA0 && ch <= 0x24F) return true; // Latin-1/genişletilmiş
    if (ch >= 0x2010 && ch <= 0x2027) return true; // tipografik tire/tırnak
    return false;
  }

  static String _utf16Runs(Uint8List b) {
    final sb = StringBuffer();
    final run = <int>[];
    void flush() {
      if (run.length >= 4) {
        sb.writeln(String.fromCharCodes(run).trim());
      }
      run.clear();
    }

    for (var i = 0; i + 1 < b.length; i += 2) {
      final ch = b[i] | (b[i + 1] << 8);
      if (ch == 13 || ch == 10) {
        flush();
      } else if (_accept(ch)) {
        run.add(ch);
      } else {
        flush();
      }
    }
    flush();
    return sb.toString();
  }

  static String _cp1252Runs(Uint8List b) {
    final sb = StringBuffer();
    final run = <int>[];
    void flush() {
      if (run.length >= 4) {
        sb.writeln(String.fromCharCodes(run).trim());
      }
      run.clear();
    }

    for (var i = 0; i < b.length; i++) {
      final ch = b[i];
      if (ch == 13 || ch == 10) {
        flush();
      } else if (_accept(ch)) {
        run.add(ch);
      } else {
        flush();
      }
    }
    flush();
    return sb.toString();
  }
}
