import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/pdf/pdf_ocr_text.dart';
import '../services/pdf/pdf_scanned_retype.dart';
import '../services/pdf_page_edit.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/scan_ai_fix.dart';
import '../services/scan_text_fix.dart';
import '../widgets/pdf_edit_overlay.dart';
import '../widgets/pdf_save_dialog.dart';
import '../core/snack.dart';

/// **Tek PDF düzenleme ekranı** — metin, görsel, filigran ve sayfa işlerinin
/// hepsi burada (2026-07-27 kullanıcı isteği: *"tüm bu işler tek bir pdf
/// düzenleme editör sayfasında yapılmalı"*).
///
/// Akış tasarımı, kullanıcının tarif ettiği gibi:
/// 1. Bir mod seç (alt çubuk: Metin · Görsel · Filigran · Sayfa),
/// 2. sayfada düzenlenecek öğeye dokun — çerçeveli kutular neyin
///    düzenlenebilir olduğunu peşinen gösterir, kullanıcı aramak zorunda değil,
/// 3. küçük bir pencerede düzenle → **Uygula** → sonuç HEMEN sayfada görünür,
/// 4. beğenmediysen **Geri al**,
/// 5. **Kaydet** → *Orijinali değiştir* / *Kopyasını kaydet* / *Klasör seç*.
///
/// Özgün dosyaya kaydedilene kadar DOKUNULMAZ: bütün düzenlemeler geçici bir
/// çalışma kopyasında yapılır. Kullanıcı vazgeçerse hiçbir iz kalmaz.
class PdfEditorScreen extends StatefulWidget {
  final String path;
  final int initialPage;

  const PdfEditorScreen({
    super.key,
    required this.path,
    this.initialPage = 1,
  });

  /// Ekranı açar; bir şey kaydedildiyse `true` döner (çağıran tazelesin).
  static Future<bool> open(
    BuildContext context, {
    required String path,
    int initialPage = 1,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PdfEditorScreen(path: path, initialPage: initialPage),
      ),
    );
    return saved ?? false;
  }

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

