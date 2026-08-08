import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../widgets/fm/archive_password_dialog.dart';
import '../../widgets/fm/compress_sheet.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/tag_picker_sheet.dart';
import 'ai_actions.dart';
import 'archive_screen.dart';
import 'drive_screen.dart';
import 'folder_picker_screen.dart';
import 'important_screen.dart';
import 'resize_actions.dart';

/// Girdi (dosya/klasör) üzerinde yapılabilecek işlemler. Gözatıcı, kategori
/// ekranları ve arama sonuçları AYNI davranışı paylaşsın diye tek dosyada.
enum _EntryAction {
  open,
  openWith,
  share,
  driveUpload,
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
  resize,
  tag,
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
                  ? '${ctx.t('fm.folder')} · ${FsPaths.humanDate(entry.modifiedMs)}'
                  : '${FsPaths.humanSize(entry.sizeBytes)} · '
                      '${FsPaths.humanDate(entry.modifiedMs)}'),
            ),
            const Divider(),
            _tile(ctx, Icons.open_in_new, context.t('common.open'), _EntryAction.open),
            if (!entry.isDir)
              _tile(ctx, Icons.apps, context.t('fm.open_with_other'),
                  _EntryAction.openWith),
            if (!entry.isDir)
              _tile(ctx, Icons.share_outlined, context.t('common.share'), _EntryAction.share),
            if (!entry.isDir)
              _tile(ctx, Icons.cloud_upload_outlined, context.t('drive.upload_action'),
                  _EntryAction.driveUpload),
            // Tek adımlı akış EN ÜSTTE (kullanıcı isteği 2026-07-29:
            // "taşıma/kopyalama şu an çok zor"): hedefi burada seç, iş bitsin.
            // Pano (kopyala/kes + git + yapıştır) altta, ileri kullanım için.
            _tile(ctx, Icons.drive_file_move_outline, context.t('fm.move_to'),
                _EntryAction.moveTo),
            _tile(ctx, Icons.folder_copy_outlined, context.t('fm.copy_to'),
                _EntryAction.copyTo),
            _tile(ctx, Icons.copy_outlined, context.t('fm.clip_copy'),
                _EntryAction.copy),
            _tile(ctx, Icons.content_cut, context.t('fm.clip_cut'), _EntryAction.cut),
            _tile(ctx, Icons.drive_file_rename_outline, context.t('fm.rename'),
                _EntryAction.rename),
            if (isArchive)
              _tile(ctx, Icons.folder_zip_outlined, context.t('fm.show_archive'),
                  _EntryAction.openArchive),
            if (isArchive)
              _tile(ctx, Icons.unarchive_outlined, context.t('fm.extract_here'),
                  _EntryAction.extract),
            _tile(ctx, Icons.archive_outlined, context.t('fm.compress_pw'),
                _EntryAction.zip),
            if (entry.isDir)
              _tile(
                ctx,
                appState.isBookmarked(entry.path)
                    ? Icons.star
                    : Icons.star_border,
                appState.isBookmarked(entry.path)
                    ? context.t('fm.unfavorite')
                    : 'Favorilere ekle',
                _EntryAction.bookmark,
              ),
            _tile(ctx, Icons.star_outline, context.t('fm.copy_to_important'),
                _EntryAction.important),
            // AI/tanıma: belgede özet, görselde metin tanıma + sınıflandırma.
            if (!entry.isDir &&
                entry.category != FmCategory.image &&
                entry.category != FmCategory.video &&
                entry.category != FmCategory.audio)
              _tile(ctx, Icons.auto_awesome, context.t('fm.ai_summary'),
                  _EntryAction.aiSummary),
            if (entry.category == FmCategory.image)
              _tile(ctx, Icons.document_scanner_outlined,
                  context.t('fm.image_insight'), _EntryAction.imageInsight),
            // Boyut düşürme ve etiketleme eskiden YALNIZ çoklu seçim çubuğunda
            // vardı: kullanıcı tek bir fotoğrafa uzun basınca bulamıyordu
            // (2026-07-29 sadakat denetimi). Aynı işler burada da duruyor.
            if (!entry.isDir &&
                (entry.category == FmCategory.image ||
                    entry.category == FmCategory.video))
              _tile(ctx, Icons.photo_size_select_large,
                  context.t('fm.resize'), _EntryAction.resize),
            if (!entry.isDir)
              _tile(ctx, Icons.sell_outlined, context.t('fm.tag'),
                  _EntryAction.tag),
            if (allowReveal)
              _tile(ctx, Icons.my_location, context.t('fm.reveal'), _EntryAction.reveal),
            _tile(ctx, Icons.info_outline, context.t('fm.properties'),
                _EntryAction.properties),
            _tile(
                ctx,
                Icons.delete_outline,
                // Etiket ayarı okur: çöp kutusu kapalıyken "çöp kutusuna"
                // yazmak tutulmayan bir sözdür (bkz. [deleteActionText]).
                'Sil (${context.read<AppState>().fmUseTrash ? 'çöp kutusuna' : 'KALICI'})',
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

    case _EntryAction.driveUpload:
      await uploadToDrive(context, entry.path);
      return false;

    case _EntryAction.moveTo:
      return moveOrCopyEntries(context, [entry.path], move: true);

    case _EntryAction.copyTo:
      return moveOrCopyEntries(context, [entry.path], move: false);

    case _EntryAction.copy:
      appState.setClipboard([entry.path], cut: false);
      _snack(context,
          context.t('fm.entry_clip_copied', {'name': entry.name}));
      return false;

    case _EntryAction.cut:
      appState.setClipboard([entry.path], cut: true);
      _snack(context,
          context.t('fm.entry_clip_cut', {'name': entry.name}));
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

    case _EntryAction.resize:
      // İş kuyruğa gider; liste tazelemeyi FsEvents üstlenir.
      await startResizeJob(context, [entry]);
      return false;

    case _EntryAction.tag:
      return showTagPicker(context, [entry.path]);

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
      title: Text(context.t('fm.rename')),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: ctx.t('fm.new_name')),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(ctx.t('common.save')),
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
    if (context.mounted) {
      _snack(context, context.t('fm.rename_failed', {'error': e}));
    }
    return false;
  }
}

