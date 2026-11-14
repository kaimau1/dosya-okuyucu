import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/nav_tabs.dart';
import '../../services/fm/storage_stats.dart' show StorageKind;
import 'fm_entry_icon.dart';

/// **Tabletin kalıcı gezinme sütunu** (Ferrari H9.1, 2026-11-14): yalnız
/// `isTabletWide` ekranda, ana kabuğun solunda. Üstte pano / son açılanlar /
/// yeni dosyalar / indirilenler, ortada kategoriler, altta depolamalar.
/// Sekme kimlikleri [NavTabs.available] ile aynı — seçilen sayfa sağda açılır,
/// sütun yerinde kalır. Depolama satırı gezgini iter ([onVolume]).
/// Daraltılınca yalnız simgeler (ipucuyla) kalır.
class HomeNavColumn extends StatelessWidget {
  static const double expandedWidth = 280;
  static const double collapsedWidth = 72;

  /// Sütunun gösterdiği sekmeler (sıra = ekrandaki sıra).
  static const top = [NavTabs.home, 'recent', 'new', 'downloads'];
  static const categories = [
    (id: 'image', cat: FmCategory.image),
    (id: 'video', cat: FmCategory.video),
    (id: 'document', cat: FmCategory.document),
    (id: 'audio', cat: FmCategory.audio),
    (id: 'archive', cat: FmCategory.archive),
    (id: 'apk', cat: FmCategory.apk),
  ];

  /// Sütunun açabildiği tüm sekme kimlikleri.
  static final ids = [...top, for (final c in categories) c.id];

  final String selected;
  final bool collapsed;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onVolume;
  final VoidCallback onToggle;

  const HomeNavColumn({
    super.key,
    required this.selected,
    required this.collapsed,
    required this.onSelect,
    required this.onVolume,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String label,
        {bool active = false, required VoidCallback onTap}) {
      if (collapsed) {
        return Center(
          child: IconButton(
            tooltip: label,
            isSelected: active,
            icon: Icon(icon, size: AppIcons.medium),
            onPressed: onTap,
          ),
        );
      }
      return ListTile(
        dense: true,
        leading: Icon(icon, size: AppIcons.medium),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: active,
        selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        onTap: onTap,
      );
    }

    Widget header(String text) => collapsed
        ? const Divider(height: Gap.md)
        : Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.md, Gap.md, Gap.md, Gap.xs),
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          );

    (IconData, String) topItem(String id) => switch (id) {
          'recent' => (AppIcons.history, context.t('oh.title')),
          'new' => (AppIcons.incoming, context.t('fm.new_files')),
          'downloads' => (AppIcons.download, context.t('fm.downloads')),
          _ => (AppIcons.home, context.t('fm.files')),
        };

    return Material(
      key: const ValueKey('home-nav-column'),
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: collapsed ? collapsedWidth : expandedWidth,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.all(Gap.sm),
            children: [
              Align(
                alignment: collapsed
                    ? Alignment.center
                    : AlignmentDirectional.centerStart,
                child: IconButton(
                  key: const ValueKey('home-nav-toggle'),
                  tooltip:
                      context.t(collapsed ? 'nav.expand' : 'nav.collapse'),
                  icon: const Icon(AppIcons.viewColumn),
                  onPressed: onToggle,
                ),
              ),
              for (final id in top)
                () {
                  final (icon, label) = topItem(id);
                  return tile(icon, label,
                      active: selected == id, onTap: () => onSelect(id));
                }(),
              header(context.t('fm.categories')),
              for (final c in categories)
                tile(FmEntryIcon.iconFor(c.cat), context.t(c.cat.labelKey),
                    active: selected == c.id, onTap: () => onSelect(c.id)),
              header(context.t('pane.places')),
              for (final v in FmEnv.volumes)
                tile(
                  switch (v.kind) {
                    StorageKind.usb => AppIcons.external,
                    StorageKind.sdCard => AppIcons.sdCard,
                    _ => AppIcons.device,
                  },
                  v.displayLabel(context.t),
                  onTap: () => onVolume(v.path),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
