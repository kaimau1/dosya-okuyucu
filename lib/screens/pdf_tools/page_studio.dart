import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdfrx/pdfrx.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../services/conversion_service.dart';
import '../../services/document_scanner.dart';
import '../../services/pdf_tools.dart';
import '../../services/scan_prepare.dart';
import '../../widgets/app_dialog.dart';
import '../fm/pick_file_screen.dart' show AppFilePicker, PickedFile;

/// Stüdyodaki bir sayfa: [id] çoğaltılan kopyaları ayırır (anahtar),
/// [page] sanal 0-tabanlı indeks (önce bu belge, sonra dosyadan eklenenler;
/// [PdfTools.studioBlank] = boş sayfa),
/// [turns] eklenecek çeyrek tur.
typedef _Item = ({int id, int page, int turns});

/// **Sayfa stüdyosu** (B4/P20, PDF_PRO Faz 63 m.1) — küçük resim ızgarası:
/// dokun = seç, basılı tut + sürükle = taşı; seçilenleri döndür, sil, çoğalt,
/// ardına boş sayfa, başka PDF'in sayfalarını, görsel ya da tarama ekle;
/// seçilenleri yeni PDF'e çıkar ya da seçilenlerden böl;
/// her adım geri alınabilir. Sonuç `PdfTools.applyPageStudio` girdisidir
/// ([PdfStudioResult]; `newFiles` boş değilse her parça ayrı yeni dosya,
/// belge değişmez) ya da vazgeçilirse `null`.
///
/// Perf: hücre boyu ızgara delegesiyle sabit (ölçüm yok), küçük resim 72 DPI
/// + `RepaintBoundary`, ızgara tembel (yalnız görünen sayfa çizilir); belge
/// bir kez açılır. Döndürme yeniden çizim değil `RotatedBox`. Seçim kök
/// `setState` ile (ekran kısa ömürlü araç; görünür hücre ~20, `PdfPageView`
/// aynı girdiyle yeniden çizmez) — cihazda ölçülmedi, C2'de.
///
/// Sürüklerken parmak ızgaranın üst/alt kenar bandındaysa ızgara
/// kendiliğinden kayar (kare başı sabit adım; `Timer` yalnız sürüklerken,
/// hücreler yeniden kurulmaz).
typedef PdfStudioResult = ({
  List<(int, int)> plan,
  int pageCount,
  List<Uint8List> extra,
  List<List<(int, int)>> newFiles,
});

class PdfPageStudioScreen extends StatefulWidget {
  const PdfPageStudioScreen({super.key, required this.bytes, this.password});

  final Uint8List bytes;
  final String? password;

  static Future<PdfStudioResult?> open(BuildContext context,
          {required Uint8List bytes, String? password}) =>
      Navigator.of(context).push<PdfStudioResult>(MaterialPageRoute(
          builder: (_) =>
              PdfPageStudioScreen(bytes: bytes, password: password)));

  @override
  State<PdfPageStudioScreen> createState() => _PdfPageStudioScreenState();
}

class _PdfPageStudioScreenState extends State<PdfPageStudioScreen> {
  PdfDocument? _doc;

