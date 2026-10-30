import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../services/pdf/pdf_form.dart';
import '../services/pdf/pdf_pending_objects.dart';

/// PDF düzenleyicinin **sayfa üstü katmanları** (Faz 31, 2026-10-30):
/// * [PdfTransformBox] — seçili nesnenin taşı + **dört köşeden** boyutlandır
///   kutusu (oran kilidi isteğe bağlı; PD6: eskiden yalnız sağ-alt köşe);
/// * [PdfPendingObjectLayer] — kaydedilene kadar nesne olarak yaşayan
///   yazı / imza / görseller (PD3);
/// * [PdfInlineParagraphEditor] — paragrafın KENDİ kutusunda düzenleme alanı
///   (PD1: eskiden 8 satırlık diyalog);
/// * [PdfFormOverlay] — form alanlarını sayfanın üstünde doldurma (PD5).
///
/// Hepsi pdfrx'in `pageOverlaysBuilder` katmanında, yani belge koordinatında
/// çizilir ve görüntüleyicinin yakınlaştırmasıyla birlikte büyür. Jest kuralı
/// `PdfEditOverlay` ile aynı: sayfanın tamamını kaplayan tanıyıcı YOK —
/// seçim dokunuşla, sürükleme yalnız seçili nesnenin kutusunda.

/// Sayfa üstündeki yazma alanlarının süslemesiz hâli: uygulama temasının
/// dolgu/çerçevesi (`InputDecorationTheme`) belgenin üstünde yabancı durur.
const _bare = InputDecoration(
  isCollapsed: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

/// Taşınır / dört köşeden boyutlanır kutu.
class PdfTransformBox extends StatefulWidget {
  /// Katman koordinatında başlangıç kutusu.
  final Rect rect;
  final Color color;
  final bool movable;
  final bool resizable;

  /// Köşeden çekerken en-boy oranı korunsun mu?
  final bool keepAspect;

  /// Kutunun içi (canlı kutu ölçüsünde çizilir; null → yalnız çerçeve).
  final Widget Function(Rect rect)? childBuilder;

  /// Sürükleme/boyutlandırma bitti — yeni kutu.
  final ValueChanged<Rect> onCommit;
  final VoidCallback? onTap;

  const PdfTransformBox({
    super.key,
    required this.rect,
    required this.color,
    required this.onCommit,
    this.movable = true,
    this.resizable = true,
    this.keepAspect = false,
    this.childBuilder,
    this.onTap,
  });

  /// Tutamak kutusunun kenar uzunluğu (parmak hedefi).
  static const double handle = 30;

  /// En küçük kutu — kullanıcı nesneyi yanlışlıkla yok etmesin.
  static const double minSize = 16;

  /// [corner] köşesi (0 sol-üst · 1 sağ-üst · 2 sağ-alt · 3 sol-alt)
  /// [delta] kadar çekildiğinde yeni kutu. Karşı köşe SABİT kalır.
  /// [keepAspect]'te hangi eksen daha çok oynadıysa o esas alınır.
  @visibleForTesting
  static Rect resizeFromCorner(Rect r, int corner, Offset delta,
      {bool keepAspect = false, double min = minSize}) {
    final left = corner == 0 || corner == 3;
    final top = corner == 0 || corner == 1;
    var w = r.width + (left ? -delta.dx : delta.dx);
    var h = r.height + (top ? -delta.dy : delta.dy);
    if (keepAspect && r.width > 0 && r.height > 0) {
      final aspect = r.width / r.height;
      if ((w - r.width).abs() / r.width >= (h - r.height).abs() / r.height) {
        h = w / aspect;
      } else {
        w = h * aspect;
      }
      if (w < min || h < min) {
        // En kısa kenar [min]'e oturur, oran korunur.
        if (aspect >= 1) {
          h = min;
          w = min * aspect;
        } else {
          w = min;
          h = min / aspect;
        }
      }
    } else {
      w = math.max(w, min);
      h = math.max(h, min);
    }
    final x = left ? r.right - w : r.left;
    final y = top ? r.bottom - h : r.top;
    return Rect.fromLTWH(x, y, w, h);
  }

  @override
  State<PdfTransformBox> createState() => _PdfTransformBoxState();
}

class _PdfTransformBoxState extends State<PdfTransformBox> {
  late Rect _rect = widget.rect;

  @override
  void didUpdateWidget(PdfTransformBox old) {
    super.didUpdateWidget(old);
    if (old.rect != widget.rect) _rect = widget.rect;
  }

  @override
  Widget build(BuildContext context) {
    const h = PdfTransformBox.handle;
    final r = _rect;
    Widget corner(int i) {
      final dx = i == 1 || i == 2 ? r.width : 0.0;
      final dy = i >= 2 ? r.height : 0.0;
      return Positioned(
        left: dx,
        top: dy,
        width: h,
        height: h,
        child: GestureDetector(
          key: ValueKey('transform-corner-$i'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => setState(() => _rect =
              PdfTransformBox.resizeFromCorner(_rect, i, d.delta,
                  keepAspect: widget.keepAspect)),
          onPanEnd: (_) => widget.onCommit(_rect),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onMedia, width: 2),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fromRect(
      rect: r.inflate(h / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: Rect.fromLTWH(h / 2, h / 2, r.width, r.height),
            child: GestureDetector(
              key: const ValueKey('transform-body'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onPanUpdate: widget.movable
                  ? (d) => setState(() => _rect = _rect.shift(d.delta))
                  : null,
              onPanEnd: widget.movable ? (_) => widget.onCommit(_rect) : null,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: widget.color, width: 2),
                  color: widget.childBuilder == null
                      ? widget.color.withValues(alpha: 0.12)
                      : null,
                ),
                child: widget.childBuilder?.call(r) ??
                    Center(
                      child: Icon(
                          widget.movable ? AppIcons.dragMove : AppIcons.lock,
                          color: widget.color.withValues(alpha: 0.8),
                          size: 20),
                    ),
              ),
            ),
          ),
          if (widget.resizable) ...[for (var i = 0; i < 4; i++) corner(i)],
        ],
      ),
    );
  }
}

