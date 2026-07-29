import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../services/blank_docs.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/pin_dialog.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'archive_screen.dart';
import 'entry_actions.dart';
import 'organize_screen.dart';
import 'search_screen.dart';

/// Klasör gözatıcısı: listeleme, çoklu seçim, kopyala/kes/yapıştır, yeni
/// klasör/dosya, sıralama, ızgara/liste, favoriler.
///
/// Gezinme **push tabanlı**: her alt klasör yeni bir sayfadır → Android geri
/// tuşu doğal olarak bir üst klasöre çıkar, kaydırma konumu korunur.
class BrowserScreen extends StatefulWidget {
  final String path;

  /// Başlıkta klasör adı yerine gösterilecek etiket (ör. "Ana bellek").
  final String? title;

  const BrowserScreen({super.key, required this.path, this.title});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  List<FsEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};

  /// Liste ve ızgara aynı anda mount edilmediği için tek denetleyici yeterli;
  /// sürükleyerek seçimde kenara gelince otomatik kaydırma bunu kullanır.
  final ScrollController _scroll = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  /// Görünen tüm girdiler seçili mi? ("Tümünü seç" düğmesinin durumu.)
  bool get _allSelected =>
      _entries.isNotEmpty && _entries.every((e) => _selected.contains(e.path));

  /// Kilitli klasör açıldı ve PIN henüz doğrulanmadı → içerik gizlenir.
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    // Kilit denetimi ilk kareden sonra (context.read için mount gerekir).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLock());
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Kilit denetimi: klasör kilitliyse PIN sorulur, yanlışsa geri çıkılır.
  Future<void> _checkLock() async {
    final appState = context.read<AppState>();
    if (!appState.isFolderLocked(widget.path)) return;
    setState(() => _locked = true);
    final ok = await askPin(context, title: 'Kilitli klasör');
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
      await _load();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final list =
          await FsScan.list(widget.path, showHidden: appState.fmShowHidden);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
        // Silinen/taşınan öğeler seçimde kalmasın.
        _selected.removeWhere((s) => !list.any((e) => e.path == s));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Bu klasör okunamadı.\n'
            'Android’in koruduğu bir konum olabilir (Android/data gibi) ya da '
            '“tüm dosyalara erişim” izni verilmemiş olabilir.';
      });
    }
  }

  List<FsEntry> get _sorted {
    final appState = context.watch<AppState>();
    return FsScan.sort(_entries, appState.fmSort,
        descending: appState.fmSortDesc);
  }

  // ── işlemler ──────────────────────────────────────────────────────────────

  Future<void> _openEntry(FsEntry entry) async {
    if (_selecting) {
      _toggle(entry);
      return;
    }
    if (entry.isDir) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BrowserScreen(path: entry.path),
      ));
      if (mounted) _load(); // alt klasörde yapılan değişiklikler yansısın
      return;
    }
    // Arşive dokunmak: içeriği ÇIKARMADAN listelenir (RAR/7z/zip/tar).
    // Oradan tümünü ya da tek dosyayı çıkarabilir, önizleyebilir.
    if (ArchiveOps.canExtract(entry.path)) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveScreen(path: entry.path),
      ));
      if (mounted) _load(); // çıkarılan klasör listede görünsün
      return;
    }
    // Kardeş dosyalar: görselde kaydırmalı galeri, medyada çalma listesi.
    await EntryOpener.open(
      context,
      entry.path,
      siblings: _sorted.where((e) => !e.isDir).map((e) => e.path).toList(),
    );
  }

  void _toggle(FsEntry entry) {
    setState(() {
      if (!_selected.remove(entry.path)) _selected.add(entry.path);
    });
  }

  /// Sürükleyerek seçimde çağrılır: görünen sıradaki [start]..[end] aralığı.
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

  /// Toplu seçme: hepsi seçiliyse seçimi kaldırır, değilse tümünü seçer.
  void _toggleSelectAll() {
    final all = _entries.map((e) => e.path).toSet();
    setState(() {
      if (_selected.length >= all.length && all.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected.addAll(all);
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

  List<FsEntry> get _selectedEntries =>
      _entries.where((e) => _selected.contains(e.path)).toList();

  Future<void> _paste() async {
    final appState = context.read<AppState>();
    final sources = appState.clipboard;
    if (sources.isEmpty) return;
    final cut = appState.clipboardCut;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: cut ? 'Taşınıyor' : 'Kopyalanıyor',
      task: (report, isCancelled) => cut
          ? FileOps.moveAll(sources, widget.path,
              onProgress: report, isCancelled: isCancelled)
          : FileOps.copyAll(sources, widget.path,
              onProgress: report, isCancelled: isCancelled),
    );
    appState.clearClipboard();
    if (!mounted) return;
    if (result.hasError) {
      _snack('Bazı öğeler aktarılamadı: ${result.errors.first}');
    } else if (result.cancelled) {
      _snack('İşlem iptal edildi (aktarılanlar yerinde kaldı).');
    }
    _load();
  }

  Future<void> _newFolder() async {
    final name = await _askName('Yeni klasör', 'Klasör adı', 'Yeni klasör');
    if (name == null) return;
    try {
      await FileOps.createFolder(widget.path, name);
      _load();
    } catch (e) {
      _snack('Klasör oluşturulamadı: $e');
    }
  }

  /// Yeni boş belge (metin / Word / Excel) — mevcut BlankDocs üreteçleriyle,
  /// ama dosya GEÇERLİ klasöre yazılır (BlankDocs kendi dizinine yazıyordu).
  Future<void> _newDocument(String kind) async {
    final suggestion = switch (kind) {
      'docx' => 'Yeni Belge.docx',
      'xlsx' => 'Yeni Tablo.xlsx',
      _ => 'Yeni Metin.txt',
    };
    final name = await _askName('Yeni dosya', 'Dosya adı', suggestion);
    if (name == null) return;
    try {
      final target =
          FileOps.uniquePath(p.join(widget.path, FileOps.sanitizeName(name)));
      final bytes = switch (kind) {
        'docx' => BlankDocs.blankDocx(),
        'xlsx' => BlankDocs.blankXlsx(),
        _ => const <int>[],
      };
      await File(target).writeAsBytes(bytes);
      if (!mounted) return;
      _load();
      await EntryOpener.open(context, target);
    } catch (e) {
      _snack('Dosya oluşturulamadı: $e');
    }
  }

  Future<String?> _askName(String title, String label, String initial) async {
    final controller = TextEditingController(text: initial);
    final dot = initial.lastIndexOf('.');
    controller.selection = TextSelection(
        baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = _sorted;

    return Scaffold(
      appBar: _selecting ? _selectionBar(context, entries) : _normalBar(context),
      // Stack: alt eylem çubuğu gövdenin yüksekliğini DEĞİŞTİRMESİN (aksi
      // hâlde liste zıplıyor — 2026-07-29 hatası).
      body: Stack(
        children: [
          Column(
        children: [
          _Breadcrumb(
            path: widget.path,
            onTap: (target) {
              // Üst klasöre atlamak = yığında oraya kadar geri gitmek yerine
              // yeni sayfa açmak; geri tuşu yine çalışır, kod basit kalır.
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BrowserScreen(path: target),
              ));
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _locked
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: Text(
                        'Bu klasör kilitli.\nGörmek için PIN girin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _body(entries),
          ),
          if (appState.hasClipboard && !_selecting) _pasteBar(appState),
        ],
          ),
          // Seçim varken alt eylem çubuğu: Taşı · Kopyala · Paylaş · Sil.
          // (Üst çubuktaki küçük simgeler başparmakla zor ve taşıma orada yoktu.)
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FmSelectionBar(
                selected: _selectedEntries,
                zipDestDir: widget.path,
                onChanged: () async {
                  setState(_selected.clear);
                  _load();
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: _showCreateSheet,
              tooltip: 'Yeni klasör / dosya',
              child: const Icon(Icons.add),
            ),
    );
  }

  PreferredSizeWidget _normalBar(BuildContext context) {
    final appState = context.watch<AppState>();
    final starred = appState.isBookmarked(widget.path);
    return AppBar(
      title: Text(widget.title ?? p.basename(widget.path),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Bu klasörde ara',
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SearchScreen(root: widget.path),
          )),
        ),
        IconButton(
          tooltip: 'Görünüm: ${appState.fmLayout.label}',
          icon: Icon(fmLayoutIcon(appState.fmLayout)),
          onPressed: () async {
            final picked =
                await showFmLayoutSheet(context, current: appState.fmLayout);
            if (picked != null) await appState.setFmLayout(picked);
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'Diğer',
          onSelected: (value) async {
            switch (value) {
              case 'sort_name':
                appState.setFmSort(FmSort.name);
              case 'sort_date':
                appState.setFmSort(FmSort.date, descending: true);
              case 'sort_size':
                appState.setFmSort(FmSort.size, descending: true);
              case 'sort_type':
                appState.setFmSort(FmSort.type);
              case 'sort_dir':
                appState.setFmSort(appState.fmSort,
                    descending: !appState.fmSortDesc);
              case 'hidden':
                await appState.setFmShowHidden(!appState.fmShowHidden);
                _load();
              case 'star':
                appState.toggleBookmark(widget.path);
              case 'lock':
                if (!appState.fmHasLockPin && !await setupPin(context)) break;
                if (!context.mounted) break;
                // Kilidi KALDIRIRKEN de PIN sorulur: telefonu eline alan biri
                // kilidi tek dokunuşla açabilseydi kilit anlamsız olurdu.
                if (appState.isFolderLocked(widget.path) &&
                    !await askPin(context)) {
                  break;
                }
                await appState.toggleLockedFolder(widget.path);
              case 'organize':
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrganizeScreen(path: widget.path),
                ));
                _load();
              case 'select_all':
                _toggleSelectAll();
              case 'refresh':
                _load();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'sort_name', child: Text('Ada göre sırala')),
            const PopupMenuItem(
                value: 'sort_date', child: Text('Tarihe göre sırala')),
            const PopupMenuItem(
                value: 'sort_size', child: Text('Boyuta göre sırala')),
            const PopupMenuItem(
                value: 'sort_type', child: Text('Türe göre sırala')),
            PopupMenuItem(
              value: 'sort_dir',
              child:
                  Text(appState.fmSortDesc ? 'Artan sırala' : 'Azalan sırala'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'hidden',
              child: Text(appState.fmShowHidden
                  ? 'Gizli dosyaları gizle'
                  : 'Gizli dosyaları göster'),
            ),
            PopupMenuItem(
              value: 'star',
              child: Text(starred ? 'Favorilerden çıkar' : 'Favorilere ekle'),
            ),
            PopupMenuItem(
              value: 'lock',
              child: Text(appState.isFolderLocked(widget.path)
                  ? 'Klasör kilidini kaldır'
                  : 'Klasörü kilitle (PIN)'),
            ),
            const PopupMenuItem(
                value: 'organize', child: Text('Otomatik düzenle…')),
            const PopupMenuItem(value: 'select_all', child: Text('Tümünü seç')),
            const PopupMenuItem(value: 'refresh', child: Text('Yenile')),
          ],
        ),
      ],
    );
  }

  /// Seçim üst çubuğu **sade**: sayaç + seçme yardımcıları. Eylemler
  /// (Taşı/Kopyala/Paylaş/Sil/…) alttaki [FmSelectionBar]'da — proje kuralı:
  /// üstte yalnız altta karşılığı OLMAYAN durur (HAFIZA 2026-07-28 D).
  PreferredSizeWidget _selectionBar(BuildContext context, List<FsEntry> visible) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length} / ${_entries.length} seçildi'),
      actions: [
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
          tooltip: _allSelected ? 'Seçimi kaldır' : 'Tümünü seç',
          icon: Icon(_allSelected ? Icons.deselect : Icons.select_all),
          onPressed: _toggleSelectAll,
        ),
        IconButton(
          tooltip: 'Seçimi tersine çevir',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => setState(() {
            final all = _entries.map((e) => e.path).toSet();
            final inverted = all.difference(_selected);
            _selected
              ..clear()
              ..addAll(inverted);
          }),
        ),
      ],
    );
  }

  Widget _pasteBar(AppState appState) {
    final count = appState.clipboard.length;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
          child: Row(
            children: [
              Icon(appState.clipboardCut
                  ? Icons.content_cut
                  : Icons.copy_outlined),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  '$count öğe ${appState.clipboardCut ? "taşınmaya" : "kopyalanmaya"} hazır',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: appState.clearClipboard,
                child: const Text('Vazgeç'),
              ),
              FilledButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Yapıştır'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<FsEntry> entries) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: Gap.md),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton.tonal(
                  onPressed: _load, child: const Text('Yeniden dene')),
            ],
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.folder_open,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: Gap.md),
            const Center(child: Text('Bu klasör boş')),
          ],
        ),
      );
    }

    final layout = context.watch<AppState>().fmLayout;
    return RefreshIndicator(
      onRefresh: _load,
      // Uzun basış artık öğelerde değil BURADA yakalanır (çocuk uzun basışı
      // jest arenasını kazanıp sürüklemeyi öldürürdü) → basılı tutup kaydırınca
      // çapa ile parmağın altındaki öğe arasındaki tüm dosyalar seçilir.
      child: DragSelectArea(
        scrollController: _scroll,
        isSelected: (i) =>
            i >= 0 && i < entries.length && _selected.contains(entries[i].path),
        onSelectRange: (a, b, sel) => _selectRange(entries, a, b, sel),
        child: layout.isGrid ? _grid(entries, layout) : _list(entries, layout),
      ),
    );
  }

  Widget _list(List<FsEntry> entries, FmLayout layout) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 96),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return DragSelectItem(
            index: i,
            child: FmEntryListTile(
              entry: e,
              layout: layout,
              selected: _selected.contains(e.path),
              selecting: _selecting,
              showChevron: true,
              subtitle: e.isDir
                  ? FsPaths.humanDate(e.modifiedMs)
                  : '${FsPaths.humanSize(e.sizeBytes)} · '
                      '${FsPaths.humanDate(e.modifiedMs)}',
              onTap: () => _openEntry(e),
              onCheck: () => _toggle(e),
              onMore: () async {
                if (await showEntryActions(context, e)) _load();
              },
            ),
          );
        },
      );

  Widget _grid(List<FsEntry> entries, FmLayout layout) => LayoutBuilder(
        builder: (context, constraints) {
          const pad = Gap.sm;
          return GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(pad, pad, pad, 96),
            gridDelegate:
                fmGridDelegate(layout, constraints.maxWidth - pad * 2),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return DragSelectItem(
                index: i,
                child: FmEntryGridTile(
                  entry: e,
                  layout: layout,
                  selected: _selected.contains(e.path),
                  selecting: _selecting,
                  onTap: () => _openEntry(e),
                ),
              );
            },
          );
        },
      );

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Yeni klasör'),
              onTap: () {
                Navigator.pop(ctx);
                _newFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Word belgesi (.docx)'),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('docx');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Excel tablosu (.xlsx)'),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('xlsx');
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Metin dosyası (.txt)'),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('txt');
              },
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

