import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart' show XmlElement;

import '../services/pptx_render.dart';
import 'chart_painter.dart';
import 'slide_frame_editor.dart';
import '../core/app_colors.dart';

/// Slayt run'ının çizim stili (punto biriminde). Kanvas ve düzenleyici
/// ([SlideTextController]) AYNI kuralla çizer — yazarken ve Bitti'den sonra
/// yazı birebir aynı görünsün.
TextStyle slideRunStyle({
  String? family,
  required double size,
  bool bold = false,
  bool italic = false,
  bool underline = false,
  required Color color,
  required double height,
}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      color: color,
      height: height,
    );

/// Slayt görsellerinin çözüleceği en uzun kenar (piksel).
///
/// **Bellek (2026-09-23 denetimi):** PPTX'teki fotoğraflar çoğu zaman kamera
/// çözünürlüğünde (4000×3000) gömülü ve `Image.memory` onları TAM çözüyordu —
/// görsel başına ~48 MB; fotoğraflı bir destede birkaç slayt gezinmek düşük
/// bellekli telefonda uygulamayı öldürmeye yetiyordu. Slayt en büyük ekranda
/// (ve PDF'e 2× aktarmada: 960 pt → 1920 px) bu kadar pikselden fazlasını
/// göstermiyor.
const slideImageMaxEdge = 2560;

/// Slayt görselinin sağlayıcısı. **Tek kaynak:** [SlideCanvas] ve PDF'e
/// aktarmadaki önbelleğe alma (`SlideSnapshot`) AYNI anahtarı kullanmalı —
/// ayrı anahtar, aktarmada görselin önbellekte bulunamayıp slaydın
/// görselsiz basılması demekti.
ImageProvider slideImageProvider(Uint8List bytes) => ResizeImage(
      MemoryImage(bytes),
      width: slideImageMaxEdge,
      height: slideImageMaxEdge,
      policy: ResizeImagePolicy.fit,
    );

/// Bir slaytı orijinal tasarımıyla (arka plan, şekiller, görseller, biçimli
/// metin) çizer. Ölçü birimi punto; [FittedBox] ile kullanılabilir genişliğe
/// orantılı olarak ölçeklenir — yani her ekranda PowerPoint'teki yerleşimin
/// aynısı görünür.
class SlideCanvas extends StatelessWidget {
  final SlideVM slide;

  /// Metin kutusuna dokunulduğunda çağrılır (düzenleme için). null ise salt okunur.
  final void Function(ShapeVM shape)? onEditShape;

  /// Faz 28 — seç / düzenle ayrımı (PowerPoint mobil): verilirse şekle İLK
  /// dokunuş onu seçer, seçili şekle ikinci dokunuş (ya da çift dokunuş)
  /// [onEditShape]'i çağırır. null ise eski davranış (dokun = düzenle).
  final void Function(ShapeVM shape)? onSelectShape;

  /// Seçili şekil (çerçeve + tutamaklar çizilir).
  final ShapeVM? selectedShape;

  /// Şu an **canlı düzenlenen** şekil. O kutunun metni yerine
  /// [editorBuilder]'ın verdiği editör çizilir. Kimlikle (identical) eşlenir.
  final ShapeVM? editingShape;

  /// Düzenlenen kutunun editörü (kutunun iç boşluğu içinde, punto biriminde).
  final Widget Function(ShapeVM shape)? editorBuilder;

  /// Boş yer tutucunun istem metni ("Başlık eklemek için dokunun"); null =
  /// istem çizilmez (sunum, PDF, küçük resim).
  final String Function(String placeholderType)? promptFor;

  /// Kaçıncı animasyon adımına kadar görünsün. null = her şey görünür
  /// (düzenleme görünümü). Sunum modunda 0'dan başlar, her tıklamada artar.
  final int? step;

  /// Faz 29 — seçili şeklin çerçevesi sürüklenip bırakılınca (taşı /
  /// boyutlandır / döndür): yeni çerçeve (pt) ve dönüş (derece).
  final void Function(ShapeVM shape, Rect frame, double rotationDeg)?
      onFrameChanged;

