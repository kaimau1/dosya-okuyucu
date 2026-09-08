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
import '../../services/fm/content_search.dart';
import '../../services/fm/exif_reader.dart';
import '../../services/fm/file_digest.dart';
import '../../services/fm/file_split.dart';
import '../../services/fm/image_rotate.dart';
import '../../services/text_decode.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/remote/ftp_tree.dart';
import '../../services/fm/remote/share_scope.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/volume_watcher.dart';
import '../../widgets/fm/archive_password_dialog.dart';
import '../../widgets/fm/compress_sheet.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/tag_picker_sheet.dart';
import 'ai_actions.dart';
import 'archive_screen.dart';
import 'drive_screen.dart';
import 'folder_picker_screen.dart';
import 'remote/peer_share_screen.dart';
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
  sharedFolder,
  externalDrive,
  aiSummary,
  imageInsight,
  resize,
  tag,
  reveal,
  properties,
  rotate,
  split,
  join,
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
  final canRotate = !entry.isDir && ImageRotate.canRotate(entry.path);
  // Bölmenin anlamlı olduğu alt sınır: 1 MB'ın altındaki bir dosyayı bölmek
  // kullanıcıya iş çıkarmaktan başka bir şey yapmaz.
  final canSplit = !entry.isDir && entry.sizeBytes > 1024 * 1024;
  final isPart = !entry.isDir && FileSplit.baseNameOf(entry.path) != null;
  final isMedia =
      entry.category == FmCategory.image || entry.category == FmCategory.video;

  // Takılı harici bellekler (USB / SD). Menü kurulmadan ÖNCE okunuyor:
  // `isWritable` diske dokunuyor ve build içinde çağrılmamalı.
  final externals = VolumeWatcher.copyTargets();
  final hasExternal = externals.isNotEmpty;
  final externalHint = externals.length == 1
      ? externals.single.displayLabel(context.t)
      : context.t('fm.external_pick_hint');

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
              // "Paylaşılan"a kopyala (kullanıcı isteği 2026-08-31): ağ
              // paylaşımının dar kapsamlı kutusu. Taşımak değil KOPYALAMAK —
              // dosya kullanıcının bildiği yerde kalmalı.
              _act(ctx, Icons.folder_shared_outlined,
                  ctx.t('fm.copy_to_shared'), _EntryAction.sharedFolder,
                  hint: ctx.t('ea.shared_hint')),
              // **Harici belleğe kopyala** (kullanıcı isteği 2026-09-01:
              // *"bir harici bellek takıldığında telefondaki bir belgeye
              // tıklayıp 3 nokta ayarlarında harici belleğe kopyala şeklinde
              // basit bir kısayol da olmalı"*). Yalnız takılı ve YAZILABİLİR
              // bir birim varken görünür: yokken çıkması, dokunup "hedef yok"
              // yemek demekti.
              if (hasExternal)
                _act(ctx, Icons.usb, ctx.t('fm.copy_to_external'),
                    _EntryAction.externalDrive,
                    hint: externalHint),
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
              // **Döndür** (2026-09-06 denetim turu): yan çekilmiş bir
              // fotoğrafı düzeltmenin uygulama içinde hiçbir yolu yoktu.
              if (canRotate)
                _act(ctx, Icons.rotate_90_degrees_cw_outlined,
                    ctx.t('ea.rotate'), _EntryAction.rotate,
                    hint: ctx.t('ea.rotate_hint')),
              // **Böl / birleştir**: FAT32 biçimli USB bellek ve SD kartlar
              // 4 GB'tan büyük tek dosya kabul etmiyor; kullanıcının
              // yapabileceği hiçbir şey yoktu.
              if (canSplit)
                _act(ctx, Icons.call_split, ctx.t('ea.split'),
                    _EntryAction.split, hint: ctx.t('ea.split_hint')),
              if (isPart)
                _act(ctx, Icons.merge, ctx.t('ea.join'), _EntryAction.join,
                    hint: ctx.t('ea.join_hint')),
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
      await shareEntriesFrom(context, [entry.path]);
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

    case _EntryAction.externalDrive:
      return copyToExternal(context, [entry.path]);

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

    case _EntryAction.sharedFolder:
      return copyToShared(context, [entry.path]);

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

    case _EntryAction.rotate:
      return rotateImageEntry(context, entry);

    case _EntryAction.split:
      return splitEntry(context, entry);

    case _EntryAction.join:
      return joinEntry(context, entry);
  }
}

