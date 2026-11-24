import 'dart:math' as math;

import '../../models/fs_entry.dart';
import 'cleanup_advisor.dart';
import 'fs_scan.dart';
import 'image_hash.dart';
import 'media_duration.dart';
import 'media_fingerprint.dart';

/// **Gönderilen sohbet medyası asıl doğrulayıcısı** (2026-11-24).
///
/// WhatsApp/Telegram `.../Sent/` klasöründeki bir video veya fotoğraf her zaman
/// başka bir yerde aslı duran bir kopya OLMAYABİLİR (ör. doğrudan WhatsApp
/// kamerasıyla çekilmiş ya da galerideki aslı sonradan silinmiş olabilir).
///
/// Bu sınıf `Sent` dosyasını cihazdaki `Sent`-dışı dosyalarla karşılaştırır:
/// - **Görseller:** sıkı algısal parmak izi (`dHash`, Hamming ≤ 2).
/// - **Videolar:** kapak karesi `dHash` (Hamming ≤ 3) **VE** süre eşleşmesi
///   (±2 sn veya %5 — aynı odada çekilmiş farklı uzunluktaki iki videoyu
///   yanlışlıkla eşleştirmemek için). Süre okunamazsa yalnız çok sıkı `dHash`
///   (Hamming ≤ 2) ve zaman koşulu aranır.
///
/// Yalnız cihazda aslı doğrulanan `Sent` dosyaları döndürülür; aslı
/// bulunamayanlar asla "kopya" olarak önerilmez.
abstract final class SentOriginalMatcher {
  /// Aday asıl görseller için tarama penceresi (gönderimden en çok 30 gün önce).
  static const int _imageWindowMs = 30 * 24 * 60 * 60 * 1000;

  /// Aday asıl videolar için tarama penceresi (gönderimden en çok 90 gün önce).
  static const int _videoWindowMs = 90 * 24 * 60 * 60 * 1000;

  /// Saat sapması toleransı (EXIF/kopyalama saat farkı için +24 saat).
  static const int _futureSlackMs = 24 * 60 * 60 * 1000;

  /// İlk taramada donmayı önleyen aday üst sınırları (önbellekteki tüm
  /// parmak izleri bunlara ek olarak sıfır maliyetle her zaman taranır).
  static const int _maxUncachedImages = 600;
  static const int _maxUncachedVideos = 400;

  /// Depolama indeksindeki `Sent` dosyalarının cihazda doğrulanan asıllarını
  /// bulur (`sent.path → originalEntry`).
  static Future<Map<String, FsEntry>> findOriginals(
    StorageIndex index, {
    bool Function()? isCancelled,
  }) async {
    final sentVideos = <FsEntry>[];
    final nonSentVideos = <FsEntry>[];
    for (final e in index.files(FmCategory.video)) {
      if (e.isDir) continue;
      if (isChatSentCopy(e)) {
        sentVideos.add(e);
      } else {
        nonSentVideos.add(e);
      }
    }

    final sentImages = <FsEntry>[];
    final nonSentImages = <FsEntry>[];
    for (final e in index.files(FmCategory.image)) {
      if (e.isDir) continue;
      if (isChatSentCopy(e)) {
        sentImages.add(e);
      } else {
        nonSentImages.add(e);
      }
    }

    if (sentVideos.isEmpty && sentImages.isEmpty) return const {};

    await MediaFingerprint.ensureLoaded();
    if (isCancelled?.call() == true) return const {};

    final hashes = <String, int>{};
    final durations = <String, int>{};
    final result = <String, FsEntry>{};

    // 1) Videolar: kapak karesi dHash + süre doğrulaması.
    if (sentVideos.isNotEmpty && nonSentVideos.isNotEmpty) {
      final candVideos = _selectCandidates(
        sent: sentVideos,
        pool: nonSentVideos,
        windowMs: _videoWindowMs,
        maxUncached: _maxUncachedVideos,
      );
      for (final e in [...sentVideos, ...candVideos]) {
        if (isCancelled?.call() == true) return result;
        final h = await MediaFingerprint.of(e);
        if (h != null) hashes[e.path] = h;
      }

      // Yalnız dHash adayı çıkan video çiftlerinin süresi ölçülür (ucuz).
      final needDuration = <FsEntry>{};
      for (final s in sentVideos) {
        final hs = hashes[s.path];
        if (hs == null) continue;
        for (final o in candVideos) {
          final ho = hashes[o.path];
          if (ho == null) continue;
          if (hamming(hs, ho) <= 3) {
            needDuration.add(s);
            needDuration.add(o);
          }
        }
      }
      for (final e in needDuration) {
        if (isCancelled?.call() == true) return result;
        final d = await MediaDuration.forVideo(e.path, modifiedMs: e.modifiedMs);
        if (d != null && d.inSeconds > 0) {
          durations[e.path] = d.inSeconds;
        }
      }

      result.addAll(matchSentOriginalsSync(
        sent: sentVideos,
        originals: candVideos,
        hashes: hashes,
        durationsSec: durations,
      ));
    }

    // 2) Fotoğraflar: sıkı algısal dHash doğrulaması.
    if (sentImages.isNotEmpty && nonSentImages.isNotEmpty) {
      final candImages = _selectCandidates(
        sent: sentImages,
        pool: nonSentImages,
        windowMs: _imageWindowMs,
        maxUncached: _maxUncachedImages,
      );
      for (final e in [...sentImages, ...candImages]) {
        if (isCancelled?.call() == true) return result;
        final h = await MediaFingerprint.of(e);
        if (h != null) hashes[e.path] = h;
      }

      result.addAll(matchSentOriginalsSync(
        sent: sentImages,
        originals: candImages,
        hashes: hashes,
      ));
    }

    await MediaFingerprint.flush();
    return result;
  }

