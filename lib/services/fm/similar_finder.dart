import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import 'fs_scan.dart';
import 'image_hash.dart';
import 'job_queue.dart';
import 'media_fingerprint.dart';

/// Birbirine **benzeyen** (birebir aynı olmayan) görüntü/video kümesi.
class SimilarGroup {
  /// En iyi kopya **başta**: en net kare, eşitlikte en büyük dosya (en az
  /// sıkıştırılmış), o da eşitse en yenisi ([SimilarFinder.orderBest]).
  /// Arayüz varsayılan olarak bunu korur.
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
  /// İş kuyruğundaki kararlı kimlik — **kapsam başına ayrı** (ekran geri
  /// dönünce KENDİ sonucunu bulur).
  ///
  /// Eskiden tek bir `'similar_media'` sabiti vardı: Görüntüler'den açılan
  /// tarama ile Videolar'dan ya da panodaki "Benzer görsel" kutucuğundan açılan
  /// tarama aynı işi paylaşıyordu. Sonuç, ikinci ekranın açılışta "sonuç zaten
  /// var" deyip **başka bir kapsamın** gruplarını kendi sonucuymuş gibi
  /// göstermesiydi — kullanıcı Videolar'da fotoğraf grupları görüp onları
  /// silebilirdi (2026-07-29 sadakat denetimi).
  static String jobIdFor(String scope) => 'similar_media:$scope';

  /// SAF: grubu "en iyi kare başta" sıralar — önce netlik kademesi
  /// ([sharpnessTier]; bulanık kopya büyük olsa da geride kalır), eşitse en
  /// büyük dosya (en az sıkıştırılmış), o da eşitse en yenisi.
  static List<FsEntry> orderBest(
          List<FsEntry> files, Map<String, double?> sharpness) =>
      [...files]..sort((a, b) {
          final byTier = sharpnessTier(sharpness[b.path])
              .compareTo(sharpnessTier(sharpness[a.path]));
          if (byTier != 0) return byTier;
          final bySize = b.sizeBytes.compareTo(a.sizeBytes);
          return bySize != 0 ? bySize : b.modifiedMs.compareTo(a.modifiedMs);
        });

  /// [entries] içindeki benzer kümeleri döndürür.
  ///
  /// [handle] verilirse ilerleme bildirilir ve iptal isteği yoklanır.
  ///
  /// [strings]: bu dosya saf servis katmanı, `BuildContext` almıyor; ilerleme
  /// metinleri çağıranın verdiği tablodan çözülür.
  static Future<List<SimilarGroup>> run(
    List<FsEntry> entries, {
    SimilarityLevel level = SimilarityLevel.normal,
    JobHandle? handle,
    AppStrings strings = const AppStrings(AppLanguage.tr),
  }) async {
    final files = [
      for (final e in entries)
        if (!e.isDir &&
            (e.category == FmCategory.image || e.category == FmCategory.video))
          e,
    ];
    handle?.report(done: 0, total: files.length, detail: strings.t('simf.preparing'));

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
        detail: strings
            .t('simf.inspected', {'n': i + 1, 'total': files.length}),
      );
    }
    await MediaFingerprint.flush();
    handle?.throwIfCancelled();
    handle?.report(detail: strings.t('simf.matching'));

    final indexGroups =
        groupSimilar(hashes, maxDistance: level.maxDistance);
    final groups = <SimilarGroup>[];
    for (final indexes in indexGroups) {
      handle?.throwIfCancelled();
      final group = [for (final i in indexes) hashed[i]];
      // Ayıkla 2: yalnız gruptaki görüntülerin netliği ölçülür (galerinin
      // tamamı değil) → en net kare başa.
      final sharp = <String, double?>{
        for (final f in group) f.path: await MediaFingerprint.sharpness(f),
      };
      groups.add(SimilarGroup(orderBest(group, sharp)));
    }
    groups.sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes));
    handle?.report(
      detail: groups.isEmpty
          ? strings.t('simf.none')
          : strings.t('sim.groups_summary', {
              'n': groups.length,
              'size': FsPaths.humanSize(
                  groups.fold<int>(0, (sum, g) => sum + g.wastedBytes)),
            }),
    );
    return groups;
  }
}
