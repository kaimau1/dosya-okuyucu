import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/list_memory.dart';
import '../../services/fm/open_history.dart';
import '../../core/app_icons.dart';
import '../../widgets/fm/fm_file_list_view.dart';
import '../../widgets/motion.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_list_controls.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/fm/fm_type_chips.dart';
import 'browser_screen.dart';
import 'category_tools.dart';
import 'entry_actions.dart';

/// Bir kategorinin (Görüntüler / Videolar / Ses / Belgeler / Uygulamalar /
/// Arşivler / Yeni dosyalar) tüm depolamadaki dosyaları.
///
/// Liste, panonun tek geçişli taramasından ([StorageIndex]) gelir — bu ekran
/// yeniden tarama YAPMAZ, anında açılır. Aynı sebeple buradaki arama da
/// bellekte süzmedir: yazdıkça anında daralır, disk okunmaz.
class CategoryScreen extends StatefulWidget {
  final String title;
  final List<FsEntry> files;

  /// Kategori ızgarada görsel ise küçük resimli ızgara varsayılan olur.
  final bool gridDefault;

  /// [ListMemory] anahtarı (ör. `new_files`): verilirse sıralama/yerleşim
  /// kalıcı, tür süzgeci oturum boyunca hatırlanır (K17). `null` = hafızasız
  /// (aynı ekran farklı kategorilerle açılıyor; başlığa göre anahtar dil
  /// değişince kayardı).
  ///
  /// **Belge türü çipleri artık bayrak değil** (Faz 13): eski `showDocKinds`
  /// yalnız Belgeler kutusunda açıktı ve aynı ekranı açan *Yeni gelenler*
  /// PDF çipini kaybediyordu. Tür çipleri listede iki ya da daha çok tür
  /// varsa kendiliğinden çıkar ([FmTypeChips]).
  final String? memoryId;

  /// **Eksiksiz** listeyi getiren yükleyici (bkz. `MediaLibrary`). Pano
  /// önbelleği kategori başına en yeni 800 dosyayla sınırlıdır; ekran anında
  /// açılsın diye önce o gösterilir, tam liste gelince yerine geçer.
  final Future<List<FsEntry>> Function()? loadAll;

  /// [loadAll] sonucu listenin **yerine geçsin mi**?
  ///
  /// Varsayılan davranış "yalnız daha uzunsa değiştir": pano önbelleği kırpık
  /// olduğu için tam liste daima daha uzundur ve kırpık listenin üstüne
  /// yazması istenir. Ama sabit sınırlı bir liste tazeleniyorsa (bkz.
  /// `NewFilesScreen` — hep 100 dosya) uzunluk aynı kalır ve taze sonuç
  /// sessizce yutulurdu.
  final bool replaceOnLoad;

  /// Ekran hangi sıralamayla açılsın (varsayılan: tarih, yeniden eskiye).
  ///
  /// Bellek Analizi'ndeki tür çubuklarından açılan liste **boyuta göre** açılır
  /// (kullanıcı isteği 2026-08-27: *"türlerin üzerine tıklayınca ona özel sayfa
  /// açılsın ve içerikler boyutlarına göre sıralanıp gösterilsin"*). Kullanıcı
  /// içeride sıralamayı değiştirebilir — bu yalnız açılış değeri.
  final FmSort initialSort;

  /// [initialSort] azalan mı? Boyutta "en büyük üstte", tarihte "en yeni
  /// üstte" demek.
  final bool initialDescending;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.files,
    this.gridDefault = false,
    this.memoryId,
    this.loadAll,
    this.replaceOnLoad = false,
    this.initialSort = FmSort.date,
    this.initialDescending = true,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late List<FsEntry> _files = [...widget.files];
  final Set<String> _selected = {};

  /// Sürükleyerek seçimde kenarda otomatik kaydırma için (liste ve ızgara aynı
  /// anda mount edilmez → tek denetleyici yeter).
  final ScrollController _scroll = ScrollController();
  late FmLayout _layout = widget.gridDefault ? FmLayout.grid3 : FmLayout.list;

  void _setLayout(FmLayout layout) {
    setState(() => _layout = layout);
    final id = widget.memoryId;
    if (id != null) ListMemory.saveLayout(id, layout);
  }
  late FmSort _sort = widget.initialSort;
  late bool _desc = widget.initialDescending;

