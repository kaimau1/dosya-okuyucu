import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image/image.dart' as imglib;

import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/edition.dart';
import '../core/l10n/app_strings.dart';
import 'arabic_ocr.dart';
import 'cloud_ocr.dart';
import 'pdf/ocr_page_text.dart' show OcrWordBox;
import '../core/app_colors.dart';
import 'scan_enhance.dart' show ScanEnhance, ScanFilter;
import 'scan_page_ops.dart' show ScanPageOps;

/// Cihaz-içi OCR (Google ML Kit, Latin alfabesi — Türkçe karakterler dahil).
/// Arapça vb. Latin dışı alfabeler ML Kit'te yok → kullanıcının başlattığı
/// tanımada AI ile ([CloudOcr], `allowCloud`).
///
/// Tanıma cihazda, internetsiz yapılır. **Model APK'da DEĞİL** (2026-09-26):
/// CI, eklentinin gömülü `com.google.mlkit:text-recognition` bağımlılığını
/// Google Play Hizmetleri'nin paylaşılan modeline
/// (`play-services-mlkit-text-recognition`, aynı API) çeviriyor — APK ~12 MB
/// küçülüyor. Model uygulama kurulurken Play Hizmetleri'nce bir kez indiriliyor
/// (manifestteki `com.google.mlkit.vision.DEPENDENCIES = ocr`); henüz inmediyse
/// [OcrModelNotReady] (bkz. [_process]). Görsel dosyalardan ve taranmış (metin
/// katmanı olmayan) PDF'lerden metin çıkarır. PDF sayfaları pdfium ile
/// bitmap'e çizilir, geçici PNG üzerinden ML Kit'e verilir.
/// OCR'ın bulduğu tek metin satırı ve resmin piksel koordinatındaki kutusu.
class OcrLine {
  final String text;
  final ui.Rect box;
  const OcrLine(this.text, this.box);
}

/// Tek sayfanın metni (sayfa numarası 1'den başlar).
///
/// Niye sayfa sayfa: çeviri sayfa yapısını KORUMALI ("tüm sayfa olarak çevir",
/// kullanıcı isteği 2026-07-31). Metni tek dizede birleştirip içine
/// "— Sayfa 3 —" yazmak, o başlığın da çeviriye girmesi demekti; sayfa ayrımı
/// veride durursa başlığı arayüz kendi dilinde yazar ve çeviriye hiç sokmaz.
class OcrPage {
  final int number;
  final String text;
  const OcrPage(this.number, this.text);
}

/// Metin tanıma kalite kipi.
enum OcrQualityMode {
  /// Ham görüntü / 2048px JPEG — hızlı cihaz-içi tarama.
  fast,

  /// 2400px kayıpsız PNG + ışık/gölge düzeltmeli ön işleme + satır sırası.
  enhanced,

  /// Kendi Gemini anahtarıyla (Pro + BYOK) AI görüş OCR'ı.
  aiVision,
}

/// Metin tanıma modeli Play Hizmetleri'nce henüz indirilmedi.
///
/// `toString` kullanıcıya gösterilecek metni döner: çağıranların çoğu hatayı
/// `'$e'` diye şeride yazıyor — ham ML Kit iletisi ("Waiting for the text
/// optional module to be downloaded") yerine ne yapacağını söyleyen cümle.
class OcrModelNotReady implements Exception {
  const OcrModelNotReady();

  @override
  String toString() => AppStrings.current.t('ocr.model_downloading');
}

class OcrService {
  /// ML Kit'in "model henüz inmedi" hatası mı? (Play Hizmetleri modeli.)
  ///
  /// Eklenti hatayı `PlatformException` olarak, mesajında ML Kit'in iletisiyle
  /// taşıyor; kod yerine ileti aranıyor çünkü eklenti tüm hatalara aynı kodu
  /// veriyor. Saf fonksiyon → birim testli.
  static bool isModelDownloading(Object error) {
    final text = error is PlatformException
        ? '${error.message} ${error.details}'
        : '$error';
    final lower = text.toLowerCase();
    return lower.contains('optional module') ||
        lower.contains('waiting for the text');
  }

