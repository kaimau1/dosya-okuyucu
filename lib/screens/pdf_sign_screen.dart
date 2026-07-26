import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_save.dart';
import '../services/pdf_tools.dart';
import '../widgets/pdf_save_dialog.dart';
import '../widgets/signature_pad.dart';

/// **PDF imzalama** — imzayı sayfa üzerinde sürükleyip boyutlandır, bas.
///
/// Koordinat sözleşmesi: kullanıcı sayfayı `/Rotate` uygulanmış hâliyle görür
/// (pdfrx `PdfPage.width/height` zaten döndürülmüş ölçüyü verir) ve imzayı ona
/// göre yerleştirir. Ham sayfa koordinatına çeviriyi [PdfTools.stampStrokes]
/// yapar — ekran tarafı görünen ölçüden başka bir şey bilmez.
class PdfSignScreen extends StatefulWidget {
  const PdfSignScreen({super.key, required this.path});

  final String path;

  /// İmzalanıp kaydedilirse `true` döner.
  static Future<bool?> open(BuildContext context, String path) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PdfSignScreen(path: path)),
      );

  @override
  State<PdfSignScreen> createState() => _PdfSignScreenState();
}

class _PdfSignScreenState extends State<PdfSignScreen> {
  Signature? _signature;
  int _page = 0;
  bool _busy = false;

  /// İmza kutusunun sayfa içindeki yeri — **0..1 oranında** (sayfa büyüklüğünden
  /// bağımsız): ekran döndüğünde/boyut değiştiğinde imza yerinde kalır.
  Offset _pos = const Offset(0.55, 0.75);
  double _widthFraction = 0.35;

  @override
  void initState() {
    super.initState();
    _restoreSignature();
  }

  Future<void> _restoreSignature() async {
    final saved = await Signature.load();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _signature = saved);
    } else {
      await _drawSignature();
    }
  }

  Future<void> _drawSignature() async {
    final sig = await SignaturePad.show(context);
    if (sig != null && mounted) setState(() => _signature = sig);
  }

  Future<void> _stamp(PdfPage page) async {
    final sig = _signature;
    if (sig == null || _busy) return;
    // İmza atmak geri alınamaz bir yazma: özgün belgeyi korumak isteyene
    // "kopyasını kaydet" yolu açık (2026-07-26 isteği).
    final mode = await askPdfSaveMode(
      context,
      path: widget.path,
      note: 'İmza belgeye kalıcı olarak basılacak.',
    );
    if (mode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Görünen sayfa ölçüsünde hedef kutu (oranlar → punto).
      final w = _widthFraction * page.width;
      final rect = Rect.fromLTWH(
        _pos.dx * page.width,
        _pos.dy * page.height,
        w,
        w / sig.aspect,
      );
      final out = await PdfTools.stampStrokes(
        bytes,
        pageIndex: _page,
        strokes: sig.strokes,
        rect: rect,
      );
      final written = await PdfSave.write(widget.path, out, mode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mode == PdfSaveMode.overwrite
            ? 'İmza belgeye eklendi'
            : 'İmzalı kopya kaydedildi: ${written.split('/').last}'),
      ));
      // Yalnız üzerine yazıldıysa açık görüntüleyici tazelenmeli.
      Navigator.of(context).pop(mode == PdfSaveMode.overwrite);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('İmzalanamadı: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder.file(
      widget.path,
      builder: (context, document) {
        final pages = document?.pages;
        return Scaffold(
          appBar: AppBar(
            title: Text('İmzala — ${p.basename(widget.path)}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'İmzayı yeniden çiz',
                icon: const Icon(Icons.gesture),
                onPressed: _busy ? null : _drawSignature,
              ),
              TextButton.icon(
                onPressed: pages == null || _signature == null || _busy
                    ? null
                    : () => _stamp(pages[_page]),
                icon: const Icon(Icons.check),
                label: const Text('Bas'),
              ),
            ],
          ),
          body: pages == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(minHeight: 3),
                    Expanded(child: _pageArea(document!, pages[_page])),
                    _controls(pages.length),
                  ],
                ),
        );
      },
    );
  }

  /// Sayfayı en-boy oranını koruyarak yerleştirir ve imzayı üzerine bindirir.
  /// İmza kutusu bu "sığdırılmış" alanın içinde oranla konumlanır.
  Widget _pageArea(PdfDocument document, PdfPage page) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = math.min(
          box.maxWidth / page.width,
          box.maxHeight / page.height,
        );
        final fitted = Size(page.width * scale, page.height * scale);
        final sig = _signature;
        final sigWidth = _widthFraction * fitted.width;
        final sigHeight = sig == null ? 0.0 : sigWidth / sig.aspect;

        return Center(
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PdfPageView(
                    document: document,
                    pageNumber: _page + 1,
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                ),
                if (sig != null)
                  Positioned(
                    left: _pos.dx * fitted.width,
                    top: _pos.dy * fitted.height,
                    width: sigWidth,
                    height: sigHeight,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        // Oranla sakla; kutu sayfadan taşmasın.
                        final nx = _pos.dx + d.delta.dx / fitted.width;
                        final ny = _pos.dy + d.delta.dy / fitted.height;
                        _pos = Offset(
                          nx.clamp(0.0, 1 - sigWidth / fitted.width),
                          ny.clamp(0.0, 1 - sigHeight / fitted.height),
                        );
                      }),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5),
                        ),
                        child: CustomPaint(
                          painter: SignaturePainter(sig),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _controls(int pageCount) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Önceki sayfa',
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  _page == 0 ? null : () => setState(() => _page -= 1),
            ),
            Text('${_page + 1} / $pageCount'),
            IconButton(
              tooltip: 'Sonraki sayfa',
              icon: const Icon(Icons.chevron_right),
              onPressed: _page >= pageCount - 1
                  ? null
                  : () => setState(() => _page += 1),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.photo_size_select_small, size: 18),
            Expanded(
              child: Slider(
                value: _widthFraction,
                min: 0.1,
                max: 0.8,
                onChanged: (v) => setState(() => _widthFraction = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
