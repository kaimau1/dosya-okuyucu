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
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import 'browser_screen.dart';
import 'cleanup_screen.dart';
import 'duplicates_screen.dart';
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
  late List<FsEntry> _largest = [...widget.index.largest];

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

  @override
  void initState() {
    super.initState();
    _loadTrend();
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

  /// Ekranda gösterilen liste: arama sonucu ya da en büyük dosyalar.
  List<FsEntry> get _visible {
    final source = _isSearch ? _results : _largest;
    final list = [
      for (final e in source)
        if (_category == null || e.category == _category)
          // `tagsOf` her zaman verilir: bu ekranın süzgeç sayfası şu an etiket
          // çipi göstermiyor (bkz. aşağıdaki `showFmFilterSheet` çağrısı), ama
          // çözücüyü atlamak sessiz bir tuzak — çip bir gün eklenirse liste
          // sebepsizce bomboş görünürdü (etiketsiz sayılan her dosya elenir).
          if (_filter.matches(e, tagsOf: FileTags.forPath)) e,
    ];
    return FsScan.sort(list, _sort, descending: _desc, foldersFirst: false);
  }

  Future<void> _openFilterSheet() async {
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: extensionCounts(_isSearch ? _results : _largest),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  Future<void> _refreshAlive() async {
    final alive = await FsScan.pruneMissing(_largest);
    if (!mounted) return;
    setState(() {
      _largest = alive;
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
      appBar: AppBar(
        title: const Text('Bellek Analizi'),
        actions: [
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
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
                        label: c.label,
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
                _isSearch
                    ? context.t('ana.result_count', {'n': visible.length})
                    : '${index.totalFiles} dosya · '
                        '${FsPaths.humanSize(index.totalBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (_category != null || _filter.isActive)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Wrap(
                spacing: Gap.sm,
                children: [
                  if (_category != null)
                    InputChip(
                      label: Text(_category!.label),
                      onDeleted: () => setState(() => _category = null),
                    ),
                  if (_filter.isActive)
                    InputChip(
                      label: Text('${_filter.activeCount} filtre'),
                      onDeleted: () =>
                          setState(() => _filter = FmFilter.none),
                    ),
                ],
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
              leading: FmEntryIcon(entry: e),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${FsPaths.humanSize(e.sizeBytes)} · '
                '${FsPaths.humanDate(e.modifiedMs)} · ${p.dirname(e.path)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => EntryOpener.open(context, e.path),
              trailing: IconButton(
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
    );
  }

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
                    'Son ${trend.days} günde '
                    '${grew ? "+" : "−"}'
                    '${FsPaths.humanSize(trend.deltaBytes.abs())}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (trend.topCategory != null && trend.topCategoryBytes > 0)
                    Text(
                      'En çok büyüyen: ${trend.topCategory!.label} '
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
            Text(volume.label,
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
              Text(
                '${FsPaths.humanSize(volume.usedBytes)} / '
                '${FsPaths.humanSize(volume.totalBytes)} kullanıldı '
                '(%${(volume.usedFraction * 100).round()}) · '
                '${FsPaths.humanSize(volume.freeBytes)} boş',
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
