/// Dosya listelerinin **süzgeci**: tarih aralığı, boyut aralığı, kaynak
/// (kamera/WhatsApp…) ve dosya türü.
///
/// Bilinçli olarak **saf Dart** (Flutter importu yok): "son 7 gün" penceresinin
/// gün sınırına doğru oturması, özel aralığın son gününün de kapsanması gibi
/// kolay kaçan kurallar birim testiyle sabitlensin diye.
///
/// Kullanıcı isteği (2026-07-29): "videolarda arama lazım isimlerine göre
/// zamana göre aynı şekilde fotolar içinde · daha çok filtreleme seçeneği
/// lazım video foto için".
library;

import '../core/text_search.dart';
import 'chat_media.dart';
import 'fs_entry.dart';
import 'media_bucket.dart';

/// Hazır tarih aralıkları. [custom] kullanıcıdan gün seçtirir.
enum FmDateRange { any, today, week, month, year, custom }

extension FmDateRangeLabel on FmDateRange {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        FmDateRange.any => 'enum.date_any',
        FmDateRange.today => 'enum.date_today',
        FmDateRange.week => 'enum.date_week',
        FmDateRange.month => 'enum.date_month',
        FmDateRange.year => 'enum.date_year',
        FmDateRange.custom => 'enum.date_custom',
      };

  String get label => switch (this) {
        FmDateRange.any => 'Her zaman',
        FmDateRange.today => 'Bugün',
        FmDateRange.week => 'Son 7 gün',
        FmDateRange.month => 'Son 30 gün',
        FmDateRange.year => 'Son 1 yıl',
        FmDateRange.custom => 'Özel aralık',
      };
}

/// Hazır boyut aralıkları (video/görsel ayıklamada en çok işe yarayanlar).
enum FmSizeRange { any, tiny, small, medium, large }

extension FmSizeRangeLabel on FmSizeRange {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        FmSizeRange.any => 'enum.size_any',
        FmSizeRange.tiny => 'enum.size_tiny',
        FmSizeRange.small => 'enum.size_small',
        FmSizeRange.medium => 'enum.size_medium',
        FmSizeRange.large => 'enum.size_large',
      };

  String get label => switch (this) {
        FmSizeRange.any => 'Tümü',
        FmSizeRange.tiny => '1 MB altı',
        FmSizeRange.small => '1 – 10 MB',
        FmSizeRange.medium => '10 – 100 MB',
        FmSizeRange.large => '100 MB üzeri',
      };

  /// Alt sınır (dahil).
  int get minBytes => switch (this) {
        FmSizeRange.any || FmSizeRange.tiny => 0,
        FmSizeRange.small => 1024 * 1024,
        FmSizeRange.medium => 10 * 1024 * 1024,
        FmSizeRange.large => 100 * 1024 * 1024,
      };

  /// Üst sınır (hariç); sınırsızsa null.
  int? get maxBytes => switch (this) {
        FmSizeRange.any || FmSizeRange.large => null,
        FmSizeRange.tiny => 1024 * 1024,
        FmSizeRange.small => 10 * 1024 * 1024,
        FmSizeRange.medium => 100 * 1024 * 1024,
      };
}

/// Çözülmüş zaman penceresi (ms). Sınırlar dahildir; null = sınırsız.
class FmTimeWindow {
  final int? fromMs;
  final int? toMs;
  const FmTimeWindow(this.fromMs, this.toMs);

  static const unbounded = FmTimeWindow(null, null);

  bool contains(int ms) {
    if (fromMs != null && ms < fromMs!) return false;
    if (toMs != null && ms > toMs!) return false;
    return true;
  }
}

/// Bir listeye uygulanan süzgeç. Değişmez (immutable); değiştirmek için
/// `with*` üreteçleri kullanılır — nullable alanlarda `copyWith` "değeri
/// null'a çek" ile "dokunma"yı ayırt edemediği için bilinçli tercih.
class FmFilter {
  /// Kaynaklar (Kamera / WhatsApp / Ekran görüntüsü …). **Boş = tümü.**
  ///
  /// Çoklu seçim (kullanıcı isteği 2026-07-29: "kaynak kısmında birden fazla
  /// kaynak seçilebilmeli"): "Kamera + WhatsApp" gibi birleşimler tek geçişte
  /// süzülebilsin.
  final Set<MediaBucket> buckets;