/// Bekleyen bir nesnenin içeriği — PDF'e yazılacak hâliyle aynı ölçüde.
class PdfPendingObjectView extends StatelessWidget {
  final PdfPendingObject object;

  /// Katman pikseli / PDF noktası.
  final double scale;

  const PdfPendingObjectView(
      {super.key, required this.object, required this.scale});

  /// Yazının Flutter biçemi — PDF'e Carlito ile yazıldığı için ekranda da o.
  static TextStyle textStyle(PdfPendingObject o, double scale) => TextStyle(
        fontFamily: 'Carlito',
        fontSize: o.fontSize * scale,
        height: 1.2,
        // Tema gövdesinin harf aralığı (M3: 0,5) alana karışmasın: PDF'e
        // aralıksız yazılıyor, ekranda da öyle görünmeli.
        letterSpacing: 0,
        fontWeight: o.bold ? FontWeight.w700 : FontWeight.w400,
        color: Color(o.colorArgb),
      );

  /// Yazının [width] genişlikte kaplayacağı yükseklik (PDF noktası).
  static double measureText(PdfPendingObject o, double width) {
    final tp = TextPainter(
      text: TextSpan(text: o.text.isEmpty ? ' ' : o.text, style: textStyle(o, 1)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(width, 1));
    final h = tp.height;
    tp.dispose();
    return h;
  }

  /// Yazının tek satırda kapladığı genişlik (PDF noktası) — yeni kutunun eni.
  static double measureWidth(PdfPendingObject o) {
    final tp = TextPainter(
      text: TextSpan(text: o.text.isEmpty ? ' ' : o.text, style: textStyle(o, 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    switch (object.kind) {
      case PdfPendingKind.text:
        return Text(object.text, style: textStyle(object, scale));
      case PdfPendingKind.signature:
        return CustomPaint(
          painter: _StrokesPainter(object.strokes, Color(
              object.colorArgb == 0xFF191919 ? 0xFF000000 : object.colorArgb)),
          size: Size.infinite,
        );
      case PdfPendingKind.image:
        final data = object.image;
        return data == null
            ? const SizedBox.shrink()
            : Image.memory(data, fit: BoxFit.fill, gaplessPlayback: true);
    }
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width / 120)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()
        ..moveTo(s.first.dx * size.width, s.first.dy * size.height);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      !identical(old.strokes, strokes) || old.color != color;
}

/// Bir sayfanın bekleyen nesneleri.
class PdfPendingObjectLayer extends StatelessWidget {
  final List<PdfPendingObject> objects;

  /// Katman pikseli / PDF noktası.
  final double scale;
  final int? selectedId;

  /// Yerinde yazılan yazı nesnesi (seçili olmalı) ve denetleyicisi.
  final int? editingId;
  final TextEditingController? editingController;
  final FocusNode? editingFocus;

  final ValueChanged<int> onSelect;
  final void Function(PdfPendingObject next) onChanged;

  /// Seçili yazıya yeniden dokunuldu → yerinde düzenle.
  final ValueChanged<int> onEdit;

  const PdfPendingObjectLayer({
    super.key,
    required this.objects,
    required this.scale,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    required this.onEdit,
    this.editingId,
    this.editingController,
    this.editingFocus,
  });

  Rect _screen(Rect box) => Rect.fromLTWH(box.left * scale, box.top * scale,
      box.width * scale, box.height * scale);

  Rect _page(Rect r) => Rect.fromLTWH(
      r.left / scale, r.top / scale, r.width / scale, r.height / scale);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final o in objects)
          if (o.id == editingId && o.kind == PdfPendingKind.text)
            _editing(scheme, o)
          else if (o.id == selectedId)
            PdfTransformBox(
              key: ValueKey('pending-${o.id}'),
              rect: _screen(o.box),
              color: scheme.tertiary,
              keepAspect: o.keepAspect,
              onTap: o.kind == PdfPendingKind.text ? () => onEdit(o.id) : null,
              childBuilder: (r) => FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: o.box.width * scale,
                  height: o.box.height * scale,
                  child: PdfPendingObjectView(object: o, scale: scale),
                ),
              ),
              onCommit: (r) => onChanged(o.resizedTo(_page(r))),
            )
          else
            Positioned.fromRect(
              key: ValueKey('pending-${o.id}'),
              rect: _screen(o.box),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(o.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: scheme.tertiary.withValues(alpha: 0.5),
                        width: 1),
                  ),
                  child: PdfPendingObjectView(object: o, scale: scale),
                ),
              ),
            ),
      ],
    );
  }

  Widget _editing(ColorScheme scheme, PdfPendingObject o) {
    final r = _screen(o.box);
    return Positioned(
      key: ValueKey('pending-edit-${o.id}'),
      left: r.left,
      top: r.top,
      width: math.max(r.width, 40 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.page.withValues(alpha: 0.85),
          border: Border.all(color: scheme.primary, width: 2),
        ),
        child: TextField(
          key: const ValueKey('pending-text-field'),
          controller: editingController,
          focusNode: editingFocus,
          autofocus: true,
          maxLines: null,
          style: PdfPendingObjectView.textStyle(o, scale),
          cursorColor: scheme.primary,
          decoration: _bare,
        ),
      ),
    );
  }
}

