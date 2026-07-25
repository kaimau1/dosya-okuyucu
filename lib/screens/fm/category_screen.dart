import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/file_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_search_field.dart';
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

  /// Kaynak filtresi (Kamera / WhatsApp / Telegram / Ekran görüntüsü …)
  /// gösterilsin mi? Görsel ve video kategorilerinde anlamlı.
  final bool showSources;

  /// Belge türü süzgeci (PDF / Word / Excel / Slayt / Metin) gösterilsin mi?
  /// Kullanıcı isteği: "belgelerde filtre olmalı, PDF slayt text word vs
  /// ayırt edilebilmeli".
  final bool showDocKinds;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.files,
    this.gridDefault = false,
    this.showSources = false,
    this.showDocKinds = false,
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

  /// Seçili kaynak (null = tümü).
  MediaBucket? _bucket;

  /// Seçili belge türü (null = tümü).
  DocKind? _docKind;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

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
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FsEntry> get _sorted {
    var filtered = _files;
    if (_bucket != null) {
      filtered =
          filtered.where((f) => bucketForPath(f.path) == _bucket).toList();
    }
    if (_docKind != null) {
      filtered = filtered
          .where((f) => FileService.kindForExtension(f.extension) == _docKind)
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      filtered = filtered.where((f) => fmMatches(f.name, _query)).toList();
    }
    return FsScan.sort(filtered, _sort, descending: _desc, foldersFirst: false);
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
  void _dropMissing() {
    if (!mounted) return;
    setState(() {
      _files = _files.where((e) => e.exists).toList();
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
    return Scaffold(
      appBar: _selecting
          ? _selectionBar(files)
          : (_searching ? _searchBar() : _normalBar()),
      body: Column(
        children: [
          if (widget.showSources && !_selecting) _sourceChips(),
          if (widget.showDocKinds && !_selecting) _docKindChips(),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text(_query.trim().isEmpty
                        ? 'Bu kategoride dosya bulunamadı.'
                        : '“$_query” için sonuç yok.'),
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
    );
  }

  PreferredSizeWidget _normalBar() => AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '${widget.title} içinde ara',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            tooltip: 'Görünüm: ${_layout.label}',
            icon: Icon(fmLayoutIcon(_layout)),
            onPressed: () async {
              final picked = await showFmLayoutSheet(context, current: _layout);
              if (picked != null) setState(() => _layout = picked);
            },
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
      );

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeSearch,
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

  PreferredSizeWidget _selectionBar(List<FsEntry> files) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} / ${files.length} seçildi'),
        actions: [
          IconButton(
            tooltip: files.every((e) => _selected.contains(e.path))
                ? 'Seçimi kaldır'
                : 'Tümünü seç',
            icon: Icon(files.every((e) => _selected.contains(e.path))
                ? Icons.deselect
                : Icons.select_all),
            onPressed: () => _toggleSelectAll(files),
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
                  content: Text(
                      'Kopyalandı. Dosyalar sekmesinde hedef klasörde yapıştırın.')));
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
              label: Text('Tümü (${_files.length})'),
              selected: _docKind == null,
              onSelected: (_) => setState(() => _docKind = null),
            ),
          ),
          for (final k in kinds)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: ChoiceChip(
                label: Text('${k == DocKind.unknown ? "Diğer" : k.label} '
                    '(${counts[k]})'),
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
            padding: const EdgeInsets.all(pad),
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
