import 'fs_entry.dart';

/// Google Drive'daki bir dosya (Drive v3 `files` kaynağının bizim
/// kullandığımız alanları).
class DriveFile {
  final String id;
  final String name;
  final String mimeType;

  /// Drive `size` alanı METİN olarak gelir ve Google Dokümanlar/E-Tablolar
  /// gibi "yerel" biçimlerde HİÇ GELMEZ (onların bayt karşılığı yoktur).
  /// O durumda 0 kalır; arayüz "—" gösterir, "0 B" DEĞİL.
  final int sizeBytes;

  final int modifiedAtMs;

  /// Oluşturulma zamanı. Değiştirilmeden ayrı bir bilgi: Drive'a *ne zaman
  /// yüklendiği* çoğu zaman dosyanın kendi tarihinden farklıdır.
  final int createdAtMs;

  /// Dosya sahibinin görünen adı. Paylaşılan sürücülerde/başkasının paylaştığı
  /// dosyada "bu benim değil" bilgisini veren tek alan; boş olabilir.
  final String ownerName;

  /// Drive'da başkasıyla paylaşılmış mı. Bilgi penceresinde gösterilir —
  /// "bağlantıyı paylaş" dedikten sonra durumu görmenin tek yolu buydu.
  final bool shared;

  /// Drive'ın yıldızı. Menüdeki "Yıldız ekle/kaldır" bunun tersini yazar;
  /// listede yıldızlı dosyanın satırında da işaret gösterilir.
  final bool starred;

  const DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes = 0,
    this.modifiedAtMs = 0,
    this.createdAtMs = 0,
    this.ownerName = '',
    this.shared = false,
    this.starred = false,
  });

  static const folderMime = 'application/vnd.google-apps.folder';

  bool get isFolder => mimeType == folderMime;

  /// Google'ın kendi biçimleri (Dokümanlar/E-Tablolar/Slaytlar). Bunlar
  /// doğrudan indirilemez; `export` ile Office biçimine çevrilmeleri gerekir.
  bool get isGoogleDoc => mimeType.startsWith('application/vnd.google-apps.');

  /// Google biçimini indirirken kullanılacak hedef MIME'ı ve uzantı.
  /// Bilinmeyen Google biçimi için null (indirilemez).
  (String mime, String extension)? get exportAs => switch (mimeType) {
        'application/vnd.google-apps.document' => (
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'docx'
          ),
        'application/vnd.google-apps.spreadsheet' => (
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'xlsx'
          ),
        'application/vnd.google-apps.presentation' => (
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'pptx'
          ),
        'application/vnd.google-apps.drawing' => ('application/pdf', 'pdf'),
        _ => null,
      };

  factory DriveFile.fromJson(Map<String, dynamic> json) => DriveFile(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        mimeType: (json['mimeType'] ?? '').toString(),
        // `size` metin gelir ("1048576"); sayı gelen sürümlere karşı ikisi de
        // kabul ediliyor.
        sizeBytes: switch (json['size']) {
          final num n => n.toInt(),
          final String s => int.tryParse(s) ?? 0,
          _ => 0,
        },
        modifiedAtMs:
            DateTime.tryParse('${json['modifiedTime']}')?.millisecondsSinceEpoch ??
                0,
        createdAtMs:
            DateTime.tryParse('${json['createdTime']}')?.millisecondsSinceEpoch ??
                0,
        ownerName: _firstOwner(json['owners']),
        shared: json['shared'] == true,
        starred: json['starred'] == true,
      );

  /// `owners` bir DİZİ gelir (Drive birden çok sahip modelini taşıyor) ama
  /// pratikte tek eleman olur; ilkinin görünen adı alınır, yoksa boş.
  static String _firstOwner(Object? owners) {
    if (owners is! List || owners.isEmpty) return '';
    final first = owners.first;
    if (first is! Map) return '';
    final name = first['displayName'] ?? first['emailAddress'];
    return name is String ? name : '';
  }

  /// Uzantı (noktasız, küçük harf). Google biçimlerinde adın uzantısı yoktur —
  /// o durumda dışa aktarım uzantısı kullanılır ki dosya "Diğer"e düşmesin.
  String get extension {
    final dot = name.lastIndexOf('.');
    final fromName =
        dot <= 0 || dot == name.length - 1 ? '' : name.substring(dot + 1);
    if (fromName.isNotEmpty) return fromName.toLowerCase();
    return exportAs?.$2 ?? '';
  }

  /// Yerel gezginle AYNI kategori tablosu (`FsEntry.categoryForExtension`):
  /// Drive listesinde de APK yeşil android, PDF kırmızı belge, görüntü mor
  /// olsun diye — eskiden hepsi tek tip gri kağıt ikonuydu.
  FmCategory get category =>
      FsEntry.categoryForExtension(extension, isDir: isFolder);

  /// İndirilen dosyanın yerel adı. Google biçimlerinde Drive'daki adın
  /// uzantısı YOKTUR ("Bütçe" gibi) — dışa aktarım uzantısı eklenir, yoksa
  /// telefonda hiçbir uygulama açamaz.
  String localName() {
    final export = exportAs;
    if (export == null) return name;
    final ext = export.$2;
    return name.toLowerCase().endsWith('.$ext') ? name : '$name.$ext';
  }
}
