/// **Ortak editör üst çubuğu** (Faz 40 / madde 1, 2026-11-05).
///
/// KÖK NEDEN: dört editörün (Word sayfa/mobil, Excel, Slayt) üst çubuğu
/// dört ayrı sırayla kurulmuştu: Word'de ↶ ↷ 🔍 💾 ⋮, Excel'de ↶ ↷ 🔍 (kaydet
/// altta), Slayt'ta ↶ ↷ anahat 🔍 (kaydet yalnız yazarken), mobil Word'de
/// ↶ ↷ sayfa 💾. Kullanıcı bir editörden ötekine geçince aynı düğmeyi başka
/// yerde arıyordu.
///
/// Tek yapı: **başlık · kaydet · geri al · yinele · [editöre özgü] · ⋮**.
/// Sıra [EditorTopBar.actions] içinde sabittir; editör yalnız yuvaları doldurur.
/// ⋮ her editörde vardır (Paylaş/Dışa aktar orada — bkz. madde 7).
///
/// Perf: düz `IconButton` — `saveLayer`/blur yok; geri al/yinele durumu
/// [Listenable] verilirse yalnız o iki düğme yeniden kurulur (kökte watch yok).
library;

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';

/// ⋮ menüsündeki tek satır.
class EditorMenuItem {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const EditorMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.onTap,
  });
}

abstract final class EditorTopBar {
  /// Yuva anahtarları (testler ve TalkBack sırası için sabit).
  static const saveKey = ValueKey('editor-save');
  static const moreKey = ValueKey('editor-more');

  /// Üst çubuk eylemleri — SIRA SABİT: kaydet · geri al · yinele · ekler · ⋮.
  ///
  /// [undo]/[redo] her kurulumda okunur; [history] verilirse yalnız o iki
  /// düğme onu dinler.
  static List<Widget> actions(
    BuildContext context, {
    VoidCallback? onSave,
    bool showSave = true,
    ValueGetter<VoidCallback?>? undo,
    ValueGetter<VoidCallback?>? redo,
    Listenable? history,
    Key? undoKey,
    Key? redoKey,
    List<Widget> extras = const [],
    List<EditorMenuItem> menu = const [],
    Widget? more,
  }) {
    Widget undoRedo(bool isUndo) {
      Widget button() {
        final cb = (isUndo ? undo : redo)?.call();
        return IconButton(
          key: isUndo ? undoKey : redoKey,
          tooltip: context.t(isUndo ? 'word.undo' : 'word.redo'),
          icon: Icon(isUndo ? AppIcons.undo : AppIcons.redo),
          onPressed: cb,
        );
      }

      return history == null
          ? button()
          : ListenableBuilder(
              listenable: history, builder: (context, _) => button());
    }

    return [
      if (showSave)
        IconButton(
          key: saveKey,
          tooltip: context.t('common.save'),
          icon: const Icon(AppIcons.save),
          onPressed: onSave,
        ),
      if (undo != null) undoRedo(true),
      if (redo != null) undoRedo(false),
      ...extras,
      more ?? moreButton(context, menu),
    ];
  }

  /// Standart ⋮ düğmesi; boş menüde devre dışı ama yeri korunur (çubuk
  /// editörden editöre kaymasın).
  static Widget moreButton(BuildContext context, List<EditorMenuItem> menu) {
    return PopupMenuButton<String>(
      key: moreKey,
      tooltip: context.t('common.more'),
      icon: const Icon(AppIcons.more),
      enabled: menu.isNotEmpty,
      onSelected: (id) {
        for (final m in menu) {
          if (m.id == id) m.onTap?.call();
        }
      },
      itemBuilder: (_) => [
        for (final m in menu)
          PopupMenuItem<String>(
            value: m.id,
            enabled: m.onTap != null,
            child: Row(
              children: [
                Icon(m.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(m.label)),
              ],
            ),
          ),
      ],
    );
  }
}
