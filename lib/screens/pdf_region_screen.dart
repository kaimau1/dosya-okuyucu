import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../core/user_error.dart';
import '../widgets/state_views.dart' show AppErrorView;

/// Bölge işaretleme kipi.
enum PdfRegionMode {
  /// Kalıcı karartma: her sayfaya çok kutu, siyah dolgu.
  redact,

  /// Kırpma: tek kutu (tüm seçili sayfalara uygulanır).
  crop,

  /// Form alanı yerleştirme: her sayfaya çok kutu, çerçeve.
  field,
}

/// **Sayfa üstünde dikdörtgen işaretleme** (Faz 39: karartma, kırpma, form
/// alanı). Sayfa sayfa gezilir, parmakla sürükleyerek kutu çizilir, kutuya
/// dokununca silinir. Koordinatlar **görünen sayfa** puntosunda (sol-üst).
///
/// Perf: tek sayfa çizilir (PdfPageView, ekran DPI'sı), ızgara/şerit yok;
/// kutular tek `CustomPaint`.
class PdfRegionScreen extends StatefulWidget {
  const PdfRegionScreen({
    super.key,
    required this.bytes,
    required this.mode,
    this.password,
    this.initial = const {},
    this.title,
  });

  final Uint8List bytes;
  final String? password;
  final PdfRegionMode mode;
  final Map<int, List<Rect>> initial;
  final String? title;

  static Future<Map<int, List<Rect>>?> open(
    BuildContext context, {
    required Uint8List bytes,
    required PdfRegionMode mode,
    String? password,
    Map<int, List<Rect>> initial = const {},
    String? title,
  }) =>
      Navigator.of(context).push<Map<int, List<Rect>>>(MaterialPageRoute(
        builder: (_) => PdfRegionScreen(
          bytes: bytes,
          mode: mode,
          password: password,
          initial: initial,
          title: title,
        ),
      ));

  @override
  State<PdfRegionScreen> createState() => _PdfRegionScreenState();
}

class _PdfRegionScreenState extends State<PdfRegionScreen> {
  late final Map<int, List<Rect>> _marks = {
    for (final e in widget.initial.entries) e.key: List.of(e.value),
  };
  int _page = 0;
  PdfDocument? _doc;
  Object? _error;
  Offset? _dragStart;
  Rect? _dragRect;

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// Belge bir kez açılır (PdfDocumentViewBuilder her `setState`te yeni
  /// örnek olur ve pdfrx belgeyi kapatıp yeniden yükleyebilir — pdf_tools
  /// ekranındaki `_gridCache` notu).
  Future<void> _open() async {
    final password = widget.password;
    try {
      final doc = await PdfDocument.openData(
        widget.bytes,
        passwordProvider: password == null ? null : () async => password,
      );
      if (!mounted) {
        await doc.dispose();
        return;
      }
      setState(() => _doc = doc);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  int get _total => _marks.values.fold(0, (s, l) => s + l.length);

  void _addRect(Rect r) {
    if (r.width < 3 || r.height < 3) return;
    setState(() {
      if (widget.mode == PdfRegionMode.crop) {
        _marks
          ..clear()
          ..[_page] = [r];
      } else {
        (_marks[_page] ??= []).add(r);
      }
    });
  }

  void _removeAt(Offset pt) {
    final list = _marks[_page];
    if (list == null) return;
    final hit = list.lastIndexWhere((r) => r.contains(pt));
    if (hit < 0) return;
    setState(() {
      list.removeAt(hit);
      if (list.isEmpty) _marks.remove(_page);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.t('pp.region_title')),
        actions: [
          TextButton(
            onPressed: _total == 0 ? null : () => Navigator.pop(context, _marks),
            child: Text(context.t('common.ok')),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final document = _doc;
          if (_error != null) {
            // H10.3: ham istisna yok; ham metin yalnız "Ayrıntıyı kopyala"da.
            return AppErrorView(
              message: userErrorText(_error!),
              details: '$_error',
              onRetry: () {
                setState(() => _error = null);
                _open();
              },
            );
          }
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final count = document.pages.length;
          final page = document.pages[_page.clamp(0, count - 1)];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: Text(
                  context.t(widget.mode == PdfRegionMode.crop
                      ? 'pp.region_hint_crop'
                      : 'pp.region_hint'),
                  style: context.type.small,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.sm),
                    child: AspectRatio(
                      aspectRatio: page.width / page.height,
                      child: LayoutBuilder(builder: (context, box) {
                        final scale = box.maxWidth / page.width;
                        Offset toPt(Offset px) => px / scale;
                        return GestureDetector(
                          onPanStart: (d) => _dragStart = toPt(d.localPosition),
                          onPanUpdate: (d) => setState(() => _dragRect =
                              Rect.fromPoints(_dragStart!, toPt(d.localPosition))),
                          onPanEnd: (_) {
                            final r = _dragRect;
                            _dragStart = null;
                            setState(() => _dragRect = null);
                            if (r != null) _addRect(r);
                          },
                          onTapUp: (d) => _removeAt(toPt(d.localPosition)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                child: PdfPageView(
                                  document: document,
                                  pageNumber: _page + 1,
                                  maximumDpi: 150,
                                  decoration:
                                      const BoxDecoration(color: AppColors.page),
                                ),
                              ),
                              CustomPaint(
                                painter: _RegionPainter(
                                  rects: [
                                    ...?_marks[_page],
                                    ?_dragRect,
                                  ],
                                  scale: scale,
                                  mode: widget.mode,
                                  accent: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: context.t('pp.prev_page'),
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(AppIcons.chevronLeft),
                    ),
                    Text(context.t('pp.region_status', {
                      'page': _page + 1,
                      'count': count,
                      'n': _total,
                    })),
                    IconButton(
                      tooltip: context.t('pp.next_page'),
                      onPressed: _page < count - 1
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(AppIcons.chevron),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.rects,
    required this.scale,
    required this.mode,
    required this.accent,
  });

  final List<Rect> rects;
  final double scale;
  final PdfRegionMode mode;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = mode == PdfRegionMode.redact
          ? AppColors.pageInk.withValues(alpha: 0.85)
          : accent.withValues(alpha: 0.18);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = mode == PdfRegionMode.redact ? AppColors.pageInk : accent;
    for (final r in rects) {
      final px = Rect.fromLTRB(
          r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);
      canvas.drawRect(px, fill);
      canvas.drawRect(px, stroke);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.rects.length != rects.length ||
      old.scale != scale ||
      !_same(old.rects, rects);

  static bool _same(List<Rect> a, List<Rect> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