  /// Dosyadan eklenen belgeler (sanal indeks bu belgeden sonra sürer).
  final List<PdfDocument> _extraDocs = [];
  final List<Uint8List> _extraBytes = [];
  List<_Item> _items = const [];
  final List<List<_Item>> _history = [];
  final Set<int> _selected = {};
  int _nextId = 0;
  bool _loading = false;
  bool _scanning = false;
  final _scroll = ScrollController();
  final _gridKey = GlobalKey();
  Timer? _edgeTimer;
  double _edgeDir = 0;
  static const _edge = 56.0;
  static const _edgeStep = 14.0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final password = widget.password;
      final doc = await PdfDocument.openData(
        widget.bytes,
        passwordProvider: password == null ? null : () async => password,
      );
      if (!mounted) {
        await doc.dispose();
        return;
      }
      setState(() {
        _doc = doc;
        _items = [
          for (var i = 0; i < doc.pages.length; i++)
            (id: i, page: i, turns: 0),
        ];
        _nextId = doc.pages.length;
      });
    } catch (_) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _scroll.dispose();
    _doc?.dispose();
    for (final d in _extraDocs) {
      d.dispose();
    }
    super.dispose();
  }

  /// Geri alınabilir değişiklik: önceki hâl yığına girer.
  void _commit(List<_Item> next) {
    setState(() {
      _history.add(_items);
      if (_history.length > 50) _history.removeAt(0);
      _items = next;
      _selected.retainAll(next.map((e) => e.id));
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _items = _history.removeLast();
      _selected.retainAll(_items.map((e) => e.id));
    });
  }

  void _rotate(int turns) {
    AppHaptics.step();
    _commit([
      for (final e in _items)
        _selected.contains(e.id)
            ? (id: e.id, page: e.page, turns: (e.turns + turns) % 4)
            : e,
    ]);
  }

  /// Seçilen her sayfanın ardına [make] ile üretilen öğeyi koyar
  /// (çoğalt = aynı sayfa, boş ekle = [PdfTools.studioBlank]).
  void _insertAfterSelected(_Item Function(_Item) make) {
    AppHaptics.step();
    final next = <_Item>[];
    for (final e in _items) {
      next.add(e);
      if (_selected.contains(e.id)) next.add(make(e));
    }
    _commit(next);
  }

  void _duplicate() => _insertAfterSelected(
      (e) => (id: _nextId++, page: e.page, turns: e.turns));

  void _insertBlank() => _insertAfterSelected(
      (_) => (id: _nextId++, page: PdfTools.studioBlank, turns: 0));

  /// Sanal indeks → (belge, 1-tabanlı sayfa no).
  (PdfDocument, int) _locate(PdfDocument doc, int v) {
    var local = v;
    for (final d in [doc, ..._extraDocs]) {
      if (local < d.pages.length) return (d, local + 1);
      local -= d.pages.length;
    }
    return (doc, 1); // ulaşılmaz: indeksler yalnız buradan üretilir
  }

  Future<void> _insertFile() async {
    if (_loading || _scanning) return;
    final res = await AppFilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
    // Araçlardaki eski "PDF birleştir" çoklu dosya alıyordu: seçim sırasıyla,
    // her dosya bir öncekinin ardına.
    int? at;
    for (final f in res?.files ?? const <PickedFile>[]) {
      final path = f.path;
      if (path == null || !mounted) continue;
      at = await _insertPdf(() => File(path).readAsBytes(), at: at) ?? at;
    }
  }

  /// Görseller A4 sayfalara (Pro "Görsellerden PDF" ile aynı yol).
  Future<void> _insertImages() async {
    if (_loading || _scanning) return;
    final res =
        await AppFilePicker.pickFiles(type: FileType.image, allowMultiple: true);
    final paths = [
      for (final f in res?.files ?? const <PickedFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    await _insertPdf(() => ConversionService()
        .imagesToPdf(paths, uniformPage: PdfPageFormat.a4));
  }

  /// Tarama, araçlardaki "tara ve ekle" kuralıyla: sayfa olduğu gibi.
  Future<void> _insertScan() async {
    if (_loading || _scanning) return;
    _scanning = true;
    List<String>? scanned;
    try {
      scanned = await DocumentScanner.scanPages();
    } catch (e) {
      if (mounted) {
        showSnack(context, userErrorText(e));
      }
      return;
    } finally {
      _scanning = false;
    }
    if (scanned == null || scanned.isEmpty || !mounted) return;
    await _insertPdf(() async => ConversionService().imagesToPdf(
        ScanPage.displays(await ScanPrepare.pages(scanned!)),
        uniformPage: PdfPageFormat.a4));
  }

  /// [load]'un verdiği PDF'in tüm sayfalarını [at] konumuna (verilmezse son
  /// seçilenin ardına, yoksa sona) koyar; eklenenlerin bittiği konumu döner
  /// (eklenemediyse `null`).
  Future<int?> _insertPdf(Future<Uint8List> Function() load, {int? at}) async {
    setState(() => _loading = true);
    (Uint8List, PdfDocument)? opened;
    try {
      final b = await load();
      opened = (b, await PdfDocument.openData(b));
    } catch (_) {
      opened = null;
    }
    if (mounted) setState(() => _loading = false);
    if (!mounted) {
      await opened?.$2.dispose();
      return null;
    }
    if (opened == null) {
      showSnack(context, context.t('pp.studio_file_failed'));
      return null;
    }
    final (bytes, other) = opened;
    final doc = _doc!;
    var start = doc.pages.length;
    for (final d in _extraDocs) {
      start += d.pages.length;
    }
    _extraDocs.add(other);
    _extraBytes.add(bytes);
    var pos = at ?? _items.length;
    if (at == null) {
      for (var i = _items.length - 1; i >= 0; i--) {
        if (_selected.contains(_items[i].id)) {
          pos = i + 1;
          break;
        }
      }
    }
    AppHaptics.step();
    _commit([
      ..._items.take(pos),
      for (var i = 0; i < other.pages.length; i++)
        (id: _nextId++, page: start + i, turns: 0),
      ..._items.skip(pos),
    ]);
    return pos + other.pages.length;
  }

  void _delete() {
    // En az bir özgün sayfa kalmalı (yalnız boş sayfalı belge anlamsız).
    if (!_items.any((e) =>
        !_selected.contains(e.id) && e.page != PdfTools.studioBlank)) {
      showSnack(context, context.t('pt.cannot_delete_all'));
      return;
    }
    AppHaptics.destructive();
    _commit([
      for (final e in _items)
        if (!_selected.contains(e.id)) e
    ]);
  }

  /// Seçilenleri (stüdyodaki sırayla) yeni PDF'e çıkarır.
  void _extract() {
    final part = [
      for (final e in _items)
        if (_selected.contains(e.id)) (e.page, e.turns),
    ];
    if (!part.any((e) => e.$1 != PdfTools.studioBlank)) {
      showSnack(context, context.t('pp.studio_need_page'));
      return;
    }
    _finish([part]);
  }

  /// Her seçili sayfadan önce keserek parçaları ayrı PDF'lere böler.
  void _split() {
    final parts = PdfTools.studioSplit(
      [for (final e in _items) (e.page, e.turns)],
      {
        for (var k = 0; k < _items.length; k++)
          if (_selected.contains(_items[k].id)) k,
      },
    );
    if (parts.length < 2) {
      showSnack(context, context.t('pp.studio_split_hint'));
      return;
    }
    _finish(parts);
  }

  void _finish(List<List<(int, int)>> newFiles) =>
      Navigator.pop<PdfStudioResult>(context, (
        plan: [for (final e in _items) (e.page, e.turns)],
        pageCount: _doc!.pages.length,
        extra: _extraBytes,
        newFiles: newFiles,
      ));

  /// Sürükleme konumu ızgaranın kenar bandındaysa kaydırıcıyı başlatır.
  void _dragAt(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final y = box.globalToLocal(global).dy;
    _edgeDir = y < _edge
        ? -1.0
        : y > box.size.height - _edge
            ? 1.0
            : 0.0;
    if (_edgeDir == 0) {
      _stopEdge();
      return;
    }
    // Kare başı bir adım (zamanlayıcı, animasyon süresi değil).
    _edgeTimer ??= Timer.periodic(const Duration(microseconds: 16667), (_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final to = (pos.pixels + _edgeDir * _edgeStep)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (to != pos.pixels) _scroll.jumpTo(to);
    });
  }

  void _stopEdge() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
  }

  /// Tek seçili sayfayı numarayla konuma taşır (uzun belgede sürüklemek
  /// yerine; araçlardaki "Sayfayı taşı…", kullanıcı isteği 2026-09-03).
  Future<void> _moveTo() async {
    final from = _items.indexWhere((e) => _selected.contains(e.id));
    if (from < 0) return;
    final total = _items.length;
    final text = await showAppPrompt(context,
        title: context.t('pt.move_to'),
        label: context.t('pt.move_to_hint', {'n': '$total'}),
        initial: '${from + 1}');
    final to = int.tryParse(text ?? '');
    if (to == null || to < 1 || to > total || !mounted) return;
    AppHaptics.step();
    _move(from, to - 1);
  }

  /// Tüm sırayı ters çevirir (ters taranmış belge).
  void _reverse() {
    AppHaptics.step();
    _commit(_items.reversed.toList());
  }

  /// Belgeyi N sayfalık parçalara böler; her parça ayrı yeni PDF.
  Future<void> _splitEvery() async {
    if (_items.length < 2) {
      showSnack(context, context.t('pt.split_too_short'));
      return;
    }
    final size = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.t('pt.split_every')),
        children: [
          for (final n in const [1, 2, 5, 10])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text(ctx.t('pt.split_size', {'n': '$n'})),
            ),
        ],
      ),
    );
    if (size == null || !mounted) return;
    final parts = PdfTools.studioSplit(
      [for (final e in _items) (e.page, e.turns)],
      {for (var k = size; k < _items.length; k += size) k},
    );
    if (parts.length < 2) {
      showSnack(context, context.t('pt.split_too_short'));
      return;
    }
    _finish(parts);
  }

  void _move(int from, int to) {
    if (from == to) return;
    final next = [..._items];
    final item = next.removeAt(from);
    next.insert(to, item);
    _commit(next);
  }

  void _toggle(int id) {
    AppHaptics.selection();
    setState(() => _selected.contains(id)
        ? _selected.remove(id)
        : _selected.add(id));
  }

  void _toggleAll() {
    setState(() => _selected.length == _items.length
        ? _selected.clear()
        : _selected.addAll(_items.map((e) => e.id)));
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    if (_history.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showAppConfirm(
      context,
      title: context.t('pdf.discard_title'),
      message: context.t('pdf.discard_body'),
      confirmLabel: context.t('pdf.discard_confirm'),
      destructive: true,
    );
    if (leave && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final hasSel = _selected.isNotEmpty;
    return PopScope<PdfStudioResult>(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
      appBar: AppBar(
        title: Text(hasSel
            ? context.t('pp.studio_selected', {'n': _selected.length})
            : context.t('pp.studio')),
        actions: [
          IconButton(
            tooltip: context.t('common.undo'),
            icon: const Icon(AppIcons.undo),
            onPressed: _history.isEmpty ? null : _undo,
          ),
          PopupMenuButton<Future<void> Function()>(
            tooltip: context.t('pp.studio_insert'),
            icon: const Icon(AppIcons.postAdd),
            enabled: doc != null && !_loading,
            onSelected: (f) => unawaited(f()),
            itemBuilder: (ctx) => [
              for (final (icon, key, f) in [
                (AppIcons.postAdd, 'pp.studio_insert_file', _insertFile),
                (AppIcons.addPhoto, 'pp.studio_insert_image', _insertImages),
                (AppIcons.scanHere, 'pp.studio_insert_scan', _insertScan),
              ])
                PopupMenuItem(
                  value: f,
                  child: ListTile(
                    leading: Icon(icon),
                    title: Text(ctx.t(key)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: context.t('pt.select_all'),
            icon: const Icon(AppIcons.selectAll),
            onPressed: doc == null ? null : _toggleAll,
          ),
          PopupMenuButton<Future<void> Function()>(
            tooltip: context.t('common.more'),
            icon: const Icon(AppIcons.more),
            enabled: doc != null && !_loading,
            onSelected: (f) => unawaited(f()),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: _moveTo,
                enabled: _selected.length == 1,
                child: Text(ctx.t('pt.move_to')),
              ),
              PopupMenuItem(
                value: () async => _reverse(),
                child: Text(ctx.t('pt.op_reverse')),
              ),
              PopupMenuItem(
                value: _splitEvery,
                child: Text(ctx.t('pt.split_every')),
              ),
            ],
          ),
          TextButton(
            onPressed: _history.isEmpty
                ? null
                : () => _finish(const []),
            child: Text(context.t('common.ok')),
          ),
        ],
      ),
      bottomNavigationBar: hasSel
          ? SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: context.t('pp.rotate_left'),
                    icon: const Icon(AppIcons.rotateLeft),
                    onPressed: () => _rotate(3),
                  ),
                  IconButton(
                    tooltip: context.t('pp.rotate_right'),
                    icon: const Icon(AppIcons.rotateRight),
                    onPressed: () => _rotate(1),
                  ),
                  IconButton(
                    tooltip: context.t('pt.op_duplicate'),
                    icon: const Icon(AppIcons.copy),
                    onPressed: _duplicate,
                  ),
                  IconButton(
                    tooltip: context.t('pt.op_insert_blank'),
                    icon: const Icon(AppIcons.addFile),
                    onPressed: _insertBlank,
                  ),
                  IconButton(
                    tooltip: context.t('pp.studio_extract'),
                    icon: const Icon(AppIcons.pdf),
                    onPressed: _extract,
                  ),
                  IconButton(
                    tooltip: context.t('pp.studio_split'),
                    icon: const Icon(AppIcons.split),
                    onPressed: _split,
                  ),
                  IconButton(
                    tooltip: context.t('common.delete'),
                    icon: const Icon(AppIcons.delete),
                    onPressed: _delete,
                  ),
                ],
              ),
            )
          : null,
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.md, Gap.sm, Gap.md, 0),
                  child: Text(context.t('pp.studio_hint'),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: GridView.builder(
                    key: _gridKey,
                    controller: _scroll,
                    padding: const EdgeInsets.all(Gap.md),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 132,
                      mainAxisSpacing: Gap.sm,
                      crossAxisSpacing: Gap.sm,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => _cell(context, doc, i),
                  ),
                ),
              ],
            ),
    ),
    );
  }

  Widget _cell(BuildContext context, PdfDocument doc, int index) {
    final item = _items[index];
    final selected = _selected.contains(item.id);
    final scheme = Theme.of(context).colorScheme;
    final thumb = RepaintBoundary(
      child: RotatedBox(
        quarterTurns: item.turns,
        child: item.page == PdfTools.studioBlank
            ? const ColoredBox(color: AppColors.page, child: SizedBox.expand())
            : PdfPageView(
                document: _locate(doc, item.page).$1,
                pageNumber: _locate(doc, item.page).$2,
                maximumDpi: 72,
                decoration: const BoxDecoration(color: AppColors.page),
              ),
      ),
    );
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xs),
        child: Column(
          children: [
            Expanded(child: thumb),
            const SizedBox(height: Gap.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected)
                  Icon(AppIcons.checkCircle, size: 16, color: scheme.primary),
                Text(' ${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
    return DragTarget<int>(
      key: ValueKey(item.id),
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) {
        AppHaptics.drop();
        _move(d.data, index);
      },
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: index,
        hapticFeedbackOnStart: false, // AppHaptics ayarı dinler
        onDragStarted: AppHaptics.longPress,
        onDragUpdate: (d) => _dragAt(d.globalPosition),
        onDragEnd: (_) => _stopEdge(),
        feedback: SizedBox(
          width: 96,
          height: 132,
          child: Material(elevation: 6, child: thumb),
        ),
        // Hücrede Opacity/saveLayer yok (kasma-kontrol m.1): boş çerçeve.
        childWhenDragging: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: scheme.outlineVariant),
          ),
        ),
        child: GestureDetector(
          onTap: () => _toggle(item.id),
          // Ağaç şekli sabit (m.3): bırakma hedefi yalnız rengi değiştirir.
          child: ColoredBox(
            color: candidates.isEmpty
                ? Colors.transparent
                : scheme.primaryContainer,
            child: tile,
          ),
        ),
      ),
    );
  }
}
