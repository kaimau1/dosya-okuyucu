part of '../dashboard_screen.dart';



/// **Klasör izniyle eklenen bellek kartı.**
///
/// Yol yoluyla görünen birimlerin kartında doluluk halkası var; burada YOK ve
/// olamaz: SAF bir ağaç verir, aygıtın kapasitesini vermez. Uydurma bir halka
/// çizmektense hiç çizmemek dürüst olan.
class _SafCard extends StatelessWidget {
  final SafRoot root;
  final VoidCallback onTap;

  const _SafCard({required this.root, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(AppIcons.external, color: scheme.onSurfaceVariant),
        ),
        title: Text(root.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.t('saf.granted')),
        trailing: const Icon(AppIcons.chevron),
      ),
    );
  }
}

/// **Ham USB kartı** — Android'in bağlamadığı ama sürebildiğimiz bellek.
///
/// Doluluk halkası YOK ve olamaz: kapasiteyi ancak aygıtı açtıktan sonra
/// öğreniyoruz. Uydurma bir halka çizmektense hiç çizmemek dürüst olan.
class _RawUsbCard extends StatelessWidget {
  final UsbDevice device;
  final VoidCallback onTap;

  const _RawUsbCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.tertiaryContainer,
          child: Icon(AppIcons.external, color: scheme.onTertiaryContainer),
        ),
        title: Text(device.displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.t('usb.open_raw')),
        trailing: const Icon(AppIcons.chevron),
      ),
    );
  }
}

/// Birimin kategori payları (ana bellek kartı ve bellek panosu ortak).
List<({Color color, String label, int bytes})> _volumeBreakdown(
  BuildContext context, StorageVolume volume, StorageIndex index) {
  if (!volume.isPrimary) {
    return [
      (
        color: FmColors.other,
        label: context.t('fm.used'),
        bytes: volume.usedBytes,
      ),
    ];
  }
  final image = index.stat(FmCategory.image).bytes;
  final video = index.stat(FmCategory.video).bytes;
  final document = index.stat(FmCategory.document).bytes;
  final audio = index.stat(FmCategory.audio).bytes;
  final rest = volume.usedBytes - image - video - document - audio;
  return [
    (
      color: FmColors.image,
      label: FmCategory.image.label,
      bytes: image,
    ),
    (
      color: FmColors.video,
      label: FmCategory.video.label,
      bytes: video,
    ),
    (
      color: OfficeColors.neutral,
      label: FmCategory.document.label,
      bytes: document,
    ),
    (
      color: FmColors.audio,
      label: FmCategory.audio.label,
      bytes: audio,
    ),
    (
      color: FmColors.other,
      label: FmCategory.other.label,
      bytes: rest < 0 ? 0 : rest,
    ),
  ];
}


/// **Bellek panosu** — panonun en üstü (2026-10-18, kullanıcı ekran
/// görüntüsüyle: *"ana sayfada üst alandaki bellek analizi ve ana bellek
/// butonlarını sevmiyorum, tamamen baştan tasarla; yeri, konumu, şekli,
/// boyutu tamamen serbest"*).
///
/// Eskiden iki ayrı kutu yan yanaydı: solda bilgi kartı (küçük halka + iki
/// satır sayı), sağda yalnız "Bellek Analizi" yazan bir düğme. İkisi
/// `IntrinsicHeight` ile aynı boya zorlanıyordu; sağ kutu dar olduğu için
/// yazı kırılıyor, sol kutu sıkışıyor, kullanıcının asıl sorusu ("ne kadar
/// yerim kaldı?") küçük gri bir satırda kalıyordu.
///
/// Şimdi tek, tam genişlik kart:
/// - **Büyük sayı = boş yer** ("196 GB boş") — panoya bakan kişinin sorusu.
/// - Doluluk yüzdesi halkanın ORTASINDA; halka kategori renkleriyle dilimli.
/// - Altında kalın, yuvarlak uçlu kategori çubuğu.
/// - Altta üç eşit eylem: **Göz at · Analiz · Yer aç** — bellekle ilgili her
///   şey bir dokunuş uzakta, ayrı bir kutu aramaya gerek yok. Bellek %90'ı
///   geçince "Yer aç" vurgulanır (dolu telefonda asıl yapılacak iş o).
class _StorageHero extends StatelessWidget {
  final StorageVolume volume;
  final StorageIndex index;
  final VoidCallback onBrowse;
  final VoidCallback onAnalysis;
  final VoidCallback onFreeSpace;
  final VoidCallback? onLongPress;

