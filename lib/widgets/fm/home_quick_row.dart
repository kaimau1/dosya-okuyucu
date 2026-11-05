import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/ai_hub_screen.dart';
import '../../screens/fm/browser_screen.dart';
import '../../screens/fm/dashboard_screen.dart';
import 'ai_status_icon.dart';
import '../../screens/fm/downloads_screen.dart';
import '../../screens/fm/drive_screen.dart';
import '../../screens/fm/history_screen.dart';
import '../../screens/fm/installed_apps_screen.dart';
import '../../screens/fm/library_screen.dart';
import '../../screens/fm/operations_screen.dart';
import '../../screens/fm/transfer_screen.dart';
import '../../screens/fm/trash_screen.dart';
import '../../screens/fm/vault_screen.dart';
import '../../services/fm/fm_env.dart';
import '../app_dialog.dart';
import '../new_document_sheet.dart';
import '../scan_flow.dart';

/// **Alt panel** (2026-11-04, üçüncü tasarım — kullanıcı: *"alt panelde
/// aktar, çöp kutusu, drive, tara kalacak; örnek resimdeki gibi ama daha az
/// yer kaplayan bir panel; isteğe göre kişiler ek 2 buton daha ekleyebilir,
/// bir sağa bir sola, isimleri yazacak"*).
///
/// Düzen: `[sol ek] Çöp · Drive  ( Aktar )  Tara [sağ ek]`
/// - **Aktar** ortada tek vurgulu kapsül (en sık "dışarıyla" iş),
/// - öbürleri simge + altında küçük ad; çöp doluysa simgenin köşesinde sayı,
/// - ek düğmeler [DockExtras]'tan (Yer aç, İşlemler, Kasa, Kitaplık…);
///   panele **basılı tutunca** düzenleme sayfası açılır.
/// Yükseklik 52 dp (önceki iki parçalı sıra ~56 dp'ydi).
class HomeQuickRow extends StatelessWidget {
  const HomeQuickRow({super.key});

  static const _trashFull = AppHues.orange;

