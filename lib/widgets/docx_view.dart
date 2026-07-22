import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// .docx belgesini **Word'deki sayfa görünümüyle** çizer: sayfa kenarları,
/// stiller, tablolar, gömülü görseller, sütunlar. Canlı düzenleme modunda
/// sayfanın kendisi contenteditable olur; değişen paragraflar `Kalem`
/// kanalından `{i, segs:[[metin,b,i,u],…]}` olarak Flutter'a akar.
///
/// Çizimi `assets/word/` içine gömülü docx-preview motoru yapar; WebView yalnızca
/// yerel dosyaları yükler, internet erişimi yoktur.
// ponytail: Flutter'da docx sayfa akışını (satır kırma, sayfa sonu, stil mirası)
// elle yazmak yerine olgun bir motor gömüldü — sadakat farkı büyük, kod farkı ~40 satır.
class DocxView extends StatefulWidget {
  final Uint8List bytes;

  /// Canlı düzenlemede bir paragraf değiştiğinde (indeks + biçimli parçalar).
  final void Function(int index, List<(String, bool, bool, bool)> segs)?
      onEdited;

  /// Seçimin kalın/italik/altçizgi durumu değiştiğinde (araç çubuğu için).
  final void Function(bool bold, bool italic, bool underline)? onSelection;

  /// Sayfa görünümü başarıyla açıldı mı (false → çağıran yedek editöre geçer).
  final void Function(bool ok)? onStatus;

  /// WebView'daki paragraf sayısı beklenen sayıyla uyuşmazsa (eşleme sigortası).
  final void Function(int webCount)? onParagraphCount;

  const DocxView({
    super.key,
    required this.bytes,
    this.onEdited,
    this.onSelection,
    this.onStatus,
    this.onParagraphCount,
  });

  @override
  State<DocxView> createState() => DocxViewState();
}

class DocxViewState extends State<DocxView> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F2F1)) // Fluent kanvas
      ..enableZoom(true)
      ..addJavaScriptChannel('Durum', onMessageReceived: (m) {
        if (!mounted) return;
        final err = m.message.startsWith('hata') ? m.message : null;
        setState(() {
          _loading = false;
          _error = err;
        });
        widget.onStatus?.call(err == null);
      })
      ..addJavaScriptChannel('Kalem', onMessageReceived: _onKalem)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _render(),
        onWebResourceError: (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = e.description;
          });
          widget.onStatus?.call(false);
        },
      ))
      ..loadFlutterAsset('assets/word/viewer.html');
  }

  void _onKalem(JavaScriptMessage m) {
    if (!mounted) return;
    final dynamic data;
    try {
      data = jsonDecode(m.message);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    if (data['n'] is int) {
      widget.onParagraphCount?.call(data['n'] as int);
      return;
    }
    if (data['sel'] is Map) {
      final s = data['sel'] as Map;
      widget.onSelection?.call(
          s['b'] == true, s['i'] == true, s['u'] == true);
      return;
    }
    if (data['i'] is int && data['segs'] is List) {
      final segs = <(String, bool, bool, bool)>[
        for (final seg in data['segs'] as List)
          if (seg is List && seg.isNotEmpty)
            (
              '${seg[0]}',
              seg.length > 1 && seg[1] == true,
              seg.length > 2 && seg[2] == true,
              seg.length > 3 && seg[3] == true,
            ),
      ];
      widget.onEdited?.call(data['i'] as int, segs);
    }
  }

  /// Canlı düzenlemeyi açar/kapatır (sayfa contenteditable olur).
  void setEditing(bool on) =>
      _controller.runJavaScript('setEditable($on)');

  /// Seçime biçim uygular: 'bold' | 'italic' | 'underline'.
  void format(String cmd) => _controller.runJavaScript("fmt('$cmd')");

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
      widget.onStatus?.call(false);
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
                'Metin düzenleyiciye geçiliyor.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
