import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../models/fs_entry.dart';
import '../media_library.dart';

/// FTP kökündeki bir girdinin türü.
enum FtpNodeKind {
  /// Sanal kök (`/`) — aşağıdaki kutuların listesi.
  root,

  /// Gerçek bir klasör/dosya (kökün altındaki her şey böyle çözülür).
  real,

  /// Sanal kategori klasörü: içindekiler telefonun her yerinden toplanır.
  category,

  /// Sanal kategori klasörünün İÇİNDEKİ bir dosya (gerçek yolu ayrı).
  categoryFile,
}

/// Çözümlenmiş bir FTP yolu.
class FtpNode {
  final FtpNodeKind kind;

  /// [FtpNodeKind.real] için gerçek kökE GÖRE yol (`DCIM/a.jpg`).
  ///
  /// Mutlak yol değil, çünkü kök hapsini tek bir yer yapıyor:
  /// [FtpServer.resolve]. Sanal katman "hangi klasörün altındayız"ı çözer,
  /// "kökün dışına çıkılmıyor mu"yu yine sunucu doğrular.
  final String? relative;

  /// [FtpNodeKind.categoryFile] için gerçek disk yolu (kutudaki dosya
  /// telefonun herhangi bir yerinde olabilir; kökün içindedir).
  final String? realPath;

  /// [FtpNodeKind.category] / [FtpNodeKind.categoryFile] için kutu adı.
  final String? category;

  const FtpNode(this.kind, {this.relative, this.realPath, this.category});

  /// Yol yok. ([FtpNodeKind.real] + yolsuz = "çözülemedi".)
  static const notFound = FtpNode(FtpNodeKind.real);
}

/// FTP kökünde gösterilecek kutu.
class FtpRootItem {
  final String name;

  /// Doluysa kutu gerçek bir klasördür (İndirilenler, Kamera…); boşsa
  /// [category] ile toplanan sanal bir kutudur.
  final String? realPath;

  final FmCategory? category;

  const FtpRootItem(this.name, {this.realPath, this.category});
}

/// **PC'de telefondaki kategorilerin aynısını gösteren sanal ağaç.**
///
/// Kullanıcı isteği (2026-08-29): *"bilgisayarda açınca da telefondaki
/// dosyaları telefondaki gibi Belgeler, Görüntüler, Videolar, İndirilenler vs
/// şeklinde aynı kategorizasyonda görelim, bulması kolay olsun."*
///
/// ## Niye gerekliydi
/// FTP kökü doğrudan `/storage/emulated/0` idi: PC'de `Android`, `.thumbnails`,
/// `MIUI`, `com.whatsapp` gibi 40 küsur klasör görünüyor, aradığı faturayı ya
/// da videoyu bulmak için kullanıcının Android'in klasör düzenini bilmesi
/// gerekiyordu. Telefonda ise aynı dosyalar panoda kutulara ayrılmış duruyor.
///
/// ## Kök artık SEÇİLMİŞ kutulardan ibaret
/// ```
/// /Telefon/          → gerçek kök (her şey burada, hiçbir şey kaybolmuyor)
/// /Indirilenler/     → gerçek Download klasörü
/// /Kamera/           → gerçek DCIM klasörü
/// /Resimler/         → SANAL: telefonun her yerindeki fotoğraflar
/// /Videolar/ /Ses/ /Belgeler/ /Arsivler/ /Uygulamalar/
/// ```
/// Kökte gerçek klasörler LİSTELENMEZ; hepsi "Telefon Belleği"nin altında.
/// Bunun bir yan faydası da ad çakışmasının imkânsız olması: kökteki adları
/// tamamen biz belirlediğimiz için "Belgeler" adlı gerçek bir klasör sanal
/// kutuyu gölgeleyemiyor.
///
/// ## Sanal kutuların içi
/// [MediaLibrary.categoryFiles] ile toplanır (arama dizini hazırsa diske hiç
/// inilmez). Liste **düz**dür — telefondaki kategori ekranının aynısı.
/// Aynı adlı iki dosya varsa ikincisine ` (2)` eklenir: FTP'de bir klasörde
/// iki kez aynı ad olamaz, olsaydı istemci birini sessizce yutardı.
class FtpTree {
  /// Gerçek kök (`/storage/emulated/0`).
  final String realRoot;

