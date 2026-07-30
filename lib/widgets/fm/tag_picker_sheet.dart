import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/file_tags.dart';

/// **Etiketle** sayfası: seçili dosyalara kişi/grup etiketi verir.
///
/// Niye etiket: WhatsApp/Telegram dosyalarında gönderen bilgisi diskte YOK
/// (bkz. `models/chat_media.dart`). "Ayşe'den gelenler" gibi bir süzme ancak
/// kullanıcının bir kez etiketlemesiyle mümkün — uydurmak yerine sorulur.
///
/// Değişiklik yapıldıysa true döner.
Future<bool> showTagPicker(BuildContext context, List<String> paths) async {
  await FileTags.ensureLoaded();
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TagSheet(paths: paths),
  );
  return result ?? false;
}

class _TagSheet extends StatefulWidget {
  final List<String> paths;
  const _TagSheet({required this.paths});

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  final _controller = TextEditingController();
  bool _changed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Seçilen dosyaların **tamamında** olan etiketler (üç durumlu gösterim
  /// yerine: hepsinde varsa işaretli, bazısında varsa yarım işaretli).
  Set<String> get _common {
    Set<String>? common;
    for (final path in widget.paths) {
      final tags = FileTags.forPath(path);
      common = common == null ? {...tags} : common.intersection(tags);
    }
    return common ?? {};
  }

  Set<String> get _partial {
    final any = <String>{};
    for (final path in widget.paths) {
      any.addAll(FileTags.forPath(path));
    }
    return any.difference(_common);
  }

  Future<void> _addNew() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await FileTags.add(widget.paths, name);
    _controller.clear();
    if (mounted) setState(() => _changed = true);
  }

  Future<void> _toggle(String tag, bool add) async {
    if (add) {
      await FileTags.add(widget.paths, tag);
    } else {
      await FileTags.remove(widget.paths, tag);
    }
    if (mounted) setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = FileTags.counts().keys.toList()..sort();
    final common = _common;
    final partial = _partial;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.paths.length == 1
                        ? 'Etiketle'
                        : 'Etiketle (${widget.paths.length} dosya)',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const Divider(height: Gap.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: context.t('tp.new_tag'),
                              hintText: context.t('tp.new_tag_hint'),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addNew(),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        FilledButton(
                          onPressed: _addNew,
                          child: const Text('Ekle'),
                        ),
                      ],
                    ),
                    if (all.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      Text('Var olan etiketler',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: Gap.sm),
                      Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.xs,
                        children: [
                          for (final tag in all)
                            FilterChip(
                              label: Text(partial.contains(tag)
                                  ? context.t('tp.partial', {'tag': tag})
                                  : tag),
                              selected: common.contains(tag),
                              onSelected: (v) => _toggle(tag, v),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Gap.md),
                    Text(
                      context.t('tp.note'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _changed),
                    child: const Text('Tamam'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
