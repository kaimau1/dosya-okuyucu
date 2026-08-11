/// **AI analizinin kapsamı** — hangi dosyalara bakılır, hangilerine ASLA.
///
/// KÖK NEDEN (2026-08-10 kullanıcı, planlama turunda): *"kapsama girmeyecek
/// klasörleri ve filtreleri (mesela kamera klasörü) seçilebilmeli, kameram ile
/// çektiğim fotoğraflara erişmesini istemiyorum."*
///
/// Bu yüzden kapsam denetimi sonradan takılan bir süzgeç DEĞİL, indeksin
/// **temeli**: dışlanan klasöre tarayıcı hiç girmez. "Taradık ama göstermedik"
/// ya da "indeksledik ama AI'ya yollamadık" gibi bir ara durum yok — dışlanan
/// yol `ai_index.jsonl` dosyasına da girmez, sohbet bağlamına da.
///
/// ## Üç katmanlı süzgeç
/// 1. **Sabit dışlamalar** ([_hardBlocked]) — kullanıcı isterse bile
///    açılamaz: uygulamanın kendi çöp kutusu, `Android/data`, küçük resim
///    önbellekleri. Bunları analiz etmek anlamsız gürültü üretir.
/// 2. **Kilitli klasörler** — PIN arkasına alınmış klasör (`FolderLock`)
///    otomatik olarak kapsam dışıdır. Kilidi "listede görünmesin" diye koyup
///    içeriğinin AI özetinde çıktığını görmek, kilidi anlamsız kılardı.
/// 3. **Kullanıcı dışlamaları** — ayarlardan seçilen klasörler. Varsayılanda
///    **`DCIM/Camera` kapalı gelir**: kamera fotoğrafları en mahrem yığın ve
///    kullanıcının açık isteği bu yönde. Açmak tek dokunuş, ama karar
///    kullanıcının.
///
/// Ayrıca **buluta ne gider** ayrı bir karardır: [sendText] belgelerin metin
/// özünü, [sendImages] görsellerin kendisini Gemini'ye göndermeyi yönetir.
/// `sendImages` varsayılan **kapalı** — görsel göndermek hem en pahalı hem en
/// mahrem yol.
library;

import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'folder_lock.dart';
import 'fs_scan.dart';

/// Kapsam ayarlarının değişmez (immutable) hâli.
class AiScopeSettings {
  /// Kullanıcının kapsam dışı bıraktığı klasörler (mutlak yollar).
  final List<String> excludedFolders;

  /// İndekse giren dosya türleri.
  final Set<FmCategory> categories;

  /// Bundan büyük dosyanın İÇERİĞİ okunmaz (meta yine indekslenir).
  /// 100 MB'lık bir video/arşivden metin çıkarmaya çalışmak boşuna pil yakar.
  final int maxContentMb;

  /// Gizli dosyalar (`.` ile başlayan) kapsama girsin mi?
  final bool includeHidden;

  /// Belge metninin özü Gemini'ye gönderilsin mi?
  final bool sendText;

  /// Görseller Gemini'ye gönderilsin mi? (Varsayılan: hayır.)
  final bool sendImages;

  /// Buluta giden metin özünün üst sınırı (KB).
  final int excerptKb;

  /// Bir günde AI'ya gönderilebilecek en fazla dosya. **0 = sınırsız.**
  ///
  /// Kullanıcı uyarısı (2026-08-10): *"400 analizden sonra 'bir sonraki gün
  /// devam edin' diyor ama anahtarımda hâlâ kotam var, sınır koymasın."*
  /// Haklı: bütçe, havuz yokken kotayı tek oturumda yakmamak için konmuş bir
  /// korumaydı. Artık `AiPool` kotayı gerçekten ölçüyor (dolan ikili soğumaya
  /// giriyor, sıradakine geçiliyor), yani uygulamanın kendi tahmini sayacı
  /// yalnız gereksiz bir duvar. Varsayılan sınırsız; isteyen ayarlardan sınır
  /// koyabilir.
  final int dailyFileBudget;

