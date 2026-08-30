import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/smart_query.dart';
import '../../services/gemini_service.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';
import '../../core/snack.dart';

/// Klasör altında özyinelemeli dosya arama (Türkçe-duyarlı).
///
/// Arama artık **dizin üzerinden** koşar ([SearchIndex]): depolama bir kez
/// derinlemesine taranır, sonraki her arama o dizinde yapılır — 100 bin
/// dosyalı bir telefonda her harfte diski gezmek saniyeler sürüyordu. Dizin
/// yoksa ilk arama canlı taramaya düşer (kullanıcı beklemez) ve arka planda
/// dizin kurulur.
class SearchScreen extends StatefulWidget {
  final String root;
  final String? rootLabel;
  const SearchScreen({super.key, required this.root, this.rootLabel});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<FsEntry> _results = const [];
  bool _searching = false;
  bool _searched = false;
  FmCategory? _category;

  /// Tarih/boyut/kaynak/tür süzgeci ve sıralama (kullanıcı isteği 2026-07-29:
  /// "aramada sıralama seçenekleri lazım · aranan şeyler arama filtresi de
  /// olmalı").
  FmFilter _filter = FmFilter.none;
  FmSort _sort = FmSort.date;
  bool _desc = true;

  /// **Akıllı arama:** "geçen ay whatsapp videoları" gibi bir cümle yazıldığında
  /// tarih/tür/kaynak süzgeçleri cümleden çıkarılır (yerel, çevrimdışı).
  /// Anlaşılanlar çip olarak gösterilir — sessiz süzme "neden bu sonuç?"
  /// sorusunu doğurur.
  SmartQuery? _smart;
  bool _smartOn = true;
  bool _aiBusy = false;

  /// Kaçıncı arama olduğunu sayar: geç dönen eski sonuç yenisini ezmesin.
  int _queryToken = 0;

  /// **Çoklu seçim** (kullanıcı isteği 2026-08-17: *"ararken tümünü seç vs.
  /// olmalı"*). Aramanın sonucu çoğu zaman "şu 40 dosyayı sil/taşı/paylaş"
  /// demek; ekran o ana kadar tek tek açmaktan başkasına izin vermiyordu.
  /// Kategori ve galeri ekranlarıyla AYNI kalıp: uzun basış seçimi açar,
  /// üstte sayaç + tümünü seç, altta [FmSelectionBar].
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  void _toggleSelectAll(List<FsEntry> visible) {
    setState(() {
      if (visible.every((e) => _selected.contains(e.path))) {
        _selected.removeAll(visible.map((e) => e.path));
      } else {
        _selected.addAll(visible.map((e) => e.path));
      }
    });
  }

  /// Seçili girdiler — SAYAÇ ile EYLEM aynı kümeyi görsün diye görünen
  /// listeden süzülür (süzgeç değişince seçim dışarıda kalmış olabilir).
  List<FsEntry> _selectedIn(List<FsEntry> visible) =>
      [for (final e in visible) if (_selected.contains(e.path)) e];

  @override
  void initState() {
    super.initState();
    SearchIndex.revision.addListener(_onIndexChanged);
    // Etiket süzgeci çipleri için (kişi/grup).
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // "Açılmış/açılmamış" ölçütleri uygulamanın kendi açılış kaydını da sayar.
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // Ekran açılırken dizin hazırlanır; kullanıcı yazana kadar çoğu zaman
    // hazır olur, olmazsa canlı taramaya düşülür.
    SearchIndex.ensureBuilt();
  }

