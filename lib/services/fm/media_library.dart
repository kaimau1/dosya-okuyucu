import '../../models/fs_entry.dart';
import 'fm_env.dart';
import 'folder_lock.dart';
import 'fs_scan.dart';
import 'search_index.dart';

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
abstract final class MediaLibrary {
  /// Tek listede tutulacak üst sınır. 100 bin dosya ~20 MB'lık girdi demek;
  /// bunun üstünde ekran zaten kullanılamaz hâle gelir, sınır bilinçlidir.
  static const maxItems = 100000;

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
        return FolderLock.filterOut(rows, lockedFolders, (e) => e.path);
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
}
