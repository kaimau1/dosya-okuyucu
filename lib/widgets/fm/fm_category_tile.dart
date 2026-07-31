import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Pano kutusunun verisi (ikon, renk, başlık, alt satır, dokunma).
class FmTileData {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  /// Kutu **dikkat çeksin mi** — simge yavaşça nefes alır.
  ///
  /// Kullanıcı isteği 2026-07-31: *"çöp kutusunu bulmak çok zor … doluysa
  /// animasyonu olsun"*. Yalnız DURUM varken açılır (çöp kutusunda dosya
  /// varken); sürekli oynayan bir kutu bir süre sonra görünmez olur.
  final bool pulse;

  const FmTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.pulse = false,
  });
}

/// Simgeyi yavaşça büyütüp küçülten kutu ("dolu" göstergesi).
///
/// Erişilebilirlik: cihazda animasyonlar kapalıysa (`disableAnimations`) hiç
/// oynamaz — hareket duyarlılığı olan kullanıcıya sürekli titreşen bir kutu
/// dayatılmamalı. Kutu o durumda da renk/simge değişimiyle ayırt ediliyor.
class _PulsingIcon extends StatefulWidget {
  final Widget child;
  const _PulsingIcon({super.key, required this.child});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.14).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: widget.child,
      );
}

/// Panonun kategori kutusu. **Ortak widget:** "Önemli Dosyalar" klasörü de
/// aynı kategorizasyonu gösteriyor (kullanıcı isteği 2026-07-29: "önemli
/// dosyalar klasörü ve ona yine ana sayfadaki formatta kategorizasyon") —
/// iki ekranın görünümü kopyalanırsa biri değişince diğeri geride kalırdı.
class FmCategoryTile extends StatelessWidget {
  final FmTileData data;
  const FmCategoryTile({super.key, required this.data});

  /// Nefes alan simgenin kimliği. Material'in kendi içinde de
  /// `ScaleTransition`lar var; test bizimkini tür yerine bununla bulur.
  static const pulseKey = ValueKey<String>('fm-tile-pulse');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tint =
        dark ? Color.lerp(data.color, Colors.white, 0.25)! : data.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(builder: (context) {
                final box = Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    // Dikkat çeken kutuda zemin biraz daha koyu: animasyon
                    // dursa bile (erişilebilirlik) kutu ayırt edilebilir kalır.
                    color: tint.withValues(
                        alpha: data.pulse ? (dark ? 0.34 : 0.22) : (dark ? 0.22 : 0.13)),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(data.icon, color: tint),
                );
                return data.pulse
                    ? _PulsingIcon(key: pulseKey, child: box)
                    : box;
              }),
              const SizedBox(height: Gap.sm),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kutuların ızgarası (pano ve Önemli Dosyalar aynı ölçüleri kullanır).
class FmCategoryGrid extends StatelessWidget {
  final List<FmTileData> tiles;
  const FmCategoryGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 0.95,
          mainAxisSpacing: Gap.sm,
          crossAxisSpacing: Gap.sm,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => FmCategoryTile(data: tiles[i]),
      );
}

/// **Araç satırı** — kategori kutularından görsel olarak DAHA HAFİF.
///
/// Kullanıcı geri bildirimi (2026-07-29): *"ana ekranda çok fazla buton olmuş,
/// karışıklık var"*. Sorun sayı kadar **eşit ağırlıktı**: 16 büyük renkli
/// kutunun hepsi aynı derecede bağırıyordu, göz nereye bakacağını bilemiyordu.
///
/// Çözüm hiyerarşi: **içerik** (Görüntüler, Videolar, Belgeler…) büyük kartlar
/// olarak kalır — insanlar buraya dosya aramaya gelir; **araçlar** (Yer aç,
/// Otomatik düzenle, Son işlemler…) küçük, kartsız, tek satırlık simgelerle
/// altta durur. Hiçbir şey kaldırılmadı, yalnız ağırlıkları ayrıldı.
class FmToolGrid extends StatelessWidget {
  final List<FmTileData> tools;
  const FmToolGrid({super.key, required this.tools});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        childAspectRatio: 0.9,
        mainAxisSpacing: Gap.xs,
        crossAxisSpacing: Gap.xs,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        final tint =
            dark ? Color.lerp(tool.color, Colors.white, 0.3)! : tool.color;
        return InkWell(
          onTap: tool.onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, color: tint, size: 26),
                const SizedBox(height: Gap.xs),
                Text(
                  tool.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
                // Alt yazı yalnız BİLGİ taşıyorsa yazılır ("3 sürüyor",
                // "12 öğe"); "Ayrıntılar" gibi dolgu metinler gürültüdür.
                if (tool.subtitle.isNotEmpty)
                  Text(
                    tool.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
