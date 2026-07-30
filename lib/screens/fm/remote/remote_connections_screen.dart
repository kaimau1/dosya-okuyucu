import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/remote_connection.dart';
import '../../../services/fm/remote/lan_discovery.dart';
import 'ftp_server_screen.dart';
import 'remote_browser_screen.dart';
import 'remote_edit_screen.dart';

/// Ağ depolama girişi: kayıtlı bağlantılar, ağ taraması ve "PC'den eriş".
class RemoteConnectionsScreen extends StatefulWidget {
  const RemoteConnectionsScreen({super.key});

  @override
  State<RemoteConnectionsScreen> createState() =>
      _RemoteConnectionsScreenState();
}

class _RemoteConnectionsScreenState extends State<RemoteConnectionsScreen> {
  StreamSubscription<LanHost>? _scan;
  final _found = <String, LanHost>{};
  bool _scanning = false;

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scan?.cancel();
    setState(() {
      _scanning = true;
      _found.clear();
    });
    // Sonuçlar AKIŞ olarak geliyor: 254 adresin bitmesini beklemeden ilk
    // bulunan listeye düşüyor, yoksa kullanıcı "hiçbir şey yok" sanırdı.
    _scan = LanDiscovery.discover().listen(
      (host) {
        if (!mounted) return;
        setState(() => _found[host.key] = host);
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  void _stopScan() {
    _scan?.cancel();
    _scan = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _add({RemoteConnection? prefill}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteEditScreen(prefill: prefill),
    ));
  }

  Future<void> _edit(RemoteConnection connection) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteEditScreen(existing: connection),
    ));
  }

  /// Bağlanır. Parola kaydedilmemişse ÖNCE sorar — kaydetmeme tercihinin
  /// karşılığı "her seferinde sor", sessizce boş parolayla denemek değil.
  Future<void> _connect(RemoteConnection connection) async {
    var target = connection;
    if (!connection.savePassword || connection.password.isEmpty) {
      final password = await _askPassword(connection.name);
      if (password == null) return;
      target = connection.copyWith(password: password);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: target),
    ));
  }

  Future<String?> _askPassword(String name) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('nas.password_prompt', {'name': name})),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: ctx.t('nas.password')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    );
  }

  Future<void> _delete(RemoteConnection connection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content:
            Text(ctx.t('nas.delete_confirm', {'name': connection.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().removeRemote(connection.id);
  }

  @override
  Widget build(BuildContext context) {
    final remotes = context.watch<AppState>().remotes;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('nas.title')),
        actions: [
          IconButton(
            tooltip: context.t('ftpd.title'),
            icon: const Icon(Icons.computer_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FtpServerScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (remotes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  const Icon(Icons.dns_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(context.t('nas.empty'), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            for (final connection in remotes)
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(connection.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(connection.summary,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _connect(connection),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _edit(connection);
                    if (v == 'delete') _delete(connection);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit', child: Text(context.t('common.edit'))),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(context.t('common.delete'))),
                  ],
                ),
              ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _add(),
                    icon: const Icon(Icons.add),
                    label: Text(context.t('nas.add')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? _stopScan : _startScan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(context
                        .t(_scanning ? 'nas.scanning' : 'nas.scan')),
                  ),
                ),
              ],
            ),
          ),
          if (_found.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                context.t('nas.scan_found', {'n': _found.length}),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final host in _found.values)
              ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: Text('${host.name}  ·  ${host.protocol.label}'),
                subtitle: Text('${host.host}:${host.port}'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => _add(
                  prefill: RemoteConnection(
                    id: '',
                    name: host.name,
                    protocol: host.protocol,
                    host: host.host,
                    port: host.port,
                  ),
                ),
              ),
          ] else if (!_scanning) ...[
            const SizedBox(height: 8),
          ],
          if (!_scanning && _found.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                context.t('nas.scan_none'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