  @override
  void dispose() {
    SearchIndex.revision.removeListener(_onIndexChanged);
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onIndexChanged() {
    if (!mounted) return;
    setState(() {});
    // Dizin yeni kurulduysa açık sorguyu tazele (sonuç eksik kalmasın).
    if (SearchIndex.isReady &&
        !SearchIndex.isBuilding &&
        _controller.text.trim().length >= 2) {
      _run(_controller.text);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // 250 ms: dizin sayesinde arama ucuzladı, eskisi (400 ms) fazla bekletiyor.
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _searching = false;
        _smart = null;
      });
      return;
    }
    final token = ++_queryToken;
    // Cümleyi çözümle: kalan metin dizinde aranır, ölçütler süzgece geçer.
    final smart = _smartOn ? parseSmartQuery(q) : null;
    setState(() {
      _searching = true;
      _smart = (smart != null && smart.hasStructure) ? smart : null;
    });
    // Ad araması için kalan metin; hepsi ölçüte dönüştüyse (örn. "bu hafta
    // videolar") ad süzmesi yapılmaz, yalnız süzgeç uygulanır.
    final needle = _smart?.text.trim() ?? q;
    // Sınır 500 değil 1000: sonuçlar burada ayrıca süzülüyor (tarih/boyut/tür)
    // — dar bir ham liste, süzgeçten sonra haksız yere boş kalırdı.
    final hits = needle.length >= 2
        ? await SearchIndex.query(needle, root: widget.root, limit: 1000)
        : await SearchIndex.query('', root: widget.root, limit: 1000,
            matchAll: true);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _results = hits;
      _searching = false;
      _searched = true;
    });
  }

  List<FsEntry> get _filtered {
    final smart = _smart;
    final smartCategory = smart?.category;
    final list = [
      for (final e in _results)
        if (_category == null || e.category == _category)
          if (smartCategory == null || e.category == smartCategory)
            if (smart == null || smart.filter.matches(e))
              if (_filter.matches(e,
                  tagsOf: FileTags.forPath, openedAtOf: OpenHistory.forPath))
                e,
    ];
    // Klasörler üstte KALMAZ: arama sonucunda kullanıcı ölçüte (tarih/boyut)
    // göre sıralı tek bir liste bekler.
    return FsScan.sort(list, _sort, descending: _desc, foldersFirst: false);
  }

  Future<void> _openFilterSheet() async {
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: extensionCounts(_results),
      buckets: bucketCounts(_results.map((e) => e.path)),
      chatKinds: chatKindCounts(_results),
      tags: FileTags.counts(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    if (_selecting) return _selectionScaffold(results);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.t('srch.in_hint',
                {'name': widget.rootLabel ?? p.basename(widget.root)}),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _run('');
              },
            ),
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
          PopupMenuButton<String>(
            tooltip: context.t('srch.options'),
            onSelected: (v) async {
              switch (v) {
                case 'rebuild':
                  await SearchIndex.rebuild();
                  if (mounted && _controller.text.trim().length >= 2) {
                    _run(_controller.text);
                  }
                case 'smart':
                  setState(() => _smartOn = !_smartOn);
                  if (_controller.text.trim().length >= 2) {
                    _run(_controller.text);
                  }
                case 'ai':
                  await _askAi();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'smart',
                child: Text(context
                    .t(_smartOn ? 'srch.smart_off' : 'srch.smart_on')),
              ),
              PopupMenuItem(
                value: 'ai',
                child: Text(context.t('srch.ai_interpret')),
              ),
              PopupMenuItem(
                value: 'rebuild',
                child: Text(context.t('srch.rebuild_index')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_smart != null) _smartChips(),
          _filterChips(),
          if (_searching || _aiBusy || SearchIndex.isBuilding)
            const LinearProgressIndicator(minHeight: 2),
          _indexBanner(),
          if (_searched && _results.isNotEmpty) _resultSummary(results.length),
          Expanded(child: _body(results)),
        ],
      ),
    );
  }

  /// Seçim kipindeki ekran: sade sayaç + "tümünü seç" üstte, eylemler altta.
  ///
  /// Ayrı bir `Scaffold` DEĞİL, aynı gövde farklı üst çubukla — arama alanı
  /// seçim sırasında gizlenir (klavye açılıp seçimi bozmasın) ama sonuçlar
  /// yerinde kalır, liste zıplamaz.
  Widget _selectionScaffold(List<FsEntry> results) {
    final selected = _selectedIn(results);
    final allSelected =
        results.isNotEmpty && results.every((e) => _selected.contains(e.path));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text(context.t('ph.selected_of',
            {'n': selected.length, 'total': results.length})),
        actions: [
          IconButton(
            tooltip: context
                .t(allSelected ? 'ph.clear_selection' : 'ph.select_all'),
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            onPressed: () => _toggleSelectAll(results),
          ),
        ],
      ),
      body: Stack(
        children: [
          _body(results),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FmSelectionBar(
              selected: selected,
              onChanged: () async {
                // "Arka plana al" ekranı kapatmış olabilir (bkz. kategori
                // ekranındaki aynı not).
                if (!mounted) return;
                setState(_selected.clear);
                await _run(_controller.text);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dizinin durumu: kuruluyor / bayat. Kullanıcı sonucun neden eksik
  /// olabileceğini bilsin diye açıkça yazılır.
  Widget _indexBanner() {
    String? text;
    if (SearchIndex.isBuilding) {
      text = context.t('srch.index_building');
    } else if (SearchIndex.isReady && SearchIndex.isStale) {
      text = context.t('srch.index_stale');
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  /// Cümleden ANLAŞILANLAR — kullanıcı yanlış yorumu görüp kaldırabilsin.
  Widget _smartChips() {
    final smart = _smart!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.t('srch.understood'),
              style: Theme.of(context).textTheme.bodySmall),
          for (final label in smart.understood)
            Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
            ),
          if (smart.text.trim().isNotEmpty)
            Chip(
              avatar: const Icon(Icons.abc, size: 18),
              label: Text('“${smart.text}”'),
              visualDensity: VisualDensity.compact,
            ),
          TextButton(
            onPressed: () => setState(() => _smart = null),
            child: Text(context.t('common.ignore')),
          ),
        ],
      ),
    );
  }

  /// Sorguyu Gemini'ye yorumlatır. **Yerel çözümleme yine geçerlidir**: AI
  /// başarısız olursa ya da anlamsız yanıt dönerse arama bozulmaz.
  Future<void> _askAi() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final appState = context.read<AppState>();
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    if (!appState.hasApiKey) {
      showSnack(context, str.t('srch.need_key'));
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final gemini =
          appState.gemini;
      final answer = await gemini.chat(history: [
        ChatTurn(fromUser: true, text: smartQueryPrompt(q, DateTime.now())),
      ]);
      final parsed = smartQueryFromJson(answer);
      if (!mounted) return;
      setState(() {
        _aiBusy = false;
        if (parsed != null) _smart = parsed;
      });
      if (parsed == null && mounted) {
        showSnack(context, str.t('srch.ai_fallback'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      showSnack(context, str.t('srch.ai_error', {'error': e}));
    }
  }

  /// Kaç sonuç gösteriliyor, hangi ölçütle sıralı ve liste sınıra takıldı mı.
  /// (Sessizce kırpılmış bir liste "dosyam yok" sanılır.)
  Widget _resultSummary(int shown) {
    final capped = _results.length >= 1000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      child: Text(
        context.t('srch.summary', {
          'n': shown,
          'sort': context.t(_sort.labelKey),
          'dir': context.t(_desc ? 'fmset.desc' : 'fmset.asc'),
          'capped': capped ? context.t('srch.capped') : '',
        }),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _filterChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          children: [
            for (final entry in <(String, FmCategory?)>[
              ('flt.all', null),
              for (final c in FmCategory.values) (c.labelKey, c),
            ])
              Padding(
                padding: const EdgeInsets.only(right: Gap.sm),
                child: ChoiceChip(
                  label: Text(context.t(entry.$1)),
                  selected: _category == entry.$2,
                  onSelected: (_) => setState(() => _category = entry.$2),
                ),
              ),
          ],
        ),
      );

  Widget _body(List<FsEntry> results) {
    if (results.isEmpty) {
      final message = context.t(!_searched
          ? 'srch.empty_hint'
          : (_searching ? 'srch.searching' : 'srch.no_result'));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }
    // Uzun basış seçimi açar, basılı tutup kaydırmak aralık seçer — kategori
    // ve galeri ekranlarındaki jestin AYNISI (kullanıcı bir kez öğrenir).
    return DragSelectArea(
      scrollController: _scroll,
      isSelected: (i) =>
          i >= 0 && i < results.length && _selected.contains(results[i].path),
      onSelectRange: (a, b, sel) => setState(() {
        for (var i = a; i <= b; i++) {
          if (i < 0 || i >= results.length) continue;
          if (sel) {
            _selected.add(results[i].path);
          } else {
            _selected.remove(results[i].path);
          }
        }
      }),
      child: ListView.builder(
        controller: _scroll,
        // Seçim çubuğu gövdenin ÜSTÜNE bindirmeli çizilir; son satır altında
        // kalmasın diye sabit boşluk (çubuk yokken de aynı → liste zıplamaz).
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final e = results[i];
          return DragSelectItem(
            index: i,
            child: FmEntryListTile(
              entry: e,
              selected: _selected.contains(e.path),
              selecting: _selecting,
              subtitle: e.isDir
                  ? p.dirname(e.path)
                  : '${FsPaths.humanSize(e.sizeBytes)} · ${p.dirname(e.path)}',
              onTap: () {
                if (_selecting) {
                  _toggle(e);
                } else {
                  _open(e);
                }
              },
              onCheck: () => _toggle(e),
              onMore: _selecting
                  ? null
                  : () async {
                      await showEntryActions(
                        context,
                        e,
                        allowReveal: true,
                        onReveal: _reveal,
                      );
                      if (mounted) _run(_controller.text);
                    },
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(FsEntry entry) async {
    if (entry.isDir) {
      _reveal(entry.path);
      return;
    }
    await EntryOpener.open(
      context,
      entry.path,
      siblings: _filtered.where((e) => !e.isDir).map((e) => e.path).toList(),
    );
  }

  void _reveal(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowserScreen(path: path),
    ));
  }
}
