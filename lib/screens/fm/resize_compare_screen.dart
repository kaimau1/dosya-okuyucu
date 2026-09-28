import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/path_side_index.dart';
import '../../services/fm/thumbnail_cache.dart';
import '../../widgets/fm/fm_file_image.dart';

/// Boyut düşürme sonucu: bir (eski → yeni) çifti.
class ResizePair {
  final String oldPath;
  final String newPath;
  const ResizePair(this.oldPath, this.newPath);
}

/// İşin (özgün ← çıktı) çiftlerini kurar; çıktısı artık olmayanlar düşer.
List<ResizePair> resizePairsOf(Map<String, String> sources, List<String> outputs) => [
      for (final out in outputs)
        if (sources[out] != null && File(out).existsSync())
          ResizePair(sources[out]!, out),
    ];

/// **Eski ↔ yeni karşılaştırma** — boyut düşürme bitince otomatik açılır
/// (kullanıcı isteği 2026-09-28): fotoğrafta kaydırmalı üst üste karşılaştırma,
/// videoda yan yana; her çift için "eskiyi sil / yeniyi sil / ikisini tut".
class ResizeCompareScreen extends StatefulWidget {
  final List<ResizePair> pairs;
  const ResizeCompareScreen({super.key, required this.pairs});

  @override
  State<ResizeCompareScreen> createState() => _ResizeCompareScreenState();
}

class _PairState {
  final ResizePair pair;
  final bool isVideo;
  bool oldGone;
  bool newGone = false;
  int oldBytes;
  int newBytes;
  ({int width, int height})? oldDims;
  ({int width, int height})? newDims;

  _PairState(this.pair)
      : isVideo = FsEntry.ofPath(pair.newPath)?.category == FmCategory.video,
        oldGone = !File(pair.oldPath).existsSync(),
        oldBytes = _len(pair.oldPath),
        newBytes = _len(pair.newPath);

  static int _len(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

class _ResizeCompareScreenState extends State<ResizeCompareScreen> {
  late final List<_PairState> _items;
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _items = [for (final pair in widget.pairs) _PairState(pair)];
    for (final item in _items) {
      if (!item.isVideo) _probe(item);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _probe(_PairState item) async {
    final newDims = await ImageResizer.probeSize(item.pair.newPath);
    final oldDims = item.oldGone
        ? null
        : await ImageResizer.probeSize(item.pair.oldPath);
    if (!mounted) return;
    setState(() {
      item.newDims = newDims;
      item.oldDims = oldDims;
    });
  }

  Future<void> _trashOld(_PairState item, {bool quiet = false}) async {
    if (item.oldGone) return;
    // Etiket/geçmiş yeni dosyaya taşınır, SONRA eski çöpe gider.
    await PathSideIndex.moved(item.pair.oldPath, item.pair.newPath);
    await FmEnv.trash.moveToTrash([item.pair.oldPath]);
    FsEvents.changed();
    if (!mounted) return;
    setState(() => item.oldGone = true);
    if (!quiet) showSnack(context, context.t('rc.old_trashed'));
  }

  Future<void> _trashNew(_PairState item) async {
    if (item.newGone) return;
    await FmEnv.trash.moveToTrash([item.pair.newPath]);
    FsEvents.changed();
    if (!mounted) return;
    setState(() => item.newGone = true);
    showSnack(context, context.t('rc.new_trashed'));
  }

  Future<void> _trashAllOld() async {
    final targets = [for (final i in _items) if (!i.oldGone && !i.newGone) i];
    if (targets.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('rc.trash_all_old')),
        content: Text(ctx.t('rc.confirm_all', {'n': targets.length})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('pd.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('rc.trash_all_old'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    for (final item in targets) {
      await _trashOld(item, quiet: true);
    }
    if (!mounted) return;
    showSnack(context, context.t('rc.done_snack', {'n': targets.length}));
  }

  void _next() {
    if (_page + 1 < _items.length) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _items.fold<int>(
        0,
        (sum, i) =>
            sum + (i.newGone ? 0 : (i.oldBytes - i.newBytes).clamp(0, 1 << 60)));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('rc.title')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${_items.isEmpty ? 0 : _page + 1} / ${_items.length}'
                ' · ${context.t('ra.saved_bytes', {'size': FsPaths.humanSize(saved)})}',
                style: TextStyle(fontSize: 12, color: Paper.faint(context)),
              ),
            ),
          ),
        ),
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.t('rc.empty')))
          : PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _PairPage(
                item: _items[i],
                onTrashOld: () => _trashOld(_items[i]),
                onTrashNew: () => _trashNew(_items[i]),
                onNext: _next,
              ),
            ),
      bottomNavigationBar: _items.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(context.t('rc.trash_all_old')),
                        onPressed: _trashAllOld,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: Text(context.t('rc.keep_all')),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _PairPage extends StatelessWidget {
  final _PairState item;
  final VoidCallback onTrashOld;
  final VoidCallback onTrashNew;
  final VoidCallback onNext;

  const _PairPage({
    required this.item,
    required this.onTrashOld,
    required this.onTrashNew,
    required this.onNext,
  });

  String _dims(({int width, int height})? d) =>
      d == null ? '' : ' · ${d.width}×${d.height}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pair = item.pair;
    final pct = item.oldBytes > 0
        ? (((item.oldBytes - item.newBytes) / item.oldBytes) * 100).round()
        : 0;
    final canCompare = !item.oldGone && !item.newGone;
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(p.basename(pair.newPath),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(
          '${FsPaths.humanSize(item.oldBytes)} → ${FsPaths.humanSize(item.newBytes)}'
          '${pct > 0 ? '  ·  −%$pct' : ''}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: Paper.success(context)),
        ),
        const SizedBox(height: Gap.md),
        if (item.newGone)
          _Note(text: context.t('rc.new_trashed'))
        else if (item.isVideo)
          _VideoSideBySide(item: item)
        else if (canCompare)
          _BeforeAfter(oldPath: pair.oldPath, newPath: pair.newPath)
        else
          _SingleImage(path: pair.newPath),
        const SizedBox(height: Gap.sm),
        if (item.oldGone && !item.newGone)
          _Note(text: context.t('rc.old_trashed')),
        Text(
          '${context.t('rc.old')}: ${FsPaths.humanSize(item.oldBytes)}${_dims(item.oldDims)}\n'
          '${context.t('rc.new')}: ${FsPaths.humanSize(item.newBytes)}${_dims(item.newDims)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            if (!item.oldGone && !item.newGone)
              FilledButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(context.t('rc.trash_old')),
                onPressed: onTrashOld,
              ),
            if (!item.newGone)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(context.t('rc.trash_new')),
                onPressed: onTrashNew,
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(context.t('rc.keep_both')),
              onPressed: onNext,
            ),
            if (!item.oldGone)
              TextButton(
                onPressed: () => EntryOpener.open(context, pair.oldPath),
                child: Text(context.t('rc.open_old')),
              ),
            if (!item.newGone)
              TextButton(
                onPressed: () => EntryOpener.open(context, pair.newPath),
                child: Text(context.t('rc.open_new')),
              ),
          ],
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: Paper.faint(context))),
      );
}

