import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/skin.dart';
import '../../core/theme.dart';
import '../motion.dart';
import '../../core/device_profile.dart';
import '../../core/app_colors.dart';
import '../../core/edition.dart';
import '../pro_gate.dart';
import 'fm_tile_art.dart';

export 'fm_tile_art.dart' show FmTileArt;

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

  /// Kendi çizimi olan kutular (Fotoğraflar, Videolar, Arşivler…) —
  /// bkz. [FmSquircleIcon]. Yoksa [icon] glifi çizilir.
  final FmTileArt? art;

  /// Sürüm kapısı (S2): verilirse ve bu sürümde yoksa kutu "PRO" rozetli
  /// çizilir, dokunma Pro levhasını açar (bkz. [ProGate]).
  final Feature? feature;

  const FmTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.id = '',
    this.pulse = false,
    this.art,
    this.feature,
  });

  /// Kapıdan geçmiş dokunma: sürümde yoksa Pro levhası.
  VoidCallback gatedTap(BuildContext context) =>
      feature == null ? onTap : ProGate.wrap(context, feature!, onTap);

  /// Kilitliyse simgeyi rozetler.
  Widget badged(Widget icon) =>
      feature == null ? icon : ProBadged(feature: feature!, child: icon);

  /// Yalnız dokunmayı saran kopya (pano, sayacı artırmak için kullanır).
  FmTileData withTap(VoidCallback onTap) => FmTileData(
        icon: icon,
        color: color,
        label: label,
        subtitle: subtitle,
        onTap: onTap,
        id: id,
        pulse: pulse,
        art: art,
        feature: feature,
      );
}

/// **Degrade simge** — pano kutularının ve araçların ortak glifi.
///
/// 2026-09-23 tasarım turu: çerçevesiz büyük simgeler (2026-08-17 kullanıcı
/// kararı) KALIYOR; değişen, simgenin kendisi. Düz tek renk Material glifi
/// dosya listesindeki çizilmiş, degradeli klasörlerin yanında "yapıştırma"
/// duruyordu. Şimdi aynı malzeme dili: üstten açık, alttan koyu tonlu geçiş —
/// klasör simgesiyle aynı ışık yönü. Klasik tema ailelerinde düz dolu
/// glif (eski tip dosya yöneticisi dili, 2026-11-08).
class FmTintedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  /// Simge dili; null = etkin tema ailesininki. Tema seçicinin önizlemesi
  /// henüz seçilmemiş ailenin dilini çizebilsin diye dışarıdan verilebilir.
  final SkinIconStyle? style;

  const FmTintedIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    switch (style ?? context.fmIconStyle) {
      case SkinIconStyle.classic:
        return Icon(icon, color: color, size: size);
      case SkinIconStyle.gradient:
        // **Katmansız degrade** (2026-10-17 başarım turu). Eskiden
        // `ShaderMask` ile çiziliyordu: her simge ayrı bir ekran dışı katman
        // (`saveLayer`) açıyor, panodaki ~15 kutu kaydırılırken her karede 15
        // katman birleştiriliyordu. Glif bir yazı tipi karakteri olduğu için
        // degrade doğrudan yazının fırçasına (`foreground`) verilebiliyor —
        // görüntü aynı, katman yok.
        return _GradientIcon(icon, color: color, size: size);
    }
  }
}

/// Degradeyle boyanmış simge. `Icon`dan türer: ağaçta yine bir `Icon`dur
/// (`find.byIcon`, erişilebilirlik), yalnız çizimi kendisi yapar.
class _GradientIcon extends Icon {
  const _GradientIcon(super.icon,
      {required Color super.color, required double super.size});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size!),
          painter: _GradientGlyphPainter(
            icon!,
            color!,
            size!,
            Directionality.maybeOf(context) ?? TextDirection.ltr,
          ),
        ),
      );
}

/// Glifi KENDİ koordinatında çizer. `RichText` + `foreground` denendi ve
/// yanlış çıktı: paragraf, tuvali kaydırmadan bir kaymayla çiziliyor, yani
/// fırçanın degradesi katmanın (0,0) noktasına göre değerlendiriliyordu —
/// ekranın ortasındaki simge degradenin koyu ucunda kalıyordu (ekran
/// görüntüsüyle yakalandı). `CustomPaint` tuvali kutunun köşesine taşıdığı
/// için degrade simgenin üstüne oturuyor.
class _GradientGlyphPainter extends CustomPainter {
  final IconData icon;
  final Color color;
  final double extent;
  final TextDirection direction;

