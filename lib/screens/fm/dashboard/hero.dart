part of '../dashboard_screen.dart';


/// Ana sayfadan klasör oluşturma diyaloğu: ad + konum.
class _NewFolderDialog extends StatefulWidget {
  final List<({String label, String path})> locations;
  const _NewFolderDialog({required this.locations});

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController();
  late String _parent = widget.locations.first.path;

  @override
  void initState() {
    super.initState();
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, parent: _parent));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.t('fm.new_folder')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: context.t('fm.folder_name')),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.md),
            DropdownButtonFormField<String>(
              initialValue: _parent,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: context.t('common.location')),
              items: [
                for (final l in widget.locations)
                  DropdownMenuItem(
                    value: l.path,
                    child: Text(l.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _parent = v ?? _parent),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: _submit, child: Text(context.t('fm.create'))),
        ],
      );
}

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
                padding:
                    const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.md, Gap.sm, Gap.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size.square(68),
                                painter: _RingPainter(
                                  slices: [
                                    for (final p in parts)
                                      (color: p.color, bytes: p.bytes),
                                  ],
                                  total: has ? volume.capacityBytes : 1,
                                  trackColor: scheme.surfaceContainerHighest,
                                  strokeWidth: 7,
                                ),
                              ),
                              has
                                  ? Text(
                                      context.t('fm.hero_percent',
                                          {'n': (ratio * 100).round()}),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: full
                                            ? scheme.error
                                            : scheme.onSurface,
                                      ),
                                    )
                                  : Icon(volumeIcon(volume),
                                      size: 24,
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
                              const SizedBox(height: 2),
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
                                        ? theme.textTheme.headlineSmall
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
                      const SizedBox(height: Gap.sm + 4),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
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
              padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.sm),
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
                      icon: Icons.donut_large_rounded,
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
