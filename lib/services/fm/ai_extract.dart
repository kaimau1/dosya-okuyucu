/// **Yerel içerik çıkarımı** — buluta gitmeden önce cihazda yapılan iş.
///
/// Toplu analizde maliyeti belirleyen tek şey, dosya başına Gemini'ye giden
/// karakter sayısı. Bu dosya o sayıyı olabildiğince küçük ve olabildiğince
/// **bilgilendirici** tutar:
///
/// - Metin dosyanın kendisinden çıkarılır (`FileService` — PDF/Office/metin
///   ayrıştırıcıları zaten var, yeniden yazılmaz).
/// - Görsellerde metin cihaz-içi OCR ile okunur (ML Kit, çevrimdışı, ücretsiz).
///   **Görselin kendisi buluta gitmez** — yalnız okunan metin gider, o da
///   ayarlarda "metin gönder" açıksa (`AiScope.allowsUpload`).
/// - Metin normalleştirilir: tekrarlanan boşluk/satır atılır, baştan
///   [AiScopeSettings.excerptKb] kadarı alınır. Bir belgenin ne olduğu
///   neredeyse her zaman ilk sayfasında yazar; 200 sayfalık sözleşmenin
///   tamamını yollamak katbekat pahalı, karşılığında neredeyse aynı özet.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../file_service.dart';
import '../ocr_service.dart';
import 'fs_scan.dart';

/// Bir dosyadan çıkarılan öz.
class AiExcerpt {
  /// Buluta gidecek metin (kırpılmış, normalleştirilmiş). Boş olabilir.
  final String text;

  /// Metin nereden geldi: `doc` (ayrıştırıcı), `ocr` (görselden), `none`.
  final String source;

  /// Çıkarım denendi ama olmadıysa kısa sebep (kullanıcıya gösterilmez, log).
  final String error;

  const AiExcerpt({this.text = '', this.source = 'none', this.error = ''});

  bool get isEmpty => text.trim().isEmpty;
}

abstract final class AiExtract {
  /// Bir dosyadan öz çıkarır. Hata fırlatmaz — analiz 30 bin dosyada tek bir
  /// bozuk PDF yüzünden durmamalı.
  static Future<AiExcerpt> excerpt(
    FsEntry entry, {
    required int maxChars,
    bool allowOcr = true,
  }) async {
    if (entry.isDir) return const AiExcerpt();
    try {
      if (entry.category == FmCategory.image) {
        if (!allowOcr) return const AiExcerpt();
        final text = await OcrService.recognizeImageFile(entry.path);
        return AiExcerpt(text: normalize(text, maxChars), source: 'ocr');
      }
      final doc = await FileService().load(entry.path);
      var text = doc.plainText;
      if (text.trim().isEmpty && doc.kind == DocKind.image && allowOcr) {
        text = await OcrService.recognizeImageFile(entry.path);
        return AiExcerpt(text: normalize(text, maxChars), source: 'ocr');
      }
      return AiExcerpt(text: normalize(text, maxChars), source: 'doc');
    } catch (e) {
      return AiExcerpt(error: '$e');
    }
  }

  /// Metni token açısından ucuzlatır: art arda boşluklar teke iner, üçten
  /// fazla boş satır ikiye düşer, baştan [maxChars] karakter alınır.
  ///
  /// Kırpma **karakter** üzerinden: kelime sınırına hizalamak metni
  /// güzelleştirir ama modele hiçbir şey katmaz.
  static String normalize(String raw, int maxChars) {
    if (raw.isEmpty) return '';
    final collapsed = raw
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (collapsed.length <= maxChars) return collapsed;
    return collapsed.substring(0, maxChars);
  }

  /// Dosyanın **meta satırı** — içerik okunamasa bile modele verilen bilgi.
  ///
  /// Yol bilinçli olarak yalnız son iki klasörle verilir: modelin işine yarayan
  /// şey "hangi klasörde" (`Download`, `WhatsApp/Media`), tam yol değil. Hem
  /// token yer hem de gereksiz bilgi paylaşımı olurdu.
  static String metaLine(FsEntry entry) {
    final dir = p.dirname(entry.path);
    final parts = p.split(dir);
    final tail = parts.length <= 2 ? dir : p.joinAll(parts.sublist(parts.length - 2));
    return '${entry.name} · ${FsPaths.humanSize(entry.sizeBytes)} · '
        '${_dateOnly(entry.modifiedMs)} · klasör: $tail';
  }

  static String _dateOnly(int ms) {
    if (ms <= 0) return 'tarihsiz';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Dosya gerçekten okunabiliyor mu? (İzin verilmeyen yollarda analiz
  /// başlamadan elenir — 500 dosyalık bir turun ortasında yığınla hata
  /// toplamaktansa baştan atlamak iyi.)
  static bool isReadable(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final handle = file.openSync();
      handle.closeSync();
      return true;
    } catch (_) {
      return false;
    }
  }
}
