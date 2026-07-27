import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_page_edit.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../widgets/pdf_edit_overlay.dart';
import '../widgets/pdf_save_dialog.dart';

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
      if (mounted) setState(() => _error = 'Belge hazırlanamadı: $e');
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
      });
    } on PdfPageRefused catch (e) {
      if (mounted) setState(() => _outline = PdfPageOutline.empty);
      _snack(e.message);
    } catch (e) {
      if (mounted) setState(() => _outline = PdfPageOutline.empty);
      _snack('Sayfa çözümlenemedi: $e');
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
      _snack('Arka plan öğeleri taranamadı: $e');
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
    if (mounted) _snack('Geri alındı');
  }

  // ── İşlemler ──────────────────────────────────────────────────────────────

  Future<void> _editParagraph(int index) async {
    if (index < 0 || index >= _outline.paragraphs.length) return;
    final paragraph = _outline.paragraphs[index];
    final newText = await _askParagraphText(paragraph.text);
    if (newText == null || !mounted) return;
    if (newText.trim() == paragraph.text.trim()) return;

    await _run(() async {
      final out = await PdfPageEdit.replaceParagraphInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        paragraphIndex: index,
        newText: newText.trim(),
      );
      await _apply(out, 'Paragraf güncellendi');
    });
  }

  Future<void> _deleteObject(int index) async {
    final ok = await _confirm('Görseli sil',
        'Bu görsel sayfadan kaldırılacak. Geri al ile döndürebilirsiniz.');
    if (ok != true) return;
    await _run(() async {
      final out = await PdfPageEdit.deleteObjectInBackground(
        await _workBytes(),
        pageIndex: _page - 1,
        objectIndex: index,
      );
      await _apply(out, 'Görsel silindi');
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
      await _apply(out, 'Görsel taşındı');
    });
  }

  Future<void> _removeBackground() async {
    if (_backgroundPicked.isEmpty) {
      _snack('Kaldırılacak öğe seçin');
      return;
    }
    await _run(() async {
      final out = await PdfPageEdit.removeBackgroundInBackground(
          await _workBytes(), {..._backgroundPicked});
      await _apply(out, 'Seçilen öğeler kaldırıldı');
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
      await _apply(out, 'Sayfa döndürüldü');
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
    } catch (e) {
      _longSnack('İşlem yapılamadı: $e');
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
        title: const Text('Belge korumalı'),
        content: const Text(
            'Bu belge düzenlemeye karşı kilitli ama parola sormadan açılıyor '
            '(izin kilidi). Korumayı kaldırıp düzenleyelim mi?\n\n'
            'Özgün dosyanız değişmez; koruma yalnız düzenlenen kopyada kalkar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Korumayı kaldır')),
        ],
      ),
    );
    if (unlock != true) return false;

    try {
      final unlocked = await PdfTools.removePasswordInBackground(
        await _workBytes(),
        currentPassword: '',
      );
      await _apply(unlocked, 'Koruma kaldırıldı');
      await body();
      return true;
    } catch (e) {
      _longSnack('Belgenin şifre koruması kaldırılamadı: $e\n\n'
          'Gerçek bir parola varsa PDF araçlarından kaldırıp yeniden deneyin.');
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
      note: 'Düzenlenmiş belgeyi nereye kaydedelim?',
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
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text(
            'Yaptığınız düzenlemeler henüz kaydedilmedi. Ne yapalım?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Kaydetme, çık')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Kaydet')),
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
              tooltip: 'Geri al',
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty || _busy ? null : _undoLast,
            ),
            IconButton(
              tooltip: 'Kaydet',
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
    final text = switch (_mode) {
      _EditMode.text => _outline.paragraphs.isEmpty
          ? 'Bu sayfada düzenlenebilir metin bulunamadı (taranmış sayfa olabilir).'
          : 'Değiştirmek istediğiniz paragrafa dokunun.',
      _EditMode.image => _outline.objects.isEmpty
          ? 'Bu sayfada gömülü görsel yok.'
          : 'Görsele dokunup seçin; sürükleyerek taşıyın, köşeden boyutlandırın.',
      _EditMode.background =>
        'Her sayfada yinelenen öğeler aşağıda. Kaldırmak istediklerinizi seçin.',
      _EditMode.page => 'Açık sayfayı döndürün.',
    };
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
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.text_fields), label: 'Metin'),
          NavigationDestination(icon: Icon(Icons.image_outlined), label: 'Görsel'),
          NavigationDestination(icon: Icon(Icons.layers_clear), label: 'Filigran'),
          NavigationDestination(
              icon: Icon(Icons.rotate_90_degrees_cw), label: 'Sayfa'),
        ],
      );

  Widget _objectToolbar() {
    final index = _selectedObject!;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _deleteObject(index),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedObject = null),
              icon: const Icon(Icons.close),
              label: const Text('Seçimi bırak'),
            ),
          ],
        ),
      ),
    );
  }

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
                label: const Text('90° sola'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _rotate(1),
                icon: const Icon(Icons.rotate_90_degrees_cw),
                label: const Text('90° sağa'),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Yinelenen arka plan öğesi bulunamadı.',
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
              label: Text('Seçilenleri kaldır (${_backgroundPicked.length})'),
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
  Future<String?> _askParagraphText(String original) {
    final controller = TextEditingController(text: original);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paragrafı düzenle'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Şu anki metin',
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
                decoration: const InputDecoration(
                  labelText: 'Yeni metin',
                  helperText: 'Yazı tipi, punto ve sayfa düzeni korunur.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Uygula'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sil')),
          ],
        ),
      );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Uzun açıklamalar (reddetme gerekçeleri) kaybolmadan okunabilsin.
  void _longSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      showCloseIcon: true,
    ));
  }
}
