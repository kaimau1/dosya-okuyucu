import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/archive_password_dialog.dart';
import '../../widgets/fm/compress_sheet.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'archive_screen.dart';

/// Girdi (dosya/klasör) üzerinde yapılabilecek işlemler. Gözatıcı, kategori
/// ekranları ve arama sonuçları AYNI davranışı paylaşsın diye tek dosyada.
enum _EntryAction {
  open,
  openWith,
  share,
  copy,
  cut,
  rename,
  delete,
  zip,
  extract,
  openArchive,
  bookmark,
  reveal,
  properties,
}

/// Uzun basınca açılan işlem sayfası. Dosya sistemi değiştiyse `true` döner
/// (çağıran listeyi yeniler).
Future<bool> showEntryActions(
  BuildContext context,
  FsEntry entry, {
  /// "Konumunu aç" gösterilsin mi? (Kategori/arama ekranlarında anlamlı.)
  bool allowReveal = false,
  void Function(String path)? onReveal,
}) async {
  final appState = context.read<AppState>();
  final isArchive = ArchiveOps.canExtract(entry.path);

  final action = await showModalBottomSheet<_EntryAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: FmEntryIcon(entry: entry, size: 40),
              title: Text(entry.name,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(entry.isDir
                  ? 'Klasör · ${FsPaths.humanDate(entry.modifiedMs)}'
                  : '${FsPaths.humanSize(entry.sizeBytes)} · '
                      '${FsPaths.humanDate(entry.modifiedMs)}'),
            ),
            const Divider(),
            _tile(ctx, Icons.open_in_new, 'Aç', _EntryAction.open),
            if (!entry.isDir)
              _tile(ctx, Icons.apps, 'Başka uygulamayla aç',
                  _EntryAction.openWith),
            if (!entry.isDir)
              _tile(ctx, Icons.share_outlined, 'Paylaş', _EntryAction.share),
            _tile(ctx, Icons.copy_outlined, 'Kopyala', _EntryAction.copy),
            _tile(ctx, Icons.content_cut, 'Kes', _EntryAction.cut),
            _tile(ctx, Icons.drive_file_rename_outline, 'Yeniden adlandır',
                _EntryAction.rename),
            if (isArchive)
              _tile(ctx, Icons.folder_zip_outlined, 'Arşiv içeriğini göster',
                  _EntryAction.openArchive),
            if (isArchive)
              _tile(ctx, Icons.unarchive_outlined, 'Buraya çıkar',
                  _EntryAction.extract),
            _tile(ctx, Icons.archive_outlined, 'Sıkıştır (ZIP / 7z, parolalı)',
                _EntryAction.zip),
            if (entry.isDir)
              _tile(
                ctx,
                appState.isBookmarked(entry.path)
                    ? Icons.star
                    : Icons.star_border,
                appState.isBookmarked(entry.path)
                    ? 'Favorilerden çıkar'
                    : 'Favorilere ekle',
                _EntryAction.bookmark,
              ),
            if (allowReveal)
              _tile(ctx, Icons.my_location, 'Konumunu aç', _EntryAction.reveal),
            _tile(ctx, Icons.info_outline, 'Özellikler',
                _EntryAction.properties),
            _tile(ctx, Icons.delete_outline, 'Sil (çöp kutusuna)',
                _EntryAction.delete,
                danger: true),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    ),
  );

  if (action == null || !context.mounted) return false;

  switch (action) {
    case _EntryAction.open:
      if (entry.isDir) {
        onReveal?.call(entry.path);
      } else {
        await EntryOpener.open(context, entry.path);
      }
      return false;

    case _EntryAction.openWith:
      await EntryOpener.openExternally(context, entry.path);
      return false;

    case _EntryAction.share:
      await shareEntries([entry.path]);
      return false;

    case _EntryAction.copy:
      appState.setClipboard([entry.path], cut: false);
      _snack(context, '“${entry.name}” kopyalandı. Hedef klasörde yapıştırın.');
      return false;

    case _EntryAction.cut:
      appState.setClipboard([entry.path], cut: true);
      _snack(context, '“${entry.name}” kesildi. Hedef klasörde yapıştırın.');
      return false;

    case _EntryAction.rename:
      return renameEntry(context, entry);

    case _EntryAction.delete:
      return deleteEntries(context, [entry]);

    case _EntryAction.zip:
      return zipEntries(context, [entry.path], _parentOf(entry.path));

    case _EntryAction.extract:
      return extractArchive(context, entry.path);

    case _EntryAction.openArchive:
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveScreen(path: entry.path),
      ));
      return true;

    case _EntryAction.bookmark:
      await appState.toggleBookmark(entry.path);
      return false;

    case _EntryAction.reveal:
      onReveal?.call(_parentOf(entry.path));
      return false;

    case _EntryAction.properties:
      await showProperties(context, entry);
      return false;
  }
}

