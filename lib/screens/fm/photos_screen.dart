import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../models/photo_group.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';
import 'similar_screen.dart';

/// **Fotoğraflar** — Google Fotoğraflar tarzı zaman ekseni.
///
/// Kullanıcı isteği (2026-07-25): "görsellerde Google Fotoğraflar gibi
/// görünebilir; aylara, yıllara, günlere göre ayırma."
///
/// Tasarım notları:
/// - Dosyalar **değiştirilme tarihine göre** yeniden eskiye gruplanır; her
///   grup yapışkan (pinned) bir başlıkla ayrılır → uzun listede hangi güne
///   bakıldığı hep görünür.
/// - Küçük resimler **tam kare** çizilir (ad yazılmaz, çerçeve yoktur):
///   fotoğraf ızgarasında dosya adı gürültüdür, göz resme bakar.
/// - Seçim, sürükleyerek seçim ve "gruptaki hepsini seç" desteklenir; seçim
///   indeksi gruplar boyunca DÜZ (flat) yürür, yoksa parmakla sürüklerken
///   grup sınırında aralık hesabı kopardı.
class PhotosScreen extends StatefulWidget {
  final String title;
  final List<FsEntry> files;

  /// Kaynak (Kamera / WhatsApp / Ekran görüntüsü …) çipleri gösterilsin mi?
  final bool showSources;

  /// **Eksiksiz** listeyi getiren yükleyici (bkz. `MediaLibrary`).
  ///
  /// [files] panonun önbelleğinden gelir ve kategori başına en yeni 800
  /// dosyayla sınırlıdır — ekran anında açılsın diye önce o gösterilir, tam
  /// liste arka planda gelince yerine geçer. Kullanıcı hatası 2026-07-29:
  /// "videolarda tüm videolar görünmüyor".
  final Future<List<FsEntry>> Function()? loadAll;

