import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf/pdf_scanned_retype.dart' show ScannedLine;
import '../services/pdf_page_edit.dart';

/// PDF sayfasının üstünde **düzenlenebilir öğeleri gösteren katman**:
/// paragraf kutuları ve görsel (resim/logo/QR) kutuları.
///
/// **Jest kuralı — bu katman sayfayı ASLA kilitlemez.** `pdf_select_layer`'da
/// pahalıya öğrenildi (bkz. oradaki uzun açıklama): sayfanın tamamını kaplayan
/// bir jest tanıyıcısı pdfrx'in kaydırma/yakınlaştırmasıyla arenaya girer ve
/// kullanıcı belgeyi gezemez hâle gelir. Bu yüzden:
/// * seçim yalnız **dokunuşla** yapılır (`onTap` — sürüklemeyle yarışmaz),
/// * sürükleme yalnız SEÇİLİ görselin küçük kutusunda ve tutamağında açılır,
///   yani kullanıcı bir nesneyi bilerek seçtiğinde.
class PdfEditOverlay extends StatelessWidget {
  final PdfPage page;
  final Size pageSize;

  /// Sayfadaki düzenlenebilir öğeler.
  final PdfPageOutline outline;

  /// Hangi mod açık: paragraflar mı, görseller mi?
  final bool textMode;

  /// Seçili görselin [PdfPageOutline.objects] içindeki sırası.
  final int? selectedObject;

  final void Function(int index) onParagraphTap;
  final void Function(int index) onObjectTap;

  /// Seçili görsel sürüklendi/boyutlandırıldı — sayfa uzayında yeni kutu.
  final void Function(int index, Rect pageRect) onObjectChanged;

  const PdfEditOverlay({
    super.key,
    required this.page,
    required this.pageSize,
    required this.outline,
    required this.textMode,
    required this.selectedObject,
    required this.onParagraphTap,
    required this.onObjectTap,
    required this.onObjectChanged,
  });

  /// Sayfa (PDF) koordinatındaki bir kutuyu ekran koordinatına çevirir.
  Rect _toScreen(double left, double bottom, double right, double top) =>
      PdfRect(left, top, right, bottom)
          .toRect(page: page, scaledPageSize: pageSize);

  /// Ekran koordinatındaki kutuyu sayfa koordinatına geri çevirir.
  ///
  /// pdfrx'in tersi yok; ölçek ve dikey çevirme elle uygulanıyor. Sayfa
  /// widget'ı her zaman sayfanın tamamını gösterdiği için ölçek tek sayı.
  Rect _toPage(Rect screen) {
    final scaleX = pageSize.width / page.width;
    final scaleY = pageSize.height / page.height;
    final left = screen.left / scaleX;
    final right = screen.right / scaleX;
    // Ekranda y aşağı, PDF'te yukarı büyür.
    final top = page.height - screen.top / scaleY;
    final bottom = page.height - screen.bottom / scaleY;
    return Rect.fromLTRB(left, bottom, right, top);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (textMode)
          for (var i = 0; i < outline.paragraphs.length; i++)
            _paragraphBox(scheme, i, outline.paragraphs[i])
        else
          for (var i = 0; i < outline.objects.length; i++)
            _objectBox(scheme, i, outline.objects[i]),
      ],
    );
  }

  Widget _paragraphBox(ColorScheme scheme, int index, PdfParagraph paragraph) {
    final rect = _toScreen(
        paragraph.left, paragraph.bottom, paragraph.right, paragraph.top);
    return Positioned.fromRect(
      rect: rect.inflate(2),
      child: GestureDetector(
        // Yalnız dokunuş: sürükleme pdfrx'e kalır, sayfa gezinmesi bozulmaz.
        behavior: HitTestBehavior.opaque,
        onTap: () => onParagraphTap(index),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: scheme.primary.withValues(alpha: 0.55), width: 1),
            borderRadius: BorderRadius.circular(3),
            color: scheme.primary.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }

  Widget _objectBox(ColorScheme scheme, int index, PdfPageObject object) {
    final rect = _toScreen(
        object.left, object.bottom, object.right, object.top);
    final selected = selectedObject == index;
    final color = selected ? scheme.tertiary : scheme.secondary;

    if (!selected) {
      return Positioned.fromRect(
        rect: rect,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onObjectTap(index),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
              color: color.withValues(alpha: 0.05),
            ),
          ),
        ),
      );
    }

    return _MovableObject(
      key: ValueKey('obj-$index-${rect.left}-${rect.top}'),
      initial: rect,
      color: color,
      // Döndürülmüş görselde köşe tutamağı yanıltıcı olurdu: kutu sayfaya
      // hizalı ama görsel değil. Yalnız taşımaya izin veriliyor.
      resizable: !object.rotated,
      onCommit: (screenRect) => onObjectChanged(index, _toPage(screenRect)),
    );
  }
}

