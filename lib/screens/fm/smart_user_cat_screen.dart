import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/smart_user_cats.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/fm/smart_cat_style.dart';
import '../../widgets/section_header.dart';

/// **Kullanıcı kategorisi** ekle/düzenle (Akıllı düzen 2.0, PLAN §1.1 m.3):
/// ad + "neyi kapsar" cümlesi + simge/renk. Kaydetmeden önce **"Dene"**:
/// son [SmartUserCats.trialFiles] dosyada tek soru, eşleşenler listelenir;
/// ≥ 1 eşleşme ve "Sonuçlar doğru" onayı olmadan kaydedilmez
/// ([SmartUserCats.canSave]). Düzenlemede yalnız simge/renk değiştiyse
/// yeniden deneme gerekmez (soru aynı).
class SmartUserCatScreen extends StatefulWidget {
  const SmartUserCatScreen({super.key, this.initial});

  final SmartUserCat? initial;

  /// Kaydedilen kategoriyi döner (vazgeçilirse null).
  static Future<SmartUserCat?> open(BuildContext context,
          {SmartUserCat? initial}) =>
      Navigator.of(context).push<SmartUserCat>(MaterialPageRoute(
          builder: (_) => SmartUserCatScreen(initial: initial)));

  @override
  State<SmartUserCatScreen> createState() => _SmartUserCatScreenState();
}

