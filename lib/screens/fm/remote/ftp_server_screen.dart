import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/remote/ftp_server.dart';

/// "PC'den eriş (FTP)" — telefonu FTP sunucusuna çevirir.
///
/// Sunucu **ekranla birlikte yaşar**: ekrandan çıkınca durur. Arka planda
/// çalışmaya devam etseydi kullanıcı telefonunu ağa açtığını unutur; bir
/// dosya sunucusunda bu kabul edilemez. Bilinçli sınır, KALANLAR'da yazılı.
class FtpServerScreen extends StatefulWidget {
  const FtpServerScreen({super.key});

  @override
  State<FtpServerScreen> createState() => _FtpServerScreenState();
}

class _FtpServerScreenState extends State<FtpServerScreen> {
  final _user = TextEditingController(text: 'dosya');
  final _password = TextEditingController(text: '1234');
  bool _allowWrite = false;

  FtpServer? _server;
  List<String> _addresses = const [];
  String? _error;
  bool _busy = false;

  String get _root => FmEnv.primaryRoot;

  @override
  void dispose() {
    // Ekran kapanınca sunucu MUTLAKA durur.
    _server?.stop();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_server != null) {
      await _server!.stop();
      if (!mounted) return;
      setState(() {
        _server = null;
        _addresses = const [];
      });
      return;
    }
    final failed = context.t('ftpd.start_failed');
    setState(() {
      _busy = true;
      _error = null;
    });
    final server = FtpServer(
      rootDirectory: _root,
      username: _user.text.trim(),
      password: _password.text,
      allowWrite: _allowWrite,
    );
    try {
      await server.start();
      final addresses = await FtpServer.addresses(server.boundPort);
      if (!mounted) return;
      setState(() {
        _server = server;
        _addresses = addresses;
        _busy = false;
      });
    } catch (e) {
      await server.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failed.replaceAll('{error}', '$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _server != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ftpd.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.t('ftpd.description')),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                running ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: running ? scheme.primary : scheme.onSurfaceVariant,
              ),
              title: Text(
                  context.t(running ? 'ftpd.running' : 'ftpd.stopped')),
              subtitle: Text('${context.t('ftpd.shared_folder')}: $_root',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (running) ...[
            const SizedBox(height: 8),
            if (_addresses.isEmpty)
              _notice(context.t('ftpd.no_address'), scheme, error: true)
            else
              for (final address in _addresses)
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.link),
                    title: SelectableText(address),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        final copied = context.t('ftpd.copied');
                        await Clipboard.setData(
                            ClipboardData(text: address));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(copied)));
                      },
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _user,
            enabled: !running,
            autocorrect: false,
            decoration: InputDecoration(labelText: context.t('nas.user')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !running,
            obscureText: true,
            decoration: InputDecoration(labelText: context.t('nas.password')),
          ),
          if (_user.text.trim().isEmpty) ...[
            const SizedBox(height: 8),
            _notice(context.t('ftpd.anonymous_warning'), scheme, error: true),
          ],
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _allowWrite,
            title: Text(context.t('ftpd.allow_write')),
            subtitle: Text(context.t('ftpd.allow_write_note')),
            onChanged: running ? null : (v) => setState(() => _allowWrite = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _notice(_error!, scheme, error: true),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: Icon(running ? Icons.stop : Icons.play_arrow),
            label: Text(context.t(running ? 'ftpd.stop' : 'ftpd.start')),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, ColorScheme scheme, {bool error = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? scheme.errorContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: TextStyle(
                color: error
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant)),
      );
}
