import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'legacy_convert.dart';
import 'ocr_service.dart';
import 'scan_page_ops.dart';
import 'xlsx_writer.dart';

/// PDF kalitesi (Faz 35 / madde 3): sayfa uzun kenarı + JPEG kalitesi.
enum ScanQuality { small, medium, high }

extension ScanQualityInfo on ScanQuality {
  String get labelKey => switch (this) {
        ScanQuality.small => 'sx.q_small',
        ScanQuality.medium => 'sx.q_medium',
        ScanQuality.high => 'sx.q_high',
      };

  /// Sayfa uzun kenarı (px): ~100 / ~150 / ~300 dpi A4.
  int get maxEdge => switch (this) {
        ScanQuality.small => 1240,
        ScanQuality.medium => 1754,
        ScanQuality.high => 2480,
      };

  int get jpegQuality => switch (this) {
        ScanQuality.small => 60,
        ScanQuality.medium => 75,
        ScanQuality.high => 88,
      };
}

/// İzolat isteği: tek sayfa → kaliteye göre yeniden kodlanmış JPEG.
class ScanCompressRequest {
  final String source;
  final String target;
  final int maxEdge;
  final int quality;
  const ScanCompressRequest(this.source, this.target, this.maxEdge, this.quality);
}

/// **Akıllı çıktı** (Faz 35 / madde 3): taramayı Word'e, Excel'e (tablo
/// algılayarak), TXT'ye ve seçilen kalitede PDF'e çevirir. Görsel işleri
/// izolatta, sayfa sayfa SIRAYLA (aynı anda tek görsel bellekte —
/// performans anayasası k.1); metin çıktıları zaten tanınmış OCR satırlarından.
abstract final class ScanExport {
  // ── kalite / boyut ──────────────────────────────────────────────────────

