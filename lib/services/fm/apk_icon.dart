import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'thumbnail_cache.dart';

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
/// **Nasıl:** APK bir zip. Simge `res/mipmap-*/ic_launcher.png` (ya da
/// `drawable-*`) yolunda durur. İkili `AndroidManifest.xml`i çözümlemek yerine
/// yol adına göre aday PNG'ler toplanıp **en yüksek çözünürlüklü** olan
/// seçiliyor. Bu, ikili XML ayrıştırıcısı yazmadan pratikteki APK'ların büyük
/// çoğunluğunu kapsıyor.
///
/// **Sınırlar bilinçli:**
/// - Yalnız PNG/WEBP alınır. `mipmap-anydpi-v26/ic_launcher.xml` (uyarlanabilir
///   simge) ikili XML'dir; onu çözmek ayrı bir ayrıştırıcı demek. O dosyaların
///   yanında neredeyse her zaman bir PNG de bulunur, seçim ondan yapılır.
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
      ArchiveFile? best;
      var bestScore = 0;
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final score = scoreIconPath(entry.name);
        if (score <= bestScore) continue;
        bestScore = score;
        best = entry;
      }
      if (best == null) return null;
      final content = best.content;
      if (content is! List<int> || content.isEmpty) return null;
      return Uint8List.fromList(content);
    } catch (_) {
      return null;
    } finally {
      try {
        input?.closeSync();
      } catch (_) {}
    }
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
