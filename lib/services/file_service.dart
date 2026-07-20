import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/document.dart';
import 'office_reader.dart';

/// Dosya seçme, tür tespiti ve içerik yükleme.
class FileService {
  static const _textExts = {
    'txt', 'md', 'markdown', 'json', 'xml', 'csv', 'tsv', 'html', 'htm',
    'yaml', 'yml', 'log', 'dart', 'py', 'js', 'ts', 'java', 'kt', 'c',
    'cpp', 'h', 'cs', 'go', 'rs', 'rb', 'php', 'sh', 'sql', 'ini', 'toml',
  };
  static const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'};

  static DocKind kindForExtension(String ext) {
    ext = ext.toLowerCase();
    if (ext == 'pdf') return DocKind.pdf;
    if (ext == 'xlsx' || ext == 'xls' || ext == 'xlsm') {
      return DocKind.spreadsheet;
    }
    if (ext == 'docx' || ext == 'doc') return DocKind.word;
    if (ext == 'pptx' || ext == 'ppt') return DocKind.slides;
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
    final kind = kindForExtension(ext);

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