/// **İki dosyanın SHA-256 özetini karşılaştırır.**
///
/// Niye (2026-09-06 denetim turu): kullanıcının klasörlerinde aynı dosyanın
/// iki kopyası biriktiğinde ("rapor.pdf", "rapor (1).pdf") hangisini
/// silebileceğini anlamanın bir yolu yoktu. Boyut eşitliği yetmez — aynı
/// boyutta farklı iki belge olabilir. Özet eşleşiyorsa dosyalar birebir
/// aynıdır.
Future<void> compareTwoFiles(BuildContext context, List<String> paths) async {
  if (paths.length != 2) return;
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final digests = await showFmProgress<List<String>>(
    context,
    title: strings.t('fm.compare_running'),
    backgroundable: false,
    describe: (value) => value.total > 0
        ? '${FsPaths.humanSize(value.done)} / ${FsPaths.humanSize(value.total)}'
        : '',
    task: (report, isCancelled) async {
      final out = <String>[];
      for (final path in paths) {
        if (isCancelled()) return const <String>[];
        out.add(await FileDigest.sha256Of(
          path,
          isCancelled: isCancelled,
          onProgress: (done, total) =>
              report(FmProgress(done, total, p.basename(path))),
        ));
      }
      return out;
    },
  );
  if (digests.length != 2 || digests.any((d) => d.isEmpty)) return;
  showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(digests[0] == digests[1]
          ? strings.t('fm.compare_same')
          : strings.t('fm.compare_diff')),
    ),
  );
}

/// **Görseli 90° sağa döndürüp yeni dosya olarak kaydeder.**
///
/// Özgün dosyanın üzerine YAZILMAZ: bir döndürme yanlış yöne gittiğinde geri
/// dönüşü olmalı ve JPEG yeniden kodlandığı için üzerine yazmak kaliteyi
/// geri alınamaz biçimde düşürürdü.
Future<bool> rotateImageEntry(BuildContext context, FsEntry entry) async {
  final messenger = ScaffoldMessenger.of(context);
  final strings = AppStrings.of(context);
  showSnackOn(messenger, strings.t('rotate.working'));
  try {
    final out = await ImageRotate.rotate(entry.path, quarterTurns: 1);
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('rotate.done', {'name': p.basename(out)}))),
    );
    return true;
  } catch (e) {
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('rotate.failed', {'error': e}))),
    );
    return false;
  }
}

/// **Dosyayı parçalara böler.** Önce boyut sorulur.
Future<bool> splitEntry(BuildContext context, FsEntry entry) async {
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final size = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(ctx.t('split.pick_size'),
                style: Theme.of(ctx).textTheme.titleSmall),
          ),
          for (final preset in FileSplit.presets.entries)
            ListTile(
              leading: const Icon(Icons.call_split),
              title: Text(preset.key),
              // Dosyadan BÜYÜK bir parça boyutu tek parça üretirdi: seçeneği
              // sunmak yerine sönükleştiriyoruz.
              enabled: entry.sizeBytes > preset.value,
              onTap: () => Navigator.pop(ctx, preset.value),
            ),
        ],
      ),
    ),
  );
  if (size == null || !context.mounted) return false;
  if (entry.sizeBytes <= size) {
    showSnackOn(messenger, strings.t('split.too_small'));
    return false;
  }
  final parts = await showFmProgress<List<String>>(
    context,
    title: strings.t('split.working'),
    describe: (value) => value.total > 0
        ? '${FsPaths.humanSize(value.done)} / ${FsPaths.humanSize(value.total)}'
        : '',
    task: (report, isCancelled) => FileSplit.split(
      entry.path,
      partBytes: size,
      isCancelled: isCancelled,
      onProgress: (done, total) =>
          report(FmProgress(done, total, p.basename(entry.path))),
    ),
  );
  showSnackBarReplacing(
    messenger,
    SnackBar(
      content: Text(parts.isEmpty
          ? strings.t('split.cancelled')
          : strings.t('split.done', {'n': parts.length})),
    ),
  );
  return parts.isNotEmpty;
}

