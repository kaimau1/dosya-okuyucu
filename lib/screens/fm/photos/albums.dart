part of '../photos_screen.dart';

/// **Albümler + "Bu gün geçmişte"** (2026-11-08 galeri turu).
///
/// Araştırma (Fossify/Simple Gallery, Samsung Galeri, Google Foto): klasör =
/// albüm görünümü bu uygulamaların temel gezinti biçimi; "anılar" Google
/// Foto'nun en sevilen kartı. Ikisi de ızgaranın kendisine dokunmaz (P4):
/// seçim yalnız [_visible]'ı daraltır, levha açılınca bir kez O(n) gruplanır.
///
/// 2026-11-15 (kullanıcı: *"albüm oluşturma ve albümleri gizleme silme ekleme
/// gelmeli, albüm alanını komple gizleme olmalı"*): kullanıcı albümleri
/// ([PhotoAlbums], dosya taşımaz), gizleme (her iki tür), silme (kullanıcı
/// albümü: yalnız kayıt; klasör albümü: içindekiler `deleteEntries` onayıyla
/// Çöp'e), seçimden "Albüme ekle / Albümden çıkar". Kapsam anahtarı
/// `dir:<klasör>` ya da `user:<id>`.
class _Album {
  final String key;
  final String title;
  final FsEntry? cover;
  final int count;
  final bool isUser;

  const _Album(this.key, this.title, this.cover, this.count,
      {this.isUser = false});

