import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/smart_sort_screen.dart';
import '../../screens/fm/browser_screen.dart';
import '../../screens/fm/dashboard_screen.dart';
import '../../screens/fm/downloads_screen.dart';
import '../../screens/fm/drive_screen.dart';
import '../../screens/fm/history_screen.dart';
import '../../screens/fm/installed_apps_screen.dart';
import '../../screens/fm/library_screen.dart';
import '../../screens/fm/new_files_screen.dart';
import '../../screens/fm/open_history_screen.dart';
import '../../screens/fm/operations_screen.dart';
import '../../screens/fm/transfer_screen.dart';
import '../../screens/fm/trash_screen.dart';
import '../../screens/fm/vault_screen.dart';
import '../../services/fm/fm_env.dart';
import '../../core/edition.dart';
import '../pro_gate.dart';
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

  /// Ek düğmeler; seçilmemiş (ya da tanınmayan) yer kaplamaz.
  List<Widget> _extras(BuildContext context, List<String> ids, String side) {
    final out = <Widget>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final spec = DockExtras.spec(context, id);
      if (spec == null) continue;
      out.add(Expanded(
          child: _DockItem(
        // Drive'ın eski anahtarı korunur (testler, erişilebilirlik).
        key: ValueKey(id == 'drive' ? 'dock-drive' : 'dock-extra-$side-$i'),
        icon: spec.icon,
        label: spec.label,
        color: id == 'drive' ? null : spec.color,
        semantics: id == 'drive' ? context.t('drive.title') : null,
        proBadge: spec.proBadge,
        onTap: () => spec.open(context),
      )));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    DockExtras.ensureLoaded();
    final scaler = MediaQuery.textScalerOf(context);
    // 54 dp taban yükseklik; büyük yazı ölçeğinde (1,3×–2×) simge + etiket
    // taşmasın diye satır yüksekliği esner.
    final rowH = math.max(54.0, 34.0 + scaler.scale(16));
    return Semantics(
      hint: context.t('dock.long_press'),
      child: GestureDetector(
        onLongPress: () => showDockEditor(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.xs, Gap.xs),
          child: SizedBox(
            height: rowH,
            child: ValueListenableBuilder<(List<String>, List<String>)>(
              valueListenable: DockExtras.value,
              builder: (context, extras, _) {
                // **Düzen (2026-11-14, kullanıcı: *"her iki tarafta 3'er
                // düğme bulunabilmeli, Drive ek düğme olsun, her yana 2 ek"*):**
                // `Çöp [sol ekler]  ( Aktar )  Tara [sağ ekler]`.
                // **Simetri:** Aktar tam ortada; iki yanda eşit sayıda,
                // eşit genişlikte yuva. Bir yan eksikse boş yuva konur.
                final left = <Widget>[
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
                  ..._extras(context, extras.$1, 'left'),
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
                  ..._extras(context, extras.$2, 'right'),
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
  final bool proBadge;

  const _DockItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semantics,
    this.color,
    this.count = 0,
    this.iconWidget,
    this.proBadge = false,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (iconWidget != null)
                      IconTheme.merge(
                        data: IconThemeData(
                            size: 22, color: color ?? scheme.onSurfaceVariant),
                        child: iconWidget!,
                      )
                    else
                      Icon(icon,
                          size: 22, color: color ?? scheme.onSurfaceVariant),
                    if (count > 0)
                      PositionedDirectional(
                        top: -4,
                        end: -6,
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
                            textScaler: TextScaler.noScaling,
                            style: text?.merge(context.type.micro).copyWith(
                                height: 1.2,
                                color: scheme.surface,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else if (proBadge)
                      const PositionedDirectional(
                        top: -5,
                        end: -8,
                        child: ProBadge(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: text?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
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
    var scheme = Theme.of(context).colorScheme;
    // Koyu modda parlak vurgu yerine koyulaşmış ton (2026-11-15, bellek
    // kartıyla aynı kural: "koyu modda yeşil çok parlak").
    if (Theme.of(context).brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        primary: Color.lerp(scheme.primary, scheme.surface, 0.55),
        onPrimary: scheme.onSurface,
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
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
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.swapHoriz, size: 20, color: scheme.onPrimary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.25),
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

  const DockExtraSpec(this.icon, this.label, this.color, this.open,
      {this.proBadge = false});
  final bool proBadge;
}

/// Alt panelin **ek düğmeleri** (her yana en çok [maxPerSide]), kalıcı.
abstract final class DockExtras {
  static const _leftKeyV1 = 'dock_extra_left_v1';
  static const _rightKeyV1 = 'dock_extra_right_v1';
  static const _leftKey = 'dock_extras_left_v2';
  static const _rightKey = 'dock_extras_right_v2';

  /// Her yana en çok bu kadar ek düğme (+1 sabit: solda Çöp, sağda Tara).
  static const maxPerSide = 2;

  /// (sol, sağ). Kişisel varsayılan: solda Drive, sağda AI; Play: Kitaplık + Yer aç.
  static final value = ValueNotifier<(List<String>, List<String>)>(
      Edition.current.isPlay
          ? (const ['library'], const ['free_space'])
          : (const ['drive'], const ['ai']));
  static Future<void>? _loading;

  /// Seçilebilen düğmeler (sıra = düzenleme sayfasındaki sıra).
  static const ids = [
    'drive',
    'free_space',
    'jobs',
    'vault',
    'library',
    'history',
    'new_files',
    'opened',
    'downloads',
    'apps',
    'ai',
    'new_doc',
  ];

  static List<String> _clean(Iterable<String> raw) {
    final out = <String>[];
    for (final id in raw) {
      if (ids.contains(id) && !out.contains(id)) out.add(id);
      if (out.length == maxPerSide) break;
    }
    return out;
  }

  static Future<void> ensureLoaded() => _loading ??= () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          List<String>? readV2(String key) {
            if (!prefs.containsKey(key)) return null;
            final v = prefs.getString(key) ?? '';
            return _clean(v.split(',').where((e) => e.isNotEmpty));
          }

          final savedLeft = readV2(_leftKey);
          final savedRight = readV2(_rightKey);
          final List<String> left;
          final List<String> right;
          if (savedLeft != null && savedRight != null) {
            left = savedLeft;
            right = savedRight;
          } else {
            // v1 göçü: tek ek düğme + sabit Drive → Drive sol ek olur.
            String? v1(String key, {String? fallback}) {
              if (!prefs.containsKey(key)) return fallback;
              final v = prefs.getString(key);
              return ids.contains(v) ? v : null;
            }

            final oldLeft = v1(_leftKeyV1);
            final oldRight = v1(
              _rightKeyV1,
              fallback: Edition.current.isPlay ? 'free_space' : 'ai',
            );
            left = savedLeft ??
                _clean(Edition.current.isPlay
                    ? ['library', ?oldLeft]
                    : ['drive', ?oldLeft]);
            right = savedRight ?? _clean([?oldRight]);
          }
          value.value =
              (left, [for (final e in right) if (!left.contains(e)) e]);
        } catch (_) {
          // Bilinçli: okunamazsa varsayılan.
        }
      }();

  /// [id]'yi o yana ekler/çıkarır. Yan doluysa ekleme yapılmaz (false).
  static Future<bool> toggle({required bool left, required String id}) async {
    final cur = value.value;
    final side = [...(left ? cur.$1 : cur.$2)];
    final other = [...(left ? cur.$2 : cur.$1)];
    if (side.contains(id)) {
      side.remove(id);
    } else {
      if (side.length >= maxPerSide) return false;
      other.remove(id);
      side.add(id);
    }
    value.value = left ? (side, other) : (other, side);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_leftKey, value.value.$1.join(','));
      await prefs.setString(_rightKey, value.value.$2.join(','));
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
    return true;
  }

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Sürüm kapısı (S2): Lite'ta Pro düğmesi levhayı açar.
  static void Function(BuildContext) _g(
          Feature f, void Function(BuildContext) run) =>
      (c) => ProGate.guard(c, f, () => run(c));

  static DockExtraSpec? spec(BuildContext context, String id) => switch (id) {
        'drive' when Edition.current.has(Feature.googleDrive) => DockExtraSpec(
            AppIcons.cloud, context.t('dock.drive'),
            AppHues.blue, (c) => _push(c, const DriveScreen())),
        'free_space' => DockExtraSpec(
            AppIcons.cleanEmpty,
            context.t('dock.free_space'),
            AppHues.cyan,
            _g(Feature.cleanup,
                (c) => OperationsScreen.open(c, tab: OpsTab.cleanup))),
        'jobs' => DockExtraSpec(AppIcons.playlistAddCheckCircle,
            context.t('dock.jobs'), AppHues.green,
            _g(Feature.fileManager, OperationsScreen.open)),
        'vault' => DockExtraSpec(AppIcons.vault, context.t('dock.vault'),
            AppHues.slate,
            _g(Feature.vault, (c) => _push(c, const VaultScreen()))),
        'library' => DockExtraSpec(AppIcons.autoStories,
            context.t('dock.library'), AppHues.plum,
            (c) => _push(c, const LibraryScreen())),
        'history' => DockExtraSpec(AppIcons.history,
            context.t('dock.history'), AppHues.indigo, HistoryScreen.open),
        // Kullanıcı 2026-11-20: "alt panele yeni dosyalar ve geçmiş de
        // eklenebilir olmalı".
        'new_files' => DockExtraSpec(AppIcons.moveToInbox,
            context.t('ui.dock_new'), AppHues.tangerine,
            (c) => _push(c, const NewFilesScreen())),
        'opened' => DockExtraSpec(AppIcons.history,
            context.t('ui.dock_opened'), AppHues.royal,
            (c) => _push(c, const OpenHistoryScreen())),
        'downloads' => DockExtraSpec(
            AppIcons.download, context.t('dock.downloads'), AppHues.blue,
            _g(Feature.fileManager, (c) {
            final path =
                downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot;
            Navigator.of(c).push(browserRoute(BrowserScreen(path: path)));
          })),
        'apps' when Edition.current.has(Feature.installedApps) => DockExtraSpec(AppIcons.android, context.t('dock.apps'),
            AppHues.green, (c) => _push(c, const InstalledAppsScreen())),
        'ai' => DockExtraSpec(
            AppIcons.ai,
            context.t('dock.ai'),
            AppHues.violet,
            _g(Feature.smartFolders, (c) => _push(c, const SmartSortScreen())),
            proBadge: ProGate.locked(Feature.smartFolders),
          ),
        'new_doc' => DockExtraSpec(AppIcons.noteAdd, context.t('dock.new_doc'),
            AppHues.blue, _g(Feature.officeEdit, showNewDocumentSheet)),
        _ => null,
      };
}

/// "Alt paneli düzenle" sayfası: sol ve sağ ek düğmeler (her yana en çok 2).
Future<void> showDockEditor(BuildContext context) async {
  await DockExtras.ensureLoaded();
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    title: context.t('dock.edit_title'),
    builder: (context) =>
        ValueListenableBuilder<(List<String>, List<String>)>(
      valueListenable: DockExtras.value,
      builder: (context, extras, _) {
        final theme = Theme.of(context);
        Widget side(bool left) {
          final current = left ? extras.$1 : extras.$2;
          final other = left ? extras.$2 : extras.$1;
          final full = current.length >= DockExtras.maxPerSide;
          return Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final id in DockExtras.ids)
                if (!other.contains(id))
                  if (DockExtras.spec(context, id) case final spec?)
                    FilterChip(
                      key: ValueKey('dock-chip-${left ? 'l' : 'r'}-$id'),
                      avatar: Icon(spec.icon, size: 18, color: spec.color),
                      label: Text(spec.label),
                      selected: current.contains(id),
                      showCheckmark: false,
                      onSelected: full && !current.contains(id)
                          ? null
                          : (_) => DockExtras.toggle(left: left, id: id),
                    ),
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
                Text(
                    '${context.t('dock.extra_left')} · '
                    '${extras.$1.length}/${DockExtras.maxPerSide}',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.sm),
                side(true),
                const SizedBox(height: Gap.md),
                Text(
                    '${context.t('dock.extra_right')} · '
                    '${extras.$2.length}/${DockExtras.maxPerSide}',
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