/// **Parçaları birleştirir.** Kullanıcı hangi parçaya dokunursa dokunsun
/// tamamı toplanır (bkz. [FileSplit.join]).
Future<bool> joinEntry(BuildContext context, FsEntry entry) async {
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final out = await showFmProgress<String>(
      context,
      title: strings.t('join.working'),
      describe: (value) => value.total > 0
          ? '${FsPaths.humanSize(value.done)} / '
              '${FsPaths.humanSize(value.total)}'
          : '',
      task: (report, isCancelled) => FileSplit.join(
        entry.path,
        isCancelled: isCancelled,
        onProgress: (done, total) =>
            report(FmProgress(done, total, p.basename(entry.path))),
      ),
    );
    if (out.isEmpty) return false;
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('join.done', {'name': p.basename(out)}))),
    );
    return true;
  } catch (e) {
    showSnackBarReplacing(
      messenger,
      SnackBar(content: Text(strings.t('join.failed', {'error': e}))),
    );
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
  if (!context.mounted) return false;
  // **Uzantı değişiyorsa sor** (2026-09-06 denetim turu). Uzantıyı silmek ya
  // da değiştirmek dosyayı "bilinmeyen tür" yapıyor: uygulama onu bir daha
  // doğru görüntüleyicide açamıyor ve kullanıcı dosyanın bozulduğunu
  // sanıyor. Adın kendisini düzeltirken uzantıyı yanlışlıkla silmek kolay.
  if (!entry.isDir && !await _confirmExtensionChange(context, entry.name, newName)) {
    return false;
  }
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

/// Uzantı değişiyorsa kullanıcıya sorar. Değişmiyorsa (ya da ekran
/// kapandıysa) doğrudan `true`.
Future<bool> _confirmExtensionChange(
    BuildContext context, String oldName, String newName) async {
  final oldExt = p.extension(oldName).toLowerCase();
  final newExt = p.extension(newName.trim()).toLowerCase();
  if (oldExt == newExt) return true;
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('fm.ext_changed_title')),
      content: Text(ctx.t('fm.ext_changed_body', {
        'old': oldExt.isEmpty ? '—' : oldExt,
        'new': newExt.isEmpty ? '—' : newExt,
      })),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('fm.ext_changed_keep'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('fm.ext_changed_go'))),
      ],
    ),
  );
  return answer ?? false;
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

