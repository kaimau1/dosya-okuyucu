import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_icons.dart';
import '../core/edition.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../services/play_store.dart';
import '../services/pro_purchase.dart';
import 'app_dialog.dart';

/// Bölgesel Pro fiyat etiketini çözer:
/// 1) Play Store'dan okunan canlı ülke fiyatı (`₺29,99`, `$0.79`, `Rp 12.000`),
/// 2) Türkiye / Türkçe arayüzde lansman varsayılanı (`29,99 TL`) ya da açıkça
///    verilmiş özel derleme etiketi,
/// 3) Diğer dillerde Play fiyatı henüz gelmeden sabit TL göstermemek için `''`.
String resolveProPrice(BuildContext context, {String? storePrice}) {
  final live = storePrice?.trim();
  if (live != null && live.isNotEmpty) return live;
  final lang = AppStrings.of(context).language;
  if (lang == AppLanguage.tr) return ProListing.priceLabel;
  if (ProListing.priceLabel.isNotEmpty && ProListing.priceLabel != '29,99 TL') {
    return ProListing.priceLabel;
  }
  return '';
}

/// Doğrudan açılabilen kilitli Pro ekranlarında, kullanıcı aynı ekran
/// açıkken Pro satın alırsa kilidi anında kaldırır ve ilk yüklemeyi başlatır.
mixin ProUnlockWatcher<T extends StatefulWidget> on State<T> {
  Feature get proFeature;
  void onProUnlocked();

  bool _proInitialized = false;

  /// Bu ekranın Pro verisi yüklendi mi (dispose temizliği için)?
  bool get proInitialized => _proInitialized;

  @override
  void initState() {
    super.initState();
    if (Edition.current.has(proFeature)) {
      _proInitialized = true;
      onProUnlocked();
    } else if (Edition.current == Edition.lite) {
      ProUnlock.owned.addListener(_handleProUnlock);
    }
  }

  void _handleProUnlock() {
    if (!mounted || _proInitialized || !Edition.current.has(proFeature)) {
      return;
    }
    ProUnlock.owned.removeListener(_handleProUnlock);
    _proInitialized = true;
    onProUnlocked();
    setState(() {});
  }

  @override
  void dispose() {
    ProUnlock.owned.removeListener(_handleProUnlock);
    super.dispose();
  }
}

/// **Pro kapısı** (SÜRÜM PLANI S2/S3, 2026-11-12).
///
/// Giriş noktası (kutu, menü satırı, düğme) kapatılır, ekran ekran değil:
/// - sürümde varsa → [guard] işi çalıştırır, [badge] boş döner;
/// - Lite'ta Pro özelliği → kutu görünür, köşesinde "PRO"; dokununca
///   [showProSheet] (özellik + 3 madde + fiyat + tek seferlik satın al /
///   geri yükle — K15, 2026-11-27, Play Billing `ProPurchase`);
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
  static void guard(
    BuildContext context,
    Feature f,
    VoidCallback run, {
    Edition edition = Edition.current,
  }) {
    if (edition.has(f)) {
      run();
    } else if (f.isPro) {
      showProSheet(context, f);
    }
  }

  /// [f] bu sürümde varsa `true` döner; yoksa Lite'ta Pro levhasını açıp
  /// `false` döner (`await ProGate.check(context, Feature.x)`).
  static Future<bool> check(
    BuildContext context,
    Feature f, {
    Edition edition = Edition.current,
  }) async {
    if (edition.has(f)) return true;
    if (f.isPro && context.mounted) {
      await showProSheet(context, f);
    }
    return false;
  }

  /// [guard]'ı saran dokunma geri çağrısı (kutu `onTap`'ı için).
  static VoidCallback wrap(
    BuildContext context,
    Feature f,
    VoidCallback run, {
    Edition edition = Edition.current,
  }) =>
      () => guard(context, f, run, edition: edition);
}

/// Ana ekrandaki "Pro'da neler var?" kartı (§3 madde 2): yalnız Lite'ta,
/// kapatılınca 30 gün görünmez.
abstract final class ProPromo {
  static const _key = 'pro_card_hidden_until';
  static const _firstKey = 'pro_card_first_ms';
  static const hideFor = Duration(days: 30);
  static const gracePeriod = Duration(days: 3);

  static Future<bool> shouldShow({
    Edition edition = Edition.current,
    DateTime? now,
  }) async {
    if (edition.tier != Edition.lite) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      var first = prefs.getInt(_firstKey);
      if (first == null) {
        first = nowMs;
        await prefs.setInt(_firstKey, first);
      }
      if (nowMs - first < gracePeriod.inMilliseconds) return false;
      final until = prefs.getInt(_key) ?? 0;
      return nowMs >= until;
    } catch (_) {
      return false; // Bilinçli: tercih okunamazsa kart gösterilmez.
    }
  }

  static Future<void> hide({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _key,
        (now ?? DateTime.now()).add(hideFor).millisecondsSinceEpoch,
      );
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
    if (!feature.isPro || edition != Edition.lite) return child;
    // Lite: satın alınınca rozet hemen kalksın.
    return ValueListenableBuilder<bool>(
      valueListenable: ProUnlock.owned,
      builder: (_, owned, _) => owned ? child : _badged(),
    );
  }

  Widget _badged() => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          const PositionedDirectional(top: 2, end: 2, child: ProBadge()),
        ],
      );
}

