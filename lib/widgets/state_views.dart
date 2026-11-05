/// **Boş / hata / yükleme durumlarının ortak yüzleri** (Faz 40 / madde 10).
///
/// * [AppSkeleton] — belge açılırken yer tutucu (çizgi blokları). Nabız
///   yalnız süslü animasyon bütçesi varsa (`DeviceProfile`) ve yüzey
///   görünürken (`TickerMode`) çalışır; hafif profilde sabit bloklar, sıfır
///   kare (anayasa §3, §6). `saveLayer` yok: saydamlık blok RENGİNE işlenir,
///   `Opacity`/`FadeTransition` katmanı açılmaz.
/// * [AppErrorView] — ekran İÇİ tek tip hata yüzü: simge · başlık · ileti ·
///   (varsa) Yeniden dene · Ayrıntıyı kopyala. Editörlerin dağınık
///   `Center(Text('Açılamadı: …'))` satırlarının yerine. (Uygulama çapındaki
///   çizim hatası yüzü `AppErrorScreen` ayrı: o temaya güvenemez.)
/// * Boş durum: [FmEmptyState] (`widgets/motion.dart`) + çizim (`empty_art`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_icons.dart';
import '../core/device_profile.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme.dart';

/// İskeletin biçimi.
enum SkeletonKind {
  /// Sayfa: başlık + paragraf satırları (Word, metin, PDF).
  document,

  /// Izgara: başlık satırı + hücre blokları (Excel).
  grid,

  /// Slayt: büyük kart + küçük resim şeridi.
  slides,
}

class AppSkeleton extends StatefulWidget {
  final SkeletonKind kind;
  const AppSkeleton({super.key, this.kind = SkeletonKind.document});

  /// Nabız çalışsın mı? (Test ve hafif profil için ayrık.)
  static bool get animates => DeviceProfile.budget.decorativeAnimations;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: Motion.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hafif profilde ya da "animasyonları kaldır" açıkken sabit kutular.
    if (AppSkeleton.animates && !Motion.reduced(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.t('ux.loading'),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Saydamlık rengin içinde: katman yok.
            final a = 0.05 + 0.06 * Motion.standard.transform(_pulse.value);
            final block = scheme.onSurface.withValues(alpha: a);
            return switch (widget.kind) {
              SkeletonKind.document => _document(block),
              SkeletonKind.grid => _grid(block),
              SkeletonKind.slides => _slides(block),
            };
          },
        ),
      ),
    );
  }

  static const _widths = [0.92, 0.85, 0.97, 0.6, 0.9, 0.78, 0.95, 0.5];

  Widget _bar(Color c, double w, double h) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: w,
        child: Container(
          height: h,
          margin: const EdgeInsets.only(bottom: Gap.sm + 2),
          decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(h / 2)),
        ),
      );

  Widget _document(Color c) => ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(c, 0.55, 22),
              const SizedBox(height: Gap.sm),
              for (var i = 0; i < 14; i++) _bar(c, _widths[i % _widths.length], 12),
            ],
          ),
        ),
      );

  Widget _grid(Color c) => ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            children: [
              for (var r = 0; r < 14; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      for (var col = 0; col < 4; col++)
                        Expanded(
                          child: Container(
                            height: r == 0 ? 22 : 18,
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _slides(Color c) => Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: Gap.md),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: Gap.sm),
                        decoration: BoxDecoration(
                            color: c, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Ekran içi tek tip hata yüzü.
class AppErrorView extends StatelessWidget {
  /// Başlık; null ise "Açılamadı".
  final String? title;

  /// Kullanıcıya söylenecek ileti (teknik ayrıntı değil).
  final String message;

  /// Teknik ayrıntı — "Ayrıntıyı kopyala" ile panoya (ekranda yazılmaz).
  final String? details;

  final VoidCallback? onRetry;

  const AppErrorView({
    super.key,
    this.title,
    required this.message,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          key: const ValueKey('app-error-view'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: scheme.errorContainer, shape: BoxShape.circle),
              child: Icon(AppIcons.error,
                  size: 34, color: scheme.onErrorContainer),
            ),
            const SizedBox(height: Gap.md),
            Text(title ?? context.t('ux.error_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: Gap.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                if (onRetry != null)
                  FilledButton.icon(
                    key: const ValueKey('app-error-retry'),
                    onPressed: onRetry,
                    icon: const Icon(AppIcons.refresh),
                    label: Text(context.t('common.retry')),
                  ),
                if (details != null)
                  OutlinedButton.icon(
                    key: const ValueKey('app-error-copy'),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: details!)),
                    icon: const Icon(AppIcons.copyPlain),
                    label: Text(context.t('ux.copy_details')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
