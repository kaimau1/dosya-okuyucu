part of '../photos_screen.dart';

/// **Albümler + "Bu gün geçmişte"** (2026-11-08 galeri turu).
///
/// Araştırma (Fossify/Simple Gallery, Samsung Galeri, Google Foto): klasör =
/// albüm görünümü bu uygulamaların temel gezinti biçimi; "anılar" Google
/// Foto'nun en sevilen kartı. Ikisi de ızgaranın kendisine dokunmaz (P4):
/// seçim yalnız [_visible]'ı daraltır, levha açılınca bir kez O(n) gruplanır.
class _Album {
  final String dir;
  final FsEntry cover;
  final int count;

  const _Album(this.dir, this.cover, this.count);
}

/// Bugünün ay/gününe denk gelen, önceki yıllardan dosyalar mı?
bool _isOnThisDay(FsEntry e, DateTime now) {
  final d = DateTime.fromMillisecondsSinceEpoch(e.modifiedMs);
  return d.month == now.month && d.day == now.day && d.year < now.year;
}

extension _PhotosScreenAlbumsPart on _PhotosScreenState {
  /// Albüm / anı süzgeci (null-boş = yok). [_visible] önce bunu uygular.
  List<FsEntry> _scoped(List<FsEntry> files) {
    final album = _album;
    if (album != null) {
      return [for (final e in files) if (p.dirname(e.path) == album) e];
    }
    if (_onThisDay) {
      final now = DateTime.now();
      return [for (final e in files) if (_isOnThisDay(e, now)) e];
    }
    return files;
  }

  /// Başlık: albümde klasör adı, anıda "Bu gün geçmişte".
  String get _scopeTitle {
    final album = _album;
    if (album != null) return p.basename(album);
    if (_onThisDay) return context.t('ph.on_this_day');
    return widget.title;
  }

  bool get _scopeActive => _album != null || _onThisDay;

  void _clearScope() => _partSetState(() {
        _album = null;
        _onThisDay = false;
      });

  /// Klasör = albüm, dosya sayısına göre azalan. Liste değişmedikçe yeniden
  /// gruplanmaz: öne çıkanlar şeridi bunu HER çizimde soruyor.
  List<_Album> _albums() {
    _syncAlbumCache();
    final cached = _albumsCache;
    if (cached != null) return cached;
    final byDir = <String, List<FsEntry>>{};
    for (final e in _files) {
      (byDir[p.dirname(e.path)] ??= []).add(e);
    }
    final out = [
      for (final MapEntry(key: dir, value: list) in byDir.entries)
        _Album(
          dir,
          list.reduce((a, b) => a.modifiedMs >= b.modifiedMs ? a : b),
          list.length,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    _albumsCache = out;
    return out;
  }

  /// "Bu gün geçmişte": bugünün ay/gününe denk gelen eski dosyalar.
  List<FsEntry> _memories() {
    _syncAlbumCache();
    final cached = _memoriesCache;
    if (cached != null) return cached;
    final now = DateTime.now();
    final out = [for (final e in _files) if (_isOnThisDay(e, now)) e];
    _memoriesCache = out;
    return out;
  }

  void _syncAlbumCache() {
    final key = Object.hash(identityHashCode(_files), _files.length);
    if (_albumsKey == key) return;
    _albumsKey = key;
    _albumsCache = null;
    _memoriesCache = null;
  }

  Future<void> _showAlbums() async {
    final albums = _albums();
    final memories = _memories();
    await showAppSheet<void>(
      context,
      title: context.t('ph.albums'),
      scrollable: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final text = Theme.of(ctx).textTheme;
        return ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              if (memories.isNotEmpty)
                SliverToBoxAdapter(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: FmEntryIcon(
                          entry: memories.first, size: 48, radius: 0),
                    ),
                    title: Text(ctx.t('ph.on_this_day')),
                    subtitle: Text(ctx.t('ph.on_this_day_sub',
                        {'n': memories.length})),
                    trailing: const Icon(AppIcons.chevron),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _enterScope(onThisDay: true);
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.md, Gap.sm, Gap.md, Gap.md),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: Gap.sm,
                    crossAxisSpacing: Gap.sm,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (ctx, i) {
                    final a = albums[i];
                    final name = p.basename(a.dir);
                    return Semantics(
                      button: true,
                      label: '$name, ${a.count}',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.card),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _enterScope(album: a.dir);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (ctx, c) => ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(Radii.card),
                                  child: FmEntryIcon(
                                      entry: a.cover,
                                      size: c.biggest.shortestSide,
                                      radius: 0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelLarge),
                            Text('${a.count}',
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
