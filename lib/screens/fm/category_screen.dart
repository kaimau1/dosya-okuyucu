import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';

/// Bir kategorinin (Görüntüler / Videolar / Ses / Belgeler / Uygulamalar /
/// Arşivler / Yeni dosyalar) tüm depolamadaki dosyaları.
///
/// Liste, panonun tek geçişli taramasından ([StorageIndex]) gelir — bu ekran
/// yeniden tarama YAPMAZ, anında açılır.
class CategoryScreen extends StatefulWidget {
  final String title;
  final List<FsEntry> files;

  /// Kategori ızgarada görsel ise küçük resimli ızgara varsayılan olur.
  final bool gridDefault;

  /// Kaynak filtresi (Kamera / WhatsApp / Telegram / Ekran görüntüsü …)
  /// gösterilsin mi? Görsel ve video kategorilerinde anlamlı.
  final bool showSources;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.files,
    this.gridDefault = false,
    this.showSources = false,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late List<FsEntry> _files = [...widget.files];
  final Set<String> _selected = {};
  late bool _grid = widget.gridDefault;
  FmSort _sort = FmSort.date;
  bool _desc = true;

  /// Seçili kaynak (null = tümü).
  MediaBucket? _bucket;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Başka bir ekranda silinen/taşınan dosya burada durmasın.
    FsEvents.version.addListener(_dropMissing);
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    super.dispose();
  }

  List<FsEntry> get _sorted {
    final filtered = _bucket == null
        ? _files
        : _files.where((f) => bucketForPath(f.path) == _bucket).toList();
    return FsScan.sort(filtered, _sort, descending: _desc, foldersFirst: false);
  }

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  /// Silme/taşıma sonrası: listeyi diskteki gerçekle tazele.
  void _dropMissing() {
    if (!mounted) return;
    setState(() {
      _files = _files.where((e) => e.exists).toList();
      _selected.removeWhere((s) => !_files.any((e) => e.path == s));
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = _sorted;
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text('${_selected.length} seçildi'),
              actions: [
                IconButton(
                  tooltip: 'Paylaş',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareEntries(_selected.toList()),
                ),
                IconButton(
                  tooltip: 'Kopyala',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    context
                        .read<AppState>()
                        .setClipboard(_selected.toList(), cut: false);
                    setState(_selected.clear);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Kopyalandı. Dosyalar sekmesinde hedef klasörde yapıştırın.')));
                  },
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final selected = _files
                        .where((e) => _selected.contains(e.path))
                        .toList();
                    if (await deleteEntries(context, selected)) _dropMissing();
                  },
                ),
              ],
            )
          : AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(
                  tooltip: _grid ? 'Liste görünümü' : 'Izgara görünümü',
                  icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                  onPressed: () => setState(() => _grid = !_grid),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => setState(() {
                    switch (v) {
                      case 'date':
                        _sort = FmSort.date;
                        _desc = true;
                      case 'name':
                        _sort = FmSort.name;
                        _desc = false;
                      case 'size':
                        _sort = FmSort.size;
                        _desc = true;
                      case 'dir':
                        _desc = !_desc;
                    }
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'date', child: Text('Tarihe göre')),
                    PopupMenuItem(value: 'name', child: Text('Ada göre')),
                    PopupMenuItem(value: 'size', child: Text('Boyuta göre')),
                    PopupMenuItem(value: 'dir', child: Text('Sırayı ters çevir')),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          if (widget.showSources && !_selecting) _sourceChips(),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text('Bu kategoride dosya bulunamadı.'))
                : _grid
                    ? _gridView(files)
                    : _listView(files),
          ),
        ],
      ),
    );
  }

  /// Kaynak çipleri: hangi klasörden/uygulamadan geldiğine göre süzme.
  /// Sayılar gerçek dosya sayısıdır; boş kaynak çipi gösterilmez.
  Widget _sourceChips() {
    final counts = bucketCounts(_files.map((f) => f.path));
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
              selected: _bucket == null,
              onSelected: (_) => setState(() => _bucket = null),
            ),
          ),
          for (final b in buckets)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: ChoiceChip(
                label: Text('${b.label} (${counts[b]})'),
                selected: _bucket == b,
                onSelected: (_) => setState(() => _bucket = b),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listView(List<FsEntry> files) => ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, i) {
          final e = files[i];
          final selected = _selected.contains(e.path);
          return ListTile(
            selected: selected,
            leading: _selecting
                ? Checkbox(value: selected, onChanged: (_) => _toggle(e))
                : FmEntryIcon(entry: e),
            title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${FsPaths.humanSize(e.sizeBytes)} · ${p.dirname(e.path)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              if (_selecting) {
                _toggle(e);
              } else {
                _open(e);
              }
            },
            onLongPress: () => _toggle(e),
            trailing: _selecting
                ? null
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      await showEntryActions(context, e,
                          allowReveal: true, onReveal: _reveal);
                      _dropMissing();
                    },
                  ),
          );
        },
      );

  Widget _gridView(List<FsEntry> files) => GridView.builder(
        padding: const EdgeInsets.all(Gap.sm),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          childAspectRatio: 0.82,
          mainAxisSpacing: Gap.sm,
          crossAxisSpacing: Gap.sm,
        ),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final e = files[i];
          final selected = _selected.contains(e.path);
          return InkWell(
            onTap: () {
              if (_selecting) {
                _toggle(e);
              } else {
                _open(e);
              }
            },
            onLongPress: () => _toggle(e),
            borderRadius: BorderRadius.circular(Radii.card),
            child: Container(
              padding: const EdgeInsets.all(Gap.xs),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5)
                    : null,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FmEntryIcon(entry: e, size: 64),
                  const SizedBox(height: Gap.xs),
                  Text(
                    e.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
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
