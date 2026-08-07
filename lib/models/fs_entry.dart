/// Dosya yöneticisinin çekirdek modeli: diskteki bir dosya ya da klasör.
///
/// Bilinçli olarak **saf Dart** (Flutter importu yok) — böylece listeleme,
/// sıralama ve kategori mantığı `flutter test` içinde widget kurmadan,
/// doğrudan birim testiyle doğrulanabilir.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Dosya yöneticisi kategorileri. Belge alt türleri (Word/Excel/PDF…) ayrıca
/// [DocKind] ile ayrışır; buradaki kategori "hangi bölmede/ızgarada görünür"
/// sorusunu yanıtlar (ekran görüntüsündeki Görüntüler/Ses/Videolar/Belgeler…).
enum FmCategory { folder, image, video, audio, document, archive, apk, other }

extension FmCategoryLabel on FmCategory {
  /// Çeviri anahtarı — arayüz `context.t(category.labelKey)` çağırır. [label]
  /// Türkçe kalır: **klasör adı üretiminde** de kullanılıyor (otomatik
  /// düzenleme) ve dil değişince eski klasörlerin adı değişmemeli.
  String get labelKey => switch (this) {
        FmCategory.folder => 'enum.cat_folder',
        FmCategory.image => 'enum.cat_image',
        FmCategory.video => 'enum.cat_video',
        FmCategory.audio => 'enum.cat_audio',
        FmCategory.document => 'enum.cat_document',
        FmCategory.archive => 'enum.cat_archive',
        FmCategory.apk => 'enum.cat_apk',
        FmCategory.other => 'enum.cat_other',
      };

  String get label => switch (this) {
        FmCategory.folder => 'Klasör',
        FmCategory.image => 'Görüntüler',
        FmCategory.video => 'Videolar',
        FmCategory.audio => 'Ses',
        FmCategory.document => 'Belgeler',
        FmCategory.archive => 'Arşivler',
        FmCategory.apk => 'Uygulamalar',
        FmCategory.other => 'Diğer',
      };
}

/// Uzantı → kategori tabloları. Tek kaynak: hem kategori ekranları hem de
/// ızgara ikonları buradan beslenir.
abstract final class FmExtensions {
  /// **Eksik uzantı = görünmeyen dosya** (hata 2026-07-29: "videolarda tüm
  /// videolar görünmüyor · görüntülerde de çok fazla eksik var"). Kategori
  /// dışı kalan dosya "Diğer"e düşüp galeriye hiç girmediği için listeler
  /// cömert tutulur: yanlış kategoriye düşen nadir bir dosya, hiç görünmeyen
  /// dosyadan iyidir.
  static const image = {
    'png', 'jpg', 'jpeg', 'jpe', 'gif', 'bmp', 'webp', 'heic', 'heif', 'hif',
    'svg', 'svgz', 'ico', 'tif', 'tiff', 'avif', 'jfif', 'jpf', 'jp2', 'j2k',
    'jxl', 'apng', 'pjpeg', 'dib', 'psd', 'xcf', 'pcx', 'tga', 'exr', 'hdr',
    // Ham (RAW) fotoğraf makinesi biçimleri — telefonların "pro" kipi de üretir.
    'dng', 'raw', 'cr2', 'cr3', 'nef', 'nrw', 'arw', 'srw', 'orf', 'rw2',
    'raf', 'pef', 'sr2', '3fr',
  };
  static const video = {
    'mp4', 'm4v', 'mkv', 'avi', 'mov', 'qt', 'wmv', 'flv', 'f4v', 'webm',
    '3gp', '3gpp', '3g2', 'mpg', 'mpeg', 'mpe', 'm1v', 'm2v', 'm2t', 'm2ts',
    'mts', 'ts', 'tp', 'vob', 'ogv', 'ogm', 'asf', 'rm', 'rmvb', 'divx',
    'mxf', 'dv', 'mjpeg', 'mjpg', 'insv', 'lrv',
  };
  static const audio = {
    'mp3', 'wav', 'wave', 'ogg', 'oga', 'm4a', 'm4b', 'm4r', 'aac', 'flac',
    'wma', 'opus', 'amr', 'awb', 'mid', 'midi', 'xmf', 'mka', 'aiff', 'aif',
    'aifc', 'ape', 'ac3', 'eac3', 'dts', 'dsf', 'dff', 'wv', 'caf', 'au',
    'ra', '3ga', 'mp2', 'mpga',
  };
  static const archive = {
    'zip', 'zipx', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'tbz', 'tbz2',
    'xz', 'txz', 'lz', 'lzma', 'lz4', 'zst', 'zstd', 'arj', 'ace', 'iso',
    'jar', 'cab', 'dmg', 'z',
  };
  static const apk = {'apk', 'apks', 'xapk', 'aab'};

  /// Belge sayılan uzantılar (ofis + PDF + metin/kod/veri).
  static const document = {
    'pdf', 'xps', 'djvu', 'doc', 'docx', 'docm', 'dot', 'dotx', 'odt', 'rtf',
    'xls', 'xlsx', 'xlsm', 'xlsb', 'xlt', 'xltx', 'ods', 'csv', 'tsv',
    'ppt', 'pptx', 'pptm', 'pot', 'potx', 'pps', 'ppsx', 'odp', 'odg',
    'txt', 'md', 'markdown', 'log', 'json', 'xml', 'yaml', 'yml', 'html',
    'htm', 'epub', 'mobi', 'azw', 'azw3', 'fb2', 'srt', 'vtt', 'sub', 'ass',
    'ini', 'conf', 'cfg',
  };
}

