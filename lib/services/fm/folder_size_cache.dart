import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fs_events.dart';
import 'fs_scan.dart';

/// **Listede klasör boyutu** — istek üzerine hesaplanan, bellekte tutulan
/// ölçüler.
///
/// Niye istek üzerine (KALANLAR maddesi, 2026-09-04'te kapandı): bir klasörün
/// boyutu ancak ALTINDAKİ HER ŞEY gezilerek bulunur. Bir listedeki 40 klasörü
/// açılışta ölçmek, diskin o dalını baştan sona okumak demek — ayar
/// varsayılan olarak KAPALI ve açıkken bile yalnız **ekranda görünen**
/// klasörler sıraya giriyor.
///
/// **Eşzamanlılık 2 ile sınırlı:** her ölçüm bir izolatta koşuyor
/// (`FsScan.folderSize`) ve onlarcasını aynı anda başlatmak düşük bellekli
/// telefonu boğar. Sıra, en son istenen klasörden geriye doğru işleniyor:
/// kullanıcı kaydırıyorsa ekranda DURAN klasör, yukarıda kalmış olandan daha
/// önemlidir.
///
/// Ölçüler diske yazılmıyor: klasör boyutu her kopyalama/silmede değişir ve
/// bayat bir sayı göstermek hiç göstermemekten kötüdür. Uygulama açık
/// kaldığı sürece bellekte duruyor, [invalidate] ile düşürülüyor.
abstract final class FolderSizeCache {
  /// Ölçü değiştikçe artan sayaç — listeler bunu dinleyip kendini tazeliyor.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Aynı anda en çok kaç ölçüm koşsun.
  static const maxConcurrent = 2;

  /// Bellekte en çok kaç klasör tutulsun.
  static const maxEntries = 500;

  static final Map<String, int> _sizes = {};
  static final List<String> _order = [];
  static final List<String> _queue = [];
  static final Set<String> _running = {};

  /// Ölçülemeyen yollar (izin yok, kayboldu): bir daha denenmiyor — her
  /// çizimde yeniden kuyruğa girip sonsuz döngü kurmasınlar.
  static final Set<String> _failed = {};

  /// Dosya sistemi değişimlerini dinlemeye başlar (ilk istekte kurulur).
  ///
  /// Kopyalama/silme sonrası ölçüler BAYAT olur; bayat bir boyut göstermek
  /// hiç göstermemekten kötü, o yüzden hepsi düşürülüyor. Yeniden ölçüm
  /// yalnız ekranda görünen klasörler için (kendiliğinden) yapılıyor.
  static bool _listening = false;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    FsEvents.version.addListener(clear);
  }

  /// [path] için bilinen boyut; henüz ölçülmediyse null.
  static int? sizeOf(String path) => _sizes[path];

  /// Bu klasör ölçülmeyi bekliyor mu / ölçülüyor mu?
  static bool isPending(String path) =>
      _queue.contains(path) || _running.contains(path);

  /// Ölçümü ister (zaten biliniyorsa/sırada ise hiçbir şey yapmaz).
  static void request(String path) {
    if (path.isEmpty) return;
    _listen();
    if (_sizes.containsKey(path) || _failed.contains(path)) return;
    if (_queue.contains(path) || _running.contains(path)) return;
    _queue.add(path);
    _pump();
  }

  /// Bir klasörün ölçüsünü düşürür (içine yazıldı/silindi).
  static void invalidate(String path) {
    if (_sizes.remove(path) != null) {
      _order.remove(path);
      revision.value++;
    }
    _failed.remove(path);
  }

  /// Tümünü düşürür (kullanıcı ayarı kapattı, birim çıkarıldı…).
  static void clear() {
    _sizes.clear();
    _order.clear();
    _queue.clear();
    _failed.clear();
    revision.value++;
  }

  static void _pump() {
    while (_running.length < maxConcurrent && _queue.isNotEmpty) {
      // Sondan al: en son istenen (ekranda duran) klasör önce ölçülür.
      final path = _queue.removeLast();
      _running.add(path);
      unawaited(_measure(path));
    }
  }

  static Future<void> _measure(String path) async {
    try {
      final size = await FsScan.folderSize(path);
      _sizes[path] = size;
      _order.add(path);
      if (_order.length > maxEntries) {
        _sizes.remove(_order.removeAt(0));
      }
      revision.value++;
    } catch (_) {
      _failed.add(path);
    } finally {
      _running.remove(path);
      _pump();
    }
  }

  /// Yalnız test.
  static void debugReset() {
    _sizes.clear();
    _order.clear();
    _queue.clear();
    _running.clear();
    _failed.clear();
    revision.value = 0;
  }

  /// Yalnız test: bekleyen ölçüm sayısı.
  static int get pendingCount => _queue.length + _running.length;
}
