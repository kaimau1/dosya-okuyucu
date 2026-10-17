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
///
/// ## Belirli bir tür istenince ana sayfa DEĞİL, o türün dosyaları
/// Kullanıcı bulgusu 2026-10-17 (Notlar'dan PDF/ses eklerken): *"açılan dosya
/// yöneticisi menüsünde istenen uzantıya göre filtreleme yapılmalı; şu an
/// ana sayfa açılıyor sadece ve bulmak çok zor."* Ana sayfa `*/*` isteyen
/// (her şeyi kabul eden) çağıran için doğru yüz; PDF isteyen bir uygulamada
/// ise kullanıcı önce "Belgeler"e girip Word/Excel arasında PDF arıyordu.
/// Artık istek belirliyse ([PickerRequest.isSpecific]) ekran DOĞRUDAN o
/// türün tüm depolamadaki dosyalarıyla açılır ([_PickView.matches]): en
/// yenisi üstte, yazdıkça süzülür, birden çok uzantıda uzantı çipleri; son
/// açılanlar tepede. Ana sayfa ve klasörler bir dokunuş ötede ("Klasörlerde
/// gez"); çağıran destekliyorsa "Diğer kaynaklar" sistem seçicisine geçirir.
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
import '../../core/snack.dart';

/// Ekranın hangi görünümde olduğu.
enum _PickView { home, folder, category, search, matches }

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

  /// İstenen türün BÜTÜN dosyaları, en yenisi üstte ([_PickView.matches]).
  /// Bir kez kurulur; geri dönüşte yeniden taranmaz.
  List<FsEntry>? _matches;

  /// Eşleşme listesinde seçili uzantı (null = tümü).
  String? _extFilter;

  /// Eşleşme listesi ada göre mi sıralı (varsayılan: en yeni üstte).
  bool _byName = false;
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
    if (request.isSpecific) {
      await _openMatches();
    } else {
      await _loadHome();
    }
  }

  /// Seçicinin kök görünümü: belirli tür istendiyse eşleşme listesi, yoksa
  /// ana sayfa.
  bool get _atRoot => _request.isSpecific
      ? _view == _PickView.matches
      : _view == _PickView.home;

  Future<void> _toRoot() async {
    _search.clear();
    if (_request.isSpecific) {
      await _openMatches();
    } else {
      await _loadHome();
    }
  }

  /// **İstenen türün bütün dosyaları** — belirli bir tür istendiğinde
  /// seçicinin ilk yüzü. Dizin hazırsa ondan (isolate'te, kategoriyle
  /// daraltılmış), değilse diski gezerek kurulur.
  Future<void> _openMatches() async {
    final cached = _matches;
    if (cached != null) {
      setState(() {
        _view = _PickView.matches;
        _loading = false;
        _error = '';
      });
      return;
    }
    setState(() {
      _view = _PickView.matches;
      _loading = true;
      _error = '';
    });
    final category = _request.category;
    List<FsEntry> hits;
    try {
      await SearchIndex.ensureLoaded();
      hits = SearchIndex.isReady
          ? await SearchIndex.query(
              '',
              category: category,
              includeDirs: false,
              matchAll: true,
              limit: 5000,
            )
          : await FsScan.collect(
              FmEnv.volumeRoots,
              category: category,
              limit: 5000,
            );
    } catch (_) {
      hits = const [];
    }
    List<FsEntry> recent = const [];
    try {
      await OpenHistory.ensureLoaded();
      final paths = OpenHistory.pathsByRecency().take(40).toList();
      recent = [
        for (final entry in await FsScan.statPaths(paths))
          if (!entry.isDir && _request.acceptsEntry(entry)) entry
      ].take(5).toList();
    } catch (_) {}
    if (!mounted) return;
    final matches = [
      for (final entry in hits)
        if (!entry.isDir && _request.acceptsEntry(entry)) entry
    ]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    setState(() {
      _matches = matches;
      _recent = recent;
      _loading = false;
    });
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
    if (_atRoot) {
      await PickerBridge.cancel();
      return;
    }
    if (_view == _PickView.category || _view == _PickView.search) {
      _search.clear();
      await _loadHome();
      return;
    }
    if (_view == _PickView.home) {
      // Ana sayfa yalnız belirli tür isteğinde kök değil: eşleşmelere dön.
      await _toRoot();
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
    showSnack(context, context.t('pick.failed'));
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
        _PickView.home || _PickView.matches =>
          _request.title ?? context.t('pick.title'),
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
            icon: Icon(_atRoot ? Icons.close : Icons.arrow_back),
            tooltip: context.t('common.cancel'),
            onPressed: _onBack,
          ),
          title: _titleWidget(faint),
          actions: [
            // Kardeş uygulama (Notlar) "başka bir yerden seçeceğim" diyebilsin:
            // Drive, Galeri, sistem seçicisi — çağıran açar.
            if (_request.otherSources)
              TextButton.icon(
                key: const ValueKey('pick-other-sources'),
                onPressed: PickerBridge.otherSources,
                icon: const Icon(Icons.apps_outlined, size: 18),
                label: Text(context.t('pick.other_sources')),
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
                // Eşleşme listesinde arama YERELDE ve yazdıkça süzer (liste
                // zaten elde); diğer görünümlerde tüm depolamada arar.
                onChanged: (_) {
                  if (_view == _PickView.matches) setState(() {});
                },
                onSubmitted: (q) {
                  if (_view != _PickView.matches) _runSearch(q);
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _view == _PickView.matches &&
                          _request.kindLabel.isNotEmpty
                      ? context.t('pick.filter_hint', {'kind': _request.kindLabel})
                      : context.t('pick.search_hint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.t('common.clear'),
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            if (_view == _PickView.matches) {
                              setState(() {});
                            } else {
                              _toRoot();
                            }
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
    if (_view == _PickView.matches) return _matchesView();
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

  /// Başlık: çağıranın başlığı ("PDF seç") + altında "Notlar için · PDF".
  Widget _titleWidget(Color faint) {
    final title =
        Text(_titleText, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (!(_view == _PickView.home || _view == _PickView.matches)) return title;
    final parts = [
      if (_request.caller case final caller?)
        context.t('pick.for_caller', {'app': caller}),
      if (_request.kindLabel.isNotEmpty) _request.kindLabel,
    ];
    if (parts.isEmpty) return title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: faint),
        ),
      ],
    );
  }

  /// **Eşleşme listesi** — belirli tür isteğinin ilk yüzü.
  Widget _matchesView() {
    final all = _matches ?? const <FsEntry>[];
    final q = _search.text.trim().toLowerCase();
    final counts = <String, int>{};
    for (final entry in all) {
      final ext = entry.extension.toLowerCase();
      counts[ext] = (counts[ext] ?? 0) + 1;
    }
    final filter = counts.containsKey(_extFilter) ? _extFilter : null;
    final visible = [
      for (final entry in all)
        if ((filter == null || entry.extension.toLowerCase() == filter) &&
            (q.isEmpty || entry.name.toLowerCase().contains(q)))
          entry
    ];
    if (_byName) {
      visible.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final showRecent = q.isEmpty && filter == null && _recent.isNotEmpty;
    final exts = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final header = <Widget>[
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          children: [
            if (exts.length > 1) ...[
              _chip(
                label: '${context.t('pick.all')} · ${all.length}',
                selected: filter == null,
                onTap: () => setState(() => _extFilter = null),
              ),
              for (final ext in exts)
                _chip(
                  label: '${ext.isEmpty ? '?' : ext.toUpperCase()} · '
                      '${counts[ext]}',
                  selected: filter == ext,
                  onTap: () => setState(() => _extFilter = ext),
                ),
            ],
            _chip(
              label: context.t(_byName ? 'pick.sort_name' : 'pick.sort_newest'),
              icon: Icons.swap_vert,
              onTap: () => setState(() => _byName = !_byName),
            ),
            _chip(
              label: context.t('pick.browse_folders'),
              icon: Icons.folder_open_outlined,
              onTap: () {
                _search.clear();
                _loadHome();
              },
            ),
          ],
        ),
      ),
      if (showRecent) ...[
        SectionHeader(context.t('fm.recent_opened')),
        for (final entry in _recent) _row(entry),
      ],
      SectionHeader(context.t('pick.matches_count', {'n': visible.length})),
    ];

    if (visible.isEmpty) {
      return ListView(
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              context.t(all.isEmpty ? 'pick.no_matches' : 'pick.no_filter_matches'),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                _search.clear();
                _loadHome();
              },
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(context.t('pick.browse_folders')),
            ),
          ),
        ],
      );
    }
    // Binlerce satır olabilir: başlık + satırlar TEMBEL kurulur.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      itemCount: header.length + visible.length,
      itemBuilder: (context, i) =>
          i < header.length ? header[i] : _row(visible[i - header.length]),
    );
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    IconData? icon,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
        child: Center(
          child: FilterChip(
            avatar: icon == null ? null : Icon(icon, size: 16),
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
          ),
        ),
      );

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
