import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/ai_meaning_search.dart';
import '../../services/fm/content_indexer.dart';
import '../../services/fm/content_search.dart';
import '../../services/fm/saved_searches.dart';
import '../../widgets/app_dialog.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/search_history.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/smart_query.dart';
import '../../services/gemini_service.dart';
import '../../widgets/fm/fm_more_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_type_chips.dart';
import '../../models/fm_layout.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_file_list_view.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';
import '../../widgets/ai_key_gate.dart';

part 'search_screen/parts.dart';

/// Klasör altında özyinelemeli dosya arama (Türkçe-duyarlı).
///
/// Arama artık **dizin üzerinden** koşar ([SearchIndex]): depolama bir kez
/// derinlemesine taranır, sonraki her arama o dizinde yapılır — 100 bin
/// dosyalı bir telefonda her harfte diski gezmek saniyeler sürüyordu. Dizin
/// yoksa ilk arama canlı taramaya düşer (kullanıcı beklemez) ve arka planda
/// dizin kurulur.
class SearchScreen extends StatefulWidget {
  /// Aramanın kökü; **null = tüm depolama** (ana bellek + SD kart + USB).
  ///
  /// Panodan gelen arama artık null geçiyor: eskiden `FmEnv.primaryRoot`
  /// geçiliyordu ve "Tüm dosyalarda ara" yazmasına rağmen SD karttaki
  /// dosyalar sonuçlara HİÇ girmiyordu (kullanıcı 2026-09-02).
  final String? root;
  final String? rootLabel;

  /// Ekran **anlamla ara** (AI) kipinde mi açılsın? (Panodaki arama kutusunun
  /// ✦ düğmesi.)
  final bool meaning;

  const SearchScreen(
      {super.key, this.root, this.rootLabel, this.meaning = false});

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

  /// Tarih/boyut/kaynak/tür süzgeci ve sıralama (kullanıcı isteği 2026-07-29:
  /// "aramada sıralama seçenekleri lazım · aranan şeyler arama filtresi de
  /// olmalı").
  FmFilter _filter = FmFilter.none;

  /// **Kapsam** (Faz 17 / madde 8): klasörden açılan aramada "bu klasörde /
  /// her yerde" çipi. Her yerde = kök null (tüm birimler).
  bool _everywhere = false;
  String? get _root => _everywhere ? null : widget.root;

  /// **Dosya içinde arama** açık mı (2026-09-06 denetim turu).
  ///
  /// Ayrı bir kip, ad aramasının yanında bir seçenek değil: içeri bakmak
  /// dosyaları OKUMAK demek ve saniyeler sürebiliyor. Kullanıcı bunu
  /// bilerek istemeli.
  bool _inContent = false;

