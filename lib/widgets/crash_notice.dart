import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../screens/settings/crash_log_screen.dart';
import '../services/crash_log.dart';

/// **Çökmeden sonra panoda görünen tek satırlık uyarı.**
///
/// Kök neden (2026-08-28): hata kaydını eklemek tek başına geri bildirim
/// döngüsü kurmuyor — kimse kendiliğinden Ayarlar > Hakkında > Hata
/// kayıtları'na bakmaz, dolayısıyla rapor bize hiç ulaşmazdı. Uygulama bir
/// çökmenin ARDINDAN açıldığında bu satır bir kez görünür; kullanıcı ya
/// raporu açar (ve isterse paylaşır) ya da kapatır.
///
/// Gösterilme kuralları bilinçli olarak dar:
/// - Yalnız **görülmemiş** kayıt varsa (işaret `CrashLog.markSeen`).
/// - Kapatınca ya da raporu açınca bir daha görünmez (yeni çökmeye kadar).
/// - Kayıt okunurken hiçbir şey çizilmez — açılışta yanıp sönen bir şerit
///   olmaz.
class CrashNoticeBanner extends StatefulWidget {
  const CrashNoticeBanner({super.key});

  @override
  State<CrashNoticeBanner> createState() => _CrashNoticeBannerState();
}

class _CrashNoticeBannerState extends State<CrashNoticeBanner> {
  int _unseen = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final count = await CrashLog.unseenCount();
    if (mounted) setState(() => _unseen = count);
  }

  Future<void> _open() async {
    await CrashLog.markSeen();
    if (!mounted) return;
    setState(() => _dismissed = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CrashLogScreen()),
    );
  }

  Future<void> _dismiss() async {
    await CrashLog.markSeen();
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _unseen == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Material(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
            child: Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    context.t('crash.notice', {'n': _unseen}),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  tooltip: context.t('common.close'),
                  icon: Icon(Icons.close,
                      size: 18, color: theme.colorScheme.onErrorContainer),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
