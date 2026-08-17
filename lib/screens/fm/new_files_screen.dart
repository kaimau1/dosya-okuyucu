import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/storage_stats.dart';
import 'category_screen.dart';

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
/// **Şimdi:** yalnız sıcak klasörler ([StorageStats.standardFolders])
/// geziliyor ve bellekte **en yeni [limit] dosya** tutuluyor. Tarama izolatta.
/// Ekran her görünür olduğunda ve uygulama arka plandan döndüğünde
/// kendiliğinden tazeleniyor.
///
/// *Niye 100 yeterli:* bu ekranın sorusu "az önce ne geldi?". 12 bin dosyalık
/// tam liste o sorunun cevabı değil, kategori ekranlarının işi. Daha eskiye
/// inmek isteyen Görüntüler/Belgeler/Videolar kutularından eksiksiz listeye
/// ulaşıyor.
class NewFilesScreen extends StatefulWidget {
  /// Sekme görünür mü? (Alt gezinme çubuğunda `IndexedStack` içinde duruyor:
  /// çocuk bir kez kurulup ayakta kalıyor, `initState` yalnız uygulama
  /// açılışında koşuyor. Bu bayrak olmasaydı sekmeye her dönüşte açılıştaki
  /// bayat liste görünürdü.) Ayrı bir ekran olarak açıldığında `true`.
  final bool active;

  const NewFilesScreen({super.key, this.active = true});

  /// Kaç dosya gösterilecek.
  static const int limit = 100;

  @override
  State<NewFilesScreen> createState() => _NewFilesScreenState();
}

class _NewFilesScreenState extends State<NewFilesScreen>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewFilesScreen old) {
    super.didUpdateWidget(old);
    // Sekmeye geri dönüldü → taze liste.
    if (widget.active && !old.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WhatsApp'tan belge indirip uygulamaya dönen kullanıcı onu burada
    // görmeli — "kaçmamalı hiçbir şey".
    if (state == AppLifecycleState.resumed && widget.active) unawaited(_load());
  }

  Future<List<FsEntry>> _scan() async {
    await FmEnv.ensureInit();
    final roots = [
      for (final f in StorageStats.standardFolders(FmEnv.primaryRoot)) f.path,
    ];
    if (roots.isEmpty) return const [];
    return FsScan.freshFiles(roots, limit: NewFilesScreen.limit);
  }

  Future<void> _load() async {
    if (_scanning) return;
    _scanning = true;
    try {
      final files = await _scan();
      if (!mounted) return;
      final old = _files;
      // İçerik aynıysa ekranı yeniden kurma (bkz. [_revision]).
      final same = old != null &&
          old.length == files.length &&
          (files.isEmpty || old.first.path == files.first.path);
      setState(() {
        _files = files;
        if (!same) _revision++;
      });
    } finally {
      _scanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    // İlk tarama biterken kısa bir bekleme ekranı: `CategoryScreen`i boş
    // listeyle açıp doldurmak "hiç dosya yok" yanılgısı veriyordu.
    if (files == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t('fm.new_files'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Süzme, sıralama, ızgara/liste, çoklu seçim ve toplu işlemler
    // `CategoryScreen`de zaten var — kopyalamak yerine besleniyor.
    // `replaceOnLoad`: aşağı çekince gelen taze liste **yerine geçer**;
    // varsayılan "yalnız daha uzunsa değiştir" burada yanlış olurdu
    // (uzunluk hep 100'de sabit).
    return CategoryScreen(
      key: ValueKey(_revision),
      title: context.t('fm.new_files'),
      files: files,
      loadAll: _scan,
      replaceOnLoad: true,
    );
  }
}