Widget _tile(
  BuildContext ctx,
  IconData icon,
  String label,
  _EntryAction action, {
  bool danger = false,
}) {
  final color = danger ? Theme.of(ctx).colorScheme.error : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: color == null ? null : TextStyle(color: color)),
    onTap: () => Navigator.pop(ctx, action),
  );
}

// ── Tek tek işlemler (çoklu seçim araç çubuğu da bunları çağırır) ───────────

/// Yeniden adlandırma penceresi. Değiştiyse `true`.
Future<bool> renameEntry(BuildContext context, FsEntry entry) async {
  final controller = TextEditingController(text: entry.name);
  // Uzantıyı seçimin dışında bırak: kullanıcı adı düzeltirken ".pdf"i
  // yanlışlıkla silmesin.
  final dot = entry.isDir ? -1 : entry.name.lastIndexOf('.');
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: dot > 0 ? dot : entry.name.length,
  );

  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Yeniden adlandır'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Yeni ad'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (newName == null || newName.trim().isEmpty) return false;
  try {
    await FileOps.rename(entry.path, newName);
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, 'Yeniden adlandırılamadı: $e');
    return false;
  }
}

/// Seçilenleri siler. Ayarlara göre çöp kutusuna taşır ya da kalıcı siler;
/// "silmeden önce sor" kapalıysa onay penceresi atlanır (ama KALICI silmede
/// veri geri gelmeyeceği için onay her zaman sorulur).
Future<bool> deleteEntries(BuildContext context, List<FsEntry> entries) async {
  if (entries.isEmpty) return false;
  final appState = context.read<AppState>();
  final useTrash = appState.fmUseTrash;
  final label = entries.length == 1
      ? '“${entries.first.name}”'
      : '${entries.length} öğe';

  if (appState.fmConfirmDelete || !useTrash) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(useTrash
            ? 'Çöp kutusuna taşınsın mı?'
            : 'Kalıcı olarak silinsin mi?'),
        content: Text(useTrash
            ? '$label çöp kutusuna taşınacak. '
                'Geri Dönüşüm Kutusu’ndan geri yükleyebilirsiniz.'
            : '$label KALICI olarak silinecek. Bu işlem geri alınamaz. '
                '(Çöp kutusu ayarlardan kapalı.)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(useTrash ? 'Taşı' : 'Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
  }

  final paths = entries.map((e) => e.path).toList();
  if (!useTrash) {
    final result = await showFmProgress<FmOpResult>(
      context,
      title: 'Siliniyor',
      cancellable: false,
      task: (report, _) => FileOps.deleteAll(paths, onProgress: report),
    );
    if (context.mounted && result.hasError) {
      _snack(context, 'Bazı öğeler silinemedi: ${result.errors.first}');
    }
    return true;
  }

  await FmEnv.ensureInit();
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: 'Çöp kutusuna taşınıyor',
    cancellable: false,
    task: (report, _) =>
        FmEnv.trash.moveToTrash(paths, onProgress: report),
  );
  if (context.mounted && result.hasError) {
    _snack(context, 'Bazı öğeler taşınamadı: ${result.errors.first}');
  }
  return true;
}

/// Kalıcı silme (çöp kutusunu atlar) — çöp ekranında kullanılır.
Future<bool> deleteForever(BuildContext context, List<String> paths) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kalıcı olarak silinsin mi?'),
      content: const Text('Bu işlem geri alınamaz.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await showFmProgress(
    context,
    title: 'Siliniyor',
    cancellable: false,
    task: (report, _) => FileOps.deleteAll(paths, onProgress: report),
  );
  if (context.mounted && result.hasError) {
    _snack(context, 'Silinemedi: ${result.errors.first}');
  }
  return true;
}