  const AiScopeSettings({
    this.excludedFolders = const [],
    this.categories = defaultCategories,
    this.maxContentMb = 40,
    this.includeHidden = false,
    this.sendText = true,
    this.sendImages = false,
    this.excerptKb = 6,
    this.dailyFileBudget = 0,
  });

  /// Varsayılan türler: **belge, görsel, ses, video, arşiv**.
  ///
  /// `apk` ve `other` dışarıda: uygulama kurulum dosyasının "özeti" diye bir
  /// şey yok, `other` ise tanımadığımız her şey (veritabanı parçaları, oyun
  /// verisi) — ikisi de kotayı yer, karşılığında bilgi vermez.
  static const defaultCategories = {
    FmCategory.document,
    FmCategory.image,
    FmCategory.video,
    FmCategory.audio,
    FmCategory.archive,
  };

  /// Tek bir prefs anahtarında saklanır (JSON).
  ///
  /// **Neden alan başına ayrı anahtar değil:** kapsam ayarları birlikte
  /// anlamlı bir bütün — "dışlanan klasörler yazıldı ama türler yazılmadan
  /// uygulama öldü" gibi yarım bir durumda AI, kullanıcının kapattığı
  /// klasörlere bakıyor olabilirdi. Tek yazma = tutarlı kapsam.
  Map<String, Object?> toJson() => {
        'excluded': excludedFolders,
        'categories': [for (final c in categories) c.name],
        'maxContentMb': maxContentMb,
        'hidden': includeHidden,
        'sendText': sendText,
        'sendImages': sendImages,
        'excerptKb': excerptKb,
        'dailyBudget': dailyFileBudget,
      };

  /// Bozuk/eksik alanlarda varsayılana düşer — kaydı okuyamamak yüzünden
  /// kapsamın "her şey açık"a dönmesi kabul edilemez, o yüzden hata hâlinde
  /// **kısıtlayıcı** varsayılan kullanılır.
  static AiScopeSettings fromJson(Map<String, Object?> raw) {
    const fallback = AiScopeSettings();
    final cats = <FmCategory>{};
    final rawCats = raw['categories'];
    if (rawCats is List) {
      for (final name in rawCats) {
        for (final c in FmCategory.values) {
          if (c.name == name) cats.add(c);
        }
      }
    }
    final rawExcluded = raw['excluded'];
    return AiScopeSettings(
      excludedFolders: [
        if (rawExcluded is List)
          for (final path in rawExcluded)
            if (path is String && path.isNotEmpty) path
      ],
      categories: cats.isEmpty ? fallback.categories : cats,
      maxContentMb: (raw['maxContentMb'] as num?)?.toInt() ?? fallback.maxContentMb,
      includeHidden: raw['hidden'] == true,
      sendText: raw['sendText'] != false,
      sendImages: raw['sendImages'] == true,
      excerptKb: (raw['excerptKb'] as num?)?.toInt() ?? fallback.excerptKb,
      dailyFileBudget:
          (raw['dailyBudget'] as num?)?.toInt() ?? fallback.dailyFileBudget,
    );
  }

  AiScopeSettings copyWith({
    List<String>? excludedFolders,
    Set<FmCategory>? categories,
    int? maxContentMb,
    bool? includeHidden,
    bool? sendText,
    bool? sendImages,
    int? excerptKb,
    int? dailyFileBudget,
  }) =>
      AiScopeSettings(
        excludedFolders: excludedFolders ?? this.excludedFolders,
        categories: categories ?? this.categories,
        maxContentMb: maxContentMb ?? this.maxContentMb,
        includeHidden: includeHidden ?? this.includeHidden,
        sendText: sendText ?? this.sendText,
        sendImages: sendImages ?? this.sendImages,
        excerptKb: excerptKb ?? this.excerptKb,
        dailyFileBudget: dailyFileBudget ?? this.dailyFileBudget,
      );
}

/// Kapsam kararlarını veren saf mantık.
///
/// **Saf Dart** (Flutter/prefs importu yok): karar tablosu birim testiyle
/// doğrulanabilsin diye. Kalıcılık [AiScopeStore]'da, arayüz ayarlarda.
class AiScope {
  final AiScopeSettings settings;

  /// PIN'li klasörler — `AppState.fmLockedFolders`'tan gelir.
  final List<String> lockedFolders;

