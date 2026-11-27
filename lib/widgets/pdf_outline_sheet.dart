/// **PDF içindekiler** — görüntüleyici ve Kitaplık aynı sayfayı kullanır
/// (2026-11-26).
///
/// * Açılınca okunan başlık vurgulu ve görünürdedir (kullanıcı "neredeydim"
///   diye aramaz).
/// * Üst düzey bölümler (ör. ciltler) çip şeridinden tek dokunuşla seçilir.
/// * Arama kutusu bütün başlıklarda süzer (Türkçe/şapka duyarsız).
/// * Satırlar tek satır, sık, sayfa numaralı (kullanıcı: "satır satır olmalı").
///
/// Yer imi olmayan PDF'te [createPdfOutline] başlıkları tarayıp çıkarır ve
/// onaydan sonra PDF'in İÇİNE gerçek yer imi olarak yazar.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/text_search.dart' show asciiFold;
import '../core/user_error.dart';
import '../services/pdf/pdf_auto_outline.dart';
import '../services/pdf_doc_pro.dart';
import 'app_dialog.dart';

/// Bir sonraki açılışta PDF'in hangi sayfada açılacağı (Kitaplık
/// içindekilerinden bir başlığa dokunulunca). Tek kullanımlık.
abstract final class PdfOpenTarget {
  static String? _path;
  static int? _page;

  static void set(String path, int page) {
    _path = path;
    _page = page;
  }

  /// [path] için bekleyen sayfa (1'den); okununca silinir.
  static int? take(String path) {
    if (_path != path) return null;
    final page = _page;
    _path = null;
    _page = null;
    return page;
  }
}

/// Yer imi hedefini biraz yukarı alır. PDF'teki y noktası çoğu zaman
/// başlığın altına (ilk satıra) düşer; pdfrx o noktayı ekranın tam üstüne
/// koyunca başlık görünmüyordu (kullanıcı ekran görüntüsü, "SUNUŞ").
/// Hedef sayfanın üst çeyreğindeyse sayfa başına, değilse sayfa boyunun
/// %6'sı kadar yukarı gidilir.
PdfDest roomyPdfDest(PdfDest dest, PdfDocument doc) {
  final p = dest.params;
  final yAt = switch (dest.command) {
    PdfDestCommand.xyz => 1,
    PdfDestCommand.fitH || PdfDestCommand.fitBH => 0,
    _ => -1,
  };
  if (p == null || yAt < 0 || p.length <= yAt || p[yAt] == null) return dest;
  if (dest.pageNumber < 1 || dest.pageNumber > doc.pages.length) return dest;
  final h = doc.pages[dest.pageNumber - 1].height;
  final y = p[yAt]!;
  final raised = y + h * 0.06;
  final up = (y >= h * 0.75 || raised > h) ? h : raised;
  return PdfDest(dest.pageNumber, dest.command, [...p]..[yAt] = up);
}

/// İçindekiler sayfasını açar; seçilen başlığın (rahat) hedefini döner.
Future<PdfDest?> showPdfOutlineSheet(
  BuildContext context, {
  required PdfDocument doc,
  required List<PdfOutlineNode> outline,
  required int currentPage,
}) =>
    showAppSheet<PdfDest>(
      context,
      scrollable: false,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.8,
        child: _OutlineBody(doc: doc, outline: outline, currentPage: currentPage),
      ),
    );

class _OutlineBody extends StatefulWidget {
  final PdfDocument doc;
  final List<PdfOutlineNode> outline;
  final int currentPage;

  const _OutlineBody(
      {required this.doc, required this.outline, required this.currentPage});

  @override
  State<_OutlineBody> createState() => _OutlineBodyState();
}

class _OutlineBodyState extends State<_OutlineBody> {
  // Sık satır: tek satır başlık + sayfa no; sabit boy, açılışta okunan
  // başlığa atlamak için konum hesaplanabilsin.
  static const _rowH = 40.0;

  final _scroll = ScrollController();

  // ponytail: ağaç yerine girintili düz liste — açılır/kapanır düğüm yönetimi
  // olmadan aynı işi görür; şikayet gelirse ExpansionTile'a geçilir.
  // (düğüm, derinlik, üst başlık yolu, arama anahtarı, üst düzey sırası)
  final _flat = <(PdfOutlineNode, int, String, String, int)>[];
  var _current = -1;
  late final bool _chips;
  int? _vol;
  var _query = '';

