/// **AI Merkezi** — tüm dosya analizinin tek ekranı.
///
/// Kullanıcı kararı (2026-08-10): giriş noktası **panodaki AI kartı**, işin
/// tamamı da burada. Dört sekme, dördü de aynı indeksten beslenir:
///
/// - **Sohbet:** "geçen ay indirdiğim faturalar nerede" → cevap + kaynak
///   dosyalar (dokununca açılır). Kaynaksız cevap göstermiyoruz: kullanıcı
///   doğrulayabilmeli.
/// - **Etiketler:** AI'nın verdiği tür/önem süzgeci — "kimlik" deyip
///   telefondaki tüm resmî evrakı görmek.
/// - **Öneriler:** anlamsız adlar ve yanlış klasörler için toplu onay. Otomatik
///   uygulama YOK; kullanıcı seçer, uygular, geri alabilir.
/// - **Rapor:** analiz edilen yığının özeti (önemli evrak, çöp adayı, tür
///   dağılımı).
///
/// Analiz **elle başlar** (kullanıcı kararı): uygulama arka planda kendiliğinden
/// token harcamaz.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_apply.dart';
import '../../services/fm/ai_ask.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/ai_report.dart';
import '../../services/fm/smart_folders.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/gemini_service.dart';
import '../../widgets/fm/ai_file_list.dart';
import '../../widgets/fm/ai_preview_card.dart';
import '../settings_screen.dart';
import '../chat_screen.dart';
import 'ai_files_screen.dart';
import 'bills_screen.dart';
import 'smart_folders_screen.dart';
import 'important_screen.dart';
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
  /// **Beş sekme, ilki "Analiz"** (kullanıcı hatası 2026-08-25: *"ai kısmında
  /// ai ile dosya analizini bulmak çok zor"*).
  ///
  /// KÖK NEDEN: analiz her şeyin ÖN KOŞULU (etiket, öneri, rapor ve sohbet
  /// analiz edilmiş dosya olmadan boş) ama başlatma düğmesi sekmelerin
  /// üstündeki ince durum çubuğunun sağ ucunda küçük bir düğmeydi. Uygulamaya
  /// ilk kez giren kullanıcı dört boş sekme görüyor, "AI çalışmıyor" sanıyordu.
  /// Artık açılışta gelen sekme analizin kendisi: ne işe yaradığını anlatan
  /// bir kart ve ekranın yarısı kadar bir "Analizi başlat" düğmesi.
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    AiIndex.ensureLoaded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('aih.title')),
        actions: [
          // Akıllı klasörler (2026-10-18): kayıtlı AI aramaları.
          IconButton(
            tooltip: context.t('smart.title'),
            icon: const Icon(AppIcons.folderSpecial),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SmartFoldersScreen()),
            ),
          ),
          // Faturalar ve giderler (2026-10-21, K8): ayrı pano kutusu değil,
          // AI Merkezi'nin bir bölümü — veri zaten AI analizinden geliyor.
          IconButton(
            tooltip: context.t('bills.title'),
            icon: const Icon(AppIcons.receiptLong),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BillsScreen()),
            ),
          ),
          // Serbest sohbet (eskiden alt çubuğun AI sekmesiydi, 2026-09-27).
          IconButton(
            tooltip: context.t('chat.title'),
            icon: const Icon(AppIcons.chatBubbleOutline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          IconButton(
            tooltip: context.t('aih.scope_settings'),
            icon: const Icon(AppIcons.tune),
            onPressed: () => openSettingsCategory(context, 'ai'),
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
          // Durum çubuğu Analiz sekmesinde GİZLİ: o sekme aynı sayacı ve aynı
          // "Başlat" düğmesini büyük hâliyle zaten gösteriyor — eskiden ekranda
          // iki "Analizi başlat" düğmesi alt alta duruyordu.
          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => AnimatedSize(
              duration: Motion.of(context, Motion.short),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _tabs.index == 0
                  ? const SizedBox(width: double.infinity)
                  : const _StatusBar(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AnalysisTab(onOpenTab: (i) => _tabs.animateTo(i)),
                _ChatTab(onOpenAnalysis: () => _tabs.animateTo(0)),
                const _TagsTab(),
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


// ── sekme 2: sohbet ─────────────────────────────────────────────────────────


// ── sekme 2: etiketler ──────────────────────────────────────────────────────

