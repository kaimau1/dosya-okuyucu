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

  /// 2026-11-10 (kullanıcı: *"görsel olarak uygulamaya uymuyor, yerleşimi ve
  /// dili düzgün ayarla"*): pano kartlarının dili — yüzey kartı, solda
  /// yuvarlak simge, iki satır (başlık + sürüm/açıklama), sağda tek düğme.
  /// İndirme YALNIZ düğmeye/karta dokununca başlar.
  Widget _card(
      BuildContext context, AppUpdateInfo info, bool downloaded, int? pct) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final str = AppStrings.of(context);
    final working = pct != null || _busy;
    final title = pct != null
        ? str.t('upd.b_downloading', {'p': pct})
        : str.t(downloaded ? 'upd.b_ready_title' : 'upd.b_title');
    final line = str.t('upd.b_one', {'t': title, 'v': info.version});
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Material(
        key: const ValueKey('update-banner'),
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: working ? null : () => _tap(info),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    Gap.sm, Gap.xs, Gap.xs, Gap.xs),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                          downloaded ? AppIcons.checkCircle : AppIcons.download,
                          size: 16,
                          color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: Gap.sm),
                    // **Tek satır** (Ferrari H5.5): başlık + sürüm aynı satırda;
                    // kapatma düğmesi YOK — 2026-11-10 kullanıcı kararı (kalıcı uyarı).
                    Expanded(
                      child: Text(line,
                          key: const ValueKey('update-banner-line'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: Gap.sm),
                    if (working)
                      const Padding(
                        padding: EdgeInsets.all(Gap.sm),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: () => _tap(info),
                        child: Text(str.t(
                            downloaded ? 'upd.b_install' : 'upd.b_update')),
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
