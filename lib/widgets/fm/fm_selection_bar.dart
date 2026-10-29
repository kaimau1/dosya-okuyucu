import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../screens/fm/entry_actions.dart';
import '../../screens/fm/resize_actions.dart';
import '../../screens/fm/swipe_pager.dart';
import '../app_action_sheet.dart';
import 'ai_tag_flow.dart';
import 'batch_rename_sheet.dart';
import 'tag_picker_sheet.dart';
import '../../core/snack.dart';

/// Çoklu seçim yapılınca ekranın altında beliren **eylem çubuğu**.
///
/// Kullanıcı isteği (2026-07-29): *"basılı tuttuğumda çıkan menüde rahatlıkla
/// yapabilmeliyim, her türlü dosyada bu olmalı"*. Uzun basış zaten seçim
/// kipini açıyordu ama seçince yapılabilecekler üst çubuktaki küçük simgelere
/// sıkışmıştı ve **taşıma/kopyalama yoktu** — yalnız pano vardı (kopyala →
/// sekme değiştir → klasörü bul → yapıştır).
///
/// Tasarım kararları:
/// - **Altta**, çünkü telefonun üst köşesi başparmakla zor: en sık kullanılan
///   dört eylem (Taşı · Kopyala · Paylaş · Sil) etiketleriyle burada.
/// - Etiketler yazıyla: simge tek başına ("makas mı kes mi?") tahmin ettirir.
/// - Klasör seçiliyken **Paylaş yok**: Android klasör paylaşamaz, gösterilse
///   dokunulup hiçbir şey olmuyor sanılırdı.
/// - Nadir işler ⋮ altında (pano, sıkıştır, önemli dosyalar, yeniden adlandır).
class FmSelectionBar extends StatelessWidget {
  /// Seçili girdiler.
  final List<FsEntry> selected;

  /// Dosya sistemi değiştikten sonra çağrılır (liste tazelensin, seçim
  /// temizlensin). İşlem iptal edilirse çağrılmaz.
  final Future<void> Function() onChanged;

  /// "Sıkıştır" hedef klasörü; null ise sıkıştırma gösterilmez (kategori/arama
  /// gibi tek klasöre ait olmayan listelerde arşivin nereye yazılacağı belirsiz).
  final String? zipDestDir;

