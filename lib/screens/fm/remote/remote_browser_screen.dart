import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../../../models/remote_connection.dart';
import '../../../services/file_service.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/remote_fs.dart';
import '../../../services/fm/remote/remote_fs_factory.dart';
import 'remote_edit_screen.dart';

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

  bool get _atRoot => _path == widget.connection.rootPath || _path == '/';

  Future<void> _up() async {
    if (_atRoot) return;
    await _load(RemoteFs.parentOf(_path));
  }

  Future<void> _open(RemoteEntry entry) async {
    if (entry.isDir) {
      await _load(entry.path);
      return;
    }
    final failed = context.t('nas.error_unknown');
    setState(() => _busy = true);
    try {
      final dir = p.join(FmEnv.appSupportDir, 'remote', widget.connection.id);
      final local = await _fs.download(entry, p.join(dir, entry.name));
      if (!mounted) return;
      setState(() => _busy = false);
      await EntryOpener.open(context, local.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(mounted ? errorTextFor(context, e) : failed);
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
      await _fs.makeDirectory(RemoteFs.join(_path, name.trim()));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
        appBar: AppBar(
          title: Text(widget.connection.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: 16, end: 16, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(_path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: context.t('common.refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : () => _load(_path),
            ),
            if (_connected && _fs.canWrite)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'upload') _upload();
                  if (v == 'mkdir') _newFolder();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'upload',
                      child: Text(context.t('nas.upload_here'))),
                  PopupMenuItem(
                      value: 'mkdir',
                      child: Text(context.t('nas.new_folder'))),
                ],
              ),
          ],
        ),
        body: _body(),
      ),
    );
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
        if (isSmbRoot)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(context.t('nas.smb_share_root'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        Expanded(
          child: _entries.isEmpty
              ? Center(child: Text(context.t('nas.empty_folder')))
              : RefreshIndicator(
                  onRefresh: () => _load(_path),
                  child: ListView.separated(
                    itemCount: _entries.length + (_atRoot ? 0 : 1),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (!_atRoot && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('..'),
                          onTap: _up,
                        );
                      }
                      final entry = _entries[_atRoot ? i : i - 1];
                      return ListTile(
                        leading: Icon(entry.isDir
                            ? Icons.folder_outlined
                            : Icons.insert_drive_file_outlined),
                        title: Text(entry.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_subtitle(entry)),
                        onTap: () => _open(entry),
                        onLongPress:
                            _fs.canWrite ? () => _entryMenu(entry) : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _subtitle(RemoteEntry entry) {
    final parts = <String>[
      if (!entry.isDir) FsPaths.humanSize(entry.sizeBytes),
      if (entry.modifiedMs > 0) FsPaths.humanDate(entry.modifiedMs),
    ];
    return parts.join(' · ');
  }

  void _entryMenu(RemoteEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(ctx.t('nas.rename')),
              onTap: () {
                Navigator.pop(ctx);
                _rename(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(ctx.t('common.delete')),
              onTap: () {
                Navigator.pop(ctx);
                _delete(entry);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Yüklenecek yerel dosyayı sistem seçicisiyle sorar.
///
/// Değiştirilebilir bir işlev: widget testinde dosya seçici açılamaz
/// (platform kanalı yok), testler bunu sahtesiyle değiştiriyor.
Future<String?> Function() pickLocalFile =
    () => FileService().pickFilePath();