/// Paragrafın **kendi kutusunda** düzenleme alanı (Faz 31 / PD1).
///
/// Özgün yazının üstü sayfa beyazıyla örtülür (altındaki metin görünmez),
/// alan aynı konum ve genişlikte, paragrafın puntosunda açılır; yazı uzarsa
/// kutu aşağı doğru büyür. Ekran, düzenleme başlarken paragrafa yakınlaşır —
/// alan belge koordinatında olduğu için yakınlaştırmayla birlikte büyür.
///
/// **Özgün görünüm korunur (2026-10-30, kullanıcı: *"tek satırlık yazı
/// düzenle dendiğinde 2 satıra çıkıyor"*).** İki kök neden vardı: (1) kenarlık
/// + iç boşluk alanın iç genişliğini paragrafın kendisinden ~3 px DAR
/// bırakıyordu; (2) alanın yazı tipi (Carlito) özgün gömülü yazı tipinden
/// biraz geniş olabiliyor. Artık kutu dışa doğru açılır (iç genişlik =
/// paragraf genişliği) ve özgün metin, özgün satır sayısına sığana kadar
/// puntosu en fazla %25 küçültülerek çizilir — düzenleme açıldığı an sayfa
/// "aynı" görünür; satır aralığı ve hiza da paragraftan gelir.
class PdfInlineParagraphEditor extends StatelessWidget {
  /// Paragrafın katman koordinatındaki kutusu.
  final Rect rect;
  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Katman pikseli cinsinden yazı boyu (punto × ölçek).
  final double pointSize;