  const _StorageHero({
    required this.volume,
    required this.index,
    required this.onBrowse,
    required this.onAnalysis,
    required this.onFreeSpace,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = context.fmCardRadius;
    final has = volume.hasStats;
    final capacity = volume.capacityBytes <= 0 ? 1 : volume.capacityBytes;
    final ratio = has ? (volume.usedBytes / capacity).clamp(0.0, 1.0) : 0.0;
    final full = ratio >= 0.9;
    final parts = has
        ? _volumeBreakdown(context, volume, index)
            .where((p) => p.bytes > 0)
            .toList()
        : const <({Color color, String label, int bytes})>[];
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: scheme.outlineVariant),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.surfaceContainerLow],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onBrowse,
              onLongPress: onLongPress,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(radius)),
              child: Padding(
                // **Kompakt** (2026-10-23, kullanıcı: *"üst alan ~%25 daha
                // alçak olmalı"*): halka 68 → 52, büyük sayı headlineSmall →
                // titleLarge, iç boşluklar ve eylem hapları inceldi; kazanılan
                // yer akıllı bildirim alanına ([SmartInbox]) gitti.
                padding: const EdgeInsetsDirectional.fromSTEB(
                    Gap.md, Gap.sm + 2, Gap.sm, Gap.xs + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size.square(52),
                                painter: _RingPainter(
                                  slices: [
                                    for (final p in parts)
                                      (color: p.color, bytes: p.bytes),
                                  ],
                                  total: has ? volume.capacityBytes : 1,
                                  trackColor: scheme.surfaceContainerHighest,
                                  strokeWidth: 5.5,
                                ),
                              ),
                              has
                                  ? Text(
                                      context.t('fm.hero_percent',
                                          {'n': (ratio * 100).round()}),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: full
                                            ? scheme.error
                                            : scheme.onSurface,
                                      ),
                                    )
                                  : Icon(volumeIcon(volume),
                                      size: 20,
                                      color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(volumeIcon(volume),
                                      size: 16,
                                      color: scheme.onSurfaceVariant),
                                  const SizedBox(width: Gap.xs),
                                  Flexible(
                                    child: Text(
                                      volume.displayLabel(context.t),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                              color:
                                                  scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                has
                                    ? context.t('fm.free_bytes', {
                                        'v': FsPaths.humanCapacity(
                                            volume.freeBytes),
                                      })
                                    : volume.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: (has
                                        ? theme.textTheme.titleLarge
                                        : theme.textTheme.bodySmall)
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (has)
                                Text(
                                  context.t('fm.hero_used', {
                                    'used': FsPaths.humanCapacity(
                                        volume.usedBytes),
                                    'total': FsPaths.humanCapacity(
                                        volume.capacityBytes),
                                  }),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: Paper.faint(context)),
                                ),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevron,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                    if (has) ...[
                      const SizedBox(height: Gap.sm),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 6,
                            child: Row(
                              children: [
                                for (final part in parts)
                                  Expanded(
                                    flex: part.bytes,
                                    child: ColoredBox(color: part.color),
                                  ),
                                if (volume.freeBytes > 0)
                                  Expanded(
                                    flex: volume.freeBytes,
                                    child: ColoredBox(
                                        color:
                                            scheme.surfaceContainerHighest),
                                  ),
                                if (parts.isEmpty && volume.freeBytes <= 0)
                                  Expanded(
                                    child: ColoredBox(
                                        color: scheme.outlineVariant),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.xs + 2),
              child: Row(
                children: [
                  Expanded(
                    child: _HeroAction(
                      icon: AppIcons.emptyFolder,
                      label: context.t('fm.hero_browse'),
                      onTap: onBrowse,
                    ),
                  ),
                  const SizedBox(width: Gap.xs + 2),
                  Expanded(
                    child: _HeroAction(
                      icon: AppIcons.donutLarge,
                      label: context.t('fm.hero_analysis'),
                      onTap: onAnalysis,
                    ),
                  ),
                  const SizedBox(width: Gap.xs + 2),
                  Expanded(
                    child: _HeroAction(
                      icon: AppIcons.cleanEmpty,
                      label: context.t('fm.free_space'),
                      onTap: onFreeSpace,
                      highlight: full,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bellek panosunun alt sırasındaki eylem hapı.
class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = AppSkinData.of(context).metrics.radiusControl;
    final fg = highlight ? scheme.onPrimary : scheme.primary;
    return Material(
      color: highlight
          ? scheme.primary
          : scheme.surface.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: highlight ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Tasarım ailelerinin bellek kartı** (2026-11-15, `docs/design/ana_ekran/`).
///
/// - A · Sakin: beyaz kart, büyük "198 GB boş", sağ üstte "Ana bellek ›",
///   tek renk doluluk çubuğu, üç açık tonlu düğme.
/// - B · Bento: vurgu renginde dolu kart, beyaz yazı, çerçeveli düğmeler.
/// - C · Koyu başlık: kenardan kenara vurgu alanı (arama çubuğuyla birleşik),
///   solda yüzde halkası, altında içerik levhasının yuvarlak üst kenarı.
class _StyledHero extends StatelessWidget {
  final HomeStyle style;
  final StorageVolume volume;
  final VoidCallback onBrowse;
  final VoidCallback onAnalysis;
  final VoidCallback onFreeSpace;
  final VoidCallback? onLongPress;

  const _StyledHero({
    required this.style,
    required this.volume,
    required this.onBrowse,
    required this.onAnalysis,
    required this.onFreeSpace,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = context.fmCardRadius;
    final has = volume.hasStats;
    final capacity = volume.capacityBytes <= 0 ? 1 : volume.capacityBytes;
    final ratio = has ? (volume.usedBytes / capacity).clamp(0.0, 1.0) : 0.0;
    final filled = style != HomeStyle.calm;
    final fg = filled ? scheme.onPrimary : scheme.onSurface;
    final soft = filled
        ? scheme.onPrimary.withValues(alpha: 0.82)
        : scheme.onSurfaceVariant;
    final free = Text(
      has
          ? context.t('fm.free_bytes',
              {'v': FsPaths.humanCapacity(volume.freeBytes)})
          : volume.displayLabel(context.t),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // 2026-11-15 (kullanıcı: bellek kartı %20 alçalsın, düğmelerle
      // birlikte): headlineMedium → headlineSmall, iç boşluklar ve düğme
      // yüksekliği orantılı küçüldü (~175 → ~140 dp).
      style: theme.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, color: fg, height: 1.1),
    );
    final usedText = has
        ? context.t('home.used_short', {
            'used': FsPaths.humanCapacity(volume.usedBytes),
            'total': FsPaths.humanCapacity(volume.capacityBytes),
          })
        : '';
    final used = has
        ? Text(
            usedText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: soft),
          )
        : const SizedBox.shrink();
    final volumeLink = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (filled) ...[
          Icon(volumeIcon(volume), size: 18, color: fg),
          const SizedBox(width: Gap.xs),
        ],
        Text(volume.displayLabel(context.t),
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: filled ? fg : scheme.primary)),
        if (!filled) Icon(AppIcons.chevron, size: 18, color: scheme.primary),
      ],
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        color: filled ? scheme.onPrimary : scheme.primary,
        backgroundColor: filled
            ? scheme.onPrimary.withValues(alpha: 0.28)
            : scheme.surfaceContainerHighest,
      ),
    );
    Widget action(String key, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs / 2),
            child: filled
                ? OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onPrimary,
                      side: BorderSide(
                          color: scheme.onPrimary.withValues(alpha: 0.7)),
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                    ),
                    child: Text(context.t(key),
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )
                : FilledButton.tonal(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSkinData.of(context).metrics.radiusControl)),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                    ),
                    child: Text(context.t(key),
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        );
    final actions = Row(children: [
      action('home.browse', onBrowse),
      action('home.analysis', onAnalysis),
      action('home.free_space', onFreeSpace),
    ]);

    if (style == HomeStyle.band) {
      final content = Padding(
        padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onBrowse,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(radius),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 6,
                            color: scheme.onPrimary,
                            backgroundColor:
                                scheme.onPrimary.withValues(alpha: 0.28),
                          ),
                        ),
                        Text(
                          context.t('fm.hero_percent',
                              {'n': (ratio * 100).round()}),
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: fg, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        free,
                        if (has)
                          Text(
                            '$usedText · '
                            '${volume.displayLabel(context.t)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: soft),
                          ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevron, color: fg),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            actions,
          ],
        ),
      );
      return CustomPaint(
        painter: _BleedPainter(
          color: scheme.primary,
          sheet: theme.scaffoldBackgroundColor,
          radius: AppSkinData.of(context).metrics.radiusSheet,
        ),
        child: content,
      );
    }

    return Material(
      color: filled ? scheme.primary : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: filled
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBrowse,
        onLongPress: onLongPress,
        child: Padding(
          // %5 alçak (2026-11-15): dikey boşluklar 12 → 9, ara 10 → 9.
          padding: const EdgeInsets.fromLTRB(
              Gap.md + 4, Gap.sm + 1, Gap.md + 4, Gap.sm + 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filled) ...[
                Row(children: [
                  Expanded(child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: volumeLink)),
                  Icon(AppIcons.chevron, color: fg),
                ]),
                const SizedBox(height: Gap.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: free),
                    used,
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: free),
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: volumeLink,
                    ),
                  ],
                ),
                used,
              ],
              const SizedBox(height: Gap.sm + 1),
              bar,
              const SizedBox(height: Gap.sm + 1),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// C · Koyu başlık: kartın arkasına kenardan kenara vurgu alanı ve altına
/// içerik levhasının yuvarlak üst kenarını boyar. Liste görünüm alanı yan
/// boşlukları da kapsadığı için kart sınırı dışına boyamak görünür; yerleşim
/// değişmez (yalnız boyama).
class _BleedPainter extends CustomPainter {
  final Color color;
  final Color sheet;
  final double radius;
  const _BleedPainter(
      {required this.color, required this.sheet, required this.radius});

  static const _side = Gap.md;

  @override
  void paint(Canvas canvas, Size size) {
    final left = -_side;
    final right = size.width + _side;
    canvas.drawRect(
      Rect.fromLTRB(left, -600, right, size.height + radius),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(left, size.height, right, size.height + radius * 2),
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
      Paint()..color = sheet,
    );
  }

  @override
  bool shouldRepaint(_BleedPainter old) =>
      old.color != color || old.sheet != sheet || old.radius != radius;
}
