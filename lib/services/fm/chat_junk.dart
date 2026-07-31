import '../../models/chat_media.dart';
import '../../models/fs_entry.dart';

/// Sohbet medyasında **muhtemelen gereksiz** yığın türleri.
///
/// Kullanıcı sorusu 2026-07-31: *"WhatsApp'tan 10 bin fotoğraf var, bunların
/// neredeyse %90'ı gereksiz, bunu nasıl çözeriz?"*
///
/// ## Neden kova, neden tek tek eleme değil
/// 10 bin dosyayı teker teker (kaydır-sil) elemek 10 bin karar demek; kimse
/// yapmaz. Çözüm kararı **toplulaştırmak**: aynı sebeple gereksiz olan binlerce
/// dosyayı tek bir onayla götürmek. Bu yüzden dosyalar "gereksiz olma sebebine"
/// göre kovalara ayrılıyor ve kullanıcı kova başına karar veriyor
/// ("çıkartmaların hepsi gitsin", "gönderdiklerimin hepsi gitsin").
///
/// ## Neden yalnız ÜST VERİ (dosya açılmıyor)
/// 10 bin görüntüyü çözmek (küçük resim üretmek, algısal parmak izi almak)
/// telefonda dakikalar sürer ve pili yer. Buradaki sınıflandırma yalnız yol,
/// ad, boyut ve tarihe bakar → 10 bin dosyada bile göz açıp kapayana kadar
/// biter. Görüntü çözmeyi gerektiren iş (birbirine BENZEYEN kareler) zaten ayrı
/// bir özellik: `SimilarFinder`. Kovalar bittiğinde kullanıcı oraya yönlendirilir.
///
/// ## Dürüst sınır
/// "Gereksiz" bir **tahmin**tir. Kimin gönderdiği, fotoğrafın anlamlı olup
/// olmadığı dosya sisteminden okunamaz (bkz. `models/chat_media.dart`). Bu
/// yüzden hiçbir kova kendiliğinden silinmez ve fotoğraf içeren hiçbir kova
/// varsayılan seçili GELMEZ — yalnız birebir kopyalar güvenli sayılır, çünkü
/// orada bir kopya her hâlükârda kalıyor.
enum ChatJunkKind {
  /// Birebir aynı dosyanın fazladan kopyaları (bir tanesi korunur).
  duplicate,

  /// Çıkartmalar — sohbet süsü, saklanacak bir şey değil.
  sticker,

  /// Animasyonlar (GIF) — genelde iletilmiş espri.
  gif,

  /// Profil fotoğrafı önbelleği.
  profilePhoto,

  /// Çok küçük görüntüler: iletilmiş "günaydın" görselleri, mem'ler, afişler.
  /// Telefonla çekilmiş bir kare WhatsApp sıkıştırmasından sonra bile bu
  /// eşiğin üstünde kalır.
  tiny,

  /// Kullanıcının kendi GÖNDERDİĞİ dosyalar (`.../Sent/`) — aslı zaten
  /// galeride/indirilenlerde duruyor, bu ikinci kopya.
  sent,

  /// Uzun süredir dokunulmamış eski medya.
  stale,
}

extension ChatJunkKindLabel on ChatJunkKind {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ChatJunkKind.duplicate => 'cj.kind_duplicate',
        ChatJunkKind.sticker => 'cj.kind_sticker',
        ChatJunkKind.gif => 'cj.kind_gif',
        ChatJunkKind.profilePhoto => 'cj.kind_profile',
        ChatJunkKind.tiny => 'cj.kind_tiny',
        ChatJunkKind.sent => 'cj.kind_sent',
        ChatJunkKind.stale => 'cj.kind_stale',
      };

  /// Kovanın NEDEN gereksiz sayıldığı — arayüzde her kovanın altında yazar.
  /// Kullanıcı gerekçeyi görmeden binlerce dosyayı silmeye ikna olmamalı.
  String get reasonKey => switch (this) {
        ChatJunkKind.duplicate => 'cj.why_duplicate',
        ChatJunkKind.sticker => 'cj.why_sticker',
        ChatJunkKind.gif => 'cj.why_gif',
        ChatJunkKind.profilePhoto => 'cj.why_profile',
        ChatJunkKind.tiny => 'cj.why_tiny',
        ChatJunkKind.sent => 'cj.why_sent',
        ChatJunkKind.stale => 'cj.why_stale',
      };

  /// Varsayılan seçili gelir mi? Yalnız birebir kopyalar (bir kopya kalıyor).
  bool get safeByDefault => this == ChatJunkKind.duplicate;
}

