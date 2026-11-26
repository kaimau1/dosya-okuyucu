import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'image_hash.dart';
import 'thumbnail_cache.dart';

/// Dosyaların **algısal parmak izini** üretir ve diskte önbelleğe alır.
///
/// ## Niye motor olarak dart:ui kullanılıyor
/// Saf Dart `image` paketiyle 12 MP bir JPEG'i çözmek yarım saniye sürüyor;
/// 10 bin fotoğrafta bir saat demek. `ui.ImageDescriptor.instantiateCodec`
/// **hedef boyutla** çözer, yani platformun (Android'de Skia/HEIF dahil) kendi
/// hızlı çözücüsü küçültülmüş kareyi doğrudan verir — dosya başına milisaniyeler.
/// Ayrıca `ImmutableBuffer.fromFilePath` dosyayı Dart yığınına hiç almaz.
///
/// Bedeli: bu iş **ana izlekte** yapılmalı (dart:ui bir arka plan izolatında
/// güvenilir değil). Çözme asenkron olduğu ve karo başına birkaç ms sürdüğü
/// için arayüz donmuyor; yine de iş kuyruğundan (`JobQueue`) çağrılıyor ki
/// kullanıcı ekranda beklemek zorunda kalmasın.
///
/// ## Önbellek
/// Anahtar = yol + değişiklik zamanı + boyut. Dosya değişirse parmak izi
/// kendiliğinden tazelenir. İkinci taramada hiçbir görüntü yeniden çözülmez —
/// "benzerleri bul" ilk seferden sonra anında açılır.
abstract final class MediaFingerprint {
  static const _fileName = 'phash_cache.tsv';

  static final Map<String, int> _cache = {};
  static bool _loaded = false;
  static bool _dirty = false;

  /// Üretilemeyen dosyalar (bozuk/desteklenmeyen biçim) tekrar denenmez.
  static final Set<String> _failed = {};

  static String get _cachePath => p.join(FmEnv.appSupportDir, _fileName);

  static String _key(FsEntry entry) =>
      '${entry.path}|${entry.modifiedMs}|${entry.sizeBytes}';

  /// Önbelleği diskten okur (bir kez).
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_cachePath);
      if (!file.existsSync()) return;
      for (final line in await file.readAsLines()) {
        final tab = line.lastIndexOf('\t');
        if (tab <= 0) continue;
        final hash = int.tryParse(line.substring(tab + 1), radix: 16);
        if (hash == null) continue;
        _cache[line.substring(0, tab)] = hash;
      }
    } catch (_) {
      // Bozuk önbellek sessizce yok sayılır: en kötü sonuç yeniden hesaplamak.
    }
  }

  /// Değişiklikleri diske yazar. Tarama sonunda **bir kez** çağrılır: her
  /// dosyada yazmak taramayı diske bağımlı hâle getirirdi.
  static Future<void> flush() async {
    if (!_dirty || FmEnv.appSupportDir.isEmpty) return;
    _dirty = false;
    try {
      final sink = StringBuffer();
      for (final e in _cache.entries) {
        sink.writeln('${e.key}\t${e.value.toRadixString(16)}');
      }
      final tmp = File('$_cachePath.tmp');
      await tmp.writeAsString(sink.toString(), flush: true);
      await tmp.rename(_cachePath);
    } catch (_) {
      // Bilinçli: kalıcı kayıt yazılamadı (disk dolu/izin) — bellekteki durum geçerli kalır, sonraki kayıtta yeniden denenir.
    }
  }

  static const _maxCacheEntries = 25000;
  static const _maxFailedEntries = 10000;
  static const _maxSharpEntries = 4000;

  static void _putCache(String key, int hash) {
    if (!_cache.containsKey(key) && _cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = hash;
  }

  static void _markFailed(String path) {
    if (!_failed.contains(path) && _failed.length >= _maxFailedEntries) {
      _failed.remove(_failed.first);
    }
    _failed.add(path);
  }

  /// Önbellekte zaten varsa anında döner (disk/çözme yok).
  static int? cachedOf(FsEntry entry) => _cache[_key(entry)];

  /// [entry] için parmak izi (önbellekten ya da üreterek). Üretilemezse null.
  ///
  /// Videolarda **küçük resim karesi** kullanılır (native
  /// MediaMetadataRetriever): videonun tamamını çözmek gerekmez, aynı videonun
  /// yeniden sıkıştırılmış hâli aynı kareyi verir.
  static Future<int?> of(FsEntry entry) async {
    await ensureLoaded();
    final key = _key(entry);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_failed.contains(entry.path)) return null;

    String? source = entry.path;
    if (entry.category == FmCategory.video) {
      source = await ThumbnailCache.forVideo(entry.path, size: 128);
    }
    if (source == null) {
      _markFailed(entry.path);
      return null;
    }
    final hash = await hashImageFile(source);
    if (hash == null) {
      _markFailed(entry.path);
      return null;
    }
    _putCache(key, hash);
    _dirty = true;
    return hash;
  }

  /// Tek bir görüntü dosyasının dHash'i. Çözülemezse null (bozuk dosya,
  /// desteklenmeyen biçim, izin hatası).
  static Future<int?> hashImageFile(String path) async {
    // En/boy oranı bilinçli olarak KORUNMUYOR: dHash ızgarası sabit olmalı,
    // yoksa aynı görüntünün kırpılmış hâli farklı ızgaraya düşer.
    final gray = await _grayOf(path, hashGridWidth, hashGridHeight);
    return gray == null ? null : dHashFromGray(gray);
  }

  static const _sharpSide = 128;
  static final Map<String, double> _sharpCache = {};

  /// Görüntünün netliği ([laplacianVariance], 128x128 gri). Yalnız benzer kare
  /// grubundaki dosyalar için çağrılır (tüm galeri için değil); oturum içi
  /// önbellekli. Video/çözülemeyen → null.
  static Future<double?> sharpness(FsEntry entry) async {
    if (entry.category != FmCategory.image) return null;
    final key = _key(entry);
    final cached = _sharpCache[key];
    if (cached != null) return cached;
    final gray = await _grayOf(entry.path, _sharpSide, _sharpSide);
    if (gray == null) return null;
    final v = laplacianVariance(gray, _sharpSide, _sharpSide);
    if (!_sharpCache.containsKey(key) && _sharpCache.length >= _maxSharpEntries) {
      _sharpCache.remove(_sharpCache.keys.first);
    }
    _sharpCache[key] = v;
    return v;
  }

  /// Hedef boyutta çözülmüş gri ızgara; çözülemezse null.
  static Future<List<int>?> _grayOf(String path, int width, int height) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec(
        targetWidth: width,
        targetHeight: height,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return grayFromRgba(data.buffer.asUint8List(), width * height);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