/// Seçilenleri siler. Ayarlara göre çöp kutusuna taşır ya da kalıcı siler;
/// "silmeden önce sor" kapalıysa onay penceresi atlanır (ama KALICI silmede
/// veri geri gelmeyeceği için onay her zaman sorulur).
/// [confirm] false ise onay penceresi atlanır — çağıran ZATEN toplu bir onay
/// almışsa (yer açma asistanı) ikinci kez sormak akışı boğar.
///
/// **[confirm] `false` yalnız ÇÖP KUTUSU yolunu atlar.** Kalıcı silme onayı
/// hiçbir koşulda atlanamaz: 2026-07-29 sadakat denetiminin 2. turunda tam
/// buradan bir veri kaybı yolu çıktı — Fotoğraflar ekranındaki "Temizle"
/// kendi penceresinde *"çöp kutusuna taşınacak"* yazıp `confirm: false` ile
/// buraya geliyordu; Ayarlar > "Çöp kutusunu kullan" kapalıysa `!useTrash`
/// dalı `confirm` yüzünden hiç sorulmuyor ve dosyalar **kalıcı** siliniyordu.
/// Yani kullanıcının okuduğu söz ile yapılan iş birbirinin tersiydi.
/// Silme düğmelerinin **dürüst** metni: "12 dosyayı çöpe taşı" / "…kalıcı sil".
///
/// **Saf fonksiyon:** `BuildContext` DEĞİL, [AppStrings] alır → birim testli
/// kalır (çeviri tablosu düz bir değer nesnesi). Ayarlar > "Çöp kutusunu
/// kullan" kapalıyken "çöpe taşı" yazan bir düğme, kullanıcıya geri
/// alabileceğini söyleyip dosyayı kalıcı silmek demekti.
String deleteActionText({
  required bool useTrash,
  required String what,
  AppStrings strings = const AppStrings(AppLanguage.tr),
}) =>
    useTrash
        ? strings.t('fm.delete_trash_action', {'what': what})
        : strings.t('fm.delete_permanent_action', {'what': what});

