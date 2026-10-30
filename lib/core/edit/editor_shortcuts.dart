/// Donanım klavyesi kısayolları (Faz 20 / ED6): Ctrl+Z/Y/S/F/B/I/U/A, Esc;
/// Faz 33: **Ctrl+/** kısayol yardım sayfası.
///
/// Editörler yalnız destekledikleri eylemleri verir; verilmeyen kısayol
/// sistemde kalır (Ctrl+C/X/V metin alanlarının kendi işi — onları
/// ezmemek için burada bağlanmaz; editör özel pano kullanıyorsa [copy] vb.
/// verir). Yardım sayfası YALNIZ bağlı olanları listeler (+ [extraHelp]):
/// çalışmayan bir kısayolu göstermek, olmayan kısayoldan kötüdür.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../../widgets/app_dialog.dart';
import '../theme.dart';

/// Yardım sayfasında bir satır: tuşlar ("Ctrl+B") ve ne yaptığı.
typedef ShortcutHelpEntry = (String keys, String label);

class EditorShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? undo, redo, save, find, bold, italic, underline;
  final VoidCallback? copy, cut, paste, selectAll, escape;

  /// Editörün kendi işlediği ek tuşlar (Excel'de ok/⇥/F2 …) — yalnız yardım
  /// sayfasında listelenir; bağlamayı editör kendisi yapar.
  final List<ShortcutHelpEntry> extraHelp;

  const EditorShortcuts({
    super.key,
    required this.child,
    this.undo,
    this.redo,
    this.save,
    this.find,
    this.bold,
    this.italic,
    this.underline,
    this.copy,
    this.cut,
    this.paste,
    this.selectAll,
    this.escape,
    this.extraHelp = const [],
  });

  static SingleActivator _ctrl(LogicalKeyboardKey k, {bool shift = false}) =>
      SingleActivator(k, control: true, shift: shift);

  /// Bağlı kısayolların yardım satırları (sırayla).
  List<ShortcutHelpEntry> helpEntries(AppStrings s) => [
        if (undo != null) ('Ctrl+Z', s.t('ks.undo')),
        if (redo != null) ('Ctrl+Y · Ctrl+⇧+Z', s.t('ks.redo')),
        if (save != null) ('Ctrl+S', s.t('ks.save')),
        if (find != null) ('Ctrl+F', s.t('ks.find')),
        if (bold != null) ('Ctrl+B', s.t('ks.bold')),
        if (italic != null) ('Ctrl+I', s.t('ks.italic')),
        if (underline != null) ('Ctrl+U', s.t('ks.underline')),
        if (copy != null) ('Ctrl+C', s.t('ks.copy')),
        if (cut != null) ('Ctrl+X', s.t('ks.cut')),
        if (paste != null) ('Ctrl+V', s.t('ks.paste')),
        if (selectAll != null) ('Ctrl+A', s.t('ks.select_all')),
        if (escape != null) ('Esc', s.t('ks.escape')),
        ...extraHelp,
        ('Ctrl+/', s.t('ks.help')),
      ];

  @override
  Widget build(BuildContext context) {
    final map = <ShortcutActivator, VoidCallback>{
      if (undo != null) _ctrl(LogicalKeyboardKey.keyZ): undo!,
      if (redo != null) _ctrl(LogicalKeyboardKey.keyY): redo!,
      if (redo != null) _ctrl(LogicalKeyboardKey.keyZ, shift: true): redo!,
      if (save != null) _ctrl(LogicalKeyboardKey.keyS): save!,
      if (find != null) _ctrl(LogicalKeyboardKey.keyF): find!,
      if (bold != null) _ctrl(LogicalKeyboardKey.keyB): bold!,
      if (italic != null) _ctrl(LogicalKeyboardKey.keyI): italic!,
      if (underline != null) _ctrl(LogicalKeyboardKey.keyU): underline!,
      if (copy != null) _ctrl(LogicalKeyboardKey.keyC): copy!,
      if (cut != null) _ctrl(LogicalKeyboardKey.keyX): cut!,
      if (paste != null) _ctrl(LogicalKeyboardKey.keyV): paste!,
      if (selectAll != null) _ctrl(LogicalKeyboardKey.keyA): selectAll!,
      if (escape != null) const SingleActivator(LogicalKeyboardKey.escape):
          escape!,
      _ctrl(LogicalKeyboardKey.slash): () => showShortcutHelp(context, this),
    };
    return CallbackShortcuts(bindings: map, child: child);
  }
}

/// Ctrl+/ — editörün kısayol tablosu (alttan levha).
Future<void> showShortcutHelp(BuildContext context, EditorShortcuts shortcuts) {
  final entries = shortcuts.helpEntries(AppStrings.of(context));
  return showAppSheet<void>(
    context,
    title: context.t('ks.title'),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        key: const ValueKey('shortcut-help'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, Gap.lg),
        child: Column(
          children: [
            for (final (keys, label) in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    const SizedBox(width: Gap.md),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Gap.xs),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm, vertical: 2),
                        child: Text(keys, style: theme.textTheme.labelLarge),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