/// Seçili görselin sürüklenebilir/boyutlandırılabilir kutusu.
class _MovableObject extends StatefulWidget {
  final Rect initial;
  final Color color;
  final bool resizable;
  final ValueChanged<Rect> onCommit;

  const _MovableObject({
    super.key,
    required this.initial,
    required this.color,
    required this.resizable,
    required this.onCommit,
  });

  @override
  State<_MovableObject> createState() => _MovableObjectState();
}

class _MovableObjectState extends State<_MovableObject> {
  late Rect _rect = widget.initial;

  /// Tutamak kutusunun kenar uzunluğu (dokunma hedefi: parmak ~44dp).
  static const _handle = 30.0;

  /// En küçük kutu — kullanıcı yanlışlıkla görseli yok etmesin.
  static const _minSize = 16.0;

  void _move(DragUpdateDetails d) {
    setState(() => _rect = _rect.shift(d.delta));
  }

  void _resize(DragUpdateDetails d) {
    setState(() {
      final width = (_rect.width + d.delta.dx).clamp(_minSize, 100000.0);
      final height = (_rect.height + d.delta.dy).clamp(_minSize, 100000.0);
      _rect = Rect.fromLTWH(_rect.left, _rect.top, width, height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: _rect.inflate(_handle / 2),
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                  _handle / 2, _handle / 2, _rect.width, _rect.height),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _move,
                onPanEnd: (_) => widget.onCommit(_rect),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: widget.color, width: 2),
                    color: widget.color.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Icon(Icons.open_with,
                        color: widget.color.withValues(alpha: 0.8), size: 20),
                  ),
                ),
              ),
            ),
            if (widget.resizable)
              Positioned(
                left: _rect.width,
                top: _rect.height,
                width: _handle,
                height: _handle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _resize,
                  onPanEnd: (_) => widget.onCommit(_rect),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.open_in_full,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Taranmış sayfada **OCR satır kutularını** gösteren katman (2026-08-06:
/// "taranmış belge deyip düzenleme yaptırmıyor"). Paragraf kutularıyla aynı
/// jest kuralı: yalnız dokunuş, sürükleme pdfrx'e kalır. Kesikli kenarlık
/// bilinçli fark: bunlar gerçek metin akışı değil, OCR TAHMİNİ — dokununca
/// satırın üstüne yazılır.
class PdfScannedOverlay extends StatelessWidget {
  final PdfPage page;
  final Size pageSize;
  final List<ScannedLine> lines;
  final void Function(int index) onLineTap;

  const PdfScannedOverlay({
    super.key,
    required this.page,
    required this.pageSize,
    required this.lines,
    required this.onLineTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        for (var i = 0; i < lines.length; i++)
          Positioned.fromRect(
            rect: lines[i]
                .box
                .toRect(page: page, scaledPageSize: pageSize)
                .inflate(2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onLineTap(i),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: scheme.tertiary.withValues(alpha: 0.55),
                      width: 1),
                  borderRadius: BorderRadius.circular(3),
                  color: scheme.tertiary.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
