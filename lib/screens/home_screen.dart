import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import 'app_links.dart';
import '../core/snack.dart';
import '../models/download_task.dart';
import '../models/fs_entry.dart';
import '../services/fm/app_storage_service.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/incoming_files.dart';
import '../services/fm/media_library.dart';
import '../services/fm/nav_tabs.dart';
import '../widgets/fm/job_progress_bar.dart';
import '../widgets/fm/nav_tabs_sheet.dart';
import '../services/fm/fm_env.dart';
import '../services/fm/home_shortcuts.dart';
import 'fm/ai_hub_screen.dart';
import 'fm/bills_screen.dart';
import 'fm/browser_screen.dart';
import 'fm/category_screen.dart';
import 'fm/dashboard_screen.dart';
import 'fm/download_manager_screen.dart';
import 'fm/downloads_screen.dart';
import 'fm/drive_screen.dart';
import 'fm/important_screen.dart';
import 'fm/installed_apps_screen.dart';
import 'fm/jobs_screen.dart';
import 'fm/new_files_screen.dart';
import 'fm/open_history_screen.dart';
import 'fm/photos_screen.dart';
import 'fm/search_screen.dart';
import 'fm/smart_folders_screen.dart';
import 'fm/trash_screen.dart';
import 'fm/vault_screen.dart';

