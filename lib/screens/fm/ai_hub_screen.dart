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

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_apply.dart';
import '../../services/fm/ai_ask.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/ai_report.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/gemini_service.dart';
import '../../widgets/fm/ai_file_list.dart';
import '../settings_screen.dart';
import 'ai_files_screen.dart';
import 'important_screen.dart';
import '../../core/snack.dart';

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
          IconButton(
            tooltip: context.t('aih.scope_settings'),
            icon: const Icon(Icons.tune),
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
              duration: const Duration(milliseconds: 180),
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

// ── durum çubuğu: başlat / ilerleme / duraklat ──────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) {
        return ValueListenableBuilder<int>(
          valueListenable: AiIndex.revision,
          builder: (context, _, __) => _buildBody(context, progress),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AiProgress progress) {
    final state = context.watch<AppState>();
    final faint = Paper.faint(context);
    final excluded = state.aiScope.excludedFolders.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.isBusy
                          ? '${progress.done}/${progress.total}'
                          : context.t('aih.analyzed', {'n': AiIndex.count}),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      progress.message.isNotEmpty
                          ? progress.message
                          : (progress.isBusy
                              ? progress.currentName
                              : context
                                  .t('aih.scope_summary', {'n': excluded})),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: faint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (progress.isBusy) ...[
                IconButton(
                  tooltip: context.t(progress.phase == AiRunPhase.paused
                      ? 'aih.resume'
                      : 'aih.pause'),
                  icon: Icon(progress.phase == AiRunPhase.paused
                      ? Icons.play_arrow
                      : Icons.pause),
                  onPressed: () => progress.phase == AiRunPhase.paused
                      ? AiAnalyzer.resume()
                      : AiAnalyzer.pause(),
                ),
                IconButton(
                  tooltip: context.t('aih.stop'),
                  icon: const Icon(Icons.stop),
                  onPressed: AiAnalyzer.cancel,
                ),
              ] else
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(context
                      .t(AiIndex.count == 0 ? 'aih.start' : 'aih.continue')),
                  onPressed: () => _start(context, reanalyze: false),
                ),
            ],
          ),
          if (progress.isBusy)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: LinearProgressIndicator(
                value: progress.total == 0 ? null : progress.fraction,
              ),
            ),
          if (!progress.isBusy && !state.hasApiKey)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                context.t('aih.no_key_note'),
                style: TextStyle(fontSize: 11, color: faint),
              ),
            ),
          if (!progress.isBusy && AiIndex.count > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => _start(context, reanalyze: true),
                child: Text(context.t('aih.reanalyze')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, {required bool reanalyze}) async {
    final state = context.read<AppState>();
    // Analiz uzun sürer ve ekran kapanabilir; state okumaları burada bitiyor.
    await AiAnalyzer.start(
      scope: state.aiScopeRules,
      credentials: state.aiCredentials,
      reanalyze: reanalyze,
    );
  }
}

// ── sekme 1: analiz ─────────────────────────────────────────────────────────

/// **Analiz sekmesi** — "AI ile dosya analizi"nin bulunur hâli.
///
/// Kullanıcı hatası (2026-08-25): *"ai kısmında ai ile dosya analizini bulmak
/// çok zor"*. Doğruydu: başlatma düğmesi [_StatusBar]'ın sağ ucunda, sekme
/// çubuğunun bile üstünde duran küçük bir düğmeydi ve ekranın geri kalanı
/// analiz koşmadan boş görünüyordu.
///
/// Bu sekme üç soruyu sırayla cevaplar: **ne işe yarar**, **ne kadarı bitti**,
/// **nasıl başlatılır**. Kapsam ayarı da burada — "hangi klasörler okunuyor"
/// sorusu analizi başlatmadan önce sorulan bir soru, ayarların derinlerinde
/// değil.
class _AnalysisTab extends StatelessWidget {
  /// Özet kutucuklarından ilgili sekmeye geçiş (1 sohbet, 2 etiketler,
  /// 3 öneriler, 4 rapor).
  final ValueChanged<int> onOpenTab;

