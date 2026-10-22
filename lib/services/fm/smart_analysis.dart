import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'chat_junk.dart' show isChatMediaPath;

/// Akıllı analizin bulduğu yığın türleri (içeriğe BAKAN — `chat_junk`
/// yalnız ad/boyut/tarihe bakıyor).
enum SmartKind {
  /// "Günaydın", "Hayırlı cumalar", "Kandiliniz mübarek" … iletilmiş
  /// selamlaşma/kutlama görselleri (cihaz içi OCR ile metni okunur).
  greeting,

  /// Üzerinde bolca yazı olan görseller: mem, afiş, duyuru, iletilen ilan.
  textHeavy,

  /// Bulanık (titrek/odaksız) kareler.
  blurry,

  /// Neredeyse tamamen karanlık kareler (cepte çekilmiş).
  dark,

  /// Sohbet klasörlerindeki ekran görüntüleri.
  screenshot,

  /// Belgeler: "rapor (1).pdf" — aynı klasörde aynı boyutta aslı duran
  /// kopya indirmeler.
  copyNamed,

  /// Belgeler: 1 yıldan eski, hiç açılmamış indirilen belgeler.
  oldUnopened;

  String get labelKey => 'sa.kind_$name';
  String get reasonKey => 'sa.why_$name';
}

class SmartBucket {
  final SmartKind kind;
  final List<FsEntry> files;
  const SmartBucket(this.kind, this.files);
  int get bytes => files.fold(0, (a, e) => a + e.sizeBytes);
}

/// Bir görselin ölçülen özellikleri (önbelleğe yazılır).
class ImageTraits {
  /// OCR'dan çıkan metin (küçük harf, kısaltılmış).
  final String text;

  /// Netlik: Laplace varyansı (küçük = bulanık).
  final double sharpness;

  /// Ortalama parlaklık 0..255.
  final double brightness;

  const ImageTraits(this.text, this.sharpness, this.brightness);

  Map<String, Object> toJson() =>
      {'t': text, 's': sharpness, 'b': brightness};

  static ImageTraits? fromJson(Object? j) {
    if (j is! Map) return null;
    return ImageTraits('${j['t'] ?? ''}', (j['s'] as num?)?.toDouble() ?? 0,
        (j['b'] as num?)?.toDouble() ?? 128);
  }
}

/// **Akıllı temizlik analizi** (2026-10-22, kullanıcı: *"çöp kutusu,
/// belgeler, son dosyalar vb. akıllı analiz özelliği; görsellerde özellikle
/// gereksiz WP görsellerini silmek için"*).
///
/// İçerik analizi cihazda: OCR (ML Kit, internet yok) + 64 px'e küçültülmüş
/// görüntüde netlik/parlaklık. Sonuç dosya yolu+boyut+tarih anahtarıyla
/// önbelleğe yazılır: ikinci analiz yalnız yeni görselleri okur. Hiçbir kova
/// kendiliğinden seçili GELMEZ (kural: "gereksiz" bir tahmindir).
abstract final class SmartAnalysis {
  /// Selamlaşma/kutlama görsellerinin tipik sözleri (Türkçe, küçük harf;
  /// eşleşme harf/şapka duyarsız).
  static const greetingWords = [
    'günaydın', 'gunaydin', 'iyi geceler', 'tatlı rüyalar', 'hayırlı cumalar',
    'hayirli cumalar', 'cumanız mübarek', 'cumaniz mubarek', 'hayırlı cuma',
    'kandiliniz', 'kandil', 'bayramınız', 'bayraminiz', 'iyi bayramlar',
    'hayırlı sabahlar', 'hayırlı akşamlar', 'mutlu pazarlar', 'iyi pazarlar',
    'hayırlı haftalar', 'iyi hafta sonları', 'hafta sonunuz', 'mübarek',
    'hayırlı ramazanlar', 'hayırlı kandiller', 'iyi akşamlar', 'mutlu sabahlar',
    'nice yıllara', 'yeni yılınız', 'hayırlı olsun', 'allah kabul etsin',
    'good morning', 'good night', 'happy friday', 'jumma mubarak',
  ];

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll(RegExp(r'\s+'), ' ');

  static final _greetingFolded = [for (final w in greetingWords) _fold(w)];

  static bool isGreeting(String text) {
    final t = _fold(text);
    return _greetingFolded.any(t.contains);
  }

  /// Ekran görüntüsü yolu/adı mı?
  static bool isScreenshot(String path) {
    final l = path.toLowerCase();
    return l.contains('screenshot') ||
        l.contains('ekran görüntüsü') ||
        l.contains('screen_shot');
  }

  /// "ad (1).pdf", "ad-1.pdf", "ad_copy.pdf", "ad - Kopya.pdf" → asıl ad.
  static String? copyBase(String name) {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    final m = RegExp(r'^(.*?)(?:\s*\(\d+\)|-\d|_copy|\s*-\s*kopya|\s*-\s*copy| kopya)$',
            caseSensitive: false)
        .firstMatch(base);
    if (m == null) return null;
    final orig = m.group(1)!.trim();
    return orig.isEmpty ? null : '$orig$ext';
  }

  /// Aynı klasörde aynı boyutta ASLI duran kopya-adlı dosyalar.
  static List<FsEntry> copyNamed(List<FsEntry> docs) {
    final byKey = {
      for (final e in docs) '${p.dirname(e.path)}/${p.basename(e.path).toLowerCase()}': e
    };
    return [
      for (final e in docs)
        if (!e.isDir)
          if (copyBase(p.basename(e.path)) case final orig?)
            if (byKey['${p.dirname(e.path)}/${orig.toLowerCase()}']
                    case final original?
                when original.sizeBytes == e.sizeBytes && original.path != e.path)
              e,
    ];
  }

