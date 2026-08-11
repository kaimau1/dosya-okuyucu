/// **Seçici kipi ekranı** — başka bir uygulama dosya isterken açılan bizim
/// arayüzümüz ("Şuradan aç" çekmecesindeki ok işareti buraya götürür).
///
/// ## Neden ham klasör listesi DEĞİL (kullanıcı bulgusu 2026-08-10)
/// *"orada direkt cihaz hafızası menüsü açılıyor, bu şekilde kullanışlı değil;
/// bizim ana sayfamız açılıp her türlü işleme oradan yönlendirebilmeliyiz."*
/// İlk sürüm depolamanın kökünü listeliyordu: kullanıcı aradığı dosyaya
/// ulaşmak için `Download`u ya da `DCIM`i kendisi bulmak zorundaydı — yani
/// sistem seçicisinden farkı yoktu, üstelik daha azını yapıyordu.
///
/// Artık **ana sayfa** açılıyor:
/// - üstte **arama** (arama dizininden, tüm depolama),
/// - **son açılan dosyalar** (çoğu seçim zaten son dokunulan dosyadır),
/// - **kategoriler** (Belgeler / Görüntüler / Videolar / Ses) — istenen türe
///   uymayanlar hiç gösterilmez,
/// - **hızlı klasörler** ve depolama birimleri,
/// - istenirse klasör klasör gezinme.
///
/// Seçim akışı sade tutuldu: burada dosya *seçilir*, yönetilmez. Kopyala/sil
/// gibi işlemler çağıran uygulama beklerken risk (ve yavaşlık) demek.
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/picker_bridge.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/section_header.dart';

/// Ekranın hangi görünümde olduğu.
enum _PickView { home, folder, category, search }

class PickFileScreen extends StatefulWidget {
  const PickFileScreen({super.key});

  @override
  State<PickFileScreen> createState() => _PickFileScreenState();
}

class _PickFileScreenState extends State<PickFileScreen> {
  PickerRequest _request = const PickerRequest();
  _PickView _view = _PickView.home;

  /// Gezilen klasör (yalnız [_PickView.folder]).
  String _path = '';

  /// Açık kategori (yalnız [_PickView.category]).
  FmCategory? _category;

  List<FsEntry> _entries = const [];
  List<FsEntry> _recent = const [];
  final _selected = <String>{};
  final _search = TextEditingController();

