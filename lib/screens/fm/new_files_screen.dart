import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/storage_stats.dart';
import 'category_screen.dart';
import '../../widgets/side_menu_view.dart';
import '../../widgets/motion.dart';

/// **Yeni Dosyalar** — telefona en son düşen dosyalar.
///
/// Kullanıcı 2026-08-17: *"yeni dosyaların tüm dosyaları taramasına gerek yok,
/// son 100 dosyayı taraması yeterli; hâlâ çok geç güncelleniyor. Yeni
/// dosyalara basıldığında otomatik güncellenmiş sayfa açılmalı."*
///
/// **Neyi değiştirdi:** bu kutu eskiden `CategoryScreen`i pano önbelleğiyle
/// açıyor, arkasından `MediaLibrary.categoryFiles(null)` ile **tüm depolamayı**
/// (kullanıcının telefonunda 12 010 dosya) listeliyordu. Sonuç: ekran
/// saniyelerce "yükleniyor" kalıyor ve gelen liste dünden kalma indeksten
/// besleniyordu — yani hem yavaş hem bayat.
///
/// **Şimdi:** yalnız sıcak klasörler ([StorageStats.hotFolders])
/// geziliyor ve bellekte **en yeni [limit] dosya** tutuluyor. Tarama izolatta.
/// Ekran her görünür olduğunda ve uygulama arka plandan döndüğünde
/// kendiliğinden tazeleniyor.
///
/// *Niye kırpık liste yeterli:* bu ekranın sorusu "az önce ne geldi?". 12 bin
/// dosyalık tam liste o sorunun cevabı değil, kategori ekranlarının işi. Daha
/// eskiye inmek isteyen Görüntüler/Belgeler/Videolar kutularından eksiksiz
/// listeye ulaşıyor.
class NewFilesScreen extends StatefulWidget {
  /// Sekme görünür mü? (Alt gezinme çubuğunda `IndexedStack` içinde duruyor:
  /// çocuk bir kez kurulup ayakta kalıyor, `initState` yalnız uygulama
  /// açılışında koşuyor. Bu bayrak olmasaydı sekmeye her dönüşte açılıştaki
  /// bayat liste görünürdü.) Ayrı bir ekran olarak açıldığında `true`.
  final bool active;

  const NewFilesScreen({super.key, this.active = true});

  /// Kaç dosya gösterilecek.
  ///
  /// **100 → 300 (2026-08-27):** kullanıcının telefonunda 9243 dosya var ve
  /// yoğun bir günde kameraya + WhatsApp'a düşen kare sayısı üç haneli. 100'lük
  /// pencere o gün öğlen inen bir PDF'i akşam olmadan listeden ATIYORDU —
  /// ekranın sorusu "az önce ne geldi?" olsa da kullanıcının ölçüsü "bugün ne
  /// geldi?". Tarama maliyeti değişmiyor (ağaç yine sonuna kadar geziliyor,
  /// bellekte yalnız en yeni N tutuluyor); artan tek şey listenin uzunluğu.
  static const int limit = 300;

  @override
  State<NewFilesScreen> createState() => _NewFilesScreenState();
}

class _NewFilesScreenState extends State<NewFilesScreen> {
  List<FsEntry>? _files;

  /// Liste **gerçekten değiştiğinde** artan sayaç; `CategoryScreen`in
  /// anahtarına giriyor.
  ///
  /// *Niye gerekli:* `CategoryScreen` kendi listesini `initState`te bir kez
  /// kopyalıyor, sonraki `widget.files` değişimlerini görmüyor. Değişmediğinde
  /// anahtarı SABİT bırakmak da bilinçli: her tazelemede ekranı yeniden kurmak
  /// kaydırma konumunu ve seçimi sıfırlardı.
  int _revision = 0;

  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    FsEvents.returned.addListener(_onReturned);
    _load();
  }

  @override
  void dispose() {
    FsEvents.returned.removeListener(_onReturned);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewFilesScreen old) {
    super.didUpdateWidget(old);
    // Sekmeye geri dönüldü → taze liste.
    if (widget.active && !old.active) _load();
  }

  /// Uygulamaya arkadan dönüldü: WhatsApp'tan / Claude'dan / tarayıcıdan
  /// indirilen dosya burada görünmeli — "kaçmamalı hiçbir şey".
  ///
  /// **20 sn kısıtı kalktı (2026-11-17):** eskiden `resumed`ın her türüne
  /// (izin penceresi, paylaşım sayfası…) karşı 20 sn'de bir tazeleniyordu;
  /// listeyi açıp 20 sn içinde başka uygulamada dosya indirip dönen kullanıcı
  /// onu göremiyordu. [FsEvents.returned] yalnız GERÇEK dönüşte artar, kısıt
  /// gereksiz. Sekme gizliyse tazeleme sekmeye dönüşte yapılır (didUpdateWidget).
  void _onReturned() {
    if (widget.active) unawaited(_load());
  }

  /// Tarama sürerken yeni istek geldi → bitince bir tur daha (yürüyüş
  /// İndirilenler'i çoktan geçmiş olabilir).
  bool _again = false;

  Future<List<FsEntry>> _scan() async {
    await FmEnv.ensureInit();
    // Bütün birimler (SD kart / USB dahil) — bkz. `hotFoldersForAll`.
    final roots = StorageStats.hotFoldersForAll(FmEnv.volumeRoots);
    if (roots.isEmpty) return const [];
    return FsScan.freshFiles(roots, limit: NewFilesScreen.limit);
  }

  Future<void> _load() async {
    if (_scanning) {
      _again = true;
      return;
    }
    _scanning = true;
    try {
      final files = await _scan();
      if (!mounted) return;
      final old = _files;
      // İçerik aynıysa ekranı yeniden kurma (bkz. [_revision]). Eskiden
      // yalnız uzunluk + ilk yol karşılaştırılıyordu: liste 300'de doluyken
      // en yeni OLMAYAN (eski tarihli) bir dosya gelince "aynı" sanılıp
      // ekrana hiç girmiyordu.
      final same = old != null && FsScan.sameListing(old, files);
      setState(() {
        _files = files;
        if (!same) _revision++;
      });
    } finally {
      _scanning = false;
    }
    if (_again && mounted) {
      _again = false;
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    // İlk tarama biterken kısa bir bekleme ekranı: `CategoryScreen`i boş
    // listeyle açıp doldurmak "hiç dosya yok" yanılgısı veriyordu.
    if (files == null) {
      return Scaffold(
        appBar: AppBar(
            leading: const SideMenuButton(),
            title: Text(context.t('fm.new_files'))),
        body: const FmListSkeleton(),
      );
    }
    // Süzme, sıralama, ızgara/liste, çoklu seçim ve toplu işlemler
    // `CategoryScreen`de zaten var — kopyalamak yerine besleniyor.
    // `replaceOnLoad`: aşağı çekince gelen taze liste **yerine geçer**;
    // varsayılan "yalnız daha uzunsa değiştir" burada yanlış olurdu
    // (uzunluk [NewFilesScreen.limit]'te sabit).
    return CategoryScreen(
      key: ValueKey(_revision),
      title: context.t('fm.new_files'),
      files: files,
      loadAll: _scan,
      replaceOnLoad: true,
      memoryId: 'new_files',
    );
  }
}
