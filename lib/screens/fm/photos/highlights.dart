part of '../photos_screen.dart';

/// **Öne çıkanlar şeridi** (2026-11-12 galeri turu).
///
/// Kullanıcı: *"Google Fotoğraflar, Samsung Galeri gibi premium … göze hitap
/// eden yeni bir galeri ekranı"*. O uygulamaların ilk ekranında zaman
/// ekseninin ÜSTÜNDE kapak resimli büyük kartlar durur (anılar, albümler):
/// galeri "dosya listesi" değil "fotoğraflarım" gibi okunur ve en sık gidilen
/// yerler (Kamera, Ekran görüntüleri, WhatsApp) tek dokunuş olur.
///
/// Kurallar:
/// * Şerit ızgaranın parçasıdır (listeyle birlikte kayar) — sabit bir üst
///   alan fotoğraflardan yer çalardı (2026-08-09 "üst alan çok yer kaplıyor").
/// * Seçim/arama başlayınca GİZLENMEZ: gizlense altındaki ızgara zıplardı
///   (2026-07-29 "seçince sayfa zıplıyor"). Yalnız albüm/anı süzgeci açıkken
///   ve tek klasörlük ya da çok küçük galeride çizilmez.
/// * Kartlar yalnız [_album]/[_onThisDay] kapsamını değiştirir; ızgara
///   çizimi aynı kalır.
class _Highlight {
  final String title;
  final int count;
  final FsEntry cover;
  final VoidCallback onTap;
  const _Highlight(this.title, this.count, this.cover, this.onTap);
}

extension _PhotosScreenHighlightsPart on _PhotosScreenState {
  /// Şeridin kaydırma eksenindeki boyu (kart + üst/alt pay).
  static const _extent = 148.0;
  static const _cardWidth = 104.0;
  static const _cardHeight = 132.0;

  /// Şeritte en çok kaç albüm kartı (gerisi "Albümler" levhasında).
  static const _maxAlbums = 8;

  /// En az bu kadar dosya varken şerit çizilir: üç beş dosyalık listede
  /// kartlar fotoğrafların kendisinden çok yer tutardı.
  static const _minFiles = 12;

  bool get _showHighlights =>
      _highlightsOn &&
      !_scopeActive && _files.length >= _minFiles && _albums().length >= 2;

  /// Izgaranın üstünde kalan şerit payı (yoksa 0).
  double get _highlightsExtent => _showHighlights ? _extent : 0;

  void _enterScope({String? album, bool onThisDay = false}) {
    _partSetState(() {
      _album = album;
      _onThisDay = onThisDay;
    });
    // Yeni kapsam baştan okunur (eski ofset başka bir listenin ortasıydı).
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<_Highlight> _highlights() {
    final memories = _memories();
    final albums = _albums();
    return [
      if (memories.isNotEmpty)
        _Highlight(context.t('ph.on_this_day'), memories.length,
            memories.first, () => _enterScope(onThisDay: true)),
      for (final a in albums.take(_maxAlbums))
        _Highlight(p.basename(a.dir), a.count, a.cover,
            () => _enterScope(album: a.dir)),
    ];
  }

  Widget _highlightsStrip() {
    final items = _highlights();
    final more = _albums().length > _maxAlbums;
    return SizedBox(
      height: _extent,
      child: ListView.builder(
        key: const ValueKey('ph-highlights'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        itemCount: items.length + (more ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            return _MoreAlbumsCard(
              width: _cardWidth,
              height: _cardHeight,
              label: context.t('ph.albums'),
              onTap: _selecting ? null : _showAlbums,
            );
          }
          final h = items[i];
          return _HighlightCard(
            key: ValueKey('ph-hl-$i'),
            width: _cardWidth,
            height: _cardHeight,
            item: h,
            // Seçim sürerken kart kapsam değiştirmesin: seçili dosyalar
            // gözün önünden kaybolurdu.
            onTap: _selecting ? null : h.onTap,
          );
        },
      ),
    );
  }
}

/// Kapak resimli kart: altta koyu geçiş, üstünde ad ve dosya sayısı.
class _HighlightCard extends StatelessWidget {
  final double width;
  final double height;
  final _Highlight item;
  final VoidCallback? onTap;

  const _HighlightCard({
    super.key,
    required this.width,
    required this.height,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        label: '${item.title}, ${item.count}',
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FmEntryIcon(entry: item.cover, size: height, radius: 0),
                // Yazı her fotoğrafın üstünde okunsun: alt yarıda koyu geçiş.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.none, AppColors.mediaChrome],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 10,
                  end: 10,
                  bottom: 9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          color: AppColors.onMedia,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${item.count}',
                        maxLines: 1,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.onMediaSoft,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Şeridin son kartı: bütün albümleri levhada açar.
class _MoreAlbumsCard extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final VoidCallback? onTap;

  const _MoreAlbumsCard({
    required this.width,
    required this.height,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AppSkinData.of(context).palette;
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: pal.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: pal.rule),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('ph-hl-more'),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.folderCopy, size: 28, color: pal.accent),
                const SizedBox(height: Gap.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: pal.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
