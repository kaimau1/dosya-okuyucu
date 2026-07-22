import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/document.dart';
import 'legacy_text.dart';
import 'office_reader.dart';
import 'xls_legacy.dart';

/// Dosya seçme, tür tespiti ve içerik yükleme.
class FileService {
  static const _textExts = {
    // düz metin / işaretleme
    'txt', 'text', 'md', 'markdown', 'rst', 'adoc', 'asciidoc', 'tex',
    'log', 'nfo', 'srt', 'vtt', 'diff', 'patch',
    // veri / yapılandırma
    'json', 'xml', 'csv', 'tsv', 'yaml', 'yml', 'toml', 'ini', 'conf', 'cfg',
    'properties', 'env', 'plist', 'svg', 'gpx', 'kml',
    // web
    'html', 'htm', 'css', 'scss', 'less',
    // kod
    'dart', 'py', 'js', 'jsx', 'ts', 'tsx', 'java', 'kt', 'kts', 'c', 'cc',
    'cpp', 'cxx', 'h', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'sh', 'bash',
    'zsh', 'bat', 'ps1', 'sql', 'swift', 'scala', 'lua', 'pl', 'r', 'm',
    'gradle', 'cmake', 'dockerfile', 'makefile', 'gitignore',
  };
  static const _imageExts = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'heic', 'heif',
  };

  /// Cihazda doğrudan açılamayan eski/ikili veya farklı ofis biçimleri.
  /// (Bunlar OOXML/zip değil; kendi ayrıştırıcılarımız çöker → harici uygulama.)
  static const _legacyOffice = {
    'doc', 'dot', 'xls', 'xlt', 'ppt', 'pot', 'pps',
    'odt', 'ods', 'odp', 'rtf', 'pages', 'numbers', 'key',
  };

  static bool isLegacyOffice(String ext) =>
      _legacyOffice.contains(ext.toLowerCase());

  static DocKind kindForExtension(String ext) {
    ext = ext.toLowerCase();
    if (ext == 'pdf') return DocKind.pdf;
    // Yalnızca modern OOXML biçimleri kendi editörlerimize gider.
    if (ext == 'xlsx' || ext == 'xlsm') return DocKind.spreadsheet;
    if (ext == 'docx') return DocKind.word;
    if (ext == 'pptx') return DocKind.slides;
    if (_textExts.contains(ext)) return DocKind.text;
    if (_imageExts.contains(ext)) return DocKind.image;
    return DocKind.unknown;
  }

  /// Kullanıcıya dosya seçtirir; iptal edilirse null döner.
  Future<String?> pickFilePath() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  /// Verilen yolu yükleyip [LoadedDoc] üretir.
  Future<LoadedDoc> load(String path) async {
    final file = File(path);
    final name = p.basename(path);
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();

    // Eski ikili Office biçimleri (.doc/.xls/.ppt): OLE2 kabından en iyi çaba
    // içerik çıkarılır ve SALT-OKUNUR görüntülenir. Çıkarılamazsa harici aç.
    if (isLegacyOffice(ext)) {
      final legacy = await _loadLegacy(file, path, name, ext);
      if (legacy != null) return legacy;
      return LoadedDoc(
        path: path,
        name: name,
        kind: DocKind.unknown,
        plainText:
            'Bu biçim (.$ext) eski/farklı bir ofis biçimi ve içeriği cihazda '
            'okunamadı. “Başka uygulamayla aç” ile Google Dokümanlar, WPS Office '
            'gibi bir uygulamada açabilirsiniz.\n\n'
            'İpucu: dosyayı .docx / .xlsx / .pptx olarak kaydederseniz burada '
            'tam düzenlenebilir.',
      );
    }

    var kind = kindForExtension(ext);

    // Uzantı bilinmiyorsa içeriğe bak: metin gibiyse metin olarak aç.
    // (Geniş dosya türü desteği — atılan her dosyayı elden geldiğince göster.)
    if (kind == DocKind.unknown) {
      final sniffed = await _sniffText(file);
      if (sniffed != null) {
        return LoadedDoc(
            path: path, name: name, kind: DocKind.text, plainText: sniffed);
      }
    }

    switch (kind) {
      case DocKind.text:
        final text = await _readTextSafely(file);
        return LoadedDoc(path: path, name: name, kind: kind, plainText: text);

      case DocKind.word:
        final bytes = await file.readAsBytes();
        final text = ext == 'docx'
            ? OfficeReader.extractDocxText(bytes)
            : '(.doc eski formatı için metin çıkarımı sınırlıdır)';
        return LoadedDoc(path: path, name: name, kind: kind, plainText: text);

      case DocKind.slides:
        final bytes = await file.readAsBytes();
        final text = ext == 'pptx'
            ? OfficeReader.extractPptxText(bytes)
            : '(.ppt eski formatı için metin çıkarımı sınırlıdır)';
        return LoadedDoc(path: path, name: name, kind: kind, plainText: text);

      case DocKind.spreadsheet:
        return _loadSpreadsheet(file, path, name, kind);

      case DocKind.pdf:
      case DocKind.image:
      case DocKind.unknown:
        return LoadedDoc(path: path, name: name, kind: kind);
    }
  }

  /// Eski ikili Office dosyasından (.doc/.xls/.ppt) en iyi çaba içerik çıkarır.
  /// Başarısızsa null (çağıran "harici aç"a düşer). Sonuç daima salt-okunur.
  Future<LoadedDoc?> _loadLegacy(
      File file, String path, String name, String ext) async {
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return null;
    }

    // .xls / .xlt → Excel ızgarası (BIFF).
    if (ext == 'xls' || ext == 'xlt') {
      final xlsDoc = XlsLegacy.tryParse(bytes);
      if (xlsDoc == null) return null;
      final first = xlsDoc.sheets.isEmpty ? null : xlsDoc.sheets.first;
      return LoadedDoc(
        path: path,
        name: name,
        kind: DocKind.spreadsheet,
        plainText: xlsDoc.plainText,
        table: first?.rows,
        readOnly: true,
      );
    }

    // .doc / .dot → metin; .ppt / .pot / .pps → metin (en iyi çaba).
    String? text;
    if (ext == 'doc' || ext == 'dot') {
      text = LegacyText.fromDoc(bytes);
    } else if (ext == 'ppt' || ext == 'pot' || ext == 'pps') {
      text = LegacyText.fromPpt(bytes);
    }
    if (text == null || text.trim().isEmpty) return null;

    return LoadedDoc(
      path: path,
      name: name,
      kind: DocKind.text,
      plainText: 'Eski $ext dosyası — basit metin görünümü (biçim korunmaz):\n\n'
          '$text',
      readOnly: true,
    );
  }

  Future<LoadedDoc> _loadSpreadsheet(
    File file,
    String path,
    String name,
    DocKind kind,
  ) async {
    final bytes = await file.readAsBytes();
    final table = <List<String>>[];
    final buffer = StringBuffer();
    try {
      final excel = xls.Excel.decodeBytes(bytes);
      for (final entry in excel.tables.entries) {
        buffer.writeln('# Sayfa: ${entry.key}');
        for (final row in entry.value.rows) {
          final cells = row
              .map((c) => c?.value == null ? '' : c!.value.toString())
              .toList();
          table.add(cells);
          buffer.writeln(cells.join('\t'));
        }
        buffer.writeln();
      }
    } catch (e) {
      buffer.writeln('(Elektronik tablo okunamadı: $e)');
    }
    return LoadedDoc(
      path: path,
      name: name,
      kind: kind,
      plainText: buffer.toString().trimRight(),
      table: table,
    );
  }

  /// Dosyanın ilk ~8 KB'ına bakıp metin olup olmadığını tahmin eder. Metinse
  /// tüm içeriği döndürür, ikili (binary) ise null.
  Future<String?> _sniffText(File file) async {
    try {
      final len = await file.length();
      if (len == 0) return '';
      final raf = await file.open();
      final sample = await raf.read(len < 8192 ? len : 8192);
      await raf.close();
      // NUL bayt neredeyse kesin ikili demektir.
      if (sample.contains(0)) return null;
      final decoded = utf8.decode(sample, allowMalformed: true);
      if (decoded.isEmpty) return null;
      final runes = decoded.runes.toList();
      var bad = 0;
      for (final r in runes) {
        // U+FFFD (bozuk) veya yazdırılamayan kontrol karakteri.
        if (r == 0xFFFD || r < 9 || (r > 13 && r < 32)) bad++;
      }
      if (bad / runes.length > 0.1) return null; // çok bozuk → ikili
      return await _readTextSafely(file);
    } catch (_) {
      return null;
    }
  }

  Future<String> _readTextSafely(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  Future<void> saveText(String path, String content) async {
    await File(path).writeAsString(content);
  }

  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  int sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