  /// Tarih/boyut/kaynak/tür süzgeci (kaynak ve tür çipleriyle aynı alanı
  /// yazar).
  late FmFilter _filter = widget.memoryId == null
      ? FmFilter.none
      : ListMemory.filterOf(widget.memoryId!);

  void _setFilter(FmFilter f) => setState(() {
        _filter = f;
        final id = widget.memoryId;
        if (id != null) ListMemory.rememberFilter(id, f);
      });

  void _setSort(FmSort sort, bool desc) {
    setState(() {
      _sort = sort;
      _desc = desc;
    });
    final id = widget.memoryId;
    if (id != null) ListMemory.saveSort(id, sort, desc);
  }

  final _searchController = TextEditingController();
  bool _searching = false;
  bool _loadingAll = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  /// Seçili **ve ekranda görünen** girdiler.
  ///
  /// `_files` (tüm liste) DEĞİL `_sorted` (süzgeçten geçmiş liste) üzerinden
  /// çözülür: süzgeç/belge türü çipleri seçim sürerken de canlı ve seçim
  /// budanmıyordu → "Tümünü seç" sonrası bir çipe dokunmak, ekranda görünmeyen
  /// dosyaları da silen bir "Sil" düğmesi bırakıyordu (2026-07-29 sadakat
  /// denetimi, 2. tur). Seçim kümesi korunur, yalnız eylem/sayı görünenle
  /// sınırlıdır. Ayrıntılı gerekçe: `photos_screen.dart`taki aynı getter.
  List<FsEntry> get _selectedEntries {
    if (_selected.isEmpty) return const [];
    return [
      for (final e in _sorted)
        if (_selected.contains(e.path)) e,
    ];
  }

  // Süzme/sıralama önbelleği: `build` her seçim dokunuşunda çalışıyor, 20 bin
  // dosyada her karede yeniden süzmek uygulamayı kastırıyordu (2026-07-29).
  List<FsEntry>? _sortedCache;
  String? _sortedKey;
  Map<MediaBucket, int>? _bucketCache;
  Map<String, int>? _extCache;
  Map<ChatMediaKind, int>? _chatKindCache;
  int? _countsKey;

  @override
  void initState() {
    super.initState();
    // Başka bir ekranda silinen/taşınan dosya burada durmasın.
    FsEvents.version.addListener(_dropMissing);
    // Etiketler (kişi/grup süzgeci) hazır olunca çipler görünsün.
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // Açılış geçmişi hazır olunca "açılmış/açılmamış" çiplerinin sayıları
    // doğrulansın — yüklenmeden `forPath` her dosya için null döner ve ölçüt
    // yalnız atime'a bakar (eksik ama yanlış değil).
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    final id = widget.memoryId;
    if (id != null) {
      ListMemory.load(id).then((saved) {
        if (!mounted) return;
        setState(() {
          _sort = saved.sort ?? _sort;
          _desc = saved.descending ?? _desc;
          _layout = saved.layout ?? _layout;
        });
      });
    }
    _loadAll();
  }

