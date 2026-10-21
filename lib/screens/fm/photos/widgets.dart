part of '../photos_screen.dart';


/// Yakınlaştırma geçişi sırasında satırı parmakların ortası etrafında ölçekler.
///
/// Tüm ekran değil yalnız SATIRLAR ölçeklenir: üst çubuk ve süzgeç şeridi
/// yerinde durur. Her satır aynı odak etrafında aynı ölçekle dönüştüğü için
/// satırlar birbirine göre kaymaz — görüntü tek bir yüzey gibi büyür/küçülür.
/// Ölçek 1 iken dönüşüm birim matristir (yerleşim ve çizim maliyeti yok);
/// ağaç yapısı hep aynı kalır → hücreler yeniden kurulmaz.
class _ZoomRow extends StatelessWidget {
  final ValueNotifier<double> scale;
  final Offset Function() focal;
  final double Function() viewportTop;
  final Widget child;

  const _ZoomRow({
    required this.scale,
    required this.focal,
    required this.viewportTop,
    required this.child,
  });

  static final _identity = Matrix4.identity();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: scale,
        child: child,
        builder: (context, s, child) {
          if (s == 1) return Transform(transform: _identity, child: child);
          final f = focal();
          final ox = f.dx;
          final oy = f.dy - viewportTop();
          final m = Matrix4.translationValues(ox, oy, 0)
            ..multiply(Matrix4.diagonal3Values(s, s, 1))
            ..multiply(Matrix4.translationValues(-ox, -oy, 0));
          return Transform(transform: m, child: child);
        },
      );
}

/// Grup başlığı: gün/ay/yıl adı + sayı; seçimde başta "grubu seç" halkası.
///
/// Satırı paylaşan grupların etiketiyle ([_PackedLabel]) AYNI yazı ve hiza:
/// ikisi alt alta dururken biri büyük biri küçük olunca ızgara düzensiz
/// görünüyordu (ilk ekran görüntüsü denemesinde yakalandı).
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _PackedLabel(
            title: title,
            selecting: selecting,
            allSelected: allSelected,
            onToggle: onToggle,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14, top: 8),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Satırı paylaşan küçük grubun etiketi: kısa tarih, hücrelerinin tam
/// üstünde. Seçimde başında küçük bir "grubu seç" halkası; etiketin tamamı
/// dokunulabilir (dar alanda ayrı bir düğme tutturmak zor).
class _PackedLabel extends StatelessWidget {
  final String title;
  final bool selecting;
  final bool allSelected;
  final VoidCallback onToggle;

  const _PackedLabel({
    required this.title,
    required this.selecting,
    required this.allSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 8),
      child: Row(
        children: [
          if (selecting) ...[
            Icon(
              allSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: allSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: text),
        ],
      ),
    );
    if (!selecting) return content;
    return Semantics(
      button: true,
      label: context.t(allSelected ? 'ph.group_deselect' : 'ph.group_select'),
      child: InkWell(onTap: onToggle, child: content),
    );
  }
}

/// Tam kare önizleme: ad yok, çerçeve yok — Google Fotoğraflar hücresi.
///
/// Seçilince hücre İÇE küçülür, köşeleri yuvarlanır ve arkasında vurgu tonu
/// görünür; sol üstte dolu onay. Küçülme `AnimatedScale` ile — yalnız
/// dönüşüm, yerleşim değişmez (seçimde ızgara zıplamaz).
class _PhotoTile extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final bool selected;
  final bool selecting;
  final String? heroTag;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.entry,
    required this.size,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget thumb = FmEntryIcon(entry: entry, size: size, radius: 0);
    final tag = heroTag;
    if (tag != null) thumb = Hero(tag: tag, child: thumb);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: selected ? 0.84 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 14 : 0),
                clipBehavior: selected ? Clip.antiAlias : Clip.none,
                child: thumb,
              ),
            ),
            if (selecting)
              PositionedDirectional(
                top: 6,
                start: 6,
                child: _CheckBadge(selected: selected),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seçim rozeti: seçiliyse beyaz halkalı dolu onay, değilse gölgeli boş halka
/// (altında koyu da açık da bir fotoğraf olabilir).
class _CheckBadge extends StatelessWidget {
  final bool selected;
  const _CheckBadge({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary)
          : null,
    );
  }
}
