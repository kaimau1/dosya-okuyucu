part of '../nearby_screen.dart';

/// Yakındakiler ekranının bölümleri (durum, aktarımlar, seçim, cihazlar,
/// QR, geçmiş, diğer yollar) — mantık [_NearbyScreenState]'te.
extension _NearbySections on _NearbyScreenState {
  Widget _menu(BuildContext context) {
    return IconButton(
      tooltip: context.t('common.more'),
      icon: const Icon(AppIcons.more),
      onPressed: () => unawaited(_showTransferMenu(context)),
    );
  }

  Future<void> _showTransferMenu(BuildContext context) async {
    final picked = await showAppActionSheet<String>(
      context,
      title: context.t('xfer.title'),
      subtitle: _deviceName,
      groups: [
        AppActionGroup<String>(
          title: context.t('near.sec_prefs'),
          actions: [
            AppAction(
              value: 'name',
              icon: AppIcons.device,
              label: context.t('peer.device_name'),
              hint: _deviceName,
            ),
            AppAction(
              value: 'dir',
              icon: AppIcons.folder,
              label: context.t('peer.save_to', {'path': p.basename(_saveDir)}),
            ),
            AppAction(
              value: 'confirm',
              icon: _confirmIncoming ? AppIcons.shield : AppIcons.check,
              label: context.t('peer.ask_switch'),
              accent: _confirmIncoming,
            ),
            if (_bgAvailable)
              AppAction(
                value: 'bg',
                icon: AppIcons.bolt,
                label: context.t('near.bg_switch'),
                accent: _bgOn,
              ),
          ],
        ),
        AppActionGroup<String>(
          title: context.t('xft.tab_quick'),
          actions: [
            AppAction(
              value: 'scan',
              icon: AppIcons.qrScan,
              label: context.t('qrf.scan'),
              hint: context.t('qrf.scan_sub'),
            ),
            AppAction(
              value: 'share',
              icon: AppIcons.share,
              label: context.t('near.share_apps'),
            ),
          ],
        ),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'name':
        await _editDeviceName();
      case 'dir':
        await _pickSaveDir();
      case 'confirm':
        _update(() => _confirmIncoming = !_confirmIncoming);
        if (widget.services) await _startReceiving();
      case 'bg':
        await _toggleBg();
      case 'scan':
        await _scanQr();
      case 'share':
        await _shareToApps();
    }
  }

  /// **1 · Ne gönderilecek?** — renk kodlu üç büyük kutu (Dosya ekle ·
  /// Klasör ekle · Yazı / Pano), altında seçilenler ve tek dokunuşla temizle.
  Widget _selectionCard(BuildContext context) {
    final text = _text;
    final count = _selection.length + (text == null ? 0 : 1);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              title: context.t('near.step_what'),
              sub: count == 0
                  ? null
                  : context.t('near.selected', {'n': count}),
              trailing: count > 0
                  ? TextButton(
                      key: const ValueKey('near-clear-sel'),
                      onPressed: _clearSelection,
                      child: Text(context.t('near.clear_sel')),
                    )
                  : null,
            ),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('near-add-files'),
                    icon: AppIcons.addFile,
                    label: context.t('near.add_files'),
                    accent: AppHues.teal,
                    onTap: _addFiles,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('near-add-folder'),
                    icon: AppIcons.addFolder,
                    label: context.t('near.add_folder'),
                    accent: AppHues.amber,
                    onTap: _addFolder,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('near-add-text'),
                    icon: AppIcons.textSnippet,
                    label: context.t('ux47.text_or_clip'),
                    accent: AppHues.indigo,
                    onTap: _editText,
                  ),
                ),
              ],
            ),
            if (text != null || _hasClipText || _appClip.hasItems) ...[
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  if (text != null)
                    InputChip(
                      key: const ValueKey('near-selected-text'),
                      avatar: const Icon(AppIcons.textSnippet,
                          size: AppIcons.small),
                      label: Text(
                        text.length > 36
                            ? '${text.substring(0, 36).replaceAll('\n', ' ')}…'
                            : text.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _editText,
                      onDeleted: _textCtrl.clear,
                    ),
                  if (_hasClipText)
                    ActionChip(
                      key: const ValueKey('near-clip-text'),
                      avatar: const Icon(AppIcons.paste, size: AppIcons.small),
                      label: Text(context.t('ux47.paste_clipboard')),
                      onPressed: () => unawaited(_useClipboardText()),
                    ),
                  if (_appClip.hasItems)
                    ActionChip(
                      key: const ValueKey('near-clip-files'),
                      avatar: const Icon(AppIcons.copy, size: AppIcons.small),
                      label: Text(
                          context.t('near.clip_files', {'n': _appClip.length})),
                      onPressed: _addAppClipboard,
                    ),
                ],
              ),
            ],
            if (_selection.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selection.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                  itemBuilder: (_, i) => _SelectedTile(
                    key: ValueKey(_selection[i]),
                    path: _selection[i],
                    onRemove: () => _remove(_selection[i]),
                  ),
                ),
              ),
            ],
            if (count > 0) ...[
              const SizedBox(height: Gap.xs),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('near-share-apps-inline'),
                  onPressed: _shareToApps,
                  icon: const Icon(AppIcons.share, size: AppIcons.small),
                  label: Text(context.t('near.share_apps')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Güvenilen cihazlar (yalnız varsa): kaldırmak tek dokunuş.
  Widget _trustedCard(BuildContext context) {
    final items = TrustedPeers.instance.items;
    return Card(
      key: const ValueKey('near-trusted'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: _IconWell(
                icon: items[i].keyed ? AppIcons.lock : AppIcons.verified,
                accent: Paper.success(context),
              ),
              title: Text(items[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle:
                  items[i].keyed ? Text(context.t('g5.trusted_keyed')) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (items[i].keyed)
                    IconButton(
                      tooltip: context.t('sync.menu'),
                      icon: Icon(AppIcons.sync,
                          color: AutoSync.instance.rule(items[i].fp)?.on ??
                                  false
                              ? Paper.success(context)
                              : null),
                      onPressed: () => unawaited(showAutoSyncSheet(context,
                          fp: items[i].fp,
                          name: items[i].name,
                          id: items[i].id)),
                    ),
                  IconButton(
                    tooltip: context.t('near.untrust'),
                    icon: const Icon(AppIcons.close),
                    onPressed: () =>
                        unawaited(TrustedPeers.instance.remove(items[i])),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Süren aktarımlar, en üstte: önce gönderim (varsa), sonra alımlar. İki
  /// yönde de her dosya KENDİ satırında, kendi çubuğuyla; başlıkta toplam.
  List<Widget> _transfers(BuildContext context) {
    final out = _out;
    return [
      if (out != null) _outgoingCard(context, out),
      if (_incoming.isNotEmpty) _incomingCard(context),
    ];
  }

  Widget _outgoingCard(BuildContext context, _Outgoing out) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elapsed = DateTime.now().difference(out.startedAt).inMilliseconds;
    final String detail;
    if (out.waiting) {
      detail = context.t('near.waiting');
    } else if (out.totalBytes <= 0) {
      detail = context.t('near.asking', {'name': out.to});
    } else if (elapsed > 300) {
      detail = context.t('peer.speed', {
        'done': FsPaths.humanSize(out.sentBytes),
        'total': FsPaths.humanSize(out.totalBytes),
        'speed': FsPaths.humanSize((out.sentBytes * 1000 / elapsed).round()),
      });
    } else {
      detail =
          '${FsPaths.humanSize(out.sentBytes)} / ${FsPaths.humanSize(out.totalBytes)}';
    }
    return _TransferCard(
      key: const ValueKey('near-outgoing'),
      icon: AppIcons.uploadArrow,
      title: out.totalBytes > 0
          ? '${context.t('near.sending_to', {'name': out.to})} · %${(out.sentBytes * 100 ~/ out.totalBytes).clamp(0, 100).toInt()}'
          : context.t('near.sending_to', {'name': out.to}),
      detail: detail,
      tint: scheme.secondaryContainer,
      action: TextButton(
        key: const ValueKey('near-out-stop'),
        onPressed:
            out.cancelled ? null : () => _update(() => out.cancelled = true),
        child: Text(context.t('common.stop')),
      ),
      rows: [
        if (out.security case final sec?)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: SecureBadge(
                encrypted: sec.encrypted, verifyCode: sec.verifyCode),
          ),
        for (final f in out.files.entries)
          _TransferFileRow(
            key: ValueKey('near-out-${f.key}'),
            name: f.key,
            done: f.value.sent,
            total: f.value.size,
          ),
      ],
    );
  }

  Widget _incomingCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final files = _incoming.entries.toList();
    final known = files.where((e) => e.value.total > 0);
    final got = known.fold<int>(0, (a, e) => a + e.value.received);
    final all = known.fold<int>(0, (a, e) => a + e.value.total);
    return _TransferCard(
      key: const ValueKey('near-incoming'),
      icon: AppIcons.download,
      title: [
        files.length == 1
            ? context.t('near.receiving')
            : context.t('near.receiving_n', {'n': files.length}),
        if (all > 0) '%${(got * 100 ~/ all).clamp(0, 100).toInt()}',
      ].join(' · '),
      detail: all > 0
          ? '${FsPaths.humanSize(got)} / ${FsPaths.humanSize(all)}'
          : null,
      tint: scheme.primaryContainer,
      rows: [
        for (final f in files)
          _TransferFileRow(
            key: ValueKey('near-in-${f.key}'),
            name: f.key,
            done: f.value.received,
            total: f.value.total,
          ),
      ],
    );
  }

  Widget _webCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final web = _web;
    final hs = _hotspot;
    if (_selection.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(AppIcons.qr),
          title: Text(context.t('near.web_idle')),
          subtitle: Text(context.t('near.web_idle_sub')),
        ),
      );
    }
    String? qr;
    String? url;
    String hint;
    if (web == null) {
      hint = context.t('qrf.preparing');
    } else if (hs != null && _hotspotHost != null) {
      final u = web.urlFor(_hotspotHost!);
      url = u.toString();
      qr = _hotspotStep == 0
          ? QrPayload.wifi(hs.ssid, hs.pass, sec: hs.sec)
          : QrPayload.encode(u, ssid: hs.ssid, pass: hs.pass, sec: hs.sec);
      hint =
          context.t(_hotspotStep == 0 ? 'near.web_step1' : 'near.web_step2');
    } else if (_webHost != null) {
      url = web.urlFor(_webHost!).toString();
      qr = url;
      hint = context.t('near.web_same_wifi');
    } else {
      hint = context.t('qrf.preparing');
    }
    final size = QrCode.fitSize(context, max: 200);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              title: context.t('xft.qr_title'),
              sub: hint,
            ),
            if (hs != null && _hotspotHost != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text(context.t('near.step_wifi'))),
                    ButtonSegment(
                        value: 1, label: Text(context.t('near.step_page'))),
                  ],
                  selected: {_hotspotStep},
                  onSelectionChanged: (s) =>
                      _update(() => _hotspotStep = s.first),
                ),
              ),
            // Faz 41 / 4: kısa ömürlü bağlantı — süre + tek seferlik.
            Wrap(
              key: const ValueKey('near-link-life'),
              alignment: WrapAlignment.center,
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              children: [
                for (final (d, key) in const [
                  (null, 'lnk.forever'),
                  (Duration(minutes: 15), 'lnk.min15'),
                  (Duration(hours: 1), 'lnk.hour1'),
                ])
                  ChoiceChip(
                    label: Text(context.t(key)),
                    selected: _linkTtl == d,
                    onSelected: (_) {
                      _update(() => _linkTtl = d);
                      unawaited(_restartWeb());
                    },
                  ),
                FilterChip(
                  key: const ValueKey('near-link-once'),
                  label: Text(context.t('lnk.once')),
                  selected: _linkOnce,
                  onSelected: (v) {
                    _update(() => _linkOnce = v);
                    unawaited(_restartWeb());
                  },
                ),
              ],
            ),
            if (web?.expiresAt case final at?)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  context.t('lnk.until', {
                    'time':
                        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                  }),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (_linkExpired)
              Center(
                child: TextButton.icon(
                  key: const ValueKey('near-link-renew'),
                  onPressed: () => unawaited(_restartWeb()),
                  icon: const Icon(AppIcons.refresh),
                  label: Text(context.t('lnk.expired_renew')),
                ),
              ),
            const SizedBox(height: Gap.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.75),
                  ),
                ),
                child: qr == null
                    ? SizedBox.square(
                        dimension: size,
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : QrCode(key: ValueKey(qr), data: qr, size: size),
              ),
            ),
            if (hs != null && _hotspotStep == 0) ...[
              const SizedBox(height: Gap.sm),
              SelectableText(
                '${context.t('near.network')}: ${hs.ssid}\n${context.t('near.password')}: ${hs.pass}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              Center(
                child: TextButton(
                  onPressed: () => _update(() => _hotspotStep = 1),
                  child: Text(context.t('qrf.connected_next')),
                ),
              ),
            ],
            if (url != null && (hs == null || _hotspotStep == 1)) ...[
              const SizedBox(height: Gap.md),
              Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.control),
                  onTap: () {
                    // G2.6: adres erişim belirteci taşır — hassas işaretli
                    // kopya, 60 sn sonra pano temizlenir.
                    unawaited(SensitiveClipboard.copy(url!));
                    showSnack(context, context.t('near.copied'));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            url,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: AppTheme.fontMono,
                            ),
                          ),
                        ),
                        Icon(AppIcons.copyPlain,
                            size: AppIcons.small,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(context.t('near.type_address'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (_served > 0) ...[
              const SizedBox(height: Gap.sm),
              Text(context.t('qrf.served', {'n': _served}),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: Paper.success(context))),
            ],
            if (_webError != null) ...[
              const SizedBox(height: Gap.sm),
              Text(_webError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.error)),
            ],
            if (hs == null && web != null) ...[
              const SizedBox(height: Gap.xs),
              TextButton.icon(
                onPressed: _hotspotBusy ? null : _startHotspot,
                icon: _hotspotBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.hotspot, size: AppIcons.small),
                label: Text(context.t('qrf.no_common_wifi')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _history(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: TransferHistory.instance,
      builder: (context, _) {
        final h = TransferHistory.instance;
        final all = _historyIncoming ? h.received : h.sent;
        final shown = _historyAll ? all : all.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(AppIcons.download, size: AppIcons.small),
                  label: Text(context.t('near.received_tab')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(AppIcons.uploadArrow, size: AppIcons.small),
                  label: Text(context.t('near.sent_tab')),
                ),
              ],
              selected: {_historyIncoming},
              onSelectionChanged: (s) => _update(() {
                _historyIncoming = s.first;
                _historyAll = false;
              }),
            ),
            const SizedBox(height: Gap.md),
            if (all.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconWell(
                        icon: _historyIncoming
                            ? AppIcons.download
                            : AppIcons.uploadArrow,
                        accent: scheme.primary,
                        size: 48,
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        context.t(_historyIncoming
                            ? 'near.none_received'
                            : 'near.none_sent'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _historyRow(context, shown[i]),
                    ],
                  ],
                ),
              ),
            if (!_historyAll && all.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: TextButton(
                  onPressed: () => _update(() => _historyAll = true),
                  child: Text(context.t('near.show_all', {'n': all.length})),
                ),
              ),
          ],
        );
      },
    );
  }

  /// "1 dk 5 sn" / "12 sn" / "1 sn'den az".
  static String _durationText(BuildContext context, Duration d) {
    final s = d.inSeconds;
    if (s < 1) return context.t('near.dur_lt1');
    final m = s ~/ 60;
    final rest = s % 60;
    if (m == 0) return context.t('near.dur_s', {'s': rest});
    return context.t('near.dur_ms', {'m': m, 's': rest});
  }

  Future<void> _showHistoryRowMenu(
    BuildContext context,
    TransferRecord r, {
    required bool exists,
    required bool isDir,
  }) async {
    final picked = await showAppActionSheet<String>(
      context,
      title: r.name,
      subtitle: r.peer,
      groups: [
        AppActionGroup<String>(
          actions: [
            if (exists && !isDir)
              AppAction(
                value: 'open',
                icon: AppIcons.open,
                label: context.t('common.open'),
                accent: true,
              ),
            if (exists)
              AppAction(
                value: 'reveal',
                icon: AppIcons.folder,
                label: context.t('near.reveal'),
              ),
            AppAction(
              value: 'remove',
              icon: AppIcons.delete,
              label: context.t('near.remove_record'),
              destructive: true,
            ),
          ],
        ),
      ],
    );
    if (picked == null || !mounted || !context.mounted) return;
    switch (picked) {
      case 'open':
        EntryOpener.open(context, r.path);
      case 'reveal':
        unawaited(Navigator.of(context).push(browserRoute(BrowserScreen(
            path: p.dirname(r.path), focusPath: r.path))));
      case 'remove':
        unawaited(TransferHistory.instance.remove(r));
    }
  }

  Widget _historyRow(BuildContext context, TransferRecord r) {
    final scheme = Theme.of(context).colorScheme;
    final exists = r.exists;
    final isDir = exists && FileSystemEntity.isDirectorySync(r.path);
    final ext = p.extension(r.name).replaceFirst('.', '').toLowerCase();
    final c = isDir ? FmCategory.folder : FsEntry.categoryForExtension(ext);
    final (glyph, color) = isDir
        ? (AppIcons.folder, FmColors.folder)
        : FmColors.forExtension(ext) ??
            (FmColors.iconFor(c), FmColors.forCategory(c));
    final when = MaterialLocalizations.of(context).formatShortDate(r.at);
    final time = TimeOfDay.fromDateTime(r.at).format(context);
    return ListTile(
      leading: _IconWell(
        icon: glyph,
        accent: exists ? color : scheme.outline,
      ),
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: r.incoming || (r.percent == null && r.duration == null)
          ? Text(
              [
                r.peer,
                '$when $time',
                if (r.size > 0) FsPaths.humanSize(r.size),
                if (!exists) context.t('near.missing'),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  [
                    context.t('near.sent_to', {'name': r.peer}),
                    '$when $time',
                    if (r.size > 0) FsPaths.humanSize(r.size),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    r.ok
                        ? '✓ ${context.t('near.sent_ok')}'
                        : '✗ ${context.t('near.sent_fail')}',
                    if (r.percent != null) '%${r.percent}',
                    if (r.duration != null) _durationText(context, r.duration!),
                    if (!exists) context.t('near.missing'),
                  ].join(' · '),
                  key: ValueKey('near-sent-status-${r.name}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: r.ok ? Paper.success(context) : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
      onTap: !exists
          ? null
          : () {
              if (isDir) {
                Navigator.of(context)
                    .push(browserRoute(BrowserScreen(path: r.path)));
              } else {
                EntryOpener.open(context, r.path);
              }
            },
      trailing: IconButton(
        tooltip: context.t('common.more'),
        icon: const Icon(AppIcons.more, size: AppIcons.small),
        onPressed: () => unawaited(
          _showHistoryRowMenu(context, r, exists: exists, isDir: isDir),
        ),
      ),
    );
  }

  Widget _otherWays(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([FtpService.instance, DownloadService.instance]),
      builder: (context, _) {
        final sharing = FtpService.instance.running;
        final downloading = DownloadService.instance.activeTasks.length;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _wayTile(
                context,
                icon: sharing ? AppIcons.hotspot : AppIcons.computer,
                accent: AppHues.teal,
                title: context.t('xfer.computer'),
                note: sharing
                    ? context.t('ftpd.running')
                    : context.t('xfer.computer_note'),
                live: sharing,
                screen: const FtpServerScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.dns,
                accent: AppHues.blue,
                title: context.t('fm.network_storage'),
                note: context.t('xfer.nas_note'),
                screen: const RemoteConnectionsScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.downloadForOffline,
                accent: AppHues.green,
                title: context.t('xfer.downloads'),
                note: downloading > 0
                    ? context.t('fm.jobs_running', {'n': downloading})
                    : context.t('xfer.downloads_note'),
                live: downloading > 0,
                screen: const DownloadManagerScreen(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wayTile(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String note,
    required Widget screen,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ok = Paper.success(context);
    return ListTile(
      leading: _IconWell(icon: icon, accent: live ? ok : accent),
      title: Text(title),
      subtitle: Text(
        note,
        maxLines: 2,
        style: live
            ? TextStyle(color: ok, fontWeight: FontWeight.w600)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsetsDirectional.only(end: Gap.xs),
              decoration: BoxDecoration(shape: BoxShape.circle, color: ok),
            ),
          Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
