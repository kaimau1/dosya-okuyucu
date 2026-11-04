import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/dashboard_screen.dart';
import '../../screens/fm/drive_screen.dart';
import '../../screens/fm/transfer_screen.dart';
import '../../screens/fm/trash_screen.dart';
import '../../services/fm/fm_env.dart';
import '../scan_flow.dart';

/// **Alt çubuğun hızlı sırası** (2026-11-04, kullanıcı: *"alt kısımdaki hızlı
/// erişim satırı ile yüzen erişim butonlarını tek alanda birleştirelim; alt
/// hızlı erişimde çöp ve aktar mutlaka olsun, 2 satır olsun ama yüksekliği çok
/// olmasın; Drive'ı da oraya al"*).
///
/// Eskiden sağ altta içeriğin ÜSTÜNDE yüzen bir kapsül vardı (çöp · aktar |
/// tara) ve kutu ızgarasının son satırını örtüyordu. Artık gezinme çubuğuyla
/// AYNI yüzeyde, onun hemen üstünde ince (40 dp) tek satır: Çöp · Aktar ·
/// Drive · Tara. Yalnız pano sekmesinde çizilir (yüzen kapsül de oradaydı).
class HomeQuickRow extends StatelessWidget {
  const HomeQuickRow({super.key});

  static const _trashFull = Color(0xFFE65100);

  Future<void> _openTrash(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TrashScreen()));
    // Çöp kutusunda boşaltma/geri yükleme olduysa rozet tazelensin.
    try {
      DashboardScreen.trashCount.value = (await FmEnv.trash.list()).length;
    } catch (_) {
      // Bilinçli: rozet bir sonraki pano taramasında düzelir.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
        child: Row(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: DashboardScreen.trashCount,
              builder: (context, n, _) {
                final full = n > 0;
                final icon = Icon(AppIcons.delete,
                    size: 20,
                    color: full ? _trashFull : scheme.onSurfaceVariant);
                return _QuickItem(
                  key: const ValueKey('dock-trash'),
                  icon: full
                      ? Badge(
                          label: Text(n > 99 ? '99+' : '$n'),
                          backgroundColor: _trashFull,
                          child: icon,
                        )
                      : icon,
                  label: context.t('dock.trash'),
                  tooltip: full
                      ? '${context.t('fm.trash')} · '
                          '${context.t('fm.trash_count', {'n': n})}'
                      : context.t('fm.trash'),
                  onTap: () => _openTrash(context),
                );
              },
            ),
            _QuickItem(
              key: const ValueKey('dock-transfer'),
              icon: Icon(AppIcons.swapHoriz,
                  size: 20, color: scheme.onSurfaceVariant),
              label: context.t('xfer.title'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransferScreen())),
            ),
            _QuickItem(
              key: const ValueKey('dock-drive'),
              icon: Icon(AppIcons.cloud,
                  size: 20, color: scheme.onSurfaceVariant),
              label: context.t('dock.drive'),
              tooltip: context.t('drive.title'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DriveScreen())),
            ),
            _QuickItem(
              key: const ValueKey('dock-scan'),
              primary: true,
              icon: Icon(AppIcons.ocr, size: 20, color: scheme.onPrimary),
              label: context.t('dock.scan'),
              tooltip: context.t('fm.scan_document'),
              onTap: () => ScanFlow.run(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  final bool primary;

  const _QuickItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = primary ? scheme.onPrimary : scheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Tooltip(
          message: tooltip ?? label,
          child: Material(
            color: primary ? scheme.primary : scheme.surfaceContainerHighest,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: fg, fontWeight: FontWeight.w600),
                    ),
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