  Future<void> _openTrash(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TrashScreen()));
    // Çöp kutusunda boşaltma/geri yükleme olduysa sayı tazelensin.
    try {
      DashboardScreen.trashCount.value = (await FmEnv.trash.list()).length;
    } catch (_) {
      // Bilinçli: sayı bir sonraki pano taramasında düzelir.
    }
  }

  /// Ek düğme; seçilmemişse (ya da tanınmıyorsa) hiç yer kaplamaz.
  List<Widget> _extra(BuildContext context, String? id, String side) {
    final spec = id == null ? null : DockExtras.spec(context, id);
    if (spec == null) return const [];
    return [
      Expanded(
          child: _DockItem(
      key: ValueKey('dock-extra-$side'),
      icon: spec.icon,
      label: spec.label,
      color: spec.color,
      // AI Merkezi üst çubuktan buraya taşındı (2026-11-05): durum simgesi
      // (analiz halkası, öneri noktası) onunla geldi.
      iconWidget: id == 'ai' ? const AiStatusIcon(dot: true) : null,
      onTap: () => spec.open(context),
    )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    DockExtras.ensureLoaded();
    return Semantics(
      hint: context.t('dock.long_press'),
      child: GestureDetector(
        onLongPress: () => showDockEditor(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs + 2, Gap.sm, Gap.xs),
          child: SizedBox(
            height: 52,
            child: ValueListenableBuilder<(String?, String?)>(
              valueListenable: DockExtras.value,
              builder: (context, extras, _) {
                // **Simetri:** Aktar tam ortada; iki yanda eşit sayıda,
                // eşit genişlikte yuva. Bir yan eksikse boş yuva konur —
                // yoksa Aktar kayıyor, öğeler düzensiz aralanıyordu.
                final left = <Widget>[
                  ..._extra(context, extras.$1, 'left'),
                  Expanded(
                      child: ValueListenableBuilder<int>(
                    valueListenable: DashboardScreen.trashCount,
                    builder: (context, n, _) => _DockItem(
                      key: const ValueKey('dock-trash'),
                      icon: AppIcons.delete,
                      label: context.t('dock.trash'),
                      semantics: n > 0
                          ? '${context.t('fm.trash')} · '
                              '${context.t('fm.trash_count', {'n': n})}'
                          : context.t('fm.trash'),
                      color: n > 0 ? _trashFull : null,
                      count: n,
                      onTap: () => _openTrash(context),
                    ),
                  )),
                  Expanded(
                      child: _DockItem(
                    key: const ValueKey('dock-drive'),
                    icon: AppIcons.cloud,
                    label: context.t('dock.drive'),
                    semantics: context.t('drive.title'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DriveScreen())),
                  )),
                ];
                final right = <Widget>[
                  Expanded(
                      child: _DockItem(
                    key: const ValueKey('dock-scan'),
                    icon: AppIcons.ocr,
                    label: context.t('dock.scan'),
                    semantics: context.t('fm.scan_document'),
                    onTap: () => ScanFlow.run(context),
                  )),
                  ..._extra(context, extras.$2, 'right'),
                ];
                while (right.length < left.length) {
                  right.add(const Spacer());
                }
                while (left.length < right.length) {
                  left.insert(0, const Spacer());
                }
                return Row(
                  children: [
                    Expanded(flex: left.length, child: Row(children: left)),
                    _TransferButton(
                      key: const ValueKey('dock-transfer'),
                      label: context.t('xfer.title'),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TransferScreen())),
                    ),
                    Expanded(flex: right.length, child: Row(children: right)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Simge + altında küçük ad. Tooltip YOK: dokunmatikte uzun basma tanıyıcısı
/// dokunuşla aynı arenaya giriyordu (2026-11-04).
class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? semantics;
  final VoidCallback onTap;
  final Color? color;
  final int count;

  /// Düz simge yerine canlı simge (AI: analiz halkası / öneri noktası).
  final Widget? iconWidget;

  const _DockItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semantics,
    this.color,
    this.count = 0,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      button: true,
      label: semantics ?? label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        splashFactory: InkSplash.splashFactory,
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (iconWidget != null)
                    IconTheme.merge(
                      data: IconThemeData(
                          size: 22, color: color ?? scheme.onSurfaceVariant),
                      child: iconWidget!,
                    )
                  else
                    Icon(icon, size: 22, color: color ?? scheme.onSurfaceVariant),
                  if (count > 0)
                    PositionedDirectional(
                      top: -5,
                      start: 13,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: color ?? scheme.error,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: scheme.surfaceContainer, width: 1.5),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: text?.merge(context.type.micro).copyWith(
                              height: 1.2,
                              color: scheme.surface,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ortadaki vurgulu **Aktar** kapsülü: degradeli, hafif gölgeli.
class _TransferButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TransferButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: Gap.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(scheme.primary, AppColors.mixLight, 0.12)!,
              Color.lerp(scheme.primary, AppColors.mixDark, 0.12)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            splashFactory: InkSplash.splashFactory,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md + 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.swapHoriz, size: 20, color: scheme.onPrimary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ek düğmenin tarifi.
class DockExtraSpec {
  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext context) open;

  const DockExtraSpec(this.icon, this.label, this.color, this.open);
}

/// Alt panelin **isteğe bağlı iki ek düğmesi** (sol + sağ), kalıcı.
abstract final class DockExtras {
  static const _leftKey = 'dock_extra_left_v1';
  static const _rightKey = 'dock_extra_right_v1';

  /// (sol, sağ) — null = yok. Sağ varsayılan **AI** (2026-11-05, kullanıcı:
  /// AI düğmesi üst panelden alta, "Yer aç"ın yerine). "Yer aç" seçilebilir
  /// kalır (uzun bas → alt paneli düzenle).
  static final value =
      ValueNotifier<(String?, String?)>((null, 'ai'));
  static Future<void>? _loading;

  /// Seçilebilen düğmeler (sıra = düzenleme sayfasındaki sıra).
  static const ids = [
    'free_space',
    'jobs',
    'vault',
    'library',
    'history',
    'downloads',
    'apps',
    'ai',
    'new_doc',
  ];

  static Future<void> ensureLoaded() => _loading ??= () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          String? read(String key, {String? fallback}) {
            // Hiç seçilmemişse varsayılan; "yok" seçimi '' diye saklanır.
            if (!prefs.containsKey(key)) return fallback;
            final v = prefs.getString(key);
            return ids.contains(v) ? v : null;
          }

          value.value =
              (read(_leftKey), read(_rightKey, fallback: 'ai'));
        } catch (_) {
          // Bilinçli: okunamazsa ek düğme yok.
        }
      }();

  static Future<void> set({required bool left, String? id}) async {
    final cur = value.value;
    value.value = left ? (id, cur.$2) : (cur.$1, id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = left ? _leftKey : _rightKey;
      if (id == null) {
        await prefs.setString(key, '');
      } else {
        await prefs.setString(key, id);
      }
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
  }

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  static DockExtraSpec? spec(BuildContext context, String id) => switch (id) {
        'free_space' => DockExtraSpec(
            AppIcons.cleanEmpty,
            context.t('dock.free_space'),
            AppHues.cyan,
            (c) => OperationsScreen.open(c, tab: OpsTab.cleanup)),
        'jobs' => DockExtraSpec(AppIcons.playlistAddCheckCircle,
            context.t('dock.jobs'), AppHues.green, OperationsScreen.open),
        'vault' => DockExtraSpec(AppIcons.vault, context.t('dock.vault'),
            AppHues.slate, (c) => _push(c, const VaultScreen())),
        'library' => DockExtraSpec(AppIcons.autoStories,
            context.t('dock.library'), AppHues.plum,
            (c) => _push(c, const LibraryScreen())),
        'history' => DockExtraSpec(AppIcons.history,
            context.t('dock.history'), AppHues.indigo, HistoryScreen.open),
        'downloads' => DockExtraSpec(
            AppIcons.download, context.t('dock.downloads'), AppHues.blue, (c) {
            final path =
                downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot;
            Navigator.of(c).push(browserRoute(BrowserScreen(path: path)));
          }),
        'apps' => DockExtraSpec(AppIcons.android, context.t('dock.apps'),
            AppHues.green, (c) => _push(c, const InstalledAppsScreen())),
        'ai' => DockExtraSpec(AppIcons.ai, context.t('dock.ai'),
            AppHues.violet, (c) => _push(c, const AiHubScreen())),
        'new_doc' => DockExtraSpec(AppIcons.noteAdd, context.t('dock.new_doc'),
            AppHues.blue, showNewDocumentSheet),
        _ => null,
      };
}

/// "Alt paneli düzenle" sayfası: sol ve sağ ek düğme seçimi.
Future<void> showDockEditor(BuildContext context) async {
  await DockExtras.ensureLoaded();
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    title: context.t('dock.edit_title'),
    builder: (context) => ValueListenableBuilder<(String?, String?)>(
      valueListenable: DockExtras.value,
      builder: (context, extras, _) {
        final theme = Theme.of(context);
        Widget side(bool left) {
          final current = left ? extras.$1 : extras.$2;
          final other = left ? extras.$2 : extras.$1;
          return Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              ChoiceChip(
                label: Text(context.t('dock.none')),
                selected: current == null,
                onSelected: (_) => DockExtras.set(left: left),
              ),
              for (final id in DockExtras.ids)
                if (id != other)
                  () {
                    final spec = DockExtras.spec(context, id)!;
                    return ChoiceChip(
                      avatar: Icon(spec.icon, size: 18, color: spec.color),
                      label: Text(spec.label),
                      selected: current == id,
                      onSelected: (_) => DockExtras.set(left: left, id: id),
                    );
                  }(),
            ],
          );
        }

        return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('dock.edit_body'),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: Gap.md),
                Text(context.t('dock.extra_left'),
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.sm),
                side(true),
                const SizedBox(height: Gap.md),
                Text(context.t('dock.extra_right'),
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.sm),
                side(false),
              ],
            ),
        );
      },
    ),
  );
}

/// Gezinme çubuğu + (panoda) hızlı sıra için ortak taban: tek renk, üst
/// köşeler yuvarlak, üstünde yumuşak bir gölge (tek kenarlı çizgi
/// yuvarlak köşeyle birlikte çizilemiyor — Flutter tek tip kenarlık ister). Her sekmede aynı görünür.
class BottomDock extends StatelessWidget {
  final List<Widget> children;

  const BottomDock({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.vertical(top: Radius.circular(Radii.sheet - 4));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
