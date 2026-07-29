import '../../models/file_age.dart';
import '../../models/fs_entry.dart';
import 'duplicate_finder.dart';
import 'fs_scan.dart';

/// Yer açma önerisi: ne, ne kadar yer, hangi dosyalar.
class CleanupSuggestion {
  /// Kalıcı kimlik (arayüzde seçim durumu bunun üstünden tutulur).
  final String id;
  final String title;
  final String detail;

  /// Kazanılacak yer.
  final int bytes;

  /// Silinecek/temizlenecek dosyalar. Boşsa eylem özeldir (çöp kutusu).
  final List<FsEntry> files;

  /// Güvenli mi? (Kullanıcı onayı olmadan varsayılan seçili gelir mi?)
  ///
  /// Çöp kutusu ve APK kurulum dosyaları güvenlidir; **fotoğraf/video asla
  /// varsayılan seçili gelmez** — yanlışlıkla anı silmek geri alınamaz.
  final bool safeByDefault;

  const CleanupSuggestion({
    required this.id,
    required this.title,
    required this.detail,
    required this.bytes,
    this.files = const [],
    this.safeByDefault = false,
  });
}

/// **Yer açma asistanı** — "3 GB yer aç" dendiğinde neyin silineceğini
/// önceliklendirir.
///
/// Saf fonksiyon: girdileri (tarama sonucu, indirilenler, kopyalar, çöp) alır,
/// sıralı öneri listesi döner. Dosya sistemine dokunmaz → birim testi yazılır
/// ve "yanlışlıkla sildi" sınıfı hatalar burada yakalanır.
///
/// Sıralama **kazanç × güvenlik**: en çok yer açan güvenli öneri başta.
List<CleanupSuggestion> adviseCleanup({
  required StorageIndex index,
  required List<FsEntry> downloads,
  required List<DuplicateGroup> duplicates,
  required int trashBytes,
  required int trashCount,
  DateTime? now,
}) {
  final today = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final out = <CleanupSuggestion>[];

  if (trashCount > 0) {
    out.add(CleanupSuggestion(
      id: 'trash',
      title: 'Çöp kutusunu boşalt',
      detail: '$trashCount öğe · zaten silinmiş dosyalar',
      bytes: trashBytes,
      safeByDefault: true,
    ));
  }

  // Kopyalar: her gruptan biri KALIR, kalanlar sayılır.
  if (duplicates.isNotEmpty) {
    final extras = <FsEntry>[];
    var bytes = 0;
    for (final group in duplicates) {
      final sorted = [...group.files]
        ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      // En eski kopya korunur (asıl dosya olma ihtimali en yüksek olan).
      for (final extra in sorted.skip(1)) {
        extras.add(extra);
        bytes += extra.sizeBytes;
      }
    }
    if (extras.isNotEmpty) {
      out.add(CleanupSuggestion(
        id: 'duplicates',
        title: 'Yinelenen dosyaları temizle',
        detail: '${extras.length} fazladan kopya · her gruptan biri kalır',
        bytes: bytes,
        files: extras,
        safeByDefault: true,
      ));
    }
  }

  // 180+ gündür dokunulmamış indirilenler.
  final stale = downloads
      .where((e) => ageLevelFor(daysBetween(e.lastTouchedMs, today)) ==
          AgeLevel.ancient)
      .toList()
    ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  if (stale.isNotEmpty) {
    out.add(CleanupSuggestion(
      id: 'stale_downloads',
      title: 'Eski indirilenler',
      detail: '${stale.length} dosya · 180+ gündür açılmamış',
      bytes: stale.fold(0, (s, e) => s + e.sizeBytes),
      files: stale,
      safeByDefault: false,
    ));
  }

  // Kurulum dosyaları: uygulama kurulduysa APK'nın durmasına gerek yok.
  final apks = index.files(FmCategory.apk);
  if (apks.isNotEmpty) {
    out.add(CleanupSuggestion(
      id: 'apk',
      title: 'Kurulum dosyaları (APK)',
      detail: '${apks.length} dosya · uygulama kurulduysa gereksiz',
      bytes: apks.fold(0, (s, e) => s + e.sizeBytes),
      files: apks,
      safeByDefault: true,
    ));
  }

  // En büyük videolar — kazanç burada, ama ASLA varsayılan seçili değil.
  final bigVideos = index
      .files(FmCategory.video)
      .where((e) => e.sizeBytes >= 100 * 1024 * 1024)
      .toList()
    ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  if (bigVideos.isNotEmpty) {
    final top = bigVideos.take(30).toList();
    out.add(CleanupSuggestion(
      id: 'big_videos',
      title: 'Büyük videolar',
      detail: '${top.length} video · 100 MB üzeri (tek tek seçin)',
      bytes: top.fold(0, (s, e) => s + e.sizeBytes),
      files: top,
      safeByDefault: false,
    ));
  }

  out.sort((a, b) {
    // Güvenli öneriler önce, sonra kazanca göre.
    if (a.safeByDefault != b.safeByDefault) return a.safeByDefault ? -1 : 1;
    return b.bytes.compareTo(a.bytes);
  });
  return out;
}

/// Seçili önerilerin toplam kazancı.
int cleanupTotal(Iterable<CleanupSuggestion> selected) =>
    selected.fold(0, (sum, s) => sum + s.bytes);
