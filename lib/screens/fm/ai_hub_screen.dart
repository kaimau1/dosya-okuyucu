/// **AI Merkezi** — tüm dosya analizinin tek ekranı.
///
/// 2026-11-07 baştan yazıldı (kullanıcı: *"AI analiz kısmı düzgün çalışmıyor,
/// silinenler hâlâ gösteriliyor, kendi kendine önemli dosyalara taşıma
/// yapıyor, ne yapıyor hiç anlaşılmıyor"*). Kök nedenler ve kararlar:
///
/// - **Hayalet kayıtlar:** indeks yalnız bu ekranın kendi silme düğmesinden
///   sonra temizleniyordu. Artık açılışta, dosya sistemi her değiştiğinde
///   ([FsEvents]) ve her analiz bitince `AiIndex.pruneMissing` koşar; satıra
///   dokununca dosya yoksa kayıt düşer.
/// - **"Kendi kendine taşıma":** öneriler eskiden `Önemli Dosyalar/<klasör>`'e
///   taşıyordu ve yerel kural her belgeye klasör yazıyordu. Artık klasör
///   önerisi yalnız AI'dan, hedef `Documents/<klasör>`, iş yalnız ne olacağını
///   sayılarla gösteren onay levhasından başlar.
/// - **Anlaşılırlık:** her sekmenin üstünde tek satırlık "bu ne" açıklaması;
///   otomatik başlayan analiz "Otomatik" diye etiketlenir ve kapatma anahtarı
///   Analiz sekmesinde durur; başlıktaki dört anlamsız simge tek, yazılı bir
///   menüye indi.
///
/// Sekmeler: **Analiz** (durum + başlat) · **Sohbet** (dosyalara soru) ·
/// **Türler** (AI'nın verdiği tür/önem görünümü — dosyalar yerinde durur) ·
/// **Öneriler** (ad/klasör, yalnız onayla) · **Rapor** (özet + temizlik).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_apply.dart';
import '../../services/fm/ai_apply_log.dart';
import '../../services/fm/ai_ask.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_folders.dart';
import '../../services/gemini_service.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/ai_file_list.dart';
import '../../widgets/fm/ai_preview_card.dart';
import '../settings_screen.dart';
import '../settings/tiles_ai_scope.dart' show AiAutoNewTile;
import '../chat_screen.dart';
import 'ai_files_screen.dart';
import 'bills_screen.dart';
import 'smart_folders_screen.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';
import '../../widgets/ai_key_gate.dart';

part 'ai_hub/analysis.dart';
part 'ai_hub/chat.dart';
part 'ai_hub/tabs.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  Timer? _pruneDebounce;

  @override
  void initState() {
    super.initState();
    // Açılışta bayat kayıtları düşür: dosya başka uygulamada silinmiş olabilir.
    unawaited(AiIndex.ensureLoaded().then((_) => AiIndex.pruneMissing()));
    FsEvents.version.addListener(_onFsChanged);
  }

  /// Dosya sistemi değişti (silme/taşıma/ad değiştirme) → kısa bir
  /// birikmeden sonra indeksi temizle. Art arda gelen olaylar tek tura iner.
  void _onFsChanged() {
    _pruneDebounce?.cancel();
    _pruneDebounce = Timer(Motion.long * 3, () {
      unawaited(AiIndex.pruneMissing());
    });
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_onFsChanged);
    _pruneDebounce?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _openMenu(String value) {
    final nav = Navigator.of(context);
    switch (value) {
      case 'smart':
        nav.push(MaterialPageRoute(builder: (_) => const SmartFoldersScreen()));
      case 'bills':
        nav.push(MaterialPageRoute(builder: (_) => const BillsScreen()));
      case 'chat':
        nav.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
      case 'settings':
        openSettingsCategory(context, 'ai');
    }
  }

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(String value, IconData icon, String key) =>
        PopupMenuItem<String>(
          value: value,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(context.t(key)),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('aih.title')),
        actions: [
          // Eskiden dört yazısız simge yan yanaydı (akıllı klasör, fatura,
          // serbest sohbet, ayar); hangisinin ne yaptığı anlaşılmıyordu.
          PopupMenuButton<String>(
            key: const ValueKey('aih-menu'),
            tooltip: context.t('fm.actions'),
            icon: const Icon(AppIcons.more),
            onSelected: _openMenu,
            itemBuilder: (_) => [
              item('smart', AppIcons.folderSpecial, 'smart.title'),
              item('bills', AppIcons.receiptLong, 'bills.title'),
              item('chat', AppIcons.chatBubbleOutline, 'chat.title'),
              item('settings', AppIcons.tune, 'aih.scope_settings'),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: context.t('aih.tab_analysis')),
            Tab(text: context.t('aih.tab_chat')),
            Tab(text: context.t('aih.tab_tags')),
            Tab(text: context.t('aih.tab_suggestions')),
            Tab(text: context.t('aih.tab_report')),
          ],
        ),
      ),
      body: Column(
        children: [
          // İnce ilerleme şeridi: YALNIZ analiz sürerken ve Analiz sekmesi
          // dışında (o sekme aynı bilgiyi büyük hâliyle gösteriyor).
          AnimatedBuilder(
            animation: Listenable.merge([_tabs, AiAnalyzer.progress]),
            builder: (context, _) => AnimatedSize(
              duration: Motion.of(context, Motion.short),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _tabs.index != 0 && AiAnalyzer.progress.value.isBusy
                  ? _ProgressStrip(progress: AiAnalyzer.progress.value)
                  : const SizedBox(width: double.infinity),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AnalysisTab(onOpenTab: (i) => _tabs.animateTo(i)),
                _ChatTab(onOpenAnalysis: () => _tabs.animateTo(0)),
                const _TypesTab(),
                const _SuggestionsTab(),
                const _ReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
