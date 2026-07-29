import '../../models/fs_entry.dart';
import 'image_hash.dart';
import 'job_queue.dart';
import 'media_fingerprint.dart';

/// Birbirine **benzeyen** (birebir aynı olmayan) görüntü/video kümesi.
class SimilarGroup {
  /// En iyi kopya **başta**: en büyük dosya (en az sıkıştırılmış), eşitlikte
  /// en yenisi. Arayüz varsayılan olarak bunu korur.
  final List<FsEntry> files;

  const SimilarGroup(this.files);

  /// İlk dosya dışındakiler silinirse kazanılacak yer.
  int get wastedBytes =>
      files.skip(1).fold<int>(0, (sum, e) => sum + e.sizeBytes);

  int get totalBytes => files.fold<int>(0, (sum, e) => sum + e.sizeBytes);
}

/// **Benzer görüntü/video bulucu** — algısal parmak iziyle.
///
/// `DuplicateFinder` ile ayrımı net:
/// - `DuplicateFinder`: **birebir aynı dosya** (bayt bayt doğrulanır). Silme
///   kararı kesin, yanlış pozitif yok.
/// - `SimilarFinder`: **aynı görünen** dosya (yeniden sıkıştırılmış, boyutu
///   değişmiş, hafif kırpılmış). Tahmine dayanır → arayüz asla kendiliğinden
///   silmez, kullanıcı görüp onaylar.
abstract final class SimilarFinder {
  /// İş kuyruğundaki kararlı kimlik (ekran geri dönünce sonucu bulur).
  static const jobId = 'similar_media';

  /// [entries] içindeki benzer kümeleri döndürür.
  ///
  /// [handle] verilirse ilerleme bildirilir ve iptal isteği yoklanır.
  static Future<List<SimilarGroup>> run(
    List<FsEntry> entries, {
    SimilarityLevel level = SimilarityLevel.normal,
    JobHandle? handle,
  }) async {
    final files = [
      for (final e in entries)
        if (!e.isDir &&
            (e.category == FmCategory.image || e.category == FmCategory.video))
          e,
    ];
    handle?.report(done: 0, total: files.length, detail: 'Hazırlanıyor…');

    final hashes = <int>[];
    final hashed = <FsEntry>[];
    for (var i = 0; i < files.length; i++) {
      handle?.throwIfCancelled();
      final hash = await MediaFingerprint.of(files[i]);
      if (hash != null) {
        hashes.add(hash);
        hashed.add(files[i]);
      }
      handle?.report(
        done: i + 1,
        detail: '${i + 1} / ${files.length} dosya incelendi',
      );
    }
    await MediaFingerprint.flush();
    handle?.throwIfCancelled();
    handle?.report(detail: 'Eşleşmeler çıkarılıyor…');

    final indexGroups =
        groupSimilar(hashes, maxDistance: level.maxDistance);
    final groups = <SimilarGroup>[];
    for (final indexes in indexGroups) {
      final group = [for (final i in indexes) hashed[i]]
        ..sort((a, b) {
          final bySize = b.sizeBytes.compareTo(a.sizeBytes);
          return bySize != 0 ? bySize : b.modifiedMs.compareTo(a.modifiedMs);
        });
      groups.add(SimilarGroup(group));
    }
    groups.sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes));
    handle?.report(
      detail: groups.isEmpty
          ? 'Benzer dosya bulunamadı'
          : '${groups.length} benzer grup bulundu',
    );
    return groups;
  }
}