/// Silmeden önce onay penceresi gösterilmeli mi?
///
/// Saf fonksiyon → birim testli, çünkü burada **veri kaybı** yatıyor:
/// - [useTrash] `false` (Ayarlar > "Çöp kutusunu kullan" kapalı) ise onay
///   **HER ZAMAN** sorulur. Kalıcı silme geri alınamaz; "çağıran zaten sordu"
///   gerekçesi burada geçerli değil, çünkü çağıran genellikle *"çöp kutusuna
///   taşınacak"* diye söz vermiş oluyor (bkz. [deleteEntries] notu).
/// - Çöp kutusu açıkken: kullanıcı "silmeden önce sor"u kapatmışsa
///   ([confirmSetting] `false`) ya da çağıran kendi onayını almışsa
///   ([askAllowed] `false`) sorulmaz — dosya çöpten geri alınabilir.
bool needsDeleteConfirm({
  required bool useTrash,
  required bool confirmSetting,
  required bool askAllowed,
}) =>
    !useTrash || (askAllowed && confirmSetting);

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
      : context.t('fm.items_count', {'n': entries.length});

  if (needsDeleteConfirm(
    useTrash: useTrash,
    confirmSetting: appState.fmConfirmDelete,
    askAllowed: confirm,
  )) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(useTrash
            ? context.t('fm.delete_trash_title')
            : context.t('fm.delete_permanent_title')),
        content: Text(useTrash
            ? ctx.t('fm.delete_trash_body', {'label': label})
            : ctx.t('fm.delete_permanent_body', {'label': label})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                ctx.t(useTrash ? 'fm.move' : 'common.delete')),
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
      title: context.t('fm.deleting'),
      cancellable: false,
      task: (report, _) => FileOps.deleteAll(paths, onProgress: report),
    );
    if (context.mounted && result.hasError) {
      _snack(
          context,
          '${result.succeeded} öğe silindi, ${result.errors.length} öğe '
          'silinemedi: ${result.errors.first}');
    }
    // Hiçbiri silinemediyse `false`: çağıranlar bu dönüşle "oldu" varsayıp
    // seçimi temizliyor ve listeyi tazeliyordu (2026-07-29 denetimi, 4. tur).
    return result.succeeded > 0;
  }

  await FmEnv.ensureInit();
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.trashing'),
    cancellable: false,
    task: (report, _) =>
        FmEnv.trash.moveToTrash(paths, onProgress: report),
  );
  if (context.mounted && result.hasError) {
    _snack(
        context,
        context.t('fm.trashed_partial', {
          'ok': result.succeeded,
          'fail': result.errors.length,
          'error': result.errors.first,
        }));
  }
  return result.succeeded > 0;
}

