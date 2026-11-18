import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/smart_bench.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_input.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/section_header.dart';

/// **Doğruluk ölçümü** (Akıllı düzen 2.0, PLAN §1.1 m.4; Geliştirici
/// ayarlarında gizli): kullanıcı kendi dosyalarını etiketler, AI yanıtıyla
/// karşılaştırılır ([SmartBench]). Kapı: kategori ≥ %90, alt tür ≥ %80.
/// Etiketler yalnız cihazda; kopyalanan raporda dosya adı yok.
class SmartBenchScreen extends StatefulWidget {
  const SmartBenchScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SmartBenchScreen()));

  @override
  State<SmartBenchScreen> createState() => _SmartBenchScreenState();
}

class _SmartBenchScreenState extends State<SmartBenchScreen> {
  @override
  void initState() {
    super.initState();
    SmartBench.ensureLoaded();
    SmartSort.ensureLoaded();
  }

  Future<void> _ask({required bool all}) async {
    if (!await ensureAiKey(context) || !mounted) return;
    final state = context.read<AppState>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final (ok, failed, stopped) = await SmartBench.askModel(
        credentials: state.aiCredentials, scope: state.aiScopeRules, all: all);
    if (!mounted) return;
    showSnackOn(
        messenger,
        stopped != null
            ? s.t('sb.stopped', {'reason': stopped})
            : s.t('sb.asked', {'ok': ok, 'failed': failed}));
  }

  Future<void> _copy() async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(
        text: SmartBench.report(SmartBench.current(), date: DateTime.now())));
    showSnackOn(messenger, s.t('sb.copied'));
  }

  Future<void> _pick() async {
    if (SmartBench.items.length >= SmartBench.maxItems) {
      showSnack(context, context.t('sb.full', {'n': SmartBench.maxItems}));
      return;
    }
    final scope = context.read<AppState>().aiScopeRules;
    final e = await Navigator.of(context).push<FsEntry>(MaterialPageRoute(
        builder: (_) => _BenchPickScreen(load: SmartBench.candidates(scope))));
    if (e == null || !mounted) return;
    await _label(path: e.path, size: e.sizeBytes, modifiedMs: e.modifiedMs);
  }

  Future<void> _label(
      {required String path,
      required int size,
      required int modifiedMs}) async {
    final old = SmartBench.of(path);
    final item = await showAppSheet<SmartBenchItem>(context,
        title: context.t('sb.label_title'),
        builder: (_) => _LabelSheet(
            path: path, size: size, modifiedMs: modifiedMs, initial: old));
    if (item == null || !mounted) return;
    if (item.cat.isEmpty) {
      await SmartBench.remove(path);
      return;
    }
    final saved = await SmartBench.put(item);
    if (saved || !mounted) return;
    showSnack(context, context.t('sb.full', {'n': SmartBench.maxItems}));
  }

  Future<void> _clear() async {
    final ok = await showAppConfirm(context,
        message: context.t('sb.clear_ask'),
        confirmLabel: context.t('sb.clear'),
        destructive: true);
    if (ok) await SmartBench.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('sb.title')),
        actions: [
          IconButton(
            key: const ValueKey('sb-copy'),
            tooltip: context.t('sb.copy'),
            icon: const Icon(AppIcons.copy),
            onPressed: _copy,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([SmartBench.revision, SmartSort.revision]),
        builder: (context, _) => _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final items = SmartBench.items;
    final guesses = {
      for (final i in items) i.path: SmartBench.guessFor(i, SmartSort.of(i.path))
    };
    final m = SmartBench.compute([for (final i in items) (i, guesses[i.path])]);
    final missing = guesses.values.where((g) => g == null).length;
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
      children: [
        Text(context.t('sb.intro', {'n': SmartBench.maxItems}),
            style: theme.textTheme.bodySmall),
        const SizedBox(height: Gap.md),
        _Summary(m: m),
        const SizedBox(height: Gap.md),
        ValueListenableBuilder<(int, int)?>(
          valueListenable: SmartBench.asking,
          builder: (context, prog, _) => prog == null
              ? Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('sb-add'),
                      onPressed: _pick,
                      icon: const Icon(AppIcons.add),
                      label: Text(context.t('sb.add')),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('sb-ask'),
                      onPressed: missing == 0 ? null : () => _ask(all: false),
                      icon: const Icon(AppIcons.ai),
                      label: Text(context.t('sb.ask_missing', {'n': missing})),
                    ),
                    TextButton(
                      key: const ValueKey('sb-ask-all'),
                      onPressed: items.isEmpty ? null : () => _ask(all: true),
                      child: Text(context.t('sb.ask_all')),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                        value: prog.$2 == 0 ? null : prog.$1 / prog.$2),
                    const SizedBox(height: Gap.xs),
                    Row(children: [
                      Expanded(
                        child: Text(context.t('sb.asking',
                            {'done': prog.$1, 'total': prog.$2})),
                      ),
                      TextButton(
                        onPressed: SmartBench.stop,
                        child: Text(context.t('sb.stop')),
                      ),
                    ]),
                  ],
                ),
        ),
        SectionHeader(context.t('sb.labelled'),
            count: '${items.length}',
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs)),
        if (items.isEmpty)
          Text(context.t('sb.empty'), style: theme.textTheme.bodyMedium)
        else
          for (final i in items.reversed)
            _BenchRow(
              item: i,
              guess: guesses[i.path],
              onTap: () => _label(
                  path: i.path, size: i.size, modifiedMs: i.modifiedMs),
            ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('sb-clear'),
              onPressed: _clear,
              icon: const Icon(AppIcons.delete),
              label: Text(context.t('sb.clear')),
            ),
          ),
        ],
      ],
    );
  }
}

