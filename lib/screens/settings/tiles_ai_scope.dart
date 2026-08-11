/// **AI analiz kapsamı ayarları** — "nereye bakma, ne gönderme".
///
/// KÖK NEDEN (2026-08-10 kullanıcı): *"kapsama girmeyecek klasörleri ve
/// filtreleri (mesela kamera klasörü) seçilebilmeli, kameram ile çektiğim
/// fotoğraflara erişmesini istemiyorum."*
///
/// Bu yüzden kapsam ayarı AI kategorisinin **ilk** bölümüdür, gömülü bir alt
/// menüde değil: kullanıcının analizi başlatmadan önce göreceği ilk şey neyin
/// dışarıda olduğudur. Bir klasör listeden çıkarıldığında o klasörün eski
/// analiz kayıtları da silinir ([AiIndex.dropOutOfScope]) — "artık bakma"
/// dendiğinde geçmişin de unutulması gerekir.
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_index.dart';
import '../fm/folder_picker_screen.dart';
import 'settings_widgets.dart';

/// Kapsam dışı klasörler — ekle/çıkar.
class AiExcludedFoldersTile extends StatelessWidget {
  const AiExcludedFoldersTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final excluded = state.aiScope.excludedFolders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTile(
          icon: Icons.folder_off_outlined,
          title: context.t('aiset.excluded'),
          subtitle: context.t('aiset.excluded_sub'),
          wrapSubtitle: true,
          value: '${excluded.length}',
        ),
        for (final path in excluded)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 56, right: Gap.sm),
            leading: null,
            title: Text(p.basename(path), maxLines: 1),
            subtitle: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Paper.faint(context)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.t('aiset.include_again'),
              onPressed: () => _remove(context, path),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 56, bottom: Gap.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(context.t('aiset.exclude_add')),
              onPressed: () => _add(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = context.read<AppState>();
    final label = context.t('aiset.exclude_pick');
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: const [],
          actionLabel: label,
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final current = [...state.aiScope.excludedFolders];
    if (current.contains(picked)) return;
    current.add(picked);
    await state.setAiScope(state.aiScope.copyWith(excludedFolders: current));
    // Kapsam daraldı: bu klasörün eski analizi de unutulmalı.
    final rules = state.aiScopeRules;
    await AiIndex.dropOutOfScope((path) => rules.allowsDir(p.dirname(path)));
  }

  Future<void> _remove(BuildContext context, String path) async {
    final state = context.read<AppState>();
    final current = [...state.aiScope.excludedFolders]..remove(path);
    await state.setAiScope(state.aiScope.copyWith(excludedFolders: current));
  }
}

/// Hangi dosya türleri analiz edilsin?
class AiScopeTypesTile extends StatelessWidget {
  const AiScopeTypesTile({super.key});

  /// Kullanıcının seçebildiği türler. `apk`/`other`/`folder` listede yok:
  /// birinin "özeti" olmaz, diğeri tanımadığımız her şey.
  static const _selectable = [
    FmCategory.document,
    FmCategory.image,
    FmCategory.video,
    FmCategory.audio,
    FmCategory.archive,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.aiScope.categories;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('aiset.types')),
                    Text(
                      context.t('aiset.types_sub'),
                      style: TextStyle(
                          fontSize: 12, color: Paper.faint(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final category in _selectable)
                FilterChip(
                  label: Text(context.t(category.labelKey)),
                  selected: selected.contains(category),
                  onSelected: (on) {
                    final next = {...selected};
                    if (on) {
                      next.add(category);
                    } else {
                      next.remove(category);
                    }
                    // Hepsi kapatılırsa analiz hiçbir şey bulamaz; en az bir
                    // tür açık kalsın (sessiz "hiçbir şey olmuyor" hatası).
                    if (next.isEmpty) return;
                    context
                        .read<AppState>()
                        .setAiScope(state.aiScope.copyWith(categories: next));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Buluta ne gider: metin özü / görsel / gizli dosyalar.
class AiPrivacyTile extends StatelessWidget {
  const AiPrivacyTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scope = state.aiScope;
    return Column(
      children: [
        SettingSwitch(
          icon: Icons.notes_outlined,
          title: context.t('aiset.send_text'),
          subtitle: context.t('aiset.send_text_sub', {'kb': scope.excerptKb}),
          value: scope.sendText,
          onChanged: (v) =>
              context.read<AppState>().setAiScope(scope.copyWith(sendText: v)),
        ),
        SettingSwitch(
          icon: Icons.image_outlined,
          title: context.t('aiset.send_images'),
          subtitle: context.t('aiset.send_images_sub'),
          value: scope.sendImages,
          onChanged: (v) => context
              .read<AppState>()
              .setAiScope(scope.copyWith(sendImages: v)),
        ),
        SettingSwitch(
          icon: Icons.visibility_off_outlined,
          title: context.t('aiset.hidden'),
          subtitle: context.t('aiset.hidden_sub'),
          value: scope.includeHidden,
          onChanged: (v) => context
              .read<AppState>()
              .setAiScope(scope.copyWith(includeHidden: v)),
        ),
        SettingChoice<int>(
          icon: Icons.data_usage_outlined,
          title: context.t('aiset.excerpt'),
          subtitle: context.t('aiset.excerpt_sub'),
          options: const [(2, '2 KB'), (6, '6 KB'), (12, '12 KB')],
          selected: _nearest(scope.excerptKb),
          onChanged: (v) =>
              context.read<AppState>().setAiScope(scope.copyWith(excerptKb: v)),
        ),
      ],
    );
  }

  /// Kayıtlı değer seçeneklerden biri değilse (eski sürüm/elle düzenleme)
  /// SegmentedButton "seçili değer listede yok" diye patlar.
  static int _nearest(int kb) {
    if (kb <= 3) return 2;
    if (kb <= 8) return 6;
    return 12;
  }
}

/// Günlük dosya bütçesi + AI belleğini temizleme.
class AiBudgetTile extends StatelessWidget {
  const AiBudgetTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scope = state.aiScope;
    return Column(
      children: [
        SettingChoice<int>(
          icon: Icons.speed_outlined,
          title: context.t('aiset.budget'),
          subtitle: context.t('aiset.budget_sub'),
          // **Varsayılan sınırsız** (kullanıcı 2026-08-10: *"anahtarımda hâlâ
          // kotam var, sınır koymasın"*). Gerçek kotayı havuz ölçüyor; buradaki
          // sayaç yalnız kendi isteğiyle sınır koymak isteyen için.
          options: [(0, context.t('aiset.budget_unlimited')), (400, '400'), (1000, '1000')],
          selected: _nearest(scope.dailyFileBudget),
          onChanged: (v) => context
              .read<AppState>()
              .setAiScope(scope.copyWith(dailyFileBudget: v)),
        ),
        ValueListenableBuilder<int>(
          valueListenable: AiIndex.revision,
          builder: (context, _, __) => SettingTile(
            icon: Icons.delete_sweep_outlined,
            title: context.t('aiset.forget'),
            subtitle: context.t('aiset.forget_sub'),
            wrapSubtitle: true,
            value: '${AiIndex.count}',
            onTap: () => _confirmForget(context),
          ),
        ),
      ],
    );
  }

  static int _nearest(int budget) {
    if (budget <= 0) return 0;
    if (budget <= 700) return 400;
    return 1000;
  }

  Future<void> _confirmForget(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('aiset.forget')),
        content: Text(ctx.t('aiset.forget_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok == true) await AiIndex.clear();
  }
}
