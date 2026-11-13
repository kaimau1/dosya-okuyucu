import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/pdf/pro/pdf_edit_bridge.dart';
import '../../services/pdf/pro/pdf_sensitive.dart';
import '../app_dialog.dart';
import 'pdf_pro_bars.dart';
import 'pdf_pro_edit_controller.dart';

/// **Belge geneli bul ve değiştir** (Faz 58 / 3): içerik düzeyinde — metin
/// gerçekten değişir (açıklama değil). Büyük/küçük harf, tam sözcük, Türkçe
/// katlama (İ/ı); tek tek ya da tümü. Her blok tek geri alınabilir adım.
Future<void> showPdfFindReplaceSheet(
  BuildContext context, {
  required PdfProEditController controller,
  required void Function(PdfFindHit hit) onGoTo,
  String initial = '',
}) =>
    showAppSheet<void>(
      context,
      title: context.t('pse.find_title'),
      builder: (_) => _FindReplaceBody(
          controller: controller, onGoTo: onGoTo, initial: initial),
    );

class _FindReplaceBody extends StatefulWidget {
  const _FindReplaceBody(
      {required this.controller, required this.onGoTo, required this.initial});
  final PdfProEditController controller;
  final void Function(PdfFindHit hit) onGoTo;
  final String initial;

  @override
  State<_FindReplaceBody> createState() => _FindReplaceBodyState();
}

class _FindReplaceBodyState extends State<_FindReplaceBody> {
  late final _find = TextEditingController(text: widget.initial);
  final _replace = TextEditingController();
  bool _case = false, _word = false, _busy = false;
  List<PdfFindHit>? _hits;
  int _at = -1;
  String? _status;

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  Future<List<PdfFindHit>> _search() async {
    setState(() => _busy = true);
    final hits = await widget.controller
        .find(_find.text, matchCase: _case, wholeWord: _word);
    if (!mounted) return hits;
    setState(() {
      _busy = false;
      _hits = hits;
      _status = null;
      if (_at >= hits.length) _at = -1;
    });
    return hits;
  }

  Future<void> _next() async {
    final hits = _hits ?? await _search();
    if (hits.isEmpty || !mounted) return;
    setState(() => _at = (_at + 1) % hits.length);
    widget.onGoTo(hits[_at]);
  }