  _GradientGlyphPainter(this.icon, this.color, this.extent, this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      textDirection: direction,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: extent,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontFamilyFallback: icon.fontFamilyFallback,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
          foreground: Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, AppColors.mixLight, 0.28)!,
                color,
                Color.lerp(color, AppColors.mixDark, 0.18)!,
              ],
              stops: const [0, 0.5, 1],
            ).createShader(Rect.fromLTWH(0, 0, extent, extent)),
        ),
      ),
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
    tp.dispose();
  }

  @override
  bool shouldRepaint(_GradientGlyphPainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.extent != extent ||
      old.direction != direction;
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
    // Hafif profilde süs nabzı kapalı (Faz 4).
    final reduced = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !DeviceProfile.budget.decorativeAnimations;
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
        scale: Tween<double>(
          begin: 1,
          end: 1.14,
        ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

/// Panonun kategori kutusu. **Ortak widget:** "Önemli Dosyalar" klasörü de
/// aynı kategorizasyonu gösteriyor (kullanıcı isteği 2026-07-29: "önemli
/// dosyalar klasörü ve ona yine ana sayfadaki formatta kategorizasyon") —
/// iki ekranın görünümü kopyalanırsa biri değişince diğeri geride kalırdı.
class FmCategoryTile extends StatelessWidget {
  final FmTileData data;

  /// Aynı satırdaki kardeş kutulardan birinde alt yazı varsa, alt yazısı boş
  /// olan kutuda da bir satırlık yer ayrılır; yoksa "Uygulamalar" simgesi
  /// yanındaki "Kitaplık (Kitap ekle)" simgesine göre aşağı kayar.
  final bool reserveSubtitle;

  const FmCategoryTile({
    super.key,
    required this.data,
    this.reserveSubtitle = false,
  });

  /// Nefes alan simgenin kimliği. Material'in kendi içinde de
  /// `ScaleTransition`lar var; test bizimkini tür yerine bununla bulur.
  static const pulseKey = ValueKey<String>('fm-tile-pulse');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final dark = theme.brightness == Brightness.dark;
    final tint =
        dark ? Color.lerp(data.color, AppColors.mixLight, 0.25)! : data.color;
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
    // **2026-11-04 tasarım turu:** degrade/dolgu ailelerde simge yumuşak
    // köşeli (squircle), açık renkli, gölgeli bir zemine oturur; Fotoğraflar,
    // Videolar, Arşivler… kendi 2.5D çizimiyle (bkz. [FmSquircleIcon]).
    // Çizgi ailelerinde sade glif kalır (o ailelerin sakin ağırlığı).
    final Widget icon = context.fmIconStyle == SkinIconStyle.classic
        ? FmTintedIcon(
            icon: data.icon,
            color: tint,
            size: 46 * context.fmIconScale,
          )
        : FmSquircleIcon(
            icon: data.icon,
            color: data.color,
            art: data.art,
            size: 46 * context.fmIconScale,
          );
    final labelH = scaler.scale(12) * 1.25;
    final subH = scaler.scale(10) * 1.25;
    // Basınca hafifçe çöker (iOS dokunsal hissi — bkz. widgets/motion.dart).
    return PressScale(
      child: InkWell(
        onTap: data.gatedTap(context),
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              data.badged(
                  data.pulse ? _PulsingIcon(key: pulseKey, child: icon) : icon),
              const SizedBox(height: Gap.xs),
              // Yazı bir kademe küçük ve ince (2026-11-04: "ekran nefes
              // alsın"). Dar ekranda / büyütülmüş yazıda "..." ile kesilmek
              // yerine hücreye sığacak kadar küçülür.
              SizedBox(
                height: labelH,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
              // Alt satır yalnız BİLGİ taşıyorsa (araç ızgarasındaki kuralla
              // aynı): dört sütunda dolgu metin satırı boşa yer yiyor.
              if (data.subtitle.isNotEmpty || reserveSubtitle)
                SizedBox(
                  height: subH,
                  child: data.subtitle.isEmpty
                      ? null
                      : Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              data.subtitle,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall
                                  ?.merge(context.type.micro)
                                  .copyWith(
                                    height: 1.15,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                            ),
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

/// Kutuların ızgarası (pano ve Önemli Dosyalar aynı ölçüleri kullanır).
///
/// **Dört sütun** (kullanıcı 2026-08-17: *"3 değil 4 kolon olsun"*). Sabit
/// sütun sayısı, `maxCrossAxisExtent` değil: 150 dp'lik üst sınır dar
/// telefonda 2, geniş telefonda 3 sütun üretiyordu — kullanıcının gördüğü
/// düzen cihazına göre değişiyordu. Çok geniş ekranda (tablet) hücre
/// büyümesin diye sütun sayısı genişlikle artar; çok büyük yazı ölçeğinde
/// (1,3× / 2×) ise metinler kesilmesin diye 3 veya 2 sütuna düşer.
class FmCategoryGrid extends StatelessWidget {
  final List<FmTileData> tiles;
  const FmCategoryGrid({super.key, required this.tiles});

  /// İki ızgaranın (içerik + araçlar) **ortak** sütun sayısı.
  ///
  /// Eskiden araç ızgarası `maxCrossAxisExtent: 96` ile ayrı hesaplıyordu:
  /// 480 dp'lik bir ekranda içerik 4, araçlar 5 sütun çiziyor ve pano boyunca
  /// sütunlar birbirini tutmuyordu. Tek kaynak → tek hiza.
  static int columnsFor(double width, {double textScale = 1.0}) {
    final effective = width / math.max(1.0, textScale);
    if (effective < 190) return 2;
    if ((textScale >= 1.25 && effective < 285) || width < 290) return 3;
    return (width / 110).floor().clamp(4, 8);
  }

  /// Öğe sayısına göre tek satır/öksüz artıkları önleyen sütun sayısı
  /// (ör. 12 kategori tablette 5+5+2 yerine 4×3, 6 öğe 5+1 yerine 6/3).
  static int balancedColumns(double width, int count,
      {double textScale = 1.0}) {
    final base = columnsFor(width, textScale: textScale);
    if (count <= 0 || textScale >= 1.25) return base;
    if (count == 6 && (base == 4 || base == 5)) return width >= 620 ? 6 : 3;
    if ((count == 7 || count == 8 || count == 12) &&
        base >= 5 &&
        base <= 7) {
      return 4;
    }
    return base;
  }

  /// Hücre yüksekliği: en-boy oranından gelen taban yüksekliği, simge + iki
  /// satır metnin gerçek yüksekliğinin altına düşemez (`RenderFlex overflowed`
  /// önlemi).
  static double cellHeight(
    BuildContext context,
    double tileWidth, {
    double aspect = 0.94,
    double? iconExtent,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final icon = iconExtent ?? (46 * context.fmIconScale);
    final text = scaler.scale(12) * 1.25 + scaler.scale(10) * 1.25;
    return math.max(tileWidth / aspect, icon + text + Gap.xs * 3 + 4);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = balancedColumns(
            constraints.maxWidth,
            tiles.length,
            textScale: scale,
          );
          final w =
              (constraints.maxWidth - Gap.xs * (columns - 1)) / columns;
          final withSub = tiles.any((t) => t.subtitle.isNotEmpty);
          return GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cellHeight(context, w),
              mainAxisSpacing: Gap.xs,
              crossAxisSpacing: Gap.xs,
            ),
            itemCount: tiles.length,
            itemBuilder: (context, i) => FmCategoryTile(
              data: tiles[i],
              reserveSubtitle: withSub,
            ),
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
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = tools.length == 8 &&
                constraints.maxWidth >= 320 &&
                scale < 1.3
            ? 4
            : FmCategoryGrid.columnsFor(constraints.maxWidth, textScale: scale);
        return GridView.builder(
          padding: EdgeInsets.zero,
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
                dark ? Color.lerp(tool.color, AppColors.mixLight, 0.3)! : tool.color;
            return PressScale(
              child: InkWell(
                onTap: tool.gatedTap(context),
                borderRadius: BorderRadius.circular(Radii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Gap.xs,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 26 → 34 (kullanıcı 2026-08-17); içerik kutularının
                      // 46'sından bir kademe küçük kalıyor, ağırlık hiyerarşisi
                      // korunuyor.
                      tool.badged(FmTintedIcon(
                        icon: tool.icon,
                        color: tint,
                        size: 34 * context.fmIconScale,
                      )),
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
                              ?.copyWith(height: 1.15),
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
                            style: theme.textTheme.labelSmall
                                ?.merge(context.type.micro)
                                .copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