  const FmSelectionBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.zipDestDir,
  });

  List<String> get _paths => selected.map((e) => e.path).toList();

  bool get _anyDir => selected.any((e) => e.isDir);

  /// Boyut düşürme yalnız fotoğraf/videoda anlamlı.
  bool get _anyMedia => selected.any(
      (e) => e.category == FmCategory.image || e.category == FmCategory.video);

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Çubuk görünürken kaydırmalı kategori gezgini yana GEÇMEZ (2026-10-17
    // kullanıcı: "seçim yapılırken sağa sola kaydırıp sayfalar arasında
    // geçiş olmamalı") — bkz. `SwipePager`.
    return SwipeHold(
      child: ToastAvoider(
        child: Material(
          elevation: 8,
          color: theme.colorScheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _action(
                    context,
                    AppIcons.move,
                    context.t('fm.move'),
                    () async {
                      if (await moveOrCopyEntries(context, _paths,
                          move: true)) {
                        await onChanged();
                      }
                    },
                  ),
                  _action(
                    context,
                    AppIcons.copy,
                    context.t('fm.copy'),
                    () async {
                      if (await moveOrCopyEntries(context, _paths,
                          move: false)) {
                        await onChanged();
                      }
                    },
                  ),
                  _action(
                      context,
                      AppIcons.share,
                      context.t('common.share'),
                      () => shareEntriesFrom(context, _paths),
                    ),
                  _action(
                    context,
                    AppIcons.delete,
                    context.t('common.delete'),
                    () async {
                      if (await deleteEntries(context, selected)) {
                        await onChanged();
                      }
                    },
                    danger: true,
                  ),
                  _more(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    Future<void> Function() onTap, {
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Daha fazla" — gruplu, simgeli **eylem levhası** (2026-10-23; eskiden
  /// ekranın ortasında açılan simgesiz on satırlık metin menüsüydü).
  Widget _more(BuildContext context) => _action(
        context,
        AppIcons.moreHoriz,
        context.t('fm.more'),
        () async {
          final n = selected.length;
          final v = await showAppActionSheet<String>(
            context,
            title: context.t('sel.sheet_title', {'n': n}),
            subtitle: n == 1 ? selected.first.name : null,
            groups: [
              AppActionGroup(title: context.t('sel.group_organize'), actions: [
                AppAction(
                    value: 'tag',
                    icon: AppIcons.tag,
                    label: context.t('fm.tag')),
                AppAction(
                    value: 'ai_tag',
                    icon: AppIcons.ai,
                    accent: true,
                    label: context.t('tagai.action'),
                    hint: context.t('tagai.action_hint')),
                if (_anyMedia)
                  AppAction(
                      value: 'resize',
                      icon: AppIcons.resize,
                      label: context.t('fm.resize')),
                if (n == 1)
                  AppAction(
                      value: 'rename',
                      icon: AppIcons.rename,
                      label: context.t('fm.rename')),
                if (n > 1)
                  AppAction(
                      value: 'batch_rename',
                      icon: AppIcons.rename,
                      label: context.t('fm.batch_rename')),
                if (zipDestDir != null)
                  AppAction(
                      value: 'zip',
                      icon: AppIcons.compress,
                      label: context.t('fm.compress')),
              ]),
              AppActionGroup(title: context.t('sel.group_copy'), actions: [
                AppAction(
                    value: 'important',
                    icon: AppIcons.star,
                    label: context.t('fm.copy_to_important')),
                AppAction(
                    value: 'shared',
                    icon: AppIcons.shareFolder,
                    label: context.t('fm.copy_to_shared')),
                AppAction(
                    value: 'clip_copy',
                    icon: AppIcons.clipCopy,
                    label: context.t('fm.clip_copy')),
                AppAction(
                    value: 'clip_cut',
                    icon: AppIcons.cut,
                    label: context.t('fm.clip_cut')),
              ]),
              AppActionGroup(title: context.t('sel.group_more'), actions: [
                AppAction(
                    value: 'hide',
                    icon: AppIcons.hidden,
                    label: context.t('ea.hide'),
                    hint: context.t('sel.hide_hint')),
                if (n == 2 && !_anyDir)
                  AppAction(
                      value: 'compare',
                      icon: AppIcons.compare,
                      label: context.t('fm.compare_digest')),
                if (n == 1)
                  AppAction(
                      value: 'properties',
                      icon: AppIcons.info,
                      label: context.t('fm.properties')),
              ]),
            ],
          );
          if (v != null && context.mounted) await _run(context, v);
        },
      );

  Future<void> _run(BuildContext context, String value) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    // Asenkron boşluktan sonra `context` kullanılamaz → metinler şimdi alınır.
    final clipCopied = context.t('fm.clipboard_copied');
    final clipCut = context.t('fm.clipboard_cut');
    switch (value) {
      case 'important':
        if (await copyToImportant(context, _paths)) await onChanged();
      case 'shared':
        // Çoklu seçimde de var: kullanıcı PC'ye birden çok dosya
        // göndermek isterse tek tek ⋮ açması saçma olurdu.
        if (await copyToShared(context, _paths)) await onChanged();
      case 'clip_copy':
        appState.setClipboard(_paths, cut: false);
        showSnackOn(messenger, clipCopied);
        await onChanged();
      case 'clip_cut':
        appState.setClipboard(_paths, cut: true);
        showSnackOn(messenger, clipCut);
        await onChanged();
      case 'zip':
        final dest = zipDestDir;
        if (dest != null && await zipEntries(context, _paths, dest)) {
          await onChanged();
        }
      case 'rename':
        if (selected.length == 1 &&
            await renameEntry(context, selected.first)) {
          await onChanged();
        }
      case 'batch_rename':
        if (await showBatchRenameSheet(context, selected)) {
          await onChanged();
        }
      case 'resize':
        // İş kuyruğa gider; liste tazelemeyi FsEvents üstleniyor.
        await startResizeJob(context, selected);
      case 'tag':
        if (await showTagPicker(context, _paths)) await onChanged();
      case 'ai_tag':
        if (await showAiTagFlow(context, selected)) await onChanged();
      case 'hide':
        if (await hideEntries(context, _paths)) await onChanged();
      case 'properties':
        if (selected.length == 1 && context.mounted) {
          await showProperties(context, selected.first);
        }
      case 'compare':
        // **İki dosya aynı mı?** (2026-09-06 denetim turu.) Aynı adı
        // taşıyan iki kopya ("rapor.pdf" ve "rapor (1).pdf") gerçekten
        // aynı mı, yoksa biri güncel mi — kullanıcının bunu anlamasının
        // hiçbir yolu yoktu; boyut eşitliği yeterli değil.
        if (selected.length == 2 && context.mounted) {
          await compareTwoFiles(context, _paths);
        }
    }
  }
}