/// Uygulama kabuğu: alt gezinme çubuğuyla üç bölme —
/// **Dosyalar** (dosya yöneticisi panosu), **İndirilenler**, **Yeni Dosyalar**.
///
/// **2026-09-27:** AI sekmesi alt çubuktan kalktı, yerine İndirilenler geldi
/// (kullanıcı: *"alt alandan AI'yı çıkaralım, İndirilenler kısayolu
/// koyalım"*). AI'nın kapısı artık panonun üst çubuğundaki parıltı simgesi
/// ([AiStatusIcon]) — analiz sürerken halka, bekleyen öneri varken rozet
/// orada; belge ekranlarındaki AI düğmesi zaten her belgede.
///
/// Ortadaki sekme 2026-08-17'ye kadar "Son belgeler"di (uygulamada açılmış
/// belgeler + boş belge oluşturma). Kullanıcı: *"son belgeleri kaldır, yerine
/// yeni dosyaları koy; son belgelere gerek yok"*. Gerekçe tutarlı: bu bir
/// **dosya yöneticisi**, ve "az önce telefona ne düştü?" sorusu "geçen hafta
/// hangi Word'ü açmıştım?"tan çok daha sık soruluyor. Açılmış belgeler
/// kaybolmuyor — panodaki **Son açılanlar** kutusu aynı kaydı gösteriyor.
///
/// **2026-10-18:** sekmeler artık KULLANICININ (bkz. [NavTabs]): Dosyalar
/// sabit ilk sekme, yanına en fazla beş kısayol — Görüntüler, Belgeler, Çöp
/// kutusu, AI… Çubuğa basılı tutmak düzenleme sayfasını açar.
///
/// Kabuk aynı zamanda "birlikte aç"/paylaş ile gelen dosyaları yakalar; bu iş
/// eskiden son-belgeler ekranındaydı, artık hangi sekme açık olursa olsun
/// çalışır.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Yalnız test: "açılış klasörü bir kez açılır" bayrağını sıfırlar.
  @visibleForTesting
  static void debugResetStartFolder() =>
      _HomeScreenState._startFolderOpened = false;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Açık sekmenin KİMLİĞİ (konum değil: kullanıcı çubuğu yeniden dizince
  /// açık sekme yer değiştirmesin).
  String _tab = NavTabs.home;

  /// Kurulmuş sekmeler: bir sekme ilk kez seçilene dek kurulmaz (açılışta
  /// İndirilenler klasörünün tamamını taramasın, galeri yüklenmesin).
  final Set<String> _built = {NavTabs.home};
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  /// Açılışta "başlangıç klasörü" YALNIZ BİR KEZ açılır.
  ///
  /// Alan `static`: `HomeScreen` yeniden kurulabilir (tema/dil değişimi
  /// ağacı yeniden inşa eder) ve her seferinde klasörü yeniden açmak,
  /// kullanıcı geri tuşuyla panoya döndükten sonra onu tekrar içeri
  /// fırlatmak demek olurdu.
  static bool _startFolderOpened = false;

  @override
  void initState() {
    super.initState();
    NavTabs.instance.addListener(_onTabsChanged);
    unawaited(NavTabs.instance.ensureLoaded());
    _initShareIntake();
    // Ana ekran kısayolları: uygulama açıkken dokunulursa itilir, kısayolla
    // AÇILDIYSA yol bir kez sorulur (bkz. HomeShortcuts).
    HomeShortcuts.listen(_openShortcut);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launch = await HomeShortcuts.takeLaunchPath();
      if (launch != null) {
        _startFolderOpened = true; // kısayol açılış klasörünün önüne geçer
        await _openShortcut(launch);
        return;
      }
      await _openStartFolder();
    });
  }

  /// Kısayolun gösterdiği yolu açar: klasörse gezgin, dosyaysa görüntüleyici.
  Future<void> _openShortcut(String path) async {
    if (!mounted) return;
    if (path.startsWith('app:')) {
      await openAppLink(context, path);
      return;
    }
    if (Directory(path).existsSync()) {
      await Navigator.of(context).push(browserRoute(
        BrowserScreen(path: path),
      ));
    } else if (File(path).existsSync()) {
      await EntryOpener.open(context, path);
    } else {
      showSnack(context, context.t('ea.shortcut_missing'));
    }
  }

  /// Ayarlardaki "açılış klasörü" doluysa doğrudan oraya girer.
  ///
  /// Klasör silinmiş/çıkarılmış olabilir (SD kart) — o durumda SESSİZCE pano
  /// gösterilir. Açılışta "klasör bulunamadı" penceresiyle karşılamak, üstelik
  /// kullanıcının çözemeyeceği bir sorun için, kötü bir karşılama olurdu.
  Future<void> _openStartFolder() async {
    if (_startFolderOpened || !mounted) return;
    _startFolderOpened = true;
    final path = context.read<AppState>().fmStartFolder;
    if (path.isEmpty || !Directory(path).existsSync()) return;
    await Navigator.of(context).push(browserRoute(
      BrowserScreen(path: path),
    ));
  }

  /// Açık sekme çubuktan çıkarıldıysa panoya dönülür; kurulmuş ama artık
  /// çubukta olmayan sekmeler bırakılır (bellekte boşuna durmasın).
  void _onTabsChanged() {
    if (!mounted) return;
    final tabs = NavTabs.instance.tabs;
    setState(() {
      if (!tabs.contains(_tab)) _tab = NavTabs.home;
      _built.retainAll(tabs);
      _built.add(NavTabs.home);
    });
  }

  @override
  void dispose() {
    NavTabs.instance.removeListener(_onTabsChanged);
    _intentSub?.cancel();
    super.dispose();
  }

  /// "Birlikte aç" / paylaş ile başka uygulamalardan gelen dosyaları yakalar:
  /// uygulama kapalıyken açıldıysa (initial) ve açıkken paylaşıldıysa (stream).
  void _initShareIntake() {
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _openShared(files);
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _openShared(files);
      },
      onError: (_) {},
    );
  }

  Future<void> _openShared(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final first = files.first;
    final path = first.path;
    if (path.isEmpty) return;

    // Tarayıcıdan gelen bir BAĞLANTI ise dosya değil, indirme isteğidir
    // (kullanıcı isteği 2026-07-29: "Chrome/DuckDuckGo'dan bizim programımızla
    // indirmek istiyorum · indirme kısmında seçenek olarak çıkmalıyız").
    //
    // Tür alanına GÜVENMİYORUZ: paylaşım eklentisi kaynağa göre bu içeriği
    // `text`, `url` ya da `file` diye etiketleyebiliyor ve Android sürümüne
    // göre değişiyor. Karar tek ölçüte bağlı: içerik http(s) adresi mi ve
    // diskte böyle bir dosya YOK mu? Öyleyse indirilecek bir bağlantıdır.
    final url = extractUrl(path);
    if (url != null && !File(path).existsSync()) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DownloadManagerScreen(initialUrl: url),
      ));
      return;
    }
    // Tarayıcıda açılan dosya yalnız özel önbelleğimizde kalıyordu ve
    // kullanıcı onu bir daha bulamıyordu → İndirilenler'e (Yeni Dosyalar'a
    // da düşer) ve oradan açılır. Bkz. [IncomingFiles].
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    // "Kalemle düzenle" (Chrome'un PDF kalem düğmesi) ile gelindiyse belge
    // doğrudan kalem ekranında açılır — bkz. `PdfInkScreen`.
    final edit = await AppStorageService.takeEditRequest();
    final kept = await IncomingFiles.keepIfFromBrowser(path);
    if (!mounted) return;
    if (kept != null && !kept.alreadyThere) {
      showSnackOn(messenger,
          strings.t('dl.from_browser', {'name': p.basename(kept.path)}));
    }
    final target = kept?.path ?? path;
    // `startInk` yalnız PDF yüklenince uygulanır (görüntüleyicinin
    // `onViewerReady`'si) — uzantısız önbellek adında da çalışsın diye
    // burada uzantıya bakılmıyor.
    await EntryOpener.open(context, target, startInk: edit);
  }

  @override
  Widget build(BuildContext context) {
    // **GERİ TUŞU ÖNCE ANA SEKMEYE DÖNER** (kullanıcı 2026-08-29: *"yeni
    // dosyalar / ai sekmelerinde geri yapınca uygulamadan çıkıyor, ana ekrana
    // dönmeli önce"*). Android'de gezinme çubuğu olan uygulamalarda beklenen
    // davranış budur: geri, sekme yığınını çözer, ancak KÖK sekmede uygulamayı
    // kapatır. `canPop` yalnız 0. sekmede true — orada sistem normal çıkışı
    // yapar (yığında başka sayfa varsa Navigator zaten onu açar).
    return PopScope(
      canPop: _tab == NavTabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _tab == NavTabs.home) return;
        setState(() => _tab = NavTabs.home);
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    final tabs = NavTabs.instance.tabs;
    final index = tabs.indexOf(_tab);
    return Scaffold(
      body: IndexedStack(
        index: index < 0 ? 0 : index,
        children: [
          // Anahtar = sekme kimliği: çubuk yeniden dizilince her ekran kendi
          // durumunu (kaydırma, seçim) korur, komşusununkini almaz.
          for (final id in tabs)
            KeyedSubtree(
              key: ValueKey('tab-$id'),
              // **Gizli sekme durur** (Faz 4, P7): `IndexedStack` görünmeyen
              // çocukları ayakta tutar; `TickerMode` olmadan nabız/iskelet
              // animasyonları arka planda kare planlamaya devam ediyordu.
              child: TickerMode(
                enabled: id == tabs[index < 0 ? 0 : index],
                child: _built.contains(id) ? _tabBody(id) : const SizedBox(),
              ),
            ),
        ],
      ),
      // Süren işlerin şeridi gezinme çubuğunun **üstünde**: kullanıcı hangi
      // sekmede olursa olsun "yer aç / boyut düşür / benzer ara" işinin nerede
      // olduğunu görür ve iptal edebilir (istek 2026-07-29: işlemler arka
      // planda çalışabilmeli).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panoda şerit YOK: süren/biten işler panonun en üstündeki akıllı
          // bildirim alanında (2026-10-23, kullanıcı: *"bildirim işlerinin tek
          // alanda toplanması, tek tip olması"*) — aynı iş iki yerde
          // görünmesin. Öteki sekmelerde şerit durur.
          JobProgressBar(
              hidden: (tabs.isEmpty ? NavTabs.home : tabs[index < 0 ? 0 : index]) ==
                  NavTabs.home),
          // Tek sekme kaldıysa çubuk çizilmez (Material en az iki ister) —
          // düzenleme sayfası Ayarlar'dan ve "Ana ekranı düzenle"den açılır.
          if (tabs.length > 1)
            // **Basılı tut = düzenle**: kullanıcı kısayolu çubuğun
            // kendisinde arar.
            ToastAvoider(
              child: GestureDetector(
                onLongPress: () => showNavTabsSheet(context),
                child: NavigationBar(
                  selectedIndex: index < 0 ? 0 : index,
                  // 5-6 sekmede etiketler sıkışıyor: yalnız seçilinin adı
                  // yazılır (Material'ın kendi önerisi).
                  labelBehavior: tabs.length > 4
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (i) => setState(() {
                    _tab = tabs[i];
                    _built.add(_tab);
                  }),
                  destinations: [
                    for (final id in tabs)
                      () {
                        final spec = navTabSpec(context, id);
                        return NavigationDestination(
                          icon: Icon(spec.icon),
                          selectedIcon: Icon(spec.selected),
                          label: spec.label,
                          // Boş ipucu: hedefin kendi ipucu da basılı tutmayı
                          // dinliyor ve çubuğun "basılı tut = düzenle"sini
                          // yutuyordu.
                          tooltip: '',
                        );
                      }(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bir sekmenin ekranı. Kategori sekmeleri panonun önbelleğiyle ANINDA
  /// dolar, eksiksiz liste arka planda gelir (panodaki kutuyla aynı yol).
  Widget _tabBody(String id) {
    switch (id) {
      case NavTabs.home:
        // active: pano yalnız görünürken yeniden tarar (bkz. FsEvents).
        return DashboardScreen(active: _tab == NavTabs.home);
      case 'downloads':
        return _downloadsTab();
      case 'new':
        // active: `IndexedStack` çocuğu ayakta tutar; sekmeye dönünce liste
        // kendini tazelesin (bkz. `NewFilesScreen.active`).
        return NewFilesScreen(active: _tab == 'new');
      case 'image':
      case 'video':
        final category = id == 'image' ? FmCategory.image : FmCategory.video;
        return PhotosScreen(
          title: category.label,
          scopeId: 'depolama-${category.name}',
          files: DashboardScreen.cachedFiles(category),
          loadAll: () => _loadAll(category),
        );
      case 'document':
      case 'audio':
      case 'archive':
      case 'apk':
        final category = switch (id) {
          'document' => FmCategory.document,
          'audio' => FmCategory.audio,
          'archive' => FmCategory.archive,
          _ => FmCategory.apk,
        };
        return CategoryScreen(
          title: id == 'apk' ? context.t('fm.apk_files') : category.label,
          files: DashboardScreen.cachedFiles(category),
          loadAll: () => _loadAll(category),
        );
      case 'important':
        return const ImportantScreen();
      case 'recent':
        return const OpenHistoryScreen();
      case 'search':
        return SearchScreen(rootLabel: context.t('fm.all_files'));
      case 'ai':
        return const AiHubScreen();
      case 'jobs':
        return const JobsScreen();
      case 'smart':
        return const SmartFoldersScreen();
      case 'bills':
        return const BillsScreen();
      case 'vault':
        return const VaultScreen();
      case 'trash':
        return const TrashScreen();
      case 'drive':
        return const DriveScreen();
      case 'apps':
        return const InstalledAppsScreen();
    }
    return const SizedBox();
  }

  Future<List<FsEntry>> _loadAll(FmCategory category) =>
      MediaLibrary.categoryFiles(category,
          lockedFolders: context.read<AppState>().fmLockedFolders);

  /// İndirilenler sekmesi. Klasör yoksa (ilk kurulum, alışılmadık cihaz)
  /// kullanıcı boş bir ekranla değil açıklamayla karşılanır.
  Widget _downloadsTab() {
    final path = downloadsPathIn(FmEnv.primaryRoot);
    if (path == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t('fm.downloads'))),
        body: Center(child: Text(context.t('fm.downloads_missing'))),
      );
    }
    return DownloadsScreen(key: ValueKey(path), path: path);
  }
}
