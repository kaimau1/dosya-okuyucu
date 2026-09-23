import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

/// Belge ekranlarının **ortak arama çubuğu** (PDF/metin, Word, Slayt, Excel).
///
/// 2026-09-23 tasarım turu: dört ekranın dört ayrı arama satırı vardı —
/// kimi çerçeveli kutu, kimi çizgisiz düz alan, sayaç kimi yerde sağda düz
/// metin. Artık hepsi aynı: yuvarlak (hap) arama alanı, sayaç alanın İÇİNDE
/// küçük bir rozet, önceki/sonraki yanında, en sağda kapat. Kullanıcı bir
/// kez öğrenir, dört belgede de bulur.
///
/// [leading]/[trailing] ekrana özgü ek düğmeler (değiştir, sayfaya git…).
class DocFindBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  /// Sayaç metni ("3/12", "Sonuç yok"). Boşsa rozet çizilmez.
  final String countLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onClose;
  final List<Widget> leading;
  final List<Widget> trailing;
  final bool autofocus;
  final FocusNode? focusNode;

  const DocFindBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.countLabel,
    this.onChanged,
    this.onSubmitted,
    this.onPrev,
    this.onNext,
    this.onClose,
    this.leading = const [],
    this.trailing = const [],
    this.autofocus = true,
    this.focusNode,
  });

  /// Arama/değiştir alanlarının ortak süslemesi (değiştir satırı da bunu
  /// kullanır ki iki alan aynı aileden görünsün).
  static InputDecoration decoration(
    BuildContext context, {
    required String hint,
    IconData icon = Icons.search,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      border: pill,
      enabledBorder: pill,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCount = countLabel.isNotEmpty;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: [
            ...leading,
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                decoration: decoration(
                  context,
                  hint: hint,
                  suffix: hasCount
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              countLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: context.t('common.previous'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: onPrev,
            ),
            IconButton(
              tooltip: context.t('common.next'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: onNext,
            ),
            ...trailing,
            if (onClose != null)
              IconButton(
                tooltip: context.t('common.close'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}
