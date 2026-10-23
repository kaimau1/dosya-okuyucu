import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_dialog.dart';

/// Eylem levhasındaki tek eylem.
class AppAction<T> {
  final T value;
  final IconData icon;
  final String label;

  /// İkinci satır — eylemin NE yapacağı belli değilse ("kopyası Önemli
  /// Dosyalar'a gider"). Kısa tutulur; çoğu eylemde yok.
  final String? hint;

  /// Yıkıcı (sil, kalıcı sil) — hata rengiyle çizilir.
  final bool destructive;

  /// Vurgulu (AI, öneri) — ana renkle çizilir.
  final bool accent;

  const AppAction({
    required this.value,
    required this.icon,
    required this.label,
    this.hint,
    this.destructive = false,
    this.accent = false,
  });
}

/// Başlıklı eylem grubu ("Düzenle", "Kopyala / Taşı", "Bilgi").
class AppActionGroup<T> {
  final String? title;
  final List<AppAction<T>> actions;
  const AppActionGroup({this.title, required this.actions});
}

/// **Ortak eylem levhası** (2026-10-23, kullanıcı ekran görüntüsüyle: *"bu
/// tür menüler UI olarak baştan tasarlanmalı, hepsi"*).
///
/// Eski "Daha fazla" menüsü ekranın ortasında açılan, simgesiz, gruplanmamış
/// on satırlık bir metin listesiydi: "Önemli dosyalara kopyala" ile "Panoya
/// kes" aynı ağırlıkta alt alta duruyor, menü seçili görselin üstünü
/// kapatıyordu. Levha:
/// - alttan açılır (başparmak erişimi), başlıkta NE için açıldığı yazar
///   ("3 öğe seçildi");
/// - eylemler **gruplu** ve her biri renkli bir simge kabıyla;
/// - yıkıcı eylem kırmızı, AI/öneri eylemi ana renkte;
/// - uzun listede kaydırılır, kısa listede içeriği kadar yer kaplar.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required List<AppActionGroup<T>> groups,
}) {
  final visible = [
    for (final g in groups)
      if (g.actions.isNotEmpty) g,
  ];
  return showAppSheet<T>(
    context,
    scrollable: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
      return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(24, 0, 24, Gap.xs),
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              if (subtitle != null)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(24, 0, 24, Gap.xs),
                  child: Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Paper.faint(ctx))),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  children: [
                    for (var g = 0; g < visible.length; g++) ...[
                      if (visible[g].title != null)
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              24, g == 0 ? Gap.sm : Gap.md, 24, Gap.xs),
                          child: Text(
                            visible[g].title!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                      else if (g > 0)
                        const Divider(height: Gap.md, indent: 24, endIndent: 24),
                      for (final a in visible[g].actions)
                        _ActionTile(
                          action: a,
                          onTap: () => Navigator.of(ctx).pop(a.value),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
      );
    },
  );
}

class _ActionTile<T> extends StatelessWidget {
  final AppAction<T> action;
  final VoidCallback onTap;
  const _ActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = action.destructive
        ? scheme.error
        : (action.accent ? scheme.primary : scheme.onSurfaceVariant);
    final bg = action.destructive
        ? scheme.errorContainer.withValues(alpha: 0.6)
        : (action.accent
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md + 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Icon(action.icon, size: 20, color: color),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: action.destructive ? scheme.error : null,
                    ),
                  ),
                  if (action.hint != null)
                    Text(action.hint!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Paper.faint(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
