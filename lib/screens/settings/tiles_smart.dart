import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/smart_quota.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_user_cats.dart';
import '../../widgets/fm/pin_dialog.dart';
import '../fm/smart_sort_screen.dart';
import 'settings_widgets.dart';

/// **Ayarlar > Yapay zekâ'nın başı: Akıllı klasörler** (U4, 2026-11-20 —
/// kullanıcı: *"Yapay zekâ ayar sayfası yeni duruma göre baştan yazılsın,
/// artık ana özelliğimiz akıllı klasörler"*). Durum satırı Akıllı düzen
/// ekranını açar; altında aynı ayar denetimi ([SmartSortSettings]).
class SmartSortSettingsTile extends StatefulWidget {
  const SmartSortSettingsTile({super.key});

  @override
  State<SmartSortSettingsTile> createState() => _SmartSortSettingsTileState();
}

class _SmartSortSettingsTileState extends State<SmartSortSettingsTile> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future.wait([SmartSort.ensureLoaded(), SmartQuota.read()])
        .then((_) {
      if (mounted) setState(() => _ready = true);
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return Column(children: [
      ListenableBuilder(
        listenable: SmartSort.revision,
        builder: (context, _) => SettingTile(
          key: const ValueKey('set-smart-open'),
          icon: AppIcons.ai,
          title: context.t('sm.title'),
          subtitle: SmartSort.enabled
              ? context.t('set.smart_on', {'n': SmartSort.records.length})
              : context.t('set.smart_off'),
          wrapSubtitle: true,
          trailing: const Icon(AppIcons.chevron),
          onTap: () => unawaited(SmartSortScreen.open(context)),
        ),
      ),
      const SmartSortSettings(learning: true),
    ]);
  }
}

/// Hassas akıllı klasörlerin (kimlik, sağlık, banka, vergi) kilidi: durumu
/// söyler, PIN yoksa kurdurur ([unlockSensitiveCats] kuralı aynı).
class SmartSensitivePinTile extends StatelessWidget {
  const SmartSensitivePinTile({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sub = !state.fmHasLockPin
        ? 'set.smart_pin_none'
        : (state.appLock ? 'set.smart_pin_app' : 'set.smart_pin_on');
    return SettingTile(
      key: const ValueKey('set-smart-pin'),
      icon: AppIcons.lock,
      title: context.t('set.smart_pin'),
      subtitle: context.t(sub),
      wrapSubtitle: true,
      // PIN yoksa dokunmak kurar; varsa değiştirme Gizlilik'te (tek yer).
      onTap: state.fmHasLockPin ? null : () => unawaited(setupPin(context)),
    );
  }
}

/// "Kategorilerim": sayı + adlar; dokununca Akıllı düzen ekranı (ekleme,
/// düzenleme, eski dosyalara uygulama orada — tek yer).
class SmartUserCatsTile extends StatelessWidget {
  const SmartUserCatsTile({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SmartUserCats.revision,
        builder: (context, _) {
          final cats = SmartUserCats.all;
          return SettingTile(
            key: const ValueKey('set-smart-cats'),
            icon: AppIcons.labelOutline,
            title: context.t('suc.section'),
            subtitle: cats.isEmpty
                ? context.t('suc.empty')
                : [for (final c in cats) c.name].join(' · '),
            wrapSubtitle: true,
            trailing: const Icon(AppIcons.chevron),
            onTap: () => unawaited(SmartSortScreen.open(context)),
          );
        },
      );
}
