part of '../analysis_screen.dart';


/// Doluluk çubuğunun bir dilimi (tür rengi + bayt).
class _Slice {
  final int bytes;
  final Color color;

  /// Lejantta yazan ad ("Videolar", "Sistem ve diğer").
  final String label;
  const _Slice({required this.bytes, required this.color, this.label = ''});
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
  final TrendDelta? trend;

  const _VolumeCard({
    required this.volume,
    this.slices = const [],
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
                _SliceLegend(slices: slices),
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
  const _SliceLegend({required this.slices});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    // Taranan türler zaten büyükten küçüğe; "diğer" en sonda kalsın diye
    // yeniden sıralanmaz, yalnız kırpılır.
    final shown =
        slices.length <= 6 ? slices : [...slices.take(5), slices.last];
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.xs,
      children: [
        for (final s in shown)
          Row(
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
              Text('${s.label} ${FsPaths.humanSize(s.bytes)}', style: small),
            ],
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.control),
      child: SizedBox(
        height: 14,
        child: slices.isEmpty || capacity <= 0
            ? LinearProgressIndicator(
                value: fraction.clamp(0, 1).toDouble(),
                minHeight: 14,
                backgroundColor: track,
              )
            // **`flex` tam sayı olmak zorunda:** oranları doğrudan piksele
            // çevirmek (elle genişlik) kayan nokta artığı yüzünden
            // "overflowed by 0.0001 pixels" riski taşıyor (aynı ders
            // `photos_screen`de düşüldü). Onbinde bir çözünürlükte tam sayı
            // paylar kullanılıyor; bölüştürmeyi `Row`un kendisi yapıyor.
            : Row(
                children: [
                  for (final s in slices)
                    if ((s.bytes * 10000 ~/ capacity) > 0)
                      Expanded(
                        flex: s.bytes * 10000 ~/ capacity,
                        child: ColoredBox(color: s.color),
                      ),
                  // Boş alan payı — hiç kalmadıysa çizilmez.
                  if (10000 - _usedFlex > 0)
                    Expanded(
                      flex: 10000 - _usedFlex,
                      child: ColoredBox(color: track),
                    ),
                ],
              ),
      ),
    );
  }

  int get _usedFlex {
    var total = 0;
    for (final s in slices) {
      final f = s.bytes * 10000 ~/ capacity;
      if (f > 0) total += f;
    }
    return total > 10000 ? 10000 : total;
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
        Icon(grew ? Icons.trending_up : Icons.trending_down,
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
                  // Açıklama TEK satır: üç kartın her birinde iki satır
                  // dolanan bu metinler ekranın yarısını yiyordu.
                  Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Paper.faint(context)),
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
                  Icon(Icons.chevron_right,
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
