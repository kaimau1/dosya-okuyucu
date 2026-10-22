/// **Tek tür modeli** (Faz 13, 2026-10-22): bir dosyanın listelerde hangi tür
/// çipine düştüğü — üst türler (Klasör, Görsel, Video, Ses, Arşiv, APK,
/// Diğer) ve **belge alt türleri** (PDF, Word, Excel, Sunum, Metin/Kod,
/// E-kitap, Diğer belge).
///
/// KÖK NEDEN (kullanıcı 2026-10-22: *"son dosyalarda PDF vs ayrı
/// filtreleyemiyorum"*): tür süzgeci üç yerde üç ayrı biçimde yazılmıştı —
/// gezgin `FmCategory` düzeyinde ("Belgeler" tek çip), kategori ekranı
/// `DocKind` çiplerini yalnız `showDocKinds` bayrağıyla (Belgeler kutusunda),
/// arama yine `FmCategory` ile; Son açılanlar, İndirilenler, Çöp, Kasa'da hiç
/// yoktu. Şimdi her liste bu tek modelden süzer.
///
/// **Tek kaynak:** üst tür [FsEntry.categoryForExtension]'dan (Görüntüler/
/// Videolar… bölmeleriyle aynı tablo) gelir; burada yalnız belgeler alt
/// türlere bölünür. `FileService.kindForExtension` bilinçli olarak AYRI
/// kalır: o "hangi düzenleyici açar" sorusunu yanıtlar ve eski .doc/.xls'i
/// "bilinmeyen" sayar — listede ise .xls de Excel'dir.
///
/// Saf Dart (Flutter importu yok) — birim testiyle sabitlenir.
library;

import 'fs_entry.dart';

/// Listelerdeki tür çiplerinin sırası da budur (sabit sıra: kullanıcı çiplerin
/// yerini ezberleyebilsin; sayıya göre sıralamak her açılışta yer
/// değiştirirdi).
enum FmType {
  folder,
  pdf,
  word,
  excel,
  slides,
  text,
  ebook,
  docOther,
  image,
  video,
  audio,
  archive,
  apk,
  other;

  /// Uzantıdan tür (küçük/büyük harf duyarsız, noktasız).
  static FmType forExtension(String ext, {bool isDir = false}) {
    if (isDir) return FmType.folder;
    final e = ext.toLowerCase();
    return switch (FsEntry.categoryForExtension(e)) {
      FmCategory.document => _docSubtype(e),
      FmCategory.image => FmType.image,
      FmCategory.video => FmType.video,
      FmCategory.audio => FmType.audio,
      FmCategory.archive => FmType.archive,
      FmCategory.apk => FmType.apk,
      FmCategory.folder => FmType.folder,
      FmCategory.other => FmType.other,
    };
  }

  /// Bir girdinin türü.
  static FmType of(FsEntry entry) =>
      forExtension(entry.extension, isDir: entry.isDir);

  /// Yalnız addan (Çöp/Kasa kayıtları gibi `FsEntry` olmayan öğeler için).
  static FmType ofName(String name, {bool isDir = false}) {
    if (isDir) return FmType.folder;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return FmType.other;
    return forExtension(name.substring(dot + 1));
  }

  static FmType _docSubtype(String ext) {
    if (ext == 'pdf') return FmType.pdf;
    if (_word.contains(ext)) return FmType.word;
    if (_excel.contains(ext)) return FmType.excel;
    if (_slides.contains(ext)) return FmType.slides;
    if (_ebook.contains(ext)) return FmType.ebook;
    if (_text.contains(ext)) return FmType.text;
    return FmType.docOther;
  }

  // Eski Office (.doc/.xls/.ppt) ve OpenDocument kendi ailesine düşer:
  // kullanıcı ".xls Excel değil mi?" diye sorar, "Eski Office" diye değil.
  static const _word = {'doc', 'docx', 'docm', 'dot', 'dotx', 'odt', 'rtf'};
  static const _excel = {
    'xls', 'xlsx', 'xlsm', 'xlsb', 'xlt', 'xltx', 'ods', 'csv', 'tsv',
  };
  static const _slides = {
    'ppt', 'pptx', 'pptm', 'pot', 'potx', 'pps', 'ppsx', 'odp',
  };
  static const _ebook = {'epub', 'mobi', 'azw', 'azw3', 'fb2', 'djvu'};
  static const _text = {
    'txt', 'md', 'markdown', 'log', 'json', 'xml', 'yaml', 'yml', 'html',
    'htm', 'srt', 'vtt', 'sub', 'ass', 'ini', 'conf', 'cfg',
  };

  /// Belge alt türü mü?
  bool get isDocument => switch (this) {
        FmType.pdf ||
        FmType.word ||
        FmType.excel ||
        FmType.slides ||
        FmType.text ||
        FmType.ebook ||
        FmType.docOther =>
          true,
        _ => false,
      };

  /// Üst kategori (Belgeler bölmesi vb.).
  FmCategory get category => switch (this) {
        FmType.folder => FmCategory.folder,
        FmType.image => FmCategory.image,
        FmType.video => FmCategory.video,
        FmType.audio => FmCategory.audio,
        FmType.archive => FmCategory.archive,
        FmType.apk => FmCategory.apk,
        FmType.other => FmCategory.other,
        _ => FmCategory.document,
      };

  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        FmType.folder => 'list.folders',
        FmType.pdf => 'enum.doc_pdf',
        FmType.word => 'enum.doc_word',
        FmType.excel => 'enum.doc_spreadsheet',
        FmType.slides => 'enum.doc_slides',
        FmType.text => 'type.text',
        FmType.ebook => 'type.ebook',
        FmType.docOther => 'type.doc_other',
        FmType.image => 'enum.cat_image',
        FmType.video => 'enum.cat_video',
        FmType.audio => 'enum.cat_audio',
        FmType.archive => 'enum.cat_archive',
        FmType.apk => 'enum.cat_apk',
        FmType.other => 'enum.cat_other',
      };
}

/// Türlere göre sayım (çip sayıları için).
Map<FmType, int> fmTypeCounts(Iterable<FmType> types) {
  final counts = <FmType, int>{};
  for (final t in types) {
    counts[t] = (counts[t] ?? 0) + 1;
  }
  return counts;
}