  const PhotosScreen({
    super.key,
    required this.title,
    required this.files,
    this.showSources = true,
    this.loadAll,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

/// Bir zaman grubu: başlık + o gruba düşen dosyalar (düz indeksleriyle).
class _Section {
  final String title;
  final List<FsEntry> files;

  /// Grubun ilk dosyasının düz listedeki indeksi.
  final int startIndex;
  const _Section(this.title, this.files, this.startIndex);
}

class _PhotosScreenState extends State<PhotosScreen> {
  late List<FsEntry> _files = [...widget.files];
  final Set<String> _selected = {};
  final ScrollController _scroll = ScrollController();
  final _searchController = TextEditingController();

  /// Galeride yinelenen kopyalar **varsayılan olarak gizli**: WhatsApp aynı
  /// görseli 2-3 klasöre yazıyor ve ızgara "aynı resimden 3 tane" gösteriyordu
  /// (kullanıcı hatası 2026-07-29). Gizleme sessiz değil — kaç kopyanın
  /// gizlendiği ekranda yazar ve süzgeç sayfasından kapatılabilir.
  FmFilter _filter = const FmFilter(hideDuplicates: true);
  FmSort _sort = FmSort.date;
  bool _desc = true;
  bool _searching = false;
  bool _loadingAll = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  /// Seçili girdiler. **Haritayla** bulunur: 20 bin dosyalık listede her
  /// karede `where(...)` gezmek seçim çubuğunu kastırıyordu.
  List<FsEntry> get _selectedEntries {
    final key = identityHashCode(_files);
    if (_byPathKey != key || _byPathCache == null) {
      _byPathCache = {for (final e in _files) e.path: e};
      _byPathKey = key;
    }
    final map = _byPathCache!;
    return [
      for (final path in _selected)
        if (map[path] != null) map[path]!,
    ];
  }

  // ── Önbellekler ───────────────────────────────────────────────────────────
  // Süzme/sıralama/gruplama 20 bin dosyada pahalıdır ve `build` her seçim
  // dokunuşunda çalışır. Girdiler değişmediyse sonuç yeniden hesaplanmaz
  // (kullanıcı 2026-07-29: "uygulama biraz kasmaya başladı").
  List<FsEntry>? _visibleCache;
  String? _visibleKey;
  List<_Section>? _sectionsCache;
  String? _sectionsKey;
  Map<String, FsEntry>? _byPathCache;
  int? _byPathKey;
  Map<MediaBucket, int>? _bucketCache;
  Map<String, int>? _extCache;
  Map<ChatMediaKind, int>? _chatKindCache;
  int? _countsKey;

  /// Süzgeç yüzünden gizlenen kopya sayısı (ekranda yazılır).
  int _hiddenDuplicates = 0;

  /// Zaman ekseni yalnız TARİHE göre sıralamada anlamlıdır: ada göre sıralı
  /// bir listeyi güne bölmek başlıkları rastgele tekrar ettirirdi.
  bool get _timelineMode => _sort == FmSort.date;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_dropMissing);
    // Etiketler (kişi/grup süzgeci) diskten okunur; hazır olunca çipler
    // görünsün diye yeniden çizilir.
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Tam listeyi arka planda getirir (pano önbelleği kırpılmıştır).
  Future<void> _loadAll() async {
    final loader = widget.loadAll;
    if (loader == null) return;
    setState(() => _loadingAll = true);
    try {
      final all = await loader();
      if (!mounted) return;
      // Kısa liste dönerse (dizin bozuk/boş) elimizdekini KORU: kullanıcıya
      // gösterilen dosya sayısı azalmamalı.
      setState(() {
        if (all.length > _files.length) _files = all;
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _dropMissing() async {
    if (!mounted) return;
    // 20 bin girdide ana izlekte `statSync` listeyi kilitler → isolate.
    final alive = await FsScan.pruneMissing(_files);
    if (!mounted) return;
    setState(() {
      _files = alive;
      _selected.removeWhere((s) => !_files.any((e) => e.path == s));
    });
  }

  /// Süzülmüş ve sıralı dosyalar (düz liste). Sonuç önbelleklenir.
  List<FsEntry> get _visible {
    final key = '${identityHashCode(_files)}|${_files.length}|$_query|'
        '${_filter.signature}|${_sort.name}|$_desc';
    final cached = _visibleCache;
    if (cached != null && _visibleKey == key) return cached;
    // Yinelenen ayıklaması SIRALAMADAN SONRA anlamlı olsun diye önce sıralanır:
    // "en yeni kopya kalsın" gibi bir tercihte hangi kopyanın kaldığı sıraya
    // bağlıdır (apply listedeki İLK kopyayı tutar).
    final sorted =
        FsScan.sort(_files, _sort, descending: _desc, foldersFirst: false);
    final list =
        _filter.apply(sorted, query: _query, tagsOf: FileTags.forPath);
    // Kaç kopya gizlendi? (Süzgeci kopyasız hâliyle uygulayıp farkı alırız.)
    _hiddenDuplicates = _filter.hideDuplicates
        ? _filter
                .withHideDuplicates(false)
                .apply(sorted, query: _query, tagsOf: FileTags.forPath)
                .length -
            list.length
        : 0;
    _visibleCache = list;
    _visibleKey = key;
    return list;
  }

  /// Düz listeyi zaman gruplarına böler (sıra korunur → indeksler düz kalır).
  /// Sonuç önbelleklenir: gruplama listenin tamamını gezer.
  List<_Section> _sections(List<FsEntry> visible, PhotoGroup group) {
    final cacheKey =
        '${identityHashCode(visible)}|${visible.length}|${group.name}';
    final cached = _sectionsCache;
    if (cached != null && _sectionsKey == cacheKey) return cached;
    final out = <_Section>[];
    String? key;
    var buffer = <FsEntry>[];
    var start = 0;
    for (var i = 0; i < visible.length; i++) {
      final e = visible[i];
      final k = photoGroupKey(e.modifiedMs, group);
      if (k != key) {
        if (buffer.isNotEmpty) {
          out.add(_Section(
              photoGroupTitle(buffer.first.modifiedMs, group), buffer, start));
        }
        key = k;
        buffer = [];
        start = i;
      }
      buffer.add(e);
    }
    if (buffer.isNotEmpty) {
      out.add(_Section(
          photoGroupTitle(buffer.first.modifiedMs, group), buffer, start));
    }
    _sectionsCache = out;
    _sectionsKey = cacheKey;
    return out;
  }

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

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
  ///
  /// "Üstünde/altında" **ekrandaki sıraya** göredir (mevcut sıralama/filtre
  /// ne olursa olsun): seçili dosyadan önceki indeksler üstte, sonrakiler
  /// altta görünür.
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

  void _toggleSection(_Section section) {
    final all = section.files.every((e) => _selected.contains(e.path));
    setState(() {
      if (all) {
        _selected.removeAll(section.files.map((e) => e.path));
      } else {
        _selected.addAll(section.files.map((e) => e.path));
      }
    });
  }

  void _toggleSelectAll(List<FsEntry> visible) {
    setState(() {
      if (visible.every((e) => _selected.contains(e.path))) {
        _selected.removeAll(visible.map((e) => e.path));
      } else {
        _selected.addAll(visible.map((e) => e.path));
      }
    });
  }

  Future<void> _open(FsEntry e, List<FsEntry> visible) => EntryOpener.open(
        context,
        e.path,
        siblings: visible.map((x) => x.path).toList(),
      );

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final layout = appState.fmPhotoLayout;
    final group = appState.fmPhotoGroup;
    final visible = _visible;
    final sections = _timelineMode
        ? _sections(visible, group)
        : [_Section('${visible.length} dosya · ${_sort.label}', visible, 0)];

    return Scaffold(
      appBar: _selecting
          ? _selectionBar(visible)
          : (_searching ? _searchBar() : _normalBar(appState)),
      // **Stack**, bottomNavigationBar DEĞİL: alt çubuk görünür/kaybolur
      // olduğunda gövdenin yüksekliği değişirse ızgara yeniden yerleşiyor ve
      // liste zıplıyordu (kullanıcı hatası 2026-07-29: "seçince sayfa
      // zıplıyor"). Üste bindirince görünüm alanı sabit kalır.
      //
      // **Üstteki satırlar seçim sırasında da DURUR** (2026-07-29, ikinci
      // rapor: "video basılı tutup seçtiğimde zıplama oluyor"). Alt panel
      // bindirmeli çizildiği için zıplatmıyordu; asıl neden bu satırların
      // `!_selecting` ile kaybolup ızgarayı yukarı çekmesiydi. Kalmaları
      // ayrıca işe yarıyor: seçim yaparken kaynağa/güne göre daraltılabiliyor.
      body: Stack(
        children: [
          Column(
        children: [
          if (_loadingAll) const LinearProgressIndicator(minHeight: 2),
          if (_timelineMode) _groupChips(appState, group),
          if (widget.showSources) _sourceChips(),
          if (_hiddenDuplicates > 0) _duplicateNotice(),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text(
                        _loadingAll
                            ? 'Dosyalar yükleniyor…'
                            : (_query.trim().isEmpty && !_filter.isActive
                                ? 'Burada gösterilecek dosya yok.'
                                : 'Aramanıza/filtrenize uyan dosya yok.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : DragSelectArea(
                    scrollController: _scroll,
                    isSelected: (i) =>
                        i >= 0 &&
                        i < visible.length &&
                        _selected.contains(visible[i].path),
                    onSelectRange: (a, b, sel) =>
                        _selectRange(visible, a, b, sel),
                    child: _timeline(sections, visible, layout),
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
                selected: _selectedEntries,
                onChanged: () async {
                  setState(_selected.clear);
                  await _dropMissing();
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Gizlenen kopyaları **gerçekten** siler.
  ///
  /// Gizleme ad+boyut tahminine dayanır; SİLME asla tahmine dayanamaz →
  /// adaylar önce bayt bayt doğrulanır (`DuplicateFinder.scanPaths`) ve her
  /// gruptan **en eski** dosya korunur. Silinenler çöp kutusuna gider.
  Future<void> _cleanDuplicates() async {
    final candidates = _filter
        .withHideDuplicates(false)
        .apply(_files, query: _query)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Kopyalar bayt bayt doğrulanıyor…')));
    final groups = await DuplicateFinder.scanPaths(candidates);
    if (!mounted) return;

    final extras = <FsEntry>[];
    for (final group in groups) {
      final sorted = [...group.files]
        ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      extras.addAll(sorted.skip(1));
    }
    if (extras.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Bayt bayt doğrulamada birebir kopya çıkmadı — '
              'hiçbir şey silinmedi.')));
      return;
    }
    final bytes = extras.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kopyalar silinsin mi?'),
        content: Text('${extras.length} fazladan kopya '
            '(${FsPaths.humanSize(bytes)}) çöp kutusuna taşınacak. '
            'Her gruptan en eski dosya korunur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await deleteEntries(context, extras, confirm: false)) {
      await _dropMissing();
    }
  }

  /// "N kopya gizlendi" bilgisi + tek dokunuşla göster/gizle.
  /// Sessiz gizleme "dosyam kayboldu" hatasına yol açar; burada hep görünür.
  Widget _duplicateNotice() => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.sm, 0),
        child: Row(
          children: [
            Icon(Icons.copy_all_outlined,
                size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: Gap.xs),
            Expanded(
              child: Text(
                '$_hiddenDuplicates yinelenen kopya gizlendi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Seçim sırasında düğmeler PASİF ama satır yerinde durur: kaybolsa
            // ızgara zıplar, etkin kalsa "seçtiklerimi mi siliyor?" sanılır.
            TextButton(
              onPressed: _selecting
                  ? null
                  : () => setState(
                      () => _filter = _filter.withHideDuplicates(false)),
              child: const Text('Göster'),
            ),
            TextButton(
              onPressed: _selecting ? null : _cleanDuplicates,
              child: const Text('Temizle'),
            ),
          ],
        ),
      );

  PreferredSizeWidget _normalBar(AppState appState) => AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            Text(
              '${_visible.length} / ${_files.length} dosya',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '${widget.title} içinde ara',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            tooltip: 'Benzer görüntüleri bul (yeniden sıkıştırılmış kopyalar)',
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SimilarScreen(
                files: _files,
                title: 'Benzer: ${widget.title}',
              ),
            )),
          ),
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
          IconButton(
            tooltip: 'Görünüm: ${appState.fmPhotoLayout.label}',
            icon: Icon(fmLayoutIcon(appState.fmPhotoLayout)),
            onPressed: () async {
              final picked = await showFmLayoutSheet(
                context,
                current: appState.fmPhotoLayout,
                title: 'Izgara yoğunluğu',
                // Fotoğraf zaman ekseninde liste düzeni anlamsız.
                allowLists: false,
              );
              if (picked != null) await appState.setFmPhotoLayout(picked);
            },
          ),
        ],
      );

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _query = '';
            _searchController.clear();
          }),
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: '${widget.title} içinde ara…',
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
  PreferredSizeWidget _selectionBar(List<FsEntry> visible) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} / ${visible.length} seçildi'),
        actions: [
          // Tek dosya seçiliyken çıkar: "üstündekileri/altındakileri de seç"
          // (istek 2026-07-29). Birden çok seçiliyken hangi dosya "anchor"
          // olacağı belirsizleşir, o yüzden yalnız tek seçimde gösterilir.
          if (_selected.length == 1) ...[
            IconButton(
              tooltip: 'Üstündekileri de seç',
              icon: const Icon(Icons.expand_less),
              onPressed: () => _selectFromAnchor(visible, above: true),
            ),
            IconButton(
              tooltip: 'Altındakileri de seç',
              icon: const Icon(Icons.expand_more),
              onPressed: () => _selectFromAnchor(visible, above: false),
            ),
          ],
          IconButton(
            tooltip: visible.every((e) => _selected.contains(e.path))
                ? 'Seçimi kaldır'
                : 'Tümünü seç',
            icon: Icon(visible.every((e) => _selected.contains(e.path))
                ? Icons.deselect
                : Icons.select_all),
            onPressed: () => _toggleSelectAll(visible),
          ),
        ],
      );

  /// Gün / Ay / Yıl seçimi — Google Fotoğraflar'daki zaman ölçeği.
  Widget _groupChips(AppState appState, PhotoGroup group) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
        child: Row(
          children: [
            for (final g in PhotoGroup.values)
              Padding(
                padding: const EdgeInsets.only(right: Gap.sm),
                child: ChoiceChip(
                  label: Text(g.label),
                  selected: group == g,
                  onSelected: (_) => appState.setFmPhotoGroup(g),
                ),
              ),
          ],
        ),
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
      // Fotoğraf ızgarasında "türe göre" sıralamanın karşılığı yok (uzantı
      // süzgeci zaten var); ada/tarihe/boyuta göre yeter.
      sortOptions: const [FmSort.date, FmSort.name, FmSort.size],
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  /// Kaynak, uzantı ve mesajlaşma türü sayıları — liste değişmedikçe yeniden
  /// sayılmaz.
  void _ensureCounts() {
    final key = identityHashCode(_files);
    if (_countsKey == key && _bucketCache != null) return;
    _bucketCache = bucketCounts(_files.map((f) => f.path));
    _extCache = extensionCounts(_files);
    _chatKindCache = chatKindCounts(_files);
    _countsKey = key;
  }

  Widget _sourceChips() {
    _ensureCounts();
    final counts = _bucketCache!;
    final buckets = MediaBucket.values
        .where((b) => (counts[b] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    if (buckets.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.sm),
            child: ChoiceChip(
              label: Text('Tümü (${_files.length})'),
              selected: _filter.buckets.isEmpty,
              onSelected: (_) =>
                  setState(() => _filter = _filter.withBuckets(const {})),
            ),
          ),
          for (final b in buckets)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              // FilterChip = çoklu seçim (istek 2026-07-29). Çip ve süzgeç
              // sayfası AYNI alanı yazar → ikisi hep tutarlı.
              child: FilterChip(
                label: Text('${b.label} (${counts[b]})'),
                selected: _filter.buckets.contains(b),
                onSelected: (_) =>
                    setState(() => _filter = _filter.toggleBucket(b)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeline(
    List<_Section> sections,
    List<FsEntry> visible,
    FmLayout layout,
  ) =>
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 2.0;
          final columns = layout.columns;
          final cell =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              for (final section in sections)
                SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SectionHeaderDelegate(
                        title: section.title,
                        count: section.files.length,
                        selecting: _selecting,
                        allSelected: section.files
                            .every((e) => _selected.contains(e.path)),
                        onToggle: () => _toggleSection(section),
                        background: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final e = section.files[i];
                          return DragSelectItem(
                            index: section.startIndex + i,
                            child: _PhotoTile(
                              entry: e,
                              size: cell,
                              selected: _selected.contains(e.path),
                              selecting: _selecting,
                              onTap: () {
                                if (_selecting) {
                                  _toggle(e);
                                } else {
                                  _open(e, visible);
                                }
                              },
                              onMore: () async {
                                await showEntryActions(context, e,
                                    allowReveal: true, onReveal: _reveal);
                                _dropMissing();
                              },
                            ),
                          );
                        },
                        childCount: section.files.length,
                      ),
                    ),
                  ],
                ),
              // Alt eylem çubuğu bindirmeli çizilir; son satır onun altında
              // kalmasın diye sabit boşluk (çubuk yokken de aynı → zıplamaz).
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      );

  void _reveal(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrowserScreen(path: path),
    ));
  }
}

