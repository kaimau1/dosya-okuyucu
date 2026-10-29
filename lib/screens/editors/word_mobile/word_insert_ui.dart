/// Word Mobil görünüm — Ekle levhaları ve Bul/Değiştir çubuğu (Faz 24).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/doc_find_bar.dart';
import '../../../services/docx/docx_document.dart';
import '../../../widgets/docx_editor/docx_edit_controller.dart';

/// Tablo ızgara seçici: 8×8 kare; dokun = o köşeye kadar seç → "Tabloyu ekle".
Future<(int, int)?> showWordTableSheet(BuildContext context) =>
    showAppSheet<(int, int)>(
      context,
      title: context.t('word.insert_table'),
      builder: (ctx) {
        var rows = 2, cols = 3;
        return StatefulBuilder(builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(ctx.t('word.table_size', {'r': rows, 'c': cols}),
                      key: const ValueKey('word-table-size'),
                      style: Theme.of(ctx).textTheme.titleSmall),
                ),
                const SizedBox(height: Gap.sm),
                Center(
                  child: SizedBox(
                    width: 216,
                    height: 216,
                    child: Column(
                      children: [
                        for (var r = 1; r <= 8; r++)
                          Expanded(
                            child: Row(children: [
                              for (var c = 1; c <= 8; c++)
                                Expanded(
                                  child: GestureDetector(
                                    key: ValueKey('word-cell-$r-$c'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => set(() {
                                      rows = r;
                                      cols = c;
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: r <= rows && c <= cols
                                            ? scheme.primaryContainer
                                            : scheme.surfaceContainerHighest,
                                        border: Border.all(
                                            color: r <= rows && c <= cols
                                                ? scheme.primary
                                                : scheme.outlineVariant),
                                      ),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                FilledButton(
                  key: const ValueKey('word-table-ok'),
                  onPressed: () => Navigator.pop(ctx, (rows, cols)),
                  child: Text(ctx.t('word.table_insert')),
                ),
              ],
            ),
          );
        });
      },
    );

/// Bağlantı levhası: (metin, adres).
Future<(String, String)?> showWordLinkSheet(BuildContext context,
    {String text = ''}) {
  final textCtl = TextEditingController(text: text);
  final urlCtl = TextEditingController(text: 'https://');
  return showAppSheet<(String, String)>(
    context,
    title: context.t('word.insert_link'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('word-link-text'),
            controller: textCtl,
            decoration: InputDecoration(labelText: ctx.t('word.link_text')),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const ValueKey('word-link-url'),
            controller: urlCtl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: ctx.t('word.link_url')),
          ),
          const SizedBox(height: Gap.md),
          FilledButton(
            key: const ValueKey('word-link-ok'),
            onPressed: () => Navigator.pop(ctx, (textCtl.text, urlCtl.text)),
            child: Text(ctx.t('word.link_insert')),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    textCtl.dispose();
    urlCtl.dispose();
  });
}

/// Son kullanılan semboller (oturum boyunca).
final List<String> _recentSymbols = [];

const _symbols = [
  '©',
  '®',
  '™',
  '€',
  '₺',
  '§',
  '°',
  '±',
  '×',
  '÷',
  '→',
  '←',
  '↑',
  '↓',
  '•',
  '✓',
  '✗',
  '★',
  '≈',
  '≠',
  '≤',
  '≥',
  '∞',
  'µ',
  '¶',
  '†',
  '‡',
  '…',
  '«',
  '»',
  '‹',
  '›',
  '½',
  '¼',
  '¾',
  'α',
  'β',
  'π',
  'Σ',
  'Ω',
  '²',
  '³',
];

/// Sembol levhası: dokun = ekle; son kullanılanlar üstte.
Future<String?> showWordSymbolSheet(BuildContext context) =>
    showAppSheet<String>(
      context,
      title: context.t('word.insert_symbol'),
      builder: (ctx) {
        Widget grid(List<String> items) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in items)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      key: ValueKey('word-sym-$s'),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        _recentSymbols
                          ..remove(s)
                          ..insert(0, s);
                        if (_recentSymbols.length > 8) {
                          _recentSymbols.removeLast();
                        }
                        Navigator.pop(ctx, s);
                      },
                      child: Text(s, style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                  ),
              ],
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_recentSymbols.isNotEmpty) ...[
                Text(ctx.t('word.recent_symbols'),
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: Gap.sm),
                grid(List.of(_recentSymbols)),
                const SizedBox(height: Gap.md),
              ],
              grid(_symbols),
            ],
          ),
        );
      },
    );

