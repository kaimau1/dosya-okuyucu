part of '../search_screen.dart';

/// [_SearchScreenState]'in çizim yardımcıları (A4.1 bölmesi, davranış aynı).
extension _SearchScreenStateParts on _SearchScreenState {
  /// Seçim kipindeki ekran: sade sayaç + "tümünü seç" üstte, eylemler altta.
  ///
  /// Ayrı bir `Scaffold` DEĞİL, aynı gövde farklı üst çubukla — arama alanı
  /// seçim sırasında gizlenir (klavye açılıp seçimi bozmasın) ama sonuçlar
  /// yerinde kalır, liste zıplamaz.
  Widget _selectionScaffold(List<FsEntry> results) {
    final selected = _selectedIn(results);
    final allSelected =
        results.isNotEmpty && results.every((e) => _selected.contains(e.path));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => _update(_selected.clear),
        ),
        title: Text(context.t('ph.selected_of',
            {'n': selected.length, 'total': results.length})),
        actions: [
          FmSelectionActions(
            allSelected: allSelected,
            single: _selected.length == 1,
            onToggleAll: () => _toggleSelectAll(results),
            onAbove: () => _selectAnchor(results, above: true),
            onBelow: () => _selectAnchor(results, above: false),
          ),
        ],
      ),
      body: Stack(
        children: [
          _body(results),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FmSelectionBar(
              selected: selected,
              allowReveal: true,
              onReveal: _reveal,
              onChanged: () async {
                // "Arka plana al" ekranı kapatmış olabilir (bkz. kategori
                // ekranındaki aynı not).
                if (!mounted) return;
                _update(_selected.clear);
                await _run(_controller.text);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dizinin durumu: kuruluyor / bayat. Kullanıcı sonucun neden eksik
  /// olabileceğini bilsin diye açıkça yazılır.
  Widget _indexBanner() {
    String? text;
    if (SearchIndex.isBuilding) {
      text = context.t('srch.index_building');
    } else if (SearchIndex.isReady && SearchIndex.isStale) {
      text = context.t('srch.index_stale');
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  /// Cümleden ANLAŞILANLAR — kullanıcı yanlış yorumu görüp kaldırabilsin.
  Widget _smartChips() {
    final smart = _smart!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.t('srch.understood'),
              style: Theme.of(context).textTheme.bodySmall),
          for (final label in smart.understood)
            Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
            ),
          if (smart.text.trim().isNotEmpty)
            Chip(
              avatar: const Icon(AppIcons.abc, size: 18),
              label: Text('“${smart.text}”'),
              visualDensity: VisualDensity.compact,
            ),
          TextButton(
            onPressed: () => _update(() => _smart = null),
            child: Text(context.t('common.ignore')),
          ),
        ],
      ),
    );
  }

  void _toggleMeaning() {
    _update(() {
      _meaning = !_meaning;
      _plan = null;
      _meaningMatched = const {};
      if (_meaning) {
        _inContent = false;
        _smart = null;
      }
    });
    final q = _controller.text.trim();
    if (q.length >= 2) {
      unawaited(_meaning ? _runMeaning(q) : _run(q));
    }
  }

  /// Anlamla arama: sorgu (yalnız sorgu) AI'ya, sıralama cihazda.
  Future<void> _runMeaning(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    final appState = context.read<AppState>();
    final str = AppStrings.of(context);
    if (!await ensureAiKey(context) || !mounted) return;
    final token = ++_queryToken;
    _update(() {
      _aiBusy = true;
      _searching = true;
    });
    try {
      final (plan, hits) = await AiMeaningSearch.search(
        q,
        gemini: appState.gemini,
        root: _root,
        scope: appState.aiScopeRules,
      );
      if (!mounted || token != _queryToken) return;
      _update(() {
        _aiBusy = false;
        _searching = false;
        _searched = true;
        _plan = plan;
        _results = [for (final h in hits) h.entry];
        _meaningMatched = {for (final h in hits) h.entry.path: h.matched};
      });
    } catch (e) {
      if (!mounted || token != _queryToken) return;
      _update(() {
        _aiBusy = false;
        _searching = false;
      });
      showSnack(context, str.t('srch.ai_error', {'error': userErrorText(e)}));
    }
  }

  /// Anlamla arama şeridi: ne yapıldığını söyler; arama sonrası AI'nın
  /// hangi sözcüklerle aradığını çip olarak yazar ("neden bu sonuç?").
  Widget _meaningBanner() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = _plan;
    return Container(
      key: const ValueKey('srch-meaning-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: plan == null
          ? Row(
              children: [
                Icon(AppIcons.ai, size: 18, color: scheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(context.t('srch.meaning_intro'),
                      style: theme.textTheme.bodySmall),
                ),
              ],
            )
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(AppIcons.ai, size: 16, color: scheme.primary),
                Text(context.t('srch.meaning_terms'),
                    style: theme.textTheme.labelMedium),
                for (final t in plan.terms)
                  Chip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
    );
  }

  /// Sorguyu Gemini'ye yorumlatır. **Yerel çözümleme yine geçerlidir**: AI
  /// başarısız olursa ya da anlamsız yanıt dönerse arama bozulmaz.
  Future<void> _askAi() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final appState = context.read<AppState>();
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    if (!await ensureAiKey(context) || !mounted) return;
    _update(() => _aiBusy = true);
    try {
      final gemini =
          appState.gemini;
      final answer = await gemini.chat(history: [
        ChatTurn(fromUser: true, text: smartQueryPrompt(q, DateTime.now())),
      ]);
      final parsed = smartQueryFromJson(answer);
      if (!mounted) return;
      _update(() {
        _aiBusy = false;
        if (parsed != null) _smart = parsed;
      });
      if (parsed == null && mounted) {
        showSnack(context, str.t('srch.ai_fallback'));
      }
    } catch (e) {
      if (!mounted) return;
      _update(() => _aiBusy = false);
      showSnack(context, str.t('srch.ai_error', {'error': userErrorText(e)}));
    }
  }

  /// Kaç sonuç gösteriliyor, hangi ölçütle sıralı ve liste sınıra takıldı mı.
  /// (Sessizce kırpılmış bir liste "dosyam yok" sanılır.)
  Widget _resultSummary(int shown) {
    final capped = _results.length >= 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (capped)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
            child: Text(context.t('srch.capped').replaceFirst('·', '').trim(),
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  /// Süzgeç şeridi — galeri ve kategori ekranlarıyla AYNI üç kart: Tür ·
  /// Kaynak ve zaman · Analiz ve diğer (2026-10-28). Arama kapsamı, içerikte
  /// arama ve sıralama "Analiz ve diğer" levhasında.
  Widget _filterChips() => FmQuickFilters(
        source: _results,
        filter: _filter,
        onChanged: (f) => _update(() => _filter = f),
        leading: FmTypeChips.forEntries(
          context,
          source: _results,
          filter: _filter,
          onChanged: (f) => _update(() => _filter = f),
          tagsOf: FileTags.forPath,
          openedAtOf: OpenHistory.forPath,
          cacheSalt: '${OpenHistory.revision}',
        ),
        trailing: [
          FmMoreChip(
            active: _filter.activeCount,
            sections: (c) => [
              FmMoreSection(c.t('srch.scope_title'), [
                if (widget.root != null)
                  FmMoreTile(
                    key: const ValueKey('search-scope'),
                    icon: _everywhere ? AppIcons.storage : AppIcons.folder,
                    label: _everywhere
                        ? c.t('srch.scope_everywhere')
                        : c.t('srch.scope_here'),
                    selected: _everywhere,
                    onTap: () {
                      _update(() => _everywhere = !_everywhere);
                      _run(_controller.text);
                    },
                  ),
                FmMoreTile(
                  icon: AppIcons.manageSearch,
                  label: c.t('srch.in_content'),
                  selected: _inContent,
                  onTap: () {
                    _update(() {
                      _inContent = !_inContent;
                      _contentHits = const [];
                      // İçerik araması ile anlamla arama aynı anda olmaz.
                      if (_inContent) {
                        _meaning = false;
                        _plan = null;
                      }
                    });
                    _run(_controller.text);
                  },
                ),
              ]),
              fmSortSection(c,
                  sort: _sort,
                  descending: _desc,
                  onSort: (sort, desc) => _update(() {
                        _sort = sort;
                        _desc = desc;
                      })),
              ...fmDateSizeSections(c,
                  filter: _filter,
                  onChanged: (f) => _update(() => _filter = f)),
            ],
          ),
        ],
      );

  Widget _body(List<FsEntry> results) {
    if (results.isEmpty) {
      final message = context.t(!_searched
          ? 'srch.empty_hint'
          : (_searching ? 'srch.searching' : 'srch.no_result'));
      final history = SearchHistory.queries;
      return ListView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
        children: [
          Text(message, textAlign: TextAlign.center),
          // **Kayıtlı aramalar** (Faz 41 / 3) — son aramaların üstünde.
          if (_saved.isNotEmpty && _controller.text.trim().isEmpty) ...[
            const SizedBox(height: Gap.lg),
            Text(context.t('svs.title'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                for (final s in _saved)
                  InputChip(
                    key: ValueKey('saved-search-${s.query}'),
                    label: Text(s.name),
                    avatar: Icon(
                        s.inContent ? AppIcons.newWord : AppIcons.bookmark,
                        size: 18),
                    onPressed: () => _runSaved(s),
                    onDeleted: () => _removeSaved(s),
                    deleteButtonTooltipMessage: context.t('common.delete'),
                  ),
              ],
            ),
          ],
          // **Son aramalar** — sorgu kutusu boşken gösteriliyor: bir sonuç
          // listesinin üstüne geçmiş koymak, kullanıcının baktığı şeyi
          // aşağı iterdi.
          if (history.isNotEmpty && _controller.text.trim().isEmpty) ...[
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Expanded(
                  child: Text(context.t('srch.recent'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () async {
                    await SearchHistory.clear();
                    if (mounted) _update(() {});
                  },
                  child: Text(context.t('srch.clear_history')),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                for (final q in history)
                  InputChip(
                    label: Text(q),
                    avatar: const Icon(AppIcons.history, size: 18),
                    onPressed: () {
                      _controller.text = q;
                      unawaited(SearchHistory.record(q));
                      unawaited(_run(q));
                    },
                    onDeleted: () async {
                      await SearchHistory.remove(q);
                      if (mounted) _update(() {});
                    },
                  ),
              ],
            ),
          ],
          if (_controller.text.trim().isEmpty) ..._openedSection(),
        ],
      );
    }
    // Uzun basış seçimi açar, basılı tutup kaydırmak aralık seçer — kategori
    // ve galeri ekranlarındaki jestin AYNISI (ortak [FmFileListView], Faz 6).
    return FmFileListView(
      entries: results,
      layout: FmLayout.list,
      selected: _selected,
      controller: _scroll,
      bottomPadding: 88,
      onOpen: _open,
      onToggle: _toggle,
      onSelectRange: (a, b, sel) => _update(() {
        for (var i = a; i <= b; i++) {
          if (i < 0 || i >= results.length) continue;
          if (sel) {
            _selected.add(results[i].path);
          } else {
            _selected.remove(results[i].path);
          }
        }
      }),
      // İçerik aramasında alt satır **eşleşmeyi** gösteriyor:
      // "3 eşleşme · 12. satır · …fatura no: 2024/17…". Boyut ve
      // klasör orada işe yaramaz; kullanıcı METNİ arıyor.
      subtitle: _subtitleFor,
      onMore: (e) async {
        await showEntryActions(
          context,
          e,
          allowReveal: true,
          onReveal: _reveal,
        );
        if (mounted) _run(_controller.text);
      },
    );
  }

  /// **Aramadan açılanlar** (2026-11-10): aramada bulunup açılan dosyalar
  /// kalıcı listede, en yeni üstte; tür çipleriyle süzülür. Silinmiş dosya
  /// gösterilmez (kayıtta kalır, yeniden oluşursa döner).
  List<Widget> _openedSection() {
    final all = <(SearchOpened, FsEntry)>[
      for (final o in SearchHistory.opened)
        if (FsEntry.ofPath(o.path) case final e? when !e.isDir) (o, e),
    ];
    if (all.isEmpty) return const [];
    final kinds = <FmCategory>{for (final (_, e) in all) e.category};
    final kind = kinds.contains(_openedKind) ? _openedKind : null;
    final shown = [
      for (final r in all)
        if (kind == null || r.$2.category == kind) r,
    ];
    final paths = [for (final (_, e) in shown) e.path];
    final theme = Theme.of(context);
    return [
      const SizedBox(height: Gap.lg),
      Row(
        children: [
          Expanded(
            child: Text(context.t('srch.opened'),
                style: theme.textTheme.titleSmall),
          ),
          TextButton(
            onPressed: () async {
              await SearchHistory.clearOpened();
              if (mounted) _update(() {});
            },
            child: Text(context.t('srch.clear_history')),
          ),
        ],
      ),
      if (kinds.length > 1)
        SizedBox(
          height: kFmFilterBarHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FmChip(
                label: context.t('important.gallery_all'),
                count: all.length,
                selected: kind == null,
                onTap: () => _update(() => _openedKind = null),
              ),
              for (final c in FmCategory.values)
                if (kinds.contains(c))
                  FmChip(
                    icon: FmColors.iconFor(c),
                    label: context.t(c.labelKey),
                    count: all.where((r) => r.$2.category == c).length,
                    selected: kind == c,
                    onTap: () => _update(() => _openedKind = c),
                  ),
            ],
          ),
        ),
      for (final (o, e) in shown)
        ListTile(
          key: ValueKey('opened-${e.path}'),
          contentPadding: EdgeInsets.zero,
          leading: FmEntryIcon(entry: e, size: 44),
          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (o.query.isNotEmpty) '“${o.query}”',
              FsPaths.humanDate(o.openedMs),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: context.t('common.delete'),
            icon: const Icon(AppIcons.close, size: 20),
            onPressed: () async {
              await SearchHistory.removeOpened(e.path);
              if (mounted) _update(() {});
            },
          ),
          onTap: () async {
            unawaited(SearchHistory.recordOpened(e.path, o.query));
            await EntryOpener.open(context, e.path, siblings: paths);
            if (mounted) _update(() {});
          },
        ),
    ];
  }

  Future<void> _open(FsEntry entry) async {
    // Bir sonucu açmak, sorgunun İŞE YARADIĞININ kanıtı: geçmişe o an
    // giriyor (arama düğmesine basmayan kullanıcı da geçmişini görsün).
    unawaited(SearchHistory.record(_controller.text));
    if (entry.isDir) {
      _reveal(entry.path);
      return;
    }
    unawaited(SearchHistory.recordOpened(entry.path, _controller.text));
    await EntryOpener.open(
      context,
      entry.path,
      siblings: _filtered.where((e) => !e.isDir).map((e) => e.path).toList(),
    );
  }

  void _reveal(String path) {
    Navigator.of(context).push(browserRoute(BrowserScreen(path: path)));
  }

  /// Tek sonuç seçiliyken üstündekileri/altındakileri de seçer (kategori
  /// ekranındaki "buraya kadar seç" jestinin aynısı).
  void _selectAnchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final i = visible.indexWhere((e) => e.path == _selected.first);
    if (i < 0) return;
    _update(() {
      for (var k = above ? 0 : i; k <= (above ? i : visible.length - 1); k++) {
        _selected.add(visible[k].path);
      }
    });
  }
}
