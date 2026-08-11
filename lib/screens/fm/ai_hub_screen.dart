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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_analyzer.dart';
import '../../services/fm/ai_ask.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/ai_report.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/gemini_service.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../settings_screen.dart';
import 'entry_actions.dart';
import 'important_screen.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

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
            Tab(text: context.t('aih.tab_chat')),
            Tab(text: context.t('aih.tab_tags')),
            Tab(text: context.t('aih.tab_suggestions')),
            Tab(text: context.t('aih.tab_report')),
          ],
        ),
      ),
      body: Column(
        children: [
          const _StatusBar(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _ChatTab(),
                _TagsTab(),
                _SuggestionsTab(),
                _ReportTab(),
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
                              : context.t('aih.scope_summary',
                                  {'n': excluded})),
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
                  label: Text(context.t(
                      AiIndex.count == 0 ? 'aih.start' : 'aih.continue')),
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

// ── sekme 1: sohbet ─────────────────────────────────────────────────────────

class _ChatMsg {
  final bool fromUser;
  final String text;
  final List<AiRecord> sources;
  const _ChatMsg(this.fromUser, this.text, {this.sources = const []});
}

class _ChatTab extends StatefulWidget {
  const _ChatTab();

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
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

  Future<void> _send() async {
    final question = _controller.text.trim();
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
      setState(() => _messages.add(_ChatMsg(false, e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(false, '$e')));
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

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _EmptyHint(
                  icon: Icons.forum_outlined,
                  title: context.t('aih.chat_empty'),
                  body: context.t('aih.chat_empty_sub'),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                ),
        ),
        if (_busy) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.t('aih.chat_hint'),
                      hintStyle: TextStyle(color: faint, fontSize: 13),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                IconButton.filled(
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
          color: message.fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                context.t('aih.sources'),
                style: TextStyle(
                    fontSize: 11, color: Paper.faint(context)),
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
                      label: Text(source.name,
                          overflow: TextOverflow.ellipsis),
                      onPressed: () =>
                          EntryOpener.open(context, source.path),
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

class _TagsTabState extends State<_TagsTab> {
  String? _type;
  bool _onlyImportant = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final counts = AiIndex.docTypeCounts().entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final records = AiIndex.where(
          docType: _type,
          minImportance: _onlyImportant ? AiImportance.important : 0,
        )..sort((a, b) {
            final byImportance = b.importance.compareTo(a.importance);
            return byImportance != 0
                ? byImportance
                : b.modifiedMs.compareTo(a.modifiedMs);
          });

        if (AiIndex.count == 0) {
          return _EmptyHint(
            icon: Icons.label_outline,
            title: context.t('aih.tags_empty'),
            body: context.t('aih.tags_empty_sub'),
          );
        }

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
                        label: Text('${entry.key} (${entry.value})'),
                        selected: _type == entry.key,
                        onSelected: (v) =>
                            setState(() => _type = v ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? _EmptyHint(
                      icon: Icons.filter_alt_off_outlined,
                      title: context.t('aih.no_match'),
                      body: '',
                    )
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, i) =>
                          _RecordTile(record: records[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AiRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    // Girdi kayıttan kurulur, DİSKTEN OKUNMAZ: liste kaydırılırken her satır
    // için `existsSync`/`statSync` çağırmak ana izlekte disk G/Ç demekti
    // (aynı hata "son açılanlar" ekranında ekranı saniyelerce dondurmuştu,
    // bkz. FsScan.statPaths notu). Dosya silinmişse açma denemesi zaten
    // kullanıcıya "bulunamadı" der.
    final entry = FsEntry(
      path: record.path,
      name: record.name,
      isDir: false,
      sizeBytes: record.sizeBytes,
      modifiedMs: record.modifiedMs,
    );
    return ListTile(
      leading: FmEntryIcon(entry: entry),
      title: Text(
        record.title.isEmpty ? record.name : record.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (record.docType.isNotEmpty) record.docType,
          FsPaths.humanSize(record.sizeBytes),
          if (record.summary.isNotEmpty) record.summary,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: faint),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.importance >= AiImportance.important)
            Icon(Icons.star,
                size: 18, color: Theme.of(context).colorScheme.primary),
          IconButton(
            tooltip: context.t('fm.actions'),
            icon: const Icon(Icons.more_vert),
            onPressed: () => openEntryActions(context, entry),
          ),
        ],
      ),
      onTap: () => EntryOpener.open(context, record.path),
      // Uzun basış = dosya yöneticisinin kendi işlem sayfası (sil, adlandır,
      // taşı, paylaş, etiketle, özellikler). Kullanıcı isteği 2026-08-10:
      // *"ai analizinde belgeleri silme düzenleme vs gibi işlemler de
      // yapılabilmeli."* Ayrı bir menü yazmak yerine uygulamanın var olan,
      // denenmiş sayfası kullanılıyor — davranış her yerde aynı kalsın.
      onLongPress: () => openEntryActions(context, entry),
    );
  }
}

/// İşlem sayfasını açar ve sonrasında indeksi gerçekle eşitler.
///
/// Dosya silindiyse/taşındıysa kaydın öylece durması, AI Merkezi'nde artık
/// var olmayan dosyaları göstermek demekti (dokununca "bulunamadı").
Future<void> openEntryActions(BuildContext context, FsEntry entry) async {
  final changed = await showEntryActions(context, entry, allowReveal: true);
  if (!changed) return;
  await AiIndex.pruneMissing();
}

// ── sekme 3: öneriler ───────────────────────────────────────────────────────

class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab();

  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab> {
  final _selected = <String>{};
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final suggestions = AiIndex.where(onlySuggestions: true)
          ..sort((a, b) => b.importance.compareTo(a.importance));
        if (suggestions.isEmpty) {
          return _EmptyHint(
            icon: Icons.auto_fix_high_outlined,
            title: context.t('aih.sug_empty'),
            body: context.t('aih.sug_empty_sub'),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: suggestions.length,
                itemBuilder: (context, i) {
                  final record = suggestions[i];
                  final picked = _selected.contains(record.path);
                  return ListTile(
                    leading: Checkbox(
                      value: picked,
                      onChanged: _applying
                          ? null
                          : (on) => setState(() {
                                if (on == true) {
                                  _selected.add(record.path);
                                } else {
                                  _selected.remove(record.path);
                                }
                              }),
                    ),
                    title: Text(record.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      _describe(context, record),
                      style: TextStyle(
                          fontSize: 12, color: Paper.faint(context)),
                    ),
                    // Satır başına işlem: tek öneriyi uygulamak için 40
                    // dosyalık listeyi tek tek işaretlemek zorunda kalmamalı;
                    // beğenilmeyen öneri de listeden düşebilmeli.
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'apply':
                            await _apply([record], explicit: [record]);
                          case 'ignore':
                            await AiIndex.clearSuggestion(record.path);
                          case 'actions':
                            if (!context.mounted) return;
                            await openEntryActions(
                              context,
                              FsEntry(
                                path: record.path,
                                name: record.name,
                                isDir: false,
                                sizeBytes: record.sizeBytes,
                                modifiedMs: record.modifiedMs,
                              ),
                            );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'apply',
                            child: Text(context.t('aih.apply_one'))),
                        PopupMenuItem(
                            value: 'ignore',
                            child: Text(context.t('aih.ignore_one'))),
                        PopupMenuItem(
                            value: 'actions',
                            child: Text(context.t('fm.actions'))),
                      ],
                    ),
                    onTap: _applying
                        ? null
                        : () => setState(() {
                              if (!_selected.remove(record.path)) {
                                _selected.add(record.path);
                              }
                            }),
                  );
                },
              ),
            ),
            if (_applying) const LinearProgressIndicator(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _applying
                          ? null
                          : () => setState(() {
                                if (_selected.length == suggestions.length) {
                                  _selected.clear();
                                } else {
                                  _selected
                                    ..clear()
                                    ..addAll(suggestions.map((r) => r.path));
                                }
                              }),
                      child: Text(context.t('aih.select_all')),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(context.t(
                          'aih.apply_selected', {'n': _selected.length})),
                      onPressed: _selected.isEmpty || _applying
                          ? null
                          : () => _apply(suggestions),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _describe(BuildContext context, AiRecord record) {
    final parts = <String>[];
    if (record.suggestedName.isNotEmpty &&
        record.suggestedName != record.name) {
      parts.add('→ ${record.suggestedName}');
    }
    if (record.suggestedFolder.isNotEmpty) {
      parts.add('→ ${record.suggestedFolder}/');
    }
    return parts.join('   ');
  }

  /// Seçilen önerileri uygular: önce yeniden adlandır, sonra taşı.
  ///
  /// Sıra önemli: taşıdıktan sonra adlandırmak, hedefte ad çakışması olursa
  /// dosyayı iki kez oynatırdı. Hata alan dosya atlanır ve sayılır — 40
  /// dosyalık bir uygulamada tek hata yüzünden hiçbiri işlenmemesi kötü olurdu.
  Future<void> _apply(List<AiRecord> all, {List<AiRecord>? explicit}) async {
    setState(() => _applying = true);
    final targets = explicit ??
        [
          for (final record in all)
            if (_selected.contains(record.path)) record
        ];
    var okCount = 0;
    var failCount = 0;
    var lastError = '';
    final importantRoot = ImportantScreen.pathIn(FmEnv.primaryRoot);

    for (final record in targets) {
      try {
        var path = record.path;
        if (record.suggestedName.isNotEmpty &&
            record.suggestedName != p.basename(path)) {
          path = await FileOps.rename(path, record.suggestedName);
        }
        if (record.suggestedFolder.isNotEmpty) {
          final dest = p.join(importantRoot, record.suggestedFolder);
          // KÖK NEDEN (kullanıcı 2026-08-10: *"öneriler ekranında işlemleri
          // yapmıyor, atlıyor"* — 0 düzenlendi, 312 atlandı): hedef klasör
          // yoktu ve `FileOps.moveAll` var olmayan klasöre taşıyamayıp
          // `succeeded: 0` dönüyordu. Tek tek öneride bunu `ai_actions`
          // yapıyordu (`dir.create(recursive: true)`), toplu akışta unutulmuş.
          final dir = Directory(dest);
          if (!dir.existsSync()) await dir.create(recursive: true);
          final result = await FileOps.moveAll([path], dest);
          if (result.succeeded == 0) {
            failCount++;
            if (result.errors.isNotEmpty) lastError = result.errors.first;
            continue;
          }
          path = p.join(dest, p.basename(path));
        }
        await AiIndex.movePath(record.path, path);
        okCount++;
      } catch (e) {
        failCount++;
        lastError = '$e';
      }
    }

    if (!mounted) return;
    setState(() {
      _applying = false;
      _selected.clear();
    });
    // Hata varsa SEBEBİ de söylenir: "312 atlandı" tek başına kullanıcıyı
    // neyin yanlış gittiği konusunda kör bırakıyordu.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        context.t('aih.applied', {'ok': okCount, 'fail': failCount}) +
            (failCount > 0 && lastError.isNotEmpty ? ' · $lastError' : ''),
      ),
      duration: const Duration(seconds: 5),
    ));
  }
}

