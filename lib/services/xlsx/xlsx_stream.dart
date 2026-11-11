import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// **Büyük xlsx akış okuyucusu** (Faz 42 / 2 — performans anayasası k.10).
///
/// Tam ayrıştırma (`XlsxReader.read`) dosyanın tamamını belleğe alır, sonra
/// sayfa XML'ini METİN olarak açar: 100 MB'lık bir xlsx ~1 GB XML demektir ve
/// telefonda bellek öldürmesiyle biter. Bu okuyucu:
/// - zip'i `InputFileStream` ile açar (yalnız dizin okunur, dosya belleğe
///   alınmaz);
/// - paylaşılan dizeleri ve sayfaları GEÇİCİ dosyaya açar (`writeContent`),
///   sonra XML **olay akışıyla** satır satır okur;
/// - en çok [maxCells] hücre tutar (bellek tavanı, `PerfBudget`), aşınca
///   akışı keser ve [XlsxStreamResult.truncated] işaretler.
///
/// Sonuç salt okunur önizlemedir: düzenleyici kesilmiş kitabı kaydetmez
/// (`XlsxTruncatedException`). Ana iş parçacığında koşmaz — [readInBackground].
class XlsxStreamSheet {
  final String name;

  /// Satır → (sütun → ham değer). Seyrek: boş hücre tutulmaz.
  final Map<int, Map<int, String>> cells;
  int maxRow = -1, maxCol = -1;

  XlsxStreamSheet(this.name) : cells = {};

  int get cellCount => cells.values.fold(0, (a, r) => a + r.length);
}

class XlsxStreamResult {
  final List<XlsxStreamSheet> sheets;

  /// Hücre ya da dize tavanına takıldı (dosyanın tamamı okunmadı).
  final bool truncated;
  final int cellCount;

  const XlsxStreamResult(this.sheets,
      {required this.truncated, required this.cellCount});
}

/// İzolata taşınan istek (yalnız basit alanlar).
class XlsxStreamRequest {
  final String path;
  final String tempDir;
  final int maxCells;
  final int maxSharedChars;
  const XlsxStreamRequest(this.path,
      {required this.tempDir,
      required this.maxCells,
      required this.maxSharedChars});
}

abstract final class XlsxStream {
  /// İzolat giriş noktası (`compute`/`Isolate.run`).
  static Future<XlsxStreamResult> readInBackground(XlsxStreamRequest r) => read(
      r.path,
      tempDir: r.tempDir,
      maxCells: r.maxCells,
      maxSharedChars: r.maxSharedChars);

  static Future<XlsxStreamResult> read(
    String path, {
    required String tempDir,
    required int maxCells,
    int maxSharedChars = 24 << 20,
  }) async {
    final input = InputFileStream(path);
    final work = Directory(p.join(tempDir,
        'xlsx_stream_${DateTime.now().microsecondsSinceEpoch}'))
      ..createSync(recursive: true);
    try {
      final archive = ZipDecoder().decodeStream(input);
      ArchiveFile? entry(String name) {
        final want = name.toLowerCase();
        for (final f in archive.files) {
          final n = f.name.replaceAll('\\', '/').toLowerCase();
          if (n == want || n == '/$want') return f;
        }
        return null;
      }

      final sheetsMeta = _sheetTargets(entry);
      if (sheetsMeta.isEmpty) {
        throw const FormatException('xlsx: sayfa bulunamadı');
      }

      final shared = <String>[];
      var sharedTruncated = false;
      final ss = entry('xl/sharedStrings.xml');
      if (ss != null) {
        sharedTruncated = await _readShared(
            _unpack(ss, work, 'shared.xml'), shared, maxSharedChars);
      }

      final out = <XlsxStreamSheet>[];
      var total = 0;
      var truncated = sharedTruncated;
      for (final (name, target) in sheetsMeta) {
        final sheet = XlsxStreamSheet(name);
        out.add(sheet);
        if (total >= maxCells) {
          truncated = true;
          continue;
        }
        final f = entry(target);
        if (f == null) continue;
        final file = _unpack(f, work, 'sheet_${out.length}.xml');
        final cut = await _readSheet(file, sheet, shared, maxCells - total);
        file.deleteSync();
        total += sheet.cellCount;
        truncated |= cut;
      }
      return XlsxStreamResult(out, truncated: truncated, cellCount: total);
    } finally {
      input.closeSync();
      try {
        work.deleteSync(recursive: true);
      } catch (_) {
        // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
      }
    }
  }

  /// Zip girdisini geçici dosyaya açar (girdi belleğe toptan alınmaz).
  static File _unpack(ArchiveFile f, Directory work, String name) {
    final path = p.join(work.path, name);
    final out = OutputFileStream(path);
    try {
      f.writeContent(out);
    } finally {
      out.closeSync();
    }
    return File(path);
  }

