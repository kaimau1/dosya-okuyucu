import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/pdf_tools.dart';

/// Stüdyodaki bir sayfa: [id] çoğaltılan kopyaları ayırır (anahtar),
/// [page] özgün 0-tabanlı indeks ([PdfTools.studioBlank] = boş sayfa),
/// [turns] eklenecek çeyrek tur.
typedef _Item = ({int id, int page, int turns});

/// **Sayfa stüdyosu** (B4/P20, PDF_PRO Faz 63 m.1) — küçük resim ızgarası:
/// dokun = seç, basılı tut + sürükle = taşı; seçilenleri döndür, sil, çoğalt,
/// ardına boş sayfa ekle;
/// her adım geri alınabilir. Sonuç `PdfTools.applyPageStudio` planıdır
/// (çıktı sırası: özgün indeks + çeyrek tur) ya da vazgeçilirse `null`.
///
/// Perf: hücre boyu ızgara delegesiyle sabit (ölçüm yok), küçük resim 72 DPI
/// + `RepaintBoundary`, ızgara tembel (yalnız görünen sayfa çizilir); belge
/// bir kez açılır. Döndürme yeniden çizim değil `RotatedBox`. Seçim kök
/// `setState` ile (ekran kısa ömürlü araç; görünür hücre ~20, `PdfPageView`
/// aynı girdiyle yeniden çizmez) — cihazda ölçülmedi, C2'de.
// ponytail: sürüklerken kenarda kendiliğinden kaydırma yok; uzun belgede
// gerekirse `Scrollable.ensureVisible`/kenar kaydırıcı eklenir.
class PdfPageStudioScreen extends StatefulWidget {
  const PdfPageStudioScreen({super.key, required this.bytes, this.password});

  final Uint8List bytes;
  final String? password;

  static Future<List<(int, int)>?> open(BuildContext context,
          {required Uint8List bytes, String? password}) =>
      Navigator.of(context).push<List<(int, int)>>(MaterialPageRoute(
          builder: (_) =>
              PdfPageStudioScreen(bytes: bytes, password: password)));

  @override
  State<PdfPageStudioScreen> createState() => _PdfPageStudioScreenState();
}

class _PdfPageStudioScreenState extends State<PdfPageStudioScreen> {
  PdfDocument? _doc;
  List<_Item> _items = const [];
  final List<List<_Item>> _history = [];
  final Set<int> _selected = {};
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
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
  }

  @override
  void dispose() {
    _doc?.dispose();
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

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final hasSel = _selected.isNotEmpty;
    return Scaffold(
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
          IconButton(
            tooltip: context.t('pt.select_all'),
            icon: const Icon(AppIcons.selectAll),
            onPressed: doc == null ? null : _toggleAll,
          ),
          TextButton(
            onPressed: _history.isEmpty
                ? null
                : () => Navigator.pop(
                    context, [for (final e in _items) (e.page, e.turns)]),
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
                Expanded(
                  child: GridView.builder(
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
                document: doc,
                pageNumber: item.page + 1,
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
