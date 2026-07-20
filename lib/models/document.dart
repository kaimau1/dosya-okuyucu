/// Açılan bir dosyanın türü.
enum DocKind { pdf, text, spreadsheet, word, slides, image, unknown }

extension DocKindLabel on DocKind {
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

  const LoadedDoc({
    required this.path,
    required this.name,
    required this.kind,
    this.plainText = '',
    this.table,
  });

  bool get isEditableText => kind == DocKind.text || kind == DocKind.word;
}