class _SmartUserCatScreenState extends State<SmartUserCatScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _about =
      TextEditingController(text: widget.initial?.about ?? '');
  late String _icon = widget.initial?.icon ?? SmartUserCats.icons.first;
  late String _color = widget.initial?.color ?? SmartUserCats.colors.first;

  /// Süren deneme (yapılan, toplam); null = boşta. Yalnız ilerleme satırı
  /// dinler.
  final ValueNotifier<(int, int)?> _trying = ValueNotifier(null);
  SmartTrial? _trial;
  bool _confirmed = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _trying.dispose();
    super.dispose();
  }

  /// Soru (ad ya da cümle) değişti mi? Yeni kategoride her zaman evet.
  bool get _questionChanged {
    final init = widget.initial;
    return init == null ||
        init.name != _name.text.trim() ||
        init.about != _about.text.trim();
  }

  bool get _canSave {
    if (_saving || _trying.value != null) return false;
    if (_name.text.trim().isEmpty || _about.text.trim().isEmpty) return false;
    if (!_questionChanged) return true;
    return SmartUserCats.canSave(
        name: _name.text,
        about: _about.text,
        trial: _trial,
        confirmed: _confirmed);
  }

  Future<void> _try() async {
    FocusScope.of(context).unfocus();
    if (!await ensureAiKey(context) || !mounted) return;
    final state = context.read<AppState>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _trying.value = (0, 0);
    setState(() {
      _trial = null;
      _confirmed = false;
    });
    SmartTrial? t;
    try {
      t = await SmartUserCats.trial(
        name: _name.text,
        about: _about.text,
        credentials: state.aiCredentials,
        scope: state.aiScopeRules,
        onProgress: (done, total) {
          if (mounted) _trying.value = (done, total);
        },
      );
    } finally {
      if (mounted) _trying.value = null;
    }
    if (!mounted || t == null) return;
    setState(() => _trial = t);
    if (t.stoppedBy != null) {
      showSnackOn(messenger, s.t('suc.stopped', {'reason': t.stoppedBy}));
    } else if (t.hits.isEmpty) {
      showSnackOn(messenger, s.t('suc.no_files'));
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final init = widget.initial;
    final SmartUserCat? out;
    if (init == null) {
      out = await SmartUserCats.add(
        name: _name.text,
        about: _about.text,
        icon: _icon,
        color: _color,
        trial: _trial,
      );
    } else {
      final next = init.copyWith(
          name: _name.text, about: _about.text, icon: _icon, color: _color);
      await SmartUserCats.update(next,
          trial: _questionChanged ? _trial : null);
      out = SmartUserCats.byId(init.id);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (out != null) nav.pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(
            widget.initial == null ? 'suc.new_title' : 'suc.edit_title')),
      ),
      body: ListView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
        children: [
          TextField(
            key: const ValueKey('suc-name'),
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.t('suc.name'),
              hintText: context.t('suc.name_hint'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const ValueKey('suc-about'),
            controller: _about,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.t('suc.about'),
              hintText: context.t('suc.about_hint'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SectionHeader(context.t('suc.icon'),
              padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs)),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final k in SmartUserCats.icons)
                ChoiceChip(
                  key: ValueKey('suc-icon-$k'),
                  label: Icon(SmartCatStyle.userIcon(k),
                      size: AppIcons.small,
                      color: SmartCatStyle.userColor(_color)),
                  selected: _icon == k,
                  onSelected: (_) => setState(() => _icon = k),
                ),
            ],
          ),
          SectionHeader(context.t('suc.color'),
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs)),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final k in SmartUserCats.colors)
                ChoiceChip(
                  key: ValueKey('suc-color-$k'),
                  label: Icon(AppIcons.dot,
                      size: AppIcons.small, color: SmartCatStyle.userColor(k)),
                  selected: _color == k,
                  onSelected: (_) => setState(() => _color = k),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          if (_questionChanged) ..._trialPart(context, theme),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const ValueKey('suc-save'),
            onPressed: _canSave ? _save : null,
            icon: const Icon(AppIcons.check),
            label: Text(context.t('suc.save')),
          ),
          if (!_canSave && _questionChanged) ...[
            const SizedBox(height: Gap.xs),
            Text(context.t('suc.save_need'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  List<Widget> _trialPart(BuildContext context, ThemeData theme) {
    final t = _trial;
    final stale = t != null && !t.isFor(_name.text, _about.text);
    final ready = _name.text.trim().isNotEmpty && _about.text.trim().isNotEmpty;
    final matches = t?.matches.length ?? 0;
    return [
      Text(context.t('suc.try_sub', {'n': SmartUserCats.trialFiles}),
          style: theme.textTheme.bodySmall),
      const SizedBox(height: Gap.sm),
      // İlerleme satırı ağaçta sabit; yalnız kendisi yeniden çizilir.
      ValueListenableBuilder<(int, int)?>(
        valueListenable: _trying,
        builder: (context, prog, _) => prog == null
            ? OutlinedButton.icon(
                key: const ValueKey('suc-try'),
                onPressed: ready && !_saving ? _try : null,
                icon: const Icon(AppIcons.ai),
                label: Text(context.t('suc.try')),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                      value: prog.$2 == 0 ? null : prog.$1 / prog.$2),
                  const SizedBox(height: Gap.xs),
                  Text(context.t(
                      'suc.trying', {'done': prog.$1, 'total': prog.$2})),
                ],
              ),
      ),
      if (t != null && t.hits.isNotEmpty) ...[
        const SizedBox(height: Gap.md),
        Text(
          stale
              ? context.t('suc.try_stale')
              : (matches == 0
                  ? context.t('suc.try_none', {'n': t.hits.length})
                  : context.t(
                      'suc.try_hits', {'m': matches, 'n': t.hits.length})),
          key: const ValueKey('suc-result'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: Gap.xs),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final h in t.hits)
              ListTile(
                dense: true,
                leading: Icon(h.match ? AppIcons.check : AppIcons.close,
                    color: h.match
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                title: Text(h.entry.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(context.t(
                    h.match ? 'suc.matched' : 'suc.not_matched')),
                trailing: Text('${(h.yes * 100).round()}%',
                    style: theme.textTheme.labelSmall),
              ),
          ]),
        ),
        if (matches > 0 && !stale)
          CheckboxListTile(
            key: const ValueKey('suc-confirm'),
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            title: Text(context.t('suc.confirm')),
            subtitle: Text(context.t('suc.confirm_sub')),
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
      ],
    ];
  }
}
