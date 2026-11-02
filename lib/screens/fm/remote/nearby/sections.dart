part of '../nearby_screen.dart';

/// Yakındakiler ekranının bölümleri (durum, aktarımlar, seçim, cihazlar,
/// QR, geçmiş, diğer yollar) — mantık [_NearbyScreenState]'te.
extension _NearbySections on _NearbyScreenState {
  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(AppIcons.more),
      onSelected: (v) async {
        switch (v) {
          case 'name':
            await _editDeviceName();
          case 'dir':
            await _pickSaveDir();
          case 'confirm':
            _update(() => _confirmIncoming = !_confirmIncoming);
            if (widget.services) await _startReceiving();
          case 'bg':
            await _toggleBg();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'name', child: Text(ctx.t('peer.device_name'))),
        PopupMenuItem(
          value: 'dir',
          child: Text(ctx.t('peer.save_to', {'path': p.basename(_saveDir)})),
        ),
        CheckedPopupMenuItem(
          value: 'confirm',
          checked: _confirmIncoming,
          child: Text(ctx.t('peer.ask_switch')),
        ),
        if (_bgAvailable)
          CheckedPopupMenuItem(
            value: 'bg',
            checked: _bgOn,
            child: Text(ctx.t('near.bg_switch')),
          ),
      ],
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _receiver?.running ?? false;
    final bleOk = _ble == BleStart.ok;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            _Radar(active: visible || bleOk),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _editDeviceName,
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                        Icon(AppIcons.edit, size: 16, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t(visible || bleOk ? 'near.visible' : 'near.starting'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: [
                      _Pill(
                        icon: AppIcons.wifi,
                        label: context.t(_hasWifi ? 'near.wifi_on' : 'near.wifi_off'),
                        ok: _hasWifi,
                      ),
                      _Pill(
                        icon: AppIcons.bluetooth,
                        label: context.t(switch (_ble) {
                          BleStart.ok => 'near.bt_on',
                          BleStart.off => 'near.bt_off',
                          BleStart.denied => 'near.bt_denied',
                          BleStart.unsupported => 'near.bt_none',
                          BleStart.failed => 'near.bt_failed',
                          null => 'near.bt_wait',
                        }),
                        ok: bleOk,
                        onTap: bleOk || _ble == BleStart.unsupported || !widget.services
                            ? null
                            : _startBle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selection.isEmpty
                  ? context.t('near.pick_title')
                  : context.t('near.selected', {'n': _selection.length}),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              context.t(_selection.isEmpty ? 'near.pick_sub' : 'near.tap_device'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_selection.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selection.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
                  itemBuilder: (_, i) => _SelectedTile(
                    path: _selection[i],
                    onRemove: () => _remove(_selection[i]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('near-add-files'),
                    onPressed: _addFiles,
                    icon: const Icon(AppIcons.addFile, size: AppIcons.small),
                    label: Text(context.t('near.add_files')),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('near-add-folder'),
                    onPressed: _addFolder,
                    icon: const Icon(AppIcons.addFolder, size: AppIcons.small),
                    label: Text(context.t('near.add_folder')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _devices(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = _near.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Column(
          children: [
            Icon(AppIcons.nearMe, size: AppIcons.large, color: scheme.onSurfaceVariant),
            const SizedBox(height: Gap.sm),
            Text(
              context.t('near.searching'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              context.t('near.searching_sub'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.md,
      children: [
        for (final n in list)
          _PeerAvatar(
            name: n.name,
            wifi: n.wifi != null,
            ble: n.ble != null,
            busy: _out != null,
            onTap: () => _tapPeer(n),
          ),
      ],
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
      detail = '${FsPaths.humanSize(out.sentBytes)} / ${FsPaths.humanSize(out.totalBytes)}';
    }
    return _TransferCard(
      key: const ValueKey('near-outgoing'),
      icon: AppIcons.uploadArrow,
      title: context.t('near.sending_to', {'name': out.to}),
      detail: detail,
      tint: scheme.secondaryContainer,
      action: TextButton(
        key: const ValueKey('near-out-stop'),
        onPressed: out.cancelled ? null : () => _update(() => out.cancelled = true),
        child: Text(context.t('common.stop')),
      ),
      rows: [
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
      title: files.length == 1
          ? context.t('near.receiving')
          : context.t('near.receiving_n', {'n': files.length}),
      detail: all > 0 ? '${FsPaths.humanSize(got)} / ${FsPaths.humanSize(all)}' : null,
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
      hint = context.t(_hotspotStep == 0 ? 'near.web_step1' : 'near.web_step2');
    } else if (_webHost != null) {
      url = web.urlFor(_webHost!).toString();
      qr = url;
      hint = context.t('near.web_same_wifi');
    } else {
      hint = context.t('qrf.preparing');
    }
    final size =
        (MediaQuery.sizeOf(context).shortestSide - 140).clamp(160.0, 260.0);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hs != null && _hotspotHost != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(context.t('near.step_wifi'))),
                    ButtonSegment(value: 1, label: Text(context.t('near.step_page'))),
                  ],
                  selected: {_hotspotStep},
                  onSelectionChanged: (s) => _update(() => _hotspotStep = s.first),
                ),
              ),
            Center(
              child: qr == null
                  ? SizedBox.square(
                      dimension: size,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : QrCode(key: ValueKey(qr), data: qr, size: size),
            ),
            const SizedBox(height: Gap.sm),
            Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (hs != null && _hotspotStep == 0) ...[
              const SizedBox(height: Gap.xs),
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
              const SizedBox(height: Gap.sm),
              Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.control),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: url!));
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
                            size: AppIcons.small, color: scheme.onSurfaceVariant),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
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
            const SizedBox(height: Gap.sm),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Text(
                  context.t(_historyIncoming ? 'near.none_received' : 'near.none_sent'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final r in shown) _historyRow(context, r),
                  ],
                ),
              ),
            if (!_historyAll && all.length > shown.length)
              TextButton(
                onPressed: () => _update(() => _historyAll = true),
                child: Text(context.t('near.show_all', {'n': all.length})),
              ),
          ],
        );
      },
    );
  }

  Widget _historyRow(BuildContext context, TransferRecord r) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exists = r.exists;
    final isDir = exists && FileSystemEntity.isDirectorySync(r.path);
    final ext = p.extension(r.name).replaceFirst('.', '').toLowerCase();
    final c = isDir ? FmCategory.folder : FsEntry.categoryForExtension(ext);
    final (glyph, color) = isDir
        ? (AppIcons.folder, FmColors.folder)
        : FmColors.forExtension(ext) ?? (FmColors.iconFor(c), FmColors.forCategory(c));
    final when = MaterialLocalizations.of(context).formatShortDate(r.at);
    final time = TimeOfDay.fromDateTime(r.at).format(context);
    return ListTile(
      leading: Icon(glyph, color: exists ? color : scheme.outline),
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          r.peer,
          '$when $time',
          if (r.size > 0) FsPaths.humanSize(r.size),
          if (!exists) context.t('near.missing'),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      trailing: PopupMenuButton<String>(
        icon: const Icon(AppIcons.more, size: AppIcons.small),
        onSelected: (v) {
          switch (v) {
            case 'open':
              EntryOpener.open(context, r.path);
            case 'reveal':
              Navigator.of(context).push(browserRoute(BrowserScreen(
                  path: p.dirname(r.path), focusPath: r.path)));
            case 'remove':
              unawaited(TransferHistory.instance.remove(r));
          }
        },
        itemBuilder: (ctx) => [
          if (exists && !isDir)
            PopupMenuItem(value: 'open', child: Text(ctx.t('common.open'))),
          if (exists)
            PopupMenuItem(value: 'reveal', child: Text(ctx.t('near.reveal'))),
          PopupMenuItem(value: 'remove', child: Text(ctx.t('near.remove_record'))),
        ],
      ),
    );
  }

  Widget _otherWays(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FtpService.instance, DownloadService.instance]),
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
                title: context.t('xfer.computer'),
                note: sharing ? context.t('ftpd.running') : context.t('xfer.computer_note'),
                live: sharing,
                screen: const FtpServerScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.dns,
                title: context.t('fm.network_storage'),
                note: context.t('xfer.nas_note'),
                screen: const RemoteConnectionsScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.downloadForOffline,
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
    required String title,
    required String note,
    required Widget screen,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(note,
          maxLines: 2,
          style: live ? TextStyle(color: Paper.success(context)) : null),
      trailing: Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