/// Tek kova: sebep + dosyalar.
class ChatJunkBucket {
  final ChatJunkKind kind;
  final List<FsEntry> files;

  const ChatJunkBucket(this.kind, this.files);

  int get bytes => files.fold<int>(0, (sum, e) => sum + e.sizeBytes);
  int get count => files.length;
}

/// Tarama sonucu.
class ChatJunkReport {
  /// Dolu kovalar, kazanç sırasına göre (çok yer açan üstte).
  final List<ChatJunkBucket> buckets;

  /// Taranan sohbet medyası dosyası ve toplam boyutu.
  final int scannedFiles;
  final int scannedBytes;

  const ChatJunkReport({
    required this.buckets,
    required this.scannedFiles,
    required this.scannedBytes,
  });

  static const empty =
      ChatJunkReport(buckets: [], scannedFiles: 0, scannedBytes: 0);

  int get junkFiles => buckets.fold<int>(0, (sum, b) => sum + b.count);
  int get junkBytes => buckets.fold<int>(0, (sum, b) => sum + b.bytes);

  /// Kovalara giren dosyaların taranan yığına oranı (%). "10 binin %90'ı
  /// gereksiz" iddiası ekranda bir sayıyla karşılanabilsin.
  int get junkPercent =>
      scannedFiles == 0 ? 0 : (junkFiles * 100 / scannedFiles).round();
}

/// Bir dosya sohbet uygulamasından mı geldi? (WhatsApp / Telegram klasörleri.)
///
/// Yol eşleşmesi `chatKindForPath` ile aynı bilgiye dayanır ama daha geniş:
/// tür klasörü tanınmasa bile "WhatsApp" / "Telegram" geçen her yol sohbet
/// medyasıdır (WhatsApp sürümden sürüme klasör adı değiştiriyor).
bool isChatMediaPath(String path) {
  final lower = path.toLowerCase().replaceAll('\\', '/');
  return lower.contains('whatsapp') ||
      lower.contains('telegram') ||
      lower.contains('/media/com.whatsapp') ||
      chatKindForPath(path) != null;
}

