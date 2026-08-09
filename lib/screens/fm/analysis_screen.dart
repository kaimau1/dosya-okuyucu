import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'cleanup_screen.dart';
import 'duplicates_screen.dart';
import 'installed_apps_screen.dart';
import 'entry_actions.dart';

/// Bellek Analizi: neyin ne kadar yer kapladığı + en büyük dosyalar.
/// Yer açmak isteyen kullanıcı için "büyük dosyayı bul ve sil" akışı.
///
/// **Arama burada da var** (kullanıcı isteği 2026-07-29: "arama bellek
/// analizinde yok, arama kısmı her yerde olmalı ve filtrelenebilmeli"):
/// - Sorgu boşken **en büyük dosyalar** listelenir (analizin asıl işi).
/// - Sorgu yazıldığında tüm depolamada arama dizininden ([SearchIndex])
///   aranır — analiz ekranı yalnız en büyük 200 dosyayı tuttuğu için
///   listeyi süzmek "aradığım dosya yok" demeye yol açardı.
/// - Her iki durumda da aynı süzgeç/sıralama sayfası geçerlidir.
class AnalysisScreen extends StatefulWidget {
  final StorageIndex index;
  final List<StorageVolume> volumes;

  const AnalysisScreen({
    super.key,
    required this.index,
    required this.volumes,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  /// Kategori → o kategorinin en büyükleri; `null` anahtarı genel liste.
  ///
  /// Taramadan gelen listeler kopyalanır çünkü silme sonrası
  /// ([_refreshAlive]) budanıyorlar. `StorageIndex`in listeleri değişmez
  /// (`List.unmodifiable`) — doğrudan yazmaya kalkmak çalışma anında patlardı.
  late final Map<FmCategory?, List<FsEntry>> _largest = {
    null: [...widget.index.largest],
    for (final c in FmCategory.values)
      if (widget.index.largestOf(c).isNotEmpty) c: [...widget.index.largestOf(c)],
  };

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<FsEntry> _results = const [];
  bool _searching = false;
  String _query = '';

  /// Geç dönen eski sonuç yenisini ezmesin.
  int _queryToken = 0;

  FmFilter _filter = FmFilter.none;
  FmSort _sort = FmSort.size;
  bool _desc = true;

  /// Kategori süzgeci (Türlere göre çubuklarına dokununca da ayarlanır).
  FmCategory? _category;

  /// Depolama eğilimi ("bu hafta +2,1 GB · en çok Videolar").
  TrendDelta? _trend;

  /// **Toplu seçim** (yol kümesi). Bellek analizinde "büyük dosyayı bul ve
  /// sil" akışının son adımı eksikti: tek tek ⋮ menüsünden silmek 20 dosya
  /// için 60 dokunuş demekti (kullanıcı isteği 2026-08-05).
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  /// Yüklü uygulamaların kapladığı alan. Ölçüm binder çağrıları gerektirdiği
  /// için ekran açılır açılmaz DEĞİL, arka planda gelir; hazır olana kadar
  /// kart hiç görünmez (boş bir kutu göstermek yanıltıcı olurdu).
  AppStorageSummary? _apps;

  @override
  void initState() {
    super.initState();
    _loadTrend();
    _loadApps();
    // Süzgeç sayfasındaki "açılmış/açılmamış" ölçütleri için.
    OpenHistory.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadApps() async {
    final summary = await InstalledAppsService.summary();
    if (!mounted || !summary.hasData) return;
    setState(() => _apps = summary);
  }

  /// **Uygulamalar** kartı — diğer dosya yöneticilerinin analizindeki
  /// "Uygulamalar 63 GB" kutusunun karşılığı. Bizde hiç yoktu: `df` uygulama
  /// başına kırılım bilmiyor, `Android/data` klasörü de Android 11'den beri
  /// okunamıyor; sayı ancak `StorageStatsManager` köprüsünden geliyor
  /// (`ci/MainActivity.kt`).
  Widget _appsCard() {
    final apps = _apps;
    if (apps == null) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const InstalledAppsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.android),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(context.t('fm.apps'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text(FsPaths.humanSize(apps.totalBytes),
                      style: Theme.of(context).textTheme.titleMedium),
                  const Icon(Icons.chevron_right),
                ],
              ),
              for (final (name, bytes) in apps.top)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Text(FsPaths.humanSize(bytes),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              if (apps.cacheBytes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    context.t('ana.cache_total',
                        {'v': FsPaths.humanSize(apps.cacheBytes)}),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Paper.faint(context)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadTrend() async {
    final points = await StorageTrend.load();
    if (!mounted || points.length < 2) return;
    setState(() => _trend = computeTrend(points));
  }

  bool get _isSearch => _query.trim().length >= 2;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    final token = ++_queryToken;
    setState(() => _searching = true);
    final hits = await SearchIndex.query(q, includeDirs: false, limit: 1000);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  /// Seçili kategorinin (ya da genel) en büyük dosyaları — süzülmemiş.
  ///
  /// **Kategori süzgeci genel listeyi DARALTMAZ, kendi listesini açar.** Genel
  /// liste tüm depolamanın en büyük 200 dosyası, yani pratikte 200 video; onu
  /// "Belgeler"e süzmek boş ekran demekti (kullanıcı hatası 2026-08-09).
  List<FsEntry> get _source =>
      _isSearch ? _results : (_largest[_category] ?? const []);

  /// Ekranda gösterilen liste: arama sonucu ya da en büyük dosyalar.
  List<FsEntry> get _visible {
    final list = [
      for (final e in _source)
        // Arama sonucu tüm depolamadan gelir → kategori ölçütü orada hâlâ bir
        // süzgeçtir. En büyükler listesi zaten kategorisine göre seçilidir.
        if (!_isSearch || _category == null || e.category == _category)
          // `tagsOf` her zaman verilir: bu ekranın süzgeç sayfası şu an etiket
          // çipi göstermiyor (bkz. aşağıdaki `showFmFilterSheet` çağrısı), ama
          // çözücüyü atlamak sessiz bir tuzak — çip bir gün eklenirse liste
          // sebepsizce bomboş görünürdü (etiketsiz sayılan her dosya elenir).
          if (_filter.matches(e,
              tagsOf: FileTags.forPath, openedAtOf: OpenHistory.forPath))
            e,
    ];
    return FsScan.sort(list, _sort, descending: _desc, foldersFirst: false);
  }

  Future<void> _openFilterSheet() async {
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: extensionCounts(_source),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  /// Silme/taşıma sonrası: **her** en-büyükler listesinden düşenleri at.
  ///
  /// Yalnız görünen liste budansaydı, kullanıcı "Videolar"da sildiği dosyayı
  /// "Tümü"ne dönünce yeniden görürdü.
  Future<void> _refreshAlive() async {
    final pruned = <FmCategory?, List<FsEntry>>{};
    for (final entry in _largest.entries) {
      pruned[entry.key] = await FsScan.pruneMissing(entry.value);
    }
    if (!mounted) return;
    setState(() {
      _largest
        ..clear()
        ..addAll(pruned);
      _results = _results.where((e) => e.exists).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final categories = FmCategory.values
        .where((c) => c != FmCategory.folder && index.stat(c).bytes > 0)
        .toList()
      ..sort((a, b) => index.stat(b).bytes.compareTo(index.stat(a).bytes));
    final maxBytes = categories.isEmpty ? 1 : index.stat(categories.first).bytes;
    final visible = _visible;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text(context.t('ph.selected_of', {
                'n': _selected.length,
                'total': visible.length,
              })),
              actions: [
                IconButton(
                  tooltip: context.t('ph.select_all'),
                  icon: Icon(_selected.length >= visible.length
                      ? Icons.deselect
                      : Icons.select_all),
                  onPressed: () => _toggleSelectAll(visible),
                ),
              ],
            )
          : AppBar(
              title: Text(context.t('fm.memory_analysis')),
              actions: [
                FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
              ],
            ),
      // Stack: seçim çubuğu görünürken gövde yüksekliği DEĞİŞMESİN
      // (`bottomNavigationBar` kullanılırsa liste zıplıyor).
      body: Stack(
        children: [
          ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
            children: [
              _searchField(),
              if (_searching) ...[
                const SizedBox(height: Gap.sm),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: Gap.md),
              if (!_isSearch) ...[
                for (final v in widget.volumes) ...[
                  _VolumeBar(volume: v),
                  const SizedBox(height: Gap.md),
                ],
                if (_trend?.hasData ?? false) ...[
                  _trendCard(_trend!),
                  const SizedBox(height: Gap.md),
                ],
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.auto_fix_high),
                    title: Text(context.t('ana.free_space')),
                    subtitle: Text(
                        context.t('ana.free_space_note')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CleanupScreen(index: widget.index),
                    )),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(context.t('ana.find_dupes')),
                    subtitle: Text(
                        context.t('ana.find_dupes_note')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DuplicatesScreen(roots: FmEnv.volumeRoots),
                    )),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                _appsCard(),
                const SizedBox(height: Gap.lg),
                Text(context.t('ana.by_type'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gap.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Column(
                      children: [
                        for (final c in categories)
                          _CategoryBar(
                            // Çeviri anahtarı: `c.label` Türkçe SABİT (otomatik
                            // düzenlemede klasör adı üretiyor), ekranda gösterilen
                            // ad ondan bağımsız olmalı.
                            label: context.t(c.labelKey),
                            bytes: index.stat(c).bytes,
                            count: index.stat(c).count,
                            fraction: index.stat(c).bytes / maxBytes,
                            color: FmColors.forCategory(c),
                            selected: _category == c,
                            // Çubuğa dokunmak listeyi o türe daraltır: "en büyük
                            // videolarım hangileri" en sık sorulan soru.
                            onTap: () => setState(
                                () => _category = _category == c ? null : c),
                          ),
                        if (categories.isEmpty)
                          Text(context.t('ana.no_scan')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isSearch ? context.t('ana.results') : context.t('ana.largest'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    // Kapsam seçiliyse O kapsamın toplamı yazar — başlığın
                    // altındaki sayı ekrandaki listeyle aynı şeyi anlatmalı.
                    _isSearch
                        ? context.t('ana.result_count', {'n': visible.length})
                        : context.t('ana.total_summary', {
                            'n': _category == null
                                ? index.totalFiles
                                : index.stat(_category!).count,
                            'size': FsPaths.humanSize(_category == null
                                ? index.totalBytes
                                : index.stat(_category!).bytes),
                          }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
          ),
          // **Kapsam çipleri.** "Tümü" ilk açılışta seçili görünsün diye var:
          // genel en büyükler pratikte hep video olduğu için kullanıcı ekranı
          // "videolar süzgeci açık gelmiş" sanıyordu (2026-08-09). Artık hangi
          // kapsamda olduğu yazıyor ve her kapsam KENDİ en büyüklerini açıyor.
          if (!_isSearch && categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(context.t('ana.scope_all')),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final c in categories)
                    if ((_largest[c] ?? const []).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.sm),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(context.t(c.labelKey)),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                ],
              ),
            ),
          if (_filter.isActive)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  label: Text(
                      context.t('ana.filter_count', {'n': _filter.activeCount})),
                  onDeleted: () => setState(() => _filter = FmFilter.none),
                ),
              ),
            ),
          const SizedBox(height: Gap.sm),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Center(
                child: Text(
                  _searching
                      ? context.t('ana.searching')
                      : (_isSearch
                          ? context.t('ana.no_result')
                          : context.t('ana.no_files')),
                ),
              ),
            ),
          // 200 sınırı bilinçli: "en büyük dosyalar" listesi zaten sıralı,
          // aşağısı yer açma kararına katkı vermiyor.
          for (final e in visible.take(200))
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: _selected.contains(e.path),
              leading: _selecting
                  ? Checkbox(
                      value: _selected.contains(e.path),
                      onChanged: (_) => _toggle(e),
                    )
                  : FmEntryIcon(entry: e),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${FsPaths.humanSize(e.sizeBytes)} · '
                '${FsPaths.humanDate(e.modifiedMs)} · ${p.dirname(e.path)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Seçim açıkken dokunmak SEÇER (dosyayı açmaz) — her liste
              // ekranında aynı kural.
              onTap: () => _selecting
                  ? _toggle(e)
                  : EntryOpener.open(context, e.path),
              onLongPress: () => _toggle(e),
              trailing: _selecting
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () async {
                        await showEntryActions(
                          context,
                          e,
                          allowReveal: true,
                          onReveal: (path) => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => BrowserScreen(path: path)),
                          ),
                        );
                        await _refreshAlive();
                      },
                    ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FmSelectionBar(
              selected: _selectedEntries(visible),
              onChanged: () async {
                setState(_selected.clear);
                await _refreshAlive();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Seçimi açar/kapatır.
  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  /// Hepsini seç / seçimi kaldır — ölçüt GÖRÜNEN liste (200 sınırı dahil),
  /// yoksa "tümünü seç" görünmeyen dosyaları da silmeye giderdi.
  void _toggleSelectAll(List<FsEntry> visible) => setState(() {
        if (_selected.length >= visible.length) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(visible.map((e) => e.path));
        }
      });

  /// Seçili yolların GÖRÜNEN listedeki karşılıkları. Eylem çubuğu ile sayaç
  /// aynı kümeyi kullanır; süzgeç değişip bir dosya listeden düşerse seçim de
  /// onu kapsamaz.
  List<FsEntry> _selectedEntries(List<FsEntry> visible) =>
      [for (final e in visible) if (_selected.contains(e.path)) e];

  /// Depolama eğilimi kartı. Veri yoksa hiç gösterilmez — "0 B değişti"
  /// demek bilgi değil gürültüdür.
  Widget _trendCard(TrendDelta trend) {
    final grew = trend.deltaBytes > 0;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Icon(grew ? Icons.trending_up : Icons.trending_down,
                color: grew ? scheme.error : scheme.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.t('an.trend_days', {'n': trend.days})}'
                    '${grew ? "+" : "−"}'
                    '${FsPaths.humanSize(trend.deltaBytes.abs())}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (trend.topCategory != null && trend.topCategoryBytes > 0)
                    Text(
                      '${context.t('an.top_growing', {
                            'category':
                                context.t(trend.topCategory!.labelKey),
                          })}'
                      '(+${FsPaths.humanSize(trend.topCategoryBytes)})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.t('ana.search_all'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: _onQueryChanged,
        onSubmitted: _run,
      );
}

class _VolumeBar extends StatelessWidget {
  final StorageVolume volume;
  const _VolumeBar({required this.volume});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(volume.displayLabel(context.t),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            if (volume.hasStats) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: LinearProgressIndicator(
                  value: volume.usedFraction,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: Gap.sm),
              // Kapasite ONDALIK gösterilir (512 GB) — telefonun üstünde yazan
              // sayı bu. Dosya boyutları 1024 tabanında kalır.
              Text(
                context.t('an.volume_usage', {
                  'used': FsPaths.humanCapacity(volume.usedBytes),
                  'total': FsPaths.humanCapacity(volume.capacityBytes),
                  'percent': (volume.usedFraction * 100).round(),
                  'free': FsPaths.humanCapacity(volume.freeBytes),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(context.t('ana.usage_unreadable'),
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int bytes;
  final int count;
  final double fraction;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryBar({
    required this.label,
    required this.bytes,
    required this.count,
    required this.fraction,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected) ...[
                  Icon(Icons.filter_alt, size: 16, color: color),
                  const SizedBox(width: Gap.xs),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: selected
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ),
                Text('${FsPaths.humanSize(bytes)} · $count',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Gap.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.02, 1).toDouble(),
                minHeight: 8,
                color: color,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