  /// (sayfa adı, zip yolu) — workbook.xml + ilişkiler. Bunlar küçük dosyalar,
  /// DOM ile okunur.
  static List<(String, String)> _sheetTargets(
      ArchiveFile? Function(String) entry) {
    final wb = entry('xl/workbook.xml');
    if (wb == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(wb.content, allowMalformed: true));
    final rels = <String, String>{};
    final relFile = entry('xl/_rels/workbook.xml.rels');
    if (relFile != null) {
      final rd =
          XmlDocument.parse(utf8.decode(relFile.content, allowMalformed: true));
      for (final r in rd.descendants.whereType<XmlElement>()) {
        if (r.name.local != 'Relationship') continue;
        final id = r.getAttribute('Id');
        final target = r.getAttribute('Target');
        if (id == null || target == null) continue;
        rels[id] = target.startsWith('/')
            ? target.substring(1)
            : p.posix.normalize('xl/$target');
      }
    }
    final out = <(String, String)>[];
    var i = 0;
    for (final s in doc.descendants.whereType<XmlElement>()) {
      if (s.name.local != 'sheet') continue;
      i++;
      final id = s.attributes
          .where((a) => a.name.local == 'id')
          .map((a) => a.value)
          .firstOrNull;
      out.add((
        s.getAttribute('name') ?? 'Sayfa$i',
        rels[id] ?? 'xl/worksheets/sheet$i.xml',
      ));
    }
    return out;
  }

  static Stream<XmlEvent> _events(File f) => f
      .openRead()
      .transform(utf8.decoder)
      .toXmlEvents()
      .normalizeEvents()
      .flatten();

  static String _local(String name) {
    final i = name.indexOf(':');
    return i < 0 ? name : name.substring(i + 1);
  }

  /// `<si>` başına bir dize; fonetik (`rPh`) metni atlanır. Karakter tavanı
  /// aşılınca kalan dizeler boş tutulur (dizin kaymasın). Kesildiyse true.
  static Future<bool> _readShared(
      File f, List<String> out, int maxChars) async {
    var chars = 0;
    var cut = false;
    StringBuffer? si;
    var inT = false, inPh = false;
    await for (final e in _events(f)) {
      if (e is XmlStartElementEvent) {
        final n = _local(e.name);
        if (n == 'si') {
          si = StringBuffer();
          if (e.isSelfClosing) {
            out.add('');
            si = null;
          }
        } else if (n == 't') {
          inT = !e.isSelfClosing;
        } else if (n == 'rPh') {
          inPh = !e.isSelfClosing;
        }
      } else if (e is XmlEndElementEvent) {
        final n = _local(e.name);
        if (n == 'si' && si != null) {
          final s = si.toString();
          if (chars + s.length > maxChars) {
            cut = true;
            out.add('');
          } else {
            chars += s.length;
            out.add(s);
          }
          si = null;
        } else if (n == 't') {
          inT = false;
        } else if (n == 'rPh') {
          inPh = false;
        }
      } else if (e is XmlTextEvent || e is XmlCDATAEvent) {
        if (si != null && inT && !inPh) {
          si.write(e is XmlTextEvent ? e.value : (e as XmlCDATAEvent).value);
        }
      }
    }
    return cut;
  }

  /// Sayfa XML'ini olay akışıyla okur; [budget] hücreye ulaşınca keser.
  static Future<bool> _readSheet(File f, XlsxStreamSheet sheet,
      List<String> shared, int budget) async {
    var count = 0;
    var row = -1, col = -1;
    String? type;
    StringBuffer? value; // <v> ya da satır içi <is><t>
    var inV = false, inIsT = false, inIs = false;
    await for (final e in _events(f)) {
      if (e is XmlStartElementEvent) {
        switch (_local(e.name)) {
          case 'row':
            final r = _attr(e, 'r');
            row = r == null ? row + 1 : (int.tryParse(r) ?? row + 2) - 1;
            col = -1;
          case 'c':
            final ref = _attr(e, 'r');
            col = ref == null ? col + 1 : (_colOf(ref) ?? col + 1);
            type = _attr(e, 't');
            value = StringBuffer();
            if (e.isSelfClosing) value = null;
          case 'v':
            inV = !e.isSelfClosing;
          case 'is':
            inIs = !e.isSelfClosing;
          case 't':
            inIsT = inIs && !e.isSelfClosing;
        }
      } else if (e is XmlEndElementEvent) {
        switch (_local(e.name)) {
          case 'v':
            inV = false;
          case 't':
            inIsT = false;
          case 'is':
            inIs = false;
          case 'c':
            final v = value;
            value = null;
            if (v == null || row < 0 || col < 0) break;
            final text = _cellText(type, v.toString(), shared);
            if (text.isEmpty) break;
            (sheet.cells[row] ??= {})[col] = text;
            if (row > sheet.maxRow) sheet.maxRow = row;
            if (col > sheet.maxCol) sheet.maxCol = col;
            if (++count >= budget) return true; // akış iptal → dosya kapanır
        }
      } else if (e is XmlTextEvent) {
        if (value != null && (inV || inIsT)) value.write(e.value);
      }
    }
    return false;
  }

  static String? _attr(XmlStartElementEvent e, String name) {
    for (final a in e.attributes) {
      if (_local(a.name) == name) return a.value;
    }
    return null;
  }

  static String _cellText(String? type, String raw, List<String> shared) {
    switch (type) {
      case 's':
        final i = int.tryParse(raw.trim());
        return (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
      case 'b':
        return raw.trim() == '1' ? 'TRUE' : 'FALSE';
      default:
        return raw;
    }
  }

  /// `BC12` → 54 (0 tabanlı sütun).
  static int? _colOf(String ref) {
    var c = 0, n = 0;
    for (final u in ref.codeUnits) {
      if (u >= 65 && u <= 90) {
        c = c * 26 + (u - 64);
      } else if (u >= 97 && u <= 122) {
        c = c * 26 + (u - 96);
      } else {
        break;
      }
      n++;
    }
    return n == 0 ? null : c - 1;
  }
}