  String? get dir => key.startsWith('dir:') ? key.substring(4) : null;
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
      if (album.startsWith('user:')) {
        final paths = {...?PhotoAlbums.byKey(album)?.paths};
        return [for (final e in files) if (paths.contains(e.path)) e];
      }
      final dir = album.substring(4);
      return [for (final e in files) if (p.dirname(e.path) == dir) e];
    }
    if (_onThisDay) {
      final now = DateTime.now();
      return [for (final e in files) if (_isOnThisDay(e, now)) e];
    }
    return files;
  }

  /// Başlık: albümde albüm adı, anıda "Bu gün geçmişte".
  String get _scopeTitle {
    final album = _album;
    if (album != null) return _albumTitle(album);
    if (_onThisDay) return context.t('ph.on_this_day');
    return widget.title;
  }

  String _albumTitle(String key) => key.startsWith('user:')
      ? (PhotoAlbums.byKey(key)?.name ?? '')
      : p.basename(key.substring(4));

  bool get _scopeActive => _album != null || _onThisDay;

  bool get _inUserAlbum => _album?.startsWith('user:') ?? false;

  void _clearScope() => _partSetState(() {
        _album = null;
        _onThisDay = false;
      });

  /// Bütün albümler (gizliler dahil): önce kullanıcı albümleri (oluşturma
  /// sırası), sonra klasörler dosya sayısına göre azalan. Liste ya da albüm
  /// kaydı değişmedikçe yeniden gruplanmaz: şerit bunu HER çizimde soruyor.
  List<_Album> _allAlbums() {
    _syncAlbumCache();
    final cached = _albumsCache;
    if (cached != null) return cached;
    final byDir = <String, List<FsEntry>>{};
    final byPath = <String, FsEntry>{};
    for (final e in _files) {
      (byDir[p.dirname(e.path)] ??= []).add(e);
      byPath[e.path] = e;
    }
    final user = <_Album>[];
    for (final a in PhotoAlbums.albums) {
      FsEntry? cover;
      var count = 0;
      for (final path in a.paths) {
        final e = byPath[path];
        if (e == null) continue;
        count++;
        if (cover == null || e.modifiedMs > cover.modifiedMs) cover = e;
      }
      user.add(_Album(a.key, a.name, cover, count, isUser: true));
    }
    final dirs = [
      for (final MapEntry(key: dir, value: list) in byDir.entries)
        _Album(
          'dir:$dir',
          p.basename(dir),
          list.reduce((a, b) => a.modifiedMs >= b.modifiedMs ? a : b),
          list.length,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    final out = [...user, ...dirs];
    _albumsCache = out;
    return out;
  }

  /// Görünen albümler (gizliler hariç).
  List<_Album> _albums() =>
      [for (final a in _allAlbums()) if (!PhotoAlbums.isHidden(a.key)) a];

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
    final key = Object.hash(identityHashCode(_files), _files.length,
        PhotoAlbums.revision.value);
    if (_albumsKey == key) return;
    _albumsKey = key;
    _albumsCache = null;
    _memoriesCache = null;
  }

  // ── Albüm işlemleri ──────────────────────────────────────────────────────

  Future<String?> _askAlbumName({String initial = ''}) => showAppPrompt(
        context,
        title: context.t(initial.isEmpty ? 'pa.new' : 'pa.rename'),
        label: context.t('pa.name'),
        initial: initial,
        maxLength: 60,
        confirmLabel:
            context.t(initial.isEmpty ? 'pa.create' : 'pa.rename'),
      );

  Future<void> _createAlbum({List<String> paths = const []}) async {
    final name = (await _askAlbumName())?.trim() ?? '';
    if (name.isEmpty || !mounted) return;
    await PhotoAlbums.create(name, paths: paths);
    if (!mounted) return;
    if (paths.isNotEmpty) {
      _partSetState(_selected.clear);
      showSnack(context,
          context.t('pa.added', {'n': paths.length, 'name': name}));
    }
  }

  /// Seçimden: "Albüme ekle" — var olan kullanıcı albümü ya da yeni albüm.
  Future<void> _addSelectedToAlbum(List<FsEntry> selected) async {
    if (selected.isEmpty) return;
    await PhotoAlbums.ensureLoaded();
    if (!mounted) return;
    final paths = [for (final e in selected) e.path];
    final v = await showAppActionSheet<String>(
      context,
      title: context.t('pa.add_to'),
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: '_new',
              icon: AppIcons.add,
              accent: true,
              label: context.t('pa.new')),
          for (final a in PhotoAlbums.albums)
            AppAction(
                value: a.key,
                icon: AppIcons.addPhoto,
                label: a.name,
                hint: '${a.paths.length}'),
        ]),
      ],
    );
    if (v == null || !mounted) return;
    if (v == '_new') {
      await _createAlbum(paths: paths);
      return;
    }
    final added = await PhotoAlbums.add(v, paths);
    if (!mounted) return;
    final name = _albumTitle(v);
    _partSetState(_selected.clear);
    showSnack(
        context,
        added == 0
            ? context.t('pa.already', {'name': name})
            : context.t('pa.added', {'n': added, 'name': name}));
  }

  /// Açık kullanıcı albümünden seçilenleri çıkarır (dosyalar yerinde kalır).
  Future<void> _removeSelectedFromAlbum(List<FsEntry> selected) async {
    final key = _album;
    if (key == null || !key.startsWith('user:') || selected.isEmpty) return;
    await PhotoAlbums.removePaths(key, selected.map((e) => e.path));
    if (!mounted) return;
    _partSetState(_selected.clear);
    showSnack(context, context.t('pa.removed', {'n': selected.length}));
  }

  /// Albüm kartına uzun basış: gizle/göster, yeniden adlandır, sil.
  Future<void> _albumMenu(_Album a) async {
    final hidden = PhotoAlbums.isHidden(a.key);
    final v = await showAppActionSheet<String>(
      context,
      title: a.title,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'hide',
              icon: hidden ? AppIcons.hidden : AppIcons.hiddenOff,
              label: context.t(hidden ? 'pa.unhide' : 'pa.hide')),
          if (a.isUser)
            AppAction(
                value: 'rename',
                icon: AppIcons.rename,
                label: context.t('pa.rename')),
          if (a.isUser)
            AppAction(
                value: 'delete',
                icon: AppIcons.delete,
                destructive: true,
                label: context.t('pa.delete'),
                hint: context.t('pa.delete_hint'))
          else if (a.count > 0)
            AppAction(
                value: 'delete',
                icon: AppIcons.delete,
                destructive: true,
                label: context.t('pa.delete_dir'),
                hint: context.t('pa.delete_dir_hint', {'n': a.count})),
        ]),
      ],
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'hide':
        await PhotoAlbums.setHidden(a.key, !hidden);
        if (!mounted) return;
        if (!hidden) {
          if (_album == a.key) _clearScope();
          showSnack(context, context.t('pa.hidden_done', {'name': a.title}));
        }
      case 'rename':
        final name = (await _askAlbumName(initial: a.title))?.trim() ?? '';
        if (name.isNotEmpty) await PhotoAlbums.rename(a.key, name);
      case 'delete':
        if (a.isUser) {
          final ok = await showAppConfirm(context,
              title: context.t('pa.delete'),
              message: context.t('pa.delete_msg', {'name': a.title}),
              confirmLabel: context.t('common.delete'),
              destructive: true);
          if (!ok) return;
          await PhotoAlbums.delete(a.key);
          if (mounted && _album == a.key) _clearScope();
        } else {
          final dir = a.dir!;
          final files = [
            for (final e in _files) if (p.dirname(e.path) == dir) e
          ];
          if (await deleteEntries(context, files)) {
            if (!mounted) return;
            if (_album == a.key) _clearScope();
            await _dropMissing();
          }
        }
    }
    if (mounted) _partSetState(() {});
  }

  /// Albüm alanını (şerit + çubuktaki albüm düğmesi) tümüyle gizler; geri
  /// açmak "Analiz ve diğer › Görünüm"de.
  Future<void> _hideAlbumsArea() async {
    final appState = context.read<AppState>();
    await appState.setFmPhotoHighlights(false);
    if (mounted) showSnack(context, context.t('pa.area_hidden'));
  }

  Future<void> _showAlbums() async {
    await PhotoAlbums.ensureLoaded();
    if (!mounted) return;
    final memories = _memories();
    var showHidden = false;
    await showAppSheet<void>(
      context,
      title: context.t('ph.albums'),
      scrollable: false,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: PhotoAlbums.revision,
        builder: (ctx, _, _) => StatefulBuilder(builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          final text = Theme.of(ctx).textTheme;
          final all = _allAlbums();
          final hiddenCount =
              all.where((a) => PhotoAlbums.isHidden(a.key)).length;
          final albums = [
            for (final a in all)
              if (showHidden || !PhotoAlbums.isHidden(a.key)) a
          ];
          return ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        ActionChip(
                          key: const ValueKey('pa-new'),
                          avatar: const Icon(AppIcons.add, size: 18),
                          label: Text(ctx.t('pa.new')),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _createAlbum();
                          },
                        ),
                        if (hiddenCount > 0)
                          FilterChip(
                            key: const ValueKey('pa-show-hidden'),
                            label: Text(showHidden
                                ? ctx.t('pa.hide_hidden')
                                : ctx.t('pa.show_hidden', {'n': hiddenCount})),
                            selected: showHidden,
                            onSelected: (v) => setSheet(() => showHidden = v),
                          ),
                        if (_highlightsOn)
                          ActionChip(
                            key: const ValueKey('pa-hide-area'),
                            avatar: const Icon(AppIcons.hiddenOff, size: 18),
                            label: Text(ctx.t('ph.albums_hide')),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _hideAlbumsArea();
                            },
                          )
                        else
                          ActionChip(
                            key: const ValueKey('pa-show-area'),
                            avatar: const Icon(AppIcons.thumbnails, size: 18),
                            label: Text(ctx.t('ph.albums_show')),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              unawaited(context
                                  .read<AppState>()
                                  .setFmPhotoHighlights(true));
                            },
                          ),
                      ],
                    ),
                  ),
                ),
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
                      final isHidden = PhotoAlbums.isHidden(a.key);
                      return Semantics(
                        button: true,
                        label: '${a.title}, ${a.count}',
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('pa-album-$i'),
                          borderRadius: BorderRadius.circular(Radii.card),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _enterScope(album: a.key);
                          },
                          onLongPress: () => _albumMenu(a),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (ctx, c) => ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(Radii.card),
                                      child: _AlbumCover(
                                          album: a,
                                          size: c.biggest.shortestSide),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isHidden) ...[
                                      Icon(AppIcons.hiddenOff,
                                          size: 14,
                                          color: scheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(a.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelLarge),
                                    ),
                                  ],
                                ),
                                Text(
                                    a.isUser
                                        ? '${ctx.t('pa.mine')} · ${a.count}'
                                        : '${a.count}',
                                    style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant)),
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
        }),
      ),
    );
  }
}

/// Albüm kapağı: boş kullanıcı albümünde düz zemin + simge.
class _AlbumCover extends StatelessWidget {
  final _Album album;
  final double size;
  const _AlbumCover({required this.album, required this.size});

  @override
  Widget build(BuildContext context) {
    final cover = album.cover;
    if (cover != null) return FmEntryIcon(entry: cover, size: size, radius: 0);
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: SizedBox.expand(
        child: Icon(AppIcons.addPhoto,
            size: size * 0.3, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
