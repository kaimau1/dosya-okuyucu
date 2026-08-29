import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Pano kutusunun verisi (ikon, renk, başlık, alt satır, dokunma).
class FmTileData {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  /// **Kullanım sayacının anahtarı** (yalnız araç ızgarasında anlamlı).
  ///
  /// Ekrandaki etiket DEĞİL: etiket çeviriye göre değişiyor ("Yer aç" /
  /// "Free space"), sayaç ise dil değişince sıfırlanmamalı. Boş bırakılırsa
  /// kutu sayılmaz (kategori kutuları kendi sırasını korur).
  final String id;

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
    this.id = '',
    this.pulse = false,
  });

  /// Yalnız dokunmayı saran kopya (pano, sayacı artırmak için kullanır).
  FmTileData withTap(VoidCallback onTap) => FmTileData(
        icon: icon,
        color: color,
        label: label,
        subtitle: subtitle,
        onTap: onTap,
        id: id,
        pulse: pulse,
      );
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

  /// Nefes alma bu süre sonunda **durur**.
  ///
  /// **PİL (2026-08-07 denetimi):** animasyon sonsuza kadar dönüyordu. Hareket
  /// eden tek bir piksel bile olsa Flutter her karede yeniden çizer: pano
  /// açıkken uygulama hiç boşa geçmiyor, 120 Hz ekranda saniyede 120 kare
  /// üretiliyordu — kullanıcı ekrana bakıp dururken bile. Kutunun işi
  /// **dikkat çekmek**; birkaç saniye sonra o iş bitmiştir ve ekran duruyorsa
  /// GPU da durmalıdır. Kutu bundan sonra da koyu zemin + renkle ayırt
  /// edilebilir kalıyor (aşağıdaki `data.pulse` zemin farkı).
  static const _pulseFor = Duration(seconds: 6);

  Timer? _stop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _stop?.cancel();
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating && _stop == null) {
      _controller.repeat(reverse: true);
      _stop = Timer(_pulseFor, () {
        if (!mounted) return;
        // Dinlenme boyutuna (1.0 ölçek) yumuşak dönüş — ortada kesilen bir
        // animasyon simgeyi büyük bırakıp "bozuk" görünürdü.
        _controller.animateBack(0, duration: const Duration(milliseconds: 400));
      });
    }
  }

  @override
  void dispose() {
    _stop?.cancel();
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
    // **Çerçevesiz, büyük simge** (kullanıcı 2026-08-17: *"dashboard
    // simgelerin çerçevesini kaldır, büyük sade simgeler haline gelsinler"*).
    // Eskiden 44 dp'lik yuvarlak köşeli renkli bir kutunun içinde 24 dp'lik
    // bir glif vardı: kutu gliften büyüktü, göz önce kutuyu görüyordu. Artık
    // glifin kendisi 38 dp — aynı yerde bir buçuk kat büyük ve daha sakin.
    // Kartın kendisi de kalktı: 12 renkli kutu yan yana duvar gibi görünüyordu.
    // 38 → 46 (ikinci tur: *"simgeleri olabildiğince büyüt"*). Dört sütunda
    // hücre ~76 dp; 46 dp glif hücrenin genişliğinin %60'ı — daha büyüğü
    // etiketi sıkıştırırdı.
    // 46 taban ölçü; tema ailesi bunu ölçekler (bkz. SkinMetrics.iconScale).
    final icon = Icon(data.icon, color: tint, size: 46 * context.fmIconScale);
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            data.pulse ? _PulsingIcon(key: pulseKey, child: icon) : icon,
            const SizedBox(height: Gap.xs),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            // Alt satır yalnız BİLGİ taşıyorsa (araç ızgarasındaki kuralla
            // aynı): dört sütunda dolgu metin satırı boşa yer yiyor.
            if (data.subtitle.isNotEmpty)
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kutuların ızgarası (pano ve Önemli Dosyalar aynı ölçüleri kullanır).
///
/// **Dört sütun** (kullanıcı 2026-08-17: *"3 değil 4 kolon olsun"*). Sabit
/// sütun sayısı, `maxCrossAxisExtent` değil: 150 dp'lik üst sınır dar
/// telefonda 2, geniş telefonda 3 sütun üretiyordu — kullanıcının gördüğü
/// düzen cihazına göre değişiyordu. Çok geniş ekranda (tablet) hücre
/// büyümesin diye sütun sayısı genişlikle artar.
class FmCategoryGrid extends StatelessWidget {
  final List<FmTileData> tiles;
  const FmCategoryGrid({super.key, required this.tiles});

  /// İki ızgaranın (içerik + araçlar) **ortak** sütun sayısı.
  ///
  /// Eskiden araç ızgarası `maxCrossAxisExtent: 96` ile ayrı hesaplıyordu:
  /// 480 dp'lik bir ekranda içerik 4, araçlar 5 sütun çiziyor ve pano boyunca
  /// sütunlar birbirini tutmuyordu. Tek kaynak → tek hiza.
  static int columnsFor(double width) => (width / 110).floor().clamp(4, 8);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = columnsFor(constraints.maxWidth);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 0.86,
              mainAxisSpacing: Gap.xs,
              crossAxisSpacing: Gap.xs,
            ),
            itemCount: tiles.length,
            itemBuilder: (context, i) => FmCategoryTile(data: tiles[i]),
          );
        },
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

  /// **Hücre yüksekliği ÖLÇÜLÜR, orandan gelmez.**
  ///
  /// Sabit en-boy oranı + sabit punto = büyütülmüş yazı ölçeğinde
  /// `RenderFlex overflowed` (aynı ders `fm_entry_tiles`de de var). Burada
  /// yükseklik simgeden ve etiketin GERÇEK satır yüksekliğinden toplanıyor;
  /// ölçek 1,0'da da 2,0'da da hücre metne yetiyor.
  static double cellHeight(BuildContext context, {required bool withSubtitle}) {
    final scaler = MediaQuery.textScalerOf(context);
    final icon = 34 * context.fmIconScale;
    // İki satırlık etiket: "Yeni belge oluştur", "Sohbet medyası" kırpılmak
    // yerine alt satıra iniyor (kullanıcı 2026-08-29: etiketler "…" ile
    // bitiyordu, hangi aracın ne olduğu okunmuyordu).
    final label = scaler.scale(11) * 1.25 * 2;
    final sub = withSubtitle ? scaler.scale(10) * 1.25 : 0.0;
    return icon + Gap.xs + label + sub + Gap.sm * 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Alt yazı satırı ızgaranın TAMAMI için ayrılır: yalnız "İşlemler"in alt
    // yazısı varken o hücre uzun, komşusu kısa kalıyor ve satır tırtıklı
    // görünüyordu. Hiçbirinde yoksa satır hiç açılmaz.
    final withSubtitle = tools.any((t) => t.subtitle.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = FmCategoryGrid.columnsFor(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: cellHeight(context, withSubtitle: withSubtitle),
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
                padding:
                    const EdgeInsets.symmetric(vertical: Gap.xs, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 26 → 34 (kullanıcı 2026-08-17); içerik kutularının
                    // 46'sından bir kademe küçük kalıyor, ağırlık hiyerarşisi
                    // korunuyor.
                    Icon(tool.icon, color: tint, size: 34 * context.fmIconScale),
                    const SizedBox(height: Gap.xs),
                    // `Flexible`: hesaplanan yükseklik yine de yetmezse metin
                    // taşmak yerine kırpılır — ızgara hiçbir ölçekte kırmızı
                    // şeritler göstermez.
                    Flexible(
                      child: Text(
                        tool.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(height: 1.15, fontSize: 11),
                      ),
                    ),
                    // Alt yazı yalnız BİLGİ taşıyorsa yazılır ("3 sürüyor",
                    // "12 öğe"); "Ayrıntılar" gibi dolgu metinler gürültüdür.
                    if (tool.subtitle.isNotEmpty)
                      Flexible(
                        child: Text(
                          tool.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
