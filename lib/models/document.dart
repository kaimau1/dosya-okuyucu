/// Açılan bir dosyanın türü.
enum DocKind { pdf, text, spreadsheet, word, slides, image, unknown }

extension DocKindLabel on DocKind {
  /// Çeviri anahtarı — arayüz `context.t(kind.labelKey)` çağırır.
  String get labelKey => switch (this) {
        DocKind.pdf => 'enum.doc_pdf',
        DocKind.text => 'enum.doc_text',
        DocKind.spreadsheet => 'enum.doc_spreadsheet',
        DocKind.word => 'enum.doc_word',
        DocKind.slides => 'enum.doc_slides',
        DocKind.image => 'enum.doc_image',
        DocKind.unknown => 'enum.doc_unknown',
      };

  String get label {
    switch (this) {
      case DocKind.pdf:
        return 'PDF';
      case DocKind.text:
        return 'Metin';
      case DocKind.spreadsheet:
        return 'Excel';
      case DocKind.word:
        return 'Word';
      case DocKind.slides:
        return 'Slayt';
      case DocKind.image:
        return 'Görsel';
      case DocKind.unknown:
        return 'Bilinmeyen';
    }
  }
}

/// Yüklenmiş dosyayı temsil eden hafif model.
class LoadedDoc {
  final String path;
  final String name;
  final DocKind kind;

  /// AI bağlamı ve arama için düz metin içerik (varsa).
  final String plainText;

  /// Elektronik tablolar için satır/sütun verisi (opsiyonel).
  final List<List<String>>? table;

  /// Salt-okunur mu? Eski ikili biçimlerden (.doc/.ppt) çıkarılan içerik
  /// düzenlenip geri yazılamaz — görüntüleyici (ViewerScreen) ile gösterilir,
  /// OOXML editörlerine yönlendirilmez.
  final bool readOnly;

  /// [path] bir **çalışma kopyasıysa** (ör. `.xls` → `.xlsx` çevrimi), kaydetme
  /// buraya yazar. Kullanıcının gördüğü dosya `.xls` ama biz BIFF yazamayız;
  /// kaydetme özgün dosyanın yanına aynı adlı `.xlsx` bırakır. `null` ise
  /// kaydetme [path]'in kendisine gider (normal durum).
  final String? savePath;

  /// Çalışma kopyasının geldiği özgün dosya (kullanıcıya "şuradan çevrildi"
  /// demek ve son belgeler kaydını doğru tutmak için).
  final String? sourcePath;

  const LoadedDoc({
    required this.path,
    required this.name,
    required this.kind,
    this.plainText = '',
    this.table,
    this.readOnly = false,
    this.savePath,
    this.sourcePath,
  });

  bool get isEditableText =>
      !readOnly && (kind == DocKind.text || kind == DocKind.word);
}
