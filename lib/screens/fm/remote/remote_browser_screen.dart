import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../../../models/fs_entry.dart';
import '../../../models/remote_connection.dart';
import '../../../services/file_service.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/remote_fs.dart';
import '../../../services/fm/remote/remote_fs_factory.dart';
import '../../../services/fm/remote/usb_fs.dart';
import '../../../widgets/fm/fm_entry_icon.dart';
import '../browser_screen.dart';
import 'remote_edit_screen.dart';
import '../../../core/snack.dart';

/// Uzak sunucu gezgini: listeler, indirip açar, yükler, siler.
///
/// **Açma yolu indir-önbelleğe-aç.** Uzak dosya uygulamanın kendi klasörüne
/// iner, sonra mevcut [EntryOpener] zinciriyle açılır: PDF/Word/Excel/slayt/
/// video/arşiv desteğinin tamamı ilk günden çalışıyor ve `FileOps`un saf
/// `dart:io` değişmezi bozulmuyor.
class RemoteBrowserScreen extends StatefulWidget {
  final RemoteConnection connection;

  /// Testte sahte dosya sistemi takmak için.
  final RemoteFs? fs;

  const RemoteBrowserScreen({super.key, required this.connection, this.fs});

  @override
  State<RemoteBrowserScreen> createState() => _RemoteBrowserScreenState();
}

class _RemoteBrowserScreenState extends State<RemoteBrowserScreen> {
  late final RemoteFs _fs = widget.fs ?? createRemoteFs(widget.connection);

  late String _path = widget.connection.rootPath;
  List<RemoteEntry> _entries = const [];
  bool _busy = true;
  String? _error;
  bool _connected = false;

  /// **Seçili girdilerin yolları.** Kullanıcı isteği 2026-09-02 (dışarıdan
  /// bakış): USB'den "şu 30 fotoğrafı telefona kopyala" yapılamıyordu —
  /// çoklu seçim yoktu ve tek dosya için bile "kopyala" eylemi yoktu.
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  /// Klasör içi süzme metni (boşsa süzme yok).
  String _filter = '';
  bool _searching = false;

  /// Sıralama ölçütü ve yönü.
  _RemoteSort _sort = _RemoteSort.name;
  bool _ascending = true;

  /// Toplu iş sürerken ilerleme ("3/12"); yoksa null.
  String? _progress;