  /// Tam listeyi arka planda getirir (pano önbelleği kırpılmıştır).
  Future<void> _loadAll() async {
    final loader = widget.loadAll;
    if (loader == null) return;
    setState(() => _loadingAll = true);
    try {
      final all = await loader();
      if (!mounted) return;
      setState(() {
        // `replaceOnLoad` listeyi gerçekten DEĞİŞTİRMEK isteyen ekranlar için
        // (ör. daraltılmış bir kapsamdan tam kapsama geçiş). Onun dışında
        // **birleştiriliyor**: eksiksiz liste arama dizininden geliyor ve
        // dizin bayatsa yeni dosyaları içermiyor — yerine geçseydi az önce
        // eklenen dosya listeden düşerdi (kullanıcı 2026-09-03: *"görülüp
        // geri gidiyor"*).
        _files = widget.replaceOnLoad ? all : _mergeByPath(_files, all);
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  /// İki listeyi yola göre teke indirir; ilkinin sırası korunur.
  static List<FsEntry> _mergeByPath(List<FsEntry> current, List<FsEntry> more) {
    if (current.isEmpty) return more;
    final seen = {for (final e in current) e.path};
    final out = [...current];
    for (final e in more) {
      if (seen.add(e.path)) out.add(e);
    }
    return out;
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FsEntry> get _sorted {
    // Açılış geçmişi ekran çizildikten SONRA diskten gelir; anahtara girmezse
    // önbellek eski (geçmişsiz) sonucu döndürüp donardı.
    final key = '${identityHashCode(_files)}|${_files.length}|$_query|'
        '${_filter.signature}|${_sort.name}|$_desc|'
        '${OpenHistory.revision}';
    final cached = _sortedCache;
    if (cached != null && _sortedKey == key) return cached;
    final sorted =
        FsScan.sort(_files, _sort, descending: _desc, foldersFirst: false);
    final filtered = _filter.apply(
      sorted,
      query: _query,
      tagsOf: FileTags.forPath,
      // "6 aydır açılmamış" / "son 6 ayda açılanlar" ölçütleri uygulamanın
      // kendi açılış kaydını da sayar (bkz. `FmFilter.lastSeenMs`).
      openedAtOf: OpenHistory.forPath,
    );
    _sortedCache = filtered;
    _sortedKey = key;
    return filtered;
  }

  /// Kaynak/uzantı/mesajlaşma türü sayıları — liste değişmedikçe yeniden
  /// sayılmaz.
  void _ensureCounts() {
    final key = identityHashCode(_files);
    if (_countsKey == key && _bucketCache != null) return;
    _bucketCache = bucketCounts(_files.map((f) => f.path));
    _extCache = extensionCounts(_files);
    _chatKindCache = chatKindCounts(_files);
    _countsKey = key;
  }

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  /// Basılı tutup kaydırma: görünen sıradaki [start]..[end] aralığı.
  void _selectRange(List<FsEntry> visible, int start, int end, bool select) {
    setState(() {
      for (var i = start; i <= end; i++) {
        if (i < 0 || i >= visible.length) continue;
        if (select) {
          _selected.add(visible[i].path);
        } else {
          _selected.remove(visible[i].path);
        }
      }
    });
  }

  /// Tek dosya seçiliyken görünürdeki konumuna göre üstündekileri/
  /// altındakileri de seçer (Google Fotoğraflar'daki "buraya kadar seç"
  /// jesti). Kullanıcı isteği (2026-07-29): *"1 görüntü seçtim, onun altında
  /// kalanları seç, onun üstünde kalanları seç butonu olsun"*.
  void _selectFromAnchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final anchorIndex = visible.indexWhere((e) => e.path == _selected.first);
    if (anchorIndex < 0) return;
    _selectRange(
      visible,
      above ? 0 : anchorIndex,
      above ? anchorIndex : visible.length - 1,
      true,
    );
  }

  /// Toplu seçme: hepsi seçiliyse kaldırır, değilse görünen tümünü seçer.
  void _toggleSelectAll(List<FsEntry> visible) {
    setState(() {
      if (visible.every((e) => _selected.contains(e.path))) {
        _selected.removeAll(visible.map((e) => e.path));
      } else {
        _selected.addAll(visible.map((e) => e.path));
      }
    });
  }

  /// Silme/taşıma sonrası: listeyi diskteki gerçekle tazele.
  /// Var olma denetimi isolate'te — liste on binlerce girdi olabilir.
  Future<void> _dropMissing() async {
    if (!mounted) return;
    final alive = await FsScan.pruneMissing(_files);
    if (!mounted) return;
    setState(() {
      _files = alive;
      _selected.removeWhere((s) => !_files.any((e) => e.path == s));
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = _sorted;
    // Seçili+görünen küme build başına BİR kez hesaplanır (bkz.
    // `photos_screen.dart`taki aynı not — 20 bin dosyada perf).
    final selectedEntries = _selectedEntries;
    return Scaffold(
      appBar: _selecting
          ? _selectionBar(files, selectedEntries)
          : (_searching ? _searchBar() : _normalBar()),
      // Stack: alt eylem çubuğu görünürken gövde yüksekliği DEĞİŞMESİN
      // (bottomNavigationBar kullanılırsa liste zıplıyor — 2026-07-29 hatası).
      // Üstteki çip satırları da seçim sırasında KALIR: gizlenince liste
      // yukarı kayıyor ve "basılı tutunca zıpladı" oluyordu (aynı gün, ikinci
      // rapor). Ayrıca seçim yaparken süzmeye devam edilebiliyor.
      body: Stack(
        children: [
          Column(
        children: [
          if (_loadingAll) const LinearProgressIndicator(minHeight: 2),
          // **Hızlı süzgeç çipleri** (2026-08-05 kullanıcı isteği): kaynak
          // (WhatsApp/Telegram/Kamera…), büyük dosyalar ve "6 aydır
          // açılmamış" tek dokunuşta. Eskiden kaynak çipleri `showSources`
          // bayrağının arkasındaydı ve HİÇBİR çağıran onu açmıyordu — yani
          // belgelerde WhatsApp süzgeci kodda vardı ama ekranda yoktu.
          // **TEK çip satırı** (2026-08-09): belge türü çipleri eskiden ikinci
          // bir satırdaydı; iki satır birlikte listeden 92 dp çalıyordu.
          // **Tür çipleri EN BAŞTA** (Faz 13): "yalnız PDF'ler" tek dokunuş;
          // kaynak/birim/açılma çipleri aynı satırda, türlerden SONRA.
          // **TEK süzgeç satırı** (2026-10-28, kullanıcı ekran görüntüsüyle:
          // *"üst filtre alanını baştan tasarla"*): türler artık tek açılır
          // hap (levhada büyük kutular), Sırala · Süzgeç · Analiz AYNI
          // satırda; ardından hızlı çipler (kaynak, açılma, büyük) ve
          // etiketler. İki satır (~100 dp) → bir satır (46 dp). Görünmeyen
          // etkin ölçütler yalnız varken altta kaldırılabilir çip olarak.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FmQuickFilters(
                    source: _files,
                    filter: _filter,
                    onChanged: _setFilter,
                    leading: [
                      ...FmTypeChips.forEntries(
                        context,
                        source: _files,
                        filter: _filter,
                        onChanged: _setFilter,
                        query: _query,
                        tagsOf: FileTags.forPath,
                        openedAtOf: OpenHistory.forPath,
                        cacheSalt: '${OpenHistory.revision}',
                      ),
                      ..._controls.pills(context),
                    ],
                    // Etiket çipleri (2026-10-23): etiketlenmiş dosya varsa en
                    // sık altı etiket aynı satırda — "#Fatura" tek dokunuş.
                    trailing: _tagChips(),
                  ),
                  FmActiveCriteria(
                    filter: _filter,
                    onChanged: _setFilter,
                    padding: const EdgeInsetsDirectional.only(start: 12),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FmFileListView(
              entries: files,
              layout: _layout,
              onLayoutChange: _setLayout,
              selected: _selected,
              controller: _scroll,
              loading: _loadingAll,
              groupBy: _sort,
              bottomPadding: 88,
              onOpen: _open,
              onToggle: _toggle,
              onSelectRange: (a, b, sel) => _selectRange(files, a, b, sel),
              // Tam yol yerine kaynak adı ("WhatsApp", "İndirilenler") —
              // bkz. [FmLocation] (2026-09-23 tasarım turu).
              subtitle: (e) => FmLocation.subtitle(
                  e.path, e.sizeBytes, e.modifiedMs, context.t,
                  volumes: FmEnv.volumes),
              onMore: (e) async {
                await showEntryActions(context, e,
                    allowReveal: true, onReveal: _reveal);
                _dropMissing();
              },
              empty: FmEmptyState(
                icon: _query.trim().isEmpty && !_filter.isActive
                    ? AppIcons.emptyFolder
                    : AppIcons.noMatch,
                title: context.t(_query.trim().isEmpty && !_filter.isActive
                    ? 'ph.cat_empty'
                    : 'ph.no_match'),
                // "Bu süzgeçle dosya yok" → tek dokunuşla temizle (Faz 13).
                action: _filter.isActive
                    ? TextButton(
                        key: const ValueKey('clear-filter'),
                        onPressed: () => _setFilter(FmFilter.none),
                        child: Text(context.t('list.filter_clear')),
                      )
                    : null,
              ),
            ),
          ),
        ],
          ),
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FmSelectionBar(
                selected: selectedEntries,
                onChanged: () async {
                  // "Arka plana al" ile ekran kapanmış olabilir: `FmSelectionBar`
                  // işini bitirdiğinde bu State artık ölü olabiliyor ve
                  // `setState` "called after dispose" hatası atıyordu
                  // (2026-07-29 sadakat denetimi, 2. tur).
                  if (!mounted) return;
                  setState(_selected.clear);
                  await _dropMissing();
                },
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _normalBar() {
    final shown = _sorted;
    final theme = Theme.of(context);
    final bytes = _bytesOf(shown);
    final count = shown.length == _files.length
        ? context.t('lc.count', {'n': shown.length})
        : context.t('lc.count_of', {'n': shown.length, 'total': _files.length});
    return AppBar(
      // Başlık + **özet satırı** (2026-10-23 yeniden tasarım): "161 öğe ·
      // 220 MB"; süzgeç açıksa "42 / 161 öğe · 33 MB" — sayı artık listenin
      // üstündeki şeritte soluk bir yazı değil, ekranın kimliğinin parçası.
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            bytes > 0 ? '$count · ${FsPaths.humanSize(bytes)}' : count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.t('ph.search_in', {'title': widget.title}),
          icon: const Icon(AppIcons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          tooltip: context.t('ph.layout', {'name': context.t(_layout.labelKey)}),
          icon: Icon(fmLayoutIcon(_layout)),
          onPressed: () async {
            final picked = await showFmLayoutSheet(context, current: _layout);
            if (picked != null) _setLayout(picked);
          },
        ),
      ],
    );
  }

  /// Görünen listenin toplam boyutu (liste değişmedikçe yeniden toplanmaz).
  int _bytesOf(List<FsEntry> shown) {
    final key = identityHashCode(shown);
    if (_bytesKey == key) return _bytesCache;
    _bytesKey = key;
    return _bytesCache = shown.fold<int>(0, (s, e) => s + e.sizeBytes);
  }

  int? _bytesKey;
  int _bytesCache = 0;

  /// Sırala · Süzgeç · Analiz hapları (süzgeç satırına katılır).
  FmListControls get _controls => FmListControls(
        sort: _sort,
        descending: _desc,
        onSort: _setSort,
        filter: _filter,
        onFilterChanged: _setFilter,
        onOpenFilter: _openFilterSheet,
        onTools: _openTools,
      );

  /// "Analiz ve düzenle" levhası — görünen (süzülmüş) listeye uygulanır.
  Future<void> _openTools() => showCategoryTools(
        context,
        title: widget.title,
        visible: _sorted,
        onChanged: () async {
          if (mounted) setState(() => _sortedCache = null);
        },
      );

  /// En sık altı etiketin çipi (yalnız bu listede etiketli dosya varsa).
  List<Widget> _tagChips() {
    final counts = <String, int>{};
    for (final e in _files) {
      for (final t in FileTags.forPath(e.path)) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];
    final top = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6);
    return [
      for (final e in top)
        FmChip(
          icon: AppIcons.tag,
          label: e.key,
          count: e.value,
          selected: _filter.tags.contains(e.key),
          onTap: () => _setFilter(_filter.toggleTag(e.key)),
        ),
    ];
  }

  /// Süzgeç ve sıralama sayfası (tarih aralığı, boyut, kaynak, tür).
  Future<void> _openFilterSheet() async {
    _ensureCounts();
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: _extCache ?? const {},
      buckets: _bucketCache ?? const {},
      chatKinds: _chatKindCache ?? const {},
      tags: FileTags.counts(),
      showDuplicateSwitch: true,
    );
    if (result == null || !mounted) return;
    _setFilter(result.filter);
    _setSort(result.sort, result.descending);
  }

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.back),
          onPressed: _closeSearch,
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: context.t('ph.search_in_hint', {'title': widget.title}),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(AppIcons.close),
              onPressed: () => setState(() {
                _query = '';
                _searchController.clear();
              }),
            ),
          // Arama açıkken de süzgeç erişilebilir: "adında tatil geçen, geçen
          // ay çekilmiş videolar" tek adımda daralsın.
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        ],
      );

  /// Seçim üst çubuğu **sade**: sayaç + tümünü seç. Eylemler alttaki
  /// [FmSelectionBar]'da (proje kuralı: üstte yalnız altta karşılığı OLMAYAN).
  PreferredSizeWidget _selectionBar(
          List<FsEntry> files, List<FsEntry> selectedEntries) =>
      AppBar(
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => setState(_selected.clear),
        ),
        // Sayaç EYLEMLE aynı kümeyi sayar (bkz. [_selectedEntries]).
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': files.length})),
        actions: [
          FmSelectionActions(
            allSelected: files.every((e) => _selected.contains(e.path)),
            single: _selected.length == 1,
            onToggleAll: () => _toggleSelectAll(files),
            onAbove: () => _selectFromAnchor(files, above: true),
            onBelow: () => _selectFromAnchor(files, above: false),
          ),
        ],
      );

  Future<void> _open(FsEntry e) => EntryOpener.open(
        context,
        e.path,
        siblings: _sorted.map((x) => x.path).toList(),
      );

  void _reveal(String path) {
    Navigator.of(context).push(browserRoute(BrowserScreen(path: path)));
  }
}
