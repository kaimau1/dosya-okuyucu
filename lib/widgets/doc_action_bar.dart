/// Belge ekranlarının altındaki **etiketli eylem çubuğu**.
///
/// 2026-07-27'de yalnız PDF'e eklenmişti (kullanıcı bulgusu: WhatsApp'tan gelen
/// dosya *"açılıyor ama ne yapacağım belli değil"* — üst çubuktaki ikonların
/// tooltip'i telefonda hiç görünmüyor). 2026-07-28'de kullanıcı aynısını Word,
/// txt, Excel ve slaytta da istedi; dört ekranda görünüm ayrışmasın diye çubuk
/// tek yerde duruyor.
///
/// Sığmazsa yatay kaydırılır — küçük ekranda düğme kırpılmasın.
library;

import 'package:flutter/material.dart';

/// Çubuktaki tek düğme. [onTap] null ise düğme sönük görünür (işlem şu an
/// yapılamıyor demektir — gizlemek yerine sönük bırakmak yeri sabit tutar).
///
/// [active] bir KİP düğmesi için (ör. Word'de "Mobil akış" açık): simgenin
/// hap zemini vurgu rengine döner.
class DocAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const DocAction(this.icon, this.label, this.onTap, {this.active = false});
}

/// **Dock** görünümü (2026-09-23 tasarım turu): simge ÜSTTE, etiket ALTTA —
/// Acrobat/Drive/Files'ın bugünkü alt çubuk dili. Eski çubuk yan yana
/// `TextButton.icon`lardı: dar ekranda üç düğmeden sonrası görünmüyor,
/// etiketler simgeyle yarışıyordu.
///
/// * Sığıyorsa düğmeler genişliği EŞİT paylaşır (sağda boşluk kalmaz).
/// * Sığmıyorsa sabit genişlikte yatay kayar; son düğmenin yarısı görünür
///   kalacak şekilde ölçülür — kaydırılabildiği gözle anlaşılır.
/// * Basınca simgenin arkasında hap biçimli vurgu belirir (M3 gezinme dili).
class DocActionBar extends StatelessWidget {
  final List<DocAction> actions;

  const DocActionBar(this.actions, {super.key});

  /// Bir düğmenin en az genişliği; altına inilirse kaydırmaya geçilir.
  static const double _minSlot = 68;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.sizeOf(context).width;
      final n = actions.isEmpty ? 1 : actions.length;
      final fits = width / n >= _minSlot;
      if (fits) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              for (final a in actions) Expanded(child: _DockButton(a)),
            ],
          ),
        );
      }
      // Kaydırmalı düzen: görünen düğme sayısı x.5 olacak şekilde genişlik.
      final visible = ((width - 8) / 76).floor().clamp(3, 12);
      final slot = (width - 8) / (visible + 0.5);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            for (final a in actions)
              SizedBox(width: slot, child: _DockButton(a)),
          ],
        ),
      );
    });
  }
}

class _DockButton extends StatelessWidget {
  final DocAction action;
  const _DockButton(this.action);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = action.onTap != null;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : (action.active ? scheme.onPrimaryContainer : scheme.onSurface);
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        // Dalga simgenin hapına benzesin diye köşeli değil yuvarlak.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: action.active
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(action.icon, size: 22, color: fg),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 28,
                child: Text(
                  action.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11.5,
                    height: 1.15,
                    letterSpacing: 0,
                    fontWeight:
                        action.active ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