  /// Seçili uzantılar (küçük harf, noktasız). Boş = tümü.
  final Set<String> extensions;

  final FmDateRange dateRange;

  /// [FmDateRange.custom] için gün seçimleri (günün herhangi bir anı yeter;
  /// pencere gün sınırlarına yuvarlanır).
  final int? customFromMs;
  final int? customToMs;

  final FmSizeRange sizeRange;

  /// Aynı dosyanın kopyaları tek satıra indirilsin mi?
  ///
  /// WhatsApp aynı görseli birden çok klasöre yazar (Media/WhatsApp Images,
  /// .../Sent, eski `/WhatsApp` yolu…) → galeride "aynı resimden 3 tane"
  /// görünür (kullanıcı hatası 2026-07-29). Ad+boyut aynıysa kopya sayılır;
  /// içerik karşılaştırması (bayt bayt) **Yinelenen dosyalar** ekranının işi,
  /// galeride 20 bin dosyayı okumak dondururdu.
  final bool hideDuplicates;

  /// Mesajlaşma dosyası tür kırılımı (WhatsApp Görüntü/Video/Belge/Sesli not…).
  /// **Boş = tümü.** Kullanıcı isteği 2026-07-29.
  final Set<ChatMediaKind> chatKinds;

  /// Gelen / gönderilen (WhatsApp `Sent` klasörü) ayrımı.
  final ChatDirection direction;

  /// Kullanıcının verdiği etiketler (kişi/grup). **Boş = tümü.**
  /// Gönderen bilgisi diskte olmadığı için kişi süzmesinin dürüst yolu bu
  /// (bkz. `models/chat_media.dart` ve `services/fm/file_tags.dart`).
  final Set<String> tags;

  const FmFilter({
    this.buckets = const {},
    this.extensions = const {},
    this.dateRange = FmDateRange.any,
    this.customFromMs,
    this.customToMs,
    this.sizeRange = FmSizeRange.any,
    this.hideDuplicates = false,
    this.chatKinds = const {},
    this.direction = ChatDirection.any,
    this.tags = const {},
  });

  static const none = FmFilter();

  /// Tek noktadan çoğaltma. `with*` üreteçleri bunu kullanır: her alan
  /// eklendiğinde yedi ayrı üreteci güncellemek (ve birini atlamak) yerine
  /// tek yer değişir.
  FmFilter _copy({
    Set<MediaBucket>? buckets,
    Set<String>? extensions,
    FmDateRange? dateRange,
    int? customFromMs,
    int? customToMs,
    bool clearCustomRange = false,
    FmSizeRange? sizeRange,
    bool? hideDuplicates,
    Set<ChatMediaKind>? chatKinds,
    ChatDirection? direction,
    Set<String>? tags,
  }) =>
      FmFilter(
        buckets: buckets ?? this.buckets,
        extensions: extensions ?? this.extensions,
        dateRange: dateRange ?? this.dateRange,
        customFromMs:
            clearCustomRange ? customFromMs : (customFromMs ?? this.customFromMs),
        customToMs:
            clearCustomRange ? customToMs : (customToMs ?? this.customToMs),
        sizeRange: sizeRange ?? this.sizeRange,
        hideDuplicates: hideDuplicates ?? this.hideDuplicates,
        chatKinds: chatKinds ?? this.chatKinds,
        direction: direction ?? this.direction,
        tags: tags ?? this.tags,
      );

  FmFilter withBuckets(Set<MediaBucket> value) => _copy(buckets: value);

  /// Kaynağı ekler/çıkarır (çip dokunuşu).
  FmFilter toggleBucket(MediaBucket bucket) {
    final next = {...buckets};
    if (!next.remove(bucket)) next.add(bucket);
    return withBuckets(next);
  }

  FmFilter withHideDuplicates(bool value) => _copy(hideDuplicates: value);

