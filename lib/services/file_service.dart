import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../models/document.dart';
import 'csv_codec.dart';
import 'legacy_text.dart';
import 'office_reader.dart';
import 'text_decode.dart';
import 'xls_legacy.dart';

/// Dosya seçme, tür tespiti ve içerik yükleme.
class FileService {
  static const _textExts = {
    // düz metin / işaretleme
    'txt', 'text', 'md', 'markdown', 'rst', 'adoc', 'asciidoc', 'tex',
    'log', 'nfo', 'srt', 'vtt', 'diff', 'patch',
    // veri / yapılandırma (csv/tsv artık elektronik tablo ızgarasında açılır)
    'json', 'xml', 'yaml', 'yml', 'toml', 'ini', 'conf', 'cfg',
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

    // CSV/TSV: gerçek satır/sütun tablosuna çözülüp elektronik tablo ızgarasında
    // (salt-okunur) gösterilir — eski .xls ile aynı `table`+readOnly yolu.
    if (ext == 'csv' || ext == 'tsv') {
      final csv = await _loadCsv(file, path, name, ext);
      if (csv != null) return csv;
    }

    var kind = kindForExtension(ext);

    // Uzantı güvenilmezse içeriğin imza baytlarına bak. Paylaşım/URI ile gelen
    // dosyalarda ad/uzantı sıklıkla kaybolur (ör. WhatsApp'tan PDF uzantısız bir
    // önbellek yoluyla gelir) → uzantıya göre "unknown" çıkar. İmza (magic byte)
    // ile PDF/görsel/OOXML gerçek türü belirlenir. (Bug: WhatsApp PDF tanınmıyordu.)
    if (kind == DocKind.unknown) {
      kind = await _sniffKind(file);
    }

    // Hâlâ bilinmiyorsa içeriğe bak: metin gibiyse metin olarak aç.
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
        // Eski .doc bu noktaya gelmez (yukarıda isLegacyOffice ile ayrılır);
        // kind==word ise içerik daima OOXML .docx'tir (uzantı boş olsa bile).
        final bytes = await file.readAsBytes();
        final text = OfficeReader.extractDocxText(bytes);
        return LoadedDoc(path: path, name: name, kind: kind, plainText: text);

      case DocKind.slides:
        final bytes = await file.readAsBytes();
        final text = OfficeReader.extractPptxText(bytes);
        return LoadedDoc(path: path, name: name, kind: kind, plainText: text);

      case DocKind.spreadsheet:
        return _loadSpreadsheet(file, path, name, kind);

      case DocKind.pdf:
      case DocKind.image:
      case DocKind.unknown:
        return LoadedDoc(path: path, name: name, kind: kind);
    }
  }

  /// CSV/TSV dosyasını satır/sütun tablosuna çözüp salt-okunur elektronik
  /// tablo olarak yükler. Okunamazsa null (çağıran normal metin yoluna düşer).
  Future<LoadedDoc?> _loadCsv(
      File file, String path, String name, String ext) async {
    try {
      final text = await _readTextSafely(file);
      if (text.trim().isEmpty) return null;
      final rows = CsvCodec.parse(text);
      if (rows.isEmpty) return null;
      return LoadedDoc(
        path: path,
        name: name,
        kind: DocKind.spreadsheet,
        plainText: text, // AI sohbet bağlamı için ham metin de saklanır
        table: rows,
        readOnly: true,
      );
    } catch (_) {
      return null;
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
    // Excel.decodeBytes çok hücreli dosyalarda onlarca saniye sürebiliyor
    // (excel paketi, hücre başına stil çözümlemesi yapar). Ana izlekte koşarsa
    // uygulama donar → ANR → sistem öldürür (996×26 gerçek dosyada görüldü,
    // bkz. HAFIZA 2026-07-22). Bu yüzden arka plan isolate'inde çözümlenir.
    (String, List<List<String>>) result;
    try {
      result = await compute(_decodeSpreadsheet, bytes);
    } catch (_) {
      // isolate açılamazsa (test/kısıtlı ortam) ana izlekte çöz — işlev aynı.
      result = _decodeSpreadsheet(bytes);
    }
    return LoadedDoc(
      path: path,
      name: name,
      kind: kind,
      plainText: result.$1,
      table: result.$2,
    );
  }

  /// Ham .xlsx baytlarını (düz metin, tablo) çiftine çözer. `compute` ile arka
  /// plan isolate'inde çağrılabilmesi için üst-düzey durumsuz bir yardımcı.
  static (String, List<List<String>>) _decodeSpreadsheet(Uint8List bytes) {
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
    return (buffer.toString().trimRight(), table);
  }

  /// Dosyanın imza baytlarına (magic bytes) bakarak türünü belirler. Uzantı
  /// yoksa/güvenilmezse kullanılır (paylaşım/URI ile gelen dosyalar). Tanınmazsa
  /// [DocKind.unknown].
  Future<DocKind> _sniffKind(File file) async {
    Uint8List head;
    try {
      final raf = await file.open();
      head = await raf.read(16);
      await raf.close();
    } catch (_) {
      return DocKind.unknown;
    }
    if (head.length < 4) return DocKind.unknown;
    bool at(int i, List<int> sig) {
      if (i + sig.length > head.length) return false;
      for (var k = 0; k < sig.length; k++) {
        if (head[i + k] != sig[k]) return false;
      }
      return true;
    }

    // PDF: "%PDF"
    if (at(0, [0x25, 0x50, 0x44, 0x46])) return DocKind.pdf;
    // Görseller
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return DocKind.image; // PNG
    if (at(0, [0xFF, 0xD8, 0xFF])) return DocKind.image; // JPEG
    if (at(0, [0x47, 0x49, 0x46, 0x38])) return DocKind.image; // GIF8
    if (at(0, [0x42, 0x4D])) return DocKind.image; // BMP
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return DocKind.image; // WEBP (RIFF....WEBP)
    }
    // HEIC/HEIF: ftyp + heic/heix/mif1/heif markası (yalnızca bu markalar; mp4
    // gibi diğer ftyp'ler görsel değil, dışarıda bırakılır).
    if (at(4, [0x66, 0x74, 0x79, 0x70]) &&
        (at(8, [0x68, 0x65, 0x69, 0x63]) ||
            at(8, [0x68, 0x65, 0x69, 0x78]) ||
            at(8, [0x6D, 0x69, 0x66, 0x31]) ||
            at(8, [0x68, 0x65, 0x69, 0x66]))) {
      return DocKind.image;
    }
    // ZIP (PK\x03\x04) → OOXML: içine bakıp docx/xlsx/pptx ayır.
    if (at(0, [0x50, 0x4B, 0x03, 0x04])) return await _sniffZipKind(file);
    return DocKind.unknown;
  }

  /// Bir zip'in (PK) içindeki bölüm adlarına bakarak OOXML türünü belirler.
  Future<DocKind> _sniffZipKind(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      if (names.any((n) => n.startsWith('word/'))) return DocKind.word;
      if (names.any((n) => n.startsWith('xl/'))) return DocKind.spreadsheet;
      if (names.any((n) => n.startsWith('ppt/'))) return DocKind.slides;
    } catch (_) {}
    return DocKind.unknown;
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
    // BOM temizleme + UTF-8 → Windows-1254 (Türkçe) düşüşü (bkz. TextDecode).
    return TextDecode.decode(bytes);
  }

  Future<void> saveText(String path, String content) async {
    await File(path).writeAsString(content);
  }

  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  /// İkili içeriği [path]'e yazar (PDF vurgu annotation'ı gibi düzenlenmiş
  /// baytlar için). flush: yeniden açmadan önce disk güncel olsun.
  Future<void> writeBytes(String path, List<int> bytes) =>
      File(path).writeAsBytes(bytes, flush: true);

  int sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
