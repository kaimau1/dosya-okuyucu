import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/busy_dialog.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../services/document_scanner.dart';
import '../services/fm/activity_log.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/file_ops.dart';
import '../services/fm/fs_events.dart';
import '../services/fm/safe_write.dart';
import '../services/ocr_service.dart';
import '../services/scan_dewarp.dart';
import '../services/scan_enhance.dart';
import '../services/scan_page_ops.dart';
import '../services/scan_prepare.dart';
import '../widgets/translate_flow.dart';
import 'fm/folder_picker_screen.dart';
import 'scan_edit_screen.dart';

/// PDF'i [pages]'ten AYNI YOLDA yeniden yazan iş. [ocr] sayfanın KAYNAĞINA
/// göre OCR satırları; eksik olanları tamamlayıp içine yazar.
typedef ScanSaver = Future<void> Function(
    String pdfPath, List<ScanPage> pages, Map<String, List<OcrLine>> ocr);

/// **Tarama stüdyosu** — taranan belgenin kaydedildiği, sayfa sayfa
/// düzenlendiği ve paylaşıldığı tek ekran.
///
/// ## 2026-10-18 — akış, düğmeler ve görünüm baştan
/// Kullanıcı: *"Belge tarama akışı, butonları, mantığı, görünümü tamamen
/// yenilenmeli, baştan tasarlanmalı"* + *"manuel kırpma daha kolay olmalı,
/// şu an görülmüyor, basit olmalı"*. Eski ekranda düzenleme iki kat
/// derindeydi (sonuç → "Sayfaları düzenle" → ayrı ekran → "Kaydet") ve
/// alttaki yatay kaydırmalı yedi metin düğmesinin yarısı ekran dışındaydı.
/// Yeni düzen:
/// * Üstte dosya adı ve **canlı kayıt durumu** ("Kaydediliyor…" →
///   "Kaydedildi · Dosya Okuyucu"). Ada dokunmak adı değiştirir.
/// * Ortada sayfa; altında küçük resim şeridi (basılı tutup sürükleyerek
///   sıra, sondaki "+" ile sayfa ekleme).
/// * En altta beş büyük, etiketli araç: **Kırp · Döndür · Filtre · Yeniden
///   çek · Sil** — o an görünen sayfaya uygulanır. Ara onay ekranı yok.
/// * Her değişiklik PDF'e KENDİLİĞİNDEN yazılır (kısa bir bekleme sonrası,
///   bölünmez — `SafeWrite`); "Geri al" son değişikliği döndürür.
///
/// ## Kaydetme: önce kaydet, sonra düzenle
/// PDF ekran açılmadan Belgeler dizinine yazılmış gelir (bkz. `ScanFlow`).
/// Sıra tersine kurulsaydı geri tuşuna basan kullanıcı taramasını
/// kaybederdi. Bekleyen bir değişiklik varken geri tuşu önce onu yazar.
class ScanResultScreen extends StatefulWidget {
  /// Kaydedilmiş PDF'in yolu.
  final String pdfPath;

  /// Sayfalar (kaynak + görünen görsel + filtre).
  final List<ScanPage> pages;

  /// Tanınan metin, sayfa sayfa (eski çağıranlar için; [ocrLines] varsa
  /// metin onlardan kurulur).
  final List<OcrPage> textPages;

  /// OCR satırları (kutularıyla), [pages] ile aynı sırada. PDF yeniden
  /// kurulurken görünmez metin katmanı kaybolmasın diye taşınır.
  final List<List<OcrLine>> ocrLines;

  /// Testler için kaydetme işi (varsayılan: OCR + PDF + `SafeWrite`).
  final ScanSaver? saver;

  const ScanResultScreen({
    super.key,
    required this.pdfPath,
    required this.pages,
    this.textPages = const [],
    this.ocrLines = const [],
    this.saver,
  });