  /// Kilitli klasörler listeye HİÇ girmez: kilitli klasördeki fotoğraf PC'de
  /// "Görüntüler" kutusunda görünseydi kilit hiçbir işe yaramazdı.
  final List<String> lockedFolders;

  /// Nokta ile başlayan dosyalar da toplansın mı.
  final bool showHidden;

  /// Kutu içeriğini toplayan işlev. Üretimde [MediaLibrary.categoryFiles];
  /// testlerde sahte bir liste verilebilsin diye dışarıdan alınıyor (gerçek
  /// toplayıcı arama dizinine ve tüm diski taramaya bağlı).
  final Future<List<FsEntry>> Function(FmCategory category)? collect;

  FtpTree({
    required this.realRoot,
    this.lockedFolders = const [],
    this.showHidden = false,
    this.collect,
  });

  // ── Kutu adları neden AKSANSIZ ────────────────────────────────────────────
  //
  // Adlar bilerek ASCII: `Görüntüler` değil `Resimler`, `Arşivler` değil
  // `Arsivler`, `Telefon Belleği` değil `Telefon`.
  //
  // Sebep KOZMETİK DEĞİL: FTP'de ad kodlaması istemciye bağlı. Sunucu UTF-8
  // gönderiyor (FEAT'te `UTF8` duyuruluyor) ama Windows Gezgini gibi eski
  // istemciler adları yerel kod sayfasıyla çözüyor. O zaman kullanıcı
  // "ArÅivler" görür ve — asıl kötüsü — o bozuk adla `CWD` gönderdiğinde
  // hiçbir kutumuzla eşleşmez: klasör AÇILMAZ. Testteki `ftpconnect`
  // istemcisi de tam bu şekilde davranıyor (latin-1 çözüyor), yani bu
  // varsayımsal bir risk değil, ölçülmüş bir davranış.
  //
  // Aksansız yazılmış Türkçe okunur; bozuk kodlanmış Türkçe okunmaz ve
  // çalışmaz. Kutu adları bu yüzden ASCII.

  /// Gerçek kökün adı. Kullanıcı bunun altında telefonun tamamını gezer.
  static const storageFolder = 'Telefon';

  /// Sanal kutular — telefonun panosundaki sırayla.
  static const categoryFolders = <String, FmCategory>{
    'Resimler': FmCategory.image,
    'Videolar': FmCategory.video,
    'Ses': FmCategory.audio,
    'Belgeler': FmCategory.document,
    'Arsivler': FmCategory.archive,
    'Uygulamalar': FmCategory.apk,
  };

  /// Gerçek klasöre giden kutular: klasör adı adayları (cihaza göre değişir).
  static const _realFolders = <String, List<String>>{
    'Indirilenler': ['Download', 'Downloads', 'İndirilenler'],
    'Kamera': ['DCIM'],
  };

  /// Kökte gösterilecek kutular. Gerçek klasörü olmayan (cihazda bulunmayan)
  /// kutu listelenmez — açılmayan bir klasör göstermek kullanıcıyı yanıltır.
  List<FtpRootItem> rootItems() {
    final items = <FtpRootItem>[
      FtpRootItem(storageFolder, realPath: realRoot),
    ];
    for (final entry in _realFolders.entries) {
      final path = _firstExisting(entry.value);
      if (path != null) items.add(FtpRootItem(entry.key, realPath: path));
    }
    for (final entry in categoryFolders.entries) {
      items.add(FtpRootItem(entry.key, category: entry.value));
    }
    return items;
  }

  String? _firstExisting(List<String> candidates) {
    for (final name in candidates) {
      final path = p.normalize(p.join(realRoot, name));
      if (Directory(path).existsSync()) return path;
    }
    return null;
  }

