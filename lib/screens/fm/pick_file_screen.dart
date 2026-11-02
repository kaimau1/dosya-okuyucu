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
///
/// ## Uygulama İÇİNDE de bu ekran (2026-11-01)
/// Kullanıcı (telefonda paylaş ekranındaki "dosya seç"): *"telefonunki değil,
/// bizim arayüzümüz açılsın."* Uygulamanın kendi dosya seçimleri artık
/// `FilePicker` yerine [AppFilePicker.pickFiles] üzerinden bu ekranı açar
/// ([PickFileScreen.request] dolu = uygulama içi kip: sonuç `Navigator.pop`
/// ile döner). Tam depolama izni yoksa ya da "Diğer kaynaklar" seçilirse
/// sistem seçicisine düşülür (Drive vb. yalnız oradan).
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_navigator.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/dashboard_layout.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/picker_bridge.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/section_header.dart';
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';
import 'dashboard_screen.dart';
import 'downloads_screen.dart' show downloadsPathIn;
import 'important_screen.dart';

/// Ekranın hangi görünümde olduğu.
enum _PickView { home, folder, category, search, matches }

/// Uygulamanın kendi dosya seçimleri için `FilePicker.platform.pickFiles`in
/// yerine geçer — aynı parametreler, aynı [FilePickerResult]; arayüz BİZİM
/// seçicimiz ([PickFileScreen]).
abstract final class AppFilePicker {
  /// "Diğer kaynaklar" dönüşü: çağıran sistem seçicisini açar.
  static const _system = '\u0000system';

  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
  }) async {
    Future<FilePickerResult?> system() => FilePicker.platform.pickFiles(
          dialogTitle: dialogTitle,
          type: type,
          allowedExtensions: allowedExtensions,
          allowMultiple: allowMultiple,
          withData: withData,
        );
    final nav = navigatorKey.currentState;
    // İzinsiz bizim seçicimiz hiçbir şey listeleyemez: sistem seçicisi.
    if (nav == null || !await StoragePermission.hasFullAccess()) {
      return system();
    }
    final exts = {
      for (final e in allowedExtensions ?? const <String>[])
        e.toLowerCase().replaceFirst('.', ''),
    };
    final mimes = switch (type) {
      FileType.image => const ['image/*'],
      FileType.video => const ['video/*'],
      FileType.audio => const ['audio/*'],
      FileType.media => const ['image/*', 'video/*'],
      // Yalnız uzantı listesi `*/*` sayılırdı: MIME'ları uzantılardan türet.
      FileType.custom => [
          for (final e in exts)
            PickerRequest.mimeForExtension(
                e, FsEntry.categoryForExtension(e)),
        ],
      FileType.any => const <String>[],
    };
    final paths = await nav.push<List<String>>(MaterialPageRoute(
      builder: (_) => PickFileScreen(
        request: PickerRequest(
          mimeTypes: mimes,
          extensions: type == FileType.custom ? exts : const {},
          title: dialogTitle,
          otherSources: true,
          allowMultiple: allowMultiple,
        ),
      ),
    ));
    if (paths == null || paths.isEmpty) return null;
    if (paths.first == _system) return system();
    final files = <PlatformFile>[];
    for (final path in paths) {
      final file = File(path);
      // Seçimle teslim arasında silinmiş olabilir: çağıran çökmesin.
      if (!await file.exists()) continue;
      files.add(PlatformFile(
        path: path,
        name: p.basename(path),
        size: await file.length(),
        bytes: withData ? await file.readAsBytes() : null,
      ));
    }
    return files.isEmpty ? null : FilePickerResult(files);
  }
}

class PickFileScreen extends StatefulWidget {
  /// Doluysa **uygulama içi kip**: istek buradan okunur, sonuç
  /// `Navigator.pop` ile döner. Boşsa başka uygulamanın isteği (köprü).
  final PickerRequest? request;

  const PickFileScreen({super.key, this.request});

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

  /// Çoklu seçim: yol → bayt (alt çubukta toplam boyut için).
  final _selected = <String, int>{};
  final _search = TextEditingController();
  Timer? _searchDebounce;