  static Future<void> open(
    BuildContext context, {
    required String pdfPath,
    required List<ScanPage> pages,
    List<OcrPage> textPages = const [],
    List<List<OcrLine>> ocrLines = const [],
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          pdfPath: pdfPath,
          pages: pages,
          textPages: textPages,
          ocrLines: ocrLines,
        ),
      ));

  /// Varsayılan kaydetme: OCR'ı eksik sayfaları tanır, PDF'i kurar, aynı
  /// yola bölünmez yazar ve "değişti" der.
  static Future<void> defaultSaver(String pdfPath, List<ScanPage> pages,
      Map<String, List<OcrLine>> ocr) async {
    for (final page in pages) {
      if (ocr.containsKey(page.source)) continue;
      final lines = await DocumentScanner.recognizePages([page.display]);
      ocr[page.source] = lines.isEmpty ? const [] : lines.first;
    }
    final bytes = await DocumentScanner.renderPdf(
      ScanPage.displays(pages),
      ocrLinesPerPage: [for (final page in pages) ocr[page.source] ?? const []],
    );
    await SafeWrite.bytes(pdfPath, bytes);
    FsEvents.changed();
  }

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

enum _SaveState { saved, saving, failed }

class _ScanResultScreenState extends State<ScanResultScreen>
    with WidgetsBindingObserver {
  late String _pdfPath = widget.pdfPath;
  late List<ScanPage> _pages = List.of(widget.pages);

  /// OCR satırları sayfanın KAYNAĞINA göre: filtre değişince geometri aynı
  /// kaldığı için satırlar geçerli; kırpma/döndürme yeni kaynak üretir ve o
  /// sayfa yeniden tanınır.
  final Map<String, List<OcrLine>> _ocr = {};

  /// Geri alma yığını: değişiklikten ÖNCEKİ sayfa listesi.
  final List<List<ScanPage>> _history = [];
  static const _historyLimit = 20;

  final _pager = PageController();
  int _index = 0;
  int _tab = 0;

  /// O an sürmekte olan sayfa işi ("Kırpılıyor…"); null = boşta.
  String? _work;

  _SaveState _saveState = _SaveState.saved;
  bool _dirty = false;
  Future<void>? _saving;
  Timer? _saveTimer;
  bool _logged = false;

  ScanSaver get _saver => widget.saver ?? ScanResultScreen.defaultSaver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (var i = 0; i < widget.pages.length && i < widget.ocrLines.length; i++) {
      _ocr[widget.pages[i].source] = widget.ocrLines[i];
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  /// Uygulama arka plana giderken bekleyen değişiklik hemen yazılır.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _dirty) unawaited(_save());
  }

  String get _folder => p.dirname(_pdfPath);

  bool get _pending => _dirty || _saving != null;

  bool get _busy => _work != null;

  /// Tanınan metin, sayfa sırasıyla.
  List<OcrPage> get _text {
    final hasLines = _pages.any((page) => _ocr.containsKey(page.source));
    if (!hasLines) return widget.textPages;
    return DocumentScanner.textPages(
        [for (final page in _pages) _ocr[page.source] ?? const []]);
  }

  String _plainText(BuildContext context) => OcrService.joinPages(
      _text, (n) => context.t('tf.page_header', {'n': n}));

  // ── kayıt ────────────────────────────────────────────────────────────────

  /// Sayfa listesini değiştirir: önceki hâli geri alma yığınına koyar ve
  /// kaydı (kısa bir beklemeyle — art arda döndürmeler tek yazım olsun)
  /// planlar.
  void _commit(List<ScanPage> next, {int? index}) {
    _history.add(_pages);
    if (_history.length > _historyLimit) _history.removeAt(0);
    setState(() {
      _pages = next;
      if (index != null) _index = index;
      _index = _index.clamp(0, _pages.length - 1);
      _dirty = true;
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  /// Bekleyen değişikliği yazar. Yazımlar sıraya girer (aynı dosyaya iki
  /// yazım aynı anda koşmaz); yazım sürerken gelen değişiklik bir sonraki
  /// turda yazılır.
  Future<void> _save() {
    _saveTimer?.cancel();
    final previous = _saving ?? Future<void>.value();
    late final Future<void> run;
    run = previous.then((_) async {
      if (!_dirty) return;
      _dirty = false;
      final snapshot = List<ScanPage>.of(_pages);
      if (mounted) setState(() => _saveState = _SaveState.saving);
      try {
        await _saver(_pdfPath, snapshot, _ocr);
        if (!_logged) {
          _logged = true;
          unawaited(ActivityLog.add(ActivityKind.scan, _pdfPath));
        }
        if (mounted && !_dirty) {
          setState(() => _saveState = _SaveState.saved);
        }
      } catch (e) {
        _dirty = true;
        if (mounted) {
          setState(() => _saveState = _SaveState.failed);
          showSnack(context, context.t('sf.save_failed', {'error': e}),
              copyable: true);
        }
      }
    }).whenComplete(() {
      if (identical(_saving, run)) {
        _saving = null;
        if (mounted) setState(() {});
      }
    });
    _saving = run;
    return run;
  }

  /// Ekrandan çıkmadan / paylaşmadan önce bekleyen her şeyi yazar.
  Future<void> _flush() async {
    if (_dirty) await _save();
    while (_saving != null) {
      await _saving;
    }
  }

  Future<void> _leave() async {
    final busy = showBusyDialog(
      context,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator()),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(ctx.t('ss.finishing'))),
          ],
        ),
      ),
    );
    await _flush();
    busy.close();
    // Yazım başarısız olsa da kullanıcı ekranda HAPSOLMAZ: hata bildirimi
    // zaten gösterildi, diskteki PDF son başarılı hâlinde duruyor.
    if (mounted) Navigator.of(context).pop();
  }

  // ── sayfa işleri ─────────────────────────────────────────────────────────

  /// Görünen sayfaya [label] başlığıyla bir iş uygular; iş yeni sayfayı
  /// döndürür (null = değişiklik yok).
  Future<void> _runOnPage(
      String label, Future<ScanPage?> Function(ScanPage page) job) async {
    if (_busy || _pages.isEmpty) return;
    final index = _index;
    final before = _pages[index];
    setState(() => _work = label);
    try {
      final next = await job(before);
      if (!mounted) return;
      if (next != null) {
        _commit([
          for (var i = 0; i < _pages.length; i++)
            i == index ? next : _pages[i],
        ]);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, context.t('scr.add_failed', {'error': e}),
            copyable: true);
      }
    } finally {
      if (mounted) setState(() => _work = null);
    }
  }

  /// Kaynağı değişen sayfaya filtresini yeniden uygular.
  static Future<ScanPage> _withFilter(String source, ScanFilter filter) =>
      ScanPrepare.page(source, filter: filter);

  Future<void> _crop() async {
    if (_busy || _pages.isEmpty) return;
    final page = _pages[_index];
    final quad = await ScanEditScreen.open(context, page.source);
    if (quad == null || !mounted) return;
    await _runOnPage(context.t('ss.working_crop'), (page) async {
      final cropped = await ScanPageOps.warp(page.source, quad);
      return _withFilter(cropped, page.filter);
    });
  }

  Future<void> _rotate() => _runOnPage(context.t('ss.working_rotate'),
          (page) async {
        final source = await ScanPageOps.rotate(page.source, 1);
        if (page.filter == ScanFilter.original) return ScanPage.raw(source);
        // Filtrelenmiş görseli de döndür: filtreyi baştan koşturmaktan
        // hızlı ve sonuç birebir aynı.
        final display = await ScanPageOps.rotate(page.display, 1);
        return ScanPage(source: source, display: display, filter: page.filter);
      });

  Future<void> _filter() async {
    if (_busy || _pages.isEmpty) return;
    final page = _pages[_index];
    final choice = await showModalBottomSheet<_FilterChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        source: page.source,
        current: page.filter,
        pageCount: _pages.length,
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.straighten) {
      await _straighten();
      return;
    }
    if (!choice.all) {
      if (choice.filter == page.filter) return;
      await _runOnPage(context.t('ss.working_filter'),
          (page) => _withFilter(page.source, choice.filter));
      return;
    }
    // Tüm sayfalar: sırayla (aynı anda tek büyük görsel bellekte).
    setState(() => _work = context.t('ss.working_filter'));
    try {
      final next = <ScanPage>[];
      for (final page in _pages) {
        next.add(page.filter == choice.filter
            ? page
            : await _withFilter(page.source, choice.filter));
      }
      if (mounted) _commit(next);
    } finally {
      if (mounted) setState(() => _work = null);
    }
  }

  Future<void> _straighten() async {
    var changed = false;
    await _runOnPage(context.t('ss.working_straighten'), (page) async {
      final target = await ScanDewarp.tempTarget(page.source);
      final produced = await compute(
        ScanDewarp.runRequest,
        ScanStraightenRequest(sourcePath: page.source, targetPath: target),
      );
      if (produced == null) return null;
      changed = true;
      return _withFilter(produced, page.filter);
    });
    if (mounted) {
      showSnack(context,
          context.t(changed ? 'sr.straightened' : 'sr.straighten_noop'));
    }
  }

  /// Görünen sayfayı yeniden çeker (tek sayfalık tarama, yerine konur).
  Future<void> _retake() async {
    if (_busy || _pages.isEmpty) return;
    List<String>? shot;
    try {
      shot = await DocumentScanner.scanPages(maxPages: 1);
    } catch (e) {
      if (mounted) _snack(context.t('sf.scanner_failed', {'error': e}));
      return;
    }
    if (shot == null || shot.isEmpty || !mounted) return;
    final index = _index;
    _commit([
      for (var i = 0; i < _pages.length; i++)
        i == index ? ScanPage.raw(shot.first) : _pages[i],
    ]);
  }

  void _delete() {
    if (_busy || _pages.isEmpty) return;
    if (_pages.length == 1) {
      _snack(context.t('sr.last_page'));
      return;
    }
    final index = _index;
    _commit([..._pages]..removeAt(index));
    if (_pager.hasClients) _pager.jumpToPage(_index);
    showSnack(
      context,
      context.t('ss.page_deleted'),
      action: SnackBarAction(label: context.t('common.undo'), onPressed: _undo),
    );
  }

  void _undo() {
    if (_history.isEmpty || _busy) return;
    setState(() {
      _pages = _history.removeLast();
      _index = _index.clamp(0, _pages.length - 1);
      _dirty = true;
    });
    if (_pager.hasClients) _pager.jumpToPage(_index);
    _scheduleSave();
  }

  void _reorder(int from, int to) {
    if (to > from) to -= 1;
    if (from == to) return;
    final next = [..._pages];
    final page = next.removeAt(from);
    next.insert(to, page);
    _commit(next, index: to);
    if (_pager.hasClients) _pager.jumpToPage(to);
  }

  void _goTo(int index) {
    setState(() => _index = index);
    if (_pager.hasClients) {
      _pager.animateToPage(index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _addPages() async {
    if (_busy) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const _SheetIcon(Icons.document_scanner_outlined),
                title: Text(ctx.t('ss.add_camera')),
                subtitle: Text(ctx.t('ss.add_camera_sub')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const _SheetIcon(Icons.photo_library_outlined),
                title: Text(ctx.t('ss.add_gallery')),
                subtitle: Text(ctx.t('ss.add_gallery_sub')),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == 'camera') {
      List<String>? more;
      try {
        more = await DocumentScanner.scanPages();
      } catch (e) {
        if (mounted) _snack(context.t('sf.scanner_failed', {'error': e}));
        return;
      }
      if (more == null || more.isEmpty || !mounted) return;
      final first = _pages.length;
      _commit([..._pages, for (final path in more) ScanPage.raw(path)],
          index: first);
      if (_pager.hasClients) _pager.jumpToPage(first);
      _snack(context.t('scr.pages_added', {'n': more.length}));
      return;
    }
    await _addFromGallery();
  }

  /// Galeriden fotoğraf ekler. Fotoğraf HAM çekimdir (tarayıcı kırpmadı):
  /// tek fotoğrafta kırpma ekranı kâğıt kenarı bulunmuş olarak hemen açılır.
  /// Tarayıcının resimli sayfayı yanlış kırptığı durumda kullanıcının
  /// elindeki tam denetimli yol budur.
  Future<void> _addFromGallery() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    final paths = [
      for (final f in res?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    final first = _pages.length;
    var added = [for (final path in paths) ScanPage.raw(path)];
    if (paths.length == 1) {
      final quad =
          await ScanEditScreen.open(context, paths.first, autoDetect: true);
      if (!mounted) return;
      if (quad != null) {
        setState(() => _work = context.t('ss.working_crop'));
        try {
          added = [ScanPage.raw(await ScanPageOps.warp(paths.first, quad))];
        } catch (e) {
          if (mounted) _snack(context.t('se.failed', {'error': e}));
        } finally {
          if (mounted) setState(() => _work = null);
        }
      }
    }
    if (!mounted) return;
    _commit([..._pages, ...added], index: first);
    if (_pager.hasClients) _pager.jumpToPage(first);
    _snack(context.t('scr.pages_added', {'n': added.length}));
  }

  // ── belge işleri ─────────────────────────────────────────────────────────

  Future<void> _share() async {
    await _flush();
    if (!mounted) return;
    await Share.shareXFiles([XFile(_pdfPath)], text: p.basename(_pdfPath));
  }

  Future<void> _openPdf() async {
    await _flush();
    if (!mounted) return;
    await EntryOpener.open(context, _pdfPath);
  }

  Future<void> _recognize() async {
    setState(() => _work = context.t('vw.ocr_running'));
    try {
      for (final page in _pages) {
        if (_ocr.containsKey(page.source)) continue;
        final lines = await DocumentScanner.recognizePages([page.display]);
        _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
      }
      if (!mounted) return;
      _dirty = true;
      _scheduleSave(); // görünmez metin katmanı PDF'e de girsin
      if (_text.isEmpty) _snack(context.t('vw.ocr_none'));
    } catch (e) {
      if (mounted) _snack(context.t('vw.ocr_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _work = null);
    }
  }

  Future<void> _translate() async {
    await TranslateFlow.runDocument(
      context,
      title: p.basename(_pdfPath),
      load: (progress) async {
        if (_text.isNotEmpty) return _text;
        progress.status(AppStrings.of(context).t('vw.ocr_running'));
        for (final page in _pages) {
          if (_ocr.containsKey(page.source)) continue;
          final lines = await DocumentScanner.recognizePages([page.display]);
          _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
        }
        if (mounted) setState(() {});
        return _text;
      },
    );
  }

  /// Dosya adını değiştirir (uzantı sabit kalır). Ad OCR'dan kendiliğinden
  /// gelir; burası "beğenmedim" yolu.
  Future<void> _rename() async {
    await _flush();
    if (!mounted) return;
    final controller =
        TextEditingController(text: p.basenameWithoutExtension(_pdfPath));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('scr.rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim();
    if (clean == null || clean.isEmpty || !mounted) return;
    try {
      final old = _pdfPath;
      final newPath = await FileOps.rename(_pdfPath, '$clean.pdf');
      if (!mounted) return;
      setState(() => _pdfPath = newPath);
      // "Son belgeler" kaydı yolla eşleşir; ad değişince eski kayıt ölü
      // bağlantıya dönerdi.
      await EntryOpener.rememberFile(context, newPath, previousPath: old);
    } catch (e) {
      if (mounted) _snack(context.t('scr.rename_failed', {'error': e}));
    }
  }

  /// PDF'i kullanıcının seçtiği klasöre **taşır**.
  Future<void> _changeLocation() async {
    await _flush();
    if (!mounted) return;
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: [_pdfPath],
          actionLabel: context.t('scr.save_here'),
        ),
      ),
    );
    if (target == null || !mounted || target == _folder) return;
    setState(() => _work = context.t('ss.moving'));
    final old = _pdfPath;
    final result = await FileOps.moveAll([_pdfPath], target);
    if (!mounted) return;
    setState(() => _work = null);
    if (result.transfers.isNotEmpty) {
      setState(() => _pdfPath = result.transfers.first.dest);
      await EntryOpener.rememberFile(context, _pdfPath, previousPath: old);
      if (!mounted) return;
      _snack(context.t('scr.moved', {'folder': p.basename(_folder)}));
    } else {
      _snack(result.errors.isEmpty
          ? context.t('scr.move_failed', {'error': '-'})
          : context.t('scr.move_failed', {'error': result.errors.first}));
    }
  }

  void _snack(String msg) => showSnack(context, msg);

  // ── görünüm ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_pending && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: OfficeColors.canvas(context),
        appBar: AppBar(
          backgroundColor: scheme.surface,
          titleSpacing: 0,
          title: _titleBlock(context),
          actions: [
            if (_history.isNotEmpty)
              IconButton(
                tooltip: context.t('common.undo'),
                icon: const Icon(Icons.undo_rounded),
                onPressed: _busy ? null : _undo,
              ),
            IconButton(
              tooltip: context.t('common.share'),
              icon: const Icon(Icons.share_outlined),
              onPressed: _busy ? null : _share,
            ),
            PopupMenuButton<String>(
              tooltip: context.t('common.more'),
              enabled: !_busy,
              onSelected: (v) => switch (v) {
                'open' => _openPdf(),
                'rename' => _rename(),
                'move' => _changeLocation(),
                _ => null,
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'open',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(ctx.t('scr.open_pdf')),
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(ctx.t('scr.rename')),
                  ),
                ),
                PopupMenuItem(
                  value: 'move',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drive_file_move_outlined),
                    title: Text(ctx.t('scr.change_location')),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: Text(
                            context.t('ss.pages_tab', {'n': _pages.length})),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.subject, size: 18),
                        label: Text(context.t('scr.tab_text')),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(child: _tab == 0 ? _pagesView(context) : _textView()),
            if (_tab == 0) _thumbStrip(context),
          ],
        ),
        bottomNavigationBar:
            _tab == 0 ? _toolBar(context) : _textBar(context),
      ),
    );
  }

  /// Ad + canlı kayıt durumu. Kullanıcı nereye ve HANGİ ADLA yazıldığını
  /// görmeden "kaydedildi" demek dosyayı aratmak demekti; ada dokunmak adı
  /// değiştirir.
  Widget _titleBlock(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final (IconData? icon, Color color, String text) = switch (_saveState) {
      _SaveState.saving => (null, faint, context.t('ss.saving')),
      _SaveState.failed => (
          Icons.error_outline,
          theme.colorScheme.error,
          context.t('ss.save_failed')
        ),
      _SaveState.saved => (
          Icons.check_circle,
          Paper.success(context),
          context.t('ss.saved', {'folder': p.basename(_folder)})
        ),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: _busy
          ? null
          : (_saveState == _SaveState.failed
              ? () {
                  _dirty = true;
                  unawaited(_save());
                }
              : _rename),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.basenameWithoutExtension(_pdfPath),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: faint),
                  )
                else
                  Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagesView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Bellek: 2480 px'lik sayfa tam çözülürse ~35 MB; ekranın iki katı
    // çözünürlük yakınlaştırmada da net ve belleği yarıya indiriyor.
    final cacheWidth = (width * dpr * 2).round().clamp(600, 2480);
    return Stack(
      children: [
        PageView.builder(
          controller: _pager,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Padding(
                // Alt pay sayaç hapına yer bırakır: hap sayfanın üstüne
                // binmesin.
                padding: const EdgeInsets.fromLTRB(
                    Gap.lg, Gap.md, Gap.lg, Gap.xl + Gap.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.file(
                      File(_pages[i].display),
                      key: ValueKey(_pages[i].display),
                      cacheWidth: cacheWidth,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => SizedBox(
                        width: 220,
                        height: 300,
                        child: Center(
                          child: Text(context.t('sr.page_failed'),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Sayfa sayacı + filtre adı: hangi sayfaya, hangi görünümle
        // bakıldığı tek bakışta.
        Positioned(
          left: 0,
          right: 0,
          bottom: Gap.xs,
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.inverseSurface.withValues(alpha: 0.82),
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    _pages.isEmpty
                        ? ''
                        : '${_index + 1} / ${_pages.length}'
                            '${_pages[_index].filter == ScanFilter.original ? '' : ' · ${context.t(_pages[_index].filter.labelKey)}'}',
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_work != null)
          Positioned.fill(
            child: ColoredBox(
              color: scheme.surface.withValues(alpha: 0.55),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: Gap.md),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4)),
                        const SizedBox(width: Gap.md),
                        Text(_work!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Küçük resim şeridi: dokun = git, basılı tut + sürükle = sıra, "+" =
  /// sayfa ekle.
  Widget _thumbStrip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 92,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm + 4, vertical: Gap.sm + 2),
          itemCount: _pages.length,
          onReorder: _busy ? (_, __) {} : _reorder,
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Transform.scale(
              scale: 1 + 0.08 * Curves.easeOut.transform(animation.value),
              child: Material(
                color: Colors.transparent,
                elevation: 6 * animation.value,
                child: child,
              ),
            ),
          ),
          footer: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Tooltip(
              message: context.t('scr.add_pages'),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _busy ? null : _addPages,
                child: Container(
                  width: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outline, width: 1.2),
                    color: scheme.surfaceContainerLow,
                  ),
                  child: Icon(Icons.add_rounded, color: scheme.primary),
                ),
              ),
            ),
          ),
          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
            key: ValueKey('${_pages[i].source}#$i'),
            index: i,
            enabled: !_busy,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _Thumb(
                path: _pages[i].display,
                number: i + 1,
                selected: i == _index,
                onTap: () => _goTo(i),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !_busy && _pages.isNotEmpty;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.sm, Gap.xs, 0),
              child: Row(
                children: [
                  _ToolButton(
                    icon: Icons.crop_rounded,
                    label: context.t('ss.tool_crop'),
                    onTap: enabled ? _crop : null,
                    highlight: true,
                  ),
                  _ToolButton(
                    icon: Icons.rotate_90_degrees_cw_outlined,
                    label: context.t('ss.tool_rotate'),
                    onTap: enabled ? _rotate : null,
                  ),
                  _ToolButton(
                    icon: Icons.auto_awesome_outlined,
                    label: context.t('ss.tool_filter'),
                    onTap: enabled ? _filter : null,
                  ),
                  _ToolButton(
                    icon: Icons.camera_alt_outlined,
                    label: context.t('ss.tool_retake'),
                    onTap: enabled ? _retake : null,
                  ),
                  _ToolButton(
                    icon: Icons.delete_outline_rounded,
                    label: context.t('ss.tool_delete'),
                    onTap: enabled ? _delete : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: Text(context.t('common.share'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _openPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: Text(context.t('scr.open_pdf'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textView() {
    final text = _text;
    if (text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('scr.no_text_yet'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton.icon(
                onPressed: _busy ? null : _recognize,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(context.t('vw.ocr_short')),
              ),
            ],
          ),
        ),
      );
    }
    // Sayfa sayfa kart: metin tek yığın değil, sayfa başlıklarıyla ve
    // seçilebilir.
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
      children: [
        for (final page in text)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pages.length > 1)
                    Text(
                      context.t('tf.page_header', {'n': page.number}),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  const SizedBox(height: Gap.xs),
                  SelectableText(page.text,
                      style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _textBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _text.isNotEmpty;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(Gap.sm + 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: !hasText
                          ? null
                          : () async {
                              final copied = context.t('vw.copied_all');
                              await Clipboard.setData(
                                  ClipboardData(text: _plainText(context)));
                              if (mounted) _snack(copied);
                            },
                      icon: const Icon(Icons.copy, size: 20),
                      label: Text(context.t('common.copy'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _busy ? null : _translate,
                      icon: const Icon(Icons.translate, size: 20),
                      label: Text(context.t('common.translate'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt araç: büyük simge kapsülü + etiket. Beşi eşit genişlikte.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : (highlight ? scheme.onPrimaryContainer : scheme.onSurface);
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 34,
                  decoration: BoxDecoration(
                    color: highlight && enabled
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, size: 21, color: fg),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _Thumb({
    required this.path,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 54,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.2 : 1,
          ),
          color: Colors.white,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(
                File(path),
                key: ValueKey(path),
                fit: BoxFit.cover,
                cacheWidth: (54 * dpr).round(),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: scheme.surfaceContainerHigh),
              ),
            ),
            PositionedDirectional(
              end: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: selected ? scheme.onPrimary : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  final IconData icon;
  const _SheetIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
    );
  }
}

/// Filtre levhasının sonucu.
class _FilterChoice {
  final ScanFilter filter;
  final bool all;
  final bool straighten;
  const _FilterChoice(this.filter, {this.all = false, this.straighten = false});
}

/// **Filtre levhası** — dört görünümün CANLI önizlemesi, "tüm sayfalara"
/// anahtarı ve "Düzleştir". Önizlemeler küçük kopyada tek izolatta üretilir.
class _FilterSheet extends StatefulWidget {
  final String source;
  final ScanFilter current;
  final int pageCount;

  const _FilterSheet({
    required this.source,
    required this.current,
    required this.pageCount,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  Map<ScanFilter, Uint8List>? _previews;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    compute(ScanEnhance.previews, ScanPreviewRequest(widget.source))
        .then((v) {
      if (mounted) setState(() => _previews = v);
    }).catchError((_) {
      if (mounted) setState(() => _previews = const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('ss.filter_title'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Gap.xs),
            Text(context.t('ss.filter_note'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Paper.faint(context))),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                for (final filter in ScanFilter.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _preview(context, filter),
                    ),
                  ),
              ],
            ),
            if (widget.pageCount > 1) ...[
              const SizedBox(height: Gap.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _all,
                onChanged: (v) => setState(() => _all = v),
                title: Text(context.t('scan.apply_to_all')),
              ),
            ],
            const Divider(height: Gap.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.straighten, color: scheme.primary),
              title: Text(context.t('sr.straighten')),
              subtitle: Text(context.t('ss.straighten_sub')),
              onTap: () => Navigator.pop(context,
                  _FilterChoice(widget.current, straighten: true)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, ScanFilter filter) {
    final scheme = Theme.of(context).colorScheme;
    final selected = filter == widget.current;
    final bytes = _previews?[filter];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, _FilterChoice(filter, all: _all)),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.4 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: bytes == null
                    ? ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: _previews == null
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                      )
                    : Image.memory(bytes,
                        fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(filter.shortLabelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : null,
                ),
          ),
        ],
      ),
    );
  }
}