  /// [days]'den eski ve hiç açılmamış belgeler (yalnız indirilenler klasörü).
  static List<FsEntry> oldUnopened(List<FsEntry> docs,
      {required int nowMs,
      required bool Function(String path) wasOpened,
      int days = 365}) {
    final before = nowMs - days * 24 * 60 * 60 * 1000;
    return [
      for (final e in docs)
        if (!e.isDir &&
            e.path.toLowerCase().contains('/download') &&
            e.lastTouchedMs > 0 &&
            e.lastTouchedMs < before &&
            !wasOpened(e.path))
          e,
    ];
  }

  /// Eşikler (64 px gri görüntüde).
  static const blurThreshold = 60.0;
  static const darkThreshold = 28.0;
  static const textHeavyChars = 60;

  /// Ölçülen özelliklerden kova (en çok bir; öncelik sırası: selamlaşma →
  /// yazılı → karanlık → bulanık).
  static SmartKind? classify(ImageTraits t) {
    if (t.text.isNotEmpty && isGreeting(t.text)) return SmartKind.greeting;
    if (t.text.replaceAll(RegExp(r'\s'), '').length >= textHeavyChars) {
      return SmartKind.textHeavy;
    }
    if (t.brightness < darkThreshold) return SmartKind.dark;
    if (t.sharpness < blurThreshold) return SmartKind.blurry;
    return null;
  }

  /// Görseli 64 px'e indirip parlaklık + Laplace varyansı (netlik) ölçer.
  /// Çözülemezse null. (İzolatta çağrılır.)
  static (double sharpness, double brightness)? measure(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final small = img.copyResize(decoded,
        width: decoded.width >= decoded.height ? 64 : null,
        height: decoded.height > decoded.width ? 64 : null,
        interpolation: img.Interpolation.average);
    final w = small.width, h = small.height;
    final g = List<double>.filled(w * h, 0);
    var sum = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = small.getPixel(x, y);
        final v = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
        g[y * w + x] = v.toDouble();
        sum += v;
      }
    }
    final lap = <double>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = g[y * w + x];
        lap.add(g[(y - 1) * w + x] +
            g[(y + 1) * w + x] +
            g[y * w + x - 1] +
            g[y * w + x + 1] -
            4 * c);
      }
    }
    if (lap.isEmpty) return (0, sum / (w * h));
    final mean = lap.reduce((a, b) => a + b) / lap.length;
    final variance =
        lap.fold<double>(0, (a, v) => a + math.pow(v - mean, 2)) / lap.length;
    return (variance, sum / (w * h));
  }

  /// Sohbet görsellerini analiz eder. [ocr] metni okur (testte sahte);
  /// [cacheFile] önceki ölçümleri tutar. En yeni [limit] görsel taranır.
  static Future<List<SmartBucket>> analyzeChatImages(
    List<FsEntry> entries, {
    required Future<String> Function(String path) ocr,
    File? cacheFile,
    int limit = 1500,
    int ocrMaxBytes = 600 * 1024,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final images = [
      for (final e in entries)
        if (!e.isDir &&
            e.category == FmCategory.image &&
            isChatMediaPath(e.path) &&
            !e.path.toLowerCase().endsWith('.webp')) // çıkartmalar chat_junk'ta
          e,
    ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    final scope = images.take(limit).toList();

    final cache = <String, ImageTraits>{};
    if (cacheFile != null && cacheFile.existsSync()) {
      try {
        final raw = jsonDecode(await cacheFile.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            final t = ImageTraits.fromJson(v);
            if (t != null) cache['$k'] = t;
          });
        }
      } catch (_) {
        // Bozuk önbellek: baştan ölçülür.
      }
    }
    String key(FsEntry e) => '${e.path}|${e.sizeBytes}|${e.modifiedMs}';

    final byKind = <SmartKind, List<FsEntry>>{};
    final fresh = <String, ImageTraits>{};
    for (var i = 0; i < scope.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final e = scope[i];
      if (isScreenshot(e.path)) {
        (byKind[SmartKind.screenshot] ??= []).add(e);
        onProgress?.call(i + 1, scope.length);
        continue;
      }
      var traits = cache[key(e)];
      if (traits == null) {
        String text = '';
        if (e.sizeBytes <= ocrMaxBytes) {
          try {
            text = await ocr(e.path);
          } catch (_) {
            text = '';
          }
        }
        (double, double)? m;
        try {
          m = await compute(measure, await File(e.path).readAsBytes());
        } catch (_) {
          m = null;
        }
        final folded = text.length > 400 ? text.substring(0, 400) : text;
        traits = ImageTraits(folded.toLowerCase(), m?.$1 ?? 1e9, m?.$2 ?? 128);
      }
      fresh[key(e)] = traits;
      final kind = classify(traits);
      if (kind != null) (byKind[kind] ??= []).add(e);
      onProgress?.call(i + 1, scope.length);
    }
    if (cacheFile != null) {
      try {
        await cacheFile.parent.create(recursive: true);
        await cacheFile.writeAsString(jsonEncode(
            {for (final en in fresh.entries) en.key: en.value.toJson()}));
      } catch (_) {
        // Önbellek yazılamadı: bir sonraki analiz baştan ölçer.
      }
    }
    return [
      for (final k in SmartKind.values)
        if (byKind[k]?.isNotEmpty ?? false) SmartBucket(k, byKind[k]!),
    ];
  }
}