  bool _loading = true;
  bool _hasAccess = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final request = await PickerBridge.request();
    await FmEnv.ensureInit();
    final access = await StoragePermission.hasFullAccess();
    if (!mounted) return;
    setState(() {
      _request = request;
      _hasAccess = access;
      _path = FmEnv.primaryRoot;
    });
    await _loadHome();
  }

  /// Ana sayfanın tek asenkron parçası: son açılan dosyalar.
  Future<void> _loadHome() async {
    setState(() {
      _view = _PickView.home;
      _loading = true;
      _error = '';
    });
    try {
      await OpenHistory.ensureLoaded();
      final paths = OpenHistory.pathsByRecency().take(40).toList();
      final entries = await FsScan.statPaths(paths);
      if (!mounted) return;
      setState(() {
        _recent = [
          for (final entry in entries)
            if (!entry.isDir && _request.acceptsEntry(entry)) entry
        ].take(8).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recent = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openFolder(String path) async {
    setState(() {
      _view = _PickView.folder;
      _loading = true;
      _error = '';
    });
    try {
      final all = await FsScan.list(path);
      final visible = [
        for (final entry in all)
          if (_request.acceptsEntry(entry)) entry
      ];
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = FsScan.sort(visible, FmSort.name);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Bir kategorinin **tüm depolamadaki** dosyaları (arama dizininden).
  Future<void> _openCategory(FmCategory category) async {
    setState(() {
      _view = _PickView.category;
      _category = category;
      _loading = true;
      _error = '';
    });
    final hits = await SearchIndex.query(
      '',
      category: category,
      includeDirs: false,
      matchAll: true,
      limit: 1000,
    );
    if (!mounted) return;
    setState(() {
      _entries = [
        for (final entry in hits)
          if (_request.acceptsEntry(entry)) entry
      ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
      _loading = false;
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      await _loadHome();
      return;
    }
    setState(() {
      _view = _PickView.search;
      _loading = true;
      _error = '';
    });
    final hits = await SearchIndex.query(q, includeDirs: false, limit: 300);
    if (!mounted) return;
    setState(() {
      _entries = [
        for (final entry in hits)
          if (_request.acceptsEntry(entry)) entry
      ];
      _loading = false;
    });
  }

  /// Geri: kategori/arama → ana sayfa, klasör → üst klasör, kök → iptal.
  Future<void> _onBack() async {
    if (_view == _PickView.category || _view == _PickView.search) {
      _search.clear();
      await _loadHome();
      return;
    }
    if (_view == _PickView.folder) {
      final isRoot = FmEnv.volumeRoots.any((root) => p.equals(_path, root));
      if (isRoot) {
        await _loadHome();
        return;
      }
      final up = p.dirname(_path);
      if (up == _path) {
        await _loadHome();
        return;
      }
      await _openFolder(up);
      return;
    }
    await PickerBridge.cancel();
  }

  Future<void> _deliver(List<String> paths) async {
    final ok = await PickerBridge.deliver(paths);
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.t('pick.failed'))));
  }

  Future<void> _onTapEntry(FsEntry entry) async {
    if (entry.isDir) {
      await _openFolder(entry.path);
      return;
    }
    if (_request.allowMultiple) {
      setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      });
      return;
    }
    await _deliver([entry.path]);
  }

  String get _titleText => switch (_view) {
        _PickView.home => context.t('pick.title'),
        _PickView.folder => p.basename(_path),
        _PickView.category =>
          context.t(_category?.labelKey ?? 'fm.all_files'),
        _PickView.search => context.t('fm.search_all'),
      };

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(_view == _PickView.home ? Icons.close : Icons.arrow_back),
            tooltip: context.t('common.cancel'),
            onPressed: _onBack,
          ),
          title: Text(_titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (_view == _PickView.home)
              IconButton(
                tooltip: context.t('common.cancel'),
                icon: const Icon(Icons.close),
                onPressed: PickerBridge.cancel,
              ),
          ],
          bottom: _view == _PickView.folder
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: faint),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            if (!_hasAccess)
              MaterialBanner(
                content: Text(context.t('pick.need_permission')),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final granted = await StoragePermission.request();
                      if (!mounted) return;
                      setState(() => _hasAccess = granted);
                      await FmEnv.ensureInit(force: true);
                      await _loadHome();
                    },
                    child: Text(context.t('fm.permission_grant')),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.t('pick.search_hint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _loadHome();
                          },
                        ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
        bottomNavigationBar: _request.allowMultiple
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(
                        context.t('pick.select_n', {'n': _selected.length})),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _deliver(_selected.toList()),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child:
              Text(context.t('pick.unreadable'), textAlign: TextAlign.center),
        ),
      );
    }
    if (_view == _PickView.home) return _home();
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(context.t('pick.empty'), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, i) => _row(_entries[i]),
    );
  }

  /// **Ana sayfa** — seçicinin asıl yüzü.
  Widget _home() {
    final categories = [
      for (final category in const [
        FmCategory.document,
        FmCategory.image,
        FmCategory.video,
        FmCategory.audio,
      ])
        // İstenen türü karşılamayan kategori hiç gösterilmez: `image/*` isteyen
        // bir uygulamada "Belgeler"e girip boş liste görmek zaman kaybı.
        if (_categoryAccepted(category)) category
    ];
    final folders = StorageStats.standardFolders(FmEnv.primaryRoot);

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        if (_recent.isNotEmpty) ...[
          SectionHeader(context.t('fm.recent_opened')),
          for (final entry in _recent) _row(entry),
        ],
        if (categories.isNotEmpty) ...[
          SectionHeader(context.t('fm.categories')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final category in categories)
                  ActionChip(
                    avatar: Icon(_iconFor(category), size: 18),
                    label: Text(context.t(category.labelKey)),
                    onPressed: () => _openCategory(category),
                  ),
              ],
            ),
          ),
        ],
        SectionHeader(context.t('fm.quick_folders')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final folder in folders)
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(folder.label),
                  onPressed: () => _openFolder(folder.path),
                ),
              for (final root in FmEnv.volumeRoots)
                ActionChip(
                  avatar: const Icon(Icons.sd_storage_outlined, size: 18),
                  label: Text(p.basename(root)),
                  onPressed: () => _openFolder(root),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: Text(context.t('fm.all_files')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openFolder(FmEnv.primaryRoot),
        ),
      ],
    );
  }

  /// Bu kategoride çağıranın kabul edeceği dosya olabilir mi?
  bool _categoryAccepted(FmCategory category) {
    final sample = switch (category) {
      FmCategory.image => 'jpg',
      FmCategory.video => 'mp4',
      FmCategory.audio => 'mp3',
      _ => 'pdf',
    };
    return _request.accepts(
        PickerRequest.mimeForExtension(sample, category));
  }

  static IconData _iconFor(FmCategory category) => switch (category) {
        FmCategory.image => Icons.image_outlined,
        FmCategory.video => Icons.movie_outlined,
        FmCategory.audio => Icons.audiotrack_outlined,
        _ => Icons.description_outlined,
      };

  Widget _row(FsEntry entry) {
    final picked = _selected.contains(entry.path);
    return ListTile(
      leading: FmEntryIcon(entry: entry),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.isDir
          ? null
          : Text(
              // Ana sayfada ve arama sonucunda dosyanın NEREDE olduğu kritik:
              // aynı adlı iki dosyayı ayırt etmenin tek yolu bu.
              _view == _PickView.folder
                  ? FsPaths.humanSize(entry.sizeBytes)
                  : '${FsPaths.humanSize(entry.sizeBytes)} · '
                      '${p.basename(p.dirname(entry.path))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Paper.faint(context)),
            ),
      trailing: entry.isDir
          ? const Icon(Icons.chevron_right)
          : (_request.allowMultiple
              ? Checkbox(value: picked, onChanged: (_) => _onTapEntry(entry))
              : null),
      selected: picked,
      onTap: () => _onTapEntry(entry),
    );
  }
}