/// "Paylaş" düğmesinin gerçek akışı: **önce nasıl** diye sorar.
///
/// Kullanıcı isteği (2026-09-06): *"paylaş dendiğinde iki dosya okuyucusu
/// arasında hızlı dosya paylaşımı özelliği yapalım."* Seçim penceresi iki yol
/// sunuyor — aynı Wi-Fi'deki başka bir Dosya Okuyucu'ya doğrudan gönderme
/// (hızlı, boyut sınırı yok, yeniden sıkıştırma yok) ve sistemin kendi
/// paylaşım sayfası. Yakındaki cihaz seçilmezse davranış eskisiyle birebir
/// aynı: sistem paylaşımı açılır.
Future<void> shareEntriesFrom(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return;
  if (await showShareChoice(context, paths)) return; // yakındaki cihaza gitti
  await shareEntries(paths);
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

/// Seçilenleri **takılı harici belleğe** (USB / SD kart) kopyalar.
///
/// Kullanıcı isteği (2026-09-01): *"bir harici bellek takıldığında
/// telefondaki bir belgeye tıklayıp 3 nokta ayarlarında harici belleğe
/// kopyala şeklinde basit bir kısayol da olmalı."*
///
/// Birden çok birim takılıysa hangisine gideceği SORULUR (tek birimde soru
/// yok — kısayolun anlamı tek dokunuş). Hedef, birimin kökü değil altındaki
/// `Dosya Okuyucu` klasörü: kullanıcının USB düzenini bozmamak için.
///
/// Liste menü kurulurken tazelendiği için "takılı ama listede yok" durumu
/// oluşmaz; yine de kopyalamadan hemen önce bir kez daha bakılıyor — kullanıcı
/// menü açıkken belleği çıkarmış olabilir.
Future<bool> copyToExternal(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final targets = VolumeWatcher.copyTargets();
  if (targets.isEmpty) {
    _snack(context, context.t('fm.external_none'));
    return false;
  }

  StorageVolume? volume = targets.first;
  if (targets.length > 1) {
    volume = await showModalBottomSheet<StorageVolume>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in targets)
              ListTile(
                leading: Icon(
                    v.kind == StorageKind.usb ? Icons.usb : Icons.sd_card),
                title: Text(v.displayLabel(ctx.t)),
                subtitle: Text(v.path),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
  }
  if (volume == null || !context.mounted) return false;

  final dest = VolumeWatcher.targetFolder(volume);
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

  final label = volume.displayLabel(context.t);
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_external', {'volume': label}),
    task: (report, isCancelled) => FileOps.copyAll(paths, dest,
        onProgress: report, isCancelled: isCancelled),
  );
  if (!context.mounted) return true;
  _snack(
    context,
    result.hasError
        ? context.t('fm.copy_failed', {'error': result.errors.first})
        : context.t('fm.external_copied', {
            'n': paths.length,
            'volume': label,
          }),
  );
  return true;
}

