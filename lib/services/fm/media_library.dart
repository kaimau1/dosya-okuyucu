import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'folder_lock.dart';
import 'fs_scan.dart';
import 'search_index.dart';
import 'storage_stats.dart';

/// Bir kategorinin (Görüntüler / Videolar / Ses / Belgeler …) **eksiksiz**
/// dosya listesini getirir.
///
/// ## Niye var
/// Pano taraması ([FsScan.index]) kategori başına yalnız en yeni 800 dosyayı
/// tutar — kutulardaki sayılar/önizlemeler için yeterli, ama kullanıcı
/// kategoriye girince hepsini görmek ister. Hata (2026-07-29): *"videolarda
/// tüm videolar görünmüyor ama dosyaların içinde bulabiliyorum"* — dosya
/// gezgini gerçeği gösteriyordu, kategori ekranı kırpılmış listeyi.
///
/// ## Nasıl
/// 1. Arama dizini ([SearchIndex]) hazırsa oradan süzülür — disk gezilmez,
///    100 bin satırlık düz dosyayı okumak saniyenin altında sürer.
/// 2. Dizin yoksa/boşsa diske düşülür ([FsScan.collect]); sonuç aynıdır,
///    yalnız ilk sefer yavaştır. Bu sırada dizin arka planda kurulur.
/// 3. **Dizinden SONRA gelen dosyalar diskten eklenir** ([freshTail]).
abstract final class MediaLibrary {
  /// Tek listede tutulacak üst sınır. 100 bin dosya ~20 MB'lık girdi demek;
  /// bunun üstünde ekran zaten kullanılamaz hâle gelir, sınır bilinçlidir.
  static const maxItems = 100000;

  /// Dizin kurulduktan sonra eklenen dosyalar için taranacak en fazla kayıt.
  static const freshLimit = 600;

  /// [category] null ise tüm dosyalar döner.
  /// [lockedFolders] verilirse o klasörlerin altındakiler **listeye hiç
  /// girmez**: kilitli klasördeki fotoğraf "Görüntüler" ızgarasında görünürse
  /// kilit hiçbir işe yaramaz.
  static Future<List<FsEntry>> categoryFiles(
    FmCategory? category, {
    String? root,
    int limit = maxItems,
    Iterable<String> lockedFolders = const [],
  }) async {
    await SearchIndex.ensureLoaded();
    if (SearchIndex.isReady) {
      final rows = await FsScan.collectFromIndex(
        SearchIndex.indexPath,
        category: category,
        root: root,
        limit: limit,
      );
      if (rows.isNotEmpty) {
        final fresh = await freshTail(category, root: root);
        return FolderLock.filterOut(
            _merge(rows, fresh), lockedFolders, (e) => e.path);
      }
      // Boş sonuç "dizin bozuk" da olabilir "gerçekten yok" da; diske düşmek
      // ikinci durumda yalnız bir tarama maliyeti, birincisinde doğru cevap.
    }
    final scanned = await FsScan.collect(
      root != null ? [root] : FmEnv.volumeRoots,
      category: category,
      limit: limit,
    );
    return FolderLock.filterOut(scanned, lockedFolders, (e) => e.path);
  }

  /// **Dizin kurulduktan SONRA eklenen dosyalar.**
  ///
  /// Kök neden (kullanıcı 2026-09-03: *"görüntülerde yeni aldığım ekran
  /// görüntüleri hemen görülmüyor, sanki görülüp geri gidiyor"*): arama dizini
  /// yalnız UYGULAMA İÇİNDEN yapılan değişikliklerde bayatlıyor
  /// ([SearchIndex.isStale]). Ekran görüntüsü alan, kamerayla çeken ya da
  /// WhatsApp'tan indiren BAŞKA bir uygulama kimseye haber vermiyor; dizin
  /// "taze" sanılıyor ve kategori ekranı o dosyaları hiç göstermiyordu.
  ///
  /// "Görülüp geri gidiyor" da bunun ikinci yüzü: ekran önce panonun TAZE
  /// taramasıyla açılıyor (yeni ekran görüntüsü orada), sonra dizinden gelen
  /// daha uzun ama BAYAT liste onun yerine geçiyordu — dosya gözün önünde
  /// kayboluyordu.
  ///
  /// Çözüm tam tarama değil (100 bin dosyada dakikalar sürer): yeni dosyalar
  /// **rastgele yerlere düşmez** — DCIM, Ekran Görüntüleri, İndirilenler,
  /// mesajlaşma klasörleri. `FsScan.freshFiles` o birkaç ağacı geziyor ve
  /// saniyenin altında bitiyor (aynı tarama "Yeni Dosyalar" ekranında da var).
  static Future<List<FsEntry>> freshTail(
    FmCategory? category, {
    String? root,
  }) async {
    try {
      await FmEnv.ensureInit();
      final roots = StorageStats.hotFoldersForAll(
          root != null ? [root] : FmEnv.volumeRoots);
      if (roots.isEmpty) return const [];
      // Dizin kurulduğu andan öncesi zaten dizinde; yalnız sonrası aranır.
      // Bir dakikalık pay: dosya sistemi saati ile dizinin saati birebir
      // aynı anda ilerlemiyor, sınırda kalan dosya kaçmasın.
      final since = SearchIndex.builtAtMs > 0
          ? SearchIndex.builtAtMs - 60000
          : 0;
      final fresh =
          await FsScan.freshFiles(roots, sinceMs: since, limit: freshLimit);
      if (category == null) return fresh;
      return [
        for (final e in fresh)
          if (e.category == category) e,
      ];
    } catch (_) {
      // Taze tarama bir iyileştirme; başarısızsa dizin listesi yine dönüyor.
      return const [];
    }
  }

  /// İki listeyi yola göre teke indirir (dizindeki kayıt korunur, yenisi
  /// eklenir). Sıra bozulmuyor: çağıran ekran zaten kendi ölçütüne göre
  /// sıralıyor.
  static List<FsEntry> _merge(List<FsEntry> base, List<FsEntry> extra) {
    if (extra.isEmpty) return base;
    final seen = {for (final e in base) e.path};
    final out = [...base];
    for (final e in extra) {
      if (seen.add(e.path)) out.add(e);
    }
    return out;
  }
}