  /// İlk kullanımda model inerken yapılacak bekleme adımları (toplam ~15 sn):
  /// indirme çoğu zaman bu sürede biter ve kullanıcı hiçbir şey fark etmez.
  static const modelRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 5),
  ];

  /// `processImage` + "model iniyor" hatasında kısa bekleyip yeniden deneme.
  static Future<RecognizedText> _process(
      TextRecognizer recognizer, String path) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await recognizer.processImage(InputImage.fromFilePath(path));
      } catch (e) {
        if (!isModelDownloading(e)) rethrow;
        if (attempt >= modelRetryDelays.length) throw const OcrModelNotReady();
        await Future<void>.delayed(modelRetryDelays[attempt]);
      }
    }
  }

  /// Ayar "Arapça" ve tanımayı kullanıcı başlattıysa: Latin modeli hiç
  /// koşmaz. Önce cihazdaki Arapça motor ([ArabicOcr], B16 — internetsiz);
  /// kurulu değilse ya da düşerse AI ([CloudOcr]) — o da yoksa açık hata
  /// (kullanıcı neden tanınmadığını ve ne yapacağını görmeli).
  static Future<List<OcrLine>?> _forcedArabic(
      String path, bool allowCloud) async {
    if (!allowCloud || await CloudOcr.script() != OcrScript.arabic) return null;
    if (ArabicOcr.installed) {
      try {
        return await ArabicOcr.recognize(path);
      } catch (_) {
        if (!CloudOcr.available) rethrow;
      }
    } else if (!CloudOcr.available) {
      throw const ArabicOcrMissing();
    }
    return CloudOcr.lines(path);
  }

  /// "Otomatik": cihazdaki Latin sonucu zayıf/bozuksa önce cihazdaki Arapça
  /// motor (kuruluysa; sonuçta Arapça harf varsa o kalır), sonra Decisions
  /// API görselde Latin dışı yazı ya da el yazısı görürse AI. Her hata
  /// sessiz: cihazdaki sonuç kalır (null).
  static Future<List<OcrLine>?> _autoArabic(
      String path, String latinText, bool allowCloud) async {
    if (!allowCloud ||
        await CloudOcr.script() != OcrScript.auto ||
        !(CloudOcr.looksWeak(latinText) ||
            CloudOcr.looksGarbled(latinText))) {
      return null;
    }
    if (ArabicOcr.installed) {
      try {
        final local = await ArabicOcr.recognize(path);
        if (hasArabicText(local.map((l) => l.text).join(' '))) return local;
      } catch (_) {
        // Bilinçli: yerel motor düşerse AI / Latin sonucu denenir.
      }
    }
    if (!CloudOcr.available) return null;
    if (!await CloudOcr.hasNonLatinScript(path)) return null;
    try {
      final lines = await CloudOcr.lines(path);
      return lines.isEmpty ? null : lines;
    } catch (_) {
      return null; // Bilinçli: bulut düşerse cihazdaki sonuç gösterilir.
    }
  }

  /// En az 8 Arapça harf (Arapça bloğu + sunum biçimleri). Saf → testli.
  static bool hasArabicText(String text) =>
      RegExp('[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFC]')
          .allMatches(text)
          .length >=
      8;

  static String _joinLines(List<OcrLine> lines) =>
      formatOrderedLines(orderOcrRows(lines));

  static List<OcrLine> _recognizedLines(RecognizedText result) => [
        for (final block in result.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty)
              OcrLine(line.text, line.boundingBox),
      ];

  static List<List<OcrLine>> _clusterRows(List<OcrLine> raw) {
    final rows = <List<OcrLine>>[];
    for (final line in raw) {
      if (line.text.trim().isEmpty) continue;
      if (rows.isEmpty) {
        rows.add([line]);
        continue;
      }
      final cur = rows.last;
      var rowTop = cur.first.box.top;
      var rowBottom = cur.first.box.bottom;
      for (var i = 1; i < cur.length; i++) {
        if (cur[i].box.top < rowTop) rowTop = cur[i].box.top;
        if (cur[i].box.bottom > rowBottom) rowBottom = cur[i].box.bottom;
      }
      final overlap =
          math.min(rowBottom, line.box.bottom) - math.max(rowTop, line.box.top);
      final minH = math.min(rowBottom - rowTop, line.box.height);
      final sameRow = minH <= 0
          ? (line.box.top - rowTop).abs() <= 4
          : overlap >= minH * 0.45;
      if (sameRow) {
        cur.add(line);
      } else {
        rows.add([line]);
      }
    }
    return rows;
  }

  /// Ham OCR satırlarını görsel okuma sırasına sokar: üstten alta görsel
  /// satır kümeleri (dikeyi %45+ örtüşen parçalar aynı satır sayılır), satır
  /// içinde soldan sağa sıralanır. Saf -> testli.
  static List<OcrLine> orderOcrRows(List<OcrLine> raw) {
    if (raw.length <= 1) return raw;
    final nonEmpty = [
      for (final l in raw)
        if (l.text.trim().isNotEmpty) l,
    ];
    if (nonEmpty.length <= 1) return nonEmpty;
    final byTop = [...nonEmpty]..sort((a, b) {
        final dy = a.box.top.compareTo(b.box.top);
        return dy != 0 ? dy : a.box.left.compareTo(b.box.left);
      });
    final rows = _clusterRows(byTop);
    for (final row in rows) {
      row.sort((a, b) => a.box.left.compareTo(b.box.left));
    }
    return [for (final row in rows) ...row];
  }

  /// Sıralı [OcrLine] listesini okunaklı satır ve paragraflara biçimlendirir:
  /// yatayda büyük sütun boşluğu `\t`, normal akış `  `, ortanca satır
  /// yüksekliğinin 1.6 katını aşan dikey boşlukta paragraf ayrımı (`\n\n`).
  static String formatOrderedLines(List<OcrLine> ordered) {
    final rows = _clusterRows(ordered);
    if (rows.isEmpty) return '';
    final heights = [
      for (final r in rows) r.map((e) => e.box.height).fold(0.0, math.max),
    ]..sort();
    final medH = heights[heights.length ~/ 2] <= 0
        ? 16.0
        : heights[heights.length ~/ 2];

    final sb = StringBuffer();
    double? prevBottom;
    for (final rawRow in rows) {
      final row = [...rawRow]..sort((a, b) => a.box.left.compareTo(b.box.left));
      final rowTop = row.map((e) => e.box.top).reduce(math.min);
      final rowBottom = row.map((e) => e.box.bottom).reduce(math.max);
      final rowH = (rowBottom - rowTop) > 0 ? (rowBottom - rowTop) : medH;
      if (prevBottom != null) {
        sb.write((rowTop - prevBottom) > medH * 1.1 ? '\n\n' : '\n');
      }
      for (var i = 0; i < row.length; i++) {
        if (i > 0) {
          final hGap = row[i].box.left - row[i - 1].box.right;
          sb.write(hGap > rowH * 2.0 ? '\t' : '  ');
        }
        sb.write(row[i].text.trim());
      }
      prevBottom = rowBottom;
    }
    return sb.toString().trim();
  }

  /// Görseli OCR öncesinde izolatta temizler (EXIF pişirme + ışık/gölge
  /// eşitleme + metin keskinleştirme) ve kayıpsız PNG yazar.
  static Future<({String path, double sx, double sy})?> _preprocessImageForOcr(
      String sourcePath) async {
    try {
      final outPath =
          '${Directory.systemTemp.path}/ocr_prep_${DateTime.now().microsecondsSinceEpoch}.png';
      final dims = await Isolate.run(() {
        final file = File(sourcePath);
        if (!file.existsSync()) return null;
        final decoded = ScanPageOps.decode(file.readAsBytesSync());
        if (decoded == null || decoded.width < 16 || decoded.height < 16) {
          return null;
        }
        final origW = decoded.width, origH = decoded.height;
        final enhanced = ScanEnhance.applyToImage(decoded, ScanFilter.gray);
        File(outPath).writeAsBytesSync(imglib.encodePng(enhanced));
        return (origW, origH, enhanced.width, enhanced.height);
      });
      if (dims == null) return null;
      return (
        path: outPath,
        sx: dims.$1 / dims.$3,
        sy: dims.$2 / dims.$4,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<OcrLine>> _requireAiVision(String path) async {
    if (!Edition.current.has(Feature.ai) || !CloudOcr.available) {
      throw StateError(AppStrings.current.t('uerr.ai_key'));
    }
    return CloudOcr.lines(path);
  }

  static void _deleteTemp(String? path) {
    if (path == null) return;
    try {
      File(path).deleteSync();
    } catch (_) {
      // Bilinçli: geçici OCR görseli temizliği en iyi çaba.
    }
  }

  static List<List<OcrWordBox>> _wordLines(List<OcrLine> lines) => [
        for (final line in lines)
          [for (final w in CloudOcr.words(line)) OcrWordBox(w.text, w.box)],
      ];

  /// Tek OCR turunda işlenecek en fazla PDF sayfası (süre/pil koruması).
  ///
  /// "Metni tanı" sayfasının varsayılanı budur. Belge ÇEVİRİSİ bu sınırı
  /// [recognizePdfPages]'in `maxPages`'iyle aşabilir: orada kullanıcı işi
  /// istediği an durdurabiliyor ve durdurulan iş o ana kadarki sayfaları
  /// gösteriyor — yani uzun belgede kararı kullanıcı veriyor, sabit bir
  /// kesme değil.
  static const maxPdfPages = 25;

  /// Bir görsel dosyadan metin tanır. Metin yoksa boş dize döner.
  ///
  /// [allowCloud]: kullanıcının başlattığı tanıma — Arapça vb. için AI'ya
  /// gidilebilir ([CloudOcr]). Arka plan işleri (içerik dizini) false bırakır.
  static Future<String> recognizeImageFile(
    String path, {
    bool allowCloud = false,
    OcrQualityMode mode = OcrQualityMode.enhanced,
  }) async {
    if (mode == OcrQualityMode.aiVision) {
      return _joinLines(await _requireAiVision(path));
    }
    final forced = await _forcedArabic(path, allowCloud);
    if (forced != null) return _joinLines(forced);
    final prep = mode == OcrQualityMode.enhanced
        ? await _preprocessImageForOcr(path)
        : null;
    final workPath = prep?.path ?? path;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<OcrLine> lines;
    try {
      final result = await _process(recognizer, workPath);
      lines = orderOcrRows(_recognizedLines(result));
    } finally {
      await recognizer.close();
      if (prep != null) _deleteTemp(prep.path);
    }
    final text = mode == OcrQualityMode.fast
        ? lines.map((l) => l.text).join('\n').trim()
        : formatOrderedLines(lines);
    final cloud = await _autoArabic(path, text, allowCloud);
    return cloud != null ? _joinLines(cloud) : text;
  }

  /// Bir görselden metni SATIR SATIR, resim piksel koordinatındaki kutusuyla
  /// birlikte tanır. Aranabilir PDF üretiminde (görünmez metin katmanı) her
  /// satırı kendi yerine yazmak için gerekir.
  static Future<List<OcrLine>> recognizeImageLines(
    String path, {
    bool allowCloud = false,
    OcrQualityMode mode = OcrQualityMode.enhanced,
  }) async {
    if (mode == OcrQualityMode.aiVision) {
      return orderOcrRows(await _requireAiVision(path));
    }
    final forced = await _forcedArabic(path, allowCloud);
    if (forced != null) return orderOcrRows(forced);
    final prep = mode == OcrQualityMode.enhanced
        ? await _preprocessImageForOcr(path)
        : null;
    final workPath = prep?.path ?? path;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<OcrLine> lines;
    try {
      final result = await _process(recognizer, workPath);
      final sx = prep?.sx ?? 1.0;
      final sy = prep?.sy ?? 1.0;
      lines = orderOcrRows([
        for (final l in _recognizedLines(result))
          sx == 1.0 && sy == 1.0
              ? l
              : OcrLine(
                  l.text,
                  ui.Rect.fromLTRB(
                    l.box.left * sx,
                    l.box.top * sy,
                    l.box.right * sx,
                    l.box.bottom * sy,
                  ),
                ),
      ]);
    } finally {
      await recognizer.close();
      if (prep != null) _deleteTemp(prep.path);
    }
    return await _autoArabic(path, _joinLines(lines), allowCloud) ?? lines;
  }

  /// Birden çok görselden metni satır satır, kutularıyla birlikte tanır.
  ///
  /// Tüm sayfalar boyunca **TEK [TextRecognizer]** paylaşır (her sayfa için
  /// yerel motoru açıp kapatmaz). İlk sayfada [OcrModelNotReady] yakalanırsa
  /// kalan sayfalar için 15 sn × N tekrar yapmadan döngüyü hemen sonlandırır
  /// ve [onModelNotReady] ile bildirir.
  static Future<List<List<OcrLine>>> recognizeImagesLines(
    List<String> paths, {
    bool allowCloud = false,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    void Function(OcrModelNotReady)? onModelNotReady,
  }) async {
    if (paths.isEmpty) return const [];
    final out = <List<OcrLine>>[];
    TextRecognizer? recognizer;
    try {
      for (var i = 0; i < paths.length; i++) {
        if (isCancelled?.call() ?? false) break;
        onProgress?.call(i, paths.length);
        final path = paths[i];
        try {
          final forced = await _forcedArabic(path, allowCloud);
          if (forced != null) {
            out.add(forced);
            continue;
          }
          recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
          final result = await _process(recognizer, path);
          final lines = orderOcrRows(_recognizedLines(result));
          out.add(
            await _autoArabic(path, _joinLines(lines), allowCloud) ?? lines,
          );
        } on OcrModelNotReady catch (e) {
          out.add(const []);
          onModelNotReady?.call(e);
          break;
        } catch (_) {
          out.add(const []);
        }
      }
      while (out.length < paths.length) {
        out.add(const []);
      }
      onProgress?.call(paths.length, paths.length);
      return out;
    } finally {
      await recognizer?.close();
    }
  }

  /// Bir görselden metni SÖZCÜK SÖZCÜK, satır yapısı korunarak tanır
  /// (satır başına sözcük listesi; kutular resim piksel koordinatında).
  ///
  /// Taranmış PDF sayfasında Chrome benzeri metin seçimi bunun üstüne kurulur:
  /// sözcük kutuları `buildOcrPageText` ile sahte bir `PdfPageText`e çevrilir
  /// ve seçim katmanı yazılmış sayfayla aynı yoldan çalışır.
  static Future<List<List<OcrWordBox>>> recognizeImageWordLines(String path,
      {bool allowCloud = false}) async {
    final forced = await _forcedArabic(path, allowCloud);
    if (forced != null) return _wordLines(forced);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<List<OcrWordBox>> words;
    try {
      final result =
          await _process(recognizer, path);
      words = [
        for (final block in result.blocks)
          for (final line in block.lines)
            [
              for (final e in line.elements)
                if (e.text.trim().isNotEmpty)
                  OcrWordBox(e.text, e.boundingBox, confidence: e.confidence),
            ],
      ];
    } finally {
      await recognizer.close();
    }
    final latin = words.map((l) => l.map((w) => w.text).join(' ')).join('\n');
    final cloud = await _autoArabic(path, latin, allowCloud);
    return cloud != null ? _wordLines(cloud) : words;
  }

  /// Açık bir PDF belgesinin sayfalarını (en çok [maxPdfPages]) OCR'lar.
  /// [onProgress] her sayfa öncesi (işlenen, toplam) ile çağrılır.
  static Future<String> recognizePdf(
    PdfDocument document, {
    void Function(int done, int total)? onProgress,
    bool allowCloud = false,
  }) async {
    final pages = await recognizePdfPages(document,
        onProgress: onProgress, allowCloud: allowCloud);
    return joinPages(pages, (n) => '— Sayfa $n —');
  }

  /// PDF sayfalarını **ayrı ayrı** OCR'lar; metni olmayan sayfa listeye girmez.
  ///
  /// [maxPages] sayfa üst sınırı (varsayılan [maxPdfPages]).
  /// [cancelled] her sayfa öncesi yoklanır; true dönerse o ana kadar tanınan
  /// sayfalar döner (hata atılmaz — yarım sonuç, hiç sonuçtan iyidir ve
  /// kullanıcı işi bilerek durdurmuştur).
  /// [onlyPages] verilirse yalnız o sayfa numaraları (1'den) taranır: metin
  /// katmanı olan PDF'te sadece taranmış sayfalar için OCR'a düşülür.
  static Future<List<OcrPage>> recognizePdfPages(
    PdfDocument document, {
    int maxPages = maxPdfPages,
    void Function(int done, int total)? onProgress,
    void Function(OcrPage page)? onPageDone,
    bool Function()? cancelled,
    Set<int>? onlyPages,
    bool allowCloud = false,
    OcrQualityMode mode = OcrQualityMode.enhanced,
  }) async {
    final pages = [
      for (final page in document.pages)
        if (onlyPages == null || onlyPages.contains(page.pageNumber)) page,
    ];
    final total = pages.length > maxPages ? maxPages : pages.length;
    if (total == 0) {
      onProgress?.call(0, 0);
      return const [];
    }
    TextRecognizer? recognizer;
    final out = <OcrPage>[];
    try {
      for (var i = 0; i < total; i++) {
        if (cancelled?.call() ?? false) break;
        onProgress?.call(i, total);
        final page = pages[i];
        final rendered = await renderPageForOcr(
          page,
          tag: '$i',
          targetWidth: mode == OcrQualityMode.fast ? 2048 : 2400,
          enhance: mode == OcrQualityMode.enhanced,
          losslessPng: mode == OcrQualityMode.enhanced,
        );
        final path = rendered?.path;
        if (path == null) continue;
        try {
          String text;
          if (mode == OcrQualityMode.aiVision) {
            text = _joinLines(await _requireAiVision(path));
          } else {
            final forced = await _forcedArabic(path, allowCloud);
            if (forced != null) {
              text = _joinLines(forced);
            } else {
              recognizer ??=
                  TextRecognizer(script: TextRecognitionScript.latin);
              final res = await _process(recognizer, path);
              final lines = orderOcrRows(_recognizedLines(res));
              text = mode == OcrQualityMode.fast
                  ? lines.map((l) => l.text).join('\n').trim()
                  : formatOrderedLines(lines);
              final cloud = await _autoArabic(path, text, allowCloud);
              if (cloud != null) text = _joinLines(cloud);
            }
          }
          if (text.isNotEmpty) {
            final item = OcrPage(page.pageNumber, text);
            out.add(item);
            onPageDone?.call(item);
          }
        } finally {
          _deleteTemp(path);
        }
      }
      onProgress?.call(total, total);
      return out;
    } finally {
      await recognizer?.close();
    }
  }

  /// Sayfaları tek metne dizer; birden çok sayfa varsa [header] ile başlık
  /// yazar. Saf fonksiyon → birim testli (bkz. test/ocr_pages_test.dart).
  static String joinPages(
      List<OcrPage> pages, String Function(int pageNumber) header) {
    final sb = StringBuffer();
    for (final page in pages) {
      if (pages.length > 1) sb.writeln(header(page.number));
      sb.writeln(page.text);
      sb.writeln();
    }
    return sb.toString().trim();
  }

  /// Sayfayı JPEG/PNG olarak OCR için çizer (bkz. [renderPageForOcr]).
  static Future<({String path, double scale})?> renderPageForOcr(
    PdfPage page, {
    String tag = '',
    int targetWidth = 2400,
    bool enhance = false,
    bool losslessPng = true,
  }) async {
    final scale = (targetWidth / page.width).clamp(1.0, 4.0);
    final img = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: AppColors.page.toARGB32(),
    );
    if (img == null) return null;
    final int w = img.width, h = img.height;
    final TransferableTypedData pixels;
    try {
      // pdfium belleği `dispose`ta kalkar: izolata gitmeden önce kopya.
      pixels = TransferableTypedData.fromList([img.pixels]);
    } finally {
      img.dispose();
    }
    final ext = losslessPng ? 'png' : 'jpg';
    final path =
        '${Directory.systemTemp.path}/ocr_page_${tag}_${page.pageNumber}.$ext';
    final ok = await _encodeImageInIsolate(
      pixels,
      w,
      h,
      path,
      enhance: enhance,
      losslessPng: losslessPng,
    );
    return ok ? (path: path, scale: scale) : null;
  }

  /// Ayrı fonksiyon: izolata giden kapanış yalnız bu ilkel değerleri taşısın
  /// (sayfa/pdfium nesneleri yakalanmasın).
  static Future<bool> _encodeImageInIsolate(
    TransferableTypedData pixels,
    int w,
    int h,
    String path, {
    required bool enhance,
    required bool losslessPng,
  }) =>
      Isolate.run(() {
        final bgra = pixels.materialize().asUint8List();
        var image = imglib.Image.fromBytes(
          width: w,
          height: h,
          bytes: bgra.buffer,
          bytesOffset: bgra.offsetInBytes,
          numChannels: 4,
          order: imglib.ChannelOrder.bgra,
        );
        if (enhance) {
          image = ScanEnhance.applyToImage(image, ScanFilter.gray);
        }
        final encoded = losslessPng
            ? imglib.encodePng(image)
            : imglib.encodeJpg(image, quality: 92);
        File(path).writeAsBytesSync(encoded);
        return true;
      });

  /// PDF sayfasını UI GPU dokusu üzerinden 1600px PNG'ye çizer.
  static Future<({String path, double scale})?> renderPageToPng(
    PdfPage page, {
    String tag = '',
  }) async {
    final scale = (1600 / page.width).clamp(1.0, 4.0);
    final img = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: AppColors.page.toARGB32(),
    );
    if (img == null) return null;
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        img.pixels,
        img.width,
        img.height,
        // pdfrx 2.x: pdfium çıktısı her platformda BGRA.
        ui.PixelFormat.bgra8888,
        completer.complete,
      );
      final uiImage = await completer.future;
      final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (png == null) return null;
      final f = File(
          '${Directory.systemTemp.path}/ocr_page_${tag}_${page.pageNumber}.png');
      await f.writeAsBytes(png.buffer.asUint8List());
      return (path: f.path, scale: scale);
    } finally {
      img.dispose();
    }
  }
}