  /// Son seçim yapılan klasör: çoğu seçim aynı yerden tekrarlanır.
  String? _lastFolder;
  static const _lastFolderKey = 'pick_last_folder';

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
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final request = widget.request ?? await PickerBridge.request();
    await FmEnv.ensureInit();
    final access = await StoragePermission.hasFullAccess();
    String? lastFolder;
    try {
      lastFolder = (await SharedPreferences.getInstance())
          .getString(_lastFolderKey);
      if (lastFolder != null && !await Directory(lastFolder).exists()) {
        lastFolder = null;
      }
    } catch (_) {
      // Bilinçli: yalnız kısayol; okunamazsa çip görünmez.
    }
    if (!mounted) return;
    setState(() {
      _lastFolder = lastFolder;
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
    final hits = await _allOf(category, limit: 5000);
    List<FsEntry> recent = const [];
    try {
      await OpenHistory.ensureLoaded();
      final paths = OpenHistory.pathsByRecency().take(40).toList();
      recent = [
        for (final entry in await FsScan.statPaths(paths))
          if (!entry.isDir && _request.acceptsEntry(entry)) entry
      ].take(5).toList();
    } catch (_) {
      // Bilinçli: "son dosyalar" kısayolu yalnız kolaylık; geçmiş okunamazsa liste boş gösterilir, seçim yine gezinerek yapılır.
    }
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

  /// Bir türün bütün dosyaları: dizin hazırsa ondan, değilse (yeni kurulum,
  /// dizin daha yok) diski gezerek. Eskiden kategori ve arama yalnız dizine
  /// bakıyordu → ilk açılışta "boş" görünüyordu.
  Future<List<FsEntry>> _allOf(FmCategory? category, {required int limit}) async {
    try {
      await SearchIndex.ensureLoaded();
      final hits = SearchIndex.isReady
          ? await SearchIndex.query(
              '',
              category: category,
              includeDirs: false,
              matchAll: true,
              limit: limit,
            )
          : await FsScan.collect(
              FmEnv.volumeRoots,
              category: category,
              limit: limit,
            );
      // Uygulamaların gizli klasörleri (`.…recycle`) seçim listesine girmesin.
      return [
        for (final entry in hits)
          if (!entry.path.contains('/.')) entry
      ];
    } catch (_) {
      return const [];
    }
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
        _error = userErrorText(e);
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
    final hits = await _allOf(category, limit: 1000);
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
      await _toRoot();
      return;
    }
    setState(() {
      _view = _PickView.search;
      _loading = true;
      _error = '';
    });
    List<FsEntry> hits;
    try {
      await SearchIndex.ensureLoaded();
      if (SearchIndex.isReady) {
        hits = await SearchIndex.query(q, includeDirs: false, limit: 300);
      } else {
        final lower = q.toLowerCase();
        hits = [
          for (final entry in await _allOf(null, limit: 5000))
            if (entry.name.toLowerCase().contains(lower)) entry
        ];
      }
    } catch (_) {
      hits = const [];
    }
    // Yazmaya devam edildiyse eski sorgunun sonucu yenisini ezmesin.
    if (!mounted || _search.text.trim() != q) return;
    setState(() {
      _entries = [
        for (final entry in hits)
          if (_request.acceptsEntry(entry)) entry
      ];
      _loading = false;
    });
  }

  /// Geri: kategori/arama → ana sayfa, klasör → üst klasör, kök → iptal.
  bool get _inApp => widget.request != null;

  Future<void> _cancel() async {
    if (_inApp) {
      Navigator.of(context).pop();
    } else {
      await PickerBridge.cancel();
    }
  }

  Future<void> _onBack() async {
    if (_atRoot) {
      await _cancel();
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
    await _cancel();
  }

  Future<void> _deliver(List<String> paths) async {
    if (paths.isNotEmpty) {
      try {
        await (await SharedPreferences.getInstance())
            .setString(_lastFolderKey, p.dirname(paths.first));
      } catch (_) {
        // Bilinçli: yalnız kısayol; yazılamazsa seçim yine teslim edilir.
      }
      if (!mounted) return;
    }
    if (_inApp) {
      Navigator.of(context).pop(paths);
      return;
    }
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
        if (_selected.remove(entry.path) == null) {
          _selected[entry.path] = entry.sizeBytes;
        }
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
            icon: Icon(_atRoot ? AppIcons.close : AppIcons.back),
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
                onPressed: _inApp
                    ? () => Navigator.of(context)
                        .pop(const [AppFilePicker._system])
                    : PickerBridge.otherSources,
                icon: const Icon(AppIcons.openWith, size: 18),
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
                        style: context.type.caption.copyWith(color: faint),
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
                      setState(() {
                        _hasAccess = granted;
                        _matches = null;
                      });
                      await FmEnv.ensureInit(force: true);
                      await _toRoot();
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
                onChanged: (q) {
                  _searchDebounce?.cancel();
                  if (_view == _PickView.matches) {
                    setState(() {});
                    return;
                  }
                  _searchDebounce = Timer(Motion.medium,
                      () => _runSearch(q));
                },
                onSubmitted: (q) {
                  _searchDebounce?.cancel();
                  if (_view != _PickView.matches) _runSearch(q);
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _view == _PickView.matches &&
                          _request.kindLabel.isNotEmpty
                      ? context.t('pick.filter_hint', {'kind': _request.kindLabel})
                      : context.t('pick.search_hint'),
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.t('common.clear'),
                          icon: const Icon(AppIcons.close),
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
                  child: Row(
                    children: [
                      if (_selected.isNotEmpty) ...[
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: Text(context.t('common.clear')),
                        ),
                        const SizedBox(width: Gap.sm),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(AppIcons.check),
                          label: Text(
                            [
                              context.t('pick.select_n', {'n': _selected.length}),
                              if (_selected.isNotEmpty)
                                FsPaths.humanSize(_selected.values
                                    .fold(0, (a, b) => a + b)),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _selected.isEmpty
                              ? null
                              : () => _deliver(_selected.keys.toList()),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _body() {
    if (_loading) return const FmListSkeleton();
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
      return FmEmptyState(
        icon: AppIcons.folderOff,
        title: context.t('pick.empty'),
      );
    }
    final entries = [..._entries];
    if (_view != _PickView.folder || _byName) {
      entries.sort(_byName
          ? (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : (a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    }
    final files = entries.where((e) => !e.isDir).toList();
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) {
        if (i > 0) return _row(entries[i - 1]);
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            children: [
              _chip(
                label: context.t(_byName ? 'pick.sort_name' : 'pick.sort_newest'),
                icon: AppIcons.swapVert,
                onTap: () => setState(() => _byName = !_byName),
              ),
              if (_request.allowMultiple && files.isNotEmpty)
                _selectAllChip(files),
            ],
          ),
        );
      },
    );
  }

  /// Görünen bütün dosyalar seç / bırak.
  Widget _selectAllChip(List<FsEntry> files) {
    final all = files.every((e) => _selected.containsKey(e.path));
    return _chip(
      label: context.t('pick.select_all'),
      icon: AppIcons.check,
      selected: all,
      onTap: () => setState(() {
        for (final e in files) {
          if (all) {
            _selected.remove(e.path);
          } else {
            _selected[e.path] = e.sizeBytes;
          }
        }
      }),
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
          style: context.type.small.copyWith(color: faint),
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
              icon: AppIcons.swapVert,
              onTap: () => setState(() => _byName = !_byName),
            ),
            if (_request.allowMultiple && visible.isNotEmpty)
              _selectAllChip(visible),
            _chip(
              label: context.t('pick.browse_folders'),
              icon: AppIcons.emptyFolder,
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
              icon: const Icon(AppIcons.emptyFolder),
              label: Text(context.t('pick.browse_folders')),
            ),
          ),
        ],
      );
    }
    // Binlerce satır olabilir: başlık + satırlar TEMBEL kurulur.
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
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

  /// **Ana sayfa** — seçicinin asıl yüzü: panonun AYNISI (2026-11-02,
  /// kullanıcı: *"dosya seçici ekranı bizim ana ekranımızın aynısı olmalı,
  /// oradaki tüm kartlar bulunmalı"*). Bellek kartları, kullanıcının
  /// dizdiği kutu ızgarası ve hızlı klasörler; dokunuşlar uygulamanın
  /// ekranlarına değil seçicinin kendi görünümlerine gider.
  Widget _home() {
    final folders = StorageStats.standardFolders(FmEnv.primaryRoot);
    final tiles = _tiles();

    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
      children: [
        for (final v in FmEnv.volumes) ...[
          DashboardVolumeCard(
            volume: v,
            onTap: () => _openFolder(v.path),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (_recent.isNotEmpty) ...[
          SectionHeader(context.t('fm.recent_opened'),
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs)),
          for (final entry in _recent) _row(entry),
        ],
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          FmCategoryGrid(
            tiles: DashboardLayout.instance.arrangeTiles(tiles, (t) => t.id),
          ),
        ],
        SectionHeader(context.t('fm.quick_folders'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            if (_lastFolder case final last?)
              ActionChip(
                key: const ValueKey('pick-last-folder'),
                avatar: const Icon(AppIcons.history, size: 18),
                label: Text(p.basename(last)),
                tooltip: context.t('pick.last_folder'),
                onPressed: () => _openFolder(last),
              ),
            for (final folder in folders)
              ActionChip(
                avatar: const Icon(AppIcons.folder, size: 18),
                label: Text(folder.label),
                onPressed: () => _openFolder(folder.path),
              ),
            for (final root in FmEnv.volumeRoots)
              ActionChip(
                avatar: const Icon(AppIcons.storage, size: 18),
                label: Text(p.equals(root, FmEnv.primaryRoot)
                    ? context.t('fm.internal_storage')
                    : p.basename(root)),
                onPressed: () => _openFolder(root),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.database),
          title: Text(context.t('fm.all_files')),
          trailing: const Icon(AppIcons.chevron),
          onTap: () => _openFolder(FmEnv.primaryRoot),
        ),
      ],
    );
  }

  /// Panodaki kutuların seçicideki karşılığı. Seçilebilir dosya vermeyen
  /// kutular (Uygulamalar, Geçmiş, Kitaplık) burada YOK; Drive, çağıran
  /// "diğer kaynaklar"ı açtıysa onun kapısı olur. İstenen türü karşılamayan
  /// kategori kutusu hiç çizilmez (`image/*` isteyen yerde "Belgeler"e girip
  /// boş liste görmek zaman kaybı).
  List<FmTileData> _tiles() {
    final outlined = context.fmOutlinedIcons;
    String sub(CategoryStat stat) => stat.count == 0
        ? context.t('fm.none')
        : '${FsPaths.humanSize(stat.bytes)} (${stat.count})';

    FmTileData? category(String id, FmCategory c, {String? label}) {
      if (!_categoryAccepted(c)) return null;
      return FmTileData(
        id: id,
        icon: FmColors.iconFor(c, outlined: outlined),
        color: FmColors.forCategory(c),
        label: label ?? c.label,
        subtitle: sub(DashboardScreen.cachedStat(c)),
        onTap: () => _openCategory(c),
      );
    }

    final downloads = downloadsPathIn(FmEnv.primaryRoot);
    final important = ImportantScreen.pathIn(FmEnv.primaryRoot);
    return [
      if (downloads != null)
        FmTileData(
          id: 'downloads',
          icon: AppIcons.download,
          color: AppHues.blue,
          label: context.t('fm.downloads'),
          subtitle: '',
          onTap: () => _openFolder(downloads),
        ),
      if (Directory(important).existsSync())
        FmTileData(
          id: 'important',
          icon: AppIcons.star,
          color: AppHues.amber,
          label: ImportantScreen.folderName,
          subtitle: context.t('common.open'),
          onTap: () => _openFolder(important),
        ),
      if (category('image', FmCategory.image, label: context.t('fm.photos')) case final t?) t,
      if (category('video', FmCategory.video) case final t?) t,
      if (category('document', FmCategory.document) case final t?) t,
      if (category('audio', FmCategory.audio) case final t?) t,
      if (category('archive', FmCategory.archive) case final t?) t,
      if (category('apk', FmCategory.apk, label: context.t('fm.apk_files')) case final t?) t,
      if (_request.otherSources)
        FmTileData(
          id: 'drive',
          icon: AppIcons.cloud,
          color: AppHues.mint,
          label: 'Google Drive',
          subtitle: context.t('pick.other_sources'),
          onTap: _inApp
              ? () => Navigator.of(context).pop(const [AppFilePicker._system])
              : PickerBridge.otherSources,
        ),
    ];
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

  /// Ortak satır ([FmEntryRow], Faz 6): seçici de gezginle AYNI satırı
  /// çizer; çoklu seçimde onay rozeti önizlemenin köşesine biner.
  Widget _row(FsEntry entry) {
    final picked = _selected.containsKey(entry.path);
    return FmEntryRow(
      entry: entry,
      selected: picked,
      selecting: _request.allowMultiple && !entry.isDir,
      showChevron: true,
      // Ana sayfada ve arama sonucunda dosyanın NEREDE olduğu kritik:
      // aynı adlı iki dosyayı ayırt etmenin tek yolu bu.
      subtitle: entry.isDir
          ? FsPaths.humanDate(entry.modifiedMs)
          : (_view == _PickView.folder
              ? FsPaths.humanSize(entry.sizeBytes)
              : '${FsPaths.humanSize(entry.sizeBytes)} · '
                  '${p.basename(p.dirname(entry.path))}'),
      onCheck: () => _onTapEntry(entry),
      onTap: () => _onTapEntry(entry),
    );
  }
}
