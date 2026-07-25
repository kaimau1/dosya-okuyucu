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
  static const image = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'heic', 'heif', 'svg', 'ico',
    'tif', 'tiff', 'avif', 'jfif', 'dng', 'raw',
  };
  static const video = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v', 'mpg',
    'mpeg', 'ts', 'mts', 'ogv',
  };
  static const audio = {
    'mp3', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'flac', 'wma', 'opus', 'amr',
    'mid', 'midi', 'aiff', '3ga',
  };
  static const archive = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'iso', 'jar', 'cab',
  };
  static const apk = {'apk', 'apks', 'xapk', 'aab'};

  /// Belge sayılan uzantılar (ofis + PDF + metin/kod/veri).
  static const document = {
    'pdf', 'doc', 'docx', 'dot', 'dotx', 'odt', 'rtf',
    'xls', 'xlsx', 'xlsm', 'xlt', 'ods', 'csv', 'tsv',
    'ppt', 'pptx', 'pot', 'pps', 'odp',
    'txt', 'md', 'markdown', 'log', 'json', 'xml', 'yaml', 'yml', 'html',
    'htm', 'epub', 'srt', 'ini', 'conf',
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
  String get label => switch (this) {
        FmSort.name => 'Ada göre',
        FmSort.date => 'Tarihe göre',
        FmSort.size => 'Boyuta göre',
        FmSort.type => 'Türe göre',
      };
}