  @override
  void initState() {
    super.initState();
    void walk(List<PdfOutlineNode> nodes, int depth, String path, int top) {
      for (var i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        final t = depth == 0 ? i : top;
        _flat.add((n, depth, path, asciiFold(n.title), t));
        walk(n.children, depth + 1,
            path.isEmpty ? n.title : '$path › ${n.title}', t);
      }
    }

    final outline = widget.outline;
    walk(outline, 0, '', 0);
    // Okunan başlık: sayfası geçerli sayfayı aşmayan son başlık (ana hat
    // sayfa sırasında varsayılır; değilse yalnız vurgu yanlış yere düşer).
    for (var i = 0; i < _flat.length; i++) {
      final p = _flat[i].$1.dest?.pageNumber;
      if (p != null && p <= widget.currentPage) _current = i;
    }
    _chips = outline.length >= 2 &&
        outline.length <= 60 &&
        outline.any((n) => n.children.isNotEmpty);
    _vol = _chips && _current >= 0 ? _flat[_current].$5 : null;
    final at = _shown().indexOf(_current);
    if (at > 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        final to = (at - 2) * _rowH;
        _scroll.jumpTo(to > max ? max : to);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _words => asciiFold(_query.trim())
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Klavye animasyonunda levha her karede yeniden kurulur; süzme (1000+
  // başlık) yalnız arama/bölüm değişince yapılır.
  (String, int?)? _shownKey;
  List<int> _shownCache = const [];
  List<int> _shownCached() {
    final key = (_query, _vol);
    if (key != _shownKey) {
      _shownKey = key;
      _shownCache = _shown();
    }
    return _shownCache;
  }

  /// Arama bütün belgede; aramasız liste seçili bölümle sınırlı.
  List<int> _shown() {
    final words = _words;
    return [
      for (var i = 0; i < _flat.length; i++)
        if (words.isNotEmpty
            ? words.every(_flat[i].$4.contains)
            : (_vol == null || _flat[i].$5 == _vol))
          i,
    ];
  }

  void _pickVol(int? v) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _vol = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _shownCached();
    final searching = _words.isNotEmpty;
    final outline = widget.outline;
    return Column(
      children: [
        if (_flat.length > 12)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.search),
                hintText: context.t('vw.toc_search'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        if (_chips && !searching)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final v in <int?>[
                  null,
                  for (var i = 0; i < outline.length; i++) i,
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          v == null ? context.t('vw.toc_all') : outline[v].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selected: _vol == v,
                      onSelected: (_) => _pickVol(v),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(context.t('vw.toc_no_match')))
              : ListView.builder(
                  controller: _scroll,
                  itemCount: shown.length,
                  itemExtent: searching ? null : _rowH,
                  itemBuilder: (ctx, i) {
                    final idx = shown[i];
                    final (node, depth, path, _, _) = _flat[idx];
                    final dest = node.dest;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      minVerticalPadding: 0,
                      minTileHeight: 0,
                      selected: idx == _current,
                      contentPadding: EdgeInsetsDirectional.only(
                          start: searching ? 16 : 16.0 + depth * 14, end: 16),
                      title: Text(node.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: depth == 0
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                      subtitle: searching && path.isNotEmpty
                          ? Text(path,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: dest == null
                          ? null
                          : Text('${dest.pageNumber}',
                              style: theme.textTheme.labelMedium),
                      onTap: dest == null
                          ? null
                          : () => Navigator.pop(
                              context, roomyPdfDest(dest, widget.doc)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Yer imi olmayan PDF'e içindekiler çıkarır ve onaylanırsa dosyaya yazar.
/// Dosya değiştiyse true döner (çağıran belgeyi yeniden yüklemeli).
///
/// Taranmış belge yalnız GERÇEKTEN metinsizse ayrıca uyarılır (OCR yavaş);
/// metinli PDF'te tek onay yeter. Tarama ve önizleme tek levhada; levhayı
/// kapatmak taramayı durdurur.
Future<bool> createPdfOutline(
  BuildContext context, {
  required String path,
  required PdfDocument doc,
}) async {
  final scanned = await PdfAutoOutline.looksScanned(doc);
  if (!context.mounted) return false;
  final go = await showAppConfirm(
    context,
    title: context.t('toc.create'),
    message: scanned
        ? context.t('toc.scanned_warn', {'n': doc.pages.length})
        : context.t('toc.create_body'),
    confirmLabel: context.t('toc.create_go'),
  );
  if (!go || !context.mounted) return false;

  final items = await showAppSheet<List<PdfOutlineItem>>(
    context,
    scrollable: false,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.7,
      child: _AutoOutlineBody(doc: doc, scanned: scanned),
    ),
  );
  if (items == null || items.isEmpty || !context.mounted) return false;

  try {
    final bytes = await File(path).readAsBytes();
    final out = await PdfDocPro.writeOutlineInBackground(bytes, items);
    // Önce geçici dosya, sonra yer değiştirme: yazma yarıda kalırsa özgün
    // PDF bozulmaz.
    final tmp = File('$path.toc.tmp');
    await tmp.writeAsBytes(out, flush: true);
    await tmp.rename(path);
  } catch (e) {
    if (context.mounted) showSnack(context, userErrorText(e));
    return false;
  }
  if (context.mounted) showSnack(context, context.t('toc.saved'));
  return true;
}

/// Tarama (ilerlemeli) → bulunan başlıkların önizlemesi → "PDF'e ekle".
class _AutoOutlineBody extends StatefulWidget {
  final PdfDocument doc;
  final bool scanned;

  const _AutoOutlineBody({required this.doc, required this.scanned});

  @override
  State<_AutoOutlineBody> createState() => _AutoOutlineBodyState();
}

class _AutoOutlineBodyState extends State<_AutoOutlineBody> {
  var _done = 0;
  late var _total = widget.doc.pages.length;
  List<PdfOutlineItem>? _items;
  String? _error;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _closed = true; // levha kapandı → tarama durur
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final items = await PdfAutoOutline.detect(
        widget.doc,
        ocr: widget.scanned,
        onProgress: (d, t) {
          if (!mounted) return;
          setState(() {
            _done = d;
            _total = t;
          });
        },
        cancelled: () => _closed,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    final error = _error;
    if (error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24), child: Text(error)));
    }
    if (items == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                context.t(
                    widget.scanned ? 'toc.scanning_ocr' : 'toc.scanning'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            const SizedBox(height: 8),
            Text('$_done / $_total', style: theme.textTheme.labelMedium),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Center(child: Text(context.t('toc.none_found')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(context.t('toc.preview', {'n': items.length}),
              style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemExtent: 36,
            itemBuilder: (ctx, i) {
              final it = items[i];
              return Padding(
                padding: EdgeInsetsDirectional.only(
                    start: 24 + it.level * 14.0, end: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: it.level == 0
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ),
                    Text('${it.page + 1}', style: theme.textTheme.labelMedium),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('common.cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, items),
                child: Text(context.t('toc.save')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
