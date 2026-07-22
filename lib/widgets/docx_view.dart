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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F2F1)) // Fluent kanvas (OfficeColors ile aynı)
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
      ],
    );
  }
}
