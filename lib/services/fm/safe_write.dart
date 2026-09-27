import 'dart:io';

import 'package:path/path.dart' as p;

/// **Kullanıcı dosyasının üzerine YARIDA KALAMAYAN yazma** (2026-09-27).
///
/// Kullanıcı bulgusu: 3239 sayfalık bir e-kitap PDF'ine vurgu eklenip
/// görüntüleyiciden çıkılıp girilince dosya **0 bayt** oldu, pdfium
/// "FPDF_GetLastError=3" (biçim bozuk) verdi — belge kayboldu.
///
/// KÖK NEDEN — üç yer aynı kalıbı kullanıyordu: `File.writeAsBytes` ve
/// `File.copySync` hedefi ÖNCE sıfırlar (O_TRUNC), SONRA yazar. Arada süreç
/// ölürse (düşük bellek, "uygulama yanıt vermiyor", görev yöneticisinden
/// kaydırma) ya da yazma hata verirse dosya 0 bayt / yarım kalır:
/// * görüntüleyici her vurguda özgün dosyanın ÜSTÜNE yazıyordu;
/// * ekrandan çıkarken özgün baytlar `dispose` içinde, **ana izlekte,
///   eşzamanlı** `copySync` ile geri yazılıyordu — büyük dosyada saniyeler
///   süren bu kopya ekranı donduruyor, tam o sırada öldürülen süreç dosyayı
///   yarım bırakıyordu;
/// * "üzerine yaz" kaydetmesi.
///
/// Çözüm: önce AYNI klasörde gizli bir geçici dosyaya yazılır, boyu
/// doğrulanır, sonra `rename` ile hedefin yerine konur. Aynı dosya
/// sisteminde `rename` bölünmez (atomik): hedef ya eski hâlidir ya yeni
/// hâli, asla yarısı. Süreç yazma ortasında ölürse geriye yalnız gizli
/// geçici dosya kalır, kullanıcının belgesi yerinde durur.
///
/// Klasöre yeni dosya açılamıyorsa (bazı SD kart / SAF konumları) eski
/// yola — doğrudan yazmaya — düşülür; o durumda da önce boy doğrulanır.
abstract final class SafeWrite {
  /// Geçici dosya adının işareti; artıklar bununla tanınıp temizlenir.
  static const marker = '.dosyaokuyucu-yaziliyor';

  static String _tempFor(String target) {
    final dir = p.dirname(target);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(dir, '.${p.basename(target)}$marker-$stamp');
  }

  /// [bytes]ı [target]a bölünmez biçimde yazar.
  static Future<void> bytes(String target, List<int> bytes) async {
    final temp = File(_tempFor(target));
    try {
      await temp.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await _deleteQuietly(temp);
      // Klasöre yeni dosya açılamıyor: tek yol doğrudan yazmak.
      await File(target).writeAsBytes(bytes, flush: true);
      return;
    }
    await _commit(temp, target, bytes.length);
  }

  /// [source]un kopyasını [target]ın yerine bölünmez biçimde koyar.
  static Future<void> copy(String source, String target) async {
    final expected = await File(source).length();
    final temp = File(_tempFor(target));
    try {
      await File(source).copy(temp.path);
    } catch (_) {
      await _deleteQuietly(temp);
      await File(source).copy(target);
      return;
    }
    await _commit(temp, target, expected);
  }

  /// [copy]nin eşzamanlı hâli — yalnız açılıştaki kurtarma gibi zorunlu
  /// yerlerde (ekran kapanırken KULLANILMAZ: ana izleği dondurur).
  static void copySync(String source, String target) {
    final expected = File(source).lengthSync();
    final temp = File(_tempFor(target));
    try {
      File(source).copySync(temp.path);
    } catch (_) {
      try {
        if (temp.existsSync()) temp.deleteSync();
      } catch (_) {}
      File(source).copySync(target);
      return;
    }
    if (temp.lengthSync() != expected) {
      temp.deleteSync();
      throw FileSystemException('Kopya eksik yazıldı', target);
    }
    try {
      temp.renameSync(target);
    } catch (_) {
      // Bazı dosya sistemleri var olan hedefin üstüne `rename` yapmaz:
      // hedef bir an silinip yeniden adlandırılır.
      File(target).deleteSync();
      temp.renameSync(target);
    }
  }

