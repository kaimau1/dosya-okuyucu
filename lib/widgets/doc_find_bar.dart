import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';

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
    IconData icon = AppIcons.search,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.65),
      ),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintText: hint,
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, end: 4),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.65),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      border: pill,
      enabledBorder: pill,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: scheme.primary, width: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCount = countLabel.isNotEmpty;
    final isEmptyHit = hasCount &&
        (countLabel.startsWith('0/') || (onPrev == null && onNext == null));
    final btnStyle = IconButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
      foregroundColor: scheme.onSurface,
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.34),
      disabledBackgroundColor: Colors.transparent,
      shape: const CircleBorder(),
      visualDensity: VisualDensity.compact,
    );
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 6, 7),
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
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: ShapeDecoration(
                                color: isEmptyHit
                                    ? scheme.errorContainer
                                    : scheme.primaryContainer,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                countLabel,
                                style: context.type.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isEmptyHit
                                      ? scheme.onErrorContainer
                                      : scheme.onPrimaryContainer,
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: context.t('common.previous'),
                style: btnStyle,
                icon: const Icon(AppIcons.keyboardArrowUp, size: 20),
                onPressed: onPrev,
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: context.t('common.next'),
                style: btnStyle,
                icon: const Icon(AppIcons.keyboardArrowDown, size: 20),
                onPressed: onNext,
              ),
              ...trailing,
              if (onClose != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  tooltip: context.t('common.close'),
                  style: btnStyle,
                  icon: const Icon(AppIcons.close, size: 19),
                  onPressed: onClose,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
