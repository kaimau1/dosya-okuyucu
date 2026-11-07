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
  static const _pad = EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md);

  /// 1 · Hızlı aktar ve QR.
  Widget _quickTab(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final send = <Widget>[
        _statusStrip(context),
        ..._transfers(context).expand((w) => [const SizedBox(height: Gap.sm), w]),
        const SizedBox(height: Gap.sm),
        _selectionCard(context),
        const SizedBox(height: Gap.sm),
        _devicesStrip(context),
      ];
      if (box.maxWidth < _NearbyScreenState._wideFrom) {
        return ListView(
          key: const ValueKey('near-quick'),
          padding: withNavInset(context, _pad),
          children: [
            ...send,
            const SizedBox(height: Gap.sm),
            _qrCard(context),
          ],
        );
      }
      // Geniş ekran: solda gönderme akışı, sağda QR.
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
                  padding: withNavInset(context, _pad.copyWith(left: 0)),
                  children: [_qrCard(context)],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// İnce durum şeridi: cihaz adı (dokununca değişir) + Wi-Fi/Bluetooth.
  Widget _statusStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _receiver?.running ?? false;
    final bleOk = _ble == BleStart.ok;
    return Card(
      key: const ValueKey('near-status'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.sm),
        child: Row(
          children: [
            _Radar(active: visible || bleOk, size: 40),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: InkWell(
                onTap: _editDeviceName,
                borderRadius: BorderRadius.circular(Radii.control),
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
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                        Icon(AppIcons.edit,
                            size: 14, color: scheme.onSurfaceVariant),
                      ],
                    ),
                    Text(
                      context.t(visible || bleOk ? 'near.visible' : 'near.starting'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
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

  /// "Kime?" — yakındaki cihazlar YATAY şeritte (Wrap ekranı uzatıyordu).
  Widget _devicesStrip(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = _selection.isNotEmpty || _text != null;
    final list = _near.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              title: context.t('near.step_who'),
              sub: ready && list.isNotEmpty ? context.t('near.tap_device') : null,
              trailing: list.isEmpty
                  ? null
                  : Text('${list.length}', style: theme.textTheme.labelLarge),
            ),
            if (list.isEmpty)
              Row(
                children: [
                  Icon(AppIcons.nearMe,
                      size: AppIcons.small, color: scheme.primary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      context.t('near.searching'),
                      maxLines: 2,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                height: 112,
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
                      trusted: TrustedPeers.instance
                          .isTrusted(n.name, n.wifi?.id ?? n.ble?.id ?? ''),
                      onTap: () => _tapPeer(n),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// QR bölümü. Seçim yokken tek satırlık davet + "QR tara" (alma); seçim
  /// varken [_webCard] (kod, adres, süre, hotspot).
  Widget _qrCard(BuildContext context) {
    if (_selection.isNotEmpty) return _webCard(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const ValueKey('near-qr-idle'),
      margin: EdgeInsets.zero,
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
                  Text(context.t('xft.qr_title'), style: theme.textTheme.titleSmall),
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

  /// 2 · Diğer yollar: bilgisayar, ağ depolama, indirmeler, ayarlar.
  Widget _otherTab(BuildContext context) {
    return ListView(
      key: const ValueKey('near-other'),
      padding: withNavInset(context, _pad),
      children: [
        _otherWays(context),
        const SizedBox(height: Gap.md),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(AppIcons.qrScan),
                title: Text(context.t('qrf.scan')),
                subtitle: Text(context.t('qrf.scan_sub')),
                onTap: _scanQr,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(AppIcons.device),
                title: Text(context.t('peer.device_name')),
                subtitle: Text(_deviceName),
                onTap: _editDeviceName,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(AppIcons.folder),
                title: Text(context.t('peer.save_to', {'path': p.basename(_saveDir)})),
                onTap: _pickSaveDir,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 3 · Geçmiş + güvenilen cihazlar.
  Widget _historyTab(BuildContext context) {
    return ListView(
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
    );
  }
}

/// Durum şeridindeki küçük Wi-Fi / Bluetooth göstergesi.
class _Dot extends StatelessWidget {
  final IconData icon;
  final bool ok;
  final String tooltip;
  final VoidCallback? onTap;

  const _Dot({required this.icon, required this.ok, required this.tooltip, this.onTap});

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
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}