  /// Zaman penceresi + önbellek birleşimiyle aday asılları seçer.
  static List<FsEntry> _selectCandidates({
    required List<FsEntry> sent,
    required List<FsEntry> pool,
    required int windowMs,
    required int maxUncached,
  }) {
    final sentTimes = [for (final s in sent) s.modifiedMs]..sort();

    int minGapToSent(int origMs) {
      // Gönderim çekimden sonra olur (en çok `_futureSlackMs` sapmayla).
      var lo = 0;
      var hi = sentTimes.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (sentTimes[mid] + _futureSlackMs < origMs) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo >= sentTimes.length) return windowMs + 1;
      final diff = sentTimes[lo] - origMs;
      return diff < 0 ? 0 : diff;
    }

    final cached = <FsEntry>[];
    final uncachedNear = <(int, FsEntry)>[];
    for (final e in pool) {
      if (MediaFingerprint.cachedOf(e) != null) {
        cached.add(e);
      } else {
        final gap = minGapToSent(e.modifiedMs);
        if (gap <= windowMs) {
          uncachedNear.add((gap, e));
        }
      }
    }

    // Havuz zaten küçükse pencere dışı kalanları da ekle (eski gönderilmiş
    // videolar/fotoğraflar da yakalansın).
    if (pool.length <= maxUncached) {
      return pool;
    }

    uncachedNear.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      ...cached,
      for (final pair in uncachedNear.take(maxUncached)) pair.$2,
    ];
  }

  /// **Saf eşleştirici (birim testli):** önceden çıkarılmış parmak izi ve
  /// (videolar için) süre tablosuna göre her `sent` dosyasının en güvenilir
  /// aslını döner.
  static Map<String, FsEntry> matchSentOriginalsSync({
    required List<FsEntry> sent,
    required List<FsEntry> originals,
    required Map<String, int> hashes,
    Map<String, int> durationsSec = const {},
  }) {
    final out = <String, FsEntry>{};
    if (sent.isEmpty || originals.isEmpty) return out;

    for (final s in sent) {
      if (!isChatSentCopy(s)) continue;
      final hs = hashes[s.path];
      if (hs == null) continue;
      final isVideo = s.category == FmCategory.video;
      final dSent = isVideo ? durationsSec[s.path] : null;

      FsEntry? best;
      var bestDist = 999;
      var bestDurDiff = 999999;

      for (final o in originals) {
        if (o.path == s.path || isChatSentCopy(o)) continue;
        if (o.category != s.category) continue;
        final ho = hashes[o.path];
        if (ho == null) continue;

        final dist = hamming(hs, ho);
        var durDiff = 0;

        if (isVideo) {
          final dOrig = durationsSec[o.path];
          if (dSent != null && dOrig != null) {
            // İki süre de biliniyor: ±2 sn ya da %5 içinde olmalı;
            // aynı ortamda çekilmiş farklı uzunlukta videolar elenir.
            durDiff = (dSent - dOrig).abs();
            final tol = math.max(2, (dOrig * 0.05).round());
            if (durDiff > tol || dist > 3) continue;
          } else {
            // Süre yoksa çok sıkı görsel eşleşme + asıl daha eski/yakın olmalı.
            if (dist > 2) continue;
            if (s.modifiedMs > 0 &&
                o.modifiedMs > s.modifiedMs + _futureSlackMs) {
              continue;
            }
          }
        } else {
          // Görsellerde sıkı eşik (Hamming ≤ 2).
          if (dist > SimilarityLevel.strict.maxDistance) continue;
        }

        final better = best == null ||
            dist < bestDist ||
            (dist == bestDist && durDiff < bestDurDiff) ||
            (dist == bestDist &&
                durDiff == bestDurDiff &&
                o.sizeBytes > best.sizeBytes);
        if (better) {
          best = o;
          bestDist = dist;
          bestDurDiff = durDiff;
        }
      }

      if (best != null) {
        out[s.path] = best;
      }
    }
    return out;
  }
}
