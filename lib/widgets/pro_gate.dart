import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_icons.dart';
import '../core/edition.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import 'app_dialog.dart';

/// **Pro kapısı** (SÜRÜM PLANI S2/S3, 2026-11-12).
///
/// Giriş noktası (kutu, menü satırı, düğme) kapatılır, ekran ekran değil:
/// - sürümde varsa → [guard] işi çalıştırır, [badge] boş döner;
/// - Lite'ta Pro özelliği → kutu görünür, köşesinde "PRO"; dokununca
///   [showProSheet] (özellik + 3 madde + fiyat + "Play'de gör");
/// - yalnız Kişisel özellik Lite/Pro'da → [visible] false, HİÇ çizilmez.
///
/// Kişisel derlemede (bugünkü nightly) her şey açık: bu sınıf saydamdır.
abstract final class ProGate {
  /// Giriş noktası çizilsin mi?
  static bool visible(Feature f, {Edition edition = Edition.current}) =>
      edition.has(f) || f.isPro;

  /// Çizilip dokununca tanıtım levhası mı açılacak?
  static bool locked(Feature f, {Edition edition = Edition.current}) =>
      !edition.has(f);

  /// [f] bu sürümde varsa [run]'ı çalıştırır, yoksa Pro levhasını açar.
  static void guard(BuildContext context, Feature f, VoidCallback run,
      {Edition edition = Edition.current}) {
    if (edition.has(f)) {
      run();
    } else if (f.isPro) {
      showProSheet(context, f);
    }
  }

  /// [guard]'ı saran dokunma geri çağrısı (kutu `onTap`'ı için).
  static VoidCallback wrap(BuildContext context, Feature f, VoidCallback run,
          {Edition edition = Edition.current}) =>
      () => guard(context, f, run, edition: edition);
}

/// Ana ekrandaki "Pro'da neler var?" kartı (§3 madde 2): yalnız Lite'ta,
/// kapatılınca 30 gün görünmez.
abstract final class ProPromo {
  static const _key = 'pro_card_hidden_until';
  static const hideFor = Duration(days: 30);

  static Future<bool> shouldShow(
      {Edition edition = Edition.current, DateTime? now}) async {
    if (edition != Edition.lite) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_key) ?? 0;
      return (now ?? DateTime.now()).millisecondsSinceEpoch >= until;
    } catch (_) {
      return false; // Bilinçli: tercih okunamazsa kart gösterilmez.
    }
  }

  static Future<void> hide({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _key, (now ?? DateTime.now()).add(hideFor).millisecondsSinceEpoch);
    } catch (_) {
      return; // Bilinçli: yazılamazsa kart yalnız bu oturumda kapanır.
    }
  }
}

/// Kilitli giriş noktasının köşesindeki küçük "PRO" etiketi.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('pro-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PRO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
              height: 1.1,
              color: scheme.onTertiaryContainer,
            ),
      ),
    );
  }
}

/// [child]'ın köşesine, [feature] bu sürümde kilitliyse [ProBadge] koyar.
class ProBadged extends StatelessWidget {
  final Feature feature;
  final Widget child;
  final Edition edition;

  const ProBadged({
    super.key,
    required this.feature,
    required this.child,
    this.edition = Edition.current,
  });

  @override
  Widget build(BuildContext context) {
    if (!ProGate.locked(feature, edition: edition)) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const PositionedDirectional(top: 2, end: 2, child: ProBadge()),
      ],
    );
  }
}

/// Pro tanıtım levhası (§3). [feature] verilmezse genel tanıtım (ayar satırı).
///
/// Olmayacaklar (§3): açılışta tam ekran, geri sayım, iş sonu araya girme.
Future<void> showProSheet(BuildContext context, [Feature? feature]) {
  return showAppSheet<void>(
    context,
    title: feature == null
        ? context.t('pro.title')
        : context.t('pro.feature_title', {'f': context.t('pro.f.${feature.name}')}),
    builder: (ctx) => _ProSheetBody(feature: feature),
  );
}

class _ProSheetBody extends StatelessWidget {
  final Feature? feature;
  const _ProSheetBody({this.feature});

  static const _bullets = ['pro.b1', 'pro.b2', 'pro.b3'];

  Future<void> _openStore(BuildContext context) async {
    final nav = Navigator.of(context);
    var ok = false;
    try {
      ok = await launchUrl(ProListing.marketUri,
          mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false; // Bilinçli: Play yüklü değil → web adresine düş.
    }
    if (!ok) {
      try {
        await launchUrl(ProListing.webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Bilinçli: tarayıcı da yoksa levha açık kalır, kullanıcı kapatır.
        return;
      }
    }
    if (nav.mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('pro.lead'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.sm),
          for (final b in _bullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Row(
                children: [
                  Icon(AppIcons.checkCircle,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(child: Text(context.t(b))),
                ],
              ),
            ),
          if (ProListing.priceLabel.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              context.t('pro.price', {'p': ProListing.priceLabel}),
              key: const ValueKey('pro-price'),
              style: theme.textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const ValueKey('pro-store'),
            onPressed: () => _openStore(context),
            icon: const Icon(AppIcons.pro),
            label: Text(context.t('pro.store')),
          ),
          TextButton(
            key: const ValueKey('pro-later'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t('pro.later')),
          ),
        ],
      ),
    );
  }
}
