import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_state.dart';
import '../core/edition.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../core/user_error.dart';
import '../services/fm/file_ops.dart';
import '../services/fm/fm_env.dart';
import '../services/fm/fs_events.dart';
import '../services/fm/safe_write.dart';
import '../services/ai_pool.dart';
import '../services/gemini_service.dart';
import '../services/ocr_service.dart';
import '../services/read_aloud_ai.dart';
import '../services/scan_text_fix.dart';
import '../services/tts_service.dart';
import '../widgets/ai_key_gate.dart';
import '../widgets/fm/fm_file_image.dart';
import '../widgets/pro_gate.dart';

/// [OcrStudioScreen]'den dönen tanıma/düzenleme sonucu.
class OcrStudioResult {
  final String text;
  final List<OcrPage> pages;
  final bool openImageOverlay;

  const OcrStudioResult({
    required this.text,
    required this.pages,
    this.openImageOverlay = false,
  });
}

enum _StudioStage { setup, running, result }

enum _PageScope { currentPage, firstBatch, custom }

/// **Metin Tanıma Stüdyosu (OCR)** (Paket 6):
/// Taranmış PDF ve görseller için kalite/kapsam seçimi, sayfa sayfa canlı
/// ilerleme + iptal ve kaynak karşılaştırmalı düzenleme/temizleme/aktarım
/// stüdyosu.
class OcrStudioScreen extends StatefulWidget {
  final String? imagePath;
  final PdfDocument? pdfDoc;
  final String? title;
  final int currentPage;
  final bool startDirectly;

  /// Widget testleri için önceden yüklenmiş sayfalar.
  final List<OcrPage>? initialPagesForTest;

  const OcrStudioScreen({
    super.key,
    this.imagePath,
    this.pdfDoc,
    this.title,
    this.currentPage = 1,
    this.startDirectly = false,
    this.initialPagesForTest,
  });

  /// Kullanıcı sayfa aralığını (`"1-3, 5"`) geçerli 1-tabanlı sayfa kümesine
  /// dönüştürür. Saf -> birim testli.
  static Set<int> parsePageRange(String input, int pageCount) {
    if (pageCount <= 0) return const <int>{};
    final out = <int>{};
    for (final rawPart in input.split(RegExp(r'[,;\s]+'))) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      final dash = part.indexOf('-');
      if (dash < 0) {
        final n = int.tryParse(part);
        if (n != null && n >= 1 && n <= pageCount) out.add(n);
        continue;
      }
      final a = int.tryParse(part.substring(0, dash).trim());
      final b = int.tryParse(part.substring(dash + 1).trim());
      if (a == null || b == null) continue;
      final lo = math.min(a, b).clamp(1, pageCount);
      final hi = math.max(a, b).clamp(1, pageCount);
      for (var page = lo; page <= hi; page++) {
        out.add(page);
      }
    }
    return out;
  }

  @override
  State<OcrStudioScreen> createState() => _OcrStudioScreenState();
}

class _OcrStudioScreenState extends State<OcrStudioScreen> {
  final TextEditingController _editor = TextEditingController();
  late final TextEditingController _rangeCtrl = TextEditingController(
    text: _defaultRangeText(),
  );

  late _StudioStage _stage;
  OcrQualityMode _mode = OcrQualityMode.enhanced;
  _PageScope _scope = _PageScope.firstBatch;
  bool _cancelled = false;
  bool _aiBusy = false;
  bool _showPreview = false;
  bool _readingAloud = false;

  int _doneCount = 0;
  int _totalCount = 0;
  List<OcrPage> _pages = const [];
  int _activePageIndex = -1; // -1 = Tümü

  TtsService? _tts;
  final Map<int, Future<Uint8List?>> _previewFutures = {};

  bool get _isPdf => widget.pdfDoc != null;
  int get _pdfPageCount => widget.pdfDoc?.pages.length ?? 0;

