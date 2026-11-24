import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_icons.dart';
import '../core/ecosystem_apps.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';

/// Kardeş uygulama **Notlar** için zorlamasız, 30 gün kapatılabilir kart.
class CrossAppPromoCard extends StatefulWidget {
  const CrossAppPromoCard({super.key, this.prefsOverride, this.onDismissed});

  final SharedPreferences? prefsOverride;
  final VoidCallback? onDismissed;

  @override
  State<CrossAppPromoCard> createState() => _CrossAppPromoCardState();
}

class _CrossAppPromoCardState extends State<CrossAppPromoCard> {
  SharedPreferences? _prefs;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefsOverride != null) {
      _prefs = widget.prefsOverride;
      _visible = EcosystemApps.shouldShowPromo(_prefs!);
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _visible = EcosystemApps.shouldShowPromo(prefs);
      });
    } catch (_) {
      // Bilinçli: test/izole ağaçlarda eklenti kanalı yoksa sessiz kalır.
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await EcosystemApps.dismissPromo(prefs);
    } catch (_) {
      // Bilinçli: eklenti kanalı yoksa kapatma yalnız oturumda sürer.
    }
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faint = Paper.faint(context);

    return Card(
      key: const ValueKey('cross-app-notlar-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.notes,
                  size: AppIcons.large,
                  color: scheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('eco.notlar_title'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        context.t('eco.notlar_sub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: faint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('cross-app-notlar-dismiss'),
                  tooltip: context.t('eco.dismiss'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    AppIcons.close,
                    size: AppIcons.small,
                    color: faint,
                  ),
                  onPressed: () => unawaited(_dismiss()),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const ValueKey('cross-app-notlar-cta'),
                onPressed: () => unawaited(EcosystemApps.openNotlarStore()),
                icon: const Icon(AppIcons.open, size: AppIcons.small),
                label: Text(context.t('eco.notlar_cta')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