  FmFilter withExtensions(Set<String> value) =>
      _copy(extensions: {for (final e in value) e.toLowerCase()});

  /// Uzantıyı ekler/çıkarır (çip dokunuşu).
  FmFilter toggleExtension(String ext) {
    final next = {...extensions};
    final key = ext.toLowerCase();
    if (!next.remove(key)) next.add(key);
    return withExtensions(next);
  }

  FmFilter withDateRange(FmDateRange value, {int? fromMs, int? toMs}) => _copy(
        dateRange: value,
        clearCustomRange: true,
        customFromMs: value == FmDateRange.custom ? fromMs : null,
        customToMs: value == FmDateRange.custom ? toMs : null,
      );

  FmFilter withSizeRange(FmSizeRange value) => _copy(sizeRange: value);

  FmFilter withChatKinds(Set<ChatMediaKind> value) => _copy(chatKinds: value);

  /// Mesajlaşma türünü ekler/çıkarır (çoklu seçim).
  FmFilter toggleChatKind(ChatMediaKind kind) {
    final next = {...chatKinds};
    if (!next.remove(kind)) next.add(kind);
    return withChatKinds(next);
  }

  FmFilter withDirection(ChatDirection value) => _copy(direction: value);

  FmFilter withTags(Set<String> value) => _copy(tags: value);

  /// Etiketi ekler/çıkarır (çoklu seçim → "Ayşe VEYA İş grubu").
  FmFilter toggleTag(String tag) {
    final next = {...tags};
    if (!next.remove(tag)) next.add(tag);
    return withTags(next);
  }

  /// Kaç ölçüt etkin? (Arayüzde süzgeç düğmesinin rozeti.)
  int get activeCount =>
      (buckets.isEmpty ? 0 : 1) +
      (extensions.isEmpty ? 0 : 1) +
      (dateRange == FmDateRange.any ? 0 : 1) +
      (sizeRange == FmSizeRange.any ? 0 : 1) +
      (chatKinds.isEmpty ? 0 : 1) +
      (direction == ChatDirection.any ? 0 : 1) +
      (tags.isEmpty ? 0 : 1);

  bool get isActive => activeCount > 0;

  /// Önbellek anahtarı: süzgeç değişmediyse liste yeniden süzülmesin.
  ///
  /// 20 bin dosyalı bir kategoride süzme+sıralama her karede yapılırsa
  /// uygulama gözle görülür şekilde kasar (kullanıcı 2026-07-29:
  /// "uygulama biraz kasmaya başladı").
  String get signature => [
        buckets.map((b) => b.name).toList()..sort(),
        extensions.toList()..sort(),
        dateRange.name,
        customFromMs,
        customToMs,
        sizeRange.name,
        hideDuplicates,
        chatKinds.map((k) => k.name).toList()..sort(),
        direction.name,
        tags.toList()..sort(),
      ].join('|');

  /// Tarih ölçütünün gerçek zaman penceresi.
  ///
  /// "Son 7 gün" = bugün dahil 7 gün → bugünün 00:00'ından 6 gün geriye.
  /// Özel aralıkta bitiş günü **tamamen** kapsanır (23:59:59.999) — yoksa
  /// kullanıcı bitiş gününü seçtiği hâlde o günün dosyaları düşerdi.
  FmTimeWindow window({DateTime? now}) {
    final today = now ?? DateTime.now();
    DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
    int backDays(int days) =>
        startOfDay(today).subtract(Duration(days: days)).millisecondsSinceEpoch;

    return switch (dateRange) {
      FmDateRange.any => FmTimeWindow.unbounded,
      FmDateRange.today => FmTimeWindow(backDays(0), null),
      FmDateRange.week => FmTimeWindow(backDays(6), null),
      FmDateRange.month => FmTimeWindow(backDays(29), null),
      FmDateRange.year => FmTimeWindow(backDays(364), null),
      FmDateRange.custom => FmTimeWindow(
          customFromMs == null
              ? null
              : startOfDay(DateTime.fromMillisecondsSinceEpoch(customFromMs!))
                  .millisecondsSinceEpoch,
          customToMs == null
              ? null
              : startOfDay(DateTime.fromMillisecondsSinceEpoch(customToMs!))
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch -
                  1,
        ),
    };
  }