  /// Sanal yolu ([FtpServer.normalizeVirtual] çıktısı: `/`, `/Belgeler`,
  /// `/Telefon Belleği/DCIM/a.jpg`…) çözer.
  ///
  /// Gerçek klasörlere çıkan sonuç [FtpNode.relative] taşır; kökün dışına
  /// çıkılmadığını sunucu doğrular (kök hapsi tek yerde: `FtpServer.resolve`).
  Future<FtpNode> resolve(String virtualPath) async {
    final segments = virtualPath
        .split('/')
        .where((s) => s.isNotEmpty && s != '.')
        .toList();
    if (segments.isEmpty) return const FtpNode(FtpNodeKind.root);

    final head = segments.first;
    final rest = segments.skip(1).toList();

    final category = categoryFolders[head];
    if (category != null) {
      if (rest.isEmpty) {
        return FtpNode(FtpNodeKind.category, category: head);
      }
      // Kategori kutusu DÜZ: altında klasör yok, yalnız dosya adı olabilir.
      if (rest.length > 1) return FtpNode.notFound;
      final files = await categoryEntries(head);
      final match = files[rest.first];
      if (match == null) return FtpNode.notFound;
      return FtpNode(FtpNodeKind.categoryFile,
          realPath: match.path, category: head);
    }

    FtpRootItem? root;
    for (final item in rootItems()) {
      if (item.name == head) root = item;
    }
    final base = root?.realPath;
    if (base == null) return FtpNode.notFound;
    // Köke göre yol: kutunun kendi klasörü + istenen alt yol.
    final baseRelative = p.equals(base, realRoot)
        ? ''
        : p.relative(base, from: realRoot).replaceAll(r'\', '/');
    final relative = [
      if (baseRelative.isNotEmpty) ...baseRelative.split('/'),
      ...rest,
    ].join('/');
    return FtpNode(FtpNodeKind.real, relative: relative);
  }

  // ── kategori içerikleri ───────────────────────────────────────────────────

  final Map<String, Map<String, FsEntry>> _cache = {};
  final Map<String, DateTime> _cachedAt = {};
  final Map<String, Future<Map<String, FsEntry>>> _inFlight = {};

  /// Tazeleme aralığı. PC'de bir klasörü açmak arka arkaya birkaç komut
  /// gönderiyor (LIST, sonra her dosya için SIZE/MDTM); her birinde yeniden
  /// taramak 4 bin fotoğraflık bir kutuyu kullanılamaz yapardı.
  static const cacheTtl = Duration(seconds: 30);

  /// Kutunun içeriği: `dosya adı → girdi`.
  Future<Map<String, FsEntry>> categoryEntries(String folder) {
    final at = _cachedAt[folder];
    final cached = _cache[folder];
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < cacheTtl) {
      return Future.value(cached);
    }
    // Aynı anda gelen ikinci istek aynı taramayı beklesin: PC bir klasörü
    // açarken paralel komut gönderebiliyor.
    return _inFlight[folder] ??= _collect(folder).whenComplete(() {
      _inFlight.remove(folder);
    });
  }

  Future<Map<String, FsEntry>> _collect(String folder) async {
    final category = categoryFolders[folder];
    if (category == null) return const {};
    final files = await (collect?.call(category) ??
        MediaLibrary.categoryFiles(category, lockedFolders: lockedFolders));
    final map = <String, FsEntry>{};
    for (final entry in files) {
      if (!showHidden && p.basename(entry.path).startsWith('.')) continue;
      map[uniqueName(map.containsKey, entry.name)] = entry;
    }
    _cache[folder] = map;
    _cachedAt[folder] = DateTime.now();
    return map;
  }

  /// Çakışan adı benzersizleştirir: `fatura.pdf` → `fatura (2).pdf`.
  ///
  /// FTP'de bir klasörde iki kez aynı ad olamaz; olsaydı istemci ikisinden
  /// birini sessizce yutar ve kullanıcı "dosyam yok" derdi. Uzantıdan ÖNCE
  /// numaralandırılır ki dosya PC'de yine doğru programla açılsın.
  static String uniqueName(bool Function(String) taken, String name) {
    if (!taken(name)) return name;
    final ext = p.extension(name);
    final stem = name.substring(0, name.length - ext.length);
    for (var i = 2;; i++) {
      final candidate = '$stem ($i)$ext';
      if (!taken(candidate)) return candidate;
    }
  }

  /// Kutu içeriği değişmiş olabilir (PC'den dosya silindi) → önbelleği düşür.
  void invalidate() {
    _cache.clear();
    _cachedAt.clear();
  }
}
