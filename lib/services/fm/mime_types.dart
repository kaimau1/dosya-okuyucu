/// Uzantı → MIME türü ve "tarayıcı bunu gösterebilir mi" bilgisi.
///
/// **Tek tablo, iki müşteri:** Drive'a yükleme (`DriveService.mimeForName`) ve
/// ağ paylaşımının HTTP sunucusu. İkisi ayrı tablolar tutsaydı biri
/// güncellenip diğeri geride kalırdı; üstelik HTTP tarafında yanlış tür
/// KULLANICI HATASI demek — tarayıcı `application/octet-stream` gördüğü PDF'i
/// göstermek yerine indiriyor, `text/plain` sandığı belgeyi ise ekrana
/// döküyor.
abstract final class MimeTypes {
  /// Bilinmeyen tür. Tarayıcı bunu daima indirir (doğrusu da bu).
  static const unknown = 'application/octet-stream';

  static const _byExtension = <String, String>{
    // Belgeler
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument'
        '.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument'
        '.presentationml.presentation',
    'odt': 'application/vnd.oasis.opendocument.text',
    'ods': 'application/vnd.oasis.opendocument.spreadsheet',
    'rtf': 'application/rtf',
    'epub': 'application/epub+zip',
    // Metin
    'txt': 'text/plain',
    'md': 'text/plain',
    'log': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'html': 'text/html',
    'htm': 'text/html',
    // Görüntü
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'svg': 'image/svg+xml',
    // Ses / video
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'opus': 'audio/opus',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    '3gp': 'video/3gpp',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    // Arşiv / kurulum
    'zip': 'application/zip',
    'apk': 'application/vnd.android.package-archive',
    'apks': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'gz': 'application/gzip',
    'tar': 'application/x-tar',
  };

  /// Dosya adından MIME. Bilinmiyorsa [unknown].
  static String forName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return unknown;
    return _byExtension[name.substring(dot + 1).toLowerCase()] ?? unknown;
  }

  /// Tarayıcı bu türü **kendi gösterebilir mi**?
  ///
  /// Ayrım "güzellik" değil, kullanıcının bildirdiği hatanın ta kendisi
  /// (2026-08-29: *"ağda paylaştığım belgeyi bilgisayarda açmaya çalışınca
  /// Edge açılıyor, dosya açılmıyor"*):
  /// - Gösterebildiği tür (PDF, görüntü, video, düz metin) `inline` gider →
  ///   sekmede açılır.
  /// - Gösteremediği tür (Word, Excel, ZIP, APK) `attachment` gider → indirilir
  ///   ve Windows dosyayı KENDİ uygulamasıyla açar. Tarayıcının Word belgesini
  ///   ekranda "açmaya çalışıp" boş kalması tam olarak bu başlığın
  ///   eksikliğidir.
  static bool opensInBrowser(String mime) =>
      mime == 'application/pdf' ||
      mime.startsWith('image/') ||
      mime.startsWith('video/') ||
      mime.startsWith('audio/') ||
      mime == 'text/plain' ||
      mime == 'text/csv';
}