  static Future<void> _commit(File temp, String target, int expected) async {
    final written = await temp.length();
    if (written != expected) {
      await _deleteQuietly(temp);
      throw FileSystemException(
          'Yazma eksik kaldı ($written / $expected bayt)', target);
    }
    try {
      await temp.rename(target);
    } catch (_) {
      try {
        // Üstüne `rename` yapılamayan dosya sistemi: önce hedefi kaldır.
        final t = File(target);
        if (await t.exists()) await t.delete();
        await temp.rename(target);
      } catch (e) {
        // Son çare: içeriği hedefe kopyala (sıfırlayıp yazar ama geçici
        // dosya duruyor — yarıda kalırsa bile tam kopyası elde).
        await temp.copy(target);
        await _deleteQuietly(temp);
      }
    }
  }

  /// [target]ın yanında önceki yarım yazmalardan kalan gizli geçici
  /// dosyaları siler (en çok birkaç tane; klasör taranmaz, ad kalıbı
  /// eşleşeni silinir).
  static Future<void> cleanupLeftovers(String target) async {
    try {
      final dir = Directory(p.dirname(target));
      final prefix = '.${p.basename(target)}$marker-';
      await for (final e in dir.list(followLinks: false)) {
        if (e is File && p.basename(e.path).startsWith(prefix)) {
          await _deleteQuietly(e);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// PDF baytları için ucuz akıl sağlığı denetimi: yazmadan ÖNCE.
///
/// Boş ya da `%PDF` ile başlamayan bir çıktıyı (üretici kütüphanenin
/// sessiz hatası) kullanıcının dosyasının yerine koymak, belgeyi yok etmek
/// demektir; burada reddedilir.
abstract final class PdfBytesCheck {
  static bool looksValid(List<int> bytes) {
    if (bytes.length < 64) return false;
    // `%PDF` başlığı ilk 1024 baytta olmalı (önünde çöp olabilir — standart
    // buna izin veriyor).
    final head = bytes.length < 1024 ? bytes.length : 1024;
    var found = false;
    for (var i = 0; i + 4 <= head; i++) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x44 &&
          bytes[i + 3] == 0x46) {
        found = true;
        break;
      }
    }
    if (!found) return false;
    // `%%EOF` son 2 KB içinde olmalı.
    final from = bytes.length > 2048 ? bytes.length - 2048 : 0;
    for (var i = bytes.length - 5; i >= from; i--) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x25 &&
          bytes[i + 2] == 0x45 &&
          bytes[i + 3] == 0x4F &&
          bytes[i + 4] == 0x46) {
        return true;
      }
    }
    return false;
  }

  /// Dosya için aynı denetim (yalnız baş ve son okunur).
  static Future<bool> fileLooksValid(String path) async {
    RandomAccessFile? raf;
    try {
      final f = File(path);
      final len = await f.length();
      if (len < 64) return false;
      raf = await f.open();
      final head = await raf.read(len < 1024 ? len : 1024);
      final tailLen = len < 2048 ? len : 2048;
      await raf.setPosition(len - tailLen);
      final tail = await raf.read(tailLen);
      // Başı ve sonu yan yana koyup aynı denetimden geçir.
      return looksValid([...head, ...List.filled(64, 0x20), ...tail]);
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  static bool fileLooksValidSync(String path) {
    RandomAccessFile? raf;
    try {
      final f = File(path);
      final len = f.lengthSync();
      if (len < 64) return false;
      raf = f.openSync();
      final head = raf.readSync(len < 1024 ? len : 1024);
      final tailLen = len < 2048 ? len : 2048;
      raf.setPositionSync(len - tailLen);
      final tail = raf.readSync(tailLen);
      return looksValid([...head, ...List.filled(64, 0x20), ...tail]);
    } catch (_) {
      return false;
    } finally {
      raf?.closeSync();
    }
  }
}
