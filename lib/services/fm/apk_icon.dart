import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'apk_resources.dart';
import 'thumbnail_cache.dart';
import 'vector_drawable.dart';

/// Bir **.apk dosyasının kendi uygulama simgesini** çıkarır ve diskte
/// önbelleğe alır.
///
/// **Niye (kullanıcı 2026-08-17):** *"apkların kendi simgeleri görülmeli"*.
/// İndirilenler klasöründe on tane kurulum dosyası vardı ve hepsi aynı yeşil
/// Android glifiyle görünüyordu; hangisinin hangi uygulama olduğu ancak dosya
/// adından anlaşılıyordu (`notlar-v1.0.303.apk` daha okunur, ama
/// `4wM...2kx.apk` hiçbir şey söylemiyor).
///
/// **Niye `installed_apps` paketi DEĞİL:** o paket **kurulu** uygulamaların
/// simgesini paket adından verir. Buradaki dosyaların çoğu kurulu değil (eski
/// sürümler, başkasından gelen kurulumlar) ve dosyanın paket adını öğrenmek
/// için zaten APK'yı açmak gerekirdi.
///
/// **Nasıl (2026-09-03'ten beri): Android ne yapıyorsa o.** Manifest'teki
/// `application@icon` bir KAYNAK KİMLİĞİDİR; `resources.arsc` o kimliği dosya
/// yoluna çevirir (bkz. `apk_resources.dart`). Ada bakan eski sezgisel yol
/// yedekte duruyor ama artık ikinci sırada.
///
/// **Niye gerekti (kullanıcı 2026-09-03: *"bizim uygulamanın simgesi
/// görülmüyor"*):** kaynak küçültmesiyle derlenen APK'larda AAPT2 yolları
/// KISALTIYOR — bizim kendi simgemiz `res/o-.png` adıyla duruyor. Ada bakan
/// eşleme boşa çıkıyor, ada bakmayan yedek ise "en büyük kare PNG" diye
/// uyarlanabilir simgenin **zemin katmanını** (düz degrade) seçiyordu:
/// kullanıcının listede gördüğü boş turkuaz kare buydu.
///
/// **Uyarlanabilir simge:** kimlik bir XML'e çıkarsa (`mipmap-anydpi-v26`)
/// katmanlar (zemin + ön plan) çözülüp BİRLEŞTİRİLİYOR, başlatıcıdaki gibi
/// ortadan kırpılıp köşeleri yuvarlanıyor. Katman vektörse eski yola düşülür.
///
/// **Sınırlar bilinçli:**
/// - Simge bulunamayan APK **işaretlenir ve bir daha denenmez**: her
///   kaydırmada 90 MB'lık bir zip'in dizinini yeniden okumak listeyi kastırır.
/// - Ayrıştırma arka plan izolatında (`compute`): zip merkezî dizinini okumak
///   büyük APK'da yüzlerce ms sürebilir, ana izlekte kare atlatırdı.
abstract final class ApkIcon {
  static final Map<String, Future<String?>> _inFlight = {};
  static const _failedLimit = 256;
  static final Set<String> _failed = <String>{};

  static Directory? _dir;

  /// Yalnız test: durumu sıfırlar.
  static void debugReset() {
    _inFlight.clear();
    _failed.clear();
    _dir = null;
  }