// ── sekme 4: rapor ──────────────────────────────────────────────────────────

class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AiIndex.revision,
      builder: (context, _, __) {
        final report = AiReport.build(AiIndex.all());
        if (report.analyzed == 0) {
          return _EmptyHint(
            icon: Icons.insights_outlined,
            title: context.t('aih.report_empty'),
            body: context.t('aih.report_empty_sub'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            _ReportRow(
              icon: Icons.folder_open,
              label: context.t('aih.report_analyzed'),
              value: '${report.analyzed}',
              sub: FsPaths.humanSize(report.totalBytes),
            ),
            _ReportRow(
              icon: Icons.star_outline,
              label: context.t('aih.report_important'),
              value: '${report.important.length}',
            ),
            _ReportRow(
              icon: Icons.delete_outline,
              label: context.t('aih.report_junk'),
              value: '${report.junk.length}',
              sub: FsPaths.humanSize(report.junkBytes),
            ),
            _ReportRow(
              icon: Icons.auto_fix_high_outlined,
              label: context.t('aih.report_suggestions'),
              value: '${report.suggestions.length}',
            ),
            const Divider(height: Gap.lg),
            Text(context.t('aih.report_types'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: Gap.sm),
            for (final entry in report.byType.take(12))
              ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('${entry.value}'),
              ),
            if (report.important.isNotEmpty) ...[
              const Divider(height: Gap.lg),
              Text(context.t('aih.report_important'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              for (final record in report.important.take(10))
                _RecordTile(record: record),
            ],
          ],
        );
      },
    );
  }
}

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: sub == null
            ? null
            : Text(sub!,
                style:
                    TextStyle(fontSize: 12, color: Paper.faint(context))),
        trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
