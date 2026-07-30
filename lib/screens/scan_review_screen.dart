import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/perspective.dart';
import '../services/scan_enhance.dart';
import 'scan_edit_screen.dart';

/// Tarama sonrası **önizleme/düzeltme** ekranı.
///
/// Tarayıcıdan çıkan sayfalar PDF'e dönüşmeden önce burada görülür: yamuk
/// çıkan sayfanın köşeleri düzeltilebilir, gereksiz sayfa atılabilir, sayfa
/// **netleştirilebilir**. Onaylanan sayfa yolları geri döndürülür (iptalde
/// `null`).
///
/// ## Netleştirme neden AÇILIŞTA uygulanıyor
/// Kullanıcı isteği 2026-07-30: *"yazılar netleştirilmeli"*. Filtreyi menüye
/// gömüp beklemek, isteği karşılamamak olurdu: kullanıcı zaten "daha iyi
/// taransın" diyor, her sayfada ayrıca düğmeye basmasını istemiyor. Bu yüzden
/// ekran açılırken tüm sayfalara [ScanFilter.auto] uygulanıyor (gölge giderme +
/// keskinleştirme, renk KORUNUR) ve isteyen tek dokunuşla "Özgün"e dönebiliyor.
/// Özgün dosyalar korunuyor — filtre yıkıcı değil.
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
  /// Gösterilen (filtre uygulanmış olabilir) sayfa yolları.
  late final List<String> _pages = List.of(widget.pages);

  /// Filtrenin uygulanacağı KAYNAK. Filtre değiştirildiğinde zincirleme
  /// uygulama olmaz: keskinleştirilmiş bir görseli tekrar keskinleştirmek
  /// sayfayı gürültüye boğuyordu. Köşe düzeltme/döndürme yapılınca bu da
  /// güncellenir (o işlem sonucu yeni "özgün"dür).
  late final List<String> _sources = List.of(widget.pages);

  /// Sayfa başına seçili filtre.
  late final List<ScanFilter> _filters =
      List.filled(widget.pages.length, ScanFilter.auto, growable: true);

  final _controller = PageController();
  int _index = 0;
  bool _busy = false;

  /// Açılıştaki toplu netleştirmenin ilerlemesi (null = bitti).
  int? _preparing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareAll());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Açılışta bütün sayfalara varsayılan filtreyi uygular.
  Future<void> _prepareAll() async {
    for (var i = 0; i < _pages.length; i++) {
      if (!mounted) return;
      setState(() => _preparing = i);
      await _applyFilter(i, ScanFilter.auto, silent: true);
    }
    if (mounted) setState(() => _preparing = null);
  }

  /// [index] sayfasına [filter] uygular. Kaynak hep `_sources[index]`.
  Future<void> _applyFilter(int index, ScanFilter filter,
      {bool silent = false}) async {
    final source = _sources[index];
    if (filter == ScanFilter.original) {
      if (!mounted) return;
      setState(() {
        _filters[index] = filter;
        _pages[index] = source;
      });
      return;
    }
    try {
      final target = await ScanEnhance.tempTarget(source, filter);
      final produced = await compute(
        ScanEnhance.runRequest,
        ScanEnhanceRequest(
            sourcePath: source, targetPath: target, filter: filter),
      );
      if (!mounted) return;
      setState(() {
        _filters[index] = filter;
        _pages[index] = produced;
      });
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('scan.filter_failed', {'error': e}))));
    }
  }

  Future<void> _editCorners() async {
    // Köşe düzeltme ÖZGÜN sayfa üzerinde yapılır: filtre uygulanmış (örneğin
    // siyah-beyaza indirgenmiş) bir görseli kırpıp sonra tekrar filtrelemek
    // kaliteyi iki kez düşürürdü.
    final edited = await ScanEditScreen.open(context, _sources[_index]);
    if (edited == null || !mounted) return;
    final index = _index;
    _sources[index] = edited;
    setState(() => _pages[index] = edited);
    await _applyFilter(index, _filters[index]);
  }

  /// Geçerli sayfayı 90° saat yönünde çevirir (yeni dosyaya yazılır).
  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final index = _index;
    final source = _sources[index];
    try {
      final image = await decodeImageFile(source);
      try {
        final png = await Perspective.rotateToPng(image, 1);
        final path = await writeTempPng(source, 'donduruldu', png);
        if (!mounted) return;
        _sources[index] = path;
        setState(() => _pages[index] = path);
        await _applyFilter(index, _filters[index]);
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
      _sources.removeAt(_index);
      _filters.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
    });
    _controller.jumpToPage(_index);
  }

  /// Geçerli sayfanın filtresini **tüm sayfalara** yayar.
  Future<void> _applyToAll() async {
    final filter = _filters[_index];
    setState(() => _busy = true);
    for (var i = 0; i < _pages.length; i++) {
      if (i == _index) continue;
      if (!mounted) return;
      setState(() => _preparing = i);
      await _applyFilter(i, filter, silent: true);
    }
    if (mounted) {
      setState(() {
        _preparing = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preparing = _preparing;
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
          if (preparing != null)
            LinearProgressIndicator(
              value: _pages.isEmpty ? null : (preparing + 1) / _pages.length,
            ),
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
          _filterRow(),
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
                  onPressed:
                      _busy || preparing != null ? null : () => Navigator.of(context).pop(_pages),
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

  /// Filtre seçimi — yatay kaydırmalı çip şeridi.
  Widget _filterRow() {
    final current = _filters.isEmpty ? ScanFilter.auto : _filters[_index];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final filter in ScanFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(context.t(filter.labelKey)),
                selected: current == filter,
                onSelected: _busy || _preparing != null
                    ? null
                    : (_) => _applyFilter(_index, filter),
              ),
            ),
          if (_pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(context.t('scan.apply_to_all')),
                onPressed: _busy || _preparing != null ? null : _applyToAll,
              ),
            ),
        ],
      ),
    );
  }
}
