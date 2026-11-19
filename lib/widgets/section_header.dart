import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/skin.dart';

/// Kağıt temasının bölüm başlığı: küçük, aralıklı, BÜYÜK HARF etiket + kalan
/// genişliği dolduran 1px cetvel çizgisi (+ isteğe bağlı sayaç).
///
/// Bölümleri boşlukla değil çizgiyle ayırmak tasarımın taşıyıcı kuralı: yedi
/// bölümlü Ayarlar'da göz nereye bakacağını çizgiden buluyor, boşluktan değil.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Başlığın sağında görünen sayaç (araç sayısı, dosya sayısı…). Boşsa
  /// çizgi kenara kadar uzar.
  final String? count;

  /// Sayacın da sağında duran serbest bileşen (ör. "Tümünü gör" düğmesi).
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, Gap.sm),
  });

  @override
  Widget build(BuildContext context) {
    final faint = Paper.faint(context);
    // **Tasarım aileleri** (2026-11-15, E-yazı panosu): BÜYÜK HARF ve harf
    // aralığı kalkar, başlık cümle düzeninde 17 kalın; çizgi yok.
    if (AppSkinData.of(context).metrics.homeStyle != HomeStyle.classic) {
      final theme = Theme.of(context);
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
              ),
            ),
            if (count != null)
              Text(count!,
                  style: theme.textTheme.bodySmall?.copyWith(color: faint)),
            if (trailing != null) ...[const SizedBox(width: Gap.xs), trailing!],
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            // 2026-11-14 kullanıcı isteği: biraz daha büyük ve kalın
            // (caption + 2 pt, w800, soluk değil ikincil metin rengi).
            style: context.type.caption
                .copyWith(
                  height: 1.2,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
                .apply(fontSizeDelta: 2),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: Gap.sm),
            Text(
              count!,
              style: context.type.caption.copyWith(
                letterSpacing: .5,
                color: faint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: Gap.xs), trailing!],
        ],
      ),
    );
  }
}

/// Kağıt temasının "kurşun kalem" metni: yol, boyut, zaman damgası.
/// Rakamlar sabit genişlikte (tabular) — alt alta gelen boyutlar hizalı durur.
class MonoText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final int? maxLines;
  final TextOverflow overflow;

  const MonoText(
    this.text, {
    super.key,
    this.size = 11,
    this.color,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          fontFamily: AppFonts.of(context).mono,
          fontSize: size,
          height: 1.35,
          color: color ?? Paper.faint(context),
        ),
      );
}