  String _defaultRangeText() {
    final total = widget.pdfDoc?.pages.length ?? 0;
    if (total <= 1) return '1';
    final end = math.min(total, OcrService.maxPdfPages);
    return '1-$end';
  }

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialPagesForTest;
    if (seeded != null) {
      _pages = List<OcrPage>.of(seeded);
      _activePageIndex = _pages.length == 1 ? 0 : -1;
      _stage = _StudioStage.result;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncEditorFromActive();
      });
    } else {
      if (_isPdf) {
        _scope = widget.startDirectly
            ? _PageScope.currentPage
            : (_pdfPageCount <= 1
                ? _PageScope.currentPage
                : _PageScope.firstBatch);
      }
      _stage = _StudioStage.setup;
      if (widget.startDirectly) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startOcr();
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _editor.dispose();
    _rangeCtrl.dispose();
    _tts?.dispose();
    super.dispose();
  }

  AppState? _tryAppState() {
    try {
      return context.read<AppState>();
    } catch (_) {
      return null;
    }
  }

  String _pageHeader(AppStrings str, int pageNo) =>
      '— ${str.t('ocr_studio.page_chip', {'n': pageNo})} —';

  String _joinedText() {
    if (_pages.isEmpty) return '';
    if (_pages.length == 1) return _pages.first.text;
    final str = AppStrings.of(context);
    return OcrService.joinPages(_pages, (n) => _pageHeader(str, n));
  }

  void _syncEditorFromActive() {
    if (_activePageIndex >= 0 && _activePageIndex < _pages.length) {
      _editor.text = _pages[_activePageIndex].text;
    } else {
      _editor.text = _joinedText();
    }
  }

  void _commitEditorToActive() {
    if (_pages.isEmpty) return;
    if (_activePageIndex >= 0 && _activePageIndex < _pages.length) {
      final pNo = _pages[_activePageIndex].number;
      _pages = [
        for (var i = 0; i < _pages.length; i++)
          i == _activePageIndex ? OcrPage(pNo, _editor.text) : _pages[i],
      ];
    } else if (_pages.length == 1) {
      _pages = [OcrPage(_pages.first.number, _editor.text)];
    }
  }

  String _currentResultText() {
    _commitEditorToActive();
    if (_activePageIndex == -1 && _pages.length > 1) {
      return _editor.text;
    }
    return _joinedText();
  }

  Future<void> _selectMode(OcrQualityMode next) async {
    if (next == OcrQualityMode.aiVision) {
      if (!await ProGate.check(context, Feature.ai)) return;
      if (!mounted) return;
      if (!await ensureAiKey(context)) return;
      if (!mounted) return;
    }
    setState(() => _mode = next);
  }

  Future<void> _startOcr() async {
    if (_mode == OcrQualityMode.aiVision) {
      if (!await ProGate.check(context, Feature.ai)) return;
      if (!mounted) return;
      if (!await ensureAiKey(context)) return;
      if (!mounted) return;
    }

    Set<int>? onlyPages;
    var maxPages = OcrService.maxPdfPages;
    if (_isPdf) {
      final count = _pdfPageCount;
      switch (_scope) {
        case _PageScope.currentPage:
          final cur = widget.currentPage.clamp(1, math.max(1, count)).toInt();
          onlyPages = {cur};
          maxPages = 1;
        case _PageScope.firstBatch:
          onlyPages = null;
          maxPages = OcrService.maxPdfPages;
        case _PageScope.custom:
          final parsed = OcrStudioScreen.parsePageRange(_rangeCtrl.text, count);
          if (parsed.isEmpty) {
            showSnack(context, context.t('ocr_studio.range_empty'));
            return;
          }
          onlyPages = parsed;
          maxPages = parsed.length;
      }
    }

    setState(() {
      _stage = _StudioStage.running;
      _cancelled = false;
      _doneCount = 0;
      _totalCount = _isPdf ? (onlyPages?.length ?? math.min(_pdfPageCount, maxPages)) : 1;
      _pages = const [];
      _activePageIndex = -1;
    });

    try {
      final live = <OcrPage>[];
      if (widget.imagePath != null) {
        final text = await OcrService.recognizeImageFile(
          widget.imagePath!,
          allowCloud: _mode == OcrQualityMode.aiVision ||
              Edition.current.has(Feature.ai),
          mode: _mode,
        );
        if (text.trim().isNotEmpty) live.add(OcrPage(1, text.trim()));
        if (mounted) {
          setState(() {
            _doneCount = 1;
            _pages = List<OcrPage>.of(live);
          });
        }
      } else if (widget.pdfDoc != null) {
        final pages = await OcrService.recognizePdfPages(
          widget.pdfDoc!,
          maxPages: maxPages,
          onlyPages: onlyPages,
          allowCloud: _mode == OcrQualityMode.aiVision ||
              Edition.current.has(Feature.ai),
          mode: _mode,
          cancelled: () => _cancelled || !mounted,
          onProgress: (done, total) {
            if (!mounted) return;
            setState(() {
              _doneCount = done;
              _totalCount = total;
            });
          },
          onPageDone: (page) {
            live.add(page);
            if (!mounted) return;
            setState(() => _pages = List<OcrPage>.of(live));
          },
        );
        if (mounted && pages.isNotEmpty) {
          _pages = List<OcrPage>.of(pages);
        }
      }
      if (!mounted) return;
      setState(() {
        _activePageIndex = _pages.length == 1 ? 0 : -1;
        _stage = _StudioStage.result;
        _syncEditorFromActive();
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, userErrorText(e));
      setState(() {
        _stage = _pages.isNotEmpty ? _StudioStage.result : _StudioStage.setup;
        if (_pages.isNotEmpty) _syncEditorFromActive();
      });
    }
  }

  void _cleanLocal() {
    final fixed = [
      for (final rawLine in _editor.text.split('\n'))
        rawLine.trim().isEmpty ? '' : rawLine,
    ];
    final nonEmptyFixed = ScanTextFix.lines(fixed);
    final updated = nonEmptyFixed.join('\n').trim();
    setState(() {
      _editor.text = updated;
      _commitEditorToActive();
    });
    showSnack(context, context.t('ocr_studio.clean_done'));
  }

  Future<void> _fixWithAi() async {
    if (_editor.text.trim().isEmpty || _aiBusy) return;
    if (!await ProGate.check(context, Feature.ai)) return;
    if (!mounted) return;
    if (!await ensureAiKey(context)) return;
    if (!mounted) return;
    final state = _tryAppState();
    final creds = state?.aiCredentials;
    if (creds == null || creds.keys.isEmpty) return;

    setState(() => _aiBusy = true);
    try {
      // Havuz üzerinden (2026-11-25 denetimi): ham `GeminiService` gönderim
      // onayını, gizli kasa kapısını ve kota soğumasını atlıyordu.
      final GeminiService gemini = PooledGemini(creds);
      final fixed = await ReadAloudAi.tidyOrOriginal(gemini, _editor.text);
      if (!mounted) return;
      setState(() {
        _editor.text = fixed;
        _commitEditorToActive();
      });
      showSnack(context, context.t('ocr_studio.ai_done'));
    } catch (e) {
      if (mounted) showSnack(context, userErrorText(e));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _copyText() async {
    final text = _editor.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, context.t('vw.copied_all'));
  }

  Future<void> _shareText() async {
    final text = _editor.text.trim();
    if (text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _saveTxt() async {
    final text = _editor.text.trim();
    if (text.isEmpty) return;
    try {
      final baseName = p.basenameWithoutExtension(
          widget.imagePath ?? widget.title ?? 'ocr_metin');
      final candidates = <String>[
        if (widget.imagePath != null)
          p.join(p.dirname(widget.imagePath!), '${baseName}_ocr.txt'),
        p.join(FmEnv.primaryRoot, 'Download', '${baseName}_ocr.txt'),
      ];
      String? saved;
      for (final raw in candidates) {
        try {
          final target = FileOps.uniquePath(raw);
          await Directory(p.dirname(target)).create(recursive: true);
          await SafeWrite.bytes(target, utf8.encode(text));
          saved = target;
          break;
        } catch (_) {
          // Bilinçli: salt okunur klasörde Download fallback'ine geç.
        }
      }
      if (saved != null) {
        FsEvents.changed([saved]);
        if (mounted) {
          showSnack(context,
              context.t('ocr_studio.saved_txt', {'name': p.basename(saved)}));
        }
      }
    } catch (e) {
      if (mounted) showSnack(context, userErrorText(e));
    }
  }

  Future<void> _toggleReadAloud() async {
    if (_readingAloud) {
      await _tts?.stop();
      if (mounted) setState(() => _readingAloud = false);
      return;
    }
    final text = _editor.text.trim();
    if (text.isEmpty) return;
    final prefs = _tryAppState()?.ttsPrefs ?? TtsPrefs.defaults;
    final tts = _tts ??= TtsService(prefs: prefs)
      ..onProgress = (_, _, playing) {
        if (mounted && !playing) {
          setState(() => _readingAloud = false);
        }
      };
    tts.prefs = prefs;
    setState(() => _readingAloud = true);
    await tts.start(cleanForSpeech(text));
  }

  Future<Uint8List?> _renderPdfPreview(int pageNumber) {
    return _previewFutures[pageNumber] ??= () async {
      final doc = widget.pdfDoc;
      if (doc == null) return null;
      final page = doc.pages
          .where((e) => e.pageNumber == pageNumber)
          .firstOrNull;
      if (page == null) return null;
      final scale = (900 / page.width).clamp(0.5, 2.0);
      final img = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        backgroundColor: AppColors.page.toARGB32(),
      );
      if (img == null) return null;
      final int w = img.width, h = img.height;
      final TransferableTypedData pixels;
      try {
        pixels = TransferableTypedData.fromList([img.pixels]);
      } finally {
        img.dispose();
      }
      return Isolate.run(() {
        final raw = pixels.materialize().asUint8List();
        final image = imglib.Image.fromBytes(
          width: w,
          height: h,
          bytes: raw.buffer,
          bytesOffset: raw.offsetInBytes,
          numChannels: 4,
          order: imglib.ChannelOrder.bgra,
        );
        return Uint8List.fromList(imglib.encodeJpg(image, quality: 82));
      });
    }();
  }

  void _popWithResult({bool openOverlay = false}) {
    final text = _currentResultText();
    Navigator.of(context).pop(OcrStudioResult(
      text: text,
      pages: _pages,
      openImageOverlay: openOverlay,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.title?.trim() ?? '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => _popWithResult(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ocr_studio.title')),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            if (_stage == _StudioStage.result) ...[
              IconButton(
                key: const ValueKey('ocr-preview-toggle'),
                icon: Icon(_showPreview ? AppIcons.hiddenOff : AppIcons.hidden),
                tooltip: context.t('ocr_studio.preview'),
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
              IconButton(
                key: const ValueKey('ocr-rescan'),
                icon: const Icon(AppIcons.refresh),
                tooltip: context.t('ocr_studio.rescan'),
                onPressed: () => setState(() => _stage = _StudioStage.setup),
              ),
            ],
          ],
        ),
        body: switch (_stage) {
          _StudioStage.setup => _buildSetup(context),
          _StudioStage.running => _buildRunning(context),
          _StudioStage.result => _buildResult(context),
        },
      ),
    );
  }

  Widget _buildSetup(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aiLocked = !Edition.current.has(Feature.ai);
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(context.t('ocr_studio.quality'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Gap.sm),
        _modeCard(
          context,
          mode: OcrQualityMode.enhanced,
          title: context.t('ocr_studio.mode_enhanced'),
          subtitle: context.t('ocr_studio.mode_enhanced_sub'),
          icon: AppIcons.ocr,
        ),
        _modeCard(
          context,
          mode: OcrQualityMode.fast,
          title: context.t('ocr_studio.mode_fast'),
          subtitle: context.t('ocr_studio.mode_fast_sub'),
          icon: AppIcons.textSnippet,
        ),
        _modeCard(
          context,
          mode: OcrQualityMode.aiVision,
          title: context.t('ocr_studio.mode_ai'),
          subtitle: context.t('ocr_studio.mode_ai_sub'),
          icon: AppIcons.ai,
          showProBadge: aiLocked,
        ),
        if (_isPdf) ...[
          const SizedBox(height: Gap.md),
          Text(context.t('ocr_studio.pages'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Gap.sm),
          RadioGroup<_PageScope>(
            groupValue: _scope,
            onChanged: (v) {
              if (v != null) setState(() => _scope = v);
            },
            child: Column(
              children: [
                RadioListTile<_PageScope>(
                  value: _PageScope.currentPage,
                  title: Text(context.t('ocr_studio.pages_current', {
                    'n': widget.currentPage.clamp(1, math.max(1, _pdfPageCount)),
                  })),
                ),
                if (_pdfPageCount > 1)
                  RadioListTile<_PageScope>(
                    value: _PageScope.firstBatch,
                    title: Text(context.t('ocr_studio.pages_batch', {
                      'n': math.min(_pdfPageCount, OcrService.maxPdfPages),
                    })),
                  ),
                if (_pdfPageCount > 1)
                  RadioListTile<_PageScope>(
                    value: _PageScope.custom,
                    title: Text(context.t('ocr_studio.pages_custom')),
                  ),
              ],
            ),
          ),
          if (_scope == _PageScope.custom && _pdfPageCount > 1)
            Padding(
              padding: const EdgeInsets.only(
                  left: Gap.md, right: Gap.md, top: Gap.xs),
              child: TextField(
                controller: _rangeCtrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: context.t('ocr_studio.range_hint', {
                    'total': _pdfPageCount,
                  }),
                ),
              ),
            ),
        ],
        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          key: const ValueKey('ocr-start'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _startOcr,
          icon: const Icon(AppIcons.ocr),
          label: Text(context.t('ocr_studio.start')),
        ),
      ],
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required OcrQualityMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    bool showProBadge = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _mode == mode;
    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(
          selected ? AppIcons.checkCircle : icon,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Flexible(child: Text(title)),
            if (showProBadge) ...[
              const SizedBox(width: Gap.sm),
              const ProBadge(),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        onTap: () => _selectMode(mode),
      ),
    );
  }

  Widget _buildRunning(BuildContext context) {
    final total = math.max(1, _totalCount);
    final fraction = (_doneCount / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: Gap.md),
          Text(
            context.t('ocr_studio.progress_page', {
              'done': math.min(_doneCount + 1, total),
              'total': total,
            }),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Gap.md),
          Expanded(
            child: _pages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _pages.length,
                    itemBuilder: (ctx, i) {
                      final pg = _pages[i];
                      return Card(
                        child: ListTile(
                          title: Text(context.t('ocr_studio.page_chip', {
                            'n': pg.number,
                          })),
                          subtitle: Text(
                            pg.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('ocr-cancel'),
            onPressed: () => setState(() => _cancelled = true),
            icon: const Icon(AppIcons.close),
            label: Text(context.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _editor.text.trim();
    final words = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = text.length;
    final previewPageNo = _activePageIndex >= 0 && _activePageIndex < _pages.length
        ? _pages[_activePageIndex].number
        : (_pages.isNotEmpty ? _pages.first.number : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pages.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(
                      context.t('ocr_studio.all_pages', {'n': _pages.length})),
                  selected: _activePageIndex == -1,
                  onSelected: (_) => setState(() {
                    _commitEditorToActive();
                    _activePageIndex = -1;
                    _syncEditorFromActive();
                  }),
                ),
                for (var i = 0; i < _pages.length; i++) ...[
                  const SizedBox(width: Gap.xs),
                  ChoiceChip(
                    label: Text(context.t(
                        'ocr_studio.page_chip', {'n': _pages[i].number})),
                    selected: _activePageIndex == i,
                    onSelected: (_) => setState(() {
                      _commitEditorToActive();
                      _activePageIndex = i;
                      _syncEditorFromActive();
                    }),
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t('ocr_studio.stats', {
                    'words': words,
                    'chars': chars,
                  }),
                  style: context.type.small.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (widget.imagePath != null)
                TextButton.icon(
                  onPressed: () => _popWithResult(openOverlay: true),
                  icon: const Icon(AppIcons.selectAll, size: AppIcons.small),
                  label: Text(context.t('ocr_studio.select_on_image')),
                ),
            ],
          ),
        ),
        if (_showPreview)
          Container(
            height: 180,
            margin: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.imagePath != null
                ? InteractiveViewer(
                    child: Image(
                      image: FmFileImage(widget.imagePath!, cacheWidth: 1080),
                      fit: BoxFit.contain,
                    ),
                  )
                : FutureBuilder<Uint8List?>(
                    future: _renderPdfPreview(previewPageNo),
                    builder: (_, snap) {
                      final bytes = snap.data;
                      if (bytes == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return InteractiveViewer(
                        child: Image.memory(
                          bytes,
                          cacheWidth: 1080,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: _pages.isEmpty && text.isEmpty
                ? Center(
                    child: Text(
                      context.t('ocr_studio.empty_result'),
                      textAlign: TextAlign.center,
                      style: context.type.body
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : TextField(
                    key: const ValueKey('ocr-editor'),
                    controller: _editor,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: context.type.body.copyWith(height: 1.45),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      hintText: context.t('ocr_studio.editor_hint'),
                    ),
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Gap.sm),
            child: Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  key: const ValueKey('ocr-clean'),
                  avatar: const Icon(AppIcons.organize, size: AppIcons.small),
                  label: Text(context.t('ocr_studio.clean')),
                  onPressed: text.isEmpty ? null : _cleanLocal,
                ),
                ActionChip(
                  key: const ValueKey('ocr-ai-fix'),
                  avatar: Icon(AppIcons.ai,
                      size: AppIcons.small,
                      color: Edition.current.has(Feature.ai)
                          ? scheme.primary
                          : scheme.onSurfaceVariant),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t('ocr_studio.ai_fix')),
                      if (!Edition.current.has(Feature.ai)) ...[
                        const SizedBox(width: Gap.xs),
                        const ProBadge(),
                      ],
                    ],
                  ),
                  onPressed: text.isEmpty || _aiBusy ? null : _fixWithAi,
                ),
                ActionChip(
                  key: const ValueKey('ocr-copy'),
                  avatar: const Icon(AppIcons.clipCopy, size: AppIcons.small),
                  label: Text(context.t('common.copy')),
                  onPressed: text.isEmpty ? null : _copyText,
                ),
                ActionChip(
                  key: const ValueKey('ocr-share'),
                  avatar: const Icon(AppIcons.share, size: AppIcons.small),
                  label: Text(context.t('common.share')),
                  onPressed: text.isEmpty ? null : _shareText,
                ),
                ActionChip(
                  key: const ValueKey('ocr-save-txt'),
                  avatar: const Icon(AppIcons.save, size: AppIcons.small),
                  label: Text(context.t('ocr_studio.save_txt')),
                  onPressed: text.isEmpty ? null : _saveTxt,
                ),
                ActionChip(
                  key: const ValueKey('ocr-read'),
                  avatar: Icon(
                    _readingAloud ? AppIcons.stop : AppIcons.volumeUp,
                    size: AppIcons.small,
                  ),
                  label: Text(context.t(
                      _readingAloud ? 'ocr_studio.stop_read' : 'ocr_studio.read')),
                  onPressed: text.isEmpty ? null : _toggleReadAloud,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
