import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../models/photo_group.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'browser_screen.dart';
import 'entry_actions.dart';

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

  const PhotosScreen({
    super.key,
    required this.title,
    required this.files,
    this.showSources = true,
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

  MediaBucket? _bucket;
  bool _searching = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_dropMissing);
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_dropMissing);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _dropMissing() {
    if (!mounted) return;
    setState(() {
      _files = _files.where((e) => e.exists).toList();
      _selected.removeWhere((s) => !_files.any((e) => e.path == s));
    });
  }

  /// Süzülmüş ve yeniden eskiye sıralı dosyalar (düz liste).
  List<FsEntry> get _visible {
    var list = _files;
    if (_bucket != null) {
      list = list.where((f) => bucketForPath(f.path) == _bucket).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = list.where((f) => fmMatches(f.name, _query)).toList();
    }
    final sorted = [...list]
      ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    return sorted;
  }

  /// Düz listeyi zaman gruplarına böler (sıra korunur → indeksler düz kalır).
  List<_Section> _sections(List<FsEntry> visible, PhotoGroup group) {
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
    final sections = _sections(visible, group);

    return Scaffold(
      appBar: _selecting
          ? _selectionBar(visible)
          : (_searching ? _searchBar() : _normalBar(appState)),
      body: Column(
        children: [
          if (!_selecting) _groupChips(appState, group),
          if (widget.showSources && !_selecting) _sourceChips(),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(_query.trim().isEmpty
                        ? 'Burada gösterilecek dosya yok.'
                        : '“$_query” için sonuç yok.'),
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
    );
  }

  PreferredSizeWidget _normalBar(AppState appState) => AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '${widget.title} içinde ara',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
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
        ],
      );

  PreferredSizeWidget _selectionBar(List<FsEntry> visible) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} / ${visible.length} seçildi'),
        actions: [
          IconButton(
            tooltip: visible.every((e) => _selected.contains(e.path))
                ? 'Seçimi kaldır'
                : 'Tümünü seç',
            icon: Icon(visible.every((e) => _selected.contains(e.path))
                ? Icons.deselect
                : Icons.select_all),
            onPressed: () => _toggleSelectAll(visible),
          ),
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
                  content: Text('Kopyalandı. Dosyalar sekmesinde hedef '
                      'klasörde yapıştırın.')));
            },
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final selected =
                  _files.where((e) => _selected.contains(e.path)).toList();
              if (await deleteEntries(context, selected)) _dropMissing();
            },
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
              const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
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
