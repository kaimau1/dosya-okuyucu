import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/file_age.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';

enum _DlSort { oldest, newest, largest, name }

/// İndirilenler: "gereksizleri kolay silmek" için yaş odaklı liste.
///
/// Her satırda **indirilme tarihi** ve mümkünse **son açılma** (dosya sisteminin
/// erişim zamanı) ile renkli yaş rozeti var. Üstte "180+ gündür dokunulmamış"
/// özeti ve tek dokunuşla hepsini seçme düğmesi.
///
/// *Not:* Android'de erişim zamanı (atime) çoğu bağlamada güncellenmez; bu
/// yüzden erişim zamanı değiştirilme zamanından büyük DEĞİLSE "son açılma"
/// gösterilmez — uydurma bilgi vermeyiz ([FsEntry.hasAccessInfo]).
class DownloadsScreen extends StatefulWidget {
  final String path;
  const DownloadsScreen({super.key, required this.path});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FsEntry> _files = const [];
  final Set<String> _selected = {};

  /// Sürükleyerek seçimde kenarda otomatik kaydırma için.
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  /// **Varsayılan: en yeni önce** (kullanıcı 2026-08-17: *"indirilenlerde en
  /// güncelden en eskiye sıralanmalı, şu an tam tersi varsayılan"*).
  ///
  /// Eskiden "en eski önce"ydi çünkü bu ekran "yer aç" gözüyle tasarlanmıştı:
  /// en eski indirmeler silinecek adaylardı. Ama insanlar buraya çoğu zaman
  /// **az önce indirdikleri** dosyayı açmaya geliyor; onu bulmak için 38
  /// satır kaydırmak gerekiyordu. Eski dosyalar sıralamadan bir dokunuş uzakta
  /// (ve "çok eski" uyarısı zaten ayrı gösteriliyor).
  _DlSort _sort = _DlSort.newest;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_load);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    // `index(perCategory: 5000)` kategori başına kırpıyordu; `collect`
    // eksiksiz döner (aynı 800 sınırı hatasının küçük kardeşi).
    final all = await FsScan.collect([widget.path]);
    if (!mounted) return;
    setState(() {
      _files = all;
      _selected.removeWhere((s) => !all.any((e) => e.path == s));
      _loading = false;
    });
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  int? _ageDays(FsEntry e) => daysBetween(e.lastTouchedMs, _now);

  List<FsEntry> get _sorted {
    // Arama bellekte süzer: bu ekranın listesi zaten yüklü, disk okunmaz.
    final list = _query.trim().isEmpty
        ? [..._files]
        : _files.where((e) => fmMatches(e.name, _query)).toList();
    switch (_sort) {
      case _DlSort.oldest:
        list.sort((a, b) => a.lastTouchedMs.compareTo(b.lastTouchedMs));
      case _DlSort.newest:
        list.sort((a, b) => b.lastTouchedMs.compareTo(a.lastTouchedMs));
      case _DlSort.largest:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _DlSort.name:
        list.sort((a, b) => FsScan.nameKey(a.name).compareTo(
              FsScan.nameKey(b.name),
            ));
    }
    return list;
  }

  List<FsEntry> get _ancient => _files
      .where((e) => ageLevelFor(_ageDays(e)) == AgeLevel.ancient)
      .toList();

  /// Seçili girdiler (yol → girdi haritasıyla, liste uzun olabilir).
  List<FsEntry> get _selectedEntries {
    final map = {for (final e in _files) e.path: e};
    return [
      for (final path in _selected)
        if (map[path] != null) map[path]!,
    ];
  }

  int get _selectedBytes => _files
      .where((e) => _selected.contains(e.path))
      .fold(0, (sum, e) => sum + e.sizeBytes);

  @override
  Widget build(BuildContext context) {
    final files = _sorted;
    final total = _files.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    final ancient = _ancient;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text(context.t('downloads.selected', {'n': _selected.length, 'total': files.length})),
              actions: [
                IconButton(
                  tooltip: files.every((e) => _selected.contains(e.path))
                      ? context.t('fm.select_none')
                      : context.t('fm.select_all'),
                  icon: Icon(files.every((e) => _selected.contains(e.path))
                      ? Icons.deselect
                      : Icons.select_all),
                  onPressed: () => setState(() {
                    if (files.every((e) => _selected.contains(e.path))) {
                      _selected.removeAll(files.map((e) => e.path));
                    } else {
                      _selected.addAll(files.map((e) => e.path));
                    }
                  }),
                ),
              ],
            )
          : _searching
              ? AppBar(
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
                    hint: context.t('downloads.search_hint'),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                )
              : AppBar(
                  // Başlıkta ne gösterdiğimiz yazıyor: bu ekran klasörün
                  // KENDİSİ değil, alt klasörler dahil TÜM dosyaların yaş
                  // odaklı listesi. Kullanıcı "ilginç, kullanışsız bir klasör"
                  // dedi (2026-07-29) — çünkü klasör sandı.
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t('downloads.title')),
                      Text(
                        context.t('downloads.count', {'n': _files.length}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: context.t('downloads.search'),
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() => _searching = true),
                    ),
                    IconButton(
                      tooltip: context.t('downloads.folder_view'),
                      icon: const Icon(Icons.account_tree_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BrowserScreen(
                              path: widget.path, title: context.t('downloads.title')),
                        ),
                      ),
                    ),
                    PopupMenuButton<_DlSort>(
                      tooltip: context.t('downloads.sort'),
                      icon: const Icon(Icons.sort),
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: _DlSort.oldest,
                            child: Text(context.t('downloads.sort_oldest'))),
                        PopupMenuItem(
                            value: _DlSort.newest, child: Text(context.t('downloads.sort_newest'))),
                        PopupMenuItem(
                            value: _DlSort.largest,
                            child: Text(context.t('downloads.sort_largest'))),
                        PopupMenuItem(
                            value: _DlSort.name, child: Text(context.t('downloads.sort_name'))),
                      ],
                    ),
                  ],
                ),
      // Stack: alt eylem çubuğu gövdeyi kısaltmasın → liste zıplamaz.
      body: Stack(children: [
        _loading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? Center(
                  child: Text(_query.trim().isEmpty
                      ? context.t('downloads.empty')
                      : context.t('downloads.no_result', {'q': _query})))
              : Column(
                  children: [
                    _summary(total, ancient),
                    const Divider(height: 1),
                    Expanded(
                      child: DragSelectArea(
                        scrollController: _scroll,
                        isSelected: (i) =>
                            i >= 0 &&
                            i < files.length &&
                            _selected.contains(files[i].path),
                        onSelectRange: (a, b, sel) => setState(() {
                          for (var i = a; i <= b; i++) {
                            if (i < 0 || i >= files.length) continue;
                            if (sel) {
                              _selected.add(files[i].path);
                            } else {
                              _selected.remove(files[i].path);
                            }
                          }
                        }),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: files.length,
                          itemBuilder: (context, i) =>
                              DragSelectItem(index: i, child: _row(files[i])),
                        ),
                      ),
                    ),
                  ],
                ),
        // Seçim varken: Taşı · Kopyala · Paylaş · Sil (ortak çubuk). Seçimin
        // toplam boyutu da yazılır — bu ekranın derdi yer açmak.
        if (_selecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                    child: Text(
                      '${context.t('dls.selected', {'n': _selected.length})}'
                      '${FsPaths.humanSize(_selectedBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FmSelectionBar(
                    selected: _selectedEntries,
                    onChanged: () async {
                      setState(_selected.clear);
                      await _load();
                    },
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _summary(int total, List<FsEntry> ancient) {
    final ancientBytes = ancient.fold<int>(0, (s, e) => s + e.sizeBytes);
    return Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    context.t('count.files_size', {
                      'n': _files.length,
                      'size': FsPaths.humanSize(total),
                    }),
                    style: Theme.of(context).textTheme.titleSmall),
                if (ancient.isNotEmpty)
                  Text(
                    '${context.t('dls.untouched', {'n': ancient.length})}'
                    '${FsPaths.humanSize(ancientBytes)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
              ],
            ),
          ),
          if (ancient.isNotEmpty)
            TextButton(
              onPressed: () =>
                  setState(() => _selected.addAll(ancient.map((e) => e.path))),
              child: Text(context.t('downloads.select_old')),
            ),
        ],
      ),
    );
  }

  Widget _row(FsEntry entry) {
    final selected = _selected.contains(entry.path);
    final days = _ageDays(entry);
    final level = ageLevelFor(days);
    final color = switch (level) {
      AgeLevel.fresh => const Color(0xFF2E7D32),
      AgeLevel.recent => const Color(0xFF827717),
      AgeLevel.old => const Color(0xFFEF6C00),
      AgeLevel.ancient => Theme.of(context).colorScheme.error,
      AgeLevel.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    return ListTile(
      selected: selected,
      leading: _selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => setState(() {
                if (!_selected.remove(entry.path)) _selected.add(entry.path);
              }),
            )
          : FmEntryIcon(entry: entry),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          FsPaths.humanSize(entry.sizeBytes),
          // Liste alt klasörleri de kapsıyor; dosyanın hangi alt klasörde
          // olduğu yazılmazsa aynı adlı iki dosya ayırt edilemiyordu.
          if (p.dirname(entry.path) != widget.path)
            '📁 ${p.basename(p.dirname(entry.path))}',
          'indirilme: ${FsPaths.humanDate(entry.modifiedMs)}',
          if (entry.hasAccessInfo)
            context.t('dls.last_opened', {
              'when': relativeDays(daysBetween(entry.accessedMs, _now)),
            }),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Yaş rozeti + ⋮ menü. Menü YOKTU: kullanıcı "içerisinde pek bir şey
      // yapamıyorum" dedi (2026-07-29) — açma ve toplu silme dışında hiçbir
      // işleme (taşı/kopyala/yeniden adlandır/paylaş) yol yoktu.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            relativeDays(days),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          if (!_selecting)
            IconButton(
              tooltip: context.t('fm.jobs'),
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                await showEntryActions(context, entry,
                    allowReveal: true,
                    onReveal: (path) => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => BrowserScreen(path: path)),
                        ));
                await _load();
              },
            ),
        ],
      ),
      onTap: () {
        if (_selecting) {
          setState(() {
            if (!_selected.remove(entry.path)) _selected.add(entry.path);
          });
          return;
        }
        EntryOpener.open(context, entry.path,
            siblings: _files.map((e) => e.path).toList());
      },
    );
  }
}

/// İndirilenler klasörü diskte var mı?
bool downloadsExists(String path) => Directory(path).existsSync();

/// Standart İndirilenler yolu (varsa) — `Download`, bazı cihazlarda `Downloads`.
String? downloadsPathIn(String root) {
  // DİKKAT: bunlar DOSYA SİSTEMİ klasör adları, arayüz metni DEĞİL —
  // çevrilirlerse yol bulunamaz.
  for (final name in const ['Download', 'Downloads', 'İndirilenler']) {
    final candidate = p.join(root, name);
    if (Directory(candidate).existsSync()) return candidate;
  }
  return null;
}
