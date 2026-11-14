import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'disk_housekeeping.dart';
import 'thumbnail_cache.dart';
import '../../core/app_colors.dart';

/// PDF'in **ilk sayfasını** küçük resim olarak üretir ve diskte önbelleğe alır.
///
/// **Niye:** listelerde her PDF aynı kırmızı simgeyle
/// görünüyordu; on tane faturanın hangisinin hangisi olduğu ancak dosya adından
/// anlaşılıyordu. Kapak sayfası tek bakışta ayırt ettirir.
///
/// **Niye disk önbelleği:** pdfium ile sayfa çizmek dosya başına onlarca-yüzlerce
/// ms sürer; her kaydırmada yeniden çizmek listeyi kastırırdı. Anahtar
/// (yol + değişiklik zamanı + boy) [ThumbnailCache.cacheName] ile üretiliyor —
/// video küçük resimleriyle **aynı kural**, aynı klasör, aynı budama.
///
/// **Sınırlar bilinçli:**
/// - Yalnız ilk sayfa çizilir (kapak). Belgenin ortasını göstermek bir küçük
///   resmin işi değil.
/// - Parola korumalı belge sessizce atlanır: kullanıcıya listede parola
///   sormak kabul edilemez, simge gösterilir.
/// - Üretilemeyen dosya işaretlenir ve bir daha denenmez (bozuk PDF her
///   kaydırmada pdfium'u yeniden çalıştırmasın).
abstract final class PdfThumbnail {
  static final Map<String, Future<String?>> _inFlight = {};
  static const _failedLimit = 256;
  static final Set<String> _failed = <String>{};

  static Directory? _dir;

  /// Diskte tutulan en çok kapak sayısı.
  static const cacheLimit = 400;

  /// Yalnız test: durumu sıfırlar.
  static void debugReset() {
    _running = 0;
    _pending.clear();
    _wanted.clear();
    _inFlight.clear();
    _failed.clear();
    _sizesSeen.clear();
    _dir = null;
  }

  /// Yalnız test: önbellek klasörünü verir (path_provider testte yok).
  static void debugUseDir(Directory dir) => _dir = dir;

  /// Bu oturumda istenen kapak boyları (açılış köprüsü bunları arar).
  static final Set<int> _sizesSeen = <int>{};

  /// Liste/kitaplık ekranlarının sık kullandığı boylar (oturumda henüz
  /// liste açılmadıysa da önceki oturumun kapağı bulunsun).
  static const _commonSizes = [512, 420, 256, 160, 128, 112, 96];

