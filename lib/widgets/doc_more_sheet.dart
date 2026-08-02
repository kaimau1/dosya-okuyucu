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
class DocMoreSheet {
  const DocMoreSheet._();

  /// Sayfayı açar. Bir eyleme dokunulunca sayfa kapanır ve eylem çalışır —
  /// sıralama önemli: önce kapan, sonra çalış; yoksa eylemin açtığı diyalog
  /// (ör. "sütun genişliği") sayfanın altında kalırdı.
  static Future<void> show(BuildContext context, List<DocMoreGroup> groups) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    group.title,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ),
                for (final item in group.items)
                  ListTile(
                    dense: true,
                    enabled: item.onTap != null,
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: item.onTap == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            item.onTap!();
                          },
                  ),
              ],
              const SizedBox(height: 8),
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
class DocMoreItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const DocMoreItem(this.icon, this.label, this.onTap);
}
