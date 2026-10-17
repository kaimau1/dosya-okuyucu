import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/perspective.dart';
import '../services/scan_dewarp.dart';
import '../services/scan_enhance.dart';
import '../services/scan_prepare.dart';
import 'scan_edit_screen.dart';
import '../core/snack.dart';

/// Taranmış belgenin **sayfalarını düzenleme** ekranı: filtre, döndürme,
/// silme, sıra, köşe/kırpma, düzleştirme. Onaylanan sayfalar döner (iptalde
/// `null`).
///
/// ## Artık akışın ZORUNLU adımı değil (2026-10-17)
/// Kullanıcı: *"belge taramada kesme sorunu ve direk kaydetmesi gerekli"*.
/// Eskiden tarayıcıdan dönen her sayfa önce buraya gelir, açılışta
/// kendiliğinden kâğıt kenarı kırpması (`ScanDeskew`) + düzleştirme +
/// netleştirme yapılır, kullanıcı "Devam"a basınca kaydedilirdi. İki sorun
/// vardı: ML Kit'te "Kaydet" demiş kullanıcıya ikinci bir onay ekranı, ve
/// kırpılmış sayfanın İÇİNDEKİ çerçeveyi kâğıt sanan ikinci kırpma (başlık,
/// imza kesiliyordu — bkz. [ScanPrepare]). Şimdi sayfalar `ScanPrepare` ile
/// hazırlanıp doğrudan kaydediliyor; bu ekran sonuç ekranındaki
/// "Sayfaları düzenle"den açılıyor ve hiçbir şeyi kendiliğinden kırpmıyor.
///
/// Filtre yıkıcı değildir: her sayfa kaynağını ([ScanPage.source]) taşır,
/// filtre değişince kaynağa yeniden uygulanır. Köşe düzeltme/döndürme
/// kaynağı günceller (o işlemin sonucu yeni "özgün"dür).
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.pages});

  final List<ScanPage> pages;

  static Future<List<ScanPage>?> open(
      BuildContext context, List<ScanPage> pages) {
    return Navigator.of(context).push<List<ScanPage>>(
      MaterialPageRoute(builder: (_) => ScanReviewScreen(pages: pages)),
    );
  }

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final List<ScanPage> _pages = List.of(widget.pages);

  final _controller = PageController();
  int _index = 0;
  bool _busy = false;

  /// Toplu işin ("tüm sayfalara uygula") ilerlemesi (null = yok).
  int? _batch;

  bool get _changed {
    if (_pages.length != widget.pages.length) return true;
    for (var i = 0; i < _pages.length; i++) {
      if (_pages[i].display != widget.pages[i].display) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Yazıya bakarak eğim + kıvrım düzeltme (izolatta). Kaynak güncellenir ki
  /// sonradan seçilen filtre de düzleştirilmiş sayfaya uygulansın. Sayfa
  /// gerçekten düzleştiyse true.
  Future<bool> _flatten(int index) async {
    try {
      final source = _pages[index].source;
      final target = await ScanDewarp.tempTarget(source);
      final produced = await compute(
        ScanDewarp.runRequest,
        ScanStraightenRequest(sourcePath: source, targetPath: target),
      );
      if (produced == null || !mounted) return false;
      setState(() => _pages[index] =
          _pages[index].copyWith(source: produced, display: produced));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// **Elle düzleştirme** (kullanıcı isteği 2026-08-06): otomatik geçiş
  /// temkinli, emin değilse sayfaya dokunmuyor; eğik kaldığını GÖREN
  /// kullanıcının elinde bir düğme olmalı.
  Future<void> _straightenNow() async {
    if (_busy) return;
    final index = _index;
    setState(() => _busy = true);
    final ok = await _flatten(index);
    if (ok) await _applyFilter(index, _pages[index].filter, silent: true);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(
        context, context.t(ok ? 'sr.straightened' : 'sr.straighten_noop'));
  }

  /// Dokunulan filtre: çip ANINDA seçili görünür (2026-07-31 bulgusu:
  /// "butona bastım, başladı mı anlamıyorum"), iş bitince görsel değişir,
  /// başarısızsa seçim geri alınır.
  Future<void> _chooseFilter(int index, ScanFilter filter) async {
    if (_busy) return;
    final previous = _pages[index];
    setState(() {
      _busy = true;
      _pages[index] = previous.copyWith(filter: filter);
    });
    final ok = await _applyFilter(index, filter);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _pages[index] = previous;
    });
  }

  /// [index] sayfasına [filter] uygular; kaynak hep `source`. Meşguliyet
  /// göstergesini yönetmez (toplu döngüler kendi ilerlemesini gösterir).
  Future<bool> _applyFilter(int index, ScanFilter filter,
      {bool silent = false}) async {
    final source = _pages[index].source;
    if (filter == ScanFilter.original) {
      if (!mounted) return false;
      setState(() => _pages[index] =
          ScanPage(source: source, display: source, filter: filter));
      return true;
    }
    try {
      final target = await ScanEnhance.tempTarget(source, filter);
      final produced = await compute(
        ScanEnhance.runRequest,
        ScanEnhanceRequest(
            sourcePath: source, targetPath: target, filter: filter),
      );
      if (!mounted) return false;
      setState(() => _pages[index] =
          ScanPage(source: source, display: produced, filter: filter));
      return true;
    } catch (e) {
      if (!mounted || silent) return false;
      showSnack(context, context.t('scan.filter_failed', {'error': e}));
      return false;
    }
  }

  Future<void> _editCorners() async {
    // Köşe düzeltme KAYNAK üzerinde yapılır: filtrelenmiş (ör. siyah-beyaza
    // indirgenmiş) görseli kırpıp yeniden filtrelemek kaliteyi iki kez
    // düşürürdü.
    final index = _index;
    final edited = await ScanEditScreen.open(context, _pages[index].source);
    if (edited == null || !mounted) return;
    if (edited == _pages[index].source) return; // çerçeveye dokunulmadı
    setState(() {
      _pages[index] = _pages[index].copyWith(source: edited, display: edited);
      _busy = true;
    });
    await _applyFilter(index, _pages[index].filter);
    if (mounted) setState(() => _busy = false);
  }

  /// Geçerli sayfayı 90° saat yönünde çevirir (yeni dosyaya yazılır).
  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final index = _index;
    final source = _pages[index].source;
    try {
      final image = await decodeImageFile(source);
      try {
        final png = await Perspective.rotateToPng(image, 1);
        final path = await writeTempPng(source, 'donduruldu', png);
        if (!mounted) return;
        setState(() => _pages[index] =
            _pages[index].copyWith(source: path, display: path));
        await _applyFilter(index, _pages[index].filter);
      } finally {
        image.dispose();
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, context.t('sr.rotate_failed', {'error': e}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeCurrent() {
    if (_pages.length <= 1) {
      showSnack(context, context.t('sr.last_page'));
      return;
    }
    setState(() {
      _pages.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
    });
    _controller.jumpToPage(_index);
  }

  /// Geçerli sayfayı bir öne/arkaya taşır (PDF'teki sıra budur).
  void _move(int delta) {
    final to = _index + delta;
    if (to < 0 || to >= _pages.length) return;
    setState(() {
      final page = _pages.removeAt(_index);
      _pages.insert(to, page);
      _index = to;
    });
    _controller.jumpToPage(to);
  }

  /// Geçerli sayfanın filtresini **tüm sayfalara** yayar.
  Future<void> _applyToAll() async {
    final filter = _pages[_index].filter;
    setState(() => _busy = true);
    for (var i = 0; i < _pages.length; i++) {
      if (i == _index || _pages[i].filter == filter) continue;
      if (!mounted) return;
      setState(() => _batch = i);
      await _applyFilter(i, filter, silent: true);
    }
    if (mounted) {
      setState(() {
        _batch = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Bellek: 2480 px'lik sayfa tam çözülürse ~35 MB. Ekranın iki katı
    // çözünürlük yakınlaştırmada da net, belleği yarıya indiriyor.
    final cacheWidth = (width * dpr * 2).round().clamp(600, 2480);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
              context.t('sr.title', {'n': _index + 1, 'total': _pages.length})),
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
            if (batch != null)
              LinearProgressIndicator(
                value: _pages.isEmpty ? null : (batch + 1) / _pages.length,
              )
            else if (_busy)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),
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
                      File(_pages[i].display),
                      key: ValueKey(_pages[i].display),
                      cacheWidth: cacheWidth,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Text(
                        context.t('sr.page_failed'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_pages.length > 1) _orderRow(),
            _filterRow(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _straightenNow,
                        icon: const Icon(Icons.straighten),
                        label: Text(context.t('sr.straighten')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () =>
                            Navigator.of(context).pop(_changed ? _pages : null),
                    icon: const Icon(Icons.check),
                    label: Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sayfa sırası: ‹ önceki konuma · sayfa noktaları · sonraki konuma ›.
  Widget _orderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: context.t('sr.move_earlier'),
            color: Colors.white,
            onPressed: _busy || _index == 0 ? null : () => _move(-1),
            icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.t('sr.order_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: context.t('sr.move_later'),
            color: Colors.white,
            onPressed:
                _busy || _index >= _pages.length - 1 ? null : () => _move(1),
            icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
          ),
        ],
      ),
    );
  }

  /// Filtre seçimi — yatay kaydırmalı çip şeridi.
  Widget _filterRow() {
    final current = _pages.isEmpty ? ScanFilter.auto : _pages[_index].filter;
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
                avatar: _busy && current == filter
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onSelected: _busy ? null : (_) => _chooseFilter(_index, filter),
              ),
            ),
          if (_pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(context.t('scan.apply_to_all')),
                onPressed: _busy ? null : _applyToAll,
              ),
            ),
        ],
      ),
    );
  }
}