  const SlideCanvas({
    super.key,
    required this.slide,
    this.onEditShape,
    this.onSelectShape,
    this.selectedShape,
    this.editingShape,
    this.editorBuilder,
    this.promptFor,
    this.step,
    this.onFrameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // 1 dp'nin punto karşılığı (tutamak boyutları için).
      final scale = math.min(
          box.maxWidth.isFinite ? box.maxWidth / slide.widthPt : double.infinity,
          box.maxHeight.isFinite ? box.maxHeight / slide.heightPt : double.infinity);
      final unit = scale.isFinite && scale > 0 ? 1 / scale : 1.0;
      return _canvas(unit);
    });
  }

  Widget _canvas(double unit) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: slide.widthPt,
        height: slide.heightPt,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: slide.backgroundGradient == null
                        ? (slide.background ?? AppColors.page)
                        : null,
                    gradient: slide.backgroundGradient,
                  ),
                  child: slide.backgroundImage == null
                      ? null
                      : Image(
                          image: slideImageProvider(slide.backgroundImage!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                ),
              ),
              for (final shape in slide.shapes) _positioned(shape, unit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positioned(ShapeVM s, double unit) {
    // Animasyonlu içerik: adımı gelmemiş şekil/paragraf saydamdır (yer tutar,
    // böylece belirdiğinde yerleşim oynamaz — PowerPoint de böyle yapar).
    final animated = step != null && slide.steps.isNotEmpty;
    List<bool>? paraVisible;
    var shapeVisible = true;
    if (animated) {
      final shapeStep = slide.stepFor(s.id, -1);
      shapeVisible = shapeStep == 0 || step! >= shapeStep;
      paraVisible = [
        for (var i = 0; i < s.paragraphs.length; i++)
          slide.stepFor(s.id, i) == 0 || step! >= slide.stepFor(s.id, i),
      ];
    }

    final editing = editingShape != null && identical(s, editingShape);
    final selected = !editing &&
        selectedShape != null &&
        identical(s, selectedShape);
    final prompt = promptFor != null && s.isEmptyPlaceholder
        ? promptFor!(s.placeholderType!)
        : null;
    Widget child = _ShapeBody(
      shape: s,
      paraVisible: paraVisible,
      editor: editing ? editorBuilder?.call(s) : null,
      prompt: prompt,
    );
    if (animated) child = _Reveal(visible: shapeVisible, child: child);
    // Grup içindeki şekil de çerçeveyle taşınır (Faz 29 kalanı; düzenleyici
    // grup dönüşümünü tersine çevirir).
    final parentName = (s.element?.parent as XmlElement?)?.name.qualified;
    final framed = selected &&
        onFrameChanged != null &&
        (parentName == 'p:spTree' || parentName == 'p:grpSp');
    if (s.rotationDeg != 0 && !framed) {
      child = Transform.rotate(angle: s.rotationDeg * math.pi / 180, child: child);
    }
    // Tablo hücresi boşken de dokunulup yazılabilir (Faz 29b: tablo ekle).
    final tappable = s.hasText ||
        prompt != null ||
        (onSelectShape != null && s.element != null) ||
        (s.cellBorder != null && s.paragraphs.any((p) => p.source != null));
    if (editing) {
      // Aktif kutuyu çerçeveyle belirt; dokunuşlar içteki editöre gitsin
      // (onTap sarmalamayı atla, yoksa düzenlemeyi yeniden tetikler).
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.slideSelection, width: 1.2),
        ),
        child: child,
      );
    } else if (onEditShape != null && tappable) {
      final select = onSelectShape;
      // Tablo hücresi gibi slayt düzeyinde düğümü olmayan metin seçilemez;
      // dokunuş doğrudan düzenler. Çift dokunuş için ayrı tanıyıcı YOK:
      // olsaydı her tek dokunuş 300 ms bekletilirdi; çift dokunuşun ilk
      // dokunuşu seçer, ikincisi seçili şekli düzenler.
      final canSelect = select != null && s.element != null;
      final spoken = s.paragraphs.map((p) => p.plainText).join(' ').trim();
      child = Semantics(
        // TalkBack (Faz 33): şeklin yazısı (ya da yer tutucunun daveti).
        container: true,
        button: true,
        selected: selected,
        label: spoken.isNotEmpty
            ? (spoken.length > 120 ? '${spoken.substring(0, 120)}…' : spoken)
            : prompt,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Seçili tablo çerçevesi: yazı yok, yalnız taşınır.
            if (s.tableFrame && selected) return;
            if (!canSelect ||
                selected ||
                (prompt != null && s.element == null)) {
              onEditShape!(s);
            } else {
              select(s);
            }
          },
          // Tablo hücresine uzun bas → tablonun tamamı seçilir (taşı /
          // boyutlandır), PowerPoint'te çerçeveye dokunmanın karşılığı.
          onLongPress: select != null && s.cellBorder != null
              ? () {
                  for (final o in slide.shapes) {
                    if (o.tableFrame && o.id == s.id) {
                      select(o);
                      return;
                    }
                  }
                }
              : null,
          child: selected && !framed
              ? CustomPaint(
                  foregroundPainter: const _SelectionPainter(), child: child)
              : child,
        ),
      );
      if (framed) {
        return SlideFrameEditor(
          shape: s,
          unit: unit,
          slideW: slide.widthPt,
          slideH: slide.heightPt,
          onCommit: (r, rot) => onFrameChanged!(s, r, rot),
          others: [
            for (final o in slide.shapes)
              if (!identical(o, s) && o.element != null && o.rotationDeg == 0)
                Rect.fromLTWH(o.x, o.y, o.w, o.h),
          ],
          child: child,
        );
      }
    }
    // Yatay/dikey çizginin tek boyutu 0 olabilir → çizim için stroke kadar taban ver.
    final floor = math.max(s.strokeWidth, 1.0);
    return Positioned(
      left: s.x,
      top: s.y,
      width: s.isLine ? math.max(s.w, floor) : s.w,
      height: s.isLine ? math.max(s.h, floor) : s.h,
      child: child,
    );
  }
}

