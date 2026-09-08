import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fs_events.dart';

/// **Dosya böl / parçaları birleştir.**
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulama USB bellek ve SD kart yazabiliyor ve bu birimlerin çoğu
/// **FAT32**: tek dosya 4 GB'ı geçemez. Kullanıcının 6 GB'lık video yedeği
/// USB belleğe "Dosya çok büyük" diye kopyalanamıyor ve yapabileceği hiçbir
/// şey yoktu — uygulamanın sıkıştırma yolu da (ZIP) tek parça üretiyor.
/// Aynı sorun e-posta eki, WhatsApp sınırı ve eski bir kart okuyucu için de
/// geçerli.
///
/// Biçim bilinçli olarak **en yaygın olanı**: `dosya.mp4.001`, `.002`, …
/// (7-Zip, WinRAR ve `split` bunu okur). Böylece parçalar bilgisayara
/// taşındığında karşı tarafta özel bir araç gerekmiyor — dosyaları
/// birleştirmek Windows'ta `copy /b`, Linux'ta `cat` ile de mümkün.
///
/// Birleştirme parçaları **sıra numarasına göre** buluyor; kullanıcı yalnız
/// ilk parçayı seçiyor.
abstract final class FileSplit {
  /// Yaygın hedef boyutlar (bayt). Arayüz bunları sunuyor.
  static const presets = <String, int>{
    '100 MB': 100 * 1024 * 1024,
    '700 MB (CD)': 700 * 1024 * 1024,
    '2 GB': 2 * 1024 * 1024 * 1024,
    // FAT32 sınırı tam 4 GiB − 1 bayt; 3,99 GiB güvenli tarafta kalıyor
    // (bazı sürücüler son bloğu yazarken hata veriyor).
    '3,99 GB (FAT32)': 4285923328,
  };

  /// Parça dosyasının adı: `video.mp4.001`.
  static String partName(String baseName, int index) =>
      '$baseName.${index.toString().padLeft(3, '0')}';

  /// Bir parça adından ana adı çıkarır: `video.mp4.001` → `video.mp4`.
  /// Parça değilse null.
  static String? baseNameOf(String partPath) {
    final name = p.basename(partPath);
    final match = RegExp(r'^(.*)\.(\d{3,})$').firstMatch(name);
    if (match == null) return null;
    return match.group(1);
  }

  /// [path]'i [partBytes] boyutunda parçalara böler.
  ///
  /// Parçalar kaynağın yanına yazılır (hedef klasör verilmezse). Üretilen
  /// parça yolları döner.
  ///
  /// İptal edilirse **yazılmış parçalar silinir**: yarım bir bölme,
  /// kullanıcının "birleştirince tamam" sandığı bozuk bir dosya demek
  /// olurdu.
  static Future<List<String>> split(
    String path, {
    required int partBytes,
    String? destDir,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (partBytes < 1024) {
      throw ArgumentError('parça boyutu en az 1 KB olmalı');
    }
    final source = File(path);
    final total = await source.length();
    final dir = destDir ?? p.dirname(path);
    final baseName = p.basename(path);
    final written = <String>[];
    var index = 1;
    var inPart = 0;
    var done = 0;
    IOSink? sink;

    Future<void> closePart() async {
      await sink?.flush();
      await sink?.close();
      sink = null;
    }

    try {
      await for (final chunk in source.openRead()) {
        var offset = 0;
        while (offset < chunk.length) {
          if (isCancelled?.call() ?? false) {
            await closePart();
            for (final part in written) {
              try {
                File(part).deleteSync();
              } catch (_) {}
            }
            return const [];
          }
          if (sink == null) {
            final target = p.join(dir, partName(baseName, index));
            written.add(target);
            sink = File(target).openWrite();
            inPart = 0;
            index++;
          }
          final room = partBytes - inPart;
          final take = (chunk.length - offset) < room
              ? chunk.length - offset
              : room;
          sink!.add(chunk.sublist(offset, offset + take));
          offset += take;
          inPart += take;
          done += take;
          onProgress?.call(done, total);
          if (inPart >= partBytes) await closePart();
        }
      }
    } finally {
      await closePart();
    }
    FsEvents.changed();
    return written;
  }

  /// Bir parça yolundan başlayarak **bütün parçaları** sırayla birleştirir.
  ///
  /// [firstPart] `.001` olmak zorunda değil; ana ad ondan çıkarılıp klasörde
  /// aynı ada sahip bütün parçalar sayı sırasına göre toplanıyor. Böylece
  /// kullanıcı hangi parçaya dokunursa dokunsun doğru sonucu alıyor.
  ///
  /// Eksik parça varsa (`.003` yokken `.004` varsa) işlem YAPILMAZ ve hata
  /// fırlatılır: eksik parçayla birleştirmek sessizce bozuk dosya üretmek
  /// olurdu.
  static Future<String> join(
    String firstPart, {
    String? destPath,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final baseName = baseNameOf(firstPart);
    if (baseName == null) {
      throw const FormatException('Bu dosya bir parça değil (.001 bekleniyor)');
    }
    final dir = p.dirname(firstPart);
    final parts = <int, String>{};
    for (final entity in Directory(dir).listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final match = RegExp(r'^(.*)\.(\d{3,})$').firstMatch(name);
      if (match == null || match.group(1) != baseName) continue;
      parts[int.parse(match.group(2)!)] = entity.path;
    }
    if (parts.isEmpty) {
      throw const FormatException('Parça bulunamadı');
    }
    final numbers = parts.keys.toList()..sort();
    for (var i = 0; i < numbers.length; i++) {
      if (numbers[i] != i + 1) {
        throw FormatException(
            'Eksik parça: ${partName(baseName, i + 1)} bulunamadı');
      }
    }

    final target = FileOps.uniquePath(destPath ?? p.join(dir, baseName));
    final sink = File(target).openWrite();
    var total = 0;
    for (final number in numbers) {
      total += await File(parts[number]!).length();
    }
    var done = 0;
    try {
      for (final number in numbers) {
        await for (final chunk in File(parts[number]!).openRead()) {
          if (isCancelled?.call() ?? false) {
            await sink.flush();
            await sink.close();
            try {
              File(target).deleteSync();
            } catch (_) {}
            return '';
          }
          sink.add(chunk);
          done += chunk.length;
          onProgress?.call(done, total);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    FsEvents.changed();
    return target;
  }
}
