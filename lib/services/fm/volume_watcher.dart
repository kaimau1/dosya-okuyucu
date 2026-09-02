import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_storage_service.dart';
import 'fm_env.dart';
import 'storage_stats.dart';

/// Android'in BİLDİĞİ ama gezilemeyen bir harici birim.
///
/// Kullanıcıya "Takılı değil" demek yanlış olurdu: bellek takılı, yalnız
/// Android onu dosya yolu olarak vermiyor. [key] (UUID ya da yol) klasör
/// seçicisini doğrudan o birimin üstünde açmak için kullanılır —
/// `AppStorageService.safPickTree(volume: key)`.
class UnusableVolume {
  /// Kullanıcıya gösterilecek ad ("Kingston USB sürücüsü").
  final String name;

  /// Klasör seçiciyi konumlandıran anahtar: birimin UUID'si ya da yolu.
  final String key;

  const UnusableVolume({required this.name, required this.key});
}

/// Takılan/çıkarılan bir birim.
class VolumeChange {
  /// Yeni takılan birimler (USB bellek, SD kart).
  final List<StorageVolume> attached;

  /// Çıkarılan birimlerin yolları.
  final List<String> detached;

  const VolumeChange({this.attached = const [], this.detached = const []});

  bool get isEmpty => attached.isEmpty && detached.isEmpty;
}

/// **Harici bellek takıldığında haberdar olmak** — kullanıcı isteği
/// 2026-09-01: *"harici USB taktığımda göremiyorum onu uygulamamızda
/// görebilmeliyiz, otomatik tanımalı."*
///
/// Kök neden: birim listesi (`FmEnv.volumes`) uygulama açılışında BİR KEZ
/// kuruluyordu. Uygulama açıkken takılan bir USB belleği hiçbir ekran
/// görmüyordu; kullanıcı uygulamayı kapatıp açmak zorundaydı.
///
/// **Karar — yeni eklenti YOK, `/storage` izleniyor:** Android'in
/// `ACTION_MEDIA_MOUNTED` yayınını dinlemek bir platform kanalı + BroadcastR
/// eceiver ister; CI `android/` iskeletini her derlemede yeniden ürettiği için
/// oraya eklenen her parça bakım borcudur (bkz. HAFIZA). Bağlama noktaları
/// `/storage` altında birer KLASÖR olarak belirip kaybolduğu için
/// `Directory.watch` çoğu cihazda olayı doğrudan veriyor; vermeyen ROM'lar
/// için ayrıca düşük sıklıklı bir yoklama var (varsayılan 5 sn — bir dizin
/// listelemesi, ölçülebilir pil maliyeti yok).
///
/// Uygulama arka plandayken izleme DURDURULUR ([stop]); öne gelince
/// [start] yeniden kurar ve aradaki değişimi ilk taramada yakalar.
class VolumeWatcher {
  /// Yoklama sıklığı. `watch` çalışmayan ROM'larda tek güvence bu.
  final Duration pollInterval;

  /// Değişim akışı — dinleyen ekranlar birim listesini tazeler.
  Stream<VolumeChange> get changes => _controller.stream;

  final _controller = StreamController<VolumeChange>.broadcast();
  final _subscriptions = <StreamSubscription<FileSystemEvent>>[];
  Timer? _timer;
  Set<String> _known = const {};

  /// Son görülen bağlama noktası adları — ucuz yoklamanın karşılaştırma
  /// tabanı (bkz. [mountNames]).
  Set<String>? _mountNames;
  var _scanning = false;

  VolumeWatcher({this.pollInterval = const Duration(seconds: 5)});

  /// Şu an bilinen birim yolları (test ve ilk kurulum için).
  Set<String> get knownPaths => _known;