/// Adımı gelen içeriği hafifçe yukarı kayarak belirtir — jenerik ama
/// PowerPoint'teki "beliriş" hissini verir.
class _Reveal extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _Reveal({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    // Yapı iki durumda da aynı kalmalı, yoksa geçiş animasyonu oynamaz.
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _ShapeBody extends StatelessWidget {
  final ShapeVM shape;

  /// Paragraf bazlı görünürlük (animasyon adımları). null = hepsi görünür.
  final List<bool>? paraVisible;

  /// Canlı düzenleme editörü (kutunun metni yerine). null = statik metin.
  final Widget? editor;

  /// Boş yer tutucunun gri istem metni.
  final String? prompt;

  const _ShapeBody(
      {required this.shape, this.paraVisible, this.editor, this.prompt});

  @override
  Widget build(BuildContext context) {
    // Bağlayıcı/çizgi: kutu değil, köşe-köşe stroke (ok/kesik dahil).
    if (shape.isLine) {
      return CustomPaint(painter: _LinePainter(shape), size: Size.infinite);
    }

    // Grafik: veri modelini çizen ChartPainter.
    if (shape.chart != null) {
      return CustomPaint(
          painter: ChartPainter(shape.chart!), size: Size.infinite);
    }

    // Tablo hücresi kenar-başına kenarlık taşır; diğer şekiller tekil stroke.
    final border = shape.cellBorder ??
        (shape.stroke == null
            ? null
            : Border.all(color: shape.stroke!, width: shape.strokeWidth));
    final radius = shape.cornerRadius == 0
        ? null
        : BorderRadius.circular(shape.cornerRadius);

    final decoration = BoxDecoration(
      color: shape.gradient == null ? shape.fill : null,
      gradient: shape.gradient,
      borderRadius: radius,
      // Görselli şekilde çerçeve ÖN plana alınır (aşağıya bak).
      border: shape.image == null ? border : null,
      boxShadow: shape.shadow == null ? null : [shape.shadow!],
    );

    if (shape.image != null) {
      // Görsel: `a:srcRect` kırpması + aynalama. PowerPoint görseli kutuya
      // GERER (stretch), o yüzden `BoxFit.fill`.
      Widget img = _CroppedImage(bytes: shape.image!, crop: shape.crop);
      // Yatay/dikey aynalama (`a:xfrm@flipH/flipV`): görsel merkez etrafında
      // çevrilir. Eskiden flip yalnız çizgilerde uygulanıyordu → aynalanmış
      // görseller/oklar ters çıkıyordu.
      if (shape.flipH || shape.flipV) {
        img = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
              shape.flipH ? -1.0 : 1.0, shape.flipV ? -1.0 : 1.0, 1.0),
          child: img,
        );
      }
      // Çerçeve görselin ÜSTÜNE çizilir: arka planda kalsaydı görselin
      // altında kaybolurdu — PowerPoint'te kenarlıklı bir fotoğrafın
      // çerçevesi bizde hiç görünmüyordu.
      //
      // Dikdörtgen olmayan geometri (ör. elips çerçeveli fotoğraf) görseli de
      // şekle kırpar; kutu şekillerde ucuz `ClipRect` yeter.
      if (!shape.isBoxShaped) {
        return CustomPaint(
          painter: _GeometryPainter(shape, stroke: false),
          foregroundPainter: _GeometryPainter(shape, fill: false),
          child: ClipPath(clipper: _GeometryClipper(shape), child: img),
        );
      }
      return ClipRect(
        child: Container(
          decoration: decoration,
          foregroundDecoration: border == null
              ? null
              : BoxDecoration(border: border, borderRadius: radius),
          child: img,
        ),
      );
    }

    final body = editor != null
        ? _editorBody(shape, editor!)
        : shape.hasText
            ? _text(shape)
            : prompt != null
                ? _promptBody(shape, prompt!)
                : null;

    // Ön tanımlı şekil (üçgen/ok/elmas/yıldız/akış şeması…): kutu yerine
    // vektör yol. Metin yolun ÜSTÜNDE, PowerPoint'teki gibi kutu alanına
    // yerleşir (şeklin kendi metin dikdörtgeni ayrıca hesaplanmıyor).
    if (!shape.isBoxShaped) {
      return CustomPaint(
        painter: _GeometryPainter(shape),
        child: body ?? const SizedBox.expand(),
      );
    }

    return Container(decoration: decoration, child: body);
  }

  /// Metin kutusu: PowerPoint'te olduğu gibi sığmayan yazı kutunun dışına taşar
  /// (kırpılmaz). [OverflowBox] hem taşmayı serbest bırakır hem de dikey
  /// hizalamayı (üst/orta/alt) uygular. Fontlar artık metrik-uyumlu (Carlito/
  /// Arimo/Tinos) gömülü olduğu için ölçüm PowerPoint'le hemen hemen aynı;
  /// `_fitScale` çoğu kutuda 1 döner, yalnız gerçek taşmada devreye girer.
  Widget _text(ShapeVM s) {
    Alignment alignment;
    switch (s.vAnchor) {
      case 'ctr':
        alignment = Alignment.center;
        break;
      case 'b':
        alignment = Alignment.bottomCenter;
        break;
      default:
        alignment = Alignment.topCenter;
    }

    // Sığdırma TÜM metin kutularına güvenlik ağı olarak uygulanır: metrik-uyumlu
    // fontlarla ölçüm artık doğru (gerçekten sığan kutuda 1 döner), ama bir kutu
    // yine de taşarsa (yazar taşırmış ya da kenar durumu) komşu kutuların üstüne
    // binmesin diye küçültülür — okunurluk > birebir sadakat (kök neden #3).
    var scale = s.fontScale * _fitCache(s);

    return OverflowBox(
      alignment: alignment,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Padding(
        padding: s.inset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < s.paragraphs.length; i++)
              if (s.paragraphs[i].plainText.isNotEmpty)
                paraVisible == null
                    ? _paragraph(s.paragraphs[i], scale, s.lnSpcReduction)
                    : _Reveal(
                        visible: paraVisible![i],
                        child:
                            _paragraph(s.paragraphs[i], scale, s.lnSpcReduction),
                      ),
          ],
        ),
      ),
    );
  }

  /// Sığdırma ölçeği şekil başına BİR kez ölçülür (Faz 28 / SL7: eskiden
  /// her build'de iki TextPainter geçişi). Şekil nesnesi değişmez; slayt
  /// yeniden çizilince yeni şekil nesnesi yeni ölçüm demektir.
  static final _fitMemo = Expando<double>('slideFit');

  double _fitCache(ShapeVM s) =>
      _fitMemo[s] ??= _fitScale(s, s.fontScale);

  Alignment get _anchor => switch (shape.vAnchor) {
        'ctr' => Alignment.center,
        'b' => Alignment.bottomCenter,
        _ => Alignment.topCenter,
      };

  /// Düzenlenen kutu: editör kutunun iç boşluğunda, taşmaya izinli.
  Widget _editorBody(ShapeVM s, Widget editor) => OverflowBox(
        alignment: _anchor,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Padding(padding: s.inset, child: editor),
      );

  /// Boş yer tutucu: PowerPoint'in istem metni, gri, kesik çerçeveyle.
  Widget _promptBody(ShapeVM s, String text) {
    final look = s.paragraphs.isEmpty ? null : s.paragraphs.first.endLook;
    final size = (look?.sizePt ?? 18) * s.fontScale;
    return CustomPaint(
      painter: const _PromptFramePainter(),
      child: Padding(
        padding: s.inset,
        child: Align(
          alignment: _anchor,
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: s.placeholderType == 'title' ||
                    s.placeholderType == 'ctrTitle' ||
                    s.placeholderType == 'subTitle'
                ? TextAlign.center
                : TextAlign.start,
            style: TextStyle(
              fontFamily: look?.fontFamily,
              fontSize: size,
              color: AppColors.slidePrompt,
            ),
          ),
        ),
      ),
    );
  }

  /// Kutuya sığması için gereken ek ölçek (1 = küçültme gerekmez).
  static double _fitScale(ShapeVM s, double baseScale) {
    final availW = s.w - s.inset.horizontal;
    final availH = s.h - s.inset.vertical;
    if (availW <= 0 || availH <= 0) return 1;

    double measure(double sc) {
      var total = 0.0;
      for (final p in s.paragraphs) {
        if (p.plainText.isEmpty) continue;
        final tp = TextPainter(
          text: _span(p, sc, s.lnSpcReduction),
          textAlign: p.align,
          textDirection: TextDirection.ltr,
        )..layout(
            maxWidth: math.max(
                1, availW - p.indentPt - (p.bullet.isEmpty ? 0 : 14)));
        total += tp.height + p.spaceBeforePt + p.spaceAfterPt;
        tp.dispose();
      }
      return total;
    }

    final total = measure(baseScale);
    if (total <= 0 || total <= availH) return 1;
    // Tek geçişli oran güvenli üst sınır sanılıyordu ama sarma yüzünden
    // yetmeyebiliyor: font küçülünce satır sayısı her zaman aynı oranda
    // azalmaz (uzun kelimeler yeniden sarar). İkinci ölçüm turu gerçek
    // yüksekliği doğrular, hâlâ taşıyorsa oranı bir kez daha sıkar.
    var fit = availH / total;
    final second = measure(baseScale * math.max(0.35, fit));
    if (second > availH) fit *= availH / second;
    return math.max(0.35, fit);
  }

  static TextSpan _span(ParaVM p, double fontScale, double lnSpcReduction) {
    return TextSpan(
      children: [
        for (final r in p.runs)
          TextSpan(
            text: r.text,
            style: slideRunStyle(
              family: r.fontFamily,
              size: r.sizePt * fontScale,
              bold: r.bold,
              italic: r.italic,
              underline: r.underline,
              color: r.color,
              height: p.lineHeight * (1 - lnSpcReduction),
            ),
          ),
      ],
    );
  }

  Widget _paragraph(ParaVM p, double fontScale, double lnSpcReduction) {
    final first = p.runs.isEmpty ? null : p.runs.first;
    final Widget body =
        Text.rich(_span(p, fontScale, lnSpcReduction), textAlign: p.align);

    return Padding(
      padding: EdgeInsets.only(
          top: p.spaceBeforePt, bottom: p.spaceAfterPt, left: p.indentPt),
      child: p.bullet.isEmpty
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    p.bullet,
                    style: TextStyle(
                      fontFamily: first?.fontFamily,
                      fontSize: (first?.sizePt ?? 18) * fontScale,
                      color: first?.color,
                      height: p.lineHeight * (1 - lnSpcReduction),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }
}

/// Ön tanımlı şekli (`a:prstGeom`) vektör yol olarak çizer: gölge → dolgu
/// (düz ya da gradyan) → kenarlık. `BoxDecoration` yalnız dikdörtgen ve elips
/// çizebildiği için üçgen/ok/elmas/yıldız/akış şeması kutuları bu sınıftan
/// önce ekranda **düz dikdörtgen** görünüyordu.
class _GeometryPainter extends CustomPainter {
  final ShapeVM s;

  /// Gölge + dolgu çizilsin mi (görselli şekilde arka plan katmanı).
  final bool fill;

  /// Kenarlık çizilsin mi (görselli şekilde ÖN plan katmanı — bkz. `_ShapeBody`).
  final bool stroke;

  const _GeometryPainter(this.s, {this.fill = true, this.stroke = true});

  /// Yol + [ShapeVM.flipH]/[ShapeVM.flipV] aynalaması. Ayna şeklin kendi
  /// merkezine göredir (PowerPoint de öyle çevirir).
  ///
  /// [fillOnly]: özel geometride `fill="none"` alt yolları dışarıda bırakır
  /// (dolgu/gölge katmanı için); ön tanımlı şekillerde fark etmez.
  static Path? pathFor(ShapeVM s, Size size, {bool fillOnly = false}) {
    final path = s.custom != null
        ? s.custom!.build(size, fillOnly: fillOnly)
        : PptxPresetShape.build(s.preset, size, s.adjust);
    if (path == null || (!s.flipH && !s.flipV)) return path;
    final m = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..scaleByDouble(s.flipH ? -1.0 : 1.0, s.flipV ? -1.0 : 1.0, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
    return path.transform(m.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathFor(s, size);
    if (path == null) return;
    // Dolgu/gölge, `fill="none"` alt yolları içermeyen yola basılır — onları
    // doldurmak açık bir eğriyi kapalı lekeye çevirirdi. Özel geometri yoksa
    // iki yol aynıdır (ikinci hesap yapılmaz).
    final fillPath = s.custom == null ? path : pathFor(s, size, fillOnly: true);
    final rect = Offset.zero & size;

    final shadow = fill && fillPath != null ? s.shadow : null;
    if (shadow != null) {
      canvas.drawPath(
        fillPath!.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = shadow.blurRadius <= 0
              ? null
              : MaskFilter.blur(
                  BlurStyle.normal, _sigma(shadow.blurRadius)),
      );
    }

    if (fill && fillPath != null && s.gradient != null) {
      canvas.drawPath(
          fillPath, Paint()..shader = s.gradient!.createShader(rect));
    } else if (fill && fillPath != null && s.fill != null) {
      canvas.drawPath(fillPath, Paint()..color = s.fill!);
    }

    if (stroke && s.stroke != null && s.strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = s.stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// `BoxShadow.blurRadius` → Gauss sigması (Flutter'ın kendi dönüşümü).
  static double _sigma(double radius) => radius * 0.57735 + 0.5;

  @override
  bool shouldRepaint(_GeometryPainter old) =>
      !identical(old.s, s) || old.fill != fill || old.stroke != stroke;
}

/// Şekil geometrisiyle kırpar (elips/yıldız çerçeveli fotoğraflar için).
class _GeometryClipper extends CustomClipper<Path> {
  final ShapeVM s;
  const _GeometryClipper(this.s);

  @override
  Path getClip(Size size) =>
      _GeometryPainter.pathFor(s, size) ?? (Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(_GeometryClipper old) => !identical(old.s, s);
}

/// Görseli kutuya gerer; `a:srcRect` verilmişse önce KIRPAR.
///
/// PowerPoint kırpmayı kaynağın kenarlarından atılan oran olarak saklar;
/// görünen parça yine kutunun tamamını doldurur. Bu yüzden görsel `1/(1-l-r)`
/// oranında büyütülüp `-l` kadar kaydırılır — böylece yalnız istenen kadraj
/// kutuda kalır. Kırpma yok sayıldığında fotoğraf hem yanlış yerinden
/// görünüyor hem de yatay/dikey oranı bozuluyordu.
class _CroppedImage extends StatelessWidget {
  final Uint8List bytes;
  final Rect? crop;
  const _CroppedImage({required this.bytes, this.crop});

  @override
  Widget build(BuildContext context) {
    final img = Image(
      image: slideImageProvider(bytes),
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => const SizedBox(),
    );
    final c = crop;
    if (c == null) return img;
    final fw = 1 - c.left - c.right;
    final fh = 1 - c.top - c.bottom;
    if (fw <= 0 || fh <= 0) return img;
    return ClipRect(
      child: LayoutBuilder(
        builder: (_, box) {
          final w = box.maxWidth, h = box.maxHeight;
          if (!w.isFinite || !h.isFinite) return img;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -c.left * w / fw,
                top: -c.top * h / fh,
                width: w / fw,
                height: h / fh,
                child: img,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bağlayıcı/çizgi çizer: kutunun köşesinden karşı köşesine (flip'e göre) bir
/// stroke; kesikliyse kesik, uçlarda ok başı. Eğik/kavisli bağlayıcı düz
/// çizgiyle yaklaşıklanır (uç noktalar aynı kalır).
class _LinePainter extends CustomPainter {
  final ShapeVM s;
  const _LinePainter(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final color = s.stroke ?? AppColors.pageInk;
    final sw = s.strokeWidth <= 0 ? 1.0 : s.strokeWidth;
    final start = Offset(s.flipH ? size.width : 0, s.flipV ? size.height : 0);
    final end = Offset(s.flipH ? 0 : size.width, s.flipV ? 0 : size.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (s.dashed) {
      _dash(canvas, start, end, paint, sw);
    } else {
      canvas.drawLine(start, end, paint);
    }

    if (s.arrowEnd) _arrow(canvas, start, end, color, sw);
    if (s.arrowStart) _arrow(canvas, end, start, color, sw);
  }

  /// [to] ucunda, [from]→[to] yönünde dolu üçgen ok başı.
  void _arrow(Canvas canvas, Offset from, Offset to, Color color, double sw) {
    final dir = to - from;
    final len = dir.distance;
    if (len < 0.01) return;
    final u = dir / len;
    final head = math.max(sw * 3.5, 6.0); // ok boyu çizgi kalınlığıyla ölçekli
    final perp = Offset(-u.dy, u.dx);
    final base = to - u * head;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + perp.dx * head * 0.5, base.dy + perp.dy * head * 0.5)
      ..lineTo(base.dx - perp.dx * head * 0.5, base.dy - perp.dy * head * 0.5)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint, double sw) {
    final total = (b - a).distance;
    if (total < 0.01) return;
    final u = (b - a) / total;
    final dash = sw * 4, gap = sw * 3;
    var d = 0.0;
    while (d < total) {
      canvas.drawLine(
          a + u * d, a + u * math.min(d + dash, total), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.s != s;
}

/// Seçili şeklin çerçevesi + sekiz tutamak (Faz 28; taşı/boyutlandır Faz 29).
class _SelectionPainter extends CustomPainter {
  const _SelectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const blue = AppColors.slideSelection;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Tutamaklar kanvasın punto biriminde; slayt ~0,4 ölçekte çizildiği için
    // 6 pt ≈ ekranda 2–3 dp — görünür ama metni örtmez.
    final r = (math.min(size.width, size.height) * 0.06).clamp(3.0, 7.0);
    final fill = Paint()..color = AppColors.page;
    final edge = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final dx in [0.0, size.width / 2, size.width]) {
      for (final dy in [0.0, size.height / 2, size.height]) {
        if (dx == size.width / 2 && dy == size.height / 2) continue;
        canvas.drawCircle(Offset(dx, dy), r, fill);
        canvas.drawCircle(Offset(dx, dy), r, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => false;
}

/// Boş yer tutucunun kesik çizgili çerçevesi (PowerPoint'teki gibi).
class _PromptFramePainter extends CustomPainter {
  const _PromptFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.slidePromptFrame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 6.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total <= 0) return;
      final u = (b - a) / total;
      for (var d = 0.0; d < total; d += dash + gap) {
        canvas.drawLine(a + u * d, a + u * math.min(d + dash, total), paint);
      }
    }

    final w = size.width, h = size.height;
    line(Offset.zero, Offset(w, 0));
    line(Offset(w, 0), Offset(w, h));
    line(Offset(w, h), Offset(0, h));
    line(Offset(0, h), Offset.zero);
  }

  @override
  bool shouldRepaint(_PromptFramePainter old) => false;
}