  /// Ham USB'de birimin doluluğu ("47,4 GB / 62 GB"); bilinmiyorsa boş.
  String _usage = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _fs.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _fs.connect();
      _connected = true;
      await _load(_path);
      unawaited(_loadUsage());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorTextFor(context, e);
      });
    }
  }

  Future<void> _load(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await _fs.list(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorTextFor(context, e);
      });
    }
  }

  /// Ekranda gösterilecek liste: süzülmüş ve sıralanmış.
  ///
  /// Klasörler HER ZAMAN önce gelir (boyuta göre sıralarken bile): dosya
  /// yöneticisinde gezinti klasörlerden geçer, onları büyüklüğe göre araya
  /// serpiştirmek gezinmeyi zorlaştırır.
  List<RemoteEntry> get _visible => sortEntries(
        _filter.trim().isEmpty
            ? _entries
            : [
                for (final e in _entries)
                  if (e.name.toLowerCase().contains(_filter.trim().toLowerCase()))
                    e,
              ],
        _sort,
        ascending: _ascending,
      );

  /// **Saf sıralama** (testli).
  static List<RemoteEntry> sortEntries(
    List<RemoteEntry> entries,
    _RemoteSort sort, {
    required bool ascending,
  }) {
    final out = [...entries];
    out.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final int c;
      switch (sort) {
        case _RemoteSort.name:
          c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _RemoteSort.size:
          c = a.sizeBytes.compareTo(b.sizeBytes);
        case _RemoteSort.date:
          c = a.modifiedMs.compareTo(b.modifiedMs);
      }
      if (c != 0) return ascending ? c : -c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  /// Ham USB'de doluluğu okur (yalnız bir kez; pahalı değil ama boşuna da
  /// tekrarlanmasın). Diğer protokollerde kapasite kavramı yok.
  Future<void> _loadUsage() async {
    final fs = _fs;
    if (fs is! UsbFs) return;
    final usage = await fs.usage();
    if (!mounted || usage == null) return;
    setState(() => _usage =
        '${FsPaths.humanSize(usage.$1 - usage.$2)} / ${FsPaths.humanSize(usage.$1)}');
  }

  bool get _atRoot => _path == widget.connection.rootPath || _path == '/';

  Future<void> _up() async {
    if (_atRoot) return;
    await _load(_fs.parentPath(_path));
  }

  Future<void> _open(RemoteEntry entry) async {
    if (entry.isDir) {
      await _load(entry.path);
      return;
    }
    final failed = context.t('nas.error_unknown');
    setState(() => _busy = true);
    try {
      final dir =
          p.join(FmEnv.appSupportDir, 'remote', safeCacheName(widget.connection.id));
      final local = await _fs.download(entry, p.join(dir, entry.name));
      // Düzenleme geri yazımının ölçütü: dosyanın açılmadan ÖNCEKİ hâli.
      // Boyut + değiştirilme damgası birlikte alınıyor; yalnız damga
      // güvenilmez (aynı saniyede kaydeden editörler var), yalnız boyut da
      // güvenilmez (aynı uzunlukta düzeltme).
      // `statSync` bilinçli: `stat()` (asenkron) `flutter_test`in sahte saat
      // zonunda HİÇ tamamlanmıyor ve ekran sonsuza dek "yükleniyor" kalıyor
      // (HAFIZA 2026-07-25 §F'deki tuzağın aynısı). Damga okuma birkaç
      // baytlık bir üstveri işi, dosya içeriği okunmuyor.
      final before = local.statSync();
      final beforeLength = before.size;
      final beforeModified = before.modified;
      if (!mounted) return;
      setState(() => _busy = false);
      await openLocalFile(context, local.path);
      // Ekran geri geldiğinde yerel kopya değiştiyse kullanıcı dosyayı
      // düzenlemiş demektir; sunucudaki sürüm HÂLÂ ESKİ.
      await _offerWriteBack(entry, local, beforeLength, beforeModified);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(mounted ? errorTextFor(context, e) : failed);
    }
  }

  /// Yerel kopya düzenlendiyse sunucuya geri yüklemeyi TEKLİF eder.
  ///
  /// **Neden sorulup otomatik yapılmıyor:** yükleme sunucudaki sürümün
  /// üzerine yazıyor. Kullanıcı dosyayı yalnız incelemek için açmış ve
  /// editör dokunmuş olabilir; sessizce üzerine yazmak, geri alınamayan bir
  /// karar vermek olurdu. Sormak da şart: hiç sormamak "kaydettim sandım,
  /// sunucuda eski hâli duruyor" demek — sessiz veri kaybı gibi görünür.
  Future<void> _offerWriteBack(
    RemoteEntry entry,
    File local,
    int beforeLength,
    DateTime beforeModified,
  ) async {
    if (!mounted) return;
    FileStat after;
    try {
      after = local.statSync();
    } catch (_) {
      return;
    }
    final changed =
        after.size != beforeLength || after.modified.isAfter(beforeModified);
    if (!changed || !mounted) return;

    final title = context.t('nas.writeback_title');
    final body = context.t('nas.writeback_body', {'name': entry.name});
    final upload = context.t('nas.writeback_upload');
    final keep = context.t('nas.writeback_keep_local');
    final uploading = context.t('nas.uploading');
    final done = context.t('nas.writeback_done');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(keep)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(upload)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _snack(uploading);
    try {
      await _fs.upload(local, _fs.parentPath(entry.path),
          name: entry.name);
      if (!mounted) return;
      _snack(done);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _delete(RemoteEntry entry) async {
    final ok = await _confirm(
        context.t('nas.delete_confirm', {'name': entry.name}));
    if (ok != true) return;
    try {
      await _fs.delete(entry);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _rename(RemoteEntry entry) async {
    final name = await _prompt(
        context.t('nas.rename'), context.t('nas.new_name'), entry.name);
    if (name == null || name.trim().isEmpty || name == entry.name) return;
    try {
      await _fs.rename(entry, name.trim());
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _newFolder() async {
    final name =
        await _prompt(context.t('nas.new_folder'), context.t('nas.folder_name'), '');
    if (name == null || name.trim().isEmpty) return;
    try {
      await _fs.makeDirectory(_fs.childPath(_path, name.trim()));
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  /// Yerel bir dosyayı buraya yükler (dosya seçici sistemin kendisi).
  Future<void> _upload() async {
    final uploading = context.t('nas.uploading');
    final done = context.t('nas.upload_done');
    final path = await pickLocalFile();
    if (path == null) return;
    if (!mounted) return;
    _snack(uploading);
    try {
      await _fs.upload(File(path), _path);
      if (!mounted) return;
      _snack(done);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<bool?> _confirm(String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.ok'))),
          ],
        ),
      );

  Future<String?> _prompt(String title, String label, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }

  @override
  Widget build(BuildContext context) {
    // Geri tuşu önce KLASÖR hiyerarşisinde yukarı çıkar; ekrandan çıkmaz.
    // Aksi hâlde kullanıcı beş klasör derinken tek dokunuşla dışarı atılırdı.
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionAppBar()
            : AppBar(
          title: _searching
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: context.t('nas.filter_hint'),
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                )
              : Text(widget.connection.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: 16, end: 16, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    _usage.isEmpty ? _path : '$_path  ·  $_usage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: context.t('nas.filter_hint'),
              icon: Icon(_searching ? Icons.search_off : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _filter = '';
              }),
            ),
            IconButton(
              tooltip: context.t('common.refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : () => _load(_path),
            ),
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (_) => [
                // Sıralama HER protokolde var (salt okunur bellekte de):
                // 4000 dosyalı bir USB'de sırasız liste kullanılamaz.
                for (final sort in _RemoteSort.values)
                  CheckedPopupMenuItem(
                    value: 'sort_${sort.name}',
                    checked: _sort == sort,
                    child: Text(context.t('nas.sort_${sort.name}')),
                  ),
                CheckedPopupMenuItem(
                  value: 'asc',
                  checked: _ascending,
                  child: Text(context.t('nas.sort_ascending')),
                ),
                if (_connected && _fs.canWrite) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'upload',
                      child: Text(context.t('nas.upload_here'))),
                  PopupMenuItem(
                      value: 'mkdir',
                      child: Text(context.t('nas.new_folder'))),
                ],
                // **Güvenle çıkar YALNIZ ham USB'de.** Android'in bağladığı
                // bir birimi uygulama çıkaramaz; oraya düğme koymak
                // çalışmayan bir söz vermek olurdu.
                if (_fs is UsbFs) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'eject', child: Text(context.t('usb.eject'))),
                ],
              ],
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  /// **Güvenle çıkar:** aygıt bırakılır ve ekran kapanır.
  ///
  /// Yazma yaptıysak bu bir güvenlik meselesi: yarıda kalan bir yazma
  /// bozuk dosya bırakır. Aygıtı bıraktığımızı SÖYLEMEK de şart — kullanıcı
  /// "çıkarabilir miyim?" sorusunun cevabını uygulamadan almalı.
  Future<void> _eject() async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.t('usb.eject_done');
    try {
      await _fs.close();
    } catch (_) {
      // Kapatılamadı — yine de ekrandan çıkıyoruz; aygıt zaten gitmiş olabilir.
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnackOn(messenger, done, duration: kSnackAction);
  }

  void _onMenu(String value) {
    if (value == 'eject') {
      unawaited(_eject());
      return;
    }
    if (value == 'upload') {
      unawaited(_upload());
      return;
    }
    if (value == 'mkdir') {
      unawaited(_newFolder());
      return;
    }
    if (value == 'asc') return setState(() => _ascending = !_ascending);
    for (final sort in _RemoteSort.values) {
      if (value == 'sort_${sort.name}') {
        setState(() => _sort = sort);
        return;
      }
    }
  }

  /// Seçim kipindeki başlık çubuğu.
  ///
  /// **"Telefona kopyala" salt okunur bellekte de var** (kullanıcı 2026-09-02
  /// dışarıdan bakış): kopyalamak yazma gerektirmez, oysa eski menü tamamen
  /// `canWrite`e bağlıydı ve NTFS bir diskte uzun basış hiçbir şey yapmıyordu.
  AppBar _selectionAppBar() => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length}'),
        actions: [
          IconButton(
            tooltip: context.t('fm.select_all'),
            icon: const Icon(Icons.select_all),
            onPressed: () => setState(() {
              final all = _visible.map((e) => e.path).toSet();
              if (_selected.containsAll(all)) {
                _selected.clear();
              } else {
                _selected.addAll(all);
              }
            }),
          ),
          IconButton(
            tooltip: context.t('nas.copy_to_phone'),
            icon: const Icon(Icons.download),
            onPressed: _busy ? null : () => unawaited(_copyToPhone()),
          ),
          if (_fs.canWrite) ...[
            if (_selected.length == 1)
              IconButton(
                tooltip: context.t('nas.rename'),
                icon: const Icon(Icons.drive_file_rename_outline),
                onPressed: _busy
                    ? null
                    : () => _rename(_entryOf(_selected.first)!),
              ),
            IconButton(
              tooltip: context.t('common.delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => unawaited(_deleteSelected()),
            ),
          ],
        ],
      );

  RemoteEntry? _entryOf(String path) {
    for (final e in _entries) {
      if (e.path == path) return e;
    }
    return null;
  }

  /// **Seçilenleri telefona kopyalar** — USB'nin bir numaralı kullanım amacı.
  ///
  /// Hedef `İndirilenler/Dosya Okuyucu`: kullanıcının ULAŞABİLECEĞİ bir yer.
  /// (Dosyayı açmak da kopyalıyor ama uygulamanın özel klasörüne; oraya
  /// kullanıcı giremez, dolayısıyla "kopyaladım" sayılmaz.)
  ///
  /// Klasörler bu turda atlanıyor ve sayısı kullanıcıya SÖYLENİYOR — sessizce
  /// atlamak "kopyaladım sandım" demek olurdu.
  Future<void> _copyToPhone() async {
    final targets = [
      for (final path in _selected)
        if (_entryOf(path) case final e?) e,
    ];
    final files = [for (final e in targets) if (!e.isDir) e];
    final skippedDirs = targets.length - files.length;
    if (files.isEmpty) {
      _snack(context.t('nas.copy_only_files'));
      return;
    }
    final dir = p.join(FmEnv.primaryRoot, 'Download', 'Dosya Okuyucu');
    final messenger = ScaffoldMessenger.of(context);
    final okText = context.t('nas.copied_to_phone');
    final openText = context.t('common.open');
    final skippedText = context.t('nas.copy_skipped_dirs');
    setState(() {
      _busy = true;
      _progress = '0/${files.length}';
    });
    var done = 0;
    String? failed;
    try {
      await Directory(dir).create(recursive: true);
      for (final entry in files) {
        try {
          await _fs.download(entry, _uniquePath(dir, entry.name));
          done++;
        } catch (e) {
          failed ??= entry.name;
        }
        if (!mounted) return;
        setState(() => _progress = '$done/${files.length}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
    if (!mounted) return;
    setState(_selected.clear);
    final parts = <String>[
      '$okText ($done/${files.length})',
      if (skippedDirs > 0) '$skippedDirs $skippedText',
      if (failed != null) '· $failed',
    ];
    showSnackOn(
      messenger,
      parts.join(' '),
      duration: kSnackAction,
      action: SnackBarAction(
        label: openText,
        onPressed: () => unawaited(Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BrowserScreen(path: dir)))),
      ),
    );
  }

  /// Aynı adlı dosyanın ÜSTÜNE YAZMAZ: `ad (2).jpg` üretir.
  static String _uniquePath(String dir, String name) {
    var candidate = p.join(dir, name);
    if (!File(candidate).existsSync()) return candidate;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    for (var i = 2; i < 1000; i++) {
      candidate = p.join(dir, '$base ($i)$ext');
      if (!File(candidate).existsSync()) return candidate;
    }
    return candidate;
  }

  Future<void> _deleteSelected() async {
    final entries = [
      for (final path in _selected)
        if (_entryOf(path) case final e?) e,
    ];
    if (entries.isEmpty) return;
    // Tek dosyada ADIYLA sor: "1 öğe silinsin mi?" demek, yanlış dosyayı
    // seçmiş kullanıcıya hiçbir şey söylemez.
    if (entries.length == 1) {
      await _delete(entries.first);
      if (mounted) setState(_selected.clear);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('common.delete')),
        content: Text(ctx.t('nas.delete_many', {'n': '${entries.length}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    for (final entry in entries) {
      try {
        await _fs.delete(entry);
      } catch (_) {
        // tek dosya silinemedi — kalanlara devam
      }
    }
    if (!mounted) return;
    setState(_selected.clear);
    await _load(_path);
  }

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _connected ? _load(_path) : _start(),
                child: Text(context.t('common.refresh')),
              ),
            ],
          ),
        ),
      );
    }

    final isSmbRoot = widget.connection.protocol == RemoteProtocol.smb &&
        (_path == '/' || _path.isEmpty);

    return Column(
      children: [
        // Toplu iş sürerken kaç dosya bitti? Sessiz bir bekleme, kullanıcıya
        // "takıldı mı?" dedirtiyordu.
        if (_progress != null)
          LinearProgressIndicator(
            value: _progressValue,
            minHeight: 3,
          ),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${context.t('nas.copying')} $_progress',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        if (isSmbRoot)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(context.t('nas.smb_share_root'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        Expanded(
          child: _visible.isEmpty
              ? Center(
                  child: Text(_filter.trim().isEmpty
                      ? context.t('nas.empty_folder')
                      : context.t('nas.no_match')))
              : RefreshIndicator(
                  onRefresh: () => _load(_path),
                  child: ListView.separated(
                    itemCount: _visible.length + (_atRoot ? 0 : 1),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (!_atRoot && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('..'),
                          onTap: _selecting ? null : _up,
                        );
                      }
                      final entry = _visible[_atRoot ? i : i - 1];
                      final selected = _selected.contains(entry.path);
                      // **Tür simgesi ve rengi** (kullanıcı 2026-09-02
                      // dışarıdan bakış): jenerik "dosya" simgesi listeyi
                      // okunmaz yapıyordu; yerel gezginle aynı dil.
                      final category = FsEntry.categoryForExtension(
                          p.extension(entry.name).replaceFirst('.', ''),
                          isDir: entry.isDir);
                      return ListTile(
                        selected: selected,
                        leading: selected
                            ? const Icon(Icons.check_circle)
                            : Icon(FmColors.iconFor(category),
                                color: FmColors.forCategory(category)),
                        title: Text(entry.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_subtitle(entry)),
                        onTap: () => _selecting
                            ? _toggle(entry)
                            : _open(entry),
                        // Uzun basış HER ZAMAN seçim başlatır (salt okunur
                        // bellekte de): kopyalamak yazma gerektirmiyor.
                        onLongPress: () => _toggle(entry),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// İlerleme çubuğunun değeri ("3/12" → 0.25); okunamazsa belirsiz çubuk.
  double? get _progressValue {
    final parts = _progress?.split('/');
    if (parts == null || parts.length != 2) return null;
    final done = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (done == null || total == null || total == 0) return null;
    return done / total;
  }

  void _toggle(RemoteEntry entry) => setState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      });

  String _subtitle(RemoteEntry entry) {
    final parts = <String>[
      if (!entry.isDir) FsPaths.humanSize(entry.sizeBytes),
      if (entry.modifiedMs > 0) FsPaths.humanDate(entry.modifiedMs),
    ];
    return parts.join(' · ');
  }

}

/// İndirilen kopyayı uygulamanın görüntüleyici/editör zincirinde açar.
///
/// Değiştirilebilir bir işlev: widget testinde gerçek görüntüleyici
/// açılamaz (dosya ayrıştırma + platform kanalı ister), testler bunu
/// sahtesiyle değiştirip "kullanıcı düzenledi" durumunu taklit ediyor.
/// **Bağlantı kimliğini klasör adı yapar** — saf, testli.
///
/// Kullanıcı hatası 2026-09-02 (ekran görüntüsü): ham USB'den bir mp3
/// açılınca *"Bu ses dosyası çalınamadı: MEDIA_ERROR_UNKNOWN"* çıkıyordu.
/// Kök neden dosya değil, YOL: indirilen kopya `…/remote/<bağlantı kimliği>/`
/// altına yazılıyor ve kimlik `usb:USB` (SAF'ta `saf:content://…`) gibi
/// **iki nokta ve eğik çizgi** içeriyor. Android'in MediaPlayer'ı böyle bir
/// yolu adres (URI) sanıp reddediyor; SAF'ta ise eğik çizgiler yolu
/// beklenmedik alt klasörlere bölüyordu.
///
/// Harf, rakam, `.`, `-` ve `_` dışındaki her şey `_` oluyor; ad boş kalırsa
/// `baglanti` deniyor (boş klasör adı yol birleştirmeyi bozardı).
String safeCacheName(String id) {
  final cleaned = id
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      // Art arda gelenler tek alt çizgiye iner: `content://` üç karakter,
      // üç alt çizgi olarak kalsaydı ad gereksiz çirkin olurdu.
      .replaceAll(RegExp(r'_{2,}'), '_');
  final trimmed = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'baglanti' : trimmed;
}

Future<void> Function(BuildContext context, String path) openLocalFile =
    (context, path) => EntryOpener.open(context, path);

/// Yüklenecek yerel dosyayı sistem seçicisiyle sorar.
///
/// Değiştirilebilir bir işlev: widget testinde dosya seçici açılamaz
/// (platform kanalı yok), testler bunu sahtesiyle değiştiriyor.
Future<String?> Function() pickLocalFile =
    () => FileService().pickFilePath();


/// Uzak/USB gezgininde sıralama ölçütü.
enum _RemoteSort { name, size, date }
