import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Düzenlenmiş PDF'i nereye yazacağımız.
enum PdfSaveMode {
  /// Özgün dosyanın üzerine yaz.
  overwrite,

  /// Yanına yeni bir dosya olarak yaz (özgün dosya dokunulmadan kalır).
  copy,
}

/// PDF yazma hedefi. "Üzerine yaz" ve "kopyasını kaydet" tek yerde toplanır ki
/// PDF araçları, imza ve AI düzenleme aynı davranışı göstersin.
class PdfSave {
  const PdfSave._();

  /// [bytes]'ı [mode]'a göre diske yazar ve **yazılan dosyanın yolunu** döndürür.
  static Future<String> write(
    String originalPath,
    List<int> bytes,
    PdfSaveMode mode,
  ) async {
    if (mode == PdfSaveMode.overwrite) {
      await File(originalPath).writeAsBytes(bytes, flush: true);
      return originalPath;
    }
    final target = await copyTargetFor(originalPath);
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  /// Kopya için kullanılacak yol: önce özgün dosyanın klasörü ("… (kopya).pdf"),
  /// oraya yazılamıyorsa (salt-okunur/izinsiz konum) Belgeler dizini.
  ///
  /// Yazılabilirlik VARSAYILMAZ, ölçülür: paylaşımla gelen dosya çoğu zaman
  /// başka uygulamanın önbelleğinde durur; sessizce başarısız olmak yerine
  /// kullanıcının bulabileceği bir yere düşeriz.
  static Future<String> copyTargetFor(String originalPath) async {
    final stem = p.basenameWithoutExtension(originalPath);
    final dir = p.dirname(originalPath);
    if (await _isWritable(dir)) return _unique(dir, stem);
    final fallback = await _documentsDir();
    return _unique(fallback.path, stem);
  }

  static Future<bool> _isWritable(String dir) async {
    final probe = File(p.join(dir, '.dosyaokuyucu_yazma_denemesi'));
    try {
      await probe.writeAsString('x', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _unique(String dir, String stem) {
    var candidate = p.join(dir, '$stem (kopya).pdf');
    var n = 2;
    while (File(candidate).existsSync()) {
      candidate = p.join(dir, '$stem (kopya $n).pdf');
      n++;
    }
    return candidate;
  }

  static Future<Directory> _documentsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationSupportDirectory();
    }
  }

  /// Uint8List kısayolu (çağıranlar çoğunlukla bunu tutuyor).
  static Future<String> writeBytes(
    String originalPath,
    Uint8List bytes,
    PdfSaveMode mode,
  ) =>
      write(originalPath, bytes, mode);
}
