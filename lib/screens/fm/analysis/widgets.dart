part of '../analysis_screen.dart';


/// Doluluk çubuğunun bir dilimi (tür rengi + bayt).
class _Slice {
  final int bytes;
  final Color color;

  /// Lejantta yazan ad ("Videolar", "Sistem ve diğer").
  final String label;
  final FmCategory? category;
  final bool isApps;
  final bool isOther;

  const _Slice({
    required this.bytes,
    required this.color,
    this.label = '',
    this.category,
    this.isApps = false,
    this.isOther = false,
  });

  bool get interactive => category != null || isApps;
}

/// **Ana bellek kartı** — ekranın ilk gördüğü şey.
///
/// Kullanıcı isteği (2026-08-29, ekran görüntüsü): *"bellek analizi kısmı üst
/// kısım özellikle yılın şeklinde duruyor, daha modern bir tasarıma geçmeli"*.
///
/// **Eski hâl:** başlık, ince bir `LinearProgressIndicator` ve altında tek
/// satır küçük gri yazı ("310 GB / 512 GB kullanıldı (%60) · 202 GB boş").
/// Ekranın en önemli sayısı — **ne kadar yerim kaldı** — 12 puntoluk gri bir
/// satırın içinde, üç ayrı sayının arasında kayboluyordu.
///
/// **Yeni hâl:** boş alan büyük puntoyla manşet; kullanılan/toplam onun altında
/// ikincil; sağ üstte yüzde rozeti; çubuk **tür renkleriyle dilimli** (bkz.
/// [_Slice]) ve eğilim satırı ("Son 7 günde −450 MB") aynı kartın içinde.
class _VolumeCard extends StatelessWidget {
  final StorageVolume volume;
  final List<_Slice> slices;
  final ValueChanged<_Slice>? onSliceTap;
  final TrendDelta? trend;

