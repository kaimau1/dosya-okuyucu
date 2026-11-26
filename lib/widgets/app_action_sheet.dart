import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_dialog.dart';
import 'menu_kit.dart';

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
  final bool proBadge;

  const AppAction({
    required this.value,
    required this.icon,
    required this.label,
    this.hint,
    this.destructive = false,
    this.accent = false,
    this.proBadge = false,
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
  Widget Function(BuildContext context)? headerExtra,
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
      final header = title == null && subtitle == null && headerExtra == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs),
                    child: Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Paper.faint(ctx))),
                  ),
                if (headerExtra != null) headerExtra(ctx),
              ],
            );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
          // Ortak menü dili (2026-10-29) + menü görünümü (2026-11-15):
          // sekmeli/Bento seçimi `MenuSections`ta — dosya levhası ve "Daha
          // fazla" ile aynı (bkz. `menu_kit.dart`).
          child: MenuSections(
            header: header,
            sections: [
              for (final g in visible)
                MenuKitSection(title: g.title, actions: [
                  for (final a in g.actions)
                    MenuKitAction(
                      icon: a.icon,
                      label: a.label,
                      hint: a.hint,
                      proBadge: a.proBadge,
                      tone: a.destructive
                          ? MenuTone.danger
                          : (a.accent ? MenuTone.accent : MenuTone.neutral),
                      onTap: () => Navigator.of(ctx).pop(a.value),
                    ),
                ]),
            ],
          ),
        ),
      );
    },
  );
}