/// Diskteki bir girdinin (dosya/klasör) anlık görüntüsü. Değerler listeleme
/// anında bir kez okunur — her karede `File.statSync` çağırmak (Excel
/// getter'ları tuzağının aynısı) listeyi kilitlerdi.
class FsEntry {
  final String path;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final int modifiedMs;

  /// Son ERİŞİM zamanı (atime). Android'de çoğu bağlama `relatime`/`noatime`
  /// kullandığı için güvenilmez olabilir → değiştirilme zamanından büyük
  /// değilse "bilinmiyor" sayılır ([lastTouchedMs]).
  final int accessedMs;

  /// Sembolik bağlantı mı? (Döngüye girmemek için özyinelemeli taramada atlanır.)
  final bool isLink;

  const FsEntry({
    required this.path,
    required this.name,
    required this.isDir,
    required this.sizeBytes,
    required this.modifiedMs,
    this.accessedMs = 0,
    this.isLink = false,
  });

  /// "Son dokunulma": erişim zamanı anlamlıysa o, değilse değiştirilme zamanı.
  int get lastTouchedMs =>
      accessedMs > modifiedMs ? accessedMs : modifiedMs;

  /// Erişim zamanı gerçekten bilgi veriyor mu (dosya yazıldıktan SONRA
  /// açılmış mı)?
  bool get hasAccessInfo => accessedMs > modifiedMs;

  /// Unix geleneği: adı nokta ile başlayan girdi gizlidir.
  bool get isHidden => name.startsWith('.');

  /// Girdi hâlâ diskte mi? (Silme/taşıma sonrası listeyi tazelemek için.)
  bool get exists =>
      isDir ? Directory(path).existsSync() : File(path).existsSync();

  String get extension {
    if (isDir) return '';
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  FmCategory get category => categoryForExtension(extension, isDir: isDir);

  static FmCategory categoryForExtension(String ext, {bool isDir = false}) {
    if (isDir) return FmCategory.folder;
    ext = ext.toLowerCase();
    if (FmExtensions.image.contains(ext)) return FmCategory.image;
    if (FmExtensions.video.contains(ext)) return FmCategory.video;
    if (FmExtensions.audio.contains(ext)) return FmCategory.audio;
    if (FmExtensions.apk.contains(ext)) return FmCategory.apk;
    if (FmExtensions.archive.contains(ext)) return FmCategory.archive;
    if (FmExtensions.document.contains(ext)) return FmCategory.document;
    return FmCategory.other;
  }

  /// Yoldan girdi üretir; dosya **artık yoksa null**.
  ///
  /// Yarıda kalan bir işi yeniden kurarken gerekiyor (bkz. `JobRecipe`):
  /// kaydedilen şey yol; girdinin kendisi diskten yeniden okunur. Silinmiş
  /// dosya için null dönmesi bilinçli — 0 baytlık hayalet bir girdi üretip
  /// işi ona çalıştırmak sessiz hataya yol açardı.
  static FsEntry? ofPath(String path) {
    final file = File(path);
    if (file.existsSync()) return fromEntity(file);
    final dir = Directory(path);
    return dir.existsSync() ? fromEntity(dir) : null;
  }

  /// Diskteki bir [FileSystemEntity]'den girdi üretir. `stat` başarısız olursa
  /// (izin yok / yarışta silinmiş) boyut/tarih 0 kalır ama girdi yine listelenir
  /// — kullanıcı en azından adı görür.
  static FsEntry fromEntity(FileSystemEntity entity) {
    final name = p.basename(entity.path);
    var isDir = entity is Directory;
    var size = 0;
    var modified = 0;
    var accessed = 0;
    try {
      final stat = entity.statSync();
      isDir = stat.type == FileSystemEntityType.directory;
      size = stat.size;
      modified = stat.modified.millisecondsSinceEpoch;
      accessed = stat.accessed.millisecondsSinceEpoch;
    } catch (_) {
      // izin verilmeyen /storage alt klasörleri: ad gösterilir, meta boş kalır
    }
    return FsEntry(
      path: entity.path,
      name: name,
      isDir: isDir,
      sizeBytes: isDir ? 0 : size,
      modifiedMs: modified,
      accessedMs: accessed,
      isLink: entity is Link,
    );
  }
}

/// Sıralama ölçütü (kullanıcı seçer, tercih kalıcıdır).
enum FmSort { name, date, size, type }

extension FmSortLabel on FmSort {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        FmSort.name => 'enum.sort_name',
        FmSort.date => 'enum.sort_date',
        FmSort.size => 'enum.sort_size',
        FmSort.type => 'enum.sort_type',
      };

  String get label => switch (this) {
        FmSort.name => 'Ada göre',
        FmSort.date => 'Tarihe göre',
        FmSort.size => 'Boyuta göre',
        FmSort.type => 'Türe göre',
      };
}