/// Yapışkan grup başlığı. Yükseklik sabittir (min = max) — değişken yükseklikli
/// pinned başlık kaydırmada zıplamaya yol açıyor.
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;
  final Color background;

  const _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
    required this.background,
  });

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (selecting)
            IconButton(
              tooltip: allSelected ? 'Grubun seçimini kaldır' : 'Grubu seç',
              icon: Icon(allSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked),
              color: allSelected ? theme.colorScheme.primary : null,
              onPressed: onToggle,
            )
          else
            Text('$count',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate old) =>
      old.title != title ||
      old.count != count ||
      old.selecting != selecting ||
      old.allSelected != allSelected ||
      old.background != background;
}

/// Tam kare önizleme: ad yok, çerçeve yok — Google Fotoğraflar hücresi.
class _PhotoTile extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _PhotoTile({
    required this.entry,
    required this.size,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      // Seçim uzun basışla DragSelectArea'da başlar; ⋮ yerine ikinci dokunuş
      // menüsü hücreyi kirletmesin diye çift dokunuş eylem sayfasını açar.
      onDoubleTap: selecting ? null : onMore,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FmEntryIcon(entry: entry, size: size, radius: 0),
          if (selected)
            Container(color: scheme.primary.withValues(alpha: 0.35)),
          if (selecting)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? scheme.primary : Colors.white,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
        ],
      ),
    );
  }
}
