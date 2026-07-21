import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// .docx belgesini **Word'deki sayfa görünümüyle** çizer: sayfa kenarları,
/// stiller, tablolar, gömülü görseller, sütunlar.
///
/// Çizimi `assets/word/` içine gömülü docx-preview motoru yapar; WebView yalnızca
/// yerel dosyaları yükler, internet erişimi yoktur.
// ponytail: Flutter'da docx sayfa akışını (satır kırma, sayfa sonu, stil mirası)
// elle yazmak yerine olgun bir motor gömüldü — sadakat farkı büyük, kod farkı ~40 satır.
class DocxView extends StatefulWidget {
  final Uint8List bytes;
  const DocxView({super.key, required this.bytes});

  @override
  State<DocxView> createState() => _DocxViewState();
}

class _DocxViewState extends State<DocxView> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  double _zoom = 1.0;

  void _zoomBy(double f) {
    setState(() => _zoom = (_zoom * f).clamp(0.5, 3.0));
    // Pinch'e ek olarak düğmeyle de: sayfayı JS ile ölçekle.
    _controller.runJavaScript("document.body.style.zoom='$_zoom'");
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFECEFF1))
      ..enableZoom(true)
      ..addJavaScriptChannel('Durum', onMessageReceived: (m) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = m.message.startsWith('hata') ? m.message : null;
        });
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _render(),
        onWebResourceError: (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = e.description;
          });
        },
      ))
      ..loadFlutterAsset('assets/word/viewer.html');
  }

  /// Belge WebView'a base64 metin olarak aktarılır; çok büyük dosyalarda bu
  /// aktarım cihazı zorlar, o yüzden sınır var.
  static const _maxBytes = 12 * 1024 * 1024;

  Future<void> _render() async {
    if (widget.bytes.length > _maxBytes) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'belge çok büyük (${(widget.bytes.length / 1048576).round()} MB)';
      });
      return;
    }
    final b64 = base64Encode(widget.bytes);
    await _controller.runJavaScript("renderDocx('$b64')");
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sayfa görünümü açılamadı: $_error\n\n'
                'Düzenle sekmesinden metne erişebilirsiniz.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Yakınlaştır/uzaklaştır (pinch'e ek, garanti kontrol).
        if (_error == null)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomBtn(icon: Icons.zoom_in, onTap: () => _zoomBy(1.25)),
                const SizedBox(height: 8),
                _ZoomBtn(icon: Icons.zoom_out, onTap: () => _zoomBy(1 / 1.25)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Yarı saydam yuvarlak zoom düğmesi (WebView üstünde yüzer).
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}