  const _AnalysisTab({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProgress>(
      valueListenable: AiAnalyzer.progress,
      builder: (context, progress, _) => ValueListenableBuilder<int>(
        valueListenable: AiIndex.revision,
        builder: (context, _, __) => _body(context, progress),
      ),
    );
  }

  Widget _body(BuildContext context, AiProgress progress) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        // Ne işe yaradığı ÖNCE gelir: kullanıcı düğmeye basmadan önce ne
        // olacağını bilmeli (dosyaları okuyacağız, token harcayacağız).
        // Vurgu renginden yumuşak bir degrade: ekranın "kahraman" kartı.
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card + 4),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.16),
                theme.colorScheme.tertiary.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 24, color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(context.t('aih.analysis_what'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(context.t('aih.analysis_body'),
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Icon(
                      state.hasApiKey
                          ? Icons.cloud_done_outlined
                          : Icons.offline_bolt_outlined,
                      size: 16,
                      color: faint),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                        context.t(state.hasApiKey
                            ? 'aih.mode_cloud'
                            : 'aih.mode_local'),
                        style: TextStyle(fontSize: 12, color: faint)),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(context.t('aih.analysis_manual'),
                  style: TextStyle(fontSize: 12, color: faint)),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),

        // Sayaç: kaç dosya analiz edildi / şu an ne oluyor.
        Text(
          progress.isBusy
              ? '${context.t('aih.analysis_running')} · '
                  '${progress.done}/${progress.total}'
              : context.t('aih.analyzed', {'n': AiIndex.count}),
          style: theme.textTheme.titleLarge,
        ),
        if (progress.isBusy) ...[
          const SizedBox(height: Gap.sm),
          LinearProgressIndicator(
            value: progress.total == 0 ? null : progress.fraction,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            progress.message.isNotEmpty
                ? progress.message
                : progress.currentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: faint),
          ),
        ],
        const SizedBox(height: Gap.md),

        // Asıl düğme: tam genişlik, 56 dp. "Bulunması zor" şikâyetinin cevabı
        // burada — ekranın ortasında, adı üstünde yazan tek eylem.
        if (progress.isBusy)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(progress.phase == AiRunPhase.paused
                      ? Icons.play_arrow
                      : Icons.pause),
                  label: Text(context.t(progress.phase == AiRunPhase.paused
                      ? 'aih.resume'
                      : 'aih.pause')),
                  onPressed: () => progress.phase == AiRunPhase.paused
                      ? AiAnalyzer.resume()
                      : AiAnalyzer.pause(),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(context.t('aih.stop')),
                  onPressed: AiAnalyzer.cancel,
                ),
              ),
            ],
          )
        else
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                  context.t(AiIndex.count == 0 ? 'aih.start' : 'aih.continue')),
              onPressed: () => _start(context, reanalyze: false),
            ),
          ),
        if (!progress.isBusy && AiIndex.count > 0) ...[
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => _start(context, reanalyze: true),
            child: Text(context.t('aih.reanalyze')),
          ),
        ],
        if (!progress.isBusy && !state.hasApiKey) ...[
          const SizedBox(height: Gap.sm),
          Text(context.t('aih.no_key_note'),
              style: TextStyle(fontSize: 12, color: faint)),
        ],
        const SizedBox(height: Gap.md),

        // **Özet kutucukları** — analiz bittikten sonra "ee, ne buldu?"
        // sorusunun cevabı bu sekmede de görünsün; dokununca ilgili sekme.
        // Analiz SÜRERKEN çizilmez: ilerleme her dosyada tetikleniyor ve
        // kovalar tüm dizini dolaşıyor — binlerce kaydı saniyede onlarca kez
        // saymaya değmez; sonuç analiz bitince görünür.
        if (AiIndex.count > 0 && !progress.isBusy) ...[
          _AnalysisStats(onOpenTab: onOpenTab),
          const SizedBox(height: Gap.md),
        ],

        // Kapsam: "hangi klasörler okunuyor" — başlatmadan önce sorulan soru.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: Text(context.t('aih.analysis_scope')),
          subtitle: Text(context.t('aih.scope_summary',
              {'n': state.aiScope.excludedFolders.length})),
          onTap: () => openSettingsCategory(context, 'ai'),
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context, {required bool reanalyze}) async {
    final state = context.read<AppState>();
    // Analiz uzun sürer ve ekran kapanabilir; state okumaları burada bitiyor.
    await AiAnalyzer.start(
      scope: state.aiScopeRules,
      credentials: state.aiCredentials,
      reanalyze: reanalyze,
    );
  }
}

