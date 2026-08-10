/// **Seçici kipi ekranı** — başka bir uygulama dosya isterken açılan bizim
/// arayüzümüz ("Şuradan aç" çekmecesindeki ok işareti buraya götürür).
///
/// Tasarım kararları:
/// - **Ayrı ve sade bir ekran**, tam dosya yöneticisi değil: burada kullanıcı
///   dosya seçmeye gelmiştir; kopyala/sil/paylaş menüleri hem yavaşlatır hem
///   de yanlışlıkla dosya bozma riski taşır (çağıran uygulama beklerken).
/// - **Tek dokunuş = seçim.** Çoklu seçim yalnız çağıran istediyse
///   (`EXTRA_ALLOW_MULTIPLE`) açılır; o zaman satırlar kutucuklu olur.
/// - **İstenen türe uymayan dosya listelenmez** (klasörler hep görünür).
///   Kullanıcının seçemeyeceği bir dosyayı göstermek, dokunup "neden olmuyor"
///   dedirtir.
/// - Geri tuşu klasör yukarı çıkar; en üstte iptal eder → çağıran uygulama
///   "vazgeçildi" alır, boş sonuç değil.
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/picker_bridge.dart';
import '../../services/fm/storage_permission.dart';
import '../../widgets/fm/fm_entry_icon.dart';

class PickFileScreen extends StatefulWidget {
  const PickFileScreen({super.key});

  @override
  State<PickFileScreen> createState() => _PickFileScreenState();
}

class _PickFileScreenState extends State<PickFileScreen> {
  PickerRequest _request = const PickerRequest();
  String _path = '';
  List<FsEntry> _entries = const [];
  final _selected = <String>{};
  bool _loading = true;
  bool _hasAccess = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _boot();
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
    await _load(_path);
  }

  Future<void> _load(String path) async {
    setState(() {
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

  /// Bir üst klasör; kök ise `null` (geri tuşu iptale döner).
  String? get _parent {
    for (final root in FmEnv.volumeRoots) {
      if (p.equals(_path, root)) return null;
    }
    final up = p.dirname(_path);
    return up == _path ? null : up;
  }

  Future<bool> _onBack() async {
    final up = _parent;
    if (up == null) {
      await PickerBridge.cancel();
      return false;
    }
    await _load(up);
    return false;
  }

  Future<void> _deliver(List<String> paths) async {
    final ok = await PickerBridge.deliver(paths);
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('pick.failed'))),
    );
  }

  Future<void> _onTapEntry(FsEntry entry) async {
    if (entry.isDir) {
      await _load(entry.path);
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
            icon: const Icon(Icons.close),
            tooltip: context.t('common.cancel'),
            onPressed: PickerBridge.cancel,
          ),
          title: Text(
            _path.isEmpty ? context.t('pick.title') : p.basename(_path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
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
          ),
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
                      await _load(_path);
                    },
                    child: Text(context.t('fm.permission_grant')),
                  ),
                ],
              ),
            if (FmEnv.volumeRoots.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  children: [
                    for (final root in FmEnv.volumeRoots)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.xs, top: 6),
                        child: ChoiceChip(
                          label: Text(p.basename(root)),
                          selected: _path.startsWith(root),
                          onSelected: (_) => _load(root),
                        ),
                      ),
                  ],
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
                    label: Text(context
                        .t('pick.select_n', {'n': _selected.length})),
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
          child: Text(context.t('pick.unreadable'), textAlign: TextAlign.center),
        ),
      );
    }
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
      itemBuilder: (context, i) {
        final entry = _entries[i];
        final picked = _selected.contains(entry.path);
        return ListTile(
          leading: FmEntryIcon(entry: entry),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: entry.isDir
              ? null
              : Text(
                  FsPaths.humanSize(entry.sizeBytes),
                  style: TextStyle(
                      fontSize: 12, color: Paper.faint(context)),
                ),
          trailing: entry.isDir
              ? const Icon(Icons.chevron_right)
              : (_request.allowMultiple
                  ? Checkbox(
                      value: picked,
                      onChanged: (_) => _onTapEntry(entry),
                    )
                  : null),
          selected: picked,
          onTap: () => _onTapEntry(entry),
        );
      },
    );
  }
}