  Future<void> _apply(List<PdfFindHit> hits) async {
    if (hits.isEmpty) return;
    final done = context.t('pse.find_replaced');
    final partial = context.t('pse.find_replaced_partial');
    setState(() => _busy = true);
    final (n, refused) = await widget.controller
        .replaceHits(hits, _replace.text, label: 'pse.step_replace');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hits = null;
      _at = -1;
      _status = refused == 0
          ? done.replaceAll('{n}', '$n')
          : partial.replaceAll('{n}', '$n').replaceAll('{m}', '$refused');
    });
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('pse-find-field'),
            controller: _find,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: context.t('pse.find_what'),
              prefixIcon: const Icon(AppIcons.search),
            ),
            onChanged: (_) => setState(() {
              _hits = null;
              _at = -1;
            }),
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const ValueKey('pse-replace-field'),
            controller: _replace,
            decoration: InputDecoration(
              labelText: context.t('pse.find_with'),
              prefixIcon: const Icon(AppIcons.findReplace),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              FilterChip(
                label: Text(context.t('pse.find_case')),
                selected: _case,
                onSelected: (v) => setState(() {
                  _case = v;
                  _hits = null;
                }),
              ),
              FilterChip(
                label: Text(context.t('pse.find_word')),
                selected: _word,
                onSelected: (v) => setState(() {
                  _word = v;
                  _hits = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            _status ??
                (hits == null
                    ? context.t('pse.find_hint')
                    : hits.isEmpty
                        ? context.t('pse.find_none')
                        : context.t('pse.find_count', {
                            'n': hits.length,
                            'i': _at < 0 ? 0 : _at + 1,
                          })),
            key: const ValueKey('pse-find-status'),
            style: context.type.small,
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('pse-find-next'),
                  onPressed: _busy || _find.text.isEmpty ? null : _next,
                  child: Text(context.t('pse.find_next')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('pse-find-one'),
                  onPressed: _busy || hits == null || _at < 0
                      ? null
                      : () => _apply([hits[_at]]),
                  child: Text(context.t('pse.find_replace_one')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('pse-find-all'),
                  onPressed: _busy || _find.text.isEmpty
                      ? null
                      : () async => _apply(hits ?? await _search()),
                  child: Text(context.t('pse.find_replace_all')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String pdfAnnotTypeLabel(BuildContext context, int subtype) =>
    context.t(switch (subtype) {
      PdfAnnotType.highlight => 'pse.mk_highlight',
      PdfAnnotType.underline => 'pse.mk_underline',
      PdfAnnotType.strikeout => 'pse.mk_strikeout',
      PdfAnnotType.squiggly => 'pse.mk_squiggly',
      PdfAnnotType.ink => 'pse.mk_ink',
      PdfAnnotType.text => 'pse.mk_note',
      _ => 'pse.mk_other',
    });

/// **Yorum paneli** (Faz 60 / 3): belgenin bütün açıklamaları; süzgeç
/// (hepsi / açık / çözüldü), açıklamaya git, yanıtla, çöz, sil.
Future<void> showPdfCommentsSheet(
  BuildContext context, {
  required PdfProEditController controller,
  required void Function(PdfAnnotInfo annot) onGoTo,
}) =>
    showAppSheet<void>(
      context,
      title: context.t('pse.comments'),
      scrollable: false,
      builder: (_) => _CommentsBody(controller: controller, onGoTo: onGoTo),
    );

class _CommentsBody extends StatefulWidget {
  const _CommentsBody({required this.controller, required this.onGoTo});
  final PdfProEditController controller;
  final void Function(PdfAnnotInfo annot) onGoTo;

  @override
  State<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends State<_CommentsBody> {
  List<PdfAnnotInfo>? _all;
  int _filter = 0; // 0 hepsi · 1 açık · 2 çözüldü

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.controller.allAnnotations();
    if (mounted) setState(() => _all = all);
  }

  Future<void> _change(PdfAnnotChange c) async {
    try {
      await widget.controller.annotate(c, label: 'pse.step_markup');
    } catch (_) {
      // Bilinçli: reddedilen açıklama değişikliği liste yenilenince görünür.
    }
    await _load();
  }

  Future<void> _reply(PdfAnnotInfo a) async {
    final reply = await showAppPrompt(context,
        title: context.t('pse.comment_reply'), multiline: true);
    if (reply == null || reply.trim().isEmpty || !mounted) return;
    final joined =
        a.contents.isEmpty ? reply.trim() : '${a.contents}\n↳ ${reply.trim()}';
    await _change(PdfAnnotChange.update(a.pageIndex, a.index, contents: joined));
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final scheme = Theme.of(context).colorScheme;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.all(Gap.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final list = [
      for (final a in all)
        if (_filter == 0 ||
            (_filter == 2) == (a.state == 'resolved'))
          a
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Gap.lg),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(context.t('pse.comments_all'))),
              ButtonSegment(value: 1, label: Text(context.t('pse.comments_open'))),
              ButtonSegment(
                  value: 2, label: Text(context.t('pse.comments_resolved'))),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Text(context.t('pse.comments_none'),
                textAlign: TextAlign.center, style: context.type.body),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                final resolved = a.state == 'resolved';
                return ListTile(
                  key: ValueKey('pse-comment-${a.pageIndex}-${a.index}'),
                  leading: CircleAvatar(
                    backgroundColor: a.color == 0
                        ? scheme.secondaryContainer
                        : Color(a.color | 0xFF000000),
                    child: Icon(
                        resolved ? AppIcons.check : AppIcons.comment,
                        size: AppIcons.small,
                        color: scheme.onSurface),
                  ),
                  title: Text(
                    a.contents.isEmpty
                        ? pdfAnnotTypeLabel(context, a.subtype)
                        : a.contents,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text([
                    context.t('pse.comment_page', {'n': a.pageIndex + 1}),
                    pdfAnnotTypeLabel(context, a.subtype),
                    if (a.author.isNotEmpty) a.author,
                  ].join(' · ')),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onGoTo(a);
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                    icon: const Icon(AppIcons.more),
                    onSelected: (v) {
                      switch (v) {
                        case 'reply':
                          _reply(a);
                        case 'state':
                          _change(PdfAnnotChange.update(a.pageIndex, a.index,
                              state: resolved ? 'open' : 'resolved'));
                        case 'delete':
                          _change(PdfAnnotChange.remove(a.pageIndex, a.index));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'reply',
                          child: Text(context.t('pse.comment_reply'))),
                      PopupMenuItem(
                          value: 'state',
                          child: Text(context.t(resolved
                              ? 'pse.comment_reopen'
                              : 'pse.comment_resolve'))),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(context.t('common.delete'))),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Renk seçme levhası; seçilen ARGB ya da null.
Future<int?> showPdfColorSheet(BuildContext context,
        {required String title, required List<int> colors, int? selected}) =>
    showAppSheet<int>(
      context,
      title: title,
      builder: (ctx) => PdfProSwatches(
        colors: colors,
        selected: selected,
        onPick: (c) => Navigator.of(ctx).pop(c),
      ),
    );

/// **Düzenlenemeyen blok** (PK7): neden + seçenekler. Dönen: 'line' (satır
/// kipine geç) · 'box' (üstüne metin kutusu) · null.
Future<String?> showPdfLockedBlockSheet(BuildContext context,
        {required PdfBlockLock lock}) =>
    showAppSheet<String>(
      context,
      // Belge kilidi başlığı ("Bu belge … korunuyor") değil: kilitli olan blok.
      title: context.t('pse.locked_why'),
      builder: (ctx) => Padding(
        padding:
            const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(switch (lock) {
                PdfBlockLock.rtl => 'pse.locked_rtl',
                PdfBlockLock.invisible => 'pse.locked_ocr',
                PdfBlockLock.none => 'pse.refused',
              }),
              style: context.type.body,
            ),
            const SizedBox(height: Gap.md),
            FilledButton.tonalIcon(
              key: const ValueKey('pse-locked-box'),
              icon: const Icon(AppIcons.textFields),
              label: Text(context.t('pse.locked_box')),
              onPressed: () => Navigator.of(ctx).pop('box'),
            ),
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              key: const ValueKey('pse-locked-line'),
              icon: const Icon(AppIcons.lines),
              label: Text(context.t('pse.locked_line')),
              onPressed: () => Navigator.of(ctx).pop('line'),
            ),
          ],
        ),
      ),
    );

/// **Görsel kırpma** (Faz 59 / 1): dört kenardan yüzde. Dönen: (sol, üst, sağ,
/// alt) 0–0,45 arası oranlar; vazgeçilirse null.
Future<(double, double, double, double)?> showPdfCropSheet(
        BuildContext context) =>
    showAppSheet<(double, double, double, double)>(
      context,
      title: context.t('pse.img_crop'),
      builder: (_) => const _CropBody(),
    );

class _CropBody extends StatefulWidget {
  const _CropBody();
  @override
  State<_CropBody> createState() => _CropBodyState();
}

class _CropBodyState extends State<_CropBody> {
  final _v = [0.0, 0.0, 0.0, 0.0];

  @override
  Widget build(BuildContext context) {
    const keys = [
      'pse.crop_left',
      'pse.crop_top',
      'pse.crop_right',
      'pse.crop_bottom'
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++)
            Row(
              children: [
                SizedBox(
                    width: 72,
                    child: Text(context.t(keys[i]), style: context.type.small)),
                Expanded(
                  child: Slider(
                    key: ValueKey('pse-crop-$i'),
                    value: _v[i],
                    max: 0.45,
                    divisions: 45,
                    label: '${(_v[i] * 100).round()}%',
                    semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _v[i] = v),
                  ),
                ),
              ],
            ),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('pse-crop-apply'),
            onPressed: _v.every((x) => x == 0)
                ? null
                : () => Navigator.of(context).pop((_v[0], _v[1], _v[2], _v[3])),
            child: Text(context.t('pse.img_crop')),
          ),
        ],
      ),
    );
  }
}

/// **AI önerisi — fark görünümü** (Faz 65 / 1): eski metin üstü çizili, yeni
/// metin altında. Dönen: true = kabul.
Future<bool?> showPdfSuggestionSheet(BuildContext context,
        {required String before, required String after}) =>
    showAppSheet<bool>(
      context,
      title: context.t('pse.ai_suggestion'),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding:
              const EdgeInsetsDirectional.fromSTEB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('pse.ai_before'), style: ctx.type.caption),
              const SizedBox(height: Gap.xs),
              Text(
                before,
                key: const ValueKey('pse-ai-before'),
                style: ctx.type.body.copyWith(
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(height: Gap.md),
              Text(context.t('pse.ai_after'), style: ctx.type.caption),
              const SizedBox(height: Gap.xs),
              Container(
                padding: const EdgeInsets.all(Gap.sm),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Text(after,
                    key: const ValueKey('pse-ai-after'), style: ctx.type.body),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(context.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('pse-ai-accept'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(context.t('pse.ai_accept')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

/// **Kişisel verileri bul ve karart** (Faz 64 / 2 — KVKK): TC kimlik no, IBAN,
/// telefon, e-posta ve özel sözcükler aranır; kullanıcı önizler, seçer,
/// onaylar. Dönen: karartılacak öneriler (vazgeçilirse null).
Future<List<PdfRedactHit>?> showPdfSensitiveSheet(BuildContext context,
        {required PdfProEditController controller}) =>
    showAppSheet<List<PdfRedactHit>>(
      context,
      title: context.t('pse.kvkk_title'),
      scrollable: false,
      builder: (_) => _SensitiveBody(controller: controller),
    );

class _SensitiveBody extends StatefulWidget {
  const _SensitiveBody({required this.controller});
  final PdfProEditController controller;

  @override
  State<_SensitiveBody> createState() => _SensitiveBodyState();
}

class _SensitiveBodyState extends State<_SensitiveBody> {
  final _custom = TextEditingController();
  List<PdfRedactHit>? _hits;
  final Set<int> _off = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _busy = true);
    final hits = await widget.controller.findSensitive(custom: [
      for (final w in _custom.text.split(','))
        if (w.trim().isNotEmpty) w.trim()
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hits = hits;
      _off.clear();
    });
  }

  String _kind(BuildContext context, PdfSensitiveKind k) =>
      context.t(switch (k) {
        PdfSensitiveKind.tckn => 'pse.kvkk_tckn',
        PdfSensitiveKind.iban => 'pse.kvkk_iban',
        PdfSensitiveKind.phone => 'pse.kvkk_phone',
        PdfSensitiveKind.email => 'pse.kvkk_email',
        PdfSensitiveKind.custom => 'pse.kvkk_custom',
      });

  /// Önizlemede değerin tamamı gösterilmez (ekran görüntüsüne sızmasın).
  static String _mask(String v) => v.length <= 4
      ? '••••'
      : '${v.substring(0, 2)}${'•' * (v.length - 4)}${v.substring(v.length - 2)}';

  @override
  Widget build(BuildContext context) {
    final hits = _hits;
    final picked = hits == null
        ? const <PdfRedactHit>[]
        : [
            for (var i = 0; i < hits.length; i++)
              if (!_off.contains(i)) hits[i]
          ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Gap.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('pse-kvkk-custom'),
                  controller: _custom,
                  decoration: InputDecoration(
                      labelText: context.t('pse.kvkk_custom_hint')),
                  onSubmitted: (_) => _scan(),
                ),
              ),
              IconButton(
                tooltip: context.t('pse.find_next'),
                icon: const Icon(AppIcons.search),
                onPressed: _busy ? null : _scan,
              ),
            ],
          ),
        ),
        if (hits == null || _busy)
          const Padding(
            padding: EdgeInsets.all(Gap.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Text(context.t('pse.kvkk_none'),
                key: const ValueKey('pse-kvkk-none'),
                textAlign: TextAlign.center,
                style: context.type.body),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: hits.length,
              itemBuilder: (context, i) => CheckboxListTile(
                key: ValueKey('pse-kvkk-$i'),
                value: !_off.contains(i),
                onChanged: (v) => setState(
                    () => v == true ? _off.remove(i) : _off.add(i)),
                title: Text(_mask(hits[i].text)),
                subtitle: Text([
                  _kind(context, hits[i].kind),
                  context.t('pse.comment_page', {'n': hits[i].pageIndex + 1}),
                ].join(' · ')),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.lg, Gap.sm, Gap.lg, Gap.lg),
          child: FilledButton(
            key: const ValueKey('pse-kvkk-apply'),
            onPressed: picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(picked),
            child: Text(context.t('pse.kvkk_apply', {'n': picked.length})),
          ),
        ),
      ],
    );
  }
}