enum _EditMode { text, image, background, page }

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  /// Bu ekranın mesajları uzun asenkron işlerin **içinden** üretiliyor
  /// (`_run`, `_apply`, `catch` dalları); orada `context` kullanmak
  /// `use_build_context_synchronously` demektir. Dil uygulama genelinde tek
  /// olduğu için statik olan okunur. Doğrudan çizilen parçalarda `context.t`.
  AppStrings get _str => AppStrings.current;

  final _controller = PdfViewerController();

  /// Çalışma kopyası — özgün dosyaya kaydedene kadar hiç dokunulmaz.
  Directory? _workDir;
  String? _workPath;

  /// Geri alma yığını: her değişiklikten ÖNCEki hâlin dosya yolu.
  final List<String> _undo = [];

  _EditMode _mode = _EditMode.text;
  int _page = 1;
  int _pageCount = 0;
  PdfPageOutline _outline = PdfPageOutline.empty;
  List<PdfBackgroundEntry> _background = const [];
  final Set<int> _backgroundPicked = {};

  int? _selectedObject;
  bool _busy = false;
  bool _dirty = false;
  bool _ready = false;
  String? _error;

  // ── Taranmış sayfa düzenleme (2026-08-06: "taranmış belge deyip düzenleme
  // yaptırmıyor — PDF'de yapılabilmeli") ───────────────────────────────────
  /// Bu oturumda "taranmış" olarak sınıflanan sayfalar (1-tabanlı). YAPIŞKAN:
  /// bir satırın üstüne yazılınca sayfada gerçek metin oluşur ve paragraf
  /// sayısı artar; sınıf değişseydi kalan OCR satırları düzenlenemez kalırdı.
  final Set<int> _scannedPages = {};

  /// Açık sayfanın OCR satırları (yalnız taranmış sayfada dolu).
  List<ScannedLine> _scannedLines = const [];

  /// [_scannedLines] hangi (belge sürümü, sayfa) için yüklendi.
  String _scannedKey = '';
  bool _scannedLoading = false;

  /// Her başarılı düzenlemede artar — OCR kutuları yeniden yüklensin.
  int _docRev = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _prepare();
  }

  @override
  void dispose() {
    // Kaydedilmemiş çalışma kopyasını bırakma: geçici klasör silinir.
    final dir = _workDir;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Silinemezse sistem geçici klasörü zaten temizler.
      }
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final dir = await Directory.systemTemp.createTemp('pdf_editor');
      final work = p.join(dir.path, p.basename(widget.path));
      await File(work).writeAsBytes(
          await File(widget.path).readAsBytes(),
          flush: true);
      if (!mounted) return;
      setState(() {
        _workDir = dir;
        _workPath = work;
        _ready = true;
      });
      await _loadOutline();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _str.t('pe.prepare_failed', {'error': e}));
      }
    }
  }

  // ── Veri ──────────────────────────────────────────────────────────────────

  Future<List<int>> _workBytes() => File(_workPath!).readAsBytes();

  /// Açık sayfanın düzenlenebilir öğelerini yükler.
  Future<void> _loadOutline() async {
    final path = _workPath;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final outline =
          await PdfPageEdit.outlineInBackground(await _workBytes(), _page - 1);
      if (!mounted) return;
      setState(() {
        _outline = outline;
        _selectedObject = null;
        _error = null;
        // Taranmış aday iki türlü olur: (1) hiç metin yok, (2) metin VAR ama
        // görünmez — "aranabilir PDF"in OCR katmanı (kullanıcı bulgusu
        // 2026-08-06: aranabilir tarattığı belgede düzeltme çubuğu hiç
        // çıkmıyordu, çünkü sayfa metinli sayılıyordu). Sınıf YAPIŞKAN.
        if (outline.paragraphs.isEmpty || outline.scanned) {
          _scannedPages.add(_page);
        }
      });
    } on PdfPageRefused catch (e) {
      if (mounted) setState(() => _outline = PdfPageOutline.empty);
      _snack(e.message);
    } catch (e) {
      if (mounted) setState(() => _outline = PdfPageOutline.empty);
      _snack(_str.t('pe.outline_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadBackground() async {
    setState(() => _busy = true);
    try {
      final items =
          await PdfPageEdit.backgroundItemsInBackground(await _workBytes());
      if (!mounted) return;
      setState(() {
        _background = items;
        _backgroundPicked.clear();
      });
    } on PdfPageRefused catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(_str.t('pe.background_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Değişikliği çalışma kopyasına yazar, geri alma noktası bırakır ve
  /// görüntüleyiciyi tazeler.
  Future<void> _apply(List<int> bytes, String note) async {
    final path = _workPath!;
    final snapshot = p.join(_workDir!.path, 'undo_${_undo.length}.pdf');
    await File(snapshot).writeAsBytes(await File(path).readAsBytes(),
        flush: true);
    _undo.add(snapshot);

    await File(path).writeAsBytes(bytes, flush: true);
    await PdfReload.reloadFile(path);
    if (!mounted) return;
    setState(() => _dirty = true);
    await _loadOutline();
    if (mounted) _snack(note);
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty) return;
    final snapshot = _undo.removeLast();
    await File(_workPath!)
        .writeAsBytes(await File(snapshot).readAsBytes(), flush: true);
    await PdfReload.reloadFile(_workPath!);
    if (!mounted) return;
    setState(() => _dirty = _undo.isNotEmpty);
    await _loadOutline();
    if (mounted) _snack(_str.t('pe.undone'));
  }

  // ── İşlemler ──────────────────────────────────────────────────────────────

  Future<void> _editParagraph(int index) async {
    if (index < 0 || index >= _outline.paragraphs.length) return;
    final paragraph = _outline.paragraphs[index];
    final currentSize = paragraphPointSize(paragraph);
    final answer = await _askParagraphText(
      paragraph.text,
      pointSize: currentSize > 0 ? currentSize : null,
    );
    if (answer == null || !mounted) return;
    final newText = answer.text;
    final size = answer.size;
    final sizeChanged =
        size != null && size > 0 && (size - currentSize).abs() > 0.05;
    if (newText.trim() == paragraph.text.trim() && !sizeChanged) return;

    await _run(() async {
      final out = await PdfPageEdit.replaceParagraphInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        paragraphIndex: index,
        newText: newText.trim(),
        pointSize: sizeChanged ? size : null,
      );
      await _apply(out, _str.t('pe.paragraph_updated'));
    });
  }

  /// Bu sayfada OCR ile düzenleme denenmeli mi?
  ///
  /// Taranmış sınıfı **ya da** sayfada görsel olması yeter: gömülü fotokopi
  /// bloğu taşıyan karma sayfalarda kullanıcı "metin var ama düzenletmiyor"
  /// diyordu. Tamamen metin olan sayfalarda (görsel yok) OCR çalıştırılmaz —
  /// gereksiz iş ve zaten paragraf kutuları var.
  bool get _ocrEditable =>
      _scannedPages.contains(_page) || _outline.objects.isNotEmpty;

  /// Taranmış sayfanın OCR satır kutularını (gerekiyorsa) yükler. [page]
  /// pdfrx'in CANLI sayfa nesnesi — overlay kurucusundan gelir; yeniden
  /// yüklemeden sonra da doğru belgeyi gösterir. Yalnız zamanlar: build
  /// sırasında çağrılır ama iş Future'a atıldığı için build'i bozmaz.
  void _maybeLoadScanned(PdfPage page) {
    if (!PdfOcrText.isSupported || _scannedLoading) return;
    final key = '$_docRev#${page.pageNumber}';
    if (_scannedKey == key) return;
    _scannedLoading = true;
    Future(() async {
      var lines = const <ScannedLine>[];
      try {
        final ocr = await PdfOcrText.forPage(page);
        lines = [
          for (final f in ocr?.fragments ?? const <PdfPageTextFragment>[])
            if (f.text.trim().isNotEmpty) ScannedLine(f.text.trim(), f.bounds),
        ];
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _scannedKey = key;
        _scannedLines = _withoutParagraphOverlaps(lines);
        _scannedLoading = false;
      });
    });
  }

  /// Paragraf kutusuyla örtüşen OCR satırlarını eler: üstüne yazılmış satır
  /// artık GERÇEK metindir ve kutusu paragraf yolundan gelir — aynı yerde iki
  /// kutu (biri bayat) üst üste binmesin.
  List<ScannedLine> _withoutParagraphOverlaps(List<ScannedLine> lines) {
    if (_outline.paragraphs.isEmpty) return lines;
    bool overlaps(ScannedLine s) {
      for (final par in _outline.paragraphs) {
        final w = (s.box.right < par.right ? s.box.right : par.right) -
            (s.box.left > par.left ? s.box.left : par.left);
        final h = (s.box.top < par.top ? s.box.top : par.top) -
            (s.box.bottom > par.bottom ? s.box.bottom : par.bottom);
        if (w > 0 && h > 0 && w * h > 0.5 * s.box.width * s.box.height) {
          return true;
        }
      }
      return false;
    }

    return [
      for (final s in lines)
        if (!overlaps(s)) s
    ];
  }

  /// OCR satırına dokunuldu: tanınan metin ön-dolu pencerede düzenlenir,
  /// satır beyaz kapakla örtülüp yeni metin AYNI yere yazılır (bkz.
  /// [PdfScannedRetype]). Boş bırakmak satırı siler.
  Future<void> _editScannedLine(int index) async {
    if (index < 0 || index >= _scannedLines.length) return;
    final line = _scannedLines[index];
    final answer = await _askParagraphText(line.text);
    if (answer == null || !mounted) return;
    final newText = answer.text;
    await _run(() async {
      final out = await PdfScannedRetype.apply(
        bytes: await _workBytes(),
        pageIndex: _page - 1,
        box: line.box,
        newText: newText,
      );
      // Sayfa değişti: OCR bellek önbelleği bayat, kutular yeniden yüklensin.
      PdfOcrText.invalidateMemory();
      _docRev++;
      await _apply(out, _str.t('pe.scanned_updated'));
    });
  }

  /// **Sayfayı düzelt** — taranmış sayfanın TÜM satırlarını bir geçişte
  /// onarır (2026-08-06 kullanıcı isteği: *"düzenle ve AI ile düzenle butonu
  /// koyalım, taranan sayfaları ikisi de mükemmelleştirmeye çalışsın"*).
  ///
  /// [withAi] false → cihaz-içi kural tabanlı düzeltme ([ScanTextFix]):
  /// ücretsiz, çevrimdışı, yalnız kesin bildiğini düzeltir.
  /// [withAi] true → Gemini ([ScanAiFix]): bağlama bakarak daha cesur onarır.
  ///
  /// **Yalnız DEĞİŞEN satırlar yeniden yazılır.** Bütün satırları basmak,
  /// hiç hatası olmayan satırların görüntüsünü de gömülü fontla değiştirirdi;
  /// sayfa "tarama" olmaktan çıkar, kutu hataları her satırda görünür olurdu.
  Future<void> _fixScannedPage({required bool withAi}) async {
    if (_scannedLines.isEmpty) return;
    final originals = [for (final l in _scannedLines) l.text];
    GeminiService? gemini;
    if (withAi) {
      final state = context.read<AppState>();
      if (!state.hasApiKey) {
        _longSnack(_str.t('pe.fix_needs_key'));
        return;
      }
      gemini = state.gemini;
    }

    await _run(() async {
      final fixed = withAi
          ? await ScanAiFix.polish(gemini!, originals)
          : ScanTextFix.lines(originals);
      final edits = <ScannedEdit>[];
      for (var i = 0; i < originals.length && i < fixed.length; i++) {
        if (fixed[i].trim() == originals[i].trim()) continue;
        edits.add(ScannedEdit(_scannedLines[i].box, fixed[i]));
      }
      if (edits.isEmpty) {
        _snack(_str.t('pe.fix_nothing'));
        return;
      }
      final out = await PdfScannedRetype.applyMany(
        bytes: await _workBytes(),
        pageIndex: _page - 1,
        edits: edits,
      );
      // Sayfa değişti: OCR bellek önbelleği bayat, kutular yeniden yüklensin.
      PdfOcrText.invalidateMemory();
      _docRev++;
      await _apply(out, _str.t('pe.fix_done', {'n': edits.length}));
    });
  }

  Future<void> _deleteObject(int index) async {
    final ok =
        await _confirm(_str.t('pe.delete_image'), _str.t('pe.delete_image_body'));
    if (ok != true) return;
    await _run(() async {
      final out = await PdfPageEdit.deleteObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
      );
      await _apply(out, _str.t('pe.image_deleted'));
    });
  }

  Future<void> _moveObject(int index, Rect pageRect) async {
    await _run(() async {
      final out = await PdfPageEdit.transformObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
        left: pageRect.left,
        bottom: pageRect.top < pageRect.bottom ? pageRect.top : pageRect.bottom,
        width: pageRect.width.abs(),
        height: pageRect.height.abs(),
      );
      await _apply(out, _str.t('pe.image_moved'));
    });
  }

  /// Seçili görseli **kendi merkezinde** döndürür / aynalar (kullanıcı
  /// 2026-08-30). Sayfa döndürmeden ayrı: burada yalnız o görsel oynar.
  Future<void> _turnObject(
    int index, {
    int quarterTurns = 0,
    bool flipH = false,
    bool flipV = false,
  }) async {
    await _run(() async {
      final out = await PdfPageEdit.turnObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
        quarterTurns: quarterTurns,
        flipH: flipH,
        flipV: flipV,
      );
      await _apply(
          out,
          _str.t(quarterTurns != 0
              ? 'pe.image_turned'
              : 'pe.image_mirrored'));
    });
  }

  Future<void> _removeBackground() async {
    if (_backgroundPicked.isEmpty) {
      _snack(_str.t('pe.pick_to_remove'));
      return;
    }
    await _run(() async {
      final out = await PdfPageEdit.removeBackgroundInBackground(
          await _workBytes(), {..._backgroundPicked});
      await _apply(out, _str.t('pe.items_removed'));
      await _loadBackground();
    });
  }

  Future<void> _rotate(int quarterTurns) async {
    await _run(() async {
      final out = await PdfTools.rotatePagesInBackground(
        await _workBytes(),
        pageIndexes: [_page - 1],
        quarterTurns: quarterTurns,
      );
      await _apply(out, _str.t('pe.page_rotated'));
    });
  }

  /// Ortak sarmalayıcı: meşgul bayrağı + tek yerde hata mesajı.
  ///
  /// Reddedilme mesajları kullanıcıya doğrudan gösterilebilir biçimde
  /// yazıldı ("metin sığmıyor, 2 satır fazla geliyor" gibi); teknik bir
  /// istisna metnine sarmadan aynen gösteriyoruz.
  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } on PdfPageRefused catch (e) {
      // İzin kilitli belge: koruma boş parolayla kalkıyorsa düzenleme tam
      // sadakatle çalışır. Kullanıcıya "PDF araçlarına git, parolayı kaldır,
      // geri gel" diye ödev vermek yerine tek soruyla burada hallediyoruz.
      if (e.encrypted && await _unlockAndRetry(body)) return;
      _longSnack(e.message);
    } on PdfParagraphRefused catch (e) {
      _longSnack(e.message);
    } on ScanAiFixRefused catch (e) {
      // Eksik/bozuk AI yanıtı: sebebi kullanıcıya olduğu gibi söyleniyor,
      // "işlem başarısız" gibi bir örtü metnin altına saklanmıyor.
      _longSnack(e.message);
    } on GeminiException catch (e) {
      _longSnack(e.message);
    } catch (e) {
      _longSnack(_str.t('pe.op_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Şifre korumasını kaldırıp işlemi bir kez daha dener.
  ///
  /// Koruma yalnız ÇALIŞMA KOPYASINDA kalkar; özgün dosya değişmez ve
  /// kullanıcı kaydetmezse hiçbir iz kalmaz.
  Future<bool> _unlockAndRetry(Future<void> Function() body) async {
    if (!mounted) return false;
    final unlock = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pe.protected_title')),
        content: Text(ctx.t('pe.protected_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pe.remove_protection'))),
        ],
      ),
    );
    if (unlock != true) return false;

    try {
      final unlocked = await PdfTools.removePasswordInBackground(
        await _workBytes(),
        currentPassword: '',
      );
      await _apply(unlocked, _str.t('pe.protection_removed'));
      await body();
      return true;
    } catch (e) {
      _longSnack(_str.t('pe.unlock_failed', {'error': e}));
      return true; // mesaj verildi; çağıran ikinci kez göstermesin
    }
  }

  // ── Kaydetme ──────────────────────────────────────────────────────────────

  Future<bool> _save() async {
    if (!_dirty) return true;
    final bytes = await _workBytes();
    if (!mounted) return false;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.path,
      bytes: bytes,
      note: _str.t('pe.save_note'),
    );
    if (outcome == null) return false;
    if (mounted) setState(() => _dirty = false);
    return true;
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pe.unsaved_title')),
        content: Text(ctx.t('pe.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(ctx.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(ctx.t('pe.discard_leave'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(ctx.t('common.save'))),
        ],
      ),
    );
    if (choice == 'save') return _save();
    return choice == 'discard';
  }

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator ÖNCE alınıyor: `await`ten sonra `context` kullanmak
        // ekran kapanmışsa hatalı (use_build_context_synchronously).
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop(!_dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.path),
              overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: context.t('common.undo'),
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty || _busy ? null : _undoLast,
            ),
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: !_dirty || _busy
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      if (await _save() && mounted) navigator.pop(true);
                    },
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
        ),
        body: _body(),
        bottomNavigationBar: _modeBar(),
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _hintBar(),
        Expanded(
          child: Stack(
            children: [
              PdfViewer.file(
                _workPath!,
                controller: _controller,
                params: PdfViewerParams(
                  onPageChanged: (page) {
                    if (page == null || page == _page) return;
                    setState(() => _page = page);
                    _loadOutline();
                  },
                  onViewerReady: (doc, _) {
                    if (mounted) setState(() => _pageCount = doc.pages.length);
                  },
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    if (page.pageNumber == _page &&
                        (_mode == _EditMode.text || _mode == _EditMode.image))
                      PdfEditOverlay(
                        page: page,
                        pageSize: pageRect.size,
                        outline: _outline,
                        textMode: _mode == _EditMode.text,
                        selectedObject: _selectedObject,
                        onParagraphTap: _editParagraph,
                        onObjectTap: (i) => setState(
                            () => _selectedObject = _selectedObject == i ? null : i),
                        onObjectChanged: _moveObject,
                      ),
                    // Taranmış sayfa: OCR satır kutuları da düzenlenebilir
                    // (2026-08-06 — "taranmış belge deyip düzenleme
                    // yaptırmıyor"). Kutu listesi bu sayfa+sürüm için
                    // yüklenmemişse boş çizilir, yükleme arkada tetiklenir.
                    //
                    // **2026-08-07 — daha müsade:** artık yalnız "taranmış"
                    // sınıfı yeterli değil. Metin katmanı olan ama İÇİNDE
                    // taranmış blok taşıyan sayfalar (üstte gerçek başlık,
                    // altta fotokopi tablo) da OCR kutusu alır — sayfada
                    // görsel varsa tanıma çalıştırılır. Paragrafla örtüşen
                    // satırlar zaten eleniyor (`_withoutParagraphOverlaps`),
                    // yani gerçek metnin üstüne ikinci kutu binmez.
                    if (page.pageNumber == _page &&
                        _mode == _EditMode.text &&
                        _ocrEditable &&
                        PdfOcrText.isSupported)
                      Builder(builder: (context) {
                        _maybeLoadScanned(page);
                        final fresh =
                            _scannedKey == '$_docRev#${page.pageNumber}';
                        return PdfScannedOverlay(
                          page: page,
                          pageSize: pageRect.size,
                          lines: fresh ? _scannedLines : const [],
                          onLineTap: _editScannedLine,
                        );
                      }),
                  ],
                ),
              ),
              if (_mode == _EditMode.image && _selectedObject != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _objectToolbar(),
                ),
              // Taranmış sayfada tüm satırları bir geçişte onaran ikili.
              if (_mode == _EditMode.text &&
                  _scannedPages.contains(_page) &&
                  _scannedLines.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _scannedToolbar(),
                ),
              if (_mode == _EditMode.page)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _pageToolbar(),
                ),
            ],
          ),
        ),
        if (_mode == _EditMode.background)
          SizedBox(height: 240, child: _backgroundPanel()),
      ],
    );
  }

  /// Kullanıcı ne yapacağını bilsin: her modda tek cümlelik yönerge.
  Widget _hintBar() {
    final text = context.t(switch (_mode) {
      _EditMode.text => _outline.paragraphs.isEmpty
          ? (_scannedPages.contains(_page) && PdfOcrText.isSupported
              ? 'pe.hint_text_scanned'
              : 'pe.hint_text_none')
          : 'pe.hint_text',
      _EditMode.image =>
        _outline.objects.isEmpty ? 'pe.hint_image_none' : 'pe.hint_image',
      _EditMode.background => 'pe.hint_background',
      _EditMode.page => 'pe.hint_page',
    });
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          if (_pageCount > 0)
            Text('$_page / $_pageCount',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _modeBar() => NavigationBar(
        selectedIndex: _EditMode.values.indexOf(_mode),
        onDestinationSelected: (i) {
          final mode = _EditMode.values[i];
          setState(() {
            _mode = mode;
            _selectedObject = null;
          });
          if (mode == _EditMode.background && _background.isEmpty) {
            _loadBackground();
          }
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.text_fields),
              label: context.t('pe.mode_text')),
          NavigationDestination(
              icon: const Icon(Icons.image_outlined),
              label: context.t('pe.mode_image')),
          NavigationDestination(
              icon: const Icon(Icons.layers_clear),
              label: context.t('pe.mode_watermark')),
          NavigationDestination(
              icon: const Icon(Icons.rotate_90_degrees_cw),
              label: context.t('pe.mode_page')),
        ],
      );

  /// Seçili görselin araç çubuğu.
  ///
  /// **İki satır** (kullanıcı 2026-08-30 — *"döndür seçenekleri olmalı, ayna
  /// görüntüsü seçeneği olmalı"*): üstte biçim işleri (sola/sağa döndür,
  /// yatay/dikey ayna) simge düğmeleriyle, altta sil/seçimi bırak. Dört
  /// yeni eylemi eski tek satıra eklemek 320 dp'lik bir ekranda etiketleri
  /// üst üste bindirirdi; simgeler ipuçlarıyla (tooltip) adlandırıldı.
  Widget _objectToolbar() {
    final index = _selectedObject!;
    Widget turn(IconData icon, String key, {int turns = 0, bool h = false, bool v = false}) =>
        IconButton(
          tooltip: context.t(key),
          onPressed: _busy
              ? null
              : () => _turnObject(index,
                  quarterTurns: turns, flipH: h, flipV: v),
          icon: Icon(icon),
          visualDensity: VisualDensity.compact,
        );
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                turn(Icons.rotate_90_degrees_ccw, 'pe.rot_left', turns: -1),
                turn(Icons.rotate_90_degrees_cw, 'pe.rot_right', turns: 1),
                turn(Icons.flip, 'pe.mirror_h', h: true),
                turn(Icons.flip_camera_android_outlined, 'pe.mirror_v',
                    v: true),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _deleteObject(index),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.t('common.delete')),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedObject = null),
                  icon: const Icon(Icons.close),
                  label: Text(context.t('pe.clear_selection')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Taranmış sayfa araç çubuğu: **Düzelt** (cihaz içi) ve **AI ile düzelt**.
  /// İkisi de aynı işi yapmaya çalışır, farkı ne kadar cesur olduklarıdır —
  /// kullanıcı hangisinin sonucunu beğenirse onda kalır, beğenmezse "Geri al".
  Widget _scannedToolbar() => Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _fixScannedPage(withAi: false),
                icon: const Icon(Icons.auto_fix_high),
                label: Text(context.t('pe.fix_page')),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _fixScannedPage(withAi: true),
                icon: const Icon(Icons.auto_awesome),
                label: Text(context.t('pe.fix_page_ai')),
              ),
            ],
          ),
        ),
      );

  Widget _pageToolbar() => Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _rotate(-1),
                icon: const Icon(Icons.rotate_90_degrees_ccw),
                label: Text(context.t('pe.rot_left')),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _rotate(1),
                icon: const Icon(Icons.rotate_90_degrees_cw),
                label: Text(context.t('pe.rot_right')),
              ),
            ],
          ),
        ),
      );

  Widget _backgroundPanel() {
    if (_busy && _background.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_background.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.t('pe.no_background'),
              textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _background.length,
            itemBuilder: (_, i) {
              final item = _background[i];
              return CheckboxListTile(
                dense: true,
                value: _backgroundPicked.contains(item.index),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _backgroundPicked.add(item.index);
                  } else {
                    _backgroundPicked.remove(item.index);
                  }
                }),
                secondary:
                    Icon(item.isImage ? Icons.image_outlined : Icons.title),
                title: Text(item.label, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(item.detail),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _removeBackground,
              icon: const Icon(Icons.layers_clear),
              label: Text(context.t(
                  'pe.remove_picked', {'n': _backgroundPicked.length})),
            ),
          ),
        ),
      ],
    );
  }

  // ── Küçük yardımcılar ─────────────────────────────────────────────────────

  /// Paragraf düzenleme penceresi.
  ///
  /// Özgün metin ÜSTTE, soluk ve salt okunur duruyor — kullanıcı neyi
  /// değiştirdiğini gözden kaçırmasın (isteğin birebir karşılığı: *"orjinal
  /// arka planda duruyor"*).
  /// Paragraf düzenleme penceresi: metin **ve** punto.
  ///
  /// [pointSize] paragrafın ölçülmüş görünen puntosudur; verilirse kullanıcı
  /// onu da değiştirebilir (kullanıcı isteği 2026-09-01: *"yazı puntosu
  /// tutmadı… ufacık yazdı"*). Verilmezse (taranmış sayfa satırı) yalnız
  /// metin sorulur ve dönen `size` null olur.
  Future<({String text, double? size})?> _askParagraphText(
    String original, {
    double? pointSize,
  }) {
    final controller = TextEditingController(text: original);
    // Punto kutusu: ölçülen değer bir tık yuvarlanır (9.9998 → 10).
    final rounded =
        pointSize == null ? null : (pointSize * 10).roundToDouble() / 10;
    final sizeController = TextEditingController(
        text: rounded == null ? '' : _trimZero(rounded));
    return showDialog<({String text, double? size})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pe.edit_paragraph')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.t('pe.current_text'),
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(original,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 8,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: ctx.t('pe.new_text'),
                  helperText: ctx.t('pe.new_text_help'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (rounded != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: ctx.t('pe.font_size'),
                          helperText: ctx.t('pe.font_size_help'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: ctx.t('pe.font_smaller'),
                      icon: const Icon(Icons.text_decrease),
                      onPressed: () => _nudgeSize(sizeController, -0.5),
                    ),
                    IconButton(
                      tooltip: ctx.t('pe.font_bigger'),
                      icon: const Icon(Icons.text_increase),
                      onPressed: () => _nudgeSize(sizeController, 0.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              text: controller.text,
              size: rounded == null
                  ? null
                  : double.tryParse(sizeController.text.replaceAll(',', '.')),
            )),
            child: Text(ctx.t('common.apply')),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
      sizeController.dispose();
    });
  }

  /// Punto kutusunu [delta] kadar oynatır (± düğmeleri).
  void _nudgeSize(TextEditingController c, double delta) {
    final current = double.tryParse(c.text.replaceAll(',', '.')) ?? 10;
    final next = (current + delta).clamp(2.0, 200.0);
    c.text = _trimZero((next * 10).roundToDouble() / 10);
  }

  /// `10.0` → `10`, `10.5` → `10.5`.
  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.delete'))),
          ],
        ),
      );

  void _snack(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }

  /// Uzun açıklamalar (reddetme gerekçeleri) kaybolmadan okunabilsin.
  void _longSnack(String message) {
    if (!mounted) return;
    showSnackBarReplacing(ScaffoldMessenger.of(context), SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      showCloseIcon: true,
    ));
  }
}
