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

  const DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes = 0,
    this.modifiedAtMs = 0,
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
      );

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