  /// Girdi süzgeçten geçiyor mu? [query] verilirse ada göre de bakılır
  /// (Türkçe-duyarlı, büyük/küçük harf duyarsız).
  ///
  /// [tagsOf] etiket süzgeci kullanılıyorsa **verilmelidir** (ör.
  /// `FileTags.forPath`): etiketler diskteki ayrı bir kayıtta durduğu için bu
  /// saf modelden okunamaz. Verilmezse etiket ölçütü hiçbir dosyayı eşlemez —
  /// sessizce "tümü" saymak, kullanıcı etiketle süzdüğü hâlde her şeyi görmesi
  /// demek olurdu.
  bool matches(
    FsEntry entry, {
    String query = '',
    DateTime? now,
    Set<String> Function(String path)? tagsOf,
  }) {
    final q = turkishFold(query.trim());
    if (q.isNotEmpty && !turkishFold(entry.name).contains(q)) return false;
    if (buckets.isNotEmpty && !buckets.contains(bucketForPath(entry.path))) {
      return false;
    }
    if (chatKinds.isNotEmpty && !chatKinds.contains(chatKindForEntry(entry))) {
      return false;
    }
    if (direction != ChatDirection.any) {
      final sent = isSentByMe(entry.path);
      if (direction == ChatDirection.sent && !sent) return false;
      if (direction == ChatDirection.received && sent) return false;
    }
    if (tags.isNotEmpty) {
      final own = tagsOf?.call(entry.path) ?? const <String>{};
      if (!tags.any(own.contains)) return false;
    }
    if (extensions.isNotEmpty && !extensions.contains(entry.extension)) {
      return false;
    }
    if (!window(now: now).contains(entry.modifiedMs)) return false;
    if (sizeRange != FmSizeRange.any) {
      // Klasörün boyutu 0'dır (özyinelemeli toplam tutulmaz) — boyut ölçütü
      // seçiliyse klasörler elenir, yoksa "100 MB üzeri"nde klasör listelenirdi.
      if (entry.isDir) return false;
      if (entry.sizeBytes < sizeRange.minBytes) return false;
      final max = sizeRange.maxBytes;
      if (max != null && entry.sizeBytes >= max) return false;
    }
    return true;
  }

  /// Listeyi süzer (sıra korunur). [hideDuplicates] açıksa aynı ad+boyuttaki
  /// ikinci ve sonraki kopyalar düşer — **listedeki İLK kopya** kalır, yani
  /// sıralama neyi öne koyduysa o görünür.
  List<FsEntry> apply(
    Iterable<FsEntry> entries, {
    String query = '',
    DateTime? now,
    Set<String> Function(String path)? tagsOf,
  }) {
    final out = <FsEntry>[];
    final seen = hideDuplicates ? <String>{} : null;
    for (final e in entries) {
      if (!matches(e, query: query, now: now, tagsOf: tagsOf)) continue;
      if (seen != null && !seen.add(duplicateKey(e))) continue;
      out.add(e);
    }
    return out;
  }
}

/// Kopya anahtarı: **ad + boyut**. İçerik okunmaz (galeride 20 bin dosyayı
/// açmak dondururdu); WhatsApp/Telegram kopyaları adı ve boyutu birebir
/// koruduğu için bu anahtar pratikte yeterli. Ad karşılaştırması Türkçe
/// katlamalı ve harf duyarsız.
String duplicateKey(FsEntry entry) =>
    '${turkishFold(entry.name)}|${entry.sizeBytes}';

/// Bir listedeki uzantı sayıları (süzgeç sayfasındaki çipler için).
/// Uzantısız dosyalar sayılmaz — süzülecek bir anahtarları yok.
Map<String, int> extensionCounts(Iterable<FsEntry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    final ext = e.extension;
    if (ext.isEmpty) continue;
    counts[ext] = (counts[ext] ?? 0) + 1;
  }
  return counts;
}
