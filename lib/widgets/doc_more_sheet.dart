import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import 'menu_kit.dart';

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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group.title.isNotEmpty) MenuGroupTitle(group.title),
          MenuGroupCard(
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

/// Izgara hücresi — ortak [MenuTile] (bkz. `menu_kit.dart`).
class _Tile extends StatelessWidget {
  final DocMoreItem item;
  final VoidCallback? onTap;

  const _Tile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = item.selected == true;
    return Semantics(
      button: true,
      enabled: onTap != null,
      toggled: item.selected,
      label: item.label,
      excludeSemantics: true,
      child: MenuTile(
        icon: item.icon,
        label: item.label,
        onTap: onTap,
        tone: item.danger
            ? MenuTone.danger
            : (selected ? MenuTone.selected : MenuTone.neutral),
        badge: selected
            ? Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.checkCircle, size: 18, color: scheme.primary),
              )
            : null,
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