  /// **Açılış köprüsü için hazır kapak** (Ferrari H1.1, 2026-11-14).
  ///
  /// Görüntüleyici belgeyi yüklerken ekran boş kalmasın diye listede zaten
  /// üretilmiş kapak gösterilir. **Üretmez:** açılışta pdfium'u
  /// görüntüleyiciyle yarıştırmak tam da kaçınılan şey. Büyük boydan küçüğe
  /// aranır; dönen `aspect` = genişlik / yükseklik (PNG başlığından).
  /// Kapak yoksa ya da okunamazsa null — çağıran nötr kâğıt çizer.
  static Future<({String path, double aspect})?> cachedCover(
      String path) async {
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      final dir = await _cacheDir();
      final ms = stat.modified.millisecondsSinceEpoch;
      final sizes = {..._sizesSeen, ..._commonSizes}.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final size in sizes) {
        final file = File(p.join(
            dir.path,
            ThumbnailCache.cacheName(path, ms, size)
                .replaceAll('.jpg', '.png')));
        if (!await file.exists()) continue;
        final aspect = await pngAspect(file);
        if (aspect != null) return (path: file.path, aspect: aspect);
      }
    } catch (_) {
      // Bilinçli: köprü yalnız görsel yardım; kapak bulunamazsa nötr kâğıt.
    }
    return null;
  }

  /// PNG başlığından (IHDR) genişlik / yükseklik; PNG değilse null.
  static Future<double?> pngAspect(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(24);
      if (head.length < 24 ||
          head[0] != 0x89 ||
          head[1] != 0x50 ||
          head[2] != 0x4E ||
          head[3] != 0x47) {
        return null;
      }
      int be(int o) =>
          (head[o] << 24) | (head[o + 1] << 16) | (head[o + 2] << 8) | head[o + 3];
      final w = be(16), h = be(20);
      if (w <= 0 || h <= 0) return null;
      return w / h;
    } finally {
      await raf.close();
    }
  }

  /// [path] PDF'inin kapak küçük resmini döndürür (yoksa üretir).
  /// Üretilemezse null — çağıran simgeyi gösterir.
  static Future<String?> forPdf(String path,
      {int size = 256, bool Function()? wanted}) {
    if (_failed.contains(path)) return Future.value(null);
    if (_sizesSeen.length < 16) _sizesSeen.add(size);
    (_wanted[path] ??= []).add(wanted ?? _always);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _generate(path, size);
    _inFlight[path] = future;
    future.whenComplete(() {
      _inFlight.remove(path);
      _wanted.remove(path);
    });
    return future;
  }

  // ── Sıra (2026-11-13, kullanıcı: "USB içindekilerde önizlemeler geç
  // yükleniyor") ─────────────────────────────────────────────────────────
  // PDFium tek işçi izolatında koşar: klasör açılınca HER hücre aynı anda
  // belge açıyordu, işler geliş sırasıyla (FIFO) işleniyordu ve ekrandan
  // çıkmış hücrelerin işi de sürüyordu → parmağın durduğu yerdeki önizleme
  // en son geliyordu. Artık en çok 2 üretim, sıradakiler SONDAN alınır,
  // ekrandan çıkmış hücrenin işi hiç başlamaz (video küçük resmiyle aynı).
  static const _maxParallel = 2;
  static int _running = 0;
  static final List<(String, Completer<bool>)> _pending = [];
  static final Map<String, List<bool Function()>> _wanted = {};

  static bool _always() => true;

  static bool _isWanted(String path) =>
      (_wanted[path] ?? const []).any((check) => check());

  static Future<bool> _acquire(String path) {
    if (_running < _maxParallel) {
      _running++;
      return Future.value(true);
    }
    final ticket = Completer<bool>();
    _pending.add((path, ticket));
    return ticket.future;
  }

  static void _release() {
    while (_pending.isNotEmpty) {
      final (path, ticket) = _pending.removeLast();
      if (!_isWanted(path)) {
        ticket.complete(false);
        continue;
      }
      ticket.complete(true);
      return;
    }
    _running--;
  }

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'pdf_thumbs'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    // **Sınır** (2026-09-23): bu önbelleğin hiç budaması yoktu; her PDF'in
    // her sürümü/boyu yeni dosya olarak sonsuza dek birikiyordu. Oturumda
    // bir kez, izolatta.
    unawaited(DiskCache.prune(dir.path, cacheLimit));
    return dir;
  }

  static Future<String?> _generate(String path, int size) async {
    PdfDocument? doc;
    String dest;
    try {
      final stat = File(path).statSync();
      final dir = await _cacheDir();
      dest = p.join(
        dir.path,
        ThumbnailCache.cacheName(path, stat.modified.millisecondsSinceEpoch,
                size)
            .replaceAll('.jpg', '.png'),
      );
      if (File(dest).existsSync()) return dest;
    } catch (_) {
      _markFailed(path);
      return null;
    }
    if (!await _acquire(path)) return null; // hücre gitti — vazgeçildi
    try {
      // **Yalnız ilk sayfa ölçülür** (2026-11-13): `useProgressiveLoading`
      // kapalıyken PDFium açılışta HER sayfayı `FPDF_LoadPage` ile ölçüyordu
      // — 1 GB'lık, binlerce sayfalık bir PDF'te (USB'de daha da yavaş)
      // kapak saniyelerce gelmiyor, tek işçiyi tuttuğu için öteki
      // önizlemeler ve açık görüntüleyici de bekliyordu. Kapak için ilk
      // sayfa yeter.
      doc = await PdfDocument.openFile(path, useProgressiveLoading: true);
      if (doc.pages.isEmpty) {
        _markFailed(path);
        return null;
      }
      final page = doc.pages.first;
      // En-boy oranı korunur: kutuya sığan ölçü hesaplanır. Sabit kare
      // çizmek A4'ü yamultur ve küçük resim "yanlış belge" gibi görünür.
      final scale = size / (page.width > page.height ? page.width : page.height);
      final width = (page.width * scale).round().clamp(16, size);
      final height = (page.height * scale).round().clamp(16, size);
      final rendered = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        // Beyaz zemin: saydam çizim koyu temada okunmaz bir leke olurdu.
        backgroundColor: AppColors.page.toARGB32(),
      );
      if (rendered == null) {
        _markFailed(path);
        return null;
      }
      ui.Image? image;
      try {
        image = await rendered.createImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          _markFailed(path);
          return null;
        }
        await File(dest).writeAsBytes(png.buffer.asUint8List(), flush: true);
      } finally {
        image?.dispose();
        rendered.dispose();
      }
      return dest;
    } catch (_) {
      // Parola korumalı, bozuk ya da PDF olmayan dosya.
      _markFailed(path);
      return null;
    } finally {
      await doc?.dispose();
      _release();
    }
  }

  static void _markFailed(String path) {
    if (_failed.length >= _failedLimit) {
      for (final old in _failed.take(_failedLimit ~/ 2).toList()) {
        _failed.remove(old);
      }
    }
    _failed.add(path);
  }
}