  /// [path] APK'sının simgesini döndürür (yoksa çıkarır). Çıkarılamazsa null
  /// — çağıran Android glifini gösterir.
  static Future<String?> forApk(String path) {
    if (_failed.contains(path)) return Future.value(null);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _extract(path);
    _inFlight[path] = future;
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'apk_icons'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static Future<String?> _extract(String path) async {
    try {
      final stat = File(path).statSync();
      final dir = await _cacheDir();
      final dest = p.join(
        dir.path,
        ThumbnailCache.cacheName(
                path, stat.modified.millisecondsSinceEpoch, 0)
            .replaceAll('.jpg', '.png'),
      );
      if (File(dest).existsSync()) return dest;

      Uint8List? bytes;
      try {
        bytes = await compute(readIconBytes, path);
      } catch (_) {
        // İzolat üretilemedi (bazı cihazlarda düşük bellek) → ana izlek.
        bytes = readIconBytes(path);
      }
      if (bytes == null || bytes.isEmpty) {
        _markFailed(path);
        return null;
      }
      await File(dest).writeAsBytes(bytes, flush: true);
      return dest;
    } catch (_) {
      _markFailed(path);
      return null;
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

  /// Zip'ten en iyi simge adayının baytları (izolatta koşar; testte de
  /// doğrudan çağrılabilsin diye açık).
  static Uint8List? readIconBytes(String path) {
    if (!File(path).existsSync()) return null;
    // `InputFileStream`: APK'nın tamamı belleğe ALINMAZ, yalnız zip dizini ve
    // seçilen girdi okunur. 95 MB'lık bir kurulum dosyasını `readAsBytes` ile
    // açmak düşük bellekli cihazda uygulamayı öldürürdü.
    InputFileStream? input;
    try {
      input = InputFileStream(path);
      final archive = ZipDecoder().decodeBuffer(input);
      // 1) Doğru yol: manifest + kaynak tablosu (ad kısaltmasından etkilenmez).
      final resolved = iconFromResources(archive);
      if (resolved != null && resolved.isNotEmpty) return resolved;
      // 2) Ada bakan eski eşleme (tablosu okunamayan/çok eski APK'lar).
      ArchiveFile? best;
      var bestScore = 0;
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final score = scoreIconPath(entry.name);
        if (score <= bestScore) continue;
        bestScore = score;
        best = entry;
      }
      if (best != null) {
        final content = best.content;
        if (content is List<int> && content.isNotEmpty) {
          return Uint8List.fromList(content);
        }
      }
      // Ad eşleşmedi → **ada bakmayan** yedek arama (bkz. [_squareIconFallback]).
      return _squareIconFallback(archive);
    } catch (_) {
      return null;
    } finally {
      try {
        input?.closeSync();
      } catch (_) {}
    }
  }

  /// **Manifest + `resources.arsc` ile simge.** Bulunamazsa null (çağıran
  /// sezgisel yollara düşer).
  static Uint8List? iconFromResources(Archive archive) {
    final manifest = _entryBytes(archive, 'AndroidManifest.xml');
    final table = _entryBytes(archive, 'resources.arsc');
    if (manifest == null || table == null) return null;
    final resources = ArscTable.parse(table);
    if (resources == null) return null;
    final elements = AndroidBinaryXml.parse(manifest);
    var iconId = 0;
    for (final element in elements) {
      if (element.name != 'application') continue;
      final icon =
          element.byResId[AndroidBinaryXml.attrIcon] ?? element.byName['icon'];
      if (icon != null && icon.isReference) iconId = icon.data;
      // Yuvarlak simge yalnız yedek: kare simge listelerde daha tanıdık.
      if (iconId == 0) {
        final round = element.byResId[AndroidBinaryXml.attrRoundIcon] ??
            element.byName['roundIcon'];
        if (round != null && round.isReference) iconId = round.data;
      }
      break;
    }
    if (iconId == 0) return null;

    // Önce raster: başlatıcının da çizdiği hazır simge.
    final raster = resources.bestFile(iconId, xml: false);
    final rasterBytes = raster == null ? null : _entryBytes(archive, raster);
    if (rasterBytes != null && rasterBytes.isNotEmpty) return rasterBytes;

    // Sonra XML: uyarlanabilir simge katmanları ya da doğrudan vektör.
    final xmlPath = resources.bestFile(iconId);
    if (xmlPath == null || !xmlPath.toLowerCase().endsWith('.xml')) return null;
    final xmlBytes = _entryBytes(archive, xmlPath);
    if (xmlBytes == null) return null;
    final adaptive = composeAdaptive(archive, resources, xmlBytes);
    if (adaptive != null) return adaptive;
    // **Uyarlanabilir değil, doğrudan vektör simge** (eski uygulamaların
    // çoğu böyle): tek başına çizilir.
    final vector = _renderDrawable(archive, resources, xmlBytes);
    if (vector == null) return null;
    return Uint8List.fromList(img.encodePng(vector));
  }

  /// **Bir çizim kaynağını görüntüye çevirir** — raster, vektör ya da sarmalayıcı.
  ///
  /// Uyarlanabilir simgenin katmanı üç şeyden biri olabilir ve üçü de gerçek
  /// APK'larda karşımıza çıkıyor:
  /// 1. hazır PNG/WebP,
  /// 2. **vektör çizim** (`<vector>`) — Android Studio'nun ürettiği her
  ///    varsayılan simge böyle; eskiden burada vazgeçiliyordu,
  /// 3. sarmalayıcı XML (`<inset>`, `<bitmap>`, `<layer-list>`) — içindeki
  ///    asıl çizime gönderme yapar.
  ///
  /// [depth] sonsuz döngüyü keser (kendini gösteren bozuk kaynaklar var).
  static img.Image? _drawableImage(
    Archive archive,
    ArscTable resources,
    int resId, {
    int depth = 0,
  }) {
    if (depth > 4) return null;
    final raster = resources.bestFile(resId, xml: false);
    final rasterBytes = raster == null ? null : _entryBytes(archive, raster);
    if (rasterBytes != null && rasterBytes.isNotEmpty) {
      final decoded = _decode(rasterBytes);
      if (decoded != null) return decoded;
    }
    final xmlPath = resources.bestFile(resId);
    if (xmlPath == null || !xmlPath.toLowerCase().endsWith('.xml')) return null;
    final xmlBytes = _entryBytes(archive, xmlPath);
    if (xmlBytes == null) return null;
    return _renderDrawable(archive, resources, xmlBytes, depth: depth);
  }

  /// Bir XML çizimi görüntüye çevirir (vektör ya da sarmalayıcı).
  static img.Image? _renderDrawable(
    Archive archive,
    ArscTable resources,
    Uint8List xmlBytes, {
    int depth = 0,
  }) {
    final tree = AndroidBinaryXml.parseTree(xmlBytes);
    if (tree.isEmpty) return null;
    if (VectorDrawable.isVector(tree)) {
      final image = VectorDrawable.parse(
        tree,
        resolveColor: (id) => colorOf(resources, id),
      );
      if (image == null) return null;
      return VectorDrawable.rasterize(image, size: _iconSide);
    }
    // Sarmalayıcı: ilk çizim göndermesini izle (`<bitmap android:src>`,
    // `<inset android:drawable>`, `<layer-list><item android:drawable>`).
    for (final node in tree) {
      for (final candidate in [node, ...node.descendants('item')]) {
        for (final key in const ['drawable', 'src']) {
          final attr = candidate.element.byName[key] ??
              (key == 'drawable'
                  ? candidate.element.byResId[AndroidBinaryXml.attrDrawable]
                  : null);
          if (attr == null || !attr.isReference) continue;
          final inner =
              _drawableImage(archive, resources, attr.data, depth: depth + 1);
          if (inner != null) return inner;
        }
      }
    }
    return null;
  }

  /// Çizilen simgenin kenarı (px). 192, xxxhdpi bir başlatıcı simgesidir:
  /// listede keskin, bellekte küçük.
  static const _iconSide = 192;

  /// Uyarlanabilir simgeyi başlatıcıdaki gibi çizer: zemin + ön plan üst üste,
  /// sonra **ortadan kırpma** ve yuvarlatılmış köşe.
  ///
  /// Ölçüler Android'in tanımından: tuval 108 dp, görünen alan ortadaki 72 dp
  /// (dışarıdaki 18'er dp maskenin altında kalır). Kırpmasaydık katmanların
  /// kenar boşluğu yüzünden simge listede minicik görünürdü.
  static Uint8List? composeAdaptive(
    Archive archive,
    ArscTable resources,
    Uint8List xmlBytes,
  ) {
    final elements = AndroidBinaryXml.parse(xmlBytes);
    img.Image? background;
    img.Image? foreground;
    int? backgroundColor;
    for (final element in elements) {
      final isBackground = element.name == 'background';
      final isForeground = element.name == 'foreground';
      if (!isBackground && !isForeground) continue;
      final drawable = element.byResId[AndroidBinaryXml.attrDrawable] ??
          element.byName['drawable'];
      if (drawable == null) continue;
      img.Image? layer;
      int? color;
      if (drawable.isReference) {
        // **Katman artık VEKTÖR de olabilir** (2026-09-03): eskiden yalnız
        // hazır raster aranıyordu ve vektör ön planlı simgelerde birleştirme
        // vazgeçiyordu — kullanıcının listede gördüğü boş kare buydu.
        layer = _drawableImage(archive, resources, drawable.data);
        color = colorOf(resources, drawable.data);
      } else if (drawable.type >= typeColorFirst &&
          drawable.type <= typeColorLast) {
        color = drawable.data;
      }
      if (isBackground) {
        background = layer;
        backgroundColor = color;
      } else {
        foreground = layer;
      }
    }
    // Ön plan çizilemiyorsa (vektör katman) tek başına zemin YANILTICI olurdu:
    // düz bir renk kutusu — tam da düzeltmeye çalıştığımız görüntü.
    if (foreground == null) return null;

    final side = foreground.width > 0 ? foreground.width : _iconSide;
    final canvas = img.Image(width: side, height: side, numChannels: 4);
    if (backgroundColor != null) {
      img.fill(canvas, color: _argb(backgroundColor));
    }
    if (background != null) {
      img.compositeImage(canvas, background,
          dstX: 0, dstY: 0, dstW: side, dstH: side);
    }
    img.compositeImage(canvas, foreground,
        dstX: 0, dstY: 0, dstW: side, dstH: side);

    // Görünen alan: ortadaki 72/108.
    final visible = (side * 72 / 108).round();
    final inset = ((side - visible) / 2).round();
    final cropped = img.copyCrop(canvas,
        x: inset, y: inset, width: visible, height: visible);
    roundCorners(cropped, cropped.width * 0.22);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  /// `Res_value`nin renk türleri (ARGB8 … RGB4).
  static const typeColorFirst = 0x1c;
  static const typeColorLast = 0x1f;

  /// Kaynak bir RENK ise ARGB değeri (uyarlanabilir simgenin zemini sık sık
  /// düz renktir), değilse null.
  static int? colorOf(ArscTable resources, int resId) {
    for (final value in resources.lookup(resId)) {
      if (value.dataType >= typeColorFirst && value.dataType <= typeColorLast) {
        return value.data;
      }
    }
    return null;
  }

  static img.Color _argb(int argb) => img.ColorRgba8(
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
        (argb >> 24) & 0xFF,
      );

  /// Köşeleri yuvarlar (maskenin dışındaki pikseller saydamlaşır).
  static void roundCorners(img.Image image, double radius) {
    final r = radius.clamp(0, image.width / 2).toDouble();
    if (r <= 0) return;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final dx = x < r
            ? r - x - 0.5
            : (x >= image.width - r ? x - (image.width - r) + 0.5 : 0.0);
        final dy = y < r
            ? r - y - 0.5
            : (y >= image.height - r ? y - (image.height - r) + 0.5 : 0.0);
        if (dx <= 0 || dy <= 0) continue;
        if (dx * dx + dy * dy <= r * r) continue;
        image.getPixel(x, y).a = 0;
      }
    }
  }

  static img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _entryBytes(Archive archive, String name) {
    for (final entry in archive.files) {
      if (!entry.isFile || entry.name != name) continue;
      final content = entry.content;
      if (content is List<int> && content.isNotEmpty) {
        return Uint8List.fromList(content);
      }
      return null;
    }
    return null;
  }

  /// **Ada bakmayan yedek:** `res/` altındaki KARE ve simge boyutundaki en
  /// büyük PNG.
  ///
  /// *Niye gerekli:* ad eşlemesi (`ic_launcher`…) her APK'da tutmuyor. Kaynak
  /// küçültme (`shrinkResources`) açık derlenmiş uygulamalarda AAPT2 kaynak
  /// dosyalarının yolunu KISALTIYOR: `res/mipmap-xxxhdpi-v4/ic_launcher.png`
  /// → `res/hQ.png`. O zaman ada bakan her eşleme boşa çıkar ve kullanıcı
  /// yine düz Android glifi görür (2026-08-17 cihaz denemesi).
  ///
  /// Bu yedek YALNIZ ad eşlemesi başarısızken koşar; yani en kötü ihtimalle
  /// bugünkü davranışa (glif) döneriz, daha kötüsüne değil.
  ///
  /// Sınırlar bilinçli — yanlış bir görsel seçmemek için:
  /// * yalnız `res/` altı, yalnız PNG (boyutu başlıktan okunabiliyor),
  /// * **kare** olmalı (uygulama simgeleri karedir; afiş/arka plan değildir),
  /// * kenar 48–512 px arası (ikonun ölçüsü; ekran görüntüsü değil),
  /// * sıkıştırılmış boyutu [_fallbackMaxBytes] altındaki girdiler açılır —
  ///   90 MB'lık bir APK'da her PNG'yi açmak listeyi kastırırdı,
  /// * en çok [_fallbackMaxProbe] aday denenir.
  static const int _fallbackMaxBytes = 400 * 1024;
  static const int _fallbackMaxProbe = 40;

  static Uint8List? _squareIconFallback(Archive archive) {
    final candidates = <ArchiveFile>[];
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.toLowerCase();
      if (!name.startsWith('res/') || !name.endsWith('.png')) continue;
      if (entry.size <= 0 || entry.size > _fallbackMaxBytes) continue;
      candidates.add(entry);
    }
    // Büyükten küçüğe: en keskin simge önce denensin.
    candidates.sort((a, b) => b.size.compareTo(a.size));

    Uint8List? best;
    var bestSide = 0;
    var probed = 0;
    for (final entry in candidates) {
      if (probed >= _fallbackMaxProbe) break;
      probed++;
      final content = entry.content;
      if (content is! List<int> || content.length < 24) continue;
      final bytes = Uint8List.fromList(content);
      final size = pngSize(bytes);
      if (size == null) continue;
      final (w, h) = size;
      if (w != h || w < 48 || w > 512) continue;
      if (w > bestSide) {
        bestSide = w;
        best = bytes;
      }
    }
    return best;
  }

