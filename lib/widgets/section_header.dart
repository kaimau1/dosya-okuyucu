import 'package:flutter/material.dart';

import '../core/theme.dart';

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
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              letterSpacing: 1.1, // ~.1em
              fontWeight: FontWeight.w600,
              color: faint,
            ),
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
              style: TextStyle(
                fontSize: 11,
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
