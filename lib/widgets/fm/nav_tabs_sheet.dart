import 'package:flutter/material.dart';

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
          icon: Icons.download_outlined,
          selected: Icons.download_rounded,
          label: context.t('fm.downloads'),
        ),
      'new' => (
          icon: Icons.move_to_inbox_outlined,
          selected: Icons.move_to_inbox,
          label: context.t('fm.new_files'),
        ),
      'image' => (
          icon: Icons.image_outlined,
          selected: Icons.image_rounded,
          label: FmCategory.image.label,
        ),
      'video' => (
          icon: Icons.movie_outlined,
          selected: Icons.movie_rounded,
          label: FmCategory.video.label,
        ),
      'document' => (
          icon: Icons.description_outlined,
          selected: Icons.description_rounded,
          label: FmCategory.document.label,
        ),
      'audio' => (
          icon: Icons.music_note_outlined,
          selected: Icons.music_note_rounded,
          label: FmCategory.audio.label,
        ),
      'archive' => (
          icon: Icons.folder_zip_outlined,
          selected: Icons.folder_zip_rounded,
          label: FmCategory.archive.label,
        ),
      'apk' => (
          icon: Icons.install_mobile_outlined,
          selected: Icons.install_mobile_rounded,
          label: context.t('fm.apk_files'),
        ),
      'important' => (
          icon: Icons.star_outline_rounded,
          selected: Icons.star_rounded,
          label: context.t('nav.important'),
        ),
      'recent' => (
          icon: Icons.history_outlined,
          selected: Icons.history_rounded,
          label: context.t('fm.recent_opened'),
        ),
      'search' => (
          icon: Icons.search_outlined,
          selected: Icons.saved_search_rounded,
          label: context.t('common.search'),
        ),
      'ai' => (
          icon: Icons.auto_awesome_outlined,
          selected: Icons.auto_awesome,
          label: context.t('nav.ai'),
        ),
      'smart' => (
          icon: Icons.folder_special_outlined,
          selected: Icons.folder_special_rounded,
          label: context.t('smart.title'),
        ),
      'bills' => (
          icon: Icons.receipt_long_outlined,
          selected: Icons.receipt_long_rounded,
          label: context.t('nav.bills'),
        ),
      'vault' => (
          icon: Icons.enhanced_encryption_outlined,
          selected: Icons.enhanced_encryption_rounded,
          label: context.t('nav.vault'),
        ),
      'memories' => (
          icon: Icons.auto_awesome_mosaic_outlined,
          selected: Icons.auto_awesome_mosaic_rounded,
          label: context.t('mem.title'),
        ),
      'jobs' => (
          icon: Icons.playlist_add_check_outlined,
          selected: Icons.playlist_add_check_circle_rounded,
          label: context.t('fm.jobs'),
        ),
      'trash' => (
          icon: Icons.delete_outline_rounded,
          selected: Icons.delete_rounded,
          label: context.t('fm.trash'),
        ),
      'drive' => (
          icon: Icons.cloud_outlined,
          selected: Icons.cloud_rounded,
          label: 'Drive',
        ),
      'apps' => (
          icon: Icons.android_outlined,
          selected: Icons.android_rounded,
          label: context.t('fm.apps'),
        ),
      _ => (
          icon: Icons.folder_outlined,
          selected: Icons.folder,
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
                    child: Icon(Icons.lock_outline_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  )),
            ),
            SliverReorderableList(
              itemCount: rest.length,
              onReorder: (from, to) => nav.move(from, to),
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
                          icon: Icon(Icons.remove_circle_outline_rounded,
                              color: scheme.error),
                          onPressed: () => nav.remove(rest[i]),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.sm),
                            child: Icon(Icons.drag_handle_rounded,
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
                  icon: Icon(Icons.add_circle_outline_rounded,
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
                    icon: const Icon(Icons.restart_alt_rounded),
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
