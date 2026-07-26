import 'dart:io';

import 'package:flutter/material.dart';

import 'scan_edit_screen.dart';

/// Tarama sonrası **önizleme/düzeltme** ekranı.
///
/// Tarayıcıdan çıkan sayfalar PDF'e dönüşmeden önce burada görülür: yamuk
/// çıkan sayfanın köşeleri düzeltilebilir, gereksiz sayfa atılabilir.
/// Onaylanan sayfa yolları geri döndürülür (iptalde `null`).
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.pages});

  final List<String> pages;

  static Future<List<String>?> open(BuildContext context, List<String> pages) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => ScanReviewScreen(pages: pages)),
    );
  }

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late List<String> _pages = List.of(widget.pages);
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editCorners() async {
    final current = _pages[_index];
    final edited = await ScanEditScreen.open(context, current);
    if (edited == null || !mounted) return;
    setState(() => _pages[_index] = edited);
    // Aynı yol farklı içerikle gelirse Flutter'ın görsel önbelleği eski kareyi
    // gösterirdi; düzeltme her zaman YENİ dosyaya yazıldığı için sorun yok.
  }

  void _removeCurrent() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Son sayfa silinemez — taramayı iptal edin.')),
      );
      return;
    }
    setState(() {
      _pages.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
    });
    _controller.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Sayfa ${_index + 1} / ${_pages.length}'),
        actions: [
          IconButton(
            tooltip: 'Bu sayfayı sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: _removeCurrent,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(_pages[i]),
                    key: ValueKey(_pages[i]),
                    errorBuilder: (_, __, ___) => const Text(
                      'Sayfa görüntülenemedi',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Sayfa yamuk ya da fazla yer kaptıysa köşeleri düzeltin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editCorners,
                  icon: const Icon(Icons.crop_free),
                  label: const Text('Köşeleri ayarla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_pages),
                  icon: const Icon(Icons.check),
                  label: const Text('Devam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
