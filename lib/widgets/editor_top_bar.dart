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
import '../screens/fm/entry_actions.dart';
import 'pro_gate.dart';

/// ⋮ menüsündeki tek satır.
class EditorMenuItem {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Aç/kapa ayarı ise durumu (ör. gece modu); null = düz işlem.
  final bool? checked;
  final bool proBadge;

  const EditorMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.onTap,
    this.checked,
    this.proBadge = false,
  });
}

abstract final class EditorTopBar {
  /// Yuva anahtarları (testler ve TalkBack sırası için sabit).
  static const saveKey = ValueKey('editor-save');
  static const moreKey = ValueKey('editor-more');

  /// Tüm editör üst çubuklarında tutarlı dairesel stüdyo düğme stili.
  static ButtonStyle iconStyle(
    BuildContext context, {
    bool accent = false,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = accent || selected;
    return IconButton.styleFrom(
      backgroundColor: highlighted
          ? scheme.primaryContainer
          : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
      foregroundColor: highlighted ? scheme.primary : scheme.onSurface,
      disabledBackgroundColor: Colors.transparent,
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.34),
      shape: const CircleBorder(),
      side: highlighted
          ? BorderSide(color: scheme.primary.withValues(alpha: 0.34))
          : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      fixedSize: const Size(38, 38),
      minimumSize: const Size(38, 38),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }

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
    /// Verilirse ⋮ küçük açılır menü DEĞİL, bütün türlerde ortak dosya
    /// levhasını açar (2026-11-15 ortak düzen): üstte taşı/kopyala/yeniden
    /// adlandır/önemli/SİL, altında [menu] [menuTitle] başlığıyla, ayrı renkte.
    String? filePath,
    String? menuTitle,
  }) {
    Widget undoRedo(bool isUndo) {
      Widget button() {
        final cb = (isUndo ? undo : redo)?.call();
        // 2026-11-22 (kullanıcı): yapılacak bir şey yoksa düğme HİÇ görünmez —
        // başlık yer kazanır; yinele ancak geri alındıktan sonra çıkar.
        if (cb == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: IconButton(
            key: isUndo ? undoKey : redoKey,
            tooltip: context.t(isUndo ? 'word.undo' : 'word.redo'),
            icon: Icon(isUndo ? AppIcons.undo : AppIcons.redo, size: 20),
            style: iconStyle(context),
            onPressed: cb,
          ),
        );
      }

      return history == null
          ? button()
          : ListenableBuilder(
              listenable: history, builder: (context, _) => button());
    }

    return [
      if (showSave)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 2),
          child: IconButton(
            key: saveKey,
            tooltip: context.t('common.save'),
            icon: const Icon(AppIcons.save, size: 20),
            style: iconStyle(context, accent: onSave != null),
            onPressed: onSave,
          ),
        ),
      if (undo != null) undoRedo(true),
      if (redo != null) undoRedo(false),
      ...extras,
      more ??
          (filePath == null
              ? moreButton(context, menu)
              : fileMenuButton(context, filePath,
                  title: menuTitle ?? context.t('common.more'), menu: menu)),
    ];
  }

  /// ⋮ → ortak dosya levhası ([showViewerMenu]).
  static Widget fileMenuButton(
    BuildContext context,
    String filePath, {
    required String title,
    List<EditorMenuItem> menu = const [],
  }) {
    return IconButton(
      key: moreKey,
      tooltip: context.t('common.more'),
      icon: const Icon(AppIcons.more, size: 20),
      style: iconStyle(context),
      onPressed: () => showViewerMenu(context, filePath, groups: [
        EntryExtraGroup(title, [
          for (final m in menu)
            EntryExtraAction(
              icon: m.icon,
              label: m.label,
              onTap: m.onTap,
              checked: m.checked,
              proBadge: m.proBadge,
            ),
        ]),
      ]),
    );
  }

  /// Standart ⋮ düğmesi; boş menüde devre dışı ama yeri korunur (çubuk
  /// editörden editöre kaymasın).
  static Widget moreButton(BuildContext context, List<EditorMenuItem> menu) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      key: moreKey,
      tooltip: context.t('common.more'),
      icon: const Icon(AppIcons.more, size: 20),
      style: menu.isNotEmpty
          ? iconStyle(context)
          : IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: scheme.onSurface,
              shape: const CircleBorder(),
              visualDensity: VisualDensity.compact,
            ),
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
                if (m.proBadge) ...[
                  const SizedBox(width: 8),
                  const ProBadge(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