  /// PNG başlığındaki (IHDR) genişlik/yükseklik — PNG değilse null.
  ///
  /// İmza (8 bayt) + uzunluk (4) + "IHDR" (4) + genişlik (4) + yükseklik (4).
  /// Tüm görüntüyü ÇÖZMEDEN ölçü okumak için: kod çözme, kare olmayan onlarca
  /// adayı elemek uğruna yapılacak en pahalı iş olurdu.
  static (int, int)? pngSize(Uint8List bytes) {
    if (bytes.length < 24) return null;
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return null;
    }
    if (bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return null; // IHDR değil
    }
    int be32(int o) =>
        (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) |
            bytes[o + 3];
    return (be32(16), be32(20));
  }

  /// Bir zip yolunun "bu uygulamanın simgesi" olma puanı; 0 = aday değil.
  ///
  /// Puanlama iki şeyi birleştirir: **ad** (ic_launcher > app_icon > icon) ve
  /// **yoğunluk** (xxxhdpi > xxhdpi > …). Böylece en keskin simge seçilir —
  /// 48 dp'lik listede bulanık bir mdpi kopyası kullanmak, hiç simge
  /// göstermemekten daha kötü görünürdü.
  static int scoreIconPath(String name) {
    final lower = name.toLowerCase();
    if (!lower.startsWith('res/')) return 0;
    if (!lower.endsWith('.png') && !lower.endsWith('.webp')) return 0;
    final base = lower.split('/').last;
    var score = 0;
    if (base.contains('ic_launcher')) {
      score = 300;
    } else if (base.contains('app_icon') || base.contains('ic_app')) {
      score = 200;
    } else if (base == 'icon.png' || base == 'icon.webp') {
      score = 150;
    } else {
      return 0;
    }
    // Yuvarlak/ön plan varyantları tam simge değildir; aday kalsınlar ama
    // düz `ic_launcher.png` varsa o kazansın.
    if (base.contains('foreground') || base.contains('background')) score -= 60;
    if (base.contains('round')) score -= 20;

    const densities = [
      ('xxxhdpi', 60),
      ('xxhdpi', 50),
      ('xhdpi', 40),
      ('hdpi', 30),
      ('mdpi', 20),
      ('ldpi', 10),
    ];
    for (final (tag, bonus) in densities) {
      if (lower.contains('-$tag')) {
        score += bonus;
        break;
      }
    }
    return score;
  }
}
