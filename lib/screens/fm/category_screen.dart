import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/file_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/section_header.dart';
import 'browser_screen.dart';
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


  /// Belge türü süzgeci (PDF / Word / Excel / Slayt / Metin) gösterilsin mi?
  /// Kullanıcı isteği: "belgelerde filtre olmalı, PDF slayt text word vs
  /// ayırt edilebilmeli".
  final bool showDocKinds;

  /// **Eksiksiz** listeyi getiren yükleyici (bkz. `MediaLibrary`). Pano
  /// önbelleği kategori başına en yeni 800 dosyayla sınırlıdır; ekran anında
  /// açılsın diye önce o gösterilir, tam liste gelince yerine geçer.
  final Future<List<FsEntry>> Function()? loadAll;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.files,
    this.gridDefault = false,
    this.showDocKinds = false,
    this.loadAll,
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
  FmSort _sort = FmSort.date;
  bool _desc = true;

  /// Tarih/boyut/kaynak/tür süzgeci (kaynak çipleriyle aynı alanı yazar).
  FmFilter _filter = FmFilter.none;

  /// Seçili belge türü (null = tümü).
  DocKind? _docKind;

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
        if (all.length > _files.length) _files = all;
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FsEntry> get _sorted {
    final key = '${identityHashCode(_files)}|${_files.length}|$_query|'
        '${_filter.signature}|${_docKind?.name}|${_sort.name}|$_desc';
    final cached = _sortedCache;
    if (cached != null && _sortedKey == key) return cached;
    final sorted =
        FsScan.sort(_files, _sort, descending: _desc, foldersFirst: false);
    var filtered =
        _filter.apply(sorted, query: _query, tagsOf: FileTags.forPath);
    if (_docKind != null) {
      filtered = filtered
          .where((f) => FileService.kindForExtension(f.extension) == _docKind)
          .toList();
    }
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
          FmQuickFilters(
            source: _files,
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          if (widget.showDocKinds) _docKindChips(),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text(
                        context.t(_loadingAll
                            ? 'ph.loading'
                            : (_query.trim().isEmpty && !_filter.isActive
                                ? 'ph.cat_empty'
                                : 'ph.no_match')),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : DragSelectArea(
                    scrollController: _scroll,
                    isSelected: (i) =>
                        i >= 0 &&
                        i < files.length &&
                        _selected.contains(files[i].path),
                    onSelectRange: (a, b, sel) =>
                        _selectRange(files, a, b, sel),
                    child: _layout.isGrid ? _gridView(files) : _listView(files),
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

  PreferredSizeWidget _normalBar() => AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            // Sıralamanın ne olduğu yalnız süzgeç sayfası açılınca
            // görülüyordu — özet satıra alındı ("… · Tarihe göre ↓").
            MonoText(
              context.t('cat.summary', {
                'n': _sorted.length,
                'total': _files.length,
                'sort': '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
              }),
              size: 11,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('ph.search_in', {'title': widget.title}),
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
          IconButton(
            tooltip: context.t('ph.layout', {'name': context.t(_layout.labelKey)}),
            icon: Icon(fmLayoutIcon(_layout)),
            onPressed: () async {
              final picked = await showFmLayoutSheet(context, current: _layout);
              if (picked != null) setState(() => _layout = picked);
            },
          ),
        ],
      );

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
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
              icon: const Icon(Icons.clear),
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
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        // Sayaç EYLEMLE aynı kümeyi sayar (bkz. [_selectedEntries]).
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': files.length})),
        actions: [
          if (_selected.length == 1) ...[
            IconButton(
              tooltip: context.t('ph.select_above'),
              icon: const Icon(Icons.expand_less),
              onPressed: () => _selectFromAnchor(files, above: true),
            ),
            IconButton(
              tooltip: context.t('ph.select_below'),
              icon: const Icon(Icons.expand_more),
              onPressed: () => _selectFromAnchor(files, above: false),
            ),
          ],
          IconButton(
            tooltip: context.t(files.every((e) => _selected.contains(e.path))
                ? 'ph.clear_selection'
                : 'ph.select_all'),
            icon: Icon(files.every((e) => _selected.contains(e.path))
                ? Icons.deselect
                : Icons.select_all),
            onPressed: () => _toggleSelectAll(files),
          ),
        ],
      );


  /// Belge türü çipleri (PDF / Word / Excel / Slayt / Metin / Diğer).
  /// Boş tür gösterilmez; sayılar gerçek dosya sayısıdır.
  Widget _docKindChips() {
    final counts = <DocKind, int>{};
    for (final f in _files) {
      final kind = FileService.kindForExtension(f.extension);
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    // Sabit sıra: kullanıcı çiplerin yerini ezberleyebilsin (sayıya göre
    // sıralamak her açılışta yer değiştirmesine yol açardı).
    const order = [
      DocKind.pdf,
      DocKind.word,
      DocKind.spreadsheet,
      DocKind.slides,
      DocKind.text,
      DocKind.unknown,
    ];
    final kinds = order.where((k) => (counts[k] ?? 0) > 0).toList();
    if (kinds.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: ChoiceChip(
              label: Text(context.t('ph.all_count', {'n': _files.length})),
              selected: _docKind == null,
              onSelected: (_) => setState(() => _docKind = null),
            ),
          ),
          for (final k in kinds)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: ChoiceChip(
                label: Text(context.t('ph.chip_count', {
                  'label': context.t(k.labelKey),
                  'n': counts[k],
                })),
                selected: _docKind == k,
                onSelected: (_) => setState(() => _docKind = k),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listView(List<FsEntry> files) => ListView.builder(
        controller: _scroll,
        // Alt eylem çubuğu bindirmeli çizildiği için son satır onun altında
        // kalmasın diye sabit boşluk (çubuk yokken de aynı → zıplama olmaz).
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final e = files[i];
          return DragSelectItem(
            index: i,
            child: FmEntryListTile(
              entry: e,
              layout: _layout,
              selected: _selected.contains(e.path),
              selecting: _selecting,
              subtitle: '${FsPaths.humanSize(e.sizeBytes)} · '
                  '${p.dirname(e.path)}',
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
                      await showEntryActions(context, e,
                          allowReveal: true, onReveal: _reveal);
                      _dropMissing();
                    },
            ),
          );
        },
      );

  Widget _gridView(List<FsEntry> files) => LayoutBuilder(
        builder: (context, constraints) {
          const pad = Gap.sm;
          return GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(pad, pad, pad, 88),
            gridDelegate:
                fmGridDelegate(_layout, constraints.maxWidth - pad * 2),
            itemCount: files.length,
            itemBuilder: (context, i) {
              final e = files[i];
              return DragSelectItem(
                index: i,
                child: FmEntryGridTile(
                  entry: e,
                  layout: _layout,
                  selected: _selected.contains(e.path),
                  selecting: _selecting,
                  onTap: () {
                    if (_selecting) {
                      _toggle(e);
                    } else {
                      _open(e);
                    }
                  },
                ),
              );
            },
          );
        },
      );

  Future<void> _open(FsEntry e) => EntryOpener.open(
        context,
        e.path,
        siblings: _sorted.map((x) => x.path).toList(),
      );

  void _reveal(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowserScreen(path: path),
    ));
  }
}