  /// İzlemeyi başlatır. Birden çok kez çağrılabilir (ikincisi yok sayılır).
  void start() {
    if (_timer != null) return;
    _known = {for (final v in FmEnv.volumes) v.path};

    for (final root in StorageStats.removableRoots) {
      // `existsSync()` okunamayan bir kökte FIRLATIR (bkz.
      // `StorageStats.entriesOf`) — bu yüzden varlık denetimi de try içinde.
      try {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        _subscriptions.add(dir.watch().listen(
              (_) => unawaited(_poll()),
              onError: (_) {},
              cancelOnError: false,
            ));
      } catch (_) {
        // Bu kök izlenemiyor (yok ya da izin yok) — yoklama yine çalışıyor.
      }
    }

    _mountNames ??= mountNames();
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  /// İzlemeyi durdurur (uygulama arka plana alındığında).
  void stop() {
    _timer?.cancel();
    _timer = null;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }

  /// **Ucuz yoklama:** bağlama noktalarının adları değişti mi?
  ///
  /// Niye ayrı: tam tarama birim başına `df` çalıştırıyor (süreç başlatmak).
  /// Beş saniyede bir süreç açmak ölçülebilir bir pil maliyetidir; oysa
  /// takılan bir bellek `/storage` altında bir KLASÖR olarak beliriyor ve onu
  /// görmek tek `listSync`. Pahalı tarama yalnız bu ad kümesi değişince
  /// koşuyor.
  /// [roots] yalnız test içindir; üretimde
  /// [StorageStats.removableRoots] gezilir.
  static Set<String> mountNames({List<String>? roots}) {
    final out = <String>{};
    for (final root in roots ?? StorageStats.removableRoots) {
      // Okunamayan kök (izin yok) burada boş liste döner ve FIRLATMAZ —
      // varlık denetimi de o korumanın içinde (bkz. `StorageStats.entriesOf`).
      for (final entity in StorageStats.entriesOf(root)) {
        final name = p.basename(entity.path);
        if (name == 'self' || name == 'container') continue;
        out.add('$root/$name');
      }
    }
    return out;
  }

  /// Ucuz yoklama: ad kümesi değişmediyse hiçbir şey yapma.
  Future<void> _poll() async {
    final names = mountNames();
    if (_mountNames != null && _setEquals(_mountNames!, names)) return;
    _mountNames = names;
    await rescan();
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  /// Birimleri yeniden tarar; değişiklik varsa [changes] akışına yazar.
  ///
  /// Üst üste çağrılara karşı korumalı: bir tarama sürerken gelen ikinci
  /// çağrı sessizce düşer (izleme olayları demet hâlinde gelir).
  Future<VolumeChange> rescan() async {
    if (_scanning) return const VolumeChange();
    _scanning = true;
    try {
      _mountNames = mountNames();
      await FmEnv.ensureInit(force: true);
      final now = {for (final v in FmEnv.volumes) v.path};
      final change = VolumeChange(
        attached: [
          for (final v in FmEnv.volumes)
            if (!_known.contains(v.path)) v,
        ],
        detached: [
          for (final path in _known)
            if (!now.contains(path)) path,
        ],
      );
      _known = now;
      if (!change.isEmpty && !_controller.isClosed) _controller.add(change);
      return change;
    } catch (_) {
      return const VolumeChange();
    } finally {
      _scanning = false;
    }
  }

  /// Bir dosya için "harici belleğe kopyala" hedefleri.
  ///
  /// Yalnız YAZILABİLİR takılabilir birimler döner: salt okunur bağlanmış bir
  /// USB'yi hedef olarak sunmak kullanıcıyı boşuna uğraştırırdı.
  static List<StorageVolume> copyTargets() => [
        for (final v in FmEnv.volumes)
          if (v.isRemovable && v.isWritable) v,
      ];

  /// Android bir harici birim BİLİYOR ama kullanılamıyor mu?
  ///
  /// Kullanıcı hatası 2026-09-02: bellek takılıyken uygulama "Takılı harici
  /// bellek yok" diyordu. İki ayrı durum var ve kullanıcıya aynı cümleyi
  /// söylemek yanlış:
  /// * gerçekten hiçbir şey takılı değil → "takıp yeniden deneyin";
  /// * takılı ama bağlanmamış / yolu verilmemiş → bu yanlışı söylemek
  ///   kullanıcıyı "bozuk" hissine sokuyor. Sebebi söylemek gerekiyor.
  ///
  /// Bulunan birimi döner; öyle bir birim yoksa null.
  ///
  /// "Kullanılamıyor" ölçütü artık `state` DEĞİL, gezilebilirlik: durumu
  /// `unknown` çıkan bağlı bir USB de listeleniyorsa sorun yoktur (bkz.
  /// `StorageStats.volumes`). Dönen [UnusableVolume.key] klasör seçicisini
  /// doğrudan o birimin üstünde açmaya yarar.
  static Future<UnusableVolume?> attachedButUnusable() async {
    for (final pv in await AppStorageService.storageVolumes()) {
      if (pv.isPrimary || !pv.isRemovable) continue;
      final path = pv.path;
      if (path != null && path.isNotEmpty && StorageStats.canList(path)) {
        continue; // gezilebiliyor → sorun yok
      }
      final described = pv.description.trim();
      final uuid = pv.uuid ?? '';
      return UnusableVolume(
        name: described.isEmpty ? (uuid.isEmpty ? '?' : uuid) : described,
        key: uuid.isNotEmpty ? uuid : (path ?? ''),
      );
    }
    // `StorageManager` susuyor olabilir; bağlama tablosunda görünen ama
    // gezilemeyen bir birim de aynı durumdur (izin/bağlama sorunu).
    for (final point in StorageStats.removableMountPoints(
        StorageStats.readMounts())) {
      if (StorageStats.canList(point)) continue;
      return UnusableVolume(name: p.basename(point), key: point);
    }
    return null;
  }

  /// Kopyalanacak dosyanın harici bellekteki hedef klasörü.
  ///
  /// Kök yerine `Dosya Okuyucu` altı: bir USB belleğin köküne dosya
  /// serpiştirmek kullanıcının kendi düzenini bozar; hepsi tek klasörde
  /// olunca sonradan bulunması da kolay.
  static String targetFolder(StorageVolume volume) =>
      p.join(volume.path, 'Dosya Okuyucu');
}