  const AiScope({
    required this.settings,
    this.lockedFolders = const [],
  });

  /// Kullanıcı ne derse desin kapsam dışı kalan yol parçaları.
  ///
  /// `Android/data` ve `Android/obb` zaten okunamaz (SAF ister); denemek
  /// yalnız taramayı yavaşlatır. `.dosya-okuyucu-cop` uygulamanın çöp kutusu:
  /// silinmiş dosyanın AI özetinde dirilmesi hata olurdu.
  static const _hardBlocked = {
    '.dosya-okuyucu-cop',
    '.thumbnails',
    '.trashed',
    'lost+found',
    'cache',
  };

  /// Varsayılan dışlama: birincil depolamadaki kamera klasörü.
  ///
  /// Kullanıcı isteği (2026-08-10). `DCIM/Camera` yoksa (bazı ROM'lar doğrudan
  /// `DCIM` kullanır) her ikisi de listeye girer — var olmayan yol zararsız.
  static List<String> defaultExclusions(String primaryRoot) => [
        p.join(primaryRoot, 'DCIM', 'Camera'),
        p.join(primaryRoot, 'DCIM', '100ANDRO'),
      ];

  /// Taramanın bu klasöre **girip girmeyeceği**.
  ///
  /// Klasör bazında karar vermek kritik: dışlanan bir klasörün altındaki 20
  /// bin dosyayı tek tek eleyip atmak yerine, o dala hiç girilmez.
  bool allowsDir(String dirPath) {
    final name = p.basename(dirPath);
    if (_hardBlocked.contains(name.toLowerCase())) return false;
    if (!settings.includeHidden && name.startsWith('.') && name != '.') {
      return false;
    }
    if (_isInsideAndroidData(dirPath)) return false;
    if (FolderLock.isLocked(dirPath, lockedFolders)) return false;
    for (final excluded in settings.excludedFolders) {
      if (excluded.isEmpty) continue;
      // Dışlanan klasörün KENDİSİ de, altındaki her şey de kapsam dışı.
      if (dirPath == excluded || FsPaths.isInside(excluded, dirPath)) {
        return false;
      }
    }
    return true;
  }

  /// Dosya kapsama giriyor mu? (Klasör kuralları + tür + gizlilik.)
  bool allowsFile(FsEntry entry) {
    if (entry.isDir) return allowsDir(entry.path);
    if (entry.isLink) return false;
    if (!settings.includeHidden && entry.isHidden) return false;
    if (!settings.categories.contains(entry.category)) return false;
    return allowsDir(p.dirname(entry.path));
  }

  /// Dosyanın **içeriği** okunabilir mi? ([allowsFile] doğruysa sorulur.)
  ///
  /// Meta veri (ad/boyut/tarih) her zaman indekslenir; içerik okuma ayrı bir
  /// karardır — büyük dosyada pahalı, bazı türlerde anlamsız.
  bool allowsContent(FsEntry entry) {
    if (!allowsFile(entry)) return false;
    if (entry.sizeBytes > settings.maxContentMb * 1024 * 1024) return false;
    return entry.category == FmCategory.document ||
        entry.category == FmCategory.image;
  }

  /// Bu dosyanın içeriği **buluta** gönderilebilir mi?
  ///
  /// Son kapı: kapsam içi ve içeriği okunabilir olsa bile kullanıcı "metin
  /// gönderme"yi kapatmışsa hiçbir şey çıkmaz; görseller ayrıca kendi
  /// anahtarına bakar.
  bool allowsUpload(FsEntry entry) {
    if (!allowsContent(entry)) return false;
    return switch (entry.category) {
      FmCategory.image => settings.sendImages,
      _ => settings.sendText,
    };
  }

  /// `…/Android/data` ve `…/Android/obb` altında mıyız?
  static bool _isInsideAndroidData(String path) {
    final parts = p.split(path).map((s) => s.toLowerCase()).toList();
    for (var i = 0; i + 1 < parts.length; i++) {
      if (parts[i] == 'android' &&
          (parts[i + 1] == 'data' || parts[i + 1] == 'obb')) {
        return true;
      }
    }
    return false;
  }
}
