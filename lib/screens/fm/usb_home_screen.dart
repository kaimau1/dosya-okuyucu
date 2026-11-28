import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_location.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/motion.dart';
import '../../widgets/section_header.dart';
import 'analysis_screen.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'entry_actions.dart';
import 'photos_screen.dart';

/// Harici depolama (USB / SD kart) için ana menü tarzı ekran + klasik
/// klasör görünümü arası tek dokunuşla geçiş.
///
/// Tüm USB okumaları salt okunurdur (`FsScan.index` / `FsScan.list`); kullanıcı
/// açıkça kopyalama veya silme seçmedikçe belleğe hiçbir veri yazılmaz.
class UsbHomeScreen extends StatefulWidget {
  final StorageVolume volume;

  const UsbHomeScreen({super.key, required this.volume});

  @override
  State<UsbHomeScreen> createState() => _UsbHomeScreenState();
}

class _UsbHomeScreenState extends State<UsbHomeScreen> {
  static const _viewPrefKey = 'usb_view_home';

  bool _homeView = true;
  bool _loadingHome = true;
  bool _loadingDir = false;
  StorageIndex _index = StorageIndex.empty;
  late String _dirPath = widget.volume.path;
  List<FsEntry> _dirEntries = const [];
  String? _dirError;
  final Set<String> _selected = {};
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_onFsChanged);
    _initView();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_onFsChanged);
    super.dispose();
  }

  void _onFsChanged() {
    if (!mounted) return;
    unawaited(_scanHome());
    if (!_homeView) unawaited(_loadDir(_dirPath));
  }

  Future<void> _initView() async {
    var home = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      home = prefs.getBool(_viewPrefKey) ?? true;
    } catch (_) {
      // Tercih okunamazsa varsayılan ana görünüm açılır.
    }
    if (!mounted) return;
    setState(() => _homeView = home);
    unawaited(_scanHome());
    if (!home) unawaited(_loadDir(_dirPath));
  }

  Future<void> _toggleView(bool home) async {
    setState(() {
      _homeView = home;
      _selected.clear();
    });
    try {
      await (await SharedPreferences.getInstance()).setBool(_viewPrefKey, home);
    } catch (_) {
      // Oturum içinde geçiş yine çalışır.
    }
    if (!home && _dirEntries.isEmpty && _dirError == null) {
      unawaited(_loadDir(_dirPath));
    }
  }

  Future<void> _scanHome() async {
    if (!mounted) return;
    setState(() => _loadingHome = true);
    try {
      // Yalnız bu birimi tara — arama dizinine veya telefon kategorilerine
      // karıştırma.
      final idx = await FsScan.index([widget.volume.path]);
      if (!mounted) return;
      setState(() {
        _index = idx;
        _loadingHome = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHome = false);
    }
  }

  Future<void> _loadDir(String path) async {
    setState(() {
      _loadingDir = true;
      _dirError = null;
      _selected.clear();
    });
    try {
      final raw = await FsScan.list(path);
      final sorted = FsScan.sort(raw, FmSort.name);
      if (!mounted) return;
      setState(() {
        _dirPath = path;
        _dirEntries = sorted;
        _loadingDir = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dirPath = path;
        _dirEntries = const [];
        _dirError = userErrorText(e);
        _loadingDir = false;
      });
    }
  }

  bool get _atVolumeRoot =>
      p.normalize(_dirPath) == p.normalize(widget.volume.path);

  Future<void> _goUpOrPop() async {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
      return;
    }
    if (!_homeView && !_atVolumeRoot) {
      final up = p.dirname(_dirPath);
      await _loadDir(up.length < widget.volume.path.length
          ? widget.volume.path
          : up);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copySelected() async {
    final paths = _selected.toList();
    if (paths.isEmpty) return;
    final changed = await moveOrCopyEntries(context, paths, move: false);
    if (changed && mounted) setState(_selected.clear);
  }

  Future<void> _openCategory(FmCategory cat) async {
    final label = context.t(cat.labelKey);
    Future<List<FsEntry>> loadAll() =>
        MediaLibrary.categoryFiles(cat, root: widget.volume.path);
    final Widget screen =
        cat == FmCategory.image || cat == FmCategory.video
            ? PhotosScreen(
                title: label,
                scopeId: 'usb-${widget.volume.path}-${cat.name}',
                files: _index.files(cat),
                loadAll: loadAll,
              )
            : CategoryScreen(
                title: label,
                files: _index.files(cat),
                loadAll: loadAll,
              );
    await Navigator.of(context).push(browserRoute(screen));
  }

  List<FmTileData> _tiles() {
    String sub(FmCategory c) {
      final s = _index.stat(c);
      if (s.count == 0) return context.t('fm.none');
      return '${FsPaths.humanSize(s.bytes)} (${s.count})';
    }

    FmTileData cat(FmCategory c, FmTileArt? art) => FmTileData(
          id: 'usb_${c.name}',
          icon: FmColors.iconFor(c),
          color: FmColors.forCategory(c),
          art: art,
          label: context.t(c.labelKey),
          subtitle: sub(c),
          onTap: () => unawaited(_openCategory(c)),
        );

    return [
      cat(FmCategory.document, FmTileArt.document),
      cat(FmCategory.image, FmTileArt.photos),
      cat(FmCategory.video, FmTileArt.video),
      cat(FmCategory.audio, FmTileArt.audio),
      cat(FmCategory.archive, null),
      FmTileData(
        id: 'usb_folders',
        icon: AppIcons.folder,
        color: AppHues.teal,
        label: context.t('usb.all_folders'),
        subtitle: '${_index.totalFiles}',
        onTap: () => unawaited(_toggleView(false)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.volume;
    final label = v.displayLabel(context.t);
    final selecting = _selected.isNotEmpty;

    return PopScope(
      canPop: _homeView && !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goUpOrPop());
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: context.t('common.clear_selection'),
                  icon: const Icon(AppIcons.close),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length}'),
                actions: [
                  IconButton(
                    tooltip: context.t('fm.copy'),
                    icon: const Icon(AppIcons.copy),
                    onPressed: _copySelected,
                  ),
                ],
              )
            : AppBar(
                title: _searching
                    ? TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: context.t('common.search'),
                        ),
                        onChanged: (q) => setState(() => _query = q),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (!_homeView)
                            Text(
                              _dirPath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                actions: [
                  IconButton(
                    tooltip: context.t(
                        _homeView ? 'usb.view_folders' : 'usb.view_home'),
                    icon: Icon(
                        _homeView ? AppIcons.folder : AppIcons.spaceDashboard),
                    onPressed: () => unawaited(_toggleView(!_homeView)),
                  ),
                  IconButton(
                    tooltip: context.t('common.search'),
                    icon: Icon(
                        _searching ? AppIcons.searchOff : AppIcons.search),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                  ),
                  IconButton(
                    tooltip: context.t('fm.memory_analysis'),
                    icon: const Icon(AppIcons.donutSmall),
                    onPressed: () => Navigator.of(context).push(browserRoute(
                      AnalysisScreen(index: _index, volumes: [v]),
                    )),
                  ),
                ],
              ),
        body: _homeView ? _buildHomeView(v) : _buildFolderView(),
      ),
    );
  }

  Widget _buildHomeView(StorageVolume v) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final recent = [
      for (final e in _index.recent)
        if (q.isEmpty || e.name.toLowerCase().contains(q)) e,
    ].take(40).toList();

    return RefreshIndicator(
      onRefresh: _scanHome,
      child: ListView(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(volumeIcon(v), size: 28, color: scheme.primary),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.displayLabel(context.t),
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (v.hasStats)
                              Text(
                                context.t('ana.used_free', {
                                  'used': FsPaths.humanCapacity(v.usedBytes),
                                  'free': FsPaths.humanCapacity(v.freeBytes),
                                }),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (v.hasStats) ...[
                    const SizedBox(height: Gap.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v.usedFraction,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => unawaited(_toggleView(false)),
                      icon: const Icon(AppIcons.folder, size: 18),
                      label: Text(context.t('usb.all_folders')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingHome)
            const Padding(
              padding: EdgeInsets.only(top: Gap.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: Gap.md),
          FmCategoryGrid(tiles: _tiles()),
          SectionHeader(
            context.t('usb.recent_on_drive'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs),
          ),
          if (recent.isEmpty && !_loadingHome)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.lg),
              child: Text(
                context.t('usb.empty_drive'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final entry in recent) _entryRow(entry),
        ],
      ),
    );
  }

  Widget _buildFolderView() {
    if (_loadingDir) return const FmListSkeleton();
    if (_dirError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_dirError!, textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton(
                onPressed: () => unawaited(_loadDir(_dirPath)),
                child: Text(context.t('common.refresh')),
              ),
            ],
          ),
        ),
      );
    }
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? _dirEntries
        : [
            for (final e in _dirEntries)
              if (e.name.toLowerCase().contains(q)) e,
          ];
    if (visible.isEmpty && _atVolumeRoot) {
      return FmEmptyState(
        icon: AppIcons.folderOff,
        title: context.t('usb.empty_folder'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadDir(_dirPath),
      child: ListView.builder(
        padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
        itemCount: visible.length + (_atVolumeRoot ? 0 : 1),
        itemBuilder: (_, i) {
          if (!_atVolumeRoot && i == 0) {
            return ListTile(
              leading: const Icon(AppIcons.arrowUp),
              title: const Text('..'),
              onTap: _selected.isNotEmpty ? null : _goUpOrPop,
            );
          }
          return _entryRow(visible[_atVolumeRoot ? i : i - 1]);
        },
      ),
    );
  }

  Widget _entryRow(FsEntry entry) {
    final selected = _selected.contains(entry.path);
    return FmEntryRow(
      entry: entry,
      selected: selected,
      selecting: _selected.isNotEmpty,
      subtitle: _homeView
          ? FmLocation.label(entry.path, context.t, volumes: [widget.volume])
          : '',
      dateText: FmLocation.shortDate(entry.modifiedMs),
      subtitleEnd: entry.isDir ? null : FsPaths.humanSize(entry.sizeBytes),
      showDivider: true,
      onCheck: () => setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      }),
      onTap: () {
        if (_selected.isNotEmpty) {
          setState(() {
            if (!_selected.remove(entry.path)) _selected.add(entry.path);
          });
          return;
        }
        if (entry.isDir) {
          if (_homeView) {
            setState(() {
              _homeView = false;
              _dirPath = entry.path;
            });
          }
          unawaited(_loadDir(entry.path));
          return;
        }
        unawaited(EntryOpener.open(context, entry.path));
      },
      onLongPress: () => setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      }),
    );
  }
}