/// Kalıcı silme (çöp kutusunu atlar) — çöp ekranında kullanılır.
Future<bool> deleteForever(BuildContext context, List<String> paths) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.t('fm.delete_permanent_title')),
      content: Text(ctx.t('fm.irreversible')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('common.delete')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await showFmProgress(
    context,
    title: context.t('common.deleting'),
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
  // Sonuç metinleri await'lerden ÖNCE alınır: bu akış birden çok asenkron
  // adım içeriyor ve sonunda `context` artık kullanılamaz.
  final strings = AppStrings.of(context);
  final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => FolderPickerScreen(
      sources: paths,
      actionLabel:
          context.t(move ? 'fm.move_here' : 'fm.copy_here'),
    ),
  ));
  if (dest == null || !context.mounted) return false;

  final result = await showFmProgress<FmOpResult>(
    context,
    title: move ? context.t('fm.moving') : context.t('fm.copying'),
    task: (report, isCancelled) => move
        ? FileOps.moveAll(paths, dest, onProgress: report,
            isCancelled: isCancelled)
        : FileOps.copyAll(paths, dest, onProgress: report,
            isCancelled: isCancelled),
  );
  await appState.rememberDestination(dest);

  final where = p.basename(dest);
  final count = result.succeeded;
  final verb = strings.t(move ? 'fm.verb_moved' : 'fm.verb_copied');
  messenger.showSnackBar(SnackBar(
    // Mesaj GERÇEĞİ söyler: kaç tanesi oldu, kaç tanesi olmadı, iptal edildi mi.
    //
    // Eskiden hata varken yalnız ilk hata metni yazılıyordu ("Bazı öğeler
    // aktarılamadı: …") — başarılı sayısı gizleniyor, kaç dosyanın kaldığı
    // hiç söylenmiyordu. İptalde ise sonuç "iptal" bilgisini taşımadığı için
    // kullanıcı "1 öğe taşındı" okuyup işlemin durduğunu sanıyordu. Kopyalama
    // çekirdekte kesilemiyor (`File.copy` bölünemez); yapamadığımız şeyi
    // yapıyormuş gibi göstermek yerine olanı yazıyoruz (2026-07-29 sadakat
    // denetimi, 4. tur).
    content: Text(
      result.hasError
          ? strings.t('fm.transfer_errors', {
              'n': count,
              'verb': verb,
              'fail': result.errors.length,
              'error': result.errors.first,
            })
          : result.cancelled
              ? strings.t('fm.transfer_stopped',
                  {'n': count, 'where': where, 'verb': verb})
              : strings.t('fm.transfer_done',
                  {'n': count, 'where': where, 'verb': verb}),
    ),
    // Geri al YALNIZ taşımada: kopyalamayı geri almak "sil" demektir, yanlış
    // dokunuşta veri kaybı riski taşır.
    action: (move && result.transfers.isNotEmpty)
        ? SnackBarAction(
            label: strings.t('fm.undo_action'),
            onPressed: () async {
              final back = await FileOps.undoMove(result.transfers);
              messenger.showSnackBar(SnackBar(
                content: Text(back.hasError
                    ? strings.t('fm.undo_failed', {'error': back.errors.first})
                    : strings.t('fm.undo')),
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
    if (context.mounted) {
      _snack(context, context.t('fm.folder_create_failed', {'error': e}));
    }
    return false;
  }
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_important'),
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? context.t('fm.copy_failed', {'error': result.errors.first})
        : context.t('fm.important_copied', {
            'n': paths.length,
            'folder': ImportantScreen.folderName,
          }),
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
          ? context.t('fm.zipping')
          : context.t('fm.encrypting'),
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
      _snack(context,
          context.t('fm.created_archive', {'name': zipPath.split('/').last}));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      _snack(context, context.t('fm.zip_failed', {'error': e}));
    }
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
      title: context.t('fm.extracting'),
      cancellable: false,
      task: (report, _) => ArchiveOps.extract(
        archivePath,
        password: password,
        onProgress: report,
      ),
    );
    if (context.mounted) {
      _snack(context,
          context.t('fm.extracted_to', {'name': target.split('/').last}));
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
    if (context.mounted) {
      _snack(context, context.t('fm.extract_failed', {'error': e}));
    }
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

  /// Son açılma zamanı (bizim kaydımız). Kullanıcı isteği 2026-07-29:
  /// *"son açılma tarihi TÜM DOSYALAR içinde yapılabilmeli"* — ayrı ekranın
  /// yanında dosyanın kendi özelliklerinde de görünmesi gerekiyor, çünkü
  /// kullanıcı tek bir dosyayı merak ettiğinde listeye değil buraya bakar.
  /// Dosya sisteminin "erişilme" damgası (`accessedMs`) bunun yerine
  /// KULLANILAMAZ: Android'de tarama/yedekleme gibi işler de onu güncelliyor,
  /// yani "kullanıcı ne zaman açtı" sorusunu yanıtlamıyor.
  int? _openedAtMs;

  @override
  void initState() {
    super.initState();
    _loadOpenedAt();
  }

  Future<void> _loadOpenedAt() async {
    await OpenHistory.ensureLoaded();
    if (!mounted) return;
    setState(() => _openedAtMs = OpenHistory.forPath(widget.entry.path));
  }

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
      title: Text(context.t('fm.properties')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Ad', e.name),
            _row(context.t('fm.type'), e.isDir ? context.t('fm.folder') : e.category.label),
            if (!e.isDir) _row('Boyut', FsPaths.humanSize(e.sizeBytes)),
            if (e.isDir)
              _row(
                'Boyut',
                _folderSize != null
                    ? FsPaths.humanSize(_folderSize!)
                    : (_calculating ? context.t('fm.computing') : context.t('fm.not_computed')),
              ),
            _row(context.t('fm.modified'), FsPaths.humanDate(e.modifiedMs)),
            // Yalnız gerçekten bir kaydımız varsa yazılır: "—" göstermek
            // "hiç açılmadı" ile "bilmiyorum"u karıştırırdı.
            if (_openedAtMs != null)
              _row(context.t('fm.last_opened'), FsPaths.humanDate(_openedAtMs!)),
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
          child: Text(context.t('common.close')),
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