/// Pro tanıtım levhası (§3). [feature] verilmezse genel tanıtım (ayar satırı).
///
/// Olmayacaklar (§3): açılışta tam ekran, geri sayım, iş sonu araya girme.
Future<void> showProSheet(BuildContext context, [Feature? feature]) {
  unawaited(PlayStore.noteFriction());
  return showAppSheet<void>(
    context,
    title: feature == null
        ? context.t('pro.title')
        : context.t('pro.feature_title', {
            'f': context.t('pro.f.${feature.name}'),
          }),
    builder: (ctx) => _ProSheetBody(feature: feature),
  );
}

class _ProSheetBody extends StatefulWidget {
  final Feature? feature;
  const _ProSheetBody({this.feature});

  @override
  State<_ProSheetBody> createState() => _ProSheetBodyState();
}

class _ProSheetBodyState extends State<_ProSheetBody> {
  static const _bullets = ['pro.b1', 'pro.b2', 'pro.b3'];

  bool _busy = false;

  /// Başarısız/iptal sonucun iletisi LEVHANIN İÇİNDE (2026-11-27 tablet
  /// bulgusu: alttaki şerit "Şimdi değil" düğmesinin üstüne biniyordu).
  String? _note;

  @override
  void initState() {
    super.initState();
    if (Edition.current == Edition.lite) {
      unawaited(ProPurchase.loadPrice());
    }
  }

  /// Play satın alma akışı; sonuç iletisi, başarıda levha kapanır.
  Future<void> _buy() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _note = null;
    });
    final r = await ProPurchase.buy();
    if (!mounted) return;
    final text = s.t(switch (r) {
      ProBuyResult.purchased => 'pro.done',
      ProBuyResult.pending => 'pro.pending',
      ProBuyResult.canceled => 'pro.canceled',
      ProBuyResult.unavailable => 'pro.unavailable',
      ProBuyResult.failed => 'pro.failed',
    });
    if (r == ProBuyResult.purchased) {
      showSnackOn(messenger, text);
      nav.pop();
      return;
    }
    setState(() {
      _busy = false;
      _note = text;
    });
  }

  Future<void> _restore() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _note = null;
    });
    final owned = await ProPurchase.restore();
    if (!mounted) return;
    final text = s.t(switch (owned) {
      true => 'pro.restored',
      false => 'pro.restore_none',
      null => 'pro.unavailable',
    });
    if (owned == true) {
      showSnackOn(messenger, text);
      nav.pop();
      return;
    }
    setState(() {
      _busy = false;
      _note = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('pro-one-time'),
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 6),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.shield, size: 16, color: cs.onSecondaryContainer),
                const SizedBox(width: Gap.xs),
                Flexible(
                  child: Text(
                    context.t('pro.one_time_badge'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(context.t('pro.lead'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.sm),
          for (final b in _bullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Row(
                children: [
                  Icon(
                    AppIcons.checkCircle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(child: Text(context.t(b))),
                ],
              ),
            ),
          const _ProPricePill(prominent: true),
          const SizedBox(height: Gap.sm),
          Text(
            context.t('pro.smart_limit_note'),
            key: const ValueKey('pro-smart-note'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            context.t('pro.trust'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.md),
          if (_note != null) ...[
            Text(
              _note!,
              key: const ValueKey('pro-note'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
            const SizedBox(height: Gap.sm),
          ],
          FilledButton.icon(
            key: const ValueKey('pro-store'),
            onPressed: _busy ? null : _buy,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.pro),
            label: Text(context.t('pro.buy')),
          ),
          TextButton(
            key: const ValueKey('pro-restore'),
            onPressed: _busy ? null : _restore,
            child: Text(context.t('pro.restore')),
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

/// Lite derlemede doğrudan açılan bir Pro ekranının gösterdiği kilitli görünüm.
class ProLockedView extends StatelessWidget {
  final Feature feature;
  final String title;
  final String? lockedTitle;
  final String? message;
  final bool withScaffold;

  const ProLockedView({
    super.key,
    required this.feature,
    required this.title,
    this.lockedTitle,
    this.message,
    this.withScaffold = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final body = Center(
      key: const ValueKey('pro-locked-view'),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.pro, size: 48, color: cs.primary),
              const SizedBox(height: Gap.md),
              Text(
                lockedTitle ??
                    context.t('pro.locked_title', {
                      'f': context.t('pro.f.${feature.name}'),
                    }),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                message ?? context.t('pro.locked_sub'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const _ProPricePill(prominent: false),
              const SizedBox(height: Gap.lg),
              FilledButton.icon(
                key: const ValueKey('pro-locked-btn'),
                onPressed: () => showProSheet(context, feature),
                icon: const Icon(AppIcons.pro),
                label: Text(context.t('ab.pro_unlock')),
              ),
            ],
          ),
        ),
      ),
    );
    if (!withScaffold) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

class _ProPricePill extends StatelessWidget {
  final bool prominent;
  const _ProPricePill({required this.prominent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: ProPurchase.storePrice,
      builder: (context, livePrice, _) {
        final price = resolveProPrice(context, storePrice: livePrice);
        if (price.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: prominent ? Gap.sm : Gap.md),
          child: Container(
            key: ValueKey(prominent ? 'pro-price' : 'pro-locked-price'),
            padding: EdgeInsets.symmetric(
              horizontal: prominent ? Gap.md : Gap.sm,
              vertical: prominent ? Gap.sm : 5,
            ),
            decoration: BoxDecoration(
              color: prominent
                  ? cs.primaryContainer.withValues(alpha: 0.65)
                  : cs.secondaryContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              context.t('pro.price_one_time', {'p': price}),
              textAlign: TextAlign.center,
              style: (prominent
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                color: prominent ? cs.onPrimaryContainer : cs.onSecondaryContainer,
                fontWeight: prominent ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
