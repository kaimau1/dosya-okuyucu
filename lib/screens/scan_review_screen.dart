import 'dart:io';

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/perspective.dart';
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
  late final List<String> _pages = List.of(widget.pages);
  final _controller = PageController();
  int _index = 0;
  bool _busy = false;

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

  /// Geçerli sayfayı 90° saat yönünde çevirir (yeni dosyaya yazılır).
  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final current = _pages[_index];
    try {
      final image = await decodeImageFile(current);
      try {
        final png = await Perspective.rotateToPng(image, 1);
        final path = await writeTempPng(current, 'donduruldu', png);
        if (!mounted) return;
        setState(() => _pages[_index] = path);
      } finally {
        image.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
                content: Text(context.t('sr.rotate_failed', {'error': e}))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeCurrent() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('sr.last_page'))),
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
            tooltip: context.t('sr.rotate_page'),
            icon: const Icon(Icons.rotate_right),
            onPressed: _busy ? null : _rotate,
          ),
          IconButton(
            tooltip: context.t('sr.delete_page'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _removeCurrent,
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
                    errorBuilder: (_, __, ___) => Text(
                      context.t('sr.page_failed'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              context.t('sr.crop_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                  onPressed: _busy ? null : _editCorners,
                  icon: const Icon(Icons.crop_free),
                  label: Text(context.t('sr.adjust_corners')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_pages),
                  icon: const Icon(Icons.check),
                  label: Text(context.t('dl.continue')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
