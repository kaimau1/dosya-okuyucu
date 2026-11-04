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

  static const _trashFull = AppHues.orange;

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
    // Üstte ince çizgi: kaydırılan içerik bu satırın altına "kesik" girmesin,
    // alan gezinme çubuğuyla birlikte ayrı bir taban gibi okunsun
    // (2026-11-04 kullanıcı: "alt alan olmamış görsel olarak").
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.6)),
      ),
      child: SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.sm, 6, Gap.sm, 2),
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
                          // Rozet simgenin sol üstüne: sağa taşınca etiketin
                          // ("Çöp") üstüne biniyordu.
                          alignment: AlignmentDirectional.topStart,
                          offset: const Offset(-14, -6),
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
        // Tooltip YOK: dokunmatikte uzun basma tanıyıcısı dokunuşla aynı
        // arenaya giriyordu; açılış gecikmeli hissediliyordu (2026-11-04).
        child: Semantics(
          button: true,
          label: tooltip ?? label,
          excludeSemantics: true,
          child: Material(
            color: primary ? scheme.primary : scheme.surfaceContainerHighest,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Geri bildirim + açılış anında: dalga beklemeden sayfa itilir.
              onTap: onTap,
              splashFactory: InkSplash.splashFactory,
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
