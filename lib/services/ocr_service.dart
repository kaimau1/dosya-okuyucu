import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:image/image.dart' as imglib;

import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/l10n/app_strings.dart';
import 'cloud_ocr.dart';
import 'pdf/ocr_page_text.dart' show OcrWordBox;
import '../core/app_colors.dart';

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

  /// Ayar "Arapça (AI ile)" ve tanımayı kullanıcı başlattıysa: cihaz modeli
  /// hiç koşmaz, doğrudan AI ([CloudOcr]). Hata (anahtar yok vb.) çağırana
  /// gider — kullanıcı neden tanınmadığını görmeli.
  static Future<List<OcrLine>?> _forcedCloud(String path, bool allowCloud) async {
    if (!allowCloud || await CloudOcr.script() != OcrScript.arabic) return null;
    return CloudOcr.lines(path);
  }

  /// "Otomatik": cihazdaki sonuç zayıfsa ve Decisions API görselde Latin
  /// dışı yazı görürse AI ile yeniden tanır. Her hata sessiz: cihazdaki
  /// sonuç kalır (null).
  static Future<List<OcrLine>?> _autoCloud(
      String path, String latinText, bool allowCloud) async {
    if (!allowCloud ||
        await CloudOcr.script() != OcrScript.auto ||
        !CloudOcr.available ||
        !CloudOcr.looksWeak(latinText)) {
      return null;
    }
    if (!await CloudOcr.hasNonLatinScript(path)) return null;
    try {
      final lines = await CloudOcr.lines(path);
      return lines.isEmpty ? null : lines;
    } catch (_) {
      return null; // Bilinçli: bulut düşerse cihazdaki sonuç gösterilir.
    }
  }

  static String _joinLines(List<OcrLine> lines) =>
      lines.map((l) => l.text).join('\n').trim();

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
  static Future<String> recognizeImageFile(String path,
      {bool allowCloud = false}) async {
    final forced = await _forcedCloud(path, allowCloud);
    if (forced != null) return _joinLines(forced);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final String text;
    try {
      final result =
          await _process(recognizer, path);
      text = result.text.trim();
    } finally {
      await recognizer.close();
    }
    final cloud = await _autoCloud(path, text, allowCloud);
    return cloud != null ? _joinLines(cloud) : text;
  }

  /// Bir görselden metni SATIR SATIR, resim piksel koordinatındaki kutusuyla
  /// birlikte tanır. Aranabilir PDF üretiminde (görünmez metin katmanı) her
  /// satırı kendi yerine yazmak için gerekir.
  ///
  /// ponytail: kutular ML Kit'in EXIF döndürmesi uygulanmış hâline göredir;
  /// EXIF ile döndürülmüş fotoğraflarda katman kayabilir — şikayet gelirse
  /// resmi önce normalize edip (döndürmeyi baytlara işleyip) OCR'la.
  static Future<List<OcrLine>> recognizeImageLines(String path,
      {bool allowCloud = false}) async {
    final forced = await _forcedCloud(path, allowCloud);
    if (forced != null) return forced;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<OcrLine> lines;
    try {
      final result =
          await _process(recognizer, path);
      lines = [
        for (final block in result.blocks)
          for (final line in block.lines)
            if (line.text.trim().isNotEmpty)
              OcrLine(line.text, line.boundingBox),
      ];
    } finally {
      await recognizer.close();
    }
    return await _autoCloud(path, _joinLines(lines), allowCloud) ?? lines;
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
          final forced = await _forcedCloud(path, allowCloud);
          if (forced != null) {
            out.add(forced);
            continue;
          }
          recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
          final result = await _process(recognizer, path);
          final lines = [
            for (final block in result.blocks)
              for (final line in block.lines)
                if (line.text.trim().isNotEmpty)
                  OcrLine(line.text, line.boundingBox),
          ];
          out.add(
            await _autoCloud(path, _joinLines(lines), allowCloud) ?? lines,
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
    final forced = await _forcedCloud(path, allowCloud);
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
                  OcrWordBox(e.text, e.boundingBox),
            ],
      ];
    } finally {
      await recognizer.close();
    }
    final latin = words.map((l) => l.map((w) => w.text).join(' ')).join('\n');
    final cloud = await _autoCloud(path, latin, allowCloud);
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
    bool Function()? cancelled,
    Set<int>? onlyPages,
    bool allowCloud = false,
  }) async {
    final pages = [
      for (final page in document.pages)
        if (onlyPages == null || onlyPages.contains(page.pageNumber)) page,
    ];
    final total = pages.length > maxPages ? maxPages : pages.length;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final out = <OcrPage>[];
    try {
      for (var i = 0; i < total; i++) {
        if (cancelled?.call() ?? false) break;
        onProgress?.call(i, total);
        final page = pages[i];
        final path = await _renderPageToPng(page, i);
        if (path == null) continue;
        try {
          final forced = await _forcedCloud(path, allowCloud);
          var text = forced != null
              ? _joinLines(forced)
              : (await _process(recognizer, path)).text.trim();
          if (forced == null) {
            final cloud = await _autoCloud(path, text, allowCloud);
            if (cloud != null) text = _joinLines(cloud);
          }
          if (text.isNotEmpty) out.add(OcrPage(page.pageNumber, text));
        } finally {
          try {
            File(path).deleteSync();
          } catch (_) {
            // Bilinçli: temizlik — dosya zaten yoksa ya da silinemezse işin sonucu değişmez.
          }
        }
      }
      onProgress?.call(total, total);
      return out;
    } finally {
      await recognizer.close();
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

  /// Sayfayı ~2048px genişlikte OCR görüntüsüne çizer (bkz. [renderPageForOcr]).
  static Future<String?> _renderPageToPng(PdfPage page, int index) async =>
      (await renderPageForOcr(page, tag: '$index'))?.path;

  /// OCR için sayfa görüntüsü (JPEG, ~2048 px) — `scale` = görüntü pikseli /
  /// PDF punto oranı.
  ///
  /// **Niye [renderPageToPng] değil (2026-11-03 kasma turu):** o yol pdfium
  /// piksellerini önce bir GPU dokusuna yüklüyor (`decodeImageFromPixels`),
  /// sonra GPU'dan geri okuyup PNG'ye sıkıştırıyordu (`toByteData`). Taranmış
  /// PDF'te otomatik OCR bunu görünen HER sayfa için yapıyor; 1600×2260'lık
  /// doku yükleme + geri okuma, kaydırma sırasında çizim izleğini tıkıyordu.
  /// Burada pikseller doğrudan bir izolatta JPEG'e kodlanır — GPU'ya hiç
  /// dokunulmaz. (ML Kit JPEG'i PNG kadar iyi okur.)
  static Future<({String path, double scale})?> renderPageForOcr(
    PdfPage page, {
    String tag = '',
  }) async {
    // 2048 px (2026-11-15; eskiden 1600): taranmış tablolardaki küçük
    // yazı (~7 pt) 1600'de ML Kit'in istediği harf boyunun altında kalıyor,
    // sözcükler bölünüp yanlış okunuyordu. Bedel: sayfa başına ~%60 fazla
    // piksel (tek sayfa, izolatta kodlanıyor).
    final scale = (2048 / page.width).clamp(1.0, 4.0);
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
    final path =
        '${Directory.systemTemp.path}/ocr_page_${tag}_${page.pageNumber}.jpg';
    final ok = await _encodeJpegInIsolate(pixels, w, h, path);
    return ok ? (path: path, scale: scale) : null;
  }

  /// Ayrı fonksiyon: izolata giden kapanış yalnız bu ilkel değerleri taşısın
  /// (sayfa/pdfium nesneleri yakalanmasın).
  static Future<bool> _encodeJpegInIsolate(
          TransferableTypedData pixels, int w, int h, String path) =>
      Isolate.run(() {
        final bgra = pixels.materialize().asUint8List();
        final image = imglib.Image.fromBytes(
          width: w,
          height: h,
          bytes: bgra.buffer,
          bytesOffset: bgra.offsetInBytes,
          numChannels: 4,
          order: imglib.ChannelOrder.bgra,
        );
        File(path).writeAsBytesSync(imglib.encodeJpg(image, quality: 90));
        return true;
      });

  /// [_renderPageToPng]'nin ölçeği de döndüren biçimi: `scale` = görüntü
  /// pikseli / PDF punto oranı. Taranmış sayfa seçiminde OCR kutularını sayfa
  /// koordinatına geri çevirmek için gerekir (bkz. `PdfOcrText`).
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
