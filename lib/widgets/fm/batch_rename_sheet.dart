import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/batch_rename.dart';
import '../../services/fm/file_ops.dart';

/// **Toplu yeniden adlandırma** sayfası: kalıp yaz → **canlı önizleme** → uygula.
///
/// Önizleme şart: 200 dosyayı yeniden adlandırmak geri alınması zahmetli bir
/// iştir; kullanıcı "IMG_0001.jpg → Tatil-01.jpg" dönüşümünü uygulamadan ÖNCE
/// görmeli. Çakışan/boş adlar kırmızı yazılır ve o dosyalar atlanır.
///
/// Uzantı otomatik korunur (bkz. `planBatchRename`) — kullanıcı `.jpg`'yi
/// yanlışlıkla silerse dosya açılamaz hâle gelirdi.
Future<bool> showBatchRenameSheet(
  BuildContext context,
  List<FsEntry> entries,
) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _BatchRenameSheet(entries: entries),
  );
  return changed ?? false;
}

class _BatchRenameSheet extends StatefulWidget {
  final List<FsEntry> entries;
  const _BatchRenameSheet({required this.entries});

  @override
  State<_BatchRenameSheet> createState() => _BatchRenameSheetState();
}

class _BatchRenameSheetState extends State<_BatchRenameSheet> {
  final _patternController = TextEditingController(text: '{ad}');
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  int _startAt = 1;
  bool _running = false;

  @override
  void dispose() {
    _patternController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  List<RenamePreview> get _preview => planBatchRename(
        widget.entries,
        pattern: _patternController.text,
        startAt: _startAt,
        find: _findController.text,
        replace: _replaceController.text,
      );

  Future<void> _apply() async {
    final plan = _preview.where((r) => r.isValid && r.changed).toList();
    if (plan.isEmpty) return;
    setState(() => _running = true);
    var ok = 0;
    final errors = <String>[];
    for (final item in plan) {
      try {
        await FileOps.rename(item.entry.path, item.newName);
        ok++;
      } catch (e) {
        errors.add('${item.entry.name}: $e');
      }
    }
    if (!mounted) return;
    setState(() => _running = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errors.isEmpty
          ? '$ok dosya yeniden adlandırıldı.'
          : '$ok dosya adlandırıldı, ${errors.length} hata: ${errors.first}'),
    ));
    if (mounted) Navigator.pop(context, ok > 0);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final valid = preview.where((r) => r.isValid && r.changed).length;
    final problems = preview.where((r) => !r.isValid).length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Toplu yeniden adlandır',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text('${widget.entries.length} dosya',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: Gap.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  children: [
                    Wrap(
                      spacing: Gap.sm,
                      children: [
                        for (final preset in batchRenamePresets)
                          ActionChip(
                            label: Text(preset.label),
                            onPressed: () => setState(() =>
                                _patternController.text = preset.pattern),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    TextField(
                      controller: _patternController,
                      decoration: const InputDecoration(
                        labelText: 'Ad kalıbı',
                        helperText: '{ad} {n} {n2} {tarih} {uzanti}',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _findController,
                            decoration: const InputDecoration(
                              labelText: 'Bul (eski adda)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: TextField(
                            controller: _replaceController,
                            decoration: const InputDecoration(
                              labelText: 'Değiştir',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        SizedBox(
                          width: 92,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Başlangıç',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            controller:
                                TextEditingController(text: '$_startAt'),
                            onChanged: (v) => setState(
                                () => _startAt = int.tryParse(v) ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    Text('Önizleme',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: Gap.xs),
                    // İlk 30 satır: kalıbın doğru olduğunu görmek için yeter,
                    // 5.000 satır çizmek sayfayı kilitlerdi.
                    for (final item in preview.take(30))
                      _row(item),
                    if (preview.length > 30)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Text('… ve ${preview.length - 30} dosya daha',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: Gap.md),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        problems > 0
                            ? '$valid dosya değişecek · $problems sorunlu '
                                '(atlanacak)'
                            : '$valid dosya değişecek',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    FilledButton.icon(
                      onPressed: _running || valid == 0 ? null : _apply,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Uygula'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(RenamePreview item) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(item.entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const Icon(Icons.arrow_right_alt, size: 16),
          Expanded(
            child: Text(
              item.problem ?? item.newName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.isValid ? scheme.primary : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
