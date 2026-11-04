import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/dashboard_screen.dart';
import '../../screens/fm/drive_screen.dart';
import '../../screens/fm/transfer_screen.dart';
import '../../screens/fm/trash_screen.dart';
import '../../services/fm/fm_env.dart';
import '../scan_flow.dart';

/// **Alt taban** (2026-11-04, ikinci tasarım — kullanıcı: *"alt o 2 satırı
/// tamamen baştan tasarla, butonların yeri değişebilir, görsel birlik
/// olsun"*).
///
/// Hızlı eylemler ile gezinme çubuğu TEK yüzeyde ([BottomDock]): üst köşeleri
/// yuvarlak, üstünde ince çizgi olan bir "taban". İlk sürümde dört ayrı gri
/// hap + ayrı bir çubuk iki ayrı parça gibi duruyordu. Artık:
/// - Çöp · Aktar · Drive tek bölmeli grup (aralarında ince ayırıcı),
/// - Tara sağda tek vurgulu eylem (gezinme göstergesiyle aynı renk ailesi),
/// - çöp sayısı simgeye binen rozet değil, etiketin yanında küçük sayı.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md - 4, Gap.sm + 2, Gap.md - 4, 2),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control + 3),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: DashboardScreen.trashCount,
                      builder: (context, n, _) => _Segment(
                        key: const ValueKey('dock-trash'),
                        icon: AppIcons.delete,
                        label: context.t('dock.trash'),
                        semantics: n > 0
                            ? '${context.t('fm.trash')} · '
                                '${context.t('fm.trash_count', {'n': n})}'
                            : context.t('fm.trash'),
                        count: n,
                        countColor: _trashFull,
                        onTap: () => _openTrash(context),
                      ),
                    ),
                    const _SegmentDivider(),
                    _Segment(
                      key: const ValueKey('dock-transfer'),
                      icon: AppIcons.swapHoriz,
                      label: context.t('xfer.title'),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TransferScreen())),
                    ),
                    const _SegmentDivider(),
                    _Segment(
                      key: const ValueKey('dock-drive'),
                      icon: AppIcons.cloud,
                      label: context.t('dock.drive'),
                      semantics: context.t('drive.title'),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DriveScreen())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            _ScanButton(
              key: const ValueKey('dock-scan'),
              label: context.t('dock.scan'),
              semantics: context.t('fm.scan_document'),
              onTap: () => ScanFlow.run(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentDivider extends StatelessWidget {
  const _SegmentDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 20,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      );
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? semantics;
  final VoidCallback onTap;
  final int count;
  final Color? countColor;

  const _Segment({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semantics,
    this.count = 0,
    this.countColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelMedium;
    final full = count > 0;
    return Expanded(
      // Tooltip YOK: dokunmatikte uzun basma tanıyıcısı dokunuşla aynı
      // arenaya giriyordu (2026-11-04).
      child: Semantics(
        button: true,
        label: semantics ?? label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          splashFactory: InkSplash.splashFactory,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: full ? countColor : scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text?.copyWith(
                      color: scheme.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
              if (full) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: countColor,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.surface,
                        height: 1.2,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final String label;
  final String semantics;
  final VoidCallback onTap;

  const _ScanButton({
    super.key,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(Radii.control + 3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: InkSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.ocr, size: 18, color: scheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
