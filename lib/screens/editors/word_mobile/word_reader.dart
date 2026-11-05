/// **Faz 37 madde 11 — Word okuma kipi (yeniden akış) + gece kipi.**
///
/// Belge ekran genişliğinde akar; yazı boyu, satır aralığı ve zemin (gündüz /
/// sepya / gece) okura göre. Yalnız görünen paragraflar kurulur
/// (`ListView.builder`; anayasa: görünür ±1 çizilir). Resimler `cacheWidth`
/// ile ekran genişliğinde çözülür. Ayarlar cihazda hatırlanır.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/docx/docx_document.dart';
import '../../../services/docx/docx_styles.dart';

enum WordReaderTheme { day, sepia, night }

class WordReaderScreen extends StatefulWidget {
  final DocxDocument doc;
  final String title;
  final int startPara;
  const WordReaderScreen(
      {super.key, required this.doc, required this.title, this.startPara = 0});

  @override
  State<WordReaderScreen> createState() => _WordReaderScreenState();
}

class _WordReaderScreenState extends State<WordReaderScreen> {
  double _scale = 1.0;
  WordReaderTheme _theme = WordReaderTheme.day;
  late final List<String> _labels = widget.doc.listLabels();
  late final _scroll = ScrollController();

  static const _scaleKey = 'word_reader_scale', _themeKey = 'word_reader_theme';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (widget.startPara > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(widget.startPara));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getDouble(_scaleKey);
      final t = p.getInt(_themeKey);
      if (!mounted) return;
      setState(() {
        if (s != null) _scale = s.clamp(0.8, 2.0);
        if (t != null && t >= 0 && t < WordReaderTheme.values.length) {
          _theme = WordReaderTheme.values[t];
        }
      });
    } catch (_) {
      // En iyi çaba: tercih okunamazsa varsayılan görünüm.
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_scaleKey, _scale);
      await p.setInt(_themeKey, _theme.index);
    } catch (_) {
      // En iyi çaba: tercih yazılamazsa yalnız bu oturumda geçerli.
    }
  }

  /// Kaba konum: ortalama paragraf yüksekliğiyle atla.
  void _jump(int i) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final n = widget.doc.paras.length;
    if (n == 0) return;
    _scroll.jumpTo((max * i / n).clamp(0, max));
  }

  (Color, Color) get _colors => switch (_theme) {
        WordReaderTheme.day => (Paper.bg, Paper.ink),
        WordReaderTheme.sepia => (Paper.well, Paper.ink),
        WordReaderTheme.night => (Paper.bgDark, Paper.inkDark),
      };

  TextStyle _run(TextStyle base, DocxRunLook l, Color ink) => base.copyWith(
        fontWeight: l.bold ? FontWeight.w700 : null,
        fontStyle: l.italic ? FontStyle.italic : null,
        decoration: TextDecoration.combine([
          if (l.underline) TextDecoration.underline,
          if (l.strike) TextDecoration.lineThrough,
        ]),
        // Gece kipinde belge renkleri okunmaz olur → mürekkep rengi.
        color: _theme == WordReaderTheme.night || l.color == null
            ? ink
            : Color(l.color! | 0xFF000000),
      );

  Widget _para(BuildContext context, int i, Color ink, double width) {
    final p = widget.doc.paras[i];
    final look = p.look;
    final body = context.type.large.copyWith(height: 1.55, color: ink);
    final heading = look.headingLevel;
    final base = heading == 0
        ? body
        : body.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ).apply(fontSizeFactor: switch (heading) { 1 => 1.5, 2 => 1.3, _ => 1.15 });
    final spans = <InlineSpan>[];
    final label = i < _labels.length ? _labels[i] : '';
    if (label.isNotEmpty) spans.add(TextSpan(text: '$label  ', style: base));
    final sb = StringBuffer();
    DocxRunLook? cur;
    void flush() {
      if (sb.isEmpty || cur == null) return;
      spans.add(TextSpan(text: sb.toString(), style: _run(base, cur, ink)));
      sb.clear();
    }

    for (var k = 0; k < p.length; k++) {
      final a = p.atoms[k];
      if (a != null) {
        flush();
        cur = null;
        if (a.kind == DocxAtomKind.image && a.image != null) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          spans.add(WidgetSpan(
            child: Image.memory(a.image!,
                width: width,
                cacheWidth: (width * dpr).round(),
                fit: BoxFit.contain,
                errorBuilder: (c, e, st) => const SizedBox.shrink()),
          ));
        } else if (a.display.isNotEmpty) {
          spans.add(TextSpan(text: a.display, style: base));
        }
        continue;
      }
      final l = p.styles[k].effective;
      if (cur != null && !identical(cur, l)) flush();
      cur = l;
      sb.write(p.text[k]);
    }
    flush();
    final align = switch (look.align) {
      'center' => TextAlign.center,
      'right' || 'end' => TextAlign.end,
      'both' => TextAlign.justify,
      _ => TextAlign.start,
    };
    return Padding(
      padding: EdgeInsetsDirectional.only(
          start: p.cell != null ? 12 : 0,
          top: heading > 0 ? 18 : 4,
          bottom: heading > 0 ? 6 : 8),
      child: spans.isEmpty
          ? const SizedBox(height: 8)
          : Text.rich(TextSpan(children: spans),
              textAlign: align,
              textDirection: look.bidi ? TextDirection.rtl : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = _colors;
    final paras = widget.doc.paras;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: ink,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('word-reader-smaller'),
            tooltip: context.t('word.zoom_out'),
            icon: const Icon(AppIcons.textDecrease),
            onPressed: _scale <= 0.8
                ? null
                : () {
                    setState(() => _scale = (_scale - 0.1).clamp(0.8, 2.0));
                    _save();
                  },
          ),
          IconButton(
            key: const ValueKey('word-reader-bigger'),
            tooltip: context.t('word.zoom_in'),
            icon: const Icon(AppIcons.textIncrease),
            onPressed: _scale >= 2.0
                ? null
                : () {
                    setState(() => _scale = (_scale + 0.1).clamp(0.8, 2.0));
                    _save();
                  },
          ),
          PopupMenuButton<WordReaderTheme>(
            key: const ValueKey('word-reader-theme'),
            tooltip: context.t('wp.reader_theme'),
            icon: const Icon(AppIcons.contrast),
            onSelected: (t) {
              setState(() => _theme = t);
              _save();
            },
            itemBuilder: (ctx) => [
              for (final t in WordReaderTheme.values)
                CheckedPopupMenuItem(
                    value: t,
                    checked: _theme == t,
                    child: Text(ctx.t('wp.reader_${t.name}'))),
            ],
          ),
        ],
      ),
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_scale)),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = (box.maxWidth - 40).clamp(200.0, 720.0);
            return Center(
              child: SizedBox(
                width: width + 40,
                child: Scrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    key: const ValueKey('word-reader-list'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                    itemCount: paras.length,
                    itemBuilder: (context, i) => _para(context, i, ink, width),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
