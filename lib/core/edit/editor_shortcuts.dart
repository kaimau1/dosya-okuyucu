/// Donanım klavyesi kısayolları (Faz 20 / ED6): Ctrl+Z/Y/S/F/B/I/U/A, Esc.
///
/// Editörler yalnız destekledikleri eylemleri verir; verilmeyen kısayol
/// sistemde kalır (Ctrl+C/X/V metin alanlarının kendi işi — onları
/// ezmemek için burada bağlanmaz; editör özel pano kullanıyorsa [copy] vb.
/// verir).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? undo, redo, save, find, bold, italic, underline;
  final VoidCallback? copy, cut, paste, selectAll, escape;

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
  });

  static SingleActivator _ctrl(LogicalKeyboardKey k, {bool shift = false}) =>
      SingleActivator(k, control: true, shift: shift);

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
    };
    if (map.isEmpty) return child;
    return CallbackShortcuts(bindings: map, child: child);
  }
}
