import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/nav_tabs.dart';

/// Bir alt çubuk sekmesinin görünümü: simge, seçili simge, etiket.
typedef NavTabSpec = ({IconData icon, IconData selected, String label});

/// Sekme kimliğinden görünüm. Bilinmeyen kimlik Dosyalar'a düşer (olmaz
/// ama çubuk boş simgeyle çizilmesin).
NavTabSpec navTabSpec(BuildContext context, String id) => switch (id) {
      'downloads' => (
          icon: AppIcons.download,
          selected: AppIcons.download,
          label: context.t('fm.downloads'),
        ),
      'new' => (
          icon: AppIcons.moveToInbox,
          selected: AppIcons.moveToInbox,
          label: context.t('fm.new_files'),
        ),
      'image' => (
          icon: AppIcons.image,
          selected: AppIcons.image,
          label: FmCategory.image.label,
        ),
      'video' => (
          icon: AppIcons.video,
          selected: AppIcons.video,
          label: FmCategory.video.label,
        ),
      'document' => (
          icon: AppIcons.newWord,
          selected: AppIcons.newWord,
          label: FmCategory.document.label,
        ),
      'audio' => (
          icon: AppIcons.audio,
          selected: AppIcons.audio,
          label: FmCategory.audio.label,
        ),
      'archive' => (
          icon: AppIcons.archiveView,
          selected: AppIcons.archiveView,
          label: FmCategory.archive.label,
        ),
      'apk' => (
          icon: AppIcons.installMobile,
          selected: AppIcons.installMobile,
          label: context.t('fm.apk_files'),
        ),
      'important' => (
          icon: AppIcons.starOutline,
          selected: AppIcons.star,
          label: context.t('nav.important'),
        ),
      'recent' => (
          icon: AppIcons.history,
          selected: AppIcons.history,
          label: context.t('fm.recent_opened'),
        ),
      'search' => (
          icon: AppIcons.search,
          selected: AppIcons.savedSearch,
          label: context.t('common.search'),
        ),
      'ai' => (
          icon: AppIcons.ai,
          selected: AppIcons.ai,
          label: context.t('nav.ai'),
        ),
      'smart' => (
          icon: AppIcons.folderSpecial,
          selected: AppIcons.folderSpecial,
          label: context.t('smart.title'),
        ),
      'bills' => (
          icon: AppIcons.receiptLong,
          selected: AppIcons.receiptLong,
          label: context.t('nav.bills'),
        ),
      'vault' => (
          icon: AppIcons.vault,
          selected: AppIcons.vault,
          label: context.t('nav.vault'),
        ),
      'jobs' => (
          icon: AppIcons.exportList,
          selected: AppIcons.playlistAddCheckCircle,
          label: context.t('fm.jobs'),
        ),
      'trash' => (
          icon: AppIcons.delete,
          selected: AppIcons.delete,
          label: context.t('fm.trash'),
        ),
      'drive' => (
          icon: AppIcons.cloud,
          selected: AppIcons.cloud,
          label: 'Drive',
        ),
      'apps' => (
          icon: AppIcons.android,
          selected: AppIcons.android,
          label: context.t('fm.apps'),
        ),
      _ => (
          icon: AppIcons.folder,
          selected: AppIcons.folder,
          label: context.t('home.tab_files'),
        ),
    };

/// **Alt çubuğu düzenle** sayfası: üstte çubuktaki sekmeler (sürükleyerek
/// sıralanır, çarpıyla çıkarılır), altta eklenebilecekler. Dosyalar kilitli.
///
/// Çubuk dışından da açılır (Ayarlar → Görünüm, Ana ekranı düzenle) ama asıl
/// kapı çubuğun kendisine **basılı tutmak** — kullanıcı onu orada arar.
Future<void> showNavTabsSheet(BuildContext context) async {
  await NavTabs.instance.ensureLoaded();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => _NavTabsEditor(scroll: scroll),
    ),
  );
}

class _NavTabsEditor extends StatelessWidget {
  final ScrollController scroll;
  const _NavTabsEditor({required this.scroll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: NavTabs.instance,
      builder: (context, _) {
        final nav = NavTabs.instance;
        final tabs = nav.tabs;
        final rest = tabs.skip(1).toList();
        final addable = [
          for (final id in NavTabs.available)
            if (!tabs.contains(id)) id,
        ];
        return CustomScrollView(
          controller: scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('nav.edit_title'),
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: Gap.xs),
                    Text(
                      context.t('nav.edit_sub', {
                        'n': tabs.length,
                        'max': NavTabs.maxTabs,
                      }),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            // Dosyalar — kilitli, hep ilk.
            SliverToBoxAdapter(
              child: _row(context, NavTabs.home,
                  trailing: Tooltip(
                    message: context.t('nav.home_locked'),
                    child: Icon(AppIcons.lock,
                        size: 20, color: scheme.onSurfaceVariant),
                  )),
            ),
            SliverReorderableList(
              itemCount: rest.length,
              onReorderItem: (from, to) => nav.move(from, to),
              itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                key: ValueKey('nav-${rest[i]}'),
                index: i,
                child: Material(
                  color: Colors.transparent,
                  child: _row(
                    context,
                    rest[i],
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.t('nav.remove'),
                          icon: Icon(AppIcons.removeCircleOutline,
                              color: scheme.error),
                          onPressed: () => nav.remove(rest[i]),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.sm),
                            child: Icon(AppIcons.dragHandle,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  nav.isFull
                      ? context.t('nav.full', {'max': NavTabs.maxTabs})
                      : context.t('nav.addable'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: nav.isFull ? scheme.error : scheme.primary,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: addable.length,
              itemBuilder: (context, i) => _row(
                context,
                addable[i],
                faded: nav.isFull,
                trailing: IconButton(
                  tooltip: context.t('nav.add'),
                  icon: Icon(AppIcons.addCircleOutline,
                      color: nav.isFull
                          ? scheme.onSurfaceVariant
                          : scheme.primary),
                  onPressed: () async {
                    final ok = await nav.add(addable[i]);
                    if (!ok && context.mounted) {
                      showSnack(context,
                          context.t('nav.full', {'max': NavTabs.maxTabs}));
                    }
                  },
                ),
              ),
            ),
            SliverPadding(
              // Son düğme ("Varsayılana dön") gezinme çubuğunun altında
              // kalmasın — `useSafeArea` alt kenarı korumuyor.
              padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: nav.isDefault ? null : nav.reset,
                    icon: const Icon(AppIcons.reset),
                    label: Text(context.t('nav.reset')),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, String id,
      {required Widget trailing, bool faded = false}) {
    final spec = navTabSpec(context, id);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: faded ? scheme.surfaceContainerHigh : scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(spec.selected,
            size: 22,
            color: faded ? scheme.onSurfaceVariant : scheme.onPrimaryContainer),
      ),
      title: Text(spec.label),
      trailing: trailing,
    );
  }
}