/// Yol çubuğu: her parçaya dokununca o klasöre gider.
class _Breadcrumb extends StatelessWidget {
  final String path;
  final void Function(String) onTap;
  const _Breadcrumb({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = <({String label, String path})>[];
    // Kök olarak birim köklerini kullan: kullanıcıya "/storage/emulated/0"
    // yerine "Ana bellek" gösterilir.
    var remainder = p.normalize(path);
    String? rootPath;
    String rootLabel = 'Kök';
    for (final v in FmEnv.volumes) {
      if (FsPaths.isInside(v.path, remainder)) {
        rootPath = p.normalize(v.path);
        rootLabel = v.label;
        break;
      }
    }
    rootPath ??= '/';
    segments.add((label: rootLabel, path: rootPath));
    if (remainder.length > rootPath.length) {
      final rest = remainder
          .substring(rootPath.length)
          .split('/')
          .where((s) => s.isNotEmpty);
      var acc = rootPath;
      for (final s in rest) {
        acc = p.join(acc, s);
        segments.add((label: s, path: acc));
      }
    }

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // uzun yolda son klasör görünür kalsın
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
        itemCount: segments.length,
        itemBuilder: (context, i) {
          final seg = segments[segments.length - 1 - i];
          final isLast = i == 0;
          return Row(
            children: [
              if (!isLast)
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
              TextButton(
                onPressed: isLast ? null : () => onTap(seg.path),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  foregroundColor: isLast ? scheme.onSurface : scheme.primary,
                ),
                child: Text(
                  seg.label,
                  style: TextStyle(
                      fontWeight: isLast ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
