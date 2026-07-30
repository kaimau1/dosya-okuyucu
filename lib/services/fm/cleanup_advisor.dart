import '../../models/file_age.dart';
import '../../models/fs_entry.dart';
import 'duplicate_finder.dart';
import 'fs_scan.dart';

/// Yer açma önerisi: ne, ne kadar yer, hangi dosyalar.
class CleanupSuggestion {
  /// Kalıcı kimlik (arayüzde seçim durumu bunun üstünden tutulur).
  final String id;

  /// Başlığın **çeviri anahtarı** — bu dosya saf Dart (birim testli) ve
  /// `AppStrings`'i tanımaz; metni ekran çözer: `context.t(s.titleKey)`.
  final String titleKey;

  /// Ayrıntının çeviri anahtarı ve içindeki `{…}` değişkenleri.
  final String detailKey;
  final Map<String, Object?> detailVars;

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
    required this.titleKey,
    required this.detailKey,
    this.detailVars = const {},
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
      titleKey: 'clean.trash',
      detailKey: 'clean.trash_detail',
      detailVars: {'n': trashCount},
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
        titleKey: 'clean.duplicates',
        detailKey: 'clean.duplicates_detail',
        detailVars: {'n': extras.length},
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
      titleKey: 'clean.stale_downloads',
      detailKey: 'clean.stale_downloads_detail',
      detailVars: {'n': stale.length},
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
      titleKey: 'clean.apk',
      detailKey: 'clean.apk_detail',
      detailVars: {'n': apks.length},
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
      titleKey: 'clean.big_videos',
      detailKey: 'clean.big_videos_detail',
      detailVars: {'n': top.length},
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

/// Seçili önerilerin **uygulanma sırası** — çöp kutusu boşaltma her zaman ilk.
///
/// ## Niye ayrı bir fonksiyon (ekranda tek satır olabilirdi)
/// Burada veri kaybı yatıyordu ve bir birim testiyle kilitlenmesi gerekiyor.
/// [cleanupSuggestions] listeyi "güvenliler önce, sonra kazanca göre" sıralıyor;
/// `trash` (çöpü boşalt) ve `duplicates` (yinelenenler) **ikisi de** güvenli
/// sayıldığı için kopyalar çöpten büyük olduğunda sıra `[kopyalar, …, çöp]`
/// oluyordu. Uygulama döngüsü kopyaları çöpe TAŞIYOR, hemen ardından `empty()`
/// çağrılıp çöp KALICI siliniyordu — kullanıcının onay penceresinde
/// "çöp kutusuna taşınır, oradan geri alabilirsiniz" yazdığı hâlde dosyalar
/// geri alınamaz şekilde yok oluyordu (2026-07-29 sadakat denetimi).
///
/// Çöp önce boşaltılınca hem istenen yer kazanılır hem bu turda çöpe düşen her
/// şey kurtarılabilir kalır. Diğer önerilerin kendi arasındaki sıra korunur
/// (kararlı): kullanıcı listeyi o sırayla gördü.
List<CleanupSuggestion> cleanupApplyOrder(
    Iterable<CleanupSuggestion> chosen) {
  final list = chosen.toList();
  return [
    ...list.where((s) => s.id == 'trash'),
    ...list.where((s) => s.id != 'trash'),
  ];
}
