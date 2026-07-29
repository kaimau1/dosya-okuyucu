import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/search_index.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';

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

  /// Kaçıncı arama olduğunu sayar: geç dönen eski sonuç yenisini ezmesin.
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    SearchIndex.revision.addListener(_onIndexChanged);
    // Ekran açılırken dizin hazırlanır; kullanıcı yazana kadar çoğu zaman
    // hazır olur, olmazsa canlı taramaya düşülür.
    SearchIndex.ensureBuilt();
  }

  @override
  void dispose() {
    SearchIndex.revision.removeListener(_onIndexChanged);
    _debounce?.cancel();
    _controller.dispose();
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
      });
      return;
    }
    final token = ++_queryToken;
    setState(() => _searching = true);
    // Sınır 500 değil 1000: sonuçlar burada ayrıca süzülüyor (tarih/boyut/tür)
    // — dar bir ham liste, süzgeçten sonra haksız yere boş kalırdı.
    final hits = await SearchIndex.query(q, root: widget.root, limit: 1000);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _results = hits;
      _searching = false;
      _searched = true;
    });
  }

  List<FsEntry> get _filtered {
    final list = [
      for (final e in _results)
        if (_category == null || e.category == _category)
          if (_filter.matches(e)) e,
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '${widget.rootLabel ?? p.basename(widget.root)} '
                'içinde ara…',
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
            tooltip: 'Arama dizini',
            onSelected: (v) async {
              if (v == 'rebuild') {
                await SearchIndex.rebuild();
                if (mounted && _controller.text.trim().length >= 2) {
                  _run(_controller.text);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rebuild',
                child: Text('Dizini yeniden kur'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _filterChips(),
          if (_searching || SearchIndex.isBuilding)
            const LinearProgressIndicator(minHeight: 2),
          _indexBanner(),
          if (_searched && _results.isNotEmpty) _resultSummary(results.length),
          Expanded(child: _body(results)),
        ],
      ),
    );
  }

  /// Dizinin durumu: kuruluyor / bayat. Kullanıcı sonucun neden eksik
  /// olabileceğini bilsin diye açıkça yazılır.
  Widget _indexBanner() {
    String? text;
    if (SearchIndex.isBuilding) {
      text = 'Arama dizini kuruluyor — bu ilk sefere özel, sonraki aramalar '
          'anında olacak.';
    } else if (SearchIndex.isReady && SearchIndex.isStale) {
      text = 'Dosyalar değişti — dizin arka planda tazeleniyor.';
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  /// Kaç sonuç gösteriliyor, hangi ölçütle sıralı ve liste sınıra takıldı mı.
  /// (Sessizce kırpılmış bir liste "dosyam yok" sanılır.)
  Widget _resultSummary(int shown) {
    final capped = _results.length >= 1000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      child: Text(
        '$shown sonuç · ${_sort.label} (${_desc ? "azalan" : "artan"})'
        '${capped ? " · ilk 1000 sonuç" : ""}',
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
              ('Tümü', null),
              ('Klasör', FmCategory.folder),
              ('Belge', FmCategory.document),
              ('Görsel', FmCategory.image),
              ('Video', FmCategory.video),
              ('Ses', FmCategory.audio),
              ('Arşiv', FmCategory.archive),
              ('Uygulama', FmCategory.apk),
              ('Diğer', FmCategory.other),
            ])
              Padding(
                padding: const EdgeInsets.only(right: Gap.sm),
                child: ChoiceChip(
                  label: Text(entry.$1),
                  selected: _category == entry.$2,
                  onSelected: (_) => setState(() => _category = entry.$2),
                ),
              ),
          ],
        ),
      );

  Widget _body(List<FsEntry> results) {
    if (results.isEmpty) {
      final message = !_searched
          ? 'Dosya veya klasör adının bir bölümünü yazın.'
          : (_searching ? 'Aranıyor…' : 'Sonuç bulunamadı.');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final e = results[i];
        return ListTile(
          leading: FmEntryIcon(entry: e),
          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            e.isDir
                ? p.dirname(e.path)
                : '${FsPaths.humanSize(e.sizeBytes)} · ${p.dirname(e.path)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _open(e),
          onLongPress: () async {
            await showEntryActions(
              context,
              e,
              allowReveal: true,
              onReveal: _reveal,
            );
            if (mounted) _run(_controller.text);
          },
        );
      },
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