  /// Sayfaları [quality]'ye göre küçültüp yeniden kodlar; geçici yolu ve
  /// küçültme oranını döndürür (OCR kutuları bu oranla ölçeklenir —
  /// [scaleLines]). [onProgress] sayfa sayfa.
  static Future<List<({String path, double ratio})>> compressPages(
    List<String> pages,
    ScanQuality quality, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = <({String path, double ratio})>[];
    for (var i = 0; i < pages.length; i++) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call(i, pages.length);
      final target = p.join(dir.path,
          '${ScanPageOps.shortBase(pages[i])}_kalite_${i}_$stamp.jpg');
      final ratio = await compute(runCompress,
          ScanCompressRequest(pages[i], target, quality.maxEdge, quality.jpegQuality));
      out.add((path: target, ratio: ratio));
    }
    onProgress?.call(pages.length, pages.length);
    return out;
  }

  /// İzolat girişi: hedefi yazar, küçültme oranını (≤ 1) döndürür.
  static double runCompress(ScanCompressRequest r) {
    final bytes = File(r.source).readAsBytesSync();
    final res = compressBytesWithRatio(bytes, r.maxEdge, r.quality);
    File(r.target).writeAsBytesSync(res.bytes, flush: true);
    return res.ratio;
  }

  /// Saf kısım (birim testli): uzun kenarı [maxEdge]'e indirir, JPEG kodlar.
  static Uint8List compressBytes(Uint8List bytes, int maxEdge, int quality) =>
      compressBytesWithRatio(bytes, maxEdge, quality).bytes;

  static ({Uint8List bytes, double ratio}) compressBytesWithRatio(
      Uint8List bytes, int maxEdge, int quality) {
    var image = ScanPageOps.decode(bytes);
    if (image == null) return (bytes: bytes, ratio: 1.0);
    var ratio = 1.0;
    final long = math.max(image.width, image.height);
    if (long > maxEdge) {
      ratio = maxEdge / long;
      image = img.copyResize(image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.average);
    }
    return (bytes: img.encodeJpg(image, quality: quality), ratio: ratio);
  }

  /// OCR kutularını küçültülmüş görsele taşır.
  static List<OcrLine> scaleLines(List<OcrLine> lines, double ratio) => ratio == 1
      ? lines
      : [
          for (final l in lines)
            OcrLine(
                l.text,
                Rect.fromLTRB(l.box.left * ratio, l.box.top * ratio,
                    l.box.right * ratio, l.box.bottom * ratio)),
        ];

  /// PDF boyutu tahmini (bayt): ilk sayfa (en çok 1) örneklenip sayfa
  /// sayısıyla çarpılır + PDF iskeleti payı. Önizleme amaçlı; hızlı.
  static Future<Map<ScanQuality, int>> estimateSizes(List<String> pages) async {
    if (pages.isEmpty) return const {};
    final sizes = await compute(_estimateFirst, pages.first);
    return {
      for (final q in ScanQuality.values)
        q: estimateFromSample(sizes[q.index], pages.length),
    };
  }

  static List<int> _estimateFirst(String path) {
    final bytes = File(path).readAsBytesSync();
    return [
      for (final q in ScanQuality.values)
        compressBytes(bytes, q.maxEdge, q.jpegQuality).length,
    ];
  }

  /// Örnek sayfa boyutundan toplam: sayfa başı ~1,5 KB nesne/OCR katmanı +
  /// ~8 KB gömülü yazı tipi ve iskelet.
  static int estimateFromSample(int sampleBytes, int pageCount) =>
      sampleBytes * pageCount + 1536 * pageCount + 8192;

  // ── metin çıktıları ─────────────────────────────────────────────────────

  /// Sayfaların düz metni; sayfalar boş satırla ayrılır.
  static String plainText(List<List<OcrLine>> pages) => [
        for (final lines in pages)
          lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('\n'),
      ].where((t) => t.isNotEmpty).join('\n\n');

  /// UTF-8 (BOM'lu: eski Not Defteri Türkçe karakteri bozmasın).
  static Uint8List toTxt(List<List<OcrLine>> pages) => Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(plainText(pages))]);

  /// Düzenlenebilir Word belgesi (paragraflar korunur).
  static Uint8List toDocx(List<List<OcrLine>> pages) =>
      LegacyConvert.docxFromText(plainText(pages));

  /// Excel: her sayfa bir çalışma sayfası; satırlar/sütunlar OCR kutularından
  /// algılanır ([detectTable]); sayı görünen hücre sayı olarak yazılır.
  static Uint8List toXlsx(List<List<OcrLine>> pages, {String sheetPrefix = 'Sayfa'}) {
    final sheets = <XlsxWriteSheet>[];
    for (var i = 0; i < pages.length; i++) {
      final table = detectTable(pages[i]);
      final cells = <int, Map<int, XlsxWriteCell>>{};
      final widths = <int, double>{};
      for (var r = 0; r < table.length; r++) {
        for (var c = 0; c < table[r].length; c++) {
          final text = table[r][c].trim();
          if (text.isEmpty) continue;
          final number = parseNumber(text);
          (cells[r] ??= {})[c] = number != null
              ? XlsxWriteCell(number: number)
              : XlsxWriteCell(text: text);
          widths[c] = math.max(widths[c] ?? 8, math.min(60, text.length + 2.0));
        }
      }
      sheets.add(XlsxWriteSheet(
          name: '$sheetPrefix${i + 1}', cells: cells, colWidths: widths));
    }
    return XlsxWriter.build(sheets);
  }

  /// **Tablo algılama** (saf, birim testli): OCR satır kutuları önce dikey
  /// örtüşmeye göre SATIRLARA, sonra sol kenarları yakın olanlar SÜTUNLARA
  /// kümelenir. Tablo olmayan düz metinde her satır tek hücreli satır olur
  /// (yine okunur bir Excel).
  static List<List<String>> detectTable(List<OcrLine> lines) {
    final items = [
      for (final l in lines)
        if (l.text.trim().isNotEmpty) l,
    ]..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
    if (items.isEmpty) return const [];

    // 1) Satırlar: merkez y'si mevcut satırın dikey aralığına düşen kutu o
    //    satıra girer.
    final rows = <List<OcrLine>>[];
    Rect? band;
    for (final l in items) {
      if (band != null &&
          l.box.center.dy >= band.top &&
          l.box.center.dy <= band.bottom) {
        rows.last.add(l);
        band = band.expandToInclude(l.box);
        continue;
      }
      rows.add([l]);
      band = l.box;
    }
    for (final r in rows) {
      r.sort((a, b) => a.box.left.compareTo(b.box.left));
    }

    // 2) Sütun çapaları: yalnız ÇOK hücreli satırların sol kenarları.
    final heights = [for (final l in items) l.box.height]..sort();
    final tol = math.max(8.0, heights[heights.length ~/ 2] * 1.2);
    final anchors = <double>[];
    for (final r in rows.where((r) => r.length > 1)) {
      for (final l in r) {
        final x = l.box.left;
        final near = anchors.indexWhere((a) => (a - x).abs() <= tol);
        if (near < 0) {
          anchors.add(x);
        } else {
          anchors[near] = (anchors[near] + x) / 2;
        }
      }
    }
    anchors.sort();

    // 3) Hücreler: her kutu en yakın çapanın sütununa; çakışırsa birleşir.
    return [
      for (final r in rows)
        if (r.length == 1 || anchors.isEmpty)
          [r.map((l) => l.text.trim()).join(' ')]
        else
          () {
            final cells = List<String>.filled(anchors.length, '');
            for (final l in r) {
              var best = 0;
              for (var i = 1; i < anchors.length; i++) {
                if ((anchors[i] - l.box.left).abs() <
                    (anchors[best] - l.box.left).abs()) {
                  best = i;
                }
              }
              cells[best] = cells[best].isEmpty
                  ? l.text.trim()
                  : '${cells[best]} ${l.text.trim()}';
            }
            return cells;
          }(),
    ];
  }

  /// "1.234,56" / "1,234.56" / "%18" / "₺ 250" → sayı; değilse null.
  static double? parseNumber(String text) {
    var s = text.replaceAll(RegExp(r'[\s₺$€£%]|TL', caseSensitive: false), '');
    if (s.isEmpty || !RegExp(r'^-?[\d.,]+$').hasMatch(s)) return null;
    // Baştaki 0 + rakam (telefon, posta kodu, fatura no) metin kalır.
    if (RegExp(r'^-?0\d').hasMatch(s)) return null;
    final lastDot = s.lastIndexOf('.'), lastComma = s.lastIndexOf(',');
    if (lastDot >= 0 && lastComma >= 0) {
      // Sondaki ayraç ondalık.
      s = lastComma > lastDot
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (lastComma >= 0) {
      // Tek virgül + 1-2 hane → ondalık (TR); değilse binlik.
      final dec = s.length - lastComma - 1;
      s = (s.indexOf(',') == lastComma && dec <= 2)
          ? s.replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else if (lastDot >= 0) {
      final dec = s.length - lastDot - 1;
      if (s.indexOf('.') != lastDot || dec == 3) s = s.replaceAll('.', '');
    }
    return double.tryParse(s);
  }
}