  const _VolumeCard({
    required this.volume,
    this.slices = const [],
    this.onSliceTap,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (volume.usedFraction * 100).round();
    // Rozet doluluk arttıkça uyarıya döner: %90 üstünde kırmızı, %75 üstünde
    // turuncu. Aynı gri rozet her durumda "sorun yok" der.
    final warn = percent >= 90
        ? scheme.error
        : (percent >= 75 ? const Color(0xFFE65100) : scheme.primary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(volumeIcon(volume),
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(volume.displayLabel(context.t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium),
                ),
                if (volume.hasStats)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: warn.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Text('%$percent',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: warn, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (!volume.hasStats)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(context.t('ana.usage_unreadable'),
                    style: theme.textTheme.bodySmall),
              )
            else ...[
              const SizedBox(height: Gap.md),
              // Manşet: **kalan yer**. Kapasite ONDALIK gösterilir (512 GB) —
              // telefonun kutusunda yazan sayı bu. Dosya boyutları 1024
              // tabanında kalır.
              Text(
                context.t('an.free_headline',
                    {'size': FsPaths.humanCapacity(volume.freeBytes)}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                context.t('an.used_of', {
                  'used': FsPaths.humanCapacity(volume.usedBytes),
                  'total': FsPaths.humanCapacity(volume.capacityBytes),
                }),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Gap.md),
              _CapacityBar(
                fraction: volume.usedFraction,
                capacity: volume.capacityBytes,
                slices: slices,
              ),
              // **Lejant** — renkli dilimler neyin ne olduğunu söylemiyordu;
              // özellikle gri "sistem ve diğer" dilimi hiçbir yerde
              // açıklanmıyordu ve kullanıcı onu "boş alan" sanabiliyordu.
              if (slices.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                _SliceLegend(slices: slices, onTap: onSliceTap),
              ],
            ],
            if (trend?.hasData ?? false) ...[
              const SizedBox(height: Gap.md),
              const Divider(height: 1),
              const SizedBox(height: Gap.sm),
              _TrendRow(trend: trend!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Doluluk çubuğunun lejantı: en büyük dilimler (en çok 6) + boyutları.
class _SliceLegend extends StatelessWidget {
  final List<_Slice> slices;
  final ValueChanged<_Slice>? onTap;
  const _SliceLegend({required this.slices, this.onTap});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    // Taranan türler + uygulamalar büyükten küçüğe; "Diğer" varsa sonda kalır.
    final shown = slices.length <= 6
        ? slices
        : (slices.last.isOther
            ? [...slices.take(5), slices.last]
            : slices.take(6).toList());
    return Wrap(
      spacing: Gap.sm + 2,
      runSpacing: Gap.xs,
      children: [
        for (final s in shown)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.control),
            onTap: s.interactive && onTap != null ? () => onTap!(s) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: Gap.xs + 2),
                  Text('${s.label} ${FsPaths.humanSize(s.bytes)}',
                      style: small),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dilimli doluluk çubuğu. Dilim yoksa (SD kart, tarama yapılmamış) düz
/// kullanılan/boş çubuğuna düşer — uydurma dilim çizilmez.
class _CapacityBar extends StatelessWidget {
  final double fraction;
  final int capacity;
  final List<_Slice> slices;

  const _CapacityBar({
    required this.fraction,
    required this.capacity,
    required this.slices,
  });

  List<int> _computeFlexes() {
    if (slices.isEmpty || capacity <= 0) return const [];
    final totalSliceBytes =
        slices.fold<int>(0, (sum, s) => sum + (s.bytes > 0 ? s.bytes : 0));
    if (totalSliceBytes <= 0) return const [];
    final targetUsed = (fraction.clamp(0.0, 1.0) * 10000).round();
    final scaleToTarget =
        targetUsed > 0 && (totalSliceBytes * 10000 / capacity) > targetUsed;
    final out = List<int>.filled(slices.length, 0);
    var sum = 0;
    for (var i = 0; i < slices.length; i++) {
      final b = slices[i].bytes;
      if (b <= 0) continue;
      final raw = scaleToTarget
          ? (b * targetUsed / totalSliceBytes).round()
          : (b * 10000 / capacity).round();
      final flex = raw < 1 ? 1 : raw;
      out[i] = flex;
      sum += flex;
    }
    final maxSum = scaleToTarget ? targetUsed : 10000;
    if (sum > maxSum && sum > 0) {
      var excess = sum - maxSum;
      while (excess > 0) {
        var maxIdx = -1;
        for (var i = 0; i < out.length; i++) {
          if (out[i] > 1 && (maxIdx < 0 || out[i] > out[maxIdx])) maxIdx = i;
        }
        if (maxIdx < 0) break;
        final take = excess < (out[maxIdx] - 1) ? excess : (out[maxIdx] - 1);
        out[maxIdx] -= take;
        excess -= take;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.surfaceContainerHighest;
    final flexes = _computeFlexes();
    final usedFlex = flexes.fold<int>(0, (a, b) => a + b).clamp(0, 10000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.control),
      child: SizedBox(
        height: 14,
        child: flexes.isEmpty
            ? LinearProgressIndicator(
                value: fraction.clamp(0, 1).toDouble(),
                minHeight: 14,
                backgroundColor: track,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < slices.length; i++)
                    if (flexes[i] > 0)
                      Expanded(
                        flex: flexes[i],
                        child: ColoredBox(color: slices[i].color),
                      ),
                  // Boş alan payı — hiç kalmadıysa çizilmez.
                  if (10000 - usedFlex > 0)
                    Expanded(
                      flex: 10000 - usedFlex,
                      child: ColoredBox(color: track),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Depolama eğilimi satırı ("Son 7 günde −450 MB · en çok büyüyen: …").
/// Veri yoksa hiç çizilmez — "0 B değişti" demek bilgi değil gürültüdür.
class _TrendRow extends StatelessWidget {
  final TrendDelta trend;
  const _TrendRow({required this.trend});

  @override
  Widget build(BuildContext context) {
    final grew = trend.deltaBytes > 0;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(grew ? AppIcons.trendingUp : AppIcons.trendingDown,
            size: 18, color: grew ? scheme.error : scheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.t('an.trend_days', {'n': trend.days})}'
                '${grew ? "+" : "−"}'
                '${FsPaths.humanSize(trend.deltaBytes.abs())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (trend.topCategory != null && trend.topCategoryBytes > 0)
                Text(
                  '${context.t('an.top_growing', {
                        'category': context.t(trend.topCategory!.labelKey),
                      })}'
                  '(+${FsPaths.humanSize(trend.topCategoryBytes)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolsGroupHeader extends StatelessWidget {
  final String title;
  const _ToolsGroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsetsDirectional.fromSTEB(
          Gap.md, Gap.sm + 2, Gap.md, Gap.xs),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Analiz araçlarının satırı (Yer aç · Yinelenenler · Klasör haritası).
/// Üç ayrı kart yerine tek kartın içinde, çizgiyle ayrılmış satırlar.
class _ToolRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String note;
  final VoidCallback onTap;

  const _ToolRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(AppIcons.chevron, color: Paper.faint(context)),
          ],
        ),
      ),
    );
  }
}

/// "Türlere göre" listesinin bir satırı: tür adı, boyut, oran çubuğu.
///
/// Satırın tamamı bir DÜĞME (kendi sayfasını açar), o yüzden sağ uçta bir
/// `chevron` var: eskiden satır yalnız aşağıdaki listeyi süzüyordu ve
/// dokunulabilir olduğu hiçbir yerden anlaşılmıyordu.
class _CategoryBar extends StatelessWidget {
  final String label;

  /// Satırın başındaki tür simgesi. Kategori kutularıyla aynı glif ve renk —
  /// aynı şeyin iki ekranda farklı görünmesi kullanıcıyı ikinci kez
  /// öğrenmeye zorlar.
  final IconData? icon;

  final int bytes;

  /// Dosya sayısı. Uygulamalar satırında anlamsız (bkz. [countLabel]).
  final int? count;

  /// Sayı yerine yazılacak metin (uygulamalar satırı en büyük üç uygulamayı
  /// yazıyor).
  final String? countLabel;

  /// Çubuğun altındaki ek satır ("bunun 7,3 GB kadarı önbellek…").
  final String? detail;

  final double fraction;
  final Color color;
  final VoidCallback? onTap;

  const _CategoryBar({
    required this.label,
    required this.bytes,
    required this.fraction,
    required this.color,
    this.icon,
    this.count,
    this.countLabel,
    this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  // Simge renkli bir kutucukta: çıplak 18 dp glif çubuğun
                  // renginden kopuk duruyordu, satırın başı zayıftı.
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: Gap.sm),
                ],
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                // **Boyut asıl sayı:** eskiden dosya sayısıyla aynı soluk
                // stilde, tek bir gri metindi. Boyut koyu, sayı soluk.
                Text(FsPaths.humanSize(bytes),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (count != null)
                  Text(' · $count',
                      style: small?.copyWith(color: Paper.faint(context))),
                if (onTap != null)
                  Icon(AppIcons.chevron,
                      size: 18, color: Paper.faint(context)),
              ],
            ),
            const SizedBox(height: Gap.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.control),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.02, 1).toDouble(),
                minHeight: 6,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            if (countLabel != null || detail != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  [countLabel, detail].whereType<String>().join(' — '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small?.copyWith(color: Paper.faint(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
