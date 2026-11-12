import 'package:archive/archive.dart';

/// **Office paketi sınırları** (Güvenlik G7.3, 2026-11-12).
///
/// DOCX/XLSX/PPTX birer zip; `archive` paketi bir girişi okurken TAMAMINI
/// belleğe açar. Küçük ama dev açılan bir paket (sıkıştırma bombası) belleği
/// tüketip uygulamayı düşürürdü. Merkezi dizin okunduktan sonra, hiçbir giriş
/// açılmadan başlıktaki sayı/boyutlarla reddedilir:
/// giriş ≤ [maxEntries], tek giriş ≤ [maxEntryBytes], toplam ≤ [maxTotalBytes].
///
/// Sınır: başlık yalan söyleyebilir (açılmış boyutu küçük yazılmış giriş) —
/// bu denetim yalnız olağan bombaları keser; tam koruma akışlı açma ister.
abstract final class OfficeZipGuard {
  static const maxEntries = 10000;
  static const maxEntryBytes = 200 * 1024 * 1024;
  static const maxTotalBytes = 1024 * 1024 * 1024;

  /// [bytes]'ı zip olarak çözer ve sınırları denetler; aşılırsa
  /// [OfficeTooLarge] (bir [FormatException] — okuyucuların "bozuk dosya"
  /// yolu aynen işler).
  static Archive decode(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    check(archive);
    return archive;
  }

  static void check(Archive archive) {
    final files = archive.files;
    if (files.length > maxEntries) {
      throw OfficeTooLarge('${files.length} parça (sınır $maxEntries)');
    }
    var total = 0;
    for (final f in files) {
      final size = f.size < 0 ? 0 : f.size;
      if (size > maxEntryBytes) {
        throw OfficeTooLarge('${f.name}: ${_mb(size)} (sınır ${_mb(maxEntryBytes)})');
      }
      total += size;
      if (total > maxTotalBytes) {
        throw OfficeTooLarge('toplam ${_mb(total)}+ (sınır ${_mb(maxTotalBytes)})');
      }
    }
  }

  static String _mb(int b) => '${(b / (1024 * 1024)).toStringAsFixed(0)} MB';
}

/// Dosya çok büyük ya da bozuk (açılınca sınırı aşıyor).
class OfficeTooLarge extends FormatException {
  const OfficeTooLarge(String detail)
      : super('Dosya çok büyük ya da bozuk: $detail');
}
