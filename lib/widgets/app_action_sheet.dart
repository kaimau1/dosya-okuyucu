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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, Gap.sm),
                  children: [
                    // Ortak menü dili (2026-10-29): başlık + kart + simge
                    // kutusu — dosya içi "Daha fazla" ve uzun basma
                    // menüsüyle aynı (bkz. `menu_kit.dart`).
                    for (var g = 0; g < visible.length; g++) ...[
                      if (visible[g].title != null)
                        MenuGroupTitle(visible[g].title!)
                      else
                        const SizedBox(height: Gap.sm),
                      MenuGroupCard(
                        child: Column(
                          children: [
                            for (final a in visible[g].actions)
                              _ActionTile(
                                action: a,
                                onTap: () => Navigator.of(ctx).pop(a.value),
                              ),
                          ],
                        ),
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
  Widget build(BuildContext context) => MenuRow(
        icon: action.icon,
        label: action.label,
        hint: action.hint,
        onTap: onTap,
        tone: action.destructive
            ? MenuTone.danger
            : (action.accent ? MenuTone.accent : MenuTone.neutral),
      );
}