Future<void> shareEntries(List<String> paths) async {
  if (paths.isEmpty) return;
  await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
}

/// Seçilenleri sıkıştırır: biçim (ZIP/7z) ve isteğe bağlı parola sorulur.
Future<bool> zipEntries(
    BuildContext context, List<String> paths, String destDir) async {
  if (paths.isEmpty) return false;
  final options = await showCompressSheet(context);
  if (options == null || !context.mounted) return false;
  try {
    final zipPath = await showFmProgress<String>(
      context,
      title: options.password == null
          ? 'Sıkıştırılıyor'
          : 'Şifreleniyor (AES-256)',
      cancellable: false,
      task: (report, _) => ArchiveOps.compress(
        paths,
        destDir,
        format: options.format,
        password: options.password,
        hideNames: options.hideNames,
        onProgress: report,
      ),
    );
    if (context.mounted) {
      _snack(context, '${zipPath.split('/').last} oluşturuldu.');
    }
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, 'Sıkıştırılamadı: $e');
    return false;
  }
}

/// Arşivi bulunduğu klasöre çıkarır. Parola korumalıysa sorar (yanlışsa
/// tekrar sorar); RAR/7z dahil tüm desteklenen biçimler aynı yoldan geçer.
Future<bool> extractArchive(
  BuildContext context,
  String archivePath, {
  String? password,
}) async {
  try {
    final target = await showFmProgress<String>(
      context,
      title: 'Çıkarılıyor',
      cancellable: false,
      task: (report, _) => ArchiveOps.extract(
        archivePath,
        password: password,
        onProgress: report,
      ),
    );
    if (context.mounted) {
      _snack(context, '${target.split('/').last} klasörüne çıkarıldı.');
    }
    return true;
  } on ArchiveError catch (e) {
    if (!context.mounted) return false;
    if (e.failure == ArchiveFailure.passwordRequired ||
        e.failure == ArchiveFailure.wrongPassword) {
      final pw = await askArchivePassword(context,
          retry: e.failure == ArchiveFailure.wrongPassword);
      if (pw == null || !context.mounted) return false;
      return extractArchive(context, archivePath, password: pw);
    }
    _snack(context, e.userMessage);
    return false;
  } catch (e) {
    if (context.mounted) _snack(context, 'Çıkarılamadı: $e');
    return false;
  }
}

/// Özellikler penceresi. Klasörlerde boyut istek üzerine hesaplanır (büyük
/// ağaçta saniyeler sürebilir — pencere açılışını bekletmeyiz).
Future<void> showProperties(BuildContext context, FsEntry entry) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _PropertiesDialog(entry: entry),
  );
}

class _PropertiesDialog extends StatefulWidget {
  final FsEntry entry;
  const _PropertiesDialog({required this.entry});

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  int? _folderSize;
  bool _calculating = false;

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    final size = await FsScan.folderSize(widget.entry.path);
    if (!mounted) return;
    setState(() {
      _folderSize = size;
      _calculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return AlertDialog(
      title: const Text('Özellikler'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Ad', e.name),
            _row('Tür', e.isDir ? 'Klasör' : e.category.label),
            if (!e.isDir) _row('Boyut', FsPaths.humanSize(e.sizeBytes)),
            if (e.isDir)
              _row(
                'Boyut',
                _folderSize != null
                    ? FsPaths.humanSize(_folderSize!)
                    : (_calculating ? 'Hesaplanıyor…' : 'Hesaplanmadı'),
              ),
            _row('Değiştirilme', FsPaths.humanDate(e.modifiedMs)),
            _row('Konum', e.path),
          ],
        ),
      ),
      actions: [
        if (e.isDir && _folderSize == null)
          TextButton(
            onPressed: _calculating ? null : _calculate,
            child: const Text('Boyutu hesapla'),
          ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: e.path));
            Navigator.pop(context);
          },
          child: const Text('Yolu kopyala'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            SelectableText(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

String _parentOf(String path) {
  final i = path.lastIndexOf('/');
  return i <= 0 ? '/' : path.substring(0, i);
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
