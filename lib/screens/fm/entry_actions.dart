import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
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
import 'ai_actions.dart';
import 'archive_screen.dart';
import 'folder_picker_screen.dart';
import 'important_screen.dart';

/// Girdi (dosya/klasör) üzerinde yapılabilecek işlemler. Gözatıcı, kategori
/// ekranları ve arama sonuçları AYNI davranışı paylaşsın diye tek dosyada.
enum _EntryAction {
  open,
  openWith,
  share,
  moveTo,
  copyTo,
  copy,
  cut,
  rename,
  delete,
  zip,
  extract,
  openArchive,
  bookmark,
  important,
  aiSummary,
  imageInsight,
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
            // Tek adımlı akış EN ÜSTTE (kullanıcı isteği 2026-07-29:
            // "taşıma/kopyalama şu an çok zor"): hedefi burada seç, iş bitsin.
            // Pano (kopyala/kes + git + yapıştır) altta, ileri kullanım için.
            _tile(ctx, Icons.drive_file_move_outline, 'Taşı…  (klasör seç)',
                _EntryAction.moveTo),
            _tile(ctx, Icons.folder_copy_outlined, 'Kopyala…  (klasör seç)',
                _EntryAction.copyTo),
            _tile(ctx, Icons.copy_outlined, 'Panoya kopyala',
                _EntryAction.copy),
            _tile(ctx, Icons.content_cut, 'Panoya kes', _EntryAction.cut),
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
            _tile(ctx, Icons.star_outline, 'Önemli dosyalara kopyala',
                _EntryAction.important),
            // AI/tanıma: belgede özet, görselde metin tanıma + sınıflandırma.
            if (!entry.isDir &&
                entry.category != FmCategory.image &&
                entry.category != FmCategory.video &&
                entry.category != FmCategory.audio)
              _tile(ctx, Icons.auto_awesome, 'AI ile özetle',
                  _EntryAction.aiSummary),
            if (entry.category == FmCategory.image)
              _tile(ctx, Icons.document_scanner_outlined,
                  'Bu görselde ne var? (metin tanı)', _EntryAction.imageInsight),
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

    case _EntryAction.moveTo:
      return moveOrCopyEntries(context, [entry.path], move: true);

    case _EntryAction.copyTo:
      return moveOrCopyEntries(context, [entry.path], move: false);

    case _EntryAction.copy:
      appState.setClipboard([entry.path], cut: false);
      _snack(context, '“${entry.name}” panoya kopyalandı. Hedef klasörde '
          'yapıştırın.');
      return false;

    case _EntryAction.cut:
      appState.setClipboard([entry.path], cut: true);
      _snack(context, '“${entry.name}” panoya kesildi. Hedef klasörde '
          'yapıştırın.');
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

    case _EntryAction.important:
      return copyToImportant(context, [entry.path]);

    case _EntryAction.aiSummary:
      await showAiSummary(context, entry);
      return false;

    case _EntryAction.imageInsight:
      await showImageInsight(context, entry);
      // Sınıflandırma sonucu dosya taşınmış olabilir → liste tazelensin.
      return true;

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
/// [confirm] false ise onay penceresi atlanır — çağıran ZATEN toplu bir onay
/// almışsa (yer açma asistanı) ikinci kez sormak akışı boğar.
Future<bool> deleteEntries(
  BuildContext context,
  List<FsEntry> entries, {
  bool confirm = true,
}) async {
  if (entries.isEmpty) return false;
  final appState = context.read<AppState>();
  final useTrash = appState.fmUseTrash;
  final label = entries.length == 1
      ? '“${entries.first.name}”'
      : '${entries.length} öğe';

  if (confirm && (appState.fmConfirmDelete || !useTrash)) {
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

/// **Taşı/Kopyala akışı:** hedef klasör seçtirir, işi ilerleme penceresiyle
/// yapar, sonucu bildirir. Taşımada **Geri al** sunulur.
///
/// Kullanıcı isteği (2026-07-29): "taşıma kopyalama şu an çok zor · basılı
/// tuttuğumda çıkan menüde rahatlıkla yapabilmeliyim". Eski yol pano üzerinden
/// üç adımdı (kopyala → sekme değiştir → klasörü bul → yapıştır).
///
/// Dosya sistemi değiştiyse `true` döner (çağıran listesini tazeler).
Future<bool> moveOrCopyEntries(
  BuildContext context,
  List<String> paths, {
  required bool move,
}) async {
  if (paths.isEmpty) return false;
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => FolderPickerScreen(
      sources: paths,
      actionLabel: move ? 'Buraya taşı' : 'Buraya kopyala',
    ),
  ));
  if (dest == null || !context.mounted) return false;

  final result = await showFmProgress<FmOpResult>(
    context,
    title: move ? 'Taşınıyor' : 'Kopyalanıyor',
    task: (report, isCancelled) => move
        ? FileOps.moveAll(paths, dest, onProgress: report,
            isCancelled: isCancelled)
        : FileOps.copyAll(paths, dest, onProgress: report,
            isCancelled: isCancelled),
  );
  await appState.rememberDestination(dest);

  final where = p.basename(dest);
  final count = result.succeeded;
  messenger.showSnackBar(SnackBar(
    content: Text(result.hasError
        ? 'Bazı öğeler aktarılamadı: ${result.errors.first}'
        : '$count öğe “$where” klasörüne ${move ? "taşındı" : "kopyalandı"}.'),
    // Geri al YALNIZ taşımada: kopyalamayı geri almak "sil" demektir, yanlış
    // dokunuşta veri kaybı riski taşır.
    action: (move && result.transfers.isNotEmpty)
        ? SnackBarAction(
            label: 'Geri al',
            onPressed: () async {
              final back = await FileOps.undoMove(result.transfers);
              messenger.showSnackBar(SnackBar(
                content: Text(back.hasError
                    ? 'Geri alınamadı: ${back.errors.first}'
                    : 'Geri alındı.'),
              ));
            },
          )
        : null,
  ));
  return true;
}

/// Seçilenleri **Önemli Dosyalar** klasörüne kopyalar (klasör yoksa kurulur).
///
/// Kopya bilinçli — taşımak dosyayı kullanıcının bildiği yerden (DCIM, Belgeler)
/// koparırdı; "önemli" işareti asıl dosyanın yerini değiştirmemeli.
Future<bool> copyToImportant(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final dest = ImportantScreen.pathIn(FmEnv.primaryRoot);
  try {
    final dir = Directory(dest);
    if (!dir.existsSync()) await dir.create(recursive: true);
  } catch (e) {
    if (context.mounted) _snack(context, 'Klasör oluşturulamadı: $e');
    return false;
  }
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: 'Önemli dosyalara kopyalanıyor',
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? 'Kopyalanamadı: ${result.errors.first}'
        : '${paths.length} öğe “${ImportantScreen.folderName}” klasörüne '
            'kopyalandı.',
  );
  return true;
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
