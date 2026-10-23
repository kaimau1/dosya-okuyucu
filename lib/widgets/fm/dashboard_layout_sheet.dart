import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/dashboard_layout.dart';
import '../../core/safe_insets.dart';
import 'nav_tabs_sheet.dart';
import '../../core/app_colors.dart';

/// Düzen sayfasındaki bir satırın görünümü.
typedef LayoutRowInfo = ({String label, IconData icon, Color color});

/// **Ana ekranı düzenle** sayfası: kutuların ve bölümlerin sırası (sürükle)
/// ve görünürlüğü (anahtar). Değişiklik ANINDA panoya yansır (arkada görünür).
Future<void> showDashboardLayoutSheet(
  BuildContext context, {
  required Map<String, LayoutRowInfo> tiles,
  required Map<String, LayoutRowInfo> sections,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: AppColors.barrier,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _LayoutSheet(tiles: tiles, sections: sections, scroll: scroll),
    ),
  );
}

class _LayoutSheet extends StatefulWidget {
  final Map<String, LayoutRowInfo> tiles;
  final Map<String, LayoutRowInfo> sections;
  final ScrollController scroll;

  const _LayoutSheet({
    required this.tiles,
    required this.sections,
    required this.scroll,
  });

  @override
  State<_LayoutSheet> createState() => _LayoutSheetState();
}

class _LayoutSheetState extends State<_LayoutSheet> {
  bool _tilesTab = true;

  @override
  Widget build(BuildContext context) {
    final layout = DashboardLayout.instance;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: layout,
      builder: (context, _) {
        final ids = _tilesTab
            ? layout.tileOrder.where(widget.tiles.containsKey).toList()
            : layout.sectionOrder.where(widget.sections.containsKey).toList();
        final info = _tilesTab ? widget.tiles : widget.sections;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(context.t('dash.title'), style: text.titleLarge),
                  ),
                  if (layout.isCustomized)
                    TextButton.icon(
                      onPressed: layout.reset,
                      icon: const Icon(AppIcons.reset, size: 18),
                      label: Text(context.t('dash.reset')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(AppIcons.layoutGrid),
                    label: Text(context.t('dash.tiles')),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(AppIcons.layoutDetail),
                    label: Text(context.t('dash.sections')),
                  ),
                ],
                selected: {_tilesTab},
                onSelectionChanged: (v) => setState(() => _tilesTab = v.first),
              ),
            ),
            // Alt çubuk da ana ekranın parçası (2026-10-18): kullanıcı onu
            // "ana ekranı düzenle"de de arar.
            ListTile(
              leading: const Icon(AppIcons.spaceDashboard),
              title: Text(context.t('nav.edit_title')),
              subtitle: Text(context.t('nav.settings_sub')),
              trailing: const Icon(AppIcons.chevron),
              onTap: () => showNavTabsSheet(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Text(context.t('dash.hint'),
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: widget.scroll,
                buildDefaultDragHandles: false,
                padding: withNavInset(
                    context, const EdgeInsets.only(bottom: 24)),
                itemCount: ids.length,
                onReorderItem: (from, to) {
                  // Görünen alt kümede sürükleniyor; [to] alt kümedeki son
                  // dizin → tam listede yerini aldığı öğenin dizinine çevir.
                  final full =
                      _tilesTab ? layout.tileOrder : layout.sectionOrder;
                  final fromFull = full.indexOf(ids[from]);
                  final toFull = full.indexOf(ids[to]);
                  _tilesTab
                      ? layout.moveTile(fromFull, toFull)
                      : layout.moveSection(fromFull, toFull);
                },
                itemBuilder: (context, i) {
                  final id = ids[i];
                  final row = info[id]!;
                  final visible = _tilesTab
                      ? layout.tileVisible(id)
                      : layout.sectionVisible(id);
                  return ListTile(
                    key: ValueKey('$_tilesTab-$id'),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: row.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(row.icon, size: 20, color: row.color),
                    ),
                    title: Text(row.label,
                        style: TextStyle(
                            color: visible ? null : scheme.onSurfaceVariant)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: visible,
                          onChanged: (v) => _tilesTab
                              ? layout.setTileVisible(id, v)
                              : layout.setSectionVisible(id, v),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(AppIcons.dragIndicator),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
