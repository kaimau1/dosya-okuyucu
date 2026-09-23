import 'package:flutter/material.dart';

/// Belge araç çubuklarının **"Daha fazla"** sayfası: etiketli, gruplu eylemler.
///
/// **Neden gerekiyor:** biçim çubukları yalnız İKONDAN oluşuyordu ve telefonda
/// `tooltip` hiç görünmez — kullanıcı 20 küçük ikonun hangisinin ne yaptığını
/// ancak deneyerek öğreniyordu. (Aynı bulgu 2026-07-27'de `DocActionBar`ı
/// doğurmuştu: *"açılıyor ama ne yapacağım belli değil"*; biçim çubuğu o dersin
/// dışında kalmıştı.)
///
/// Kural: **sık kullanılan birkaç eylem çubukta ikonla, gerisi burada
/// ETİKETLE.** Böylece çubuk kısalır (yatayda kör kaydırma biter) ve seyrek
/// eylemler okunur hâle gelir.
///
/// **Izgara görünümü (2026-09-23 tasarım turu):** eski sayfa sıkışık bir
/// `ListTile` listesiydi; 15 satırlık bir menüde göz kayboluyordu. Artık her
/// grup, yuvarlak simge kutulu 4 sütunlu bir ızgara (Files / Drive / iOS
/// paylaşım sayfası dili): bir bakışta taranıyor, dokunma hedefi büyük.
/// Açık/kapalı ayarlar ([DocMoreItem.selected]) vurgu renginde ve köşesinde
/// onay işaretiyle görünür — eski "Gece modu / Gece modunu kapat" gibi
/// iki ayrı metne gerek kalmadı.
class DocMoreSheet {
  const DocMoreSheet._();

  /// Sayfayı açar. Bir eyleme dokunulunca sayfa kapanır ve eylem çalışır —
  /// sıralama önemli: önce kapan, sonra çalış; yoksa eylemin açtığı diyalog
  /// (ör. "sütun genişliği") sayfanın altında kalırdı.
  ///
  /// [header] sayfanın en üstünde durur (ör. dosya adı + tür rozeti).
  static Future<void> show(
    BuildContext context,
    List<DocMoreGroup> groups, {
    Widget? header,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: header,
                ),
              for (final group in groups)
                if (group.items.isNotEmpty)
                  _GroupCard(
                    group: group,
                    onPick: (item) {
                      Navigator.of(sheetContext).pop();
                      item.onTap!();
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final DocMoreGroup group;
  final void Function(DocMoreItem) onPick;

  const _GroupCard({required this.group, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(
                group.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(builder: (context, box) {
              // Telefon: 4 sütun; geniş ekran/tablet: 5-6.
              final cols = (box.maxWidth / 88).floor().clamp(3, 6);
              final w = box.maxWidth / cols;
              return Wrap(
                children: [
                  for (final item in group.items)
                    SizedBox(
                      width: w,
                      child: _Tile(
                        item: item,
                        onTap: item.onTap == null ? null : () => onPick(item),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final DocMoreItem item;
  final VoidCallback? onTap;

  const _Tile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final selected = item.selected == true;
    final Color iconFg;
    final Color iconBg;
    if (!enabled) {
      iconFg = scheme.onSurface.withValues(alpha: 0.35);
      iconBg = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    } else if (item.danger) {
      iconFg = scheme.error;
      iconBg = scheme.errorContainer;
    } else if (selected) {
      iconFg = scheme.onPrimary;
      iconBg = scheme.primary;
    } else {
      iconFg = scheme.onSurface;
      iconBg = scheme.surface;
    }
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: item.selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                      border: selected || !enabled || item.danger
                          ? null
                          : Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(item.icon, size: 22, color: iconFg),
                  ),
                  if (selected)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle,
                            size: 18, color: scheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (item.danger ? scheme.error : scheme.onSurface)
                      : scheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlıklı eylem grubu ("Pano", "Satır", "Sütun"…).
class DocMoreGroup {
  final String title;
  final List<DocMoreItem> items;
  const DocMoreGroup(this.title, this.items);
}

/// Sayfadaki tek eylem. [onTap] null ise satır sönük görünür (şu an
/// yapılamıyor demektir — gizlemek yerine sönük bırakmak listeyi sabit tutar).
///
/// [selected] null değilse öğe bir AÇ/KAPA ayarıdır (true = açık).
/// [danger] geri dönüşü olmayan işler için (silme): kırmızı simge.
class DocMoreItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool? selected;
  final bool danger;
  const DocMoreItem(this.icon, this.label, this.onTap,
      {this.selected, this.danger = false});
}
