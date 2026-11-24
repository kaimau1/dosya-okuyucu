part of '../nearby_screen.dart';

/// **Aktar ekranının sekmeleri** (2026-11-06 yeniden yazım, kullanıcı:
/// *"Aktar ekranının ve altındaki diğer aktarım seçeneklerini baştan
/// yazalım, görsel olarak sekme hâline getir; ilk sekme hızlı aktar ve QR
/// olsun ve ekrana sığsın"*).
///
/// Eskiden her şey (durum, seçim, cihazlar, QR, geçmiş, güvenilenler, diğer
/// yollar) tek uzun listedeydi; telefonda QR ancak iki ekran aşağıda
/// görünüyordu. Şimdi:
/// 1. **Hızlı aktar** — ince durum şeridi, "ne gönderilecek", yakındaki
///    cihazlar (yatay şerit) ve QR — telefon ekranına kaydırmadan sığar
///    (dosya seçilip QR çıkınca kayar).
/// 2. **Diğer yollar** — bilgisayar (FTP/tarayıcı), ağ depolama, indirmeler
///    ve QR ile alma büyük kartlar hâlinde.
/// 3. **Geçmiş** — alınan/gönderilen + güvenilen cihazlar.
///
/// Mantık (alma sunucusu, yayın, Bluetooth, web sunucusu) [_NearbyScreenState]
/// içinde kalır; sekme değişince hiçbir hizmet durmaz.
extension _NearbyTabs on _NearbyScreenState {
  static const _pad = EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md);

  /// 1 · Hızlı aktar ve QR.
  Widget _quickTab(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final send = <Widget>[
        _statusStrip(context),
        // 2026-11-18 kullanıcı: "SS aldı, hemen aktar ekranında üstte kayan
        // panelde gözüksün" — yeni gelenler + son açılanlar, tek dokunuşla seç.
        // (Testte `services: false` → disk taranmaz, şerit yok.)
        if (widget.services) ...[
          const SizedBox(height: Gap.sm),
          FreshFilesStrip(
            key: const ValueKey('near-fresh'),
            selected: _selection.toSet(),
            onTap: _toggleFresh,
          ),
        ],
        ..._transfers(context).expand((w) => [const SizedBox(height: Gap.sm), w]),
        const SizedBox(height: Gap.sm),
        _selectionCard(context),
      ];
      if (box.maxWidth < _NearbyScreenState._wideFrom) {
        return ListView(
          key: const ValueKey('near-quick'),
          padding: withNavInset(context, _pad),
          children: [
            ...send,
            const SizedBox(height: Gap.sm),
            _devicesStrip(context),
            // 2026-11-12 kullanıcı: "alınan şeyler bu ekranda görülmeli" —
            // gelenler yalnız Geçmiş sekmesindeydi.
            _recentReceived(context),
            const SizedBox(height: Gap.sm),
            _qrCard(context),
          ],
        );
      }
      // Geniş ekran: solda dosya seç/gönder akışı, sağda hedef cihazlar, QR
      // ve son alınanlar dengeli iki sütunda.
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                key: const ValueKey('near-col-send'),
                child: ListView(
                    padding: withNavInset(context, _pad), children: send),
              ),
              Expanded(
                key: const ValueKey('near-col-more'),
                child: ListView(
                  padding: withNavInset(
                    context,
                    const EdgeInsetsDirectional.only(
                      end: Gap.md,
                      top: Gap.sm,
                      bottom: Gap.md,
                    ),
                  ),
                  children: [
                    _devicesStrip(context),
                    const SizedBox(height: Gap.sm),
                    _qrCard(context),
                    _recentReceived(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// İnce durum şeridi: cihaz adı (dokununca değişir) + canlı görünürlük +
  /// Wi-Fi/Bluetooth göstergeleri.
  Widget _statusStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _receiver?.running ?? false;
    final bleOk = _ble == BleStart.ok;
    final live = visible || bleOk;
    return Card(
      key: const ValueKey('near-status'),
      margin: EdgeInsets.zero,
      color: live
          ? scheme.primaryContainer.withValues(alpha: 0.24)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(
          color: live
              ? scheme.primary.withValues(alpha: 0.24)
              : scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.sm),
        child: Row(
          children: [
            _Radar(active: live, size: 40),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: InkWell(
                onTap: _editDeviceName,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.xs, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: Gap.xs),
                          Icon(AppIcons.edit,
                              size: 14, color: scheme.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: live
                                  ? Paper.success(context)
                                  : scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.t(live
                                  ? 'ux47.near_visible'
                                  : 'near.starting'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: live
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: Gap.xs),
            _Dot(
              icon: AppIcons.wifi,
              ok: _hasWifi,
              tooltip: context.t(_hasWifi ? 'near.wifi_on' : 'near.wifi_off'),
            ),
            const SizedBox(width: Gap.xs),
            _Dot(
              icon: AppIcons.bluetooth,
              ok: bleOk,
              tooltip: context.t(switch (_ble) {
                BleStart.ok => 'near.bt_on',
                BleStart.off => 'near.bt_off',
                BleStart.denied => 'near.bt_denied',
                BleStart.unsupported => 'near.bt_none',
                BleStart.failed => 'near.bt_failed',
                null => 'near.bt_wait',
              }),
              onTap: bleOk || _ble == BleStart.unsupported || !widget.services
                  ? null
                  : _startBle,
            ),
          ],
        ),
      ),
    );
  }

  /// "Kime?" — yakındaki cihazlar YATAY kart şeridinde.
  Widget _devicesStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = _selection.isNotEmpty || _text != null;
    final list = _near.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              title: context.t('near.step_who'),
              sub: ready && list.isNotEmpty
                  ? context.t('near.tap_device')
                  : null,
              trailing: list.isEmpty
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${list.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            if (list.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: Gap.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    _IconWell(
                      icon: AppIcons.nearMe,
                      accent: scheme.primary,
                      size: 36,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.t('near.searching'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            context.t('near.empty_hint'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 122,
                child: ListView.separated(
                  key: const ValueKey('near-devices'),
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    return _PeerAvatar(
                      name: n.name,
                      wifi: n.wifi != null,
                      ble: n.ble != null,
                      busy: _out != null,
                      trusted: TrustedPeers.instance.isTrusted(
                          n.name,
                          n.wifi?.id ?? n.ble?.id ?? '',
                          n.wifi?.fingerprint ?? ''),
                      onTap: () => _tapPeer(n),
                      onLongPress: n.wifi?.secure ?? false
                          ? () => unawaited(showAutoSyncSheet(context,
                              fp: n.wifi!.fingerprint,
                              name: n.name,
                              id: n.wifi!.id))
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// QR bölümü. Seçim yokken davet + "QR tara" (alma); seçim varken
  /// [_webCard] (kod, adres, süre, hotspot).
  Widget _qrCard(BuildContext context) {
    if (_selection.isNotEmpty) return _webCard(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const ValueKey('near-qr-idle'),
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer.withValues(alpha: 0.30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Icon(AppIcons.qr, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('xft.qr_title'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t('near.web_idle_sub'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('near-qr-scan-btn'),
              onPressed: _scanQr,
              icon: const Icon(AppIcons.qrScan, size: AppIcons.small),
              label: Text(context.t('xft.scan_short')),
            ),
          ],
        ),
      ),
    );
  }

  /// 2 · Diğer yollar: bulut bağlantısı, bilgisayar, ağ depolama, indirmeler,
  /// aktarım tercihleri.
  Widget _otherTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          key: const ValueKey('near-other'),
          padding: withNavInset(context, _pad),
          children: [
            // Bağlantıyla gönder (internet, Drive) — 2026-11-13.
            LinkShareCard(
              selection: _selection,
              saveDir: _saveDir,
              onPickFiles: _addFiles,
            ),
            SectionHeader(
              context.t('near.sec_local'),
              padding: _NearbyScreenState._section,
            ),
            _otherWays(context),
            SectionHeader(
              context.t('near.sec_prefs'),
              padding: _NearbyScreenState._section,
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: _IconWell(
                      icon: AppIcons.device,
                      accent: scheme.primary,
                    ),
                    title: Text(context.t('peer.device_name')),
                    subtitle: Text(_deviceName),
                    trailing:
                        Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
                    onTap: _editDeviceName,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const _IconWell(
                      icon: AppIcons.folder,
                      accent: AppHues.amber,
                    ),
                    title: Text(context
                        .t('peer.save_to', {'path': p.basename(_saveDir)})),
                    trailing:
                        Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
                    onTap: _pickSaveDir,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const _IconWell(
                      icon: AppIcons.shield,
                      accent: AppHues.teal,
                    ),
                    title: Text(context.t('peer.ask_switch')),
                    value: _confirmIncoming,
                    onChanged: (v) async {
                      _update(() => _confirmIncoming = v);
                      if (widget.services) await _startReceiving();
                    },
                  ),
                  if (_bgAvailable) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const _IconWell(
                        icon: AppIcons.bolt,
                        accent: AppHues.indigo,
                      ),
                      title: Text(context.t('near.bg_switch')),
                      value: _bgOn,
                      onChanged: (_) => unawaited(_toggleBg()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hızlı aktar'da son gelen 3 dosya; "Tümü" Geçmiş sekmesini açar.
  /// Hiç alınan yoksa yer kaplamaz.
  Widget _recentReceived(BuildContext context) {
    return ListenableBuilder(
      key: const ValueKey('near-recent-received'),
      listenable: TransferHistory.instance,
      builder: (context, _) {
        final received = TransferHistory.instance.received;
        if (received.isEmpty) return const SizedBox.shrink();
        final top = received.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              context.t('near.received_tab'),
              padding: _NearbyScreenState._section,
              trailing: received.length > 3
                  ? TextButton(
                      onPressed: () {
                        _update(() {
                          _historyIncoming = true;
                          _historyAll = true;
                        });
                        DefaultTabController.of(context).animateTo(2);
                      },
                      child: Text(context
                          .t('near.show_all', {'n': received.length})),
                    )
                  : null,
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _historyRow(context, top[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 3 · Geçmiş + güvenilen cihazlar.
  Widget _historyTab(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          key: const ValueKey('near-history-tab'),
          padding: withNavInset(context, _pad),
          children: [
            _history(context),
            if (TrustedPeers.instance.items.isNotEmpty) ...[
              SectionHeader(context.t('near.trusted'),
                  padding: _NearbyScreenState._section),
              _trustedCard(context),
            ],
          ],
        ),
      ),
    );
  }
}

/// Durum şeridindeki Wi-Fi / Bluetooth gösterge rozeti.
class _Dot extends StatelessWidget {
  final IconData icon;
  final bool ok;
  final String tooltip;
  final VoidCallback? onTap;

  const _Dot({
    required this.icon,
    required this.ok,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = ok ? Paper.success(context) : scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              color: fg.withValues(alpha: ok ? 0.14 : 0.08),
              border: Border.all(
                color: fg.withValues(alpha: ok ? 0.34 : 0.18),
              ),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}
