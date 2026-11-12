import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/state/focused_states.dart';
import '../../core/l10n/app_strings.dart';
import '../app_dialog.dart';

/// Favori klasörlerin sırası (Faz 41 / 6): tutamaçtan sürükle. Sıra gezginin
/// yan bölmesinde ve klasör seçicide aynen görünür.
Future<void> showFavoritesOrderSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: context.t('fav.reorder'),
    scrollable: false,
    builder: (ctx) => const _FavoritesOrder(),
  );
}

class _FavoritesOrder extends StatelessWidget {
  const _FavoritesOrder();

  @override
  Widget build(BuildContext context) {
    final state = context.watchBrowse();
    final list = state.bookmarks;
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        itemCount: list.length,
        onReorderItem: (from, to) => state.moveBookmark(from, to),
        itemBuilder: (context, i) => ListTile(
          key: ValueKey('fav-${list[i]}'),
          leading: const Icon(AppIcons.star),
          title: Text(p.basename(list[i]),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(list[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: ReorderableDragStartListener(
            index: i,
            child: Semantics(
              label: context.t('fav.drag'),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(AppIcons.dragHandle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