// ── sekme 2: sohbet ─────────────────────────────────────────────────────────

class _ChatMsg {
  final bool fromUser;
  final String text;
  final List<AiRecord> sources;

  /// Hata cevabı (anahtar/kota/ağ): balon uyarı renginde çizilir — eskiden
  /// hata metni sıradan bir cevap gibi görünüyordu.
  final bool error;
  const _ChatMsg(this.fromUser, this.text,
      {this.sources = const [], this.error = false});
}

class _ChatTab extends StatefulWidget {
  /// Henüz analiz yoksa boş ekrandaki düğme Analiz sekmesine götürür.
  final VoidCallback onOpenAnalysis;

  const _ChatTab({required this.onOpenAnalysis});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

/// `AutomaticKeepAliveClientMixin`: **sohbet sekme değişince silinmesin.**
/// `TabBarView` görünmeyen sekmelerin durumunu atıyor; kullanıcı bir kaynak
/// dosyaya bakmak için Etiketler'e geçip döndüğünde bütün konuşma
/// kayboluyordu.
class _ChatTabState extends State<_ChatTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMsg>[];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      _snack(context.t('aih.need_key'));
      return;
    }
    setState(() {
      _messages.add(_ChatMsg(true, question));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final answer = await AiAsk.ask(
        question: question,
        gemini: state.gemini,
        scope: state.aiScopeRules,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(answer.empty
            ? _ChatMsg(false, context.t('aih.no_match'))
            : _ChatMsg(false, answer.text, sources: answer.sources));
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(false, e.message, error: true)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(false, '$e', error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _snack(String message) => showSnack(context, message);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final faint = Paper.faint(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _chatEmpty(context)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) => i == _messages.length
                      ? const _TypingBubble()
                      : _Bubble(message: _messages[i]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.sm),
            child: Row(
              children: [
                // Konuşmayı temizle — yalnız mesaj varken.
                if (_messages.isNotEmpty)
                  IconButton(
                    tooltip: context.t('aih.chat_clear'),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _busy ? null : () => setState(_messages.clear),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.t('aih.chat_hint'),
                      hintStyle: TextStyle(color: faint, fontSize: 13),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: Gap.md, vertical: Gap.sm + 2),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                IconButton.filled(
                  tooltip: context.t('common.send'),
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Boş sohbet: ne sorulabileceğini gösteren **örnek soru çipleri** (dokununca
  /// gönderilir). Henüz analiz yoksa sohbet hiçbir şey bulamaz — bunu baştan
  /// söyler ve Analiz sekmesine götürür.
  Widget _chatEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final noIndex = AiIndex.count == 0;
    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        const SizedBox(height: Gap.lg),
        Icon(Icons.forum_outlined, size: 48, color: faint),
        const SizedBox(height: Gap.md),
        Text(context.t('aih.chat_empty'),
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(
          context.t(noIndex ? 'aih.chat_need_analysis' : 'aih.chat_try'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: faint),
        ),
        const SizedBox(height: Gap.md),
        if (noIndex)
          Center(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.t('aih.tab_analysis')),
              onPressed: widget.onOpenAnalysis,
            ),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final key in const [
                'aih.ex1',
                'aih.ex2',
                'aih.ex3',
                'aih.ex4'
              ])
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(context.t(key)),
                  onPressed: _busy ? null : () => _send(context.t(key)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Cevap beklenirken karşı tarafın balonu: "yazıyor…" göstergesi. Eskiden
/// yalnız giriş kutusunun üstünde ince bir çizgi vardı; göz orada değildi.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
            const SizedBox(width: Gap.sm),
            Text(context.t('aih.thinking'),
                style: TextStyle(fontSize: 13, color: Paper.faint(context))),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMsg message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.md),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: message.error
              ? scheme.errorContainer
              : (message.fromUser
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest),
          // Konuşan tarafın köşesi sivri: kimin söylediği renkten önce
          // biçimden okunuyor.
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(message.fromUser ? 16 : 4),
            bottomEnd: Radius.circular(message.fromUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.error)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Icon(Icons.error_outline,
                    size: 18, color: scheme.onErrorContainer),
              ),
            SelectableText(
              message.text,
              style: message.error
                  ? TextStyle(color: scheme.onErrorContainer)
                  : null,
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                context.t('aih.sources'),
                style: TextStyle(fontSize: 11, color: Paper.faint(context)),
              ),
              const SizedBox(height: Gap.xs),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final source in message.sources)
                    ActionChip(
                      avatar: const Icon(Icons.insert_drive_file_outlined,
                          size: 16),
                      label: Text(source.name, overflow: TextOverflow.ellipsis),
                      onPressed: () => EntryOpener.open(context, source.path),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── sekme 2: etiketler ──────────────────────────────────────────────────────

class _TagsTab extends StatefulWidget {
  const _TagsTab();

  @override
  State<_TagsTab> createState() => _TagsTabState();
}

class _TagsTabState extends State<_TagsTab> with AutomaticKeepAliveClientMixin {
  String? _type;
  bool _onlyImportant = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        if (AiIndex.count == 0) {
          return _EmptyHint(
            icon: Icons.label_outline,
            title: context.t('aih.tags_empty'),
            body: context.t('aih.tags_empty_sub'),
          );
        }
        final counts = AiBuckets.typeCounts();
        // Yeniden analizden sonra seçili tür artık yoksa süzgeç düşer: çipi
        // görünmeyen bir süzgeç listeyi sebepsizce boşaltırdı.
        if (_type != null && !counts.any((e) => e.key == _type)) {
          _type = null;
        }
        final records = _type != null
            ? AiBuckets.of(AiBucket.docType, docType: _type)
            : AiBuckets.of(_onlyImportant ? AiBucket.important : AiBucket.all);
        final filtered = _onlyImportant
            ? [
                for (final record in records)
                  if (record.importance >= AiImportance.important) record
              ]
            : records;

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.xs, top: Gap.xs),
                    child: FilterChip(
                      label: Text(context.t('aih.filter_important')),
                      selected: _onlyImportant,
                      onSelected: (v) => setState(() => _onlyImportant = v),
                    ),
                  ),
                  for (final entry in counts)
                    Padding(
                      padding:
                          const EdgeInsets.only(right: Gap.xs, top: Gap.xs),
                      child: FilterChip(
                        label: Text(
                            '${AiBuckets.label(entry.key)} (${entry.value})'),
                        selected: _type == entry.key,
                        onSelected: (v) =>
                            setState(() => _type = v ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AiFileList(
                records: filtered,
                onChanged: () => setState(() {}),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── sekme 3: öneriler ───────────────────────────────────────────────────────

/// Öneriler sekmesi.
///
/// Uygulama artık **arka planda** koşuyor (`AiApply` → iş kuyruğu): kullanıcı
/// 2026-08-11'de *"analiz sonrası öneriler arka planda yapılmaya devam
/// etmiyor"* dedi — ekran kapanınca ya da uygulama arka plana alınınca iş
/// duruyordu. Artık bildirimde ilerliyor ve buradan çıkılabiliyor.
class _SuggestionsTab extends StatelessWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final suggestions = AiBuckets.of(AiBucket.suggestions);
        if (suggestions.isEmpty) {
          return _EmptyHint(
            icon: Icons.auto_fix_high_outlined,
            title: context.t('aih.sug_empty'),
            body: context.t('aih.sug_empty_sub'),
          );
        }
        return Column(
          children: [
            ValueListenableBuilder<AiApplyResult?>(
              valueListenable: AiApply.lastResult,
              builder: (context, result, __) => result == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding:
                          const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                      child: Text(
                        context.t('aiap.result', {
                          'ok': result.changed,
                          'fail': result.failed,
                        }),
                        style: TextStyle(
                            fontSize: 12, color: Paper.faint(context)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('aih.sug_hint'),
                      style:
                          TextStyle(fontSize: 12, color: Paper.faint(context)),
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(
                        context.t('aih.apply_all', {'n': suggestions.length})),
                    onPressed: () => _applyAll(context, suggestions),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AiFileList(
                records: suggestions,
                showSuggestion: true,
                onApply: (selected) async => _applyAll(context, selected),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyAll(BuildContext context, List<AiRecord> records) {
    AiApply.start(
      records,
      importantRoot: ImportantScreen.pathIn(FmEnv.primaryRoot),
    );
    showSnack(context, context.t('aiap.started', {'n': records.length}));
  }
}

// ── sekme 4: rapor ──────────────────────────────────────────────────────────

/// **Rapor** — analizin "ee, şimdi ne olacak?" sorusuna cevabı.
///
/// Kullanıcı (2026-08-11): *"AI analiz ediyor ama ne işe yarıyor, kullanıcı ne
/// yapacak belli değil… rapor menüsünde etkileşim yok."* Eski rapor sayı
/// listesiydi: hiçbir satıra dokunulamıyor, hiçbir sayı bir eyleme
/// bağlanmıyordu. Yeni rapor iki katman:
/// 1. **Eylem kartları** — yapılacak iş varsa en üstte, düğmesiyle birlikte.
/// 2. **Kova satırları** — her sayı tıklanabilir; dokununca o dosyaların
///    listesi (çoklu seçim + toplu işlem) açılır.
class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final all = AiIndex.all();
        final analyzed = [
          for (final record in all)
            if (record.analyzedMs > 0) record
        ];
        if (analyzed.isEmpty) {
          return _EmptyHint(
            icon: Icons.insights_outlined,
            title: context.t('aih.report_empty'),
            body: context.t('aih.report_empty_sub'),
          );
        }

        final important = AiBuckets.of(AiBucket.important, source: analyzed);
        final disposable = AiBuckets.of(AiBucket.disposable, source: analyzed);
        final lowValue = AiBuckets.of(AiBucket.lowValue, source: analyzed);
        final suggestions =
            AiBuckets.of(AiBucket.suggestions, source: analyzed);
        final types = AiBuckets.typeCounts(analyzed);

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, Gap.sm, 0, Gap.xl),
          children: [
            // ── Yapılacak işler ──────────────────────────────────────────
            if (suggestions.isNotEmpty)
              _ActionCard(
                icon: Icons.auto_fix_high,
                title:
                    context.t('aih.card_sug_title', {'n': suggestions.length}),
                body: context.t('aih.card_sug_body'),
                actionLabel: context.t('aih.card_sug_action'),
                onAction: () => _openBucket(context, AiBucket.suggestions,
                    context.t('aih.tab_suggestions')),
              ),
            if (disposable.isNotEmpty)
              _ActionCard(
                icon: Icons.cleaning_services_outlined,
                title: context.t('aih.card_junk_title', {
                  'n': disposable.length,
                  'size': FsPaths.humanSize(AiBuckets.totalBytes(disposable)),
                }),
                body: context.t('aih.card_junk_body'),
                actionLabel: context.t('aih.card_junk_action'),
                onAction: () => _openBucket(
                    context, AiBucket.disposable, context.t('aih.report_junk')),
              ),

            const SizedBox(height: Gap.sm),
            // ── Kovalar (hepsi tıklanabilir) ─────────────────────────────
            _ReportRow(
              icon: Icons.folder_open,
              label: context.t('aih.report_analyzed'),
              value: '${analyzed.length}',
              sub: FsPaths.humanSize(AiBuckets.totalBytes(analyzed)),
              onTap: () => _openBucket(
                  context, AiBucket.all, context.t('aih.report_analyzed')),
            ),
            _ReportRow(
              icon: Icons.star_outline,
              label: context.t('aih.report_important'),
              value: '${important.length}',
              onTap: () => _openBucket(context, AiBucket.important,
                  context.t('aih.report_important')),
            ),
            _ReportRow(
              icon: Icons.delete_outline,
              label: context.t('aih.report_junk'),
              value: '${disposable.length}',
              sub: FsPaths.humanSize(AiBuckets.totalBytes(disposable)),
              onTap: () => _openBucket(
                  context, AiBucket.disposable, context.t('aih.report_junk')),
            ),
            _ReportRow(
              icon: Icons.inbox_outlined,
              label: context.t('aih.report_low'),
              value: '${lowValue.length}',
              sub: FsPaths.humanSize(AiBuckets.totalBytes(lowValue)),
              onTap: () => _openBucket(
                  context, AiBucket.lowValue, context.t('aih.report_low')),
            ),
            _ReportRow(
              icon: Icons.auto_fix_high_outlined,
              label: context.t('aih.report_suggestions'),
              value: '${suggestions.length}',
              onTap: () => _openBucket(context, AiBucket.suggestions,
                  context.t('aih.tab_suggestions')),
            ),
            const Divider(height: Gap.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text(context.t('aih.report_types'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final entry in types.take(15))
              ListTile(
                dense: true,
                title: Text(AiBuckets.label(entry.key)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${entry.value}'),
                    const SizedBox(width: Gap.xs),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
                onTap: () => _openBucket(
                  context,
                  AiBucket.docType,
                  AiBuckets.label(entry.key),
                  docType: entry.key,
                ),
              ),
          ],
        );
      },
    );
  }

  static void _openBucket(
    BuildContext context,
    AiBucket bucket,
    String title, {
    String? docType,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          AiFilesScreen(bucket: bucket, title: title, docType: docType),
    ));
  }
}

/// Analiz sekmesindeki özet kutucukları: önemli · çöp adayı · öneri ·
/// analiz edilen. Her biri ilgili sekmeyi açar.
class _AnalysisStats extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const _AnalysisStats({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final analyzed = [
      for (final record in AiIndex.all())
        if (record.analyzedMs > 0) record
    ];
    final important = AiBuckets.of(AiBucket.important, source: analyzed);
    final disposable = AiBuckets.of(AiBucket.disposable, source: analyzed);
    final suggestions = AiBuckets.of(AiBucket.suggestions, source: analyzed);
    final tiles = [
      _StatTile(
        icon: Icons.star_rounded,
        color: const Color(0xFFE39B2E),
        value: '${important.length}',
        label: context.t('aih.report_important'),
        onTap: () => onOpenTab(2),
      ),
      _StatTile(
        icon: Icons.delete_sweep_rounded,
        color: const Color(0xFFD9433B),
        value: '${disposable.length}',
        label: disposable.isEmpty
            ? context.t('aih.report_junk')
            : '${context.t('aih.report_junk')} · '
                '${FsPaths.humanSize(AiBuckets.totalBytes(disposable))}',
        onTap: () => onOpenTab(4),
      ),
      _StatTile(
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFF8B4FD1),
        value: '${suggestions.length}',
        label: context.t('aih.report_suggestions'),
        onTap: () => onOpenTab(3),
      ),
      _StatTile(
        icon: Icons.forum_rounded,
        color: const Color(0xFF12998A),
        value: '${analyzed.length}',
        label: context.t('aih.ask_files'),
        onTap: () => onOpenTab(1),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // Dar telefonda 2×2, genişte tek sıra.
        final perRow = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - Gap.sm * (perRow - 1)) / perRow;
        return Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final t in tiles) SizedBox(width: w, child: t),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 4),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Paper.faint(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üstte duran "şunu yapabilirsin" kartı.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(body,
                      style:
                          TextStyle(fontSize: 12, color: Paper.faint(context))),
                  const SizedBox(height: Gap.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final VoidCallback? onTap;

  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: sub == null
            ? null
            : Text(sub!,
                style: TextStyle(fontSize: 12, color: Paper.faint(context))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: faint),
            const SizedBox(height: Gap.md),
            Text(title, textAlign: TextAlign.center),
            if (body.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
