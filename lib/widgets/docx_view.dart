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

  Future<void> _render() async {
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