  /// **Anlamla ara** kipi (2026-10-23): sorgu AI ile eş anlamlı/ilgili
  /// sözcüklere genişletilir, sonuçlar cihazda sıralanır (bkz.
  /// [AiMeaningSearch]). Her tuşta değil, "Ara"ya basınca çalışır — istek
  /// başına kota harcanır.
  late bool _meaning = widget.meaning;
  MeaningPlan? _plan;
  Map<String, List<String>> _meaningMatched = const {};
  List<ContentHit> _contentHits = const [];
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
    SearchIndex.openSession(); // P10: dizin ekran açıkken bellekte
    // Geçmiş, kullanıcı yazmaya başlamadan önce (boş ekranda) gösteriliyor.
    unawaited(_loadSaved());
    SearchHistory.ensureOpenedLoaded().then((_) {
      if (mounted) setState(() {});
    });
    SearchHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SearchIndex.revision.removeListener(_onIndexChanged);
    SearchIndex.closeSession();
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
    if (_meaning) {
      // Yazarken AI'ya gidilmez; eski planın çipleri yeni metinle çelişmesin.
      if (_plan != null) setState(() => _plan = null);
      return;
    }
    // 250 ms: dizin sayesinde arama ucuzladı, eskisi (400 ms) fazla bekletiyor.
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _contentHits = const [];
        _searched = false;
        _searching = false;
        _smart = null;
      });
      return;
    }
    final token = ++_queryToken;
    if (_inContent) {
      await _runContent(q, token);
      return;
    }
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
        ? await SearchIndex.query(needle, root: _root, limit: 1000)
        : await SearchIndex.query('', root: _root, limit: 1000,
            matchAll: true);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _results = hits;
      _searching = false;
      _searched = true;
    });
  }

  /// Dosyaların İÇİNDE arama. Ad araması dizinden gelir (anlık); bu ise
  /// diski okur, o yüzden ayrı bir yol ve kendi durdurma ölçütü var.
  Future<void> _runContent(String query, int token) async {
    setState(() {
      _searching = true;
      _smart = null;
    });
    // Faz 41 / 3: içerik DİZİNİ hazırsa disk taranmaz (Office, PDF ve OCR
    // metni dahil); dizin arka planda artımlı tazelenir. İlk kez (dizin
    // boş) eski canlı tarama çalışır, dizin bu arada kurulur.
    final index = ContentIndexer.index;
    await index.load();
    unawaited(ContentIndexer.refresh());
    final List<ContentHit> hits;
    if (index.length > 0) {
      final found = await index.query(query, root: _root ?? FmEnv.primaryRoot);
      hits = [
        for (final h in found)
          ContentHit(
              path: h.path, line: h.line, snippet: h.snippet, total: h.total),
      ];
    } else {
      hits = await ContentSearch.search(
        _root ?? FmEnv.primaryRoot,
        query,
        // Sorgu değişirse tarama kendini durdursun: kullanıcı yazmaya devam
        // ederken eski taramanın diski okumaya devam etmesi hem yavaş hem
        // yanlış sonuç demek.
        isCancelled: () => token != _queryToken,
      );
    }
    if (!mounted || token != _queryToken) return;
    setState(() {
      _contentHits = hits;
      _results = [
        for (final hit in hits)
          ?FsEntry.ofPath(hit.path),
      ];
      _searching = false;
      _searched = true;
    });
  }

  /// Bir yolun içerik eşleşmesi (alt satırda "3 eşleşme · 12. satır").
  ContentHit? _contentHitOf(String path) {
    for (final hit in _contentHits) {
      if (hit.path == path) return hit;
    }
    return null;
  }

  /// Sonuç satırının alt yazısı: içerik aramasında eşleşme, ad aramasında
  /// boyut ve klasör.
  String _subtitleFor(FsEntry e) {
    if (e.isDir) return p.dirname(e.path);
    final terms = _meaning ? _meaningMatched[e.path] : null;
    if (terms != null && terms.isNotEmpty) {
      return '≈ ${terms.join(', ')} · ${FmLocation.subtitle(e.path, e.sizeBytes, e.modifiedMs, AppStrings.of(context).t, volumes: FmEnv.volumes)}';
    }
    final hit = _inContent ? _contentHitOf(e.path) : null;
    if (hit != null) {
      final head = AppStrings.of(context)
          .t('srch.content_hits', {'n': hit.total, 'line': hit.line});
      return '$head · ${hit.snippet}';
    }
    return FmLocation.subtitle(
        e.path, e.sizeBytes, e.modifiedMs, AppStrings.of(context).t,
        volumes: FmEnv.volumes);
  }

  List<FsEntry> get _filtered {
    // Anlamla aramada sıra = İLGİ (puan); tarih/ad sıralaması uygulanmaz.
    if (_meaning && _plan != null) {
      return [
        for (final e in _results)
          if (_filter.matches(e,
              tagsOf: FileTags.forPath, openedAtOf: OpenHistory.forPath))
            e,
      ];
    }
    final smart = _smart;
    final smartCategory = smart?.category;
    final list = [
      for (final e in _results)
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
            hintText: _meaning ? context.t('srch.meaning_hint') : context.t('srch.in_hint',
                {
                  'name': (_everywhere ? null : widget.rootLabel) ??
                      (_root == null
                          ? context.t('fm.all_files')
                          : p.basename(widget.root!))
                }),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
          onSubmitted: (q) {
            // **Geçmişe yalnız "bitirilmiş" sorgular giriyor** (arama
            // düğmesi ya da bir sonucu açmak): her tuş vuruşunu kaydetmek
            // listeyi "f", "fa", "fat" gibi ön eklerle doldururdu.
            unawaited(SearchHistory.record(q));
            unawaited(_meaning ? _runMeaning(q) : _run(q));
          },
        ),
        actions: [
          // Faz 41 / 3: sorguyu adlandırıp kaydet.
          if (_controller.text.trim().length >= 2)
            IconButton(
              key: const ValueKey('srch-save'),
              tooltip: context.t('svs.save'),
              icon: const Icon(AppIcons.bookmark),
              onPressed: _saveSearch,
            ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(AppIcons.close),
              onPressed: () {
                _controller.clear();
                _run('');
              },
            ),
          // **Anlamla ara** (AI) — görünür düğme, menünün içinde değil.
          IconButton(
            key: const ValueKey('srch-meaning'),
            tooltip: context.t(_meaning ? 'srch.meaning_off' : 'srch.meaning'),
            isSelected: _meaning,
            style: _meaning
                ? IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer)
                : null,
            icon: const Icon(AppIcons.ai),
            onPressed: _toggleMeaning,
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
          if (_meaning) _meaningBanner(),
          if (_smart != null && !_meaning) _smartChips(),
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

  /// Kayıtlı aramalar (Faz 41 / 3).
  List<SavedSearch> _saved = const [];

  /// "Aramadan açılanlar" tür süzgeci (null = tümü).
  FmCategory? _openedKind;

  Future<void> _loadSaved() async {
    final v = await SavedSearches.load();
    if (mounted) setState(() => _saved = v);
  }

  Future<void> _saveSearch() async {
    final q = _controller.text.trim();
    final name = await showAppPrompt(context,
        title: context.t('svs.save'), label: context.t('svs.name'), initial: q);
    if (name == null || name.trim().isEmpty || !mounted) return;
    final next = SavedSearches.add(
        _saved, SavedSearch(name.trim(), q, inContent: _inContent));
    setState(() => _saved = next);
    await SavedSearches.store(next);
    if (mounted) showSnack(context, context.t('svs.saved', {'name': name.trim()}));
  }

  void _runSaved(SavedSearch s) {
    setState(() {
      _inContent = s.inContent;
      _controller.text = s.query;
    });
    unawaited(_run(s.query));
  }

  Future<void> _removeSaved(SavedSearch s) async {
    final next = SavedSearches.remove(_saved, s);
    setState(() => _saved = next);
    await SavedSearches.store(next);
  }

  /// Bölüm dosyası (extension) `setState`i doğrudan çağıramaz (korumalı üye).
  void _update(VoidCallback fn) => setState(fn);
}