class _SingleImage extends StatelessWidget {
  final String path;
  const _SingleImage({required this.path});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: SizedBox(
          height: 300,
          child: Image(
            image: FmFileImage(path, cacheWidth: 1200),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
}

/// Aynı kutuda üst üste iki görüntü; ayırıcıyı kaydırınca solda ESKİ, sağda
/// YENİ görünür — sıkıştırma izi/bulanıklık aynı yerde kıyaslanır.
class _BeforeAfter extends StatefulWidget {
  final String oldPath;
  final String newPath;
  const _BeforeAfter({required this.oldPath, required this.newPath});

  @override
  State<_BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<_BeforeAfter> {
  double _pos = 0.5;

  Widget _img(String path) => Image(
        image: FmFileImage(path, cacheWidth: 1400),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => setState(
                () => _pos = (_pos + d.delta.dx / w).clamp(0.0, 1.0)),
            onTapDown: (d) =>
                setState(() => _pos = (d.localPosition.dx / w).clamp(0.0, 1.0)),
            child: SizedBox(
              height: 320,
              width: w,
              child: Stack(
                children: [
                  Positioned.fill(child: _img(widget.newPath)),
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftClipper(_pos),
                      child: _img(widget.oldPath),
                    ),
                  ),
                  Positioned(
                    left: w * _pos - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: scheme.primary),
                  ),
                  Positioned(
                    left: w * _pos - 16,
                    top: 320 / 2 - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.swap_horiz,
                          size: 20, color: scheme.onPrimary),
                    ),
                  ),
                  Positioned(
                      left: 8, top: 8, child: _Tag(context.t('rc.old'))),
                  Positioned(
                      right: 8, top: 8, child: _Tag(context.t('rc.new'))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double fraction;
  _LeftClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.fraction != fraction;
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

/// Video: iki küçük resim yan yana, dokununca ilgili videoyu açar.
class _VideoSideBySide extends StatelessWidget {
  final _PairState item;
  const _VideoSideBySide({required this.item});

  Widget _cell(BuildContext context, String label, String path, int bytes,
      bool gone) {
    return Expanded(
      child: GestureDetector(
        onTap: gone ? null : () => EntryOpener.open(context, path),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 9 / 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black26),
                    if (!gone)
                      FutureBuilder<String?>(
                        future: ThumbnailCache.forVideo(path, size: 480),
                        builder: (_, snap) => snap.data == null
                            ? const SizedBox.shrink()
                            : Image.file(File(snap.data!), fit: BoxFit.cover),
                      ),
                    Center(
                      child: Icon(
                          gone ? Icons.delete_outline : Icons.play_circle_fill,
                          size: 44,
                          color: Colors.white70),
                    ),
                    Positioned(left: 8, top: 8, child: _Tag(label)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(FsPaths.humanSize(bytes),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cell(context, context.t('rc.old'), item.pair.oldPath, item.oldBytes,
              item.oldGone),
          const SizedBox(width: Gap.sm),
          _cell(context, context.t('rc.new'), item.pair.newPath, item.newBytes,
              false),
        ],
      );
}
