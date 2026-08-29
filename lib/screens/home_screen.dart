import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../models/download_task.dart';
import '../services/fm/ai_analyzer.dart';
import '../services/fm/ai_index.dart';
import '../services/fm/entry_opener.dart';
import '../widgets/fm/job_progress_bar.dart';
import 'chat_screen.dart';
import 'fm/browser_screen.dart';
import 'fm/dashboard_screen.dart';
import 'fm/download_manager_screen.dart';
import 'fm/new_files_screen.dart';

/// Uygulama kabuğu: alt gezinme çubuğuyla üç bölme —
/// **Dosyalar** (dosya yöneticisi panosu), **Yeni Dosyalar**, **AI**.
///
/// Ortadaki sekme 2026-08-17'ye kadar "Son belgeler"di (uygulamada açılmış
/// belgeler + boş belge oluşturma). Kullanıcı: *"son belgeleri kaldır, yerine
/// yeni dosyaları koy; son belgelere gerek yok"*. Gerekçe tutarlı: bu bir
/// **dosya yöneticisi**, ve "az önce telefona ne düştü?" sorusu "geçen hafta
/// hangi Word'ü açmıştım?"tan çok daha sık soruluyor. Açılmış belgeler
/// kaybolmuyor — panodaki **Son açılanlar** kutusu aynı kaydı gösteriyor.
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
  int _tab = 0;
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
    _initShareIntake();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openStartFolder());
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowserScreen(path: path),
    ));
  }


  @override
  void dispose() {
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
    await EntryOpener.open(context, path);
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
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _tab == 0) return;
        setState(() => _tab = 0);
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          // active: pano yalnız görünürken yeniden tarar (bkz. FsEvents).
          DashboardScreen(active: _tab == 0),
          // active: `IndexedStack` çocuğu ayakta tutar; sekmeye dönünce liste
          // kendini tazelesin (bkz. `NewFilesScreen.active`).
          NewFilesScreen(active: _tab == 1),
          const ChatScreen(),
        ],
      ),
      // Süren işlerin şeridi gezinme çubuğunun **üstünde**: kullanıcı hangi
      // sekmede olursa olsun "yer aç / boyut düşür / benzer ara" işinin nerede
      // olduğunu görür ve iptal edebilir (istek 2026-07-29: işlemler arka
      // planda çalışabilmeli).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JobProgressBar(),
          NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: context.t('home.tab_files'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.move_to_inbox_outlined),
            selectedIcon: const Icon(Icons.move_to_inbox),
            label: context.t('fm.new_files'),
          ),
          // **AI sekmesi durumu taşır** (kullanıcı 2026-08-17: *"ai asistan
          // yazısı sağ alttaki ai düğmesi alanına entegre et, ana ekran
          // temizlensin"*). Panodaki tam genişlikli AI kartı kalktı; analiz
          // sürerken sekmede ilerleme halkası, bekleyen öneri varsa sayı
          // rozeti çıkıyor. Bilgi aynı, kapladığı yer sıfır.
          NavigationDestination(
            icon: const _AiTabIcon(selected: false),
            selectedIcon: const _AiTabIcon(selected: true),
            label: context.t('home.tab_ai'),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

/// AI sekmesinin simgesi — **canlı durum taşır**.
///
/// Panodaki AI kartının yerini aldı (2026-08-17). Üç hâl:
/// * analiz sürüyorsa simgenin çevresinde ince bir ilerleme halkası,
/// * bekleyen öneri varsa sayı rozeti,
/// * ikisi de yoksa düz simge (gürültü yok).
class _AiTabIcon extends StatelessWidget {
  final bool selected;
  const _AiTabIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? Icons.smart_toy : Icons.smart_toy_outlined);
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) => ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, __) {
          final pending = AiIndex.suggestionCount;
          if (progress.isBusy) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.total == 0 ? null : progress.fraction,
                  ),
                ),
                icon,
              ],
            );
          }
          if (pending <= 0) return icon;
          return Badge(
            label: Text('$pending'),
            child: icon,
          );
        },
      ),
    );
  }
}
