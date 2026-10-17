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
///
/// EKOSİSTEM (kullanıcı isteği 2026-10-17, Notlar'dan: *"dosya eklerken
/// açılan dosya yöneticisi istenen uzantıya göre süzmeli, şu an ana sayfa
/// açılıyor ve bulmak çok zor"*): istek artık yalnız niyetin `type`ı değil —
/// standart EXTRA_MIME_TYPES listesi, kardeş uygulamanın uzantı listesi,
/// başlığı ve adı da okunur. Belirli bir tür istendiğinde ([isSpecific])
/// seçici ana sayfa yerine doğrudan o türün bütün dosyalarıyla açılır.
class PickerRequest {
  /// İstenen MIME türü (`*/*`, `image/*`, `application/pdf`…).
  final String mimeType;

  /// EXTRA_MIME_TYPES — birden çok tür istendiyse (boşsa yalnız [mimeType]).
  final List<String> mimeTypes;

  /// Kardeş uygulamanın gönderdiği uzantılar (küçük harf, noktasız). MIME'ı
  /// tutmayan ama listede olan uzantı da kabul edilir (`.md` gibi).
  final Set<String> extensions;

  /// Çağıranın başlığı ("PDF seç") — yoksa genel başlık.
  final String? title;

  /// Çağıran uygulamanın adı ("Notlar").
  final String? caller;

  /// Çağıran "Diğer kaynaklar" dönüşünü anlıyor mu (düğme yalnız o zaman).
  final bool otherSources;

  /// Birden çok dosya seçilebilir mi? (`EXTRA_ALLOW_MULTIPLE`)
  final bool allowMultiple;

  const PickerRequest({
    this.mimeType = '*/*',
    this.mimeTypes = const [],
    this.extensions = const {},
    this.title,
    this.caller,
    this.otherSources = false,
    this.allowMultiple = false,
  });

  /// Etkin MIME listesi: EXTRA_MIME_TYPES varsa o, yoksa [mimeType].
  List<String> get effectiveMimes {
    final list = [
      for (final m in mimeTypes)
        if (m.trim().isNotEmpty) m.trim().toLowerCase(),
    ];
    return list.isEmpty ? [mimeType.trim().toLowerCase()] : list;
  }

  /// Her şeyi kabul eden istek mi (`*/*`)?
  bool get acceptsAll =>
      extensions.isEmpty &&
      effectiveMimes.any((m) => m.isEmpty || m == '*/*' || m == '*');

  /// Belirli bir tür istendi mi — seçici o zaman doğrudan türün dosya
  /// listesiyle açılır.
  bool get isSpecific => !acceptsAll;

  /// Bu dosya isteği karşılıyor mu?
  ///
  /// Eşleşme MIME üzerinden yapılır; `*/*` her şeyi kabul eder, `image/*` gibi
  /// aile kalıpları ön ekle karşılaştırılır. Tanımadığımız bir uzantı
  /// (`application/octet-stream`) yalnız `*/*` isteğinde görünür — çağırana
  /// açamayacağı bir dosyayı vermek, o uygulamada sessiz bir hata demektir.
  bool accepts(String fileMime) {
    final have = fileMime.toLowerCase();
    for (final want in effectiveMimes) {
      if (want.isEmpty || want == '*/*' || want == '*') return true;
      if (want.endsWith('/*')) {
        if (have.startsWith(want.substring(0, want.length - 1))) return true;
      } else if (have == want) {
        return true;
      }
    }
    return false;
  }

  /// Dosya girdisi bu isteği karşılıyor mu? (Klasörler her zaman görünür —
  /// içine girilmeden aranan dosyaya ulaşılamaz.)
  bool acceptsEntry(FsEntry entry) {
    if (entry.isDir) return true;
    if (extensions.isNotEmpty &&
        extensions.contains(entry.extension.toLowerCase())) {
      return true;
    }
    return accepts(mimeForExtension(entry.extension, entry.category));
  }

  /// İstek TEK bir kategoriye mi düşüyor? (Dizin sorgusu isolate'te o
  /// kategoriyle daraltılır; karışık istekte null — süzme burada yapılır.)
  FmCategory? get category {
    final cats = <FmCategory>{};
    for (final m in effectiveMimes) {
      if (m.startsWith('image/')) {
        cats.add(FmCategory.image);
      } else if (m.startsWith('video/')) {
        cats.add(FmCategory.video);
      } else if (m.startsWith('audio/')) {
        cats.add(FmCategory.audio);
      } else if (m.startsWith('text/') || _documentMimes.contains(m) ||
          m.startsWith('application/vnd.openxmlformats-officedocument.') ||
          m.startsWith('application/vnd.ms-') ||
          m.startsWith('application/vnd.oasis.opendocument.')) {
        cats.add(FmCategory.document);
      } else {
        return null;
      }
    }
    // Uzantı listesi kategoriden taşıyorsa (ör. `.md` belge ama MIME'ı
    // verilmemiş başka bir uzantı) daraltma yapılmaz.
    if (cats.length != 1) return null;
    final only = cats.first;
    final table = switch (only) {
      FmCategory.image => FmExtensions.image,
      FmCategory.video => FmExtensions.video,
      FmCategory.audio => FmExtensions.audio,
      _ => FmExtensions.document,
    };
    if (extensions.any((e) => !table.contains(e))) return null;
    return only;
  }

  /// Başlıkta gösterilecek kısa tür adı: "PDF", "MP3 · M4A · WAV…".
  String get kindLabel {
    final exts = extensions.isNotEmpty
        ? (extensions.toList()..sort())
        : [
            for (final m in effectiveMimes)
              if (_extensionOfMime(m) case final e?) e,
          ];
    if (exts.isEmpty) return '';
    final shown = exts.take(4).map((e) => e.toUpperCase()).join(' · ');
    return exts.length > 4 ? '$shown…' : shown;
  }

  static const _documentMimes = {
    'application/pdf',
    'application/msword',
    'application/rtf',
    'application/json',
    'application/xml',
    'application/epub+zip',
  };

  static String? _extensionOfMime(String mime) => switch (mime) {
        'application/pdf' => 'pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
          'docx',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
          'pptx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
          'xlsx',
        'text/plain' => 'txt',
        'application/json' => 'json',
        _ => null,
      };

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
      List<String> strings(Object? v) => [
            if (v is List)
              for (final e in v)
                if (e is String && e.trim().isNotEmpty) e.trim(),
          ];
      String? text(Object? v) =>
          v is String && v.trim().isNotEmpty ? v.trim() : null;
      return PickerRequest(
        mimeType: (raw['mimeType'] as String?) ?? '*/*',
        mimeTypes: strings(raw['mimeTypes']),
        extensions: {
          for (final e in strings(raw['extensions']))
            e.toLowerCase().replaceFirst('.', ''),
        },
        title: text(raw['title']),
        caller: text(raw['caller']),
        otherSources: raw['otherSources'] == true,
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

  /// "Diğer kaynaklar": çağıran kendi sistem seçicisini açar (yalnız
  /// [PickerRequest.otherSources] isteğinde).
  static Future<void> otherSources() async {
    try {
      await _channel.invokeMethod<void>('other');
    } catch (_) {}
  }

  /// Kullanıcı vazgeçti — çağırana "iptal" döner.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