/// Sohbet medyasını "gereksiz olma sebebine" göre kovalara ayırır.
///
/// **Her dosya en çok BİR kovaya girer** (öncelik sırası aşağıda): aynı dosya
/// iki kovada sayılsaydı "şu kadar yer açılacak" toplamı yalan olurdu ve
/// kullanıcı iki kez silmeye çalışırdı.
///
/// Öncelik: kopya → çıkartma → GIF → profil → küçük → gönderilen → eski.
/// (Kopya en tepede, çünkü orada karar kesin: bir kopya kalıyor.)
///
/// [duplicateGroups] `DuplicateFinder`ın bulduğu birebir aynı dosya kümeleri;
/// her kümenin **en eskisi korunur**, kalanı kopya kovasına girer (yer açma
/// asistanıyla aynı kural — bkz. `cleanup_advisor.dart`).
/// [wasOpened] verilirse "eski" kovası yalnız **hiç açılmamış** dosyaları alır.
ChatJunkReport classifyChatJunk({
  required List<FsEntry> entries,
  required int nowMs,
  List<List<FsEntry>> duplicateGroups = const [],
  int tinyBytes = defaultTinyBytes,
  int staleDays = defaultStaleDays,
  bool Function(String path)? wasOpened,
}) {
  final media = [
    for (final e in entries)
      if (!e.isDir && isChatMediaPath(e.path)) e,
  ];
  final byKind = <ChatJunkKind, List<FsEntry>>{};
  final taken = <String>{};

  void put(ChatJunkKind kind, FsEntry entry) {
    if (!taken.add(entry.path)) return; // zaten bir kovada
    (byKind[kind] ??= []).add(entry);
  }

  // 1) Birebir kopyalar — en eski korunur.
  final mediaPaths = {for (final e in media) e.path};
  for (final group in duplicateGroups) {
    final inScope = [
      for (final e in group)
        if (mediaPaths.contains(e.path)) e,
    ]..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
    // Küme sohbet medyasının DIŞINDA da kopya barındırıyorsa buradaki
    // hepsini silmek dosyayı tümden yok edebilirdi; en az biri kalmalı.
    if (inScope.length < 2) continue;
    for (final extra in inScope.skip(1)) {
      put(ChatJunkKind.duplicate, extra);
    }
  }

  final staleBefore = nowMs - staleDays * 24 * 60 * 60 * 1000;
  for (final entry in media) {
    if (taken.contains(entry.path)) continue;
    final kind = chatKindForEntry(entry);
    final lower = entry.path.toLowerCase();

    if (kind == ChatMediaKind.sticker) {
      put(ChatJunkKind.sticker, entry);
    } else if (kind == ChatMediaKind.gif) {
      put(ChatJunkKind.gif, entry);
    } else if (lower.contains('profile photo') ||
        lower.contains('profile_photo')) {
      put(ChatJunkKind.profilePhoto, entry);
    } else if (entry.category == FmCategory.image &&
        entry.sizeBytes > 0 &&
        entry.sizeBytes <= tinyBytes) {
      put(ChatJunkKind.tiny, entry);
    } else if (isSentByMe(entry.path)) {
      put(ChatJunkKind.sent, entry);
    } else if (entry.lastTouchedMs > 0 &&
        entry.lastTouchedMs < staleBefore &&
        !(wasOpened?.call(entry.path) ?? false)) {
      put(ChatJunkKind.stale, entry);
    }
  }

  final buckets = [
    for (final entry in byKind.entries)
      if (entry.value.isNotEmpty) ChatJunkBucket(entry.key, entry.value),
  ]..sort((a, b) {
      // Güvenli kova (kopyalar) önce, sonra kazanca göre — yer açma
      // asistanıyla aynı sıralama mantığı.
      if (a.kind.safeByDefault != b.kind.safeByDefault) {
        return a.kind.safeByDefault ? -1 : 1;
      }
      return b.bytes.compareTo(a.bytes);
    });

  return ChatJunkReport(
    buckets: buckets,
    scannedFiles: media.length,
    scannedBytes: media.fold<int>(0, (sum, e) => sum + e.sizeBytes),
  );
}

/// "Küçük görüntü" eşiği. 150 KB: WhatsApp kendi sıkıştırmasından sonra bile
/// gerçek bir fotoğrafı genelde 150 KB üstünde bırakıyor; bunun altı ağırlıklı
/// olarak iletilen afiş/mem/"günaydın" görselleri oluyor. Kullanıcı ekrandan
/// değiştirebiliyor — eşiği sabit tutup "gereksiz" demek fazla iddialı olurdu.
const int defaultTinyBytes = 150 * 1024;

/// "Eski" eşiği (gün). Yer açma asistanındaki `AgeLevel.ancient` ile aynı.
const int defaultStaleDays = 180;

/// Ekranda sunulan küçük-görüntü eşikleri.
const List<int> tinyBytesChoices = [
  50 * 1024,
  100 * 1024,
  150 * 1024,
  300 * 1024,
  500 * 1024,
];