/// Seçilenleri **"Paylaşılan"** klasörüne kopyalar (klasör yoksa kurulur).
///
/// Kullanıcı isteği (2026-08-31): *"ayrı olarak paylaşılan klasörü olsun,
/// kişi göndermek istediği şeyi oraya atsın ve sadece o klasör paylaşılır …
/// dosyaların 3 nokta ayarında paylaşılan'a kopyala seçeneği olsun."*
///
/// Ağ paylaşımı bu klasörü ayrı bir kutu olarak sunuyor ([ShareScope]);
/// "Yalnız Paylaşılan klasörü" kipinde ağda GÖRÜNEN tek yer burası.
///
/// **Kopya, taşıma değil** — "Önemli Dosyalar"daki karar ile aynı gerekçe:
/// dosyayı PC'ye göndermek, onu kullanıcının bildiği yerden (DCIM, Belgeler)
/// koparmamalı.
Future<bool> copyToShared(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final dest = FtpTree.sharedFolderPath(FmEnv.primaryRoot);
  if (!await FtpTree.ensureSharedFolder(FmEnv.primaryRoot)) {
    if (context.mounted) {
      _snack(context, context.t('fm.folder_create_failed', {'error': dest}));
    }
    return false;
  }
  if (!context.mounted) return false;
  final result = await showFmProgress<FmOpResult>(
    context,
    title: context.t('fm.copying_shared'),
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
            'folder': ShareScope.sharedFolderName,
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

  /// Hesaplanmış SHA-256 özeti (2026-09-06 denetim turu).
  ///
  /// **İSTEK ÜZERİNE** hesaplanıyor: 4 GB'lık bir videoyu okumak saniyeler
  /// sürer ve özelliklere bakan kullanıcıların çoğu özeti merak etmiyor.
  /// Pencere açılışında başlatmak, her dokunuşta diski baştan sona okumak
  /// olurdu.
  String? _digest;
  bool _hashing = false;
  double _hashProgress = 0;

  /// Fotoğrafın EXIF künyesi (varsa). Dosya küçük bir başlık kadar okunuyor,
  /// o yüzden pencere açılırken başlatılabiliyor.
  ExifData? _exif;

  /// Metin dosyasının kodlaması ("UTF-8", "UTF-16 LE", "Windows-1254").
  ///
  /// Niye görünür olmalı (2026-09-06): kullanıcı bozuk görünen bir dosyada
  /// "bu neden böyle" diye soruyor; cevabı kodlama. Yalnız ilk baytlar
  /// okunuyor.
  String? _encoding;

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
    _loadExif();
    _loadEncoding();
  }

  Future<void> _loadEncoding() async {
    final entry = widget.entry;
    if (entry.isDir || entry.category != FmCategory.document) return;
    if (!ContentSearch.isSearchable(entry.path)) return;
    try {
      final head = await File(entry.path).openRead(0, 64).first;
      if (!mounted) return;
      setState(() => _encoding = TextDecode.describeEncoding(head));
    } catch (_) {
      // Okunamayan dosya için satır hiç çizilmiyor.
    }
  }

  Future<void> _loadExif() async {
    final entry = widget.entry;
    if (entry.isDir || entry.category != FmCategory.image) return;
    final data = await ExifReader.read(entry.path);
    if (!mounted || data.isEmpty) return;
    setState(() => _exif = data);
  }

  /// SHA-256'yı hesaplar. Pencere kapanırsa iş de durur (`mounted`): açık
  /// olmayan bir pencere için diski okumaya devam etmenin anlamı yok.
  Future<void> _computeDigest() async {
    setState(() {
      _hashing = true;
      _hashProgress = 0;
    });
    final value = await FileDigest.sha256Of(
      widget.entry.path,
      isCancelled: () => !mounted,
      onProgress: (done, total) {
        if (!mounted || total <= 0) return;
        final next = done / total;
        // Her blokta setState çağırmak yerine %1'lik adımlarda: 4 GB'lık
        // dosyada 4000 yeniden çizim, hesaplamanın kendisinden pahalı.
        if (next - _hashProgress >= 0.01) {
          setState(() => _hashProgress = next);
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _digest = value;
      _hashing = false;
    });
  }

  Future<void> _loadOpenedAt() async {
    await OpenHistory.ensureLoaded();
    if (!mounted) return;
    setState(() => _openedAtMs = OpenHistory.forPath(widget.entry.path));
  }

  /// Klasörün içindeki dosya ve klasör sayısı (2026-09-06 denetim turu).
  ///
  /// Boyut tek başına "bu klasörde ne kadar iş var" sorusunu yanıtlamıyor:
  /// 2 GB bir video da olabilir, 40 000 küçük dosya da — ve ikisi kopyalarken
  /// bambaşka sürüyor.
  ({int files, int dirs})? _counts;

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    final size = await FsScan.folderSize(widget.entry.path);
    final counts = await _countChildren(widget.entry.path);
    if (!mounted) return;
    setState(() {
      _folderSize = size;
      _counts = counts;
      _calculating = false;
    });
  }

  /// Özyinelemeli sayım — arada nefes alır (binlerce girdide arayüz donmasın).
  static Future<({int files, int dirs})> _countChildren(String root) async {
    var files = 0;
    var dirs = 0;
    var steps = 0;
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 24) return;
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        return;
      }
      for (final child in children) {
        if (++steps % 256 == 0) await Future<void>.delayed(Duration.zero);
        if (child is Directory) {
          dirs++;
          await walk(child, depth + 1);
        } else {
          files++;
        }
      }
    }

    await walk(Directory(root), 0);
    return (files: files, dirs: dirs);
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
            _row(context.t('prop.name'), e.name),
            _row(context.t('fm.type'), e.isDir ? context.t('fm.folder') : e.category.label),
            if (!e.isDir) _row(context.t('prop.size'), FsPaths.humanSize(e.sizeBytes)),
            if (e.isDir)
              _row(
                context.t('prop.size'),
                _folderSize != null
                    ? FsPaths.humanSize(_folderSize!)
                    : (_calculating ? context.t('fm.computing') : context.t('fm.not_computed')),
              ),
            _row(context.t('fm.modified'), FsPaths.humanDate(e.modifiedMs)),
            // Yalnız gerçekten bir kaydımız varsa yazılır: "—" göstermek
            // "hiç açılmadı" ile "bilmiyorum"u karıştırırdı.
            if (_openedAtMs != null)
              _row(context.t('fm.last_opened'), FsPaths.humanDate(_openedAtMs!)),
            _row(context.t('prop.location'), e.path),
            if (_counts != null)
              _row(
                context.t('prop.contents'),
                context.t('prop.contents_value',
                    {'files': _counts!.files, 'dirs': _counts!.dirs}),
              ),
            if (_encoding != null) _row(context.t('prop.encoding'), _encoding!),
            if (!e.isDir) ..._digestSection(context),
            if (_exif != null) ..._exifSection(context, _exif!),
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
            Clipboard.setData(ClipboardData(text: e.name));
            Navigator.pop(context);
          },
          child: Text(context.t('prop.copy_name')),
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

  /// **Özet satırı** — "indirdiğim dosya bozuk mu?" sorusunun cevabı.
  ///
  /// Hesaplanmadan önce bir düğme, hesaplanırken ilerleme, sonra dokununca
  /// panoya kopyalanan bir değer. Değer `SelectableText`: kullanıcı yayıncının
  /// sitesindeki özetle GÖZLE de karşılaştırabilmeli.
  List<Widget> _digestSection(BuildContext context) {
    if (_digest != null) {
      return [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _digest!));
            _snack(context, context.t('prop.digest_copied'));
          },
          child: _row(context.t('prop.digest'), _digest!),
        ),
      ];
    }
    if (_hashing) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('prop.digest'),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: _hashProgress > 0 ? _hashProgress : null),
            ],
          ),
        ),
      ];
    }
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _computeDigest,
          icon: const Icon(Icons.tag, size: 18),
          label: Text(context.t('prop.compute_digest')),
        ),
      ),
    ];
  }

  /// Fotoğrafın künyesi. **Konum (GPS) BİLİNÇLİ OLARAK YOK** — bkz.
  /// `services/fm/exif_reader.dart`.
  List<Widget> _exifSection(BuildContext context, ExifData exif) {
    final rows = <Widget>[
      const SizedBox(height: 8),
      Text(context.t('prop.photo_info'),
          style: Theme.of(context).textTheme.titleSmall),
    ];
    void add(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(_row(label, value));
    }

    add(context.t('prop.taken_at'),
        exif.taken == null ? null : FsPaths.humanDate(
            exif.taken!.millisecondsSinceEpoch));
    add(context.t('prop.camera'), exif.camera);
    add(context.t('prop.lens'), exif.lens);
    if (exif.width != null && exif.height != null) {
      add(context.t('prop.resolution'), '${exif.width} × ${exif.height}');
    }
    add(context.t('prop.iso'), exif.iso?.toString());
    add(context.t('prop.exposure'), exif.exposureLabel);
    add(context.t('prop.aperture'),
        exif.aperture == null ? null : 'f/${exif.aperture!.toStringAsFixed(1)
            .replaceAll('.', ',')}');
    add(context.t('prop.focal'),
        exif.focalLength == null ? null : '${exif.focalLength!.round()} mm');
    add(
      context.t('prop.flash'),
      exif.flash == null
          ? null
          : (exif.flash! ? context.t('prop.flash_on') : context.t('prop.flash_off')),
    );
    add(context.t('prop.software'), exif.software);
    return rows;
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
