import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../core/user_error.dart';
import '../services/pdf_compare.dart';
import '../services/pdf_raster.dart';

/// **İki PDF karşılaştırma ekranı** (Faz 39 madde 4): "Metin" ve "Görsel"
/// sekmeleri. Metin farkı açılışta (izolatta) hesaplanır; görsel fark yalnız
/// o sekme açılınca ve sayfa sayfa üretilir (anayasa k.2 — tembel).
class PdfCompareScreen extends StatefulWidget {
  const PdfCompareScreen({
    super.key,
    required this.a,
    required this.b,
    required this.nameA,
    required this.nameB,
    this.passwordA,
    this.passwordB,
  });

  final Uint8List a;
  final Uint8List b;
  final String nameA;
  final String nameB;
  final String? passwordA;
  final String? passwordB;

  /// Görsel karşılaştırmada en çok sayfa (her sayfa bir PNG bellekte).
  static const visualPageLimit = 50;

  @override
  State<PdfCompareScreen> createState() => _PdfCompareScreenState();
}

class _PdfCompareScreenState extends State<PdfCompareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTab);
  List<PageTextDiff>? _text;
  Object? _textError;
  bool _onlyChanged = true;

  final _visual = <PageVisualDiff>[];
  bool _visualStarted = false;
  bool _visualDone = false;
  Object? _visualError;
  int _visualTotal = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _runText();
  }

  @override
  void dispose() {
    _disposed = true;
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _runText() async {
    try {
      final r = await PdfCompare.compareTextInBackground(widget.a, widget.b,
          passwordA: widget.passwordA, passwordB: widget.passwordB);
      if (mounted) setState(() => _text = r);
    } catch (e) {
      if (mounted) setState(() => _textError = e);
    }
  }

  void _onTab() {
    if (_tabs.index == 1 && !_visualStarted) {
      _visualStarted = true;
      _runVisual();
    }
  }

  Future<void> _runVisual() async {
    try {
      final countA = await _count(widget.a, widget.passwordA);
      final countB = await _count(widget.b, widget.passwordB);
      final n = [countA, countB].reduce((x, y) => x > y ? x : y);
      final total = n.clamp(0, PdfCompareScreen.visualPageLimit).toInt();
      if (mounted) setState(() => _visualTotal = total);
      for (var i = 0; i < total; i++) {
        if (_disposed) return;
        final ga = i < countA
            ? (await PdfRaster.renderGray(widget.a,
                    pages: [i], password: widget.passwordA))
                .single
            : null;
        final gb = i < countB
            ? (await PdfRaster.renderGray(widget.b,
                    pages: [i], password: widget.passwordB))
                .single
            : null;
        final blank = ga ?? gb!;
        final emptyA = (w: blank.width, h: 0, luma: Uint8List(0));
        final pa = ga == null ? emptyA : (w: ga.width, h: ga.height, luma: ga.luma);
        final pb = gb == null ? emptyA : (w: gb.width, h: gb.height, luma: gb.luma);
        final page = i + 1;
        final d = await Isolate.run(() => PdfCompare.visualDiff(page, pa, pb));
        if (!mounted) return;
        setState(() => _visual.add(d));
      }
    } catch (e) {
      if (mounted) setState(() => _visualError = e);
    } finally {
      if (mounted) setState(() => _visualDone = true);
    }
  }

  static Future<int> _count(Uint8List bytes, String? password) =>
      PdfRaster.pageCount(bytes, password: password);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.t('pp.compare')),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: context.t('pp.compare_text')),
              Tab(text: context.t('pp.compare_visual')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_textTab(context), _visualTab(context)],
        ),
      );

  Widget _textTab(BuildContext context) {
    if (_textError != null) {
      return Center(child: Text(userErrorText(_textError!)));
    }
    final text = _text;
    if (text == null) return const Center(child: CircularProgressIndicator());
    final shown = _onlyChanged ? text.where((p) => p.changed).toList() : text;
    final added = text.fold<int>(0, (s, p) => s + p.addedWords);
    final removed = text.fold<int>(0, (s, p) => s + p.removedWords);
    return Column(
      children: [
        ListTile(
          title: Text(context.t('pp.compare_names',
              {'a': widget.nameA, 'b': widget.nameB})),
          subtitle: Text(context.t('pp.compare_summary', {
            'pages': text.where((p) => p.changed).length,
            'added': added,
            'removed': removed,
          })),
          trailing: FilterChip(
            label: Text(context.t('pp.compare_only_changed')),
            selected: _onlyChanged,
            onSelected: (v) => setState(() => _onlyChanged = v),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(context.t('pp.compare_same')))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _pageCard(context, shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _pageCard(BuildContext context, PageTextDiff page) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.type.body;
    TextSpan span(DiffPiece p) => switch (p.kind) {
          DiffKind.same => TextSpan(text: p.text),
          DiffKind.added => TextSpan(
              text: p.text,
              style: TextStyle(
                  backgroundColor: AppHues.green.withValues(alpha: 0.22),
                  color: scheme.onSurface)),
          DiffKind.removed => TextSpan(
              text: p.text,
              style: TextStyle(
                  backgroundColor: AppHues.red.withValues(alpha: 0.18),
                  decoration: TextDecoration.lineThrough,
                  color: scheme.onSurface)),
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('pp.compare_page', {'n': page.page}),
              style: context.type.caption),
          const SizedBox(height: Gap.xs),
          for (final line in page.lines)
            if (!_onlyChanged || line.any((p) => p.kind != DiffKind.same))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text.rich(TextSpan(
                  style: base,
                  children: [
                    for (var k = 0; k < line.length; k++) ...[
                      if (k > 0) const TextSpan(text: ' '),
                      span(line[k]),
                    ],
                  ],
                )),
              ),
        ],
      ),
    );
  }

  Widget _visualTab(BuildContext context) {
    if (_visualError != null) {
      return Center(child: Text(userErrorText(_visualError!)));
    }
    if (_visual.isEmpty && !_visualDone) {
      return const Center(child: CircularProgressIndicator());
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, box) {
      final cacheWidth = (box.maxWidth * dpr).round();
      return ListView.builder(
        itemCount: _visual.length + 1,
        itemBuilder: (context, i) {
          if (i == _visual.length) {
            return Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Center(
                child: _visualDone
                    ? Text(context.t('pp.compare_visual_note',
                        {'n': PdfCompareScreen.visualPageLimit}))
                    : Text(context.t('pp.compare_progress',
                        {'done': _visual.length, 'total': _visualTotal})),
              ),
            );
          }
          final d = _visual[i];
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('pp.compare_visual_page', {
                      'n': d.page,
                      'pct': (d.ratio * 100).toStringAsFixed(1),
                    }),
                    style: context.type.caption,
                  ),
                  const SizedBox(height: Gap.xs),
                  Image.memory(d.png,
                      cacheWidth: cacheWidth, gaplessPlayback: true),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
