import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../services/fm/smart_user_cats.dart';
import '../../services/gemini_decisions.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/smart_cat_style.dart';

/// **Kategori ekle** (2026-11-19, kullanıcı: *"bir de kategori ekle olsun;
/// AI ile oluşturduğumuz kategorilerle ortak alan, onlar manuel eklenebilir
/// olsun ve ilgili işlevlere bağlansın"*).
///
/// Tek kaynak Akıllı düzen: yerleşik AI kategorileri ([SmartSort.correct],
/// elle düzeltilmiş sayılır) + kullanıcı kategorileri
/// ([SmartSort.addToUserCat], AI turu ezmez). Böylece eklenen kategori
/// Akıllı düzen listelerinde, Fotoğraflar/Dosyalar AI kategori süzgecinde,
/// ikinci adda ve aramada görünür; AI ile ikinci ad verirken de aynı
/// kategoriler kullanılır. Kategori adı dosyanın etiketi de olur (AI ile
/// ikinci ad gibi). "Yeni kategori" yalnız ad ister (AI denemesi gerekmez);
/// ayrıntı (kapsam cümlesi, simge) Akıllı düzen › Kategorilerim'den.
///
/// Tek dosyada kullanıcı kategorisine yeniden dokunmak dosyayı ondan
/// çıkarır. Değişiklik olduysa true.
Future<bool> showAddCategory(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  await SmartSort.ensureLoaded();
  await SmartUserCats.ensureLoaded();
  if (!context.mounted) return false;
  final one = paths.length == 1 ? paths.first : null;
  final image =
      paths.any((p) => GeminiDecisions.mediaFor(p)?.type == 'image');
  final chosen = await showAppSheet<String>(
    context,
    scrollable: false,
    builder: (_) => CategoryAddSheet(
      count: paths.length,
      current: one == null ? null : SmartSort.of(one)?.cat,
      inUser: one == null
          ? const <String>{}
          : SmartSort.userCatsOf(one).toSet(),
      image: image,
    ),
  );
  if (chosen == null || !context.mounted) return false;
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var id = chosen;
  if (chosen == CategoryAddSheet.newCat) {
    if (SmartUserCats.isFull) {
      showSnackOn(messenger, s.t('cat.full', {'n': SmartUserCats.maxCats}));
      return false;
    }
    final name = await showAppPrompt(
      context,
      title: s.t('cat.new_title'),
      label: s.t('cat.new_label'),
      confirmLabel: s.t('common.save'),
      maxLength: 40,
    );
    if (name == null || name.trim().isEmpty) return false;
    final cat = await SmartUserCats.add(name: name, about: name);
    if (cat == null) return false;
    id = cat.id;
  }
  final user = SmartUserCats.isUserId(id);
  final tag = user
      ? (SmartUserCats.byId(id)?.name ?? '')
      : s.t('sm.c_$id');
  if (user && one != null && SmartSort.userCatsOf(one).contains(id)) {
    await SmartSort.removeFromUserCat(paths, id);
    if (tag.isNotEmpty) await FileTags.remove(paths, tag);
    showSnackOn(messenger, s.t('cat.removed', {'cat': tag}));
    return true;
  }
  if (user) {
    await SmartSort.addToUserCat(paths, id);
  } else {
    for (final path in paths) {
      await SmartSort.correct(path, id);
    }
  }
  if (tag.isNotEmpty && id != SmartTaxonomy.other) {
    await FileTags.add(paths, tag);
  }
  showSnackOn(messenger, s.t('cat.added', {'cat': tag, 'n': paths.length}));
  return true;
}

class CategoryAddSheet extends StatelessWidget {
  /// "Yeni kategori" seçimi.
  static const newCat = '__new__';

  final int count;

  /// Tek dosyanın yerleşik kategorisi (yoksa null).
  final String? current;

  /// Tek dosyanın kullanıcı kategorileri (seçili görünür).
  final Set<String> inUser;

  /// Seçimde görsel var mı (görsel kategorileri de gösterilir).
  final bool image;

  const CategoryAddSheet({
    super.key,
    required this.count,
    required this.current,
    required this.inUser,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String c, bool selected) => ChoiceChip(
          key: ValueKey('cat-$c'),
          selected: selected,
          avatar: selected
              ? null
              : Icon(SmartCatStyle.icon(c),
                  size: 18, color: SmartCatStyle.color(c)),
          label: Text(SmartCatStyle.label(context, c)),
          onSelected: (_) => Navigator.pop(context, c),
        );
    Widget chips(Iterable<String> cats) => Wrap(
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: [for (final c in cats) chip(c, c == current)],
        );
    Widget head(String key) => Padding(
          padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
          child: Text(context.t(key), style: theme.textTheme.labelLarge),
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(AppIcons.tag),
              title: Text(context.t('cat.add')),
              subtitle: Text(context.t('cat.add_body', {'n': count})),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    head('cat.mine'),
                    Wrap(
                      spacing: Gap.xs,
                      runSpacing: Gap.xs,
                      children: [
                        for (final c in SmartUserCats.all)
                          chip(c.id, inUser.contains(c.id)),
                        ActionChip(
                          key: const ValueKey('cat-new'),
                          avatar: const Icon(AppIcons.add, size: 18),
                          label: Text(context.t('cat.new')),
                          onPressed: () =>
                              Navigator.pop(context, CategoryAddSheet.newCat),
                        ),
                      ],
                    ),
                    head('smf.docs'),
                    chips(SmartTaxonomy.docCategories.keys),
                    if (image) ...[
                      head('smf.images'),
                      chips(SmartTaxonomy.imageCategories.keys),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
