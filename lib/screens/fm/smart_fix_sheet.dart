import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_bench.dart';
import '../../services/fm/smart_learn.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_input.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../services/gemini_decisions.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/smart_cat_style.dart';

/// **"Bu yanlış olmuş" → "Ne olmalıydı?"** (2026-11-18, kullanıcı: *"akıllı
/// düzende öğrenme de olmalı; kişi bu yanlış olmuş dediğinde ne olmalıydı
/// sorusu ve öğrenme algoritması olmalı"*).
///
/// Akış: doğru kategori seçilir → kayıt elle düzeltilmiş olur (bir daha
/// sorulmaz) → düzeltme [SmartLearn]'e yazılır (benzer dosyada aynı hata
/// yapılmaz, modele geri bildirim) → aynı yanlışla düzenlenmiş BENZER dosyalar
/// varsa "onlar da düzeltilsin mi?" diye sorulur. "Aslında doğru" da öğrenilir
/// (yanlış genellemeyi frenler).
///
/// Dosya değiştiyse true.
Future<bool> showSmartFix(BuildContext context, String path) async {
  await SmartSort.ensureLoaded();
  if (!context.mounted) return false;
  final from = SmartSort.of(path)?.cat;
  final image = GeminiDecisions.mediaFor(path)?.type == 'image';
  final kind = SmartSortInput.kindOf(path);
  final av = kind == SmartInputKind.audio || kind == SmartInputKind.video;
  final chosen = await showAppSheet<String>(
    context,
    scrollable: false,
    builder: (_) => SmartFixSheet(
        current: from, image: image, av: av, name: p.basename(path)),
  );
  if (chosen == null || !context.mounted) return false;
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final label = SmartCatStyle.label(context, chosen);
  if (from != null) await SmartLearn.record(path, from, chosen);
  await SmartSort.correct(path, chosen);
  if (chosen == from) {
    showSnackOn(messenger, s.t('smf.kept'));
    return false;
  }
  // B2: model yanlışı doğruluk tezgâhına örnek olur (yalnız kategori puanlanır;
  // elle etiketlenmiş tezgâh öğesi ezilmez, dolu tezgâha eklenmez).
  if (from != null) await _benchSample(path, chosen);
  var also = 0;
  if (from != null && context.mounted) {
    final candidates = {
      for (final r in SmartSort.records)
        if (!r.user && !r.hidden) r.path: r.cat,
    };
    final similar = SmartLearn.similar(path, from, candidates);
    if (similar.isNotEmpty && context.mounted) {
      final ok = await showAppConfirm(
        context,
        title: s.t('smf.similar_title'),
        message: s.t('smf.similar_body', {
          'n': similar.length,
          'from': SmartCatStyle.label(context, from),
          'to': label,
        }),
        confirmLabel: s.t('smf.similar_go'),
      );
      if (ok) {
        await SmartSort.correctAll(similar, chosen);
        also = similar.length;
      }
    }
  }
  showSnackOn(
      messenger,
      also > 0
          ? s.t('smf.learned_n', {'cat': label, 'n': also})
          : s.t('smf.learned', {'cat': label}));
  return true;
}

Future<void> _benchSample(String path, String cat) async {
  await SmartBench.ensureLoaded();
  if (SmartBench.of(path) != null) return;
  final stat = await FsScan.statPaths([path]);
  if (stat.isEmpty) return;
  await SmartBench.put(SmartBenchItem(
    path: path,
    size: stat.first.sizeBytes,
    modifiedMs: stat.first.modifiedMs,
    cat: cat,
  ));
}

class SmartFixSheet extends StatelessWidget {
  /// Şimdiki kategori (yoksa null: hiç düzenlenmemiş).
  final String? current;
  final bool image;
  final bool av;
  final String name;

  const SmartFixSheet({
    super.key,
    required this.current,
    required this.image,
    this.av = false,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cur = current;
    Widget chips(Iterable<String> cats) => Wrap(
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: [
            for (final c in cats)
              ChoiceChip(
                key: ValueKey('smf-$c'),
                selected: c == cur,
                avatar: c == cur
                    ? null
                    : Icon(SmartCatStyle.icon(c),
                        size: 18, color: SmartCatStyle.color(c)),
                label: Text(SmartCatStyle.label(context, c)),
                onSelected: (_) => Navigator.pop(context, c),
              ),
          ],
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
              leading: const Icon(AppIcons.ai),
              title: Text(context.t('smf.title')),
              subtitle: Text(
                cur == null
                    ? name
                    : context.t(
                        'smf.now', {'cat': SmartCatStyle.label(context, cur)}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text(context.t('smf.body'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: Gap.sm),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('smf.docs'),
                        style: theme.textTheme.labelLarge),
                    const SizedBox(height: Gap.xs),
                    chips(SmartTaxonomy.docCategories.keys),
                    if (image) ...[
                      const SizedBox(height: Gap.md),
                      Text(context.t('smf.images'),
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: Gap.xs),
                      chips(SmartTaxonomy.imageCategories.keys),
                    ],
                    if (av ||
                        cur == SmartTaxonomy.music ||
                        cur == SmartTaxonomy.audio ||
                        cur == SmartTaxonomy.video) ...[
                      const SizedBox(height: Gap.md),
                      Text(context.t('smf.media'),
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: Gap.xs),
                      chips(const [
                        SmartTaxonomy.music,
                        SmartTaxonomy.audio,
                        SmartTaxonomy.video,
                      ]),
                    ],
                    const SizedBox(height: Gap.md),
                    chips(const [SmartTaxonomy.other]),
                  ],
                ),
              ),
            ),
            if (cur != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: TextButton.icon(
                  key: const ValueKey('smf-keep'),
                  onPressed: () => Navigator.pop(context, cur),
                  icon: const Icon(AppIcons.check),
                  label: Text(context.t('smf.was_right')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
