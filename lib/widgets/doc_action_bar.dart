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
class DocAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const DocAction(this.icon, this.label, this.onTap);
}

class DocActionBar extends StatelessWidget {
  final List<DocAction> actions;

  const DocActionBar(this.actions, {super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions)
            TextButton.icon(
              onPressed: action.onTap,
              icon: Icon(action.icon, size: 20),
              label: Text(action.label),
            ),
        ],
      ),
    );
  }
}
