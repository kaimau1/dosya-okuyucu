import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../services/app_update.dart';

/// **Ana sayfadaki kalıcı "Yeni sürüm var" uyarısı** (2026-11-10, kullanıcı:
/// *"yeni güncelleme gelince ana sayfada otomatik algılasın, kalıcı uyarı
/// görülsün, tıklayınca indirsin kursun"*).
///
/// Açılışta ve uygulama öne geldikçe [AppUpdate.detect] (30 dk sınırlı)
/// GitHub'a sorar; yeni sürüm varsa kapatma düğmesi OLMAYAN şerit çıkar.
/// Dokununca inmediyse iner (yüzde çubuğu), sonra sistem kurucusu açılır.
/// Sürüm kurulunca uygulama yeniden başlar ve şerit kendiliğinden kalkar.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppUpdate.detect());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(AppUpdate.detect());
  }

  Future<void> _tap(AppUpdateInfo info) async {
    if (_busy) return;
    setState(() => _busy = true);
    final str = AppStrings.of(context);
    try {
      final result = await AppUpdate.downloadAndInstall(info);
      if (!mounted) return;
      if (result == 'download_failed') {
        showSnack(context, str.t('upd.download_failed'));
      } else if (result == 'need_permission') {
        showSnack(context, str.t('upd.permission'));
      } else if (result != null && result.startsWith('error')) {
        showSnack(context, str.t('upd.failed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppUpdateInfo?>(
        valueListenable: AppUpdate.available,
        builder: (context, info, _) {
          if (info == null) return const SizedBox.shrink();
          return ValueListenableBuilder<AppUpdateInfo?>(
            valueListenable: AppUpdate.ready,
            builder: (context, ready, _) => ValueListenableBuilder<int?>(
              valueListenable: AppUpdate.progress,
              builder: (context, pct, _) =>
                  _card(context, info, ready?.version == info.version, pct),
            ),
          );
        },
      );

  Widget _card(
      BuildContext context, AppUpdateInfo info, bool downloaded, int? pct) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;
    final str = AppStrings.of(context);
    final text = pct != null
        ? str.t('upd.downloading', {'v': info.version, 'p': pct})
        : str.t(downloaded ? 'upd.banner_ready' : 'upd.banner',
            {'v': info.version});
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Material(
        key: const ValueKey('update-banner'),
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (_busy || pct != null) ? null : () => _tap(info),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Icon(AppIcons.download, color: fg),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_busy && pct == null)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: fg),
                      ),
                  ],
                ),
              ),
              if (pct != null)
                LinearProgressIndicator(value: pct / 100, minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
