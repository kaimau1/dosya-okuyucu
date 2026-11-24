import 'package:flutter/material.dart';

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
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          // Menü görünümü (2026-11-15): sekmeli/Bento `MenuSections`ta —
          // dosya levhasıyla aynı aile.
          child: MenuSections(
            header: header == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: header,
                  ),
            sections: [
              for (final group in groups)
                MenuKitSection(title: group.title, actions: [
                  for (final item in group.items)
                    MenuKitAction(
                      icon: item.icon,
                      label: item.label,
                      checked: item.selected,
                      tone: item.danger
                          ? MenuTone.danger
                          : (item.selected == true
                              ? MenuTone.selected
                              : MenuTone.neutral),
                      onTap: item.onTap == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              item.onTap!();
                            },
                    ),
                ]),
            ],
          ),
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