/// Belge üstündeki Bul/Değiştir çubuğu (Mobil görünüm).
///
/// Eşleşme **seçim olarak** gösterilir (görünüm seçimi zaten boyar); ileri/geri
/// seçimi taşır, "Değiştir" seçili eşleşmeyi, "Tümü" hepsini değiştirir
/// (tek geri al adımı).
class WordFindBar extends StatefulWidget {
  final DocxEditController controller;
  final Future<void> Function(int para) reveal;
  final VoidCallback onClose;

  const WordFindBar({
    super.key,
    required this.controller,
    required this.reveal,
    required this.onClose,
  });

  @override
  State<WordFindBar> createState() => _WordFindBarState();
}

class _WordFindBarState extends State<WordFindBar> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _case = false, _word = false, _showReplace = false;
  List<(DocPos, DocPos)> _hits = const [];
  int _at = -1;

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  void _search() {
    final c = widget.controller;
    _hits = c.findMatches(_find.text, matchCase: _case, wholeWord: _word);
    _at = _hits.isEmpty ? -1 : 0;
    setState(() {});
    _go();
  }

  void _go() {
    if (_at < 0 || _at >= _hits.length) return;
    final (s, e) = _hits[_at];
    widget.controller.select(s, e);
    widget.reveal(s.para);
  }

  void _step(int d) {
    if (_hits.isEmpty) return;
    _at = (_at + d) % _hits.length;
    if (_at < 0) _at += _hits.length;
    setState(() {});
    _go();
  }

  void _replaceOne() {
    if (_at < 0) return;
    final keep = _at;
    widget.controller.select(_hits[_at].$1, _hits[_at].$2);
    widget.controller.replaceSelection(_replace.text);
    _hits = widget.controller
        .findMatches(_find.text, matchCase: _case, wholeWord: _word);
    _at = _hits.isEmpty ? -1 : keep.clamp(0, _hits.length - 1);
    setState(() {});
    _go();
  }

  void _replaceAll() {
    final n = widget.controller.replaceAllMatches(_find.text, _replace.text,
        matchCase: _case, wholeWord: _word);
    showSnack(context, context.t('word.replace_n', {'n': n}));
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final label = _find.text.trim().isEmpty
        ? ''
        : (_hits.isEmpty
            ? context.t('find.none')
            : '${_at + 1}/${_hits.length}');
    return Material(
      key: const ValueKey('word-find-bar'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DocFindBar(
          controller: _find,
          hint: context.t('word.find_hint'),
          countLabel: label,
          onChanged: (_) => _search(),
          onSubmitted: (_) => _step(1),
          onPrev: _hits.isEmpty ? null : () => _step(-1),
          onNext: _hits.isEmpty ? null : () => _step(1),
          onClose: widget.onClose,
          leading: [
            IconButton(
              tooltip: context.t('vw.show_replace'),
              visualDensity: VisualDensity.compact,
              isSelected: _showReplace,
              icon: const Icon(AppIcons.findReplace),
              onPressed: () => setState(() => _showReplace = !_showReplace),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(children: [
            FilterChip(
              key: const ValueKey('word-find-case'),
              label: const Text('Aa'),
              selected: _case,
              visualDensity: VisualDensity.compact,
              onSelected: (v) {
                _case = v;
                _search();
              },
            ),
            const SizedBox(width: 6),
            FilterChip(
              key: const ValueKey('word-find-word'),
              label: Text(context.t('code.whole_word')),
              selected: _word,
              visualDensity: VisualDensity.compact,
              onSelected: (v) {
                _word = v;
                _search();
              },
            ),
          ]),
        ),
        if (_showReplace)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('word-replace-field'),
                  controller: _replace,
                  decoration: DocFindBar.decoration(context,
                      hint: context.t('word.replace_hint'),
                      icon: AppIcons.edit),
                ),
              ),
              TextButton(
                key: const ValueKey('word-replace-one'),
                onPressed: _hits.isEmpty ? null : _replaceOne,
                child: Text(context.t('vw.replace_one')),
              ),
              TextButton(
                key: const ValueKey('word-replace-all'),
                onPressed: _hits.isEmpty ? null : _replaceAll,
                child: Text(context.t('vw.replace_all')),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Üst/alt bilgi levhası: iki metin kutusu + sayfa numarası. Uygulayınca
/// doğrudan belgeye yazar (zengin içerik varsa uyarır).
Future<void> showWordHeaderFooterSheet(
    BuildContext context, DocxEditController c) {
  final head = c.headerFooter(header: true);
  final foot = c.headerFooter(header: false);
  final hCtl = TextEditingController(text: head.text);
  final fCtl = TextEditingController(text: foot.text);
  var page = foot.pageNumber;
  return showAppSheet<void>(
    context,
    title: context.t('word.insert_hf'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(
            Gap.md, 0, Gap.md, Gap.md + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!head.editable || !foot.editable)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(ctx.t('word.hf_rich'),
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
            TextField(
              key: const ValueKey('word-hf-header'),
              controller: hCtl,
              enabled: head.editable,
              decoration: InputDecoration(labelText: ctx.t('word.hf_header')),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              key: const ValueKey('word-hf-footer'),
              controller: fCtl,
              enabled: foot.editable,
              decoration: InputDecoration(labelText: ctx.t('word.hf_footer')),
            ),
            CheckboxListTile(
              key: const ValueKey('word-hf-page'),
              contentPadding: EdgeInsets.zero,
              value: page,
              onChanged:
                  foot.editable ? (v) => set(() => page = v ?? false) : null,
              title: Text(ctx.t('word.hf_page')),
            ),
            FilledButton(
              key: const ValueKey('word-hf-apply'),
              onPressed: () {
                if (head.editable) {
                  c.setHeaderFooter(
                      header: true,
                      text: hCtl.text,
                      pageNumber: head.pageNumber);
                }
                if (foot.editable) {
                  c.setHeaderFooter(
                      header: false, text: fCtl.text, pageNumber: page);
                }
                Navigator.pop(ctx);
                showSnack(context, context.t('word.hf_saved'));
              },
              child: Text(ctx.t('word.hf_apply')),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Faz 24 kalanı: tarih/saat, dipnot, yorumlar ────────────────────────────

/// Tarih / saat levhası: biçim seç → metin olarak eklenir.
Future<String?> showWordDateSheet(BuildContext context) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final months = context.t('word.month_names').split(',');
  final options = [
    '${two(now.day)}.${two(now.month)}.${now.year}',
    '${now.day} ${months.length == 12 ? months[now.month - 1] : two(now.month)} ${now.year}',
    '${now.year}-${two(now.month)}-${two(now.day)}',
    '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}',
    '${two(now.hour)}:${two(now.minute)}',
  ];
  return showAppSheet<String>(
    context,
    title: context.t('word.insert_date'),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, o) in options.indexed)
          ListTile(
            key: ValueKey('word-date-$i'),
            title: Text(o),
            onTap: () => Navigator.pop(ctx, o),
          ),
      ],
    ),
  );
}

/// Kısa metin levhası (dipnot / yorum / alternatif metin): vazgeçilirse null.
Future<String?> showWordTextSheet(BuildContext context,
        {required String title,
        required String label,
        required String action,
        String initial = '',
        Key? fieldKey}) =>
    showAppSheet<String>(
      context,
      title: title,
      builder: (ctx) => _WordTextSheet(
          label: label, action: action, initial: initial, fieldKey: fieldKey),
    );

/// Denetleyicisi levhanın ömrüne bağlı (kapanış animasyonu sürerken
/// atılmasın).
class _WordTextSheet extends StatefulWidget {
  final String label, action, initial;
  final Key? fieldKey;
  const _WordTextSheet(
      {required this.label,
      required this.action,
      required this.initial,
      this.fieldKey});

  @override
  State<_WordTextSheet> createState() => _WordTextSheetState();
}

class _WordTextSheetState extends State<_WordTextSheet> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Gap.md, 0, Gap.md,
            Gap.md + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: widget.fieldKey ?? const ValueKey('word-text-field'),
              controller: _ctl,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: widget.label),
            ),
            const SizedBox(height: Gap.md),
            FilledButton(
              key: const ValueKey('word-text-ok'),
              onPressed: () => Navigator.pop(context, _ctl.text),
              child: Text(widget.action),
            ),
          ],
        ),
      );
}

