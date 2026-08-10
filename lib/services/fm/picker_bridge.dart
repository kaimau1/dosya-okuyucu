/// **"Şuradan aç" içindeki ok işareti** — başka bir uygulama dosya isterken
/// bizim kendi arayüzümüzün açılması.
///
/// KÖK NEDEN (2026-08-10, kullanıcı ekran görüntüsüyle): *"biz çıkıyoruz ama
/// bizim arayüzümüze yönlendiren işaret çıkmıyor."* Android'in belge
/// seçicisindeki çekmecede iki farklı satır türü var:
/// - **Kök satırı** — `DocumentsProvider`dan gelir; seçici dosyayı KENDİ
///   arayüzünde gezdirir (bizim `DosyaProvider` ile kazandığımız satır).
/// - **Uygulama satırı** — `ACTION_GET_CONTENT` karşılayan uygulamalar; yanında
///   "uygulamada aç" oku vardır, dokununca seçici kapanır ve o uygulamanın
///   KENDİ ekranı açılır (Drive, MIUI Dosya Yöneticisi böyle görünüyor).
///
/// Bu köprü ikincisini sağlar: `PickerActivity` (ayrı bir aktivite) seçici
/// kipinde açılır, kullanıcı dosyayı BİZİM ekranımızda seçer, sonuç çağıran
/// uygulamaya `content://` adresi olarak döner.
///
/// **Neden ayrı aktivite:** `MainActivity` `launchMode="singleTask"` ve
/// Android'de singleTask bir aktivite sonuç döndüremez —
/// `startActivityForResult` çağıranın eline anında `RESULT_CANCELED` verir.
/// Aynı aktiviteye `GET_CONTENT` filtresi koymak, listede görünüp hiçbir zaman
/// dosya döndüremeyen bir satır üretirdi.
library;

import 'package:flutter/services.dart';

import '../../models/fs_entry.dart';

/// Çağıran uygulamanın isteği.
class PickerRequest {
  /// İstenen MIME türü (`*/*`, `image/*`, `application/pdf`…).
  final String mimeType;

  /// Birden çok dosya seçilebilir mi? (`EXTRA_ALLOW_MULTIPLE`)
  final bool allowMultiple;

  const PickerRequest({this.mimeType = '*/*', this.allowMultiple = false});

  /// Bu dosya isteği karşılıyor mu?
  ///
  /// Eşleşme MIME üzerinden yapılır; `*/*` her şeyi kabul eder, `image/*` gibi
  /// aile kalıpları ön ekle karşılaştırılır. Tanımadığımız bir uzantı
  /// (`application/octet-stream`) yalnız `*/*` isteğinde görünür — çağırana
  /// açamayacağı bir dosyayı vermek, o uygulamada sessiz bir hata demektir.
  bool accepts(String fileMime) {
    final want = mimeType.trim().toLowerCase();
    if (want.isEmpty || want == '*/*' || want == '*') return true;
    final have = fileMime.toLowerCase();
    if (want.endsWith('/*')) {
      return have.startsWith(want.substring(0, want.length - 1));
    }
    return have == want;
  }

  /// Dosya girdisi bu isteği karşılıyor mu? (Klasörler her zaman görünür —
  /// içine girilmeden aranan dosyaya ulaşılamaz.)
  bool acceptsEntry(FsEntry entry) =>
      entry.isDir || accepts(mimeForExtension(entry.extension, entry.category));

  /// Uzantıdan MIME; bilinmeyen uzantıda **kategori ailesine** düşülür.
  ///
  /// Aile düşüşü bilinçli: uzantı tablosu hiçbir zaman tam olmayacak
  /// (`.heic`, `.mkv`, `.opus`… sürekli yenisi çıkıyor) ve tanımadığımız her
  /// görseli `application/octet-stream` sayarsak `image/*` isteyen bir
  /// uygulamada kullanıcı kendi fotoğrafını göremez. Kategori tabloları
  /// (`FmExtensions`) zaten geniş ve tek elden bakımlı.
  static String mimeForExtension(String extension, FmCategory category) {
    final ext = extension.toLowerCase();
    final exact = switch (ext) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'doc' => 'application/msword',
      'xls' => 'application/vnd.ms-excel',
      'ppt' => 'application/vnd.ms-powerpoint',
      'txt' || 'md' || 'log' || 'csv' => 'text/plain',
      'html' || 'htm' => 'text/html',
      'json' => 'application/json',
      'xml' => 'application/xml',
      'zip' => 'application/zip',
      'apk' => 'application/vnd.android.package-archive',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp3' => 'audio/mpeg',
      'mp4' => 'video/mp4',
      _ => '',
    };
    if (exact.isNotEmpty) return exact;
    return switch (category) {
      FmCategory.image => 'image/$ext',
      FmCategory.video => 'video/$ext',
      FmCategory.audio => 'audio/$ext',
      // Tanımadığımız bir belge uzantısını `text/*` ya da `application/pdf`
      // saymak, çağıran uygulamaya açamayacağı bir dosya vermek olurdu.
      // Genel akış türü: yalnız `*/*` isteyen seçicilerde görünür.
      _ => 'application/octet-stream',
    };
  }
}

abstract final class PickerBridge {
  static const _channel = MethodChannel('dosya_okuyucu/picker');

  /// Çağıranın ne istediğini okur. Seçici kipinde değilsek varsayılan döner.
  static Future<PickerRequest> request() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('request');
      if (raw == null) return const PickerRequest();
      return PickerRequest(
        mimeType: (raw['mimeType'] as String?) ?? '*/*',
        allowMultiple: raw['multiple'] == true,
      );
    } catch (_) {
      // Kanal yoksa (masaüstü/test) seçici kipi de yok.
      return const PickerRequest();
    }
  }

  /// Seçilen dosyaları çağırana döndürür ve aktiviteyi kapatır.
  ///
  /// `true` dönmesi "sonuç teslim edildi" demektir; `false` ise yol
  /// okunamadı — arayüz kullanıcıya hata gösterir ve ekran AÇIK kalır
  /// (sessizce kapanıp çağırana boş dönmek en kötü davranış olurdu).
  static Future<bool> deliver(List<String> paths) async {
    if (paths.isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('pick', {'paths': paths});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı vazgeçti — çağırana "iptal" döner.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