/// Üç oran + kapı + eşik önerisi.
class _Summary extends StatelessWidget {
  const _Summary({required this.m});

  final SmartBenchMetrics m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String pct(double v) => '${(v * 100).round()}%';
    Widget line(String key, SmartBenchRate r, double? gate) {
      final v = r.rate;
      final pass = gate != null && v != null && r.passes(gate);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(children: [
          if (gate != null)
            Icon(pass ? AppIcons.check : AppIcons.close,
                size: AppIcons.small,
                color: pass
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error)
          else
            const SizedBox(width: AppIcons.small),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(context.t(key))),
          Text(
            v == null
                ? context.t('sb.no_data')
                : '${pct(v)} (${r.correct}/${r.total})',
            style: theme.textTheme.titleSmall,
          ),
          if (gate != null) ...[
            const SizedBox(width: Gap.sm),
            Text(context.t('sb.gate', {'g': pct(gate)}),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ]),
      );
    }

    return Card(
      key: const ValueKey('sb-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('sb.category', m.category, SmartBench.categoryGate),
            line('sb.subtype', m.subtype, SmartBench.subtypeGate),
            line('sb.date', m.date, null),
            const SizedBox(height: Gap.xs),
            Text(context.t('sb.measured', {'m': m.measured, 'n': m.labelled}),
                style: theme.textTheme.bodySmall),
            Text(
              m.suggested == null
                  ? context.t('sb.threshold_none')
                  : context.t('sb.threshold',
                      {'t': m.suggested!.toStringAsFixed(2)}),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _catName(BuildContext context, String cat) =>
    context.t('sm.c_$cat');

String _guessText(BuildContext context, SmartBenchGuess? g) {
  if (g == null) return context.t('sb.row_none');
  final cat = _catName(context, g.cat);
  return g.sub.isEmpty ? cat : '$cat · ${context.t('sm.s_${g.sub}')}';
}

String _truthText(BuildContext context, SmartBenchItem i) {
  final cat = _catName(context, i.cat);
  final sub = i.sub;
  return sub == null || sub.isEmpty ? cat : '$cat · ${context.t('sm.s_$sub')}';
}

class _BenchRow extends StatelessWidget {
  const _BenchRow({required this.item, required this.guess, required this.onTap});

  final SmartBenchItem item;
  final SmartBenchGuess? guess;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = guess;
    final right = g != null && g.cat == item.cat;
    final name = item.path.split('/').last;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        g == null ? AppIcons.ai : (right ? AppIcons.check : AppIcons.close),
        color: g == null
            ? scheme.onSurfaceVariant
            : (right ? scheme.primary : scheme.error),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        context.t('sb.row', {
          'truth': _truthText(context, item),
          'model': _guessText(context, g),
        }),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Etiketlenecek dosya seçimi: kapsamdaki en yeni dosyalar.
class _BenchPickScreen extends StatefulWidget {
  const _BenchPickScreen({required this.load});

  final Future<List<FsEntry>> load;

  @override
  State<_BenchPickScreen> createState() => _BenchPickScreenState();
}

class _BenchPickScreenState extends State<_BenchPickScreen> {
  List<FsEntry>? _files;

  @override
  void initState() {
    super.initState();
    widget.load.then((v) {
      if (mounted) setState(() => _files = v);
    }, onError: (Object _) {
      if (mounted) setState(() => _files = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sb.pick_title'))),
      body: files == null
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Text(context.t('sb.pick_empty'),
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  padding: withNavInset(context, EdgeInsets.zero),
                  itemCount: files.length,
                  itemExtent: 64,
                  itemBuilder: (context, i) {
                    final e = files[i];
                    final done = SmartBench.of(e.path) != null;
                    return ListTile(
                      leading: FmEntryIcon(entry: e, size: 40),
                      title: Text(e.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: done ? const Icon(AppIcons.check) : null,
                      onTap: () => Navigator.of(context).pop(e),
                    );
                  },
                ),
    );
  }
}

/// Doğru etiket: kategori, alt tür (puanlama / hiçbiri / tür), tarih.
/// Kapanışta öğe döner; boş kategorili öğe = etiketi sil.
class _LabelSheet extends StatefulWidget {
  const _LabelSheet({
    required this.path,
    required this.size,
    required this.modifiedMs,
    this.initial,
  });

  final String path;
  final int size;
  final int modifiedMs;
  final SmartBenchItem? initial;

  @override
  State<_LabelSheet> createState() => _LabelSheetState();
}

class _LabelSheetState extends State<_LabelSheet> {
  late final String? _fixed = switch (SmartSortInput.kindOf(widget.path)) {
    SmartInputKind.audio => SmartTaxonomy.audio,
    SmartInputKind.video => SmartTaxonomy.video,
    SmartInputKind.meta => SmartTaxonomy.package,
    _ => null,
  };
  // Eski etiket seçeneklerde yoksa (şema değişti, yıl eskidi) boş başlar:
  // açılır liste listede olmayan değerle kurulamaz.
  late String? _cat = _fixed ??
      (_cats.contains(widget.initial?.cat) ? widget.initial?.cat : null);
  late String? _sub = _initialSub();
  late bool _dated = widget.initial?.dated ?? false;
  late int _month = _initialMonth();
  late int _year = _years.contains(widget.initial?.year)
      ? widget.initial!.year
      : 0;

  String? _initialSub() {
    final i = widget.initial;
    if (i == null || i.cat != _cat) return null;
    final sub = i.sub;
    if (sub == null || sub.isEmpty) return sub;
    return _subs.contains(sub) ? sub : null;
  }

  int _initialMonth() {
    final mo = widget.initial?.month ?? 0;
    return mo >= 1 && mo <= 12 ? mo : 0;
  }

  static List<int> get _years {
    final now = DateTime.now().year;
    return [for (var y = now; y > now - 8; y--) y];
  }

  List<String> get _cats {
    final fixed = _fixed;
    if (fixed != null) return [fixed];
    return [
      for (final c in SmartTaxonomy.categoryIds)
        if (!SmartTaxonomy.fixedCategories.contains(c)) c
    ];
  }

  List<String> get _subs => [
        for (final s in (SmartTaxonomy.subtypes[_cat] ?? const {}).keys)
          if (s != SmartTaxonomy.other) s
      ];

  void _done() {
    final cat = _cat;
    if (cat == null) return;
    final doc = SmartTaxonomy.isDoc(cat);
    Navigator.of(context).pop(SmartBenchItem(
      path: widget.path,
      size: widget.size,
      modifiedMs: widget.modifiedMs,
      cat: cat,
      sub: _subs.isEmpty ? null : _sub,
      dated: doc && _dated,
      month: doc && _dated ? _month : 0,
      year: doc && _dated ? _year : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cat = _cat;
    final subs = _subs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.path.split('/').last,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Gap.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('sb-cat'),
          initialValue: cat,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.t('sb.category')),
          items: [
            for (final c in _cats)
              DropdownMenuItem(value: c, child: Text(_catName(context, c))),
          ],
          onChanged: _fixed != null
              ? null
              : (v) => setState(() {
                    if (v != _cat) _sub = null;
                    _cat = v;
                  }),
        ),
        if (cat != null && subs.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          DropdownButtonFormField<String?>(
            key: ValueKey('sb-sub-$cat'),
            initialValue: _sub,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.t('sb.subtype')),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text(context.t('sb.sub_skip'))),
              DropdownMenuItem<String?>(
                  value: '', child: Text(context.t('sb.sub_other'))),
              for (final s in subs)
                DropdownMenuItem<String?>(
                    value: s, child: Text(context.t('sm.s_$s'))),
            ],
            onChanged: (v) => setState(() => _sub = v),
          ),
        ],
        if (cat != null && SmartTaxonomy.isDoc(cat)) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('sb.date_label')),
            value: _dated,
            onChanged: (v) => setState(() => _dated = v),
          ),
          if (_dated)
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.t('sb.month')),
                  items: [
                    DropdownMenuItem(
                        value: 0, child: Text(context.t('sb.no_date'))),
                    for (var mo = 1; mo <= 12; mo++)
                      DropdownMenuItem(value: mo, child: Text('$mo')),
                  ],
                  onChanged: (v) => setState(() => _month = v ?? 0),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.t('sb.year')),
                  items: [
                    DropdownMenuItem(
                        value: 0, child: Text(context.t('sb.year_none'))),
                    for (final y in _years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setState(() => _year = v ?? 0),
                ),
              ),
            ]),
        ],
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          key: const ValueKey('sb-save'),
          onPressed: cat == null ? null : _done,
          icon: const Icon(AppIcons.check),
          label: Text(context.t('sb.save')),
        ),
        if (widget.initial != null)
          TextButton.icon(
            key: const ValueKey('sb-remove'),
            onPressed: () => Navigator.of(context).pop(SmartBenchItem(
                path: widget.path,
                size: widget.size,
                modifiedMs: widget.modifiedMs,
                cat: '')),
            icon: const Icon(AppIcons.delete),
            label: Text(context.t('sb.remove')),
          ),
      ],
    );
  }
}