/// Yorum yazarı (bir kez sorulur, hatırlanır).
Future<String?> wordCommentAuthor(BuildContext context) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    final have = prefs.getString(kWordAuthorPref);
    if (have != null && have.trim().isNotEmpty) return have;
  } catch (_) {
    // Tercih deposu yoksa her seferinde sorulur.
  }
  if (!context.mounted) return null;
  final name = await showAppPrompt(context,
      title: context.t('word.comment_author'),
      label: context.t('word.comment_author_hint'));
  if (name == null || name.trim().isEmpty) return null;
  try {
    await prefs?.setString(kWordAuthorPref, name.trim());
  } catch (_) {
    // En iyi çaba: hatırlanamazsa bir dahaki yorumda yine sorulur.
  }
  return name.trim();
}

const kWordAuthorPref = 'word.comment_author';

/// Yorumlar levhası: liste (yanıtlar girintili), yanıtla / çözüldü / sil,
/// "Yeni yorum" seçime ekler. [focusId] verilirse o yorum vurgulu.
Future<void> showWordCommentsSheet(BuildContext context, DocxEditController c,
    {String? focusId, void Function(int para)? reveal}) {
  return showAppSheet<void>(
    context,
    title: context.t('word.comments'),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final all = c.comments;
      final roots = [
        for (final x in all)
          if (x.parentId == null) x
      ];
      final scheme = Theme.of(ctx).colorScheme;
      Future<void> addNew() async {
        final author = await wordCommentAuthor(ctx);
        if (author == null || !ctx.mounted) return;
        final text = await showWordTextSheet(ctx,
            title: ctx.t('word.comment_new'),
            label: ctx.t('word.comment_text'),
            action: ctx.t('word.comment_post'),
            fieldKey: const ValueKey('word-comment-text'));
        if (text == null || text.trim().isEmpty) return;
        c.addComment(text, author);
        set(() {});
      }

      Widget tile(DocxComment x, {bool reply = false}) => Padding(
            key: ValueKey('word-comment-${x.id}'),
            padding: EdgeInsetsDirectional.only(
                start: reply ? Gap.xl : 0, bottom: Gap.xs),
            child: Material(
              color: x.id == focusId
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.card),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                title: Text(x.author.isEmpty ? '—' : x.author,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            x.done ? TextDecoration.lineThrough : null)),
                subtitle: Text(x.text),
                onTap: reveal == null
                    ? null
                    : () {
                        final i = c.commentPara(x.id);
                        if (i >= 0) {
                          Navigator.pop(ctx);
                          reveal(i);
                        }
                      },
                trailing: PopupMenuButton<String>(
                  key: ValueKey('word-comment-menu-${x.id}'),
                  onSelected: (v) async {
                    switch (v) {
                      case 'reply':
                        final author = await wordCommentAuthor(ctx);
                        if (author == null || !ctx.mounted) return;
                        final text = await showWordTextSheet(ctx,
                            title: ctx.t('word.comment_reply'),
                            label: ctx.t('word.comment_text'),
                            action: ctx.t('word.comment_post'),
                            fieldKey: const ValueKey('word-comment-text'));
                        if (text == null) return;
                        c.replyComment(x.id, text, author);
                      case 'done':
                        c.setCommentDone(x.id, !x.done);
                      case 'delete':
                        c.deleteComment(x.id);
                    }
                    set(() {});
                  },
                  itemBuilder: (_) => [
                    if (!reply)
                      PopupMenuItem(
                          value: 'reply',
                          child: Text(ctx.t('word.comment_reply'))),
                    if (!reply)
                      PopupMenuItem(
                          value: 'done',
                          child: Text(ctx.t(x.done
                              ? 'word.comment_reopen'
                              : 'word.comment_resolve'))),
                    PopupMenuItem(
                        value: 'delete', child: Text(ctx.t('common.delete'))),
                  ],
                ),
              ),
            ),
          );

      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (roots.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(ctx.t('word.comments_none'),
                    textAlign: TextAlign.center),
              ),
            for (final r in roots) ...[
              tile(r),
              for (final x in all)
                if (x.parentId == r.id) tile(x, reply: true),
            ],
            const SizedBox(height: Gap.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('word-comment-new'),
              onPressed: addNew,
              icon: const Icon(AppIcons.addComment),
              label: Text(ctx.t('word.comment_new')),
            ),
          ],
        ),
      );
    }),
  );
}
