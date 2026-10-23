import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/text_search.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/archive_password_dialog.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'browser_screen.dart';
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';

/// Arşiv görüntüleyici: RAR / 7z / ZIP / TAR içeriğini **çıkarmadan** listeler,
/// tek dosyayı önizler, tamamını ya da seçilen dosyayı çıkarır.
///
/// Parola korumalı arşivlerde parola sorulur (yanlışsa tekrar sorar);
/// çok parçalı setlerde (`.part2.rar`, `.r00`, `.7z.002`) sonraki ciltler
/// kendiliğinden bulunur.
class ArchiveScreen extends StatefulWidget {
  final String path;
  const ArchiveScreen({super.key, required this.path});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  ArchiveListing? _listing;
  String? _password;
  String? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? password}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listing = await ArchiveOps.list(widget.path, password: password);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _password = password;
        _loading = false;
      });
    } on ArchiveError catch (e) {
      if (!mounted) return;
      if (e.failure == ArchiveFailure.passwordRequired ||
          e.failure == ArchiveFailure.wrongPassword) {
        final entered = await _askPassword(
            retry: e.failure == ArchiveFailure.wrongPassword);
        if (entered == null) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = e.userMessage;
            });
          }
          return;
        }
        await _load(password: entered);
        return;
      }
      setState(() {
        _loading = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.t('arc.open_failed', {'error': userErrorText(e)});
      });
    }
  }

  Future<String?> _askPassword({bool retry = false}) =>
      askArchivePassword(context, retry: retry);

  /// Tamamını arşivin bulunduğu klasöre çıkarır.
  Future<void> _extractAll() async {
    try {
      final target = await showFmProgress<String>(
        context,
        title: context.t('fm.extracting'),
        name: context.t('fm.extracting_name'),
        cancellable: false,
        task: (report, _) => ArchiveOps.extract(
          widget.path,
          password: _password,
          onProgress: report,
        ),
      );
      if (!mounted) return;
      showSnackBarReplacing(ScaffoldMessenger.of(context), SnackBar(
        content: Text(context.t('fm.extracted_to', {'name': p.basename(target)})),
        action: SnackBarAction(
          label: context.t('common.open'),
          onPressed: () => Navigator.of(context).push(browserRoute(BrowserScreen(path: target),
          )),
        ),
      ));
    } on ArchiveError catch (e) {
      _snack(e.userMessage);
    } catch (e) {
      _snack(context.t('fm.extract_failed', {'error': userErrorText(e)}));
    }
  }

  /// Tek dosyayı arşivin klasörüne çıkarır.
  Future<void> _extractOne(ArchiveItem item) async {
    try {
      final out = await showFmProgress<String>(
        context,
        title: context.t('fm.extracting'),
        name: context.t('fm.extracting_name'),
        cancellable: false,
        task: (report, _) {
          report(FmProgress(0, 1, item.name));
          return ArchiveOps.extractOne(
            widget.path,
            item.path,
            p.dirname(widget.path),
            password: _password,
          );
        },
      );
      if (!mounted) return;
      _snack(context.t('arc.extracted_file', {'name': p.basename(out)}));
    } on ArchiveError catch (e) {
      _snack(e.userMessage);
    } catch (e) {
      _snack(context.t('fm.extract_failed', {'error': userErrorText(e)}));
    }
  }

  /// Arşivdeki dosyayı geçici klasöre açıp görüntüleyicide gösterir
  /// (arşivi diske açmadan "içine bakma").
  Future<void> _preview(ArchiveItem item) async {
    // Hata metni await'lerden ÖNCE (asenkron boşluktan sonra context yok).
    final openFailed = context.t('common.open_failed');
    try {
      final cache = await getTemporaryDirectory();
      // Geçici klasörü almak da bir `await`: kullanıcı bu arada geri gitmişse
      // ölü bir State'in context'iyle pencere açmaya çalışıyorduk.
      if (!mounted) return;
      final dir = Directory(p.join(cache.path, 'arsiv_onizleme'));
      final out = await showFmProgress<String>(
        context,
        title: context.t('arc.opening'),
        name: context.t('arc.opening_name'),
        cancellable: false,
        task: (report, _) {
          report(FmProgress(0, 1, item.name));
          return ArchiveOps.extractOne(
            widget.path,
            item.path,
            dir.path,
            password: _password,
          );
        },
      );
      if (!mounted) return;
      await EntryOpener.open(context, out);
    } on ArchiveError catch (e) {
      _snack(e.userMessage);
    } catch (e) {
      _snack(openFailed.replaceAll('{error}', userErrorText(e)));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }

  List<ArchiveItem> get _visible {
    final listing = _listing;
    if (listing == null) return const [];
    final files = listing.files;
    final q = turkishFold(_query.trim());
    final filtered = q.isEmpty
        ? files
        : files.where((f) => turkishFold(f.path).contains(q)).toList();
    filtered.sort((a, b) => a.path.compareTo(b.path));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    final items = _visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.path),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.t('fm.open_with_other'),
            icon: const Icon(AppIcons.openWith),
            onPressed: () => EntryOpener.openExternally(context, widget.path),
          ),
        ],
      ),
      floatingActionButton: listing == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _extractAll,
              icon: const Icon(AppIcons.extract),
              label: Text(context.t('arc.extract_all')),
            ),
      body: _loading
          ? const FmListSkeleton()
          : _error != null
              ? _errorView()
              : Column(
                  children: [
                    _header(listing!),
                    if (listing.files.length > 8) _searchBar(),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? FmEmptyState(icon: AppIcons.searchOff, title: context.t('arc.no_match'))
                          : ListView.builder(
                              padding: withNavInset(
                                  context, const EdgeInsets.only(bottom: 96)),
                              itemCount: items.length,
                              itemBuilder: (context, i) => _row(items[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.archiveView,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: Gap.md),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                children: [
                  FilledButton.tonal(
                      onPressed: () => _load(password: _password),
                      child: Text(context.t('common.retry'))),
                  OutlinedButton(
                    onPressed: () async {
                      final pw = await _askPassword();
                      if (pw != null) await _load(password: pw);
                    },
                    child: Text(context.t('fm.enter_password')),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        EntryOpener.openExternally(context, widget.path),
                    child: Text(context.t('fm.open_with_other')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _header(ArchiveListing listing) {
    final theme = Theme.of(context);
    final ratio = listing.totalBytes == 0
        ? null
        : (File(widget.path).lengthSync() / listing.totalBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${listing.formatName.toUpperCase()} · '
                  '${listing.files.length} dosya · '
                  '${FsPaths.humanSize(listing.totalBytes)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (ratio != null && ratio > 0)
                      context.t('arc.ratio', {'pct': (100 - ratio * 100).clamp(0, 100).round()}),
                    if (listing.hasEncryptedEntries) context.t('arc.encrypted'),
                    if (listing.multiVolume) context.t('arc.multipart'),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: context.t('arc.search'),
            prefixIcon: const Icon(AppIcons.search),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      );

  Widget _row(ArchiveItem item) {
    // Arşiv girdisi için diskte karşılığı olmayan bir FsEntry: ikon seçimi
    // (Word mavisi, görsel moru…) dosya yöneticisiyle aynı olsun diye.
    final pseudo = FsEntry(
      path: item.path,
      name: item.name,
      isDir: false,
      sizeBytes: item.size,
      modifiedMs: item.modifiedMs,
    );
    // Arşiv içindeki girdinin diskte dosyası yok → küçük resim istenmez
    // (FmEntryRow yalnız yerel yollarda küçük resim üretir).
    return FmEntryRow(
      entry: pseudo,
      thumbnails: false,
      selected: false,
      selecting: false,
      subtitle: [
        FsPaths.humanSize(item.size),
        if (item.parent.isNotEmpty) item.parent,
        if (item.compression.isNotEmpty && item.compression != 'stored')
          item.compression,
      ].join(' · '),
      badge: item.isEncrypted
          ? const Icon(AppIcons.lock, size: 18)
          : IconButton(
              tooltip: context.t('arc.extract_one'),
              icon: const Icon(AppIcons.download),
              onPressed: () => _extractOne(item),
            ),
      onTap: () => _preview(item),
      onMore: () => _extractOne(item),
    );
  }
}