  /// Özgün punto × ölçek ve özgün metin/satır sayısı — sığdırma oranı
  /// bunlarla bir kez hesaplanır (kullanıcı puntoyu değiştirince oran sabit).
  final double? originalPointSize;
  final String? originalText;
  final int originalLines;

  /// Satır aralığı (punto katı); null → 1,15.
  final double? lineHeight;
  final TextAlign textAlign;

  /// Ret var mı — çerçeve rengi bunu söyler (gerekçe klavye üstü şeritte).
  final bool refused;

  /// Uygulanıyor: yeni metin salt okunur yerinde durur, köşede çark.
  final bool applying;

  const PdfInlineParagraphEditor({
    super.key,
    required this.rect,
    required this.controller,
    required this.pointSize,
    this.focusNode,
    this.originalPointSize,
    this.originalText,
    this.originalLines = 1,
    this.lineHeight,
    this.textAlign = TextAlign.start,
    this.refused = false,
    this.applying = false,
  });

  static const _border = 1.5;
  static const _pad = 2.0;

  /// Alanın imleç için ayırdığı pay (EditableText `cursorWidth` + boşluk).
  static const _cursorSlack = 3.0;

  static final Map<String, double> _fitCache = {};

  /// Özgün metni [lines] satıra sığdıran ölçek (0,75…1).
  static double fitRatio({
    required String text,
    required double width,
    required double size,
    required int lines,
    required double height,
    TextDirection direction = TextDirection.ltr,
  }) {
    if (text.trim().isEmpty || width <= 0 || size <= 0) return 1;
    final key = '$width|$size|$lines|$height|$text';
    final cached = _fitCache[key];
    if (cached != null) return cached;
    var ratio = 1.0;
    final painter = TextPainter(textDirection: direction);
    for (var i = 0; i < 12; i++) {
      painter.text = TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: 'Carlito',
              fontSize: size * ratio,
              height: height,
              letterSpacing: 0,
              wordSpacing: 0));
      painter.layout(maxWidth: width);
      if (painter.computeLineMetrics().length <= lines) break;
      ratio *= 0.975;
      if (ratio < 0.75) {
        ratio = 0.75;
        break;
      }
    }
    painter.dispose();
    if (_fitCache.length > 64) _fitCache.clear();
    return _fitCache[key] = ratio;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = refused ? scheme.error : scheme.primary;
    const inset = _border + _pad;
    final height = (lineHeight ?? 1.15).clamp(1.0, 2.0);
    final original = originalText;
    final ratio = original == null
        ? 1.0
        : fitRatio(
            text: original,
            width: rect.width - _cursorSlack,
            size: originalPointSize ?? pointSize,
            lines: originalLines,
            height: height,
            direction: Directionality.of(context),
          );
    return Positioned(
      // Kenarlık ve iç boşluk DIŞA açılır: yazının sığdığı genişlik
      // paragrafın kendi genişliği kadar kalır (+ imleç payı).
      left: rect.left - inset,
      top: rect.top - inset,
      width: rect.width + 2 * inset + _cursorSlack,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rect.height + 2 * inset),
        child: DecoratedBox(
          key: const ValueKey('inline-paragraph-box'),
          decoration: BoxDecoration(
            // Sayfa kâğıdı beyaz: özgün yazı alttan görünmesin.
            color: AppColors.page,
            border: Border.all(color: border, width: _border),
            boxShadow: [
              BoxShadow(color: border.withValues(alpha: 0.25), blurRadius: 6),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                // DecoratedBox kenarlığı çocuğu içeri itmez: pay elle.
                padding: const EdgeInsets.all(inset),
                child: TextField(
                  key: const ValueKey('inline-paragraph-field'),
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  readOnly: applying,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlign: textAlign,
                  // Temanın gövde stili (M3: harf aralığı 0,5) BURAYA
                  // karışmasın — sayfadaki yazının harf aralığı yok; o 0,5 px
                  // tek satırı iki satıra itiyordu.
                  style: TextStyle(
                    fontFamily: 'Carlito',
                    fontSize: pointSize * ratio,
                    height: height,
                    letterSpacing: 0,
                    wordSpacing: 0,
                    fontWeight: FontWeight.w400,
                    color: AppColors.pageInk,
                  ),
                  cursorColor: border,
                  decoration: _bare,
                ),
              ),
              if (applying)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        key: const ValueKey('inline-applying'),
                        strokeWidth: 2,
                        color: border),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form alanlarını **sayfanın üstünde** doldurma katmanı (Faz 31 / PD5).
///
/// Alan kutusuna dokun → yerinde giriş: metin alanında yazma alanı açılır,
/// onay kutusu tek dokunuşla işaretlenir, açılır liste / radyo seçenekleri
/// [onPick] ile sorulur. Değerler kaydedilene kadar katmanda yaşar
/// ([PdfOverlayLayer.formValues]) ve kaydette alanın KENDİ değerine yazılır
/// (üstüne metin basılmaz — form doldurulmuş sayılsın).
class PdfFormOverlay extends StatelessWidget {
  final List<PdfFormFieldInfo> fields;

  /// Katman pikseli / PDF noktası.
  final double scale;

  /// Kullanıcının bu oturumda verdiği değerler (alan adı → değer).
  final Map<String, String> values;

  /// Yerinde yazılan metin alanı.
  final String? activeName;
  final TextEditingController? activeController;
  final FocusNode? activeFocus;

  final ValueChanged<PdfFormFieldInfo> onTapField;

  const PdfFormOverlay({
    super.key,
    required this.fields,
    required this.scale,
    required this.values,
    required this.onTapField,
    this.activeName,
    this.activeController,
    this.activeFocus,
  });

  String _value(PdfFormFieldInfo f) => values[f.name] ?? f.value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final f in fields)
          if (f.bounds != null) _field(context, scheme, f, f.bounds!),
      ],
    );
  }

  Widget _field(BuildContext context, ColorScheme scheme, PdfFormFieldInfo f,
      Rect b) {
    final r = Rect.fromLTWH(
        b.left * scale, b.top * scale, b.width * scale, b.height * scale);
    final locked = f.readOnly;
    final active = f.name == activeName;
    final changed = values.containsKey(f.name);
    // Acrobat'ın alan vurgusu: açık mavi dolgu; değişen alan yeşilimsi.
    final fill = locked
        ? scheme.outline.withValues(alpha: 0.10)
        : changed
            ? scheme.tertiary.withValues(alpha: 0.14)
            : scheme.primary.withValues(alpha: 0.12);
    final textSize = (b.height * 0.62).clamp(5.0, 14.0) * scale;
    final value = _value(f);

    Widget content;
    switch (f.kind) {
      case PdfFormFieldKind.checkbox:
        content = value == 'true'
            ? const FittedBox(
                child: Icon(AppIcons.check, color: AppColors.pageInk))
            : const SizedBox.shrink();
      case PdfFormFieldKind.text:
        content = active
            ? TextField(
                key: ValueKey('form-field-input-${f.name}'),
                controller: activeController,
                focusNode: activeFocus,
                autofocus: true,
                maxLines: b.height > b.width * 0.5 ? null : 1,
                style: TextStyle(
                    fontFamily: 'Carlito',
                    fontSize: textSize,
                    letterSpacing: 0,
                    color: AppColors.pageInk),
                decoration: _bare,
              )
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                        fontFamily: 'Carlito',
                        fontSize: textSize,
                        color: AppColors.pageInk)),
              );
      default:
        content = Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  fontFamily: 'Carlito',
                  fontSize: textSize,
                  color: AppColors.pageInk)),
        );
    }
    return Positioned.fromRect(
      key: ValueKey('form-field-${f.name}'),
      rect: r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () => onTapField(f),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 1.5 * scale),
          decoration: BoxDecoration(
            color: active ? AppColors.page : fill,
            border: Border.all(
                color: active
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: locked ? 0.2 : 0.45),
                width: active ? 1.5 : 0.8),
          ),
          child: content,
        ),
      ),
    );
  }
}
