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
import '../../core/snack.dart';

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

/// Uzun basınca (ya da ⋮ ile) açılan işlem sayfası. Dosya sistemi değiştiyse
/// `true` döner (çağıran listeyi yeniler).
///
/// **İKİ SÜTUNLU, BÖLÜMLÜ** (kullanıcı isteği 2026-08-29: *"3 noktaya basınca
/// çıkan ayarlar çok yılın olmuş, yeniden sıralanmalı ve düzenlenmeli,
/// gerekirse 2 sütunlu olabilir"*).
///
/// **Eski hâl neden kötüydü:** 20'ye yakın işlem tek sütun `ListTile` olarak
/// alt alta diziliydi. Ekrana ancak 11'i sığıyordu — "Sil", "Özellikler",
/// "Etiketle" görmek için kaydırmak gerekiyordu ve hiçbir gruplama yoktu:
/// "Drive'a yükle" ile "Panoya kes" aynı ağırlıkta, arka arkaya duruyordu.
/// Uzun etiketler ("Sıkıştır (ZIP / 7z, parolalı)") satırı dolduruyordu.
///
/// **Yeni hâl:** işlemler dört bölüme ayrıldı (aç/paylaş · taşı/kopyala ·
/// dosya işlemleri · AI) ve iki sütuna dizildi; parantezli açıklamalar
/// etiketin ALTINDA soluk bir ipucu satırı oldu. Aynı yükseklikte iki kat çok
/// işlem görünüyor, kaydırma çoğu dosyada hiç gerekmiyor.
///
/// **Sil ayrı ve en altta**, tam genişlikte ve hata renginde: ızgaranın içinde
/// olsaydı "Kopyala"nın yanında, yanlış dokunuşa bir parmak mesafede dururdu.
Future<bool> showEntryActions(
  BuildContext context,
  FsEntry entry, {
  /// "Konumunu aç" gösterilsin mi? (Kategori/arama ekranlarında anlamlı.)
  bool allowReveal = false,
  void Function(String path)? onReveal,
}) async {
  final appState = context.read<AppState>();
  final isArchive = ArchiveOps.canExtract(entry.path);
  final isMedia =
      entry.category == FmCategory.image || entry.category == FmCategory.video;

  final action = await showModalBottomSheet<_EntryAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Uzun listede sayfa ekranı tamamen kaplamasın: üstte kalan şerit
    // "arkada bir şey var, buradan kapatabilirim" der.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHeader(ctx, entry),
            _section(ctx, ctx.t('ea.sec_open'), [
              _act(ctx, Icons.open_in_new, ctx.t('common.open'),
                  _EntryAction.open),
              if (!entry.isDir)
                _act(ctx, Icons.apps, ctx.t('fm.open_with_other'),
                    _EntryAction.openWith),
              if (!entry.isDir)
                _act(ctx, Icons.share_outlined, ctx.t('common.share'),
                    _EntryAction.share),
              if (!entry.isDir)
                _act(ctx, Icons.cloud_upload_outlined,
                    ctx.t('drive.upload_action'), _EntryAction.driveUpload),
              if (allowReveal)
                _act(ctx, Icons.my_location, ctx.t('fm.reveal'),
                    _EntryAction.reveal),
            ]),
            // Tek adımlı akış ÖNCE (kullanıcı isteği 2026-07-29:
            // "taşıma/kopyalama şu an çok zor"): hedefi burada seç, iş bitsin.
            // Pano (kopyala/kes + git + yapıştır) arkasında, ileri kullanım
            // için — aynı bölümde ama ikinci satırda.
            _section(ctx, ctx.t('ea.sec_move'), [
              _act(ctx, Icons.drive_file_move_outline, ctx.t('fm.move'),
                  _EntryAction.moveTo,
                  hint: ctx.t('ea.pick_folder')),
              _act(ctx, Icons.folder_copy_outlined, ctx.t('fm.copy'),
                  _EntryAction.copyTo,
                  hint: ctx.t('ea.pick_folder')),
              _act(ctx, Icons.copy_outlined, ctx.t('fm.clip_copy'),
                  _EntryAction.copy,
                  hint: ctx.t('ea.clip_hint')),
              _act(ctx, Icons.content_cut, ctx.t('fm.clip_cut'),
                  _EntryAction.cut,
                  hint: ctx.t('ea.clip_hint')),
              _act(ctx, Icons.star_outline, ctx.t('fm.copy_to_important'),
                  _EntryAction.important),
            ]),
            _section(ctx, ctx.t('ea.sec_file'), [
              _act(ctx, Icons.drive_file_rename_outline, ctx.t('fm.rename'),
                  _EntryAction.rename),
              if (isArchive)
                _act(ctx, Icons.folder_zip_outlined, ctx.t('fm.show_archive'),
                    _EntryAction.openArchive),
              if (isArchive)
                _act(ctx, Icons.unarchive_outlined, ctx.t('fm.extract_here'),
                    _EntryAction.extract),
              _act(ctx, Icons.archive_outlined, ctx.t('ea.compress'),
                  _EntryAction.zip,
                  hint: ctx.t('ea.compress_hint')),
              if (!entry.isDir)
                _act(ctx, Icons.sell_outlined, ctx.t('ea.tag'),
                    _EntryAction.tag,
                    hint: ctx.t('ea.tag_hint')),
              if (entry.isDir)
                _act(
                  ctx,
                  appState.isBookmarked(entry.path)
                      ? Icons.star
                      : Icons.star_border,
                  appState.isBookmarked(entry.path)
                      ? ctx.t('fm.unfavorite')
                      : ctx.t('fm.favorite'),
                  _EntryAction.bookmark,
                ),
              _act(ctx, Icons.info_outline, ctx.t('fm.properties'),
                  _EntryAction.properties),
            ]),
            // AI/tanıma ve dönüştürme: belgede özet, görselde metin tanıma,
            // medyada boyut düşürme. Boyut düşürme ve etiketleme eskiden
            // YALNIZ çoklu seçim çubuğundaydı: kullanıcı tek bir fotoğrafa
            // uzun basınca bulamıyordu (2026-07-29 sadakat denetimi).
            _section(ctx, ctx.t('ea.sec_ai'), [
              if (!entry.isDir &&
                  entry.category != FmCategory.image &&
                  entry.category != FmCategory.video &&
                  entry.category != FmCategory.audio)
                _act(ctx, Icons.auto_awesome, ctx.t('fm.ai_summary'),
                    _EntryAction.aiSummary),
              if (entry.category == FmCategory.image)
                _act(ctx, Icons.document_scanner_outlined,
                    ctx.t('ea.image_insight'), _EntryAction.imageInsight,
                    hint: ctx.t('ea.image_insight_hint')),
              if (!entry.isDir && isMedia)
                _act(ctx, Icons.photo_size_select_large, ctx.t('ea.resize'),
                    _EntryAction.resize,
                    hint: ctx.t('ea.resize_hint')),
            ]),
            const SizedBox(height: Gap.md),
            _deleteButton(ctx, appState.fmUseTrash),
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

/// Sayfanın başlığı: dosyanın kendisi (simge, ad, boyut/tarih).
Widget _sheetHeader(BuildContext ctx, FsEntry entry) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          FmEntryIcon(entry: entry, size: 40),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleMedium),
                Text(
                  entry.isDir
                      ? '${ctx.t('fm.folder')} · '
                          '${FsPaths.humanDate(entry.modifiedMs)}'
                      : '${FsPaths.humanSize(entry.sizeBytes)} · '
                          '${FsPaths.humanDate(entry.modifiedMs)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );

/// Bir bölüm: küçük başlık + iki sütunlu ızgara. Hiç işlemi kalmayan bölüm
/// (koşullar elediyse) HİÇ çizilmez — başlığın altı boş kalmaz.
Widget _section(BuildContext ctx, String title, List<Widget> actions) {
  final items = actions;
  if (items.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, Gap.md, 4, Gap.xs),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
        ),
      ),
      // Izgara ELLE satırlanıyor (GridView değil): `GridView` sabit bir
      // en-boy oranı ister, oysa hücre yüksekliği metne bağlı — büyük yazı
      // ölçeğinde sabit oran taşma demek. `IntrinsicHeight` iki hücreyi
      // satırın en uzununa eşitliyor, tek hücreli satır tek sütun kalıyor.
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: items[i]),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: i + 1 < items.length
                      ? items[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Izgaranın bir hücresi: simge + etiket (+ soluk ipucu satırı).
Widget _act(
  BuildContext ctx,
  IconData icon,
  String label,
  _EntryAction action, {
  String? hint,
}) {
  final scheme = Theme.of(ctx).colorScheme;
  return Material(
    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(Radii.control),
    child: InkWell(
      onTap: () => Navigator.pop(ctx, action),
      borderRadius: BorderRadius.circular(Radii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm, vertical: Gap.sm + 2),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  if (hint != null)
                    Text(hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// **Sil** — tam genişlikte, hata renginde, ızgaranın dışında.
///
/// Etiket ayarı okur: çöp kutusu kapalıyken "çöp kutusuna" yazmak tutulmayan
/// bir sözdür (bkz. [deleteActionText]).
Widget _deleteButton(BuildContext ctx, bool useTrash) {
  final scheme = Theme.of(ctx).colorScheme;
  return Material(
    color: scheme.errorContainer.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(Radii.control),
    child: InkWell(
      onTap: () => Navigator.pop(ctx, _EntryAction.delete),
      borderRadius: BorderRadius.circular(Radii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: scheme.error),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(
                useTrash
                    ? ctx.t('ea.delete_trash')
                    : ctx.t('ea.delete_permanent'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    ),
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
  showSnackBarReplacing(messenger, SnackBar(
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
            child: Text(context.t('fm.calc_size')),
          ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: e.path));
            Navigator.pop(context);
          },
          child: Text(context.t('fm.copy_path')),
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
  showSnack(context, message);
}
