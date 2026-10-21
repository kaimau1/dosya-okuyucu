part of '../pdf_ink_screen.dart';


/// Yazı ekleme/düzenleme penceresi.
///
/// Denetleyici pencerenin KENDİ ömrüne bağlı: `showDialog` döndükten hemen
/// sonra `dispose` etmek, kapanış animasyonu sürerken metin alanının
/// ölmüş denetleyiciye erişmesine yol açıyordu (test yakaladı).
class _TextMarkDialog extends StatefulWidget {
  const _TextMarkDialog({
    required this.initial,
    required this.size,
    required this.allowDelete,
  });

  final String initial;
  final int size;
  final bool allowDelete;

  @override
  State<_TextMarkDialog> createState() => _TextMarkDialogState();
}

class _TextMarkDialogState extends State<_TextMarkDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  late int _size = widget.size;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('ink.text_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(hintText: context.t('ink.text_hint')),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(context.t('ink.size_s'))),
              ButtonSegment(value: 1, label: Text(context.t('ink.size_m'))),
              ButtonSegment(value: 2, label: Text(context.t('ink.size_l'))),
            ],
            selected: {_size},
            onSelectionChanged: (s) => setState(() => _size = s.first),
          ),
        ],
      ),
      actions: [
        if (widget.allowDelete)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (text: '', size: _size, delete: true)),
            child: Text(context.t('common.delete')),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, (text: _controller.text, size: _size, delete: false)),
          child: Text(context.t('common.ok')),
        ),
      ],
    );
  }
}

/// Kalem/fosforlu izlerini sayfanın üstüne çizer — PDF'e yazılanla aynı
/// kalınlık ve saydamlıkta (bkz. [applyPdfMarks]).
class InkPainter extends CustomPainter {
  InkPainter(this.marks);

  final List<InkMark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in marks) {
      if (m.points.isEmpty) continue;
      final color = Color(m.colorArgb);
      final paint = Paint()
        ..color =
            m.highlighter ? color.withValues(alpha: kHighlighterOpacity) : color
        ..blendMode = m.highlighter ? BlendMode.multiply : BlendMode.srcOver
        ..strokeWidth = math.max(0.5, m.widthFraction * size.width)
        ..style = PaintingStyle.stroke
        ..strokeCap = m.highlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final pts = [
        for (final p in m.points) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(InkPainter old) => true;
}
