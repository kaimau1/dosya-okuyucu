import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../services/conversion_service.dart';
import '../services/document_scanner.dart';
import '../services/pdf_tools.dart';

/// **PDF Araçları** — sayfa ızgarası üzerinden birleştir / çıkar / sil / sırala /
/// döndür, ayrıca parola ve sıkıştırma.
///
/// Çalışma biçimi: dosya belleğe alınır, işlemler bellekteki baytlara uygulanır
/// (anında önizleme), kullanıcı **Kaydet** deyince diske yazılır. Böylece geri
/// alma ucuz ve yanlış dokunuş dosyayı bozmaz.
class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key, required this.path});

  final String path;

  /// Ekranı açar; [path] yoksa kullanıcıya PDF seçtirir. Dosya kaydedildiyse
  /// `true` döner (çağıran görüntüleyiciyi tazeleyebilir).
  static Future<bool?> open(BuildContext context, {String? path}) async {
    var target = path;
    if (target == null) {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      target = res?.files.single.path;
      if (target == null) return null;
    }
    if (!context.mounted) return null;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PdfToolsScreen(path: target!)),
    );
  }

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  final _conversion = ConversionService();

  Uint8List? _bytes;
  String? _password;
  String? _error;

  /// Seçili sayfalar (0-tabanlı).
  final _selected = <int>{};

  /// Geri alma yığını. Sayfa silme geri alınamazsa korkutucu; 5 adım yeter.
  final _undo = <Uint8List>[];

  bool _dirty = false;
  bool _busy = false;

  /// pdfrx `PdfDocumentRefData`'yı YALNIZ `sourceName` ile eşit sayar; bayt
  /// değişince aynı ad verilirse önizleme tazelenmez → her işlemde artar.
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Şifreli belge: sayfa sayısı okunamıyorsa parola sor.
      try {
        await PdfTools.pageCount(bytes);
      } catch (_) {
        final pw = await _askPassword('Belge parolalı', 'Parolayı girin');
        if (pw == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        await PdfTools.pageCount(bytes, password: pw);
        _password = pw;
      }
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Tüm işlemlerin tek kapısı: yeni baytı üretir, geri almayı besler, önizlemeyi
  /// tazeler. Hata olursa belge dokunulmadan kalır.
  Future<void> _apply(
    String label,
    Future<List<int>> Function(Uint8List bytes) op,
  ) async {
    final current = _bytes;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    try {
      final out = Uint8List.fromList(await op(current));
      if (!mounted) return;
      setState(() {
        _undo.add(current);
        if (_undo.length > 5) _undo.removeAt(0);
        _bytes = out;
        _selected.clear();
        _dirty = true;
        _rev++;
      });
    } catch (e) {
      if (mounted) _snack('$label başarısız: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int> _pageCount() =>
      PdfTools.pageCount(_bytes!, password: _password);

  // ── İşlemler ──────────────────────────────────────────────────────────────

  Future<void> _rotate() async {
    final pages = _selected.isEmpty
        ? List.generate(await _pageCount(), (i) => i)
        : _selected.toList();
    await _apply(
      'Döndürme',
      (b) => PdfTools.rotatePages(b,
          pageIndexes: pages, quarterTurns: 1, password: _password),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.length >= await _pageCount()) {
      _snack('Tüm sayfalar silinemez');
      return;
    }
    final pages = _selected.toList();
    await _apply('Silme',
        (b) => PdfTools.deletePages(b, pages, password: _password));
  }

  /// Sayfa kopyalayan işlemler vurguları taşıyamaz — kullanıcı bilmeden
  /// kaybetmesin diye yalnız belgede vurgu VARSA sorulur.
  Future<bool> _confirmAnnotationLoss(String action) async {
    final count = await PdfTools.annotationCount(_bytes!, password: _password);
    if (count == 0 || !mounted) return count == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vurgular kaybolacak'),
        content: Text('Bu belgede $count vurgu/not var. "$action" işlemi '
            'sayfaları yeniden oluşturduğu için bunlar silinir.\n\n'
            'Sayfa silmek isterseniz "Sil" düğmesi vurguları korur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Devam et')),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Seçili sayfaları **yeni bir PDF** olarak paylaşır (böl / sayfa çıkar).
  Future<void> _extractSelected() async {
    if (_selected.isEmpty || _bytes == null) return;
    final pages = _selected.toList()..sort();
    setState(() => _busy = true);
    try {
      final out = await PdfTools.selectPages(_bytes!, pages,
          password: _password);
      final name = '${p.basenameWithoutExtension(widget.path)}'
          '_sayfa${pages.length == 1 ? pages.first + 1 : '${pages.length}'}.pdf';
      final path =
          await _conversion.writeToTemp(name, Uint8List.fromList(out));
      await Share.shareXFiles([XFile(path)],
          text: 'Seçili sayfalar ayrı PDF olarak çıkarıldı');
    } catch (e) {
      if (mounted) _snack('Çıkarma başarısız: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tek seçili sayfayı bir sıra öne/arkaya taşır.
  ///
  /// ponytail: sürükle-bırak yerine ok düğmeleri — çok daha az kod, aynı iş.
  /// Uzun belgede sıkıcı olursa `ReorderableGridView` benzeri bir çözüme geç.
  Future<void> _move(int delta) async {
    if (_selected.length != 1) return;
    final from = _selected.first;
    final total = await _pageCount();
    final to = from + delta;
    if (to < 0 || to >= total) return;
    if (!await _confirmAnnotationLoss('Sayfa taşıma')) return;
    final order = movePageOrder(total, from, to);
    await _apply('Taşıma',
        (b) => PdfTools.selectPages(b, order, password: _password));
    if (mounted) setState(() => _selected.add(to));
  }

  Future<void> _mergeOther() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    final paths = res?.files.map((f) => f.path).whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    if (!await _confirmAnnotationLoss('Birleştirme')) return;
    final others = [
      for (final path in paths) await File(path).readAsBytes(),
    ];
    await _apply('Birleştirme', (b) => PdfTools.merge([b, ...others]));
    if (mounted) _snack('${paths.length} PDF eklendi');
  }

  /// Kameradan yeni sayfa(lar) tarayıp belgenin sonuna ekler — kâğıt eki olan
  /// sözleşme/rapor için asıl işe yarayan birleşim.
  Future<void> _scanAndAppend() async {
    final pages = await DocumentScanner.scanPages();
    if (pages == null) return;
    if (!await _confirmAnnotationLoss('Tarama ekleme')) return;
    // Hata/ilerleme yönetimi _apply'da; taranan sayfalar ızgarada zaten görünür.
    await _apply('Tarama ekleme', (b) async {
      final scanned = await _conversion.imagesToPdf(pages);
      return PdfTools.merge([b, scanned]);
    });
  }

  Future<void> _compress() async {
    final before = _bytes!.length;
    await _apply('Sıkıştırma',
        (b) => PdfTools.compress(b, password: _password));
    if (!mounted) return;
    final after = _bytes!.length;
    _snack(after < before
        ? 'Boyut ${_kb(before)} → ${_kb(after)}'
        : 'Bu belge zaten sıkışık (${_kb(before)}) — kazanç yok');
  }

  Future<void> _setPassword() async {
    final pw = await _askPassword('Parola koy', 'Yeni parola');
    if (pw == null || pw.isEmpty) return;
    await _apply(
      'Parola koyma',
      (b) => PdfTools.setPassword(b,
          password: pw, currentPassword: _password),
    );
    if (mounted) setState(() => _password = pw);
  }

  Future<void> _removePassword() async {
    final pw = _password;
    if (pw == null) return;
    await _apply(
        'Parola kaldırma', (b) => PdfTools.removePassword(b, currentPassword: pw));
    if (mounted) setState(() => _password = null);
  }

  Future<void> _save() async {
    if (_bytes == null || !_dirty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydet'),
        content: Text('Değişiklikler ${p.basename(widget.path)} dosyasının '
            'üzerine yazılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Üzerine yaz')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await File(widget.path).writeAsBytes(_bytes!, flush: true);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('Kaydedildi');
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  Future<void> _share() async {
    if (_bytes == null) return;
    final path = await _conversion.writeToTemp(
        p.basename(widget.path), _bytes!);
    await Share.shareXFiles([XFile(path)], text: 'PDF');
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _bytes = _undo.removeLast();
      _selected.clear();
      _dirty = true;
      _rev++;
    });
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  Future<String?> _askPassword(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Tamam')),
        ],
      ),
    );
  }

  String _kb(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).round()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklik'),
        content: const Text('Çıkarsanız yaptığınız düzenlemeler kaybolur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çık')),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Kaydedilmemiş değişiklikle geri tuşu: onay al, sonra kapat.
  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final leave = await _confirmLeave();
    if (!mounted || !leave) return;
    Navigator.of(context).pop(false);
  }

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.path),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Geri al',
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty ? null : _undoLast,
            ),
            IconButton(
              tooltip: 'Kaydet',
              icon: const Icon(Icons.save_outlined),
              onPressed: _dirty ? _save : null,
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'scan' => _scanAndAppend(),
                'merge' => _mergeOther(),
                'compress' => _compress(),
                'lock' => _setPassword(),
                'unlock' => _removePassword(),
                'share' => _share(),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'scan', child: Text('Sayfa tara ve ekle')),
                const PopupMenuItem(
                    value: 'merge', child: Text('Başka PDF ekle (birleştir)')),
                const PopupMenuItem(
                    value: 'compress', child: Text('Sıkıştır (boyut küçült)')),
                if (_password == null)
                  const PopupMenuItem(value: 'lock', child: Text('Parola koy'))
                else
                  const PopupMenuItem(
                      value: 'unlock', child: Text('Parolayı kaldır')),
                const PopupMenuItem(value: 'share', child: Text('Paylaş')),
              ],
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Açılamadı: $_error'),
              ))
            : bytes == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      _pageGrid(bytes),
                      if (_busy)
                        const LinearProgressIndicator(minHeight: 3),
                    ],
                  ),
        bottomNavigationBar: bytes == null ? null : _actionBar(),
      ),
    );
  }

  Widget _pageGrid(Uint8List bytes) {
    return PdfDocumentViewBuilder(
      // sourceName revizyonu taşır: düzenleme sonrası önizleme tazelensin.
      documentRef: PdfDocumentRefData(
        bytes,
        sourceName: '${widget.path}#$_rev',
        passwordProvider: _password == null ? null : () async => _password,
      ),
      builder: (context, document) {
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final count = document.pages.length;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: count,
          itemBuilder: (context, i) => _pageTile(document, i),
        );
      },
    );
  }

  Widget _pageTile(PdfDocument document, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected.contains(index);
    return InkWell(
      onTap: () => setState(() {
        if (!_selected.remove(index)) _selected.add(index);
      }),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PdfPageView(
                    document: document,
                    pageNumber: index + 1,
                    // Küçük resim: 300 DPI gereksiz bellek yer.
                    maximumDpi: 96,
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                  if (selected)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.check_circle,
                            color: scheme.primary, size: 22),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${index + 1}', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final has = _selected.isNotEmpty;
    final single = _selected.length == 1;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barButton(Icons.rotate_right, has ? 'Döndür' : 'Tümünü döndür',
              _busy ? null : _rotate),
          _barButton(Icons.delete_outline, 'Sil',
              has && !_busy ? _deleteSelected : null),
          _barButton(Icons.call_split, 'Çıkar',
              has && !_busy ? _extractSelected : null),
          _barButton(Icons.arrow_upward, 'Öne',
              single && !_busy ? () => _move(-1) : null),
          _barButton(Icons.arrow_downward, 'Arkaya',
              single && !_busy ? () => _move(1) : null),
        ],
      ),
    );
  }

  Widget _barButton(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: onTap == null ? Theme.of(context)
                  .disabledColor : null),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: onTap == null ? Theme.of(context).disabledColor : null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
