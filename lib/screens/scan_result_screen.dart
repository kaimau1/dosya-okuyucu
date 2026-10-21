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
import '../services/fm/doc_classifier.dart';
import '../services/fm/file_ops.dart';
import '../services/fm/fm_env.dart';
import '../services/fm/fs_events.dart';
import '../services/fm/safe_write.dart';
import '../services/ocr_service.dart';
import '../services/scan_dewarp.dart';
import '../services/scan_enhance.dart';
import '../services/scan_page_ops.dart';
import '../services/scan_prepare.dart';
import '../widgets/translate_flow.dart';
import 'fm/folder_picker_screen.dart';
import 'fm/important_screen.dart';
import 'scan_edit_screen.dart';

part 'scan_result/actions.dart';
part 'scan_result/views.dart';
part 'scan_result/widgets.dart';

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
    // **Otomatik sınıflandırma** (2026-10-18): taranan metin bir türe
    // (fatura, kimlik, sözleşme…) güvenle uyuyorsa ilgili klasör önerilir.
    // Cihazda anahtar sözcükle — metin hiçbir yere gönderilmez.
    final text = widget.textPages.map((page) => page.text).join('\n');
    if (text.trim().isNotEmpty) {
      final guess = classifyDocumentText(text);
      if (guess.isConfident) _classGuess = guess;
    }
  }

  /// Tarama sonrası tür tahmini (yalnız güvenliyse); kullanıcı kapatınca null.
  DocGuess? _classGuess;

  /// Önerilen klasör: Önemli Dosyalar / <tür klasörü>.
  String? get _suggestedFolder {
    final guess = _classGuess;
    if (guess == null) return null;
    final target = p.join(
        ImportantScreen.pathIn(FmEnv.primaryRoot), guess.type.folder);
    return p.equals(target, _folder) ? null : target;
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

  // ── sayfa işleri ─────────────────────────────────────────────────────────

  /// Kaynağı değişen sayfaya filtresini yeniden uygular.
  static Future<ScanPage> _withFilter(String source, ScanFilter filter) =>
      ScanPrepare.page(source, filter: filter);

  // ── belge işleri ─────────────────────────────────────────────────────────

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
            if (_suggestedFolder != null) _classBanner(context),
            Expanded(child: _tab == 0 ? _pagesView(context) : _textView()),
            if (_tab == 0) _thumbStrip(context),
          ],
        ),
        bottomNavigationBar:
            _tab == 0 ? _toolBar(context) : _textBar(context),
      ),
    );
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
