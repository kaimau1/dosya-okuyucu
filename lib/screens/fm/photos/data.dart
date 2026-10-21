part of '../photos_screen.dart';

extension _PhotosScreenDataPart on _PhotosScreenState {
  /// Tam listeyi arka planda getirir (pano önbelleği kırpılmıştır).
  Future<void> _loadAll() async {
    final loader = widget.loadAll;
    if (loader == null) return;
    _partSetState(() => _loadingAll = true);
    try {
      final all = await loader();
      if (!mounted) return;
      // **Değiştirme değil BİRLEŞTİRME** (kullanıcı 2026-09-03: *"yeni
      // aldığım ekran görüntüleri hemen görülmüyor, sanki görülüp geri
      // gidiyor"*). Ekran panonun TAZE listesiyle açılıyor; eksiksiz liste
      // arama dizininden geliyor ve dizin bayatsa YENİ dosyaları içermiyor.
      // Eskiden uzun liste kısa listenin yerine geçtiği için az önce çekilen
      // ekran görüntüsü gözün önünde kayboluyordu. Artık iki liste yolla
      // teke indirilip birleştiriliyor: gösterilen hiçbir dosya kaybolmaz.
      _partSetState(() {
        _files = _PhotosScreenState._mergeByPath(_files, all);
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) _partSetState(() => _loadingAll = false);
    }
  }

  Future<void> _dropMissing() async {
    if (!mounted) return;
    // 20 bin girdide ana izlekte `statSync` listeyi kilitler → isolate.
    final alive = await FsScan.pruneMissing(_files);
    if (!mounted) return;
    _partSetState(() {
      _files = alive;
      final paths = {for (final e in alive) e.path};
      _selected.removeWhere((s) => !paths.contains(s));
    });
  }

  /// Süzülmüş ve sıralı dosyalar (düz liste). Sonuç önbelleklenir.
  List<FsEntry> get _visible {
    final key = '${identityHashCode(_files)}|${_files.length}|$_query|'
        '${_filter.signature}|${_sort.name}|$_desc|${OpenHistory.revision}';
    final cached = _visibleCache;
    if (cached != null && _visibleKey == key) return cached;
    // Yinelenen ayıklaması SIRALAMADAN SONRA anlamlı olsun diye önce sıralanır:
    // "en yeni kopya kalsın" gibi bir tercihte hangi kopyanın kaldığı sıraya
    // bağlıdır (apply listedeki İLK kopyayı tutar).
    final sorted =
        FsScan.sort(_files, _sort, descending: _desc, foldersFirst: false);
    // **Süzgeç TEK kez uygulanır** (2026-08-17 donma bulgusu). Eskiden liste
    // için bir, "kaç kopya gizlendi" sayısı için bir daha uygulanıyordu: 6500
    // fotoğraflı bir galeride pahalı olan `matches` (etiket + açılma geçmişi
    // aramaları) her yeniden çizimde 13 bin kez koşuyordu. Artık eleme bir
    // kez yapılıyor, kopya gizleme onun SONUCUNA uygulanıyor ve gizlenen sayı
    // farktan çıkıyor — sonuç birebir aynı, iş yarı yarıya.
    final matched = _filter.withHideDuplicates(false).apply(sorted,
        query: _query,
        tagsOf: FileTags.forPath,
        openedAtOf: OpenHistory.forPath);
    final List<FsEntry> list;
    if (_filter.hideDuplicates) {
      final seen = <String>{};
      list = [
        for (final e in matched)
          if (seen.add(duplicateKey(e))) e,
      ];
    } else {
      list = matched;
    }
    _hiddenDuplicates = matched.length - list.length;
    _visibleBytes = list.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    _visibleCache = list;
    _visibleKey = key;
    return list;
  }

  /// Düz listeyi zaman gruplarına böler (sıra korunur → indeksler düz kalır).
  /// [group] null ise (tarih dışı sıralama) tek grup döner. Sonuç
  /// önbelleklenir: gruplama listenin tamamını gezer, üstelik plan önbelleği
  /// grupların KİMLİĞİNE bakar — her çizimde yeni liste dönseydi satır planı
  /// her karede baştan kurulurdu.
  List<_Section> _sections(List<FsEntry> visible, PhotoGroup? group) {
    final flatTitle = group == null
        ? context.t('ph.sorted_header', {
            'n': visible.length,
            'sort': '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
          })
        : '';
    final cacheKey = '${identityHashCode(visible)}|${visible.length}|'
        '${group?.name}|$flatTitle';
    final cached = _sectionsCache;
    if (cached != null && _sectionsKey == cacheKey) return cached;
    final out = <_Section>[];
    if (group == null) {
      if (visible.isNotEmpty) out.add(_Section(flatTitle, visible, 0));
    } else {
      String? key;
      var buffer = <FsEntry>[];
      var start = 0;
      for (var i = 0; i < visible.length; i++) {
        final e = visible[i];
        final k = photoGroupKey(e.modifiedMs, group);
        if (k != key) {
          if (buffer.isNotEmpty) out.add(_PhotosScreenState._timeSection(buffer, start, group));
          key = k;
          buffer = [];
          start = i;
        }
        buffer.add(e);
      }
      if (buffer.isNotEmpty) out.add(_PhotosScreenState._timeSection(buffer, start, group));
    }
    _sectionsCache = out;
    _sectionsKey = cacheKey;
    return out;
  }

  /// Satır planı — gruplar, sütun sayısı ve satır yüksekliği değişmedikçe
  /// yeniden kurulmaz. Zaman ekseninde satırı dolduramayan ardışık gruplar
  /// satırı PAYLAŞIR (bkz. `PhotoGridPlan`): günde bir-iki video çeken
  /// kullanıcının ekranı yarı boş satırlardan oluşuyordu.
  PhotoGridPlan _planFor(List<_Section> sections, int columns, double rowExtent) {
    final key = '${identityHashCode(sections)}|${sections.length}|$columns|'
        '${rowExtent.toStringAsFixed(3)}|$_timelineMode';
    final cached = _plan;
    if (cached != null && _planKey == key) return cached;
    final plan = PhotoGridPlan.build(
      sectionSizes: [for (final s in sections) s.files.length],
      columns: columns,
      headerExtent: _PhotosScreenState._headerExtent,
      rowExtent: rowExtent,
      packSmall: _timelineMode,
    );
    _plan = plan;
    _planKey = key;
    return plan;
  }

  double _cellFor(int columns, double width) =>
      (width - _PhotosScreenState._spacing * (columns - 1)) / columns;

  void _toggle(FsEntry e) => _partSetState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  void _selectRange(List<FsEntry> visible, int start, int end, bool select) {
    _partSetState(() {
      for (var i = start; i <= end; i++) {
        if (i < 0 || i >= visible.length) continue;
        if (select) {
          _selected.add(visible[i].path);
        } else {
          _selected.remove(visible[i].path);
        }
      }
    });
  }

  /// Tek dosya seçiliyken görünürdeki konumuna göre üstündekileri/
  /// altındakileri de seçer (Google Fotoğraflar'daki "buraya kadar seç"
  /// jesti). Kullanıcı isteği (2026-07-29): *"1 görüntü seçtim, onun altında
  /// kalanları seç, onun üstünde kalanları seç butonu olsun"*.
  ///
  /// "Üstünde/altında" **ekrandaki sıraya** göredir (mevcut sıralama/filtre
  /// ne olursa olsun): seçili dosyadan önceki indeksler üstte, sonrakiler
  /// altta görünür.
  void _selectFromAnchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final anchorIndex = visible.indexWhere((e) => e.path == _selected.first);
    if (anchorIndex < 0) return;
    _selectRange(
      visible,
      above ? 0 : anchorIndex,
      above ? anchorIndex : visible.length - 1,
      true,
    );
  }

  void _toggleSection(_Section section) {
    final all = section.files.every((e) => _selected.contains(e.path));
    _partSetState(() {
      if (all) {
        _selected.removeAll(section.files.map((e) => e.path));
      } else {
        _selected.addAll(section.files.map((e) => e.path));
      }
    });
  }

  void _toggleSelectAll(List<FsEntry> visible) {
    _partSetState(() {
      if (visible.every((e) => _selected.contains(e.path))) {
        _selected.removeAll(visible.map((e) => e.path));
      } else {
        _selected.addAll(visible.map((e) => e.path));
      }
    });
  }

  Future<void> _open(FsEntry e, List<FsEntry> visible) => EntryOpener.open(
        context,
        e.path,
        siblings: visible.map((x) => x.path).toList(),
      );

  void _clearSearchAndSelection() {
    _partSetState(() {
      if (_selecting) {
        _selected.clear();
      } else {
        _searching = false;
        _query = '';
        _searchController.clear();
      }
    });
  }
}
