import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/remote_connection.dart';
import '../../../services/fm/remote/remote_fs.dart';
import '../../../services/fm/remote/remote_fs_factory.dart';

/// Uzak bağlantı ekleme/düzenleme formu.
class RemoteEditScreen extends StatefulWidget {
  /// Düzenlenecek kayıt; null ise yeni bağlantı.
  final RemoteConnection? existing;

  /// Ağ taramasından gelen ön dolgu.
  final RemoteConnection? prefill;

  const RemoteEditScreen({super.key, this.existing, this.prefill});

  @override
  State<RemoteEditScreen> createState() => _RemoteEditScreenState();
}

class _RemoteEditScreenState extends State<RemoteEditScreen> {
  late RemoteProtocol _protocol;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _domain;
  late final TextEditingController _path;
  late bool _savePassword;

  bool _testing = false;
  String? _message;
  bool _messageIsError = false;

  /// Kullanıcı portu ELLE değiştirdiyse protokol değişince ezilmemeli.
  bool _portTouched = false;

  @override
  void initState() {
    super.initState();
    final source = widget.existing ?? widget.prefill;
    _protocol = source?.protocol ?? RemoteProtocol.sftp;
    _name = TextEditingController(text: source?.name ?? '');
    _host = TextEditingController(text: source?.host ?? '');
    _port = TextEditingController(
        text: '${source?.port ?? _protocol.defaultPort}');
    _user = TextEditingController(text: source?.user ?? '');
    _password = TextEditingController(text: widget.existing?.password ?? '');
    _domain = TextEditingController(text: source?.domain ?? '');
    _path = TextEditingController(text: source?.initialPath ?? '');
    _savePassword = widget.existing?.savePassword ?? true;
    _portTouched = widget.existing != null;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password, _domain, _path]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onProtocolChanged(RemoteProtocol protocol) {
    setState(() {
      _protocol = protocol;
      // Port kullanıcı tarafından değiştirilmediyse protokolün varsayılanına
      // taşınır; elle yazılmışsa DOKUNULMAZ (kullanıcının girdisini ezmek,
      // "kaydettim ama bağlanmıyor"un sık nedeni).
      if (!_portTouched) _port.text = '${protocol.defaultPort}';
    });
  }

  RemoteConnection _build() => RemoteConnection(
        id: widget.existing?.id ??
            'remote_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
        protocol: _protocol,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? _protocol.defaultPort,
        user: _user.text.trim(),
        password: _password.text,
        domain: _domain.text.trim(),
        initialPath: _path.text.trim(),
        savePassword: _savePassword,
      );

  Future<void> _test() async {
    final okText = context.t('nas.test_ok');
    setState(() {
      _testing = true;
      _message = null;
    });
    final fs = createRemoteFs(_build());
    try {
      await fs.connect();
      // Bağlanmak yetmez: kök gerçekten listelenebiliyor mu? Bazı sunucular
      // girişi kabul edip her listelemeyi reddediyor.
      await fs.list(_build().rootPath);
      if (!mounted) return;
      setState(() {
        _message = okText;
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = errorTextFor(context, e);
        _messageIsError = true;
      });
    } finally {
      await fs.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (_host.text.trim().isEmpty) return;
    await context.read<AppState>().saveRemote(_build());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context
            .t(widget.existing == null ? 'nas.add' : 'nas.edit')),
        actions: [
          TextButton(
            onPressed: _host.text.trim().isEmpty ? null : _save,
            child: Text(context.t('common.save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<RemoteProtocol>(
            value: _protocol,
            decoration:
                InputDecoration(labelText: context.t('nas.protocol')),
            items: [
              for (final p in RemoteProtocol.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => v == null ? null : _onProtocolChanged(v),
          ),
          if (_protocol == RemoteProtocol.smb) ...[
            const SizedBox(height: 8),
            _notice(context.t('nas.smb_warning'), scheme),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: context.t('nas.name'),
              hintText: context.t('nas.name_hint'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: context.t('nas.host'),
              hintText: context.t(_protocol.usesUrl
                  ? 'nas.webdav_host_hint'
                  : 'nas.host_hint'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.t('nas.port')),
            onChanged: (_) => _portTouched = true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            autocorrect: false,
            decoration: InputDecoration(labelText: context.t('nas.user')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration:
                InputDecoration(labelText: context.t('nas.password')),
          ),
          if (_protocol.usesDomain) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _domain,
              autocorrect: false,
              decoration:
                  InputDecoration(labelText: context.t('nas.domain')),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _path,
            autocorrect: false,
            decoration:
                InputDecoration(labelText: context.t('nas.initial_path')),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _savePassword,
            title: Text(context.t('nas.save_password')),
            subtitle: Text(context.t('nas.save_password_note')),
            onChanged: (v) => setState(() => _savePassword = v),
          ),
          const SizedBox(height: 12),
          if (_message != null) ...[
            _notice(_message!, scheme, error: _messageIsError),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed:
                _testing || _host.text.trim().isEmpty ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check),
            label: Text(context.t(_testing ? 'nas.connecting' : 'nas.test')),
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
        child: Text(
          text,
          style: TextStyle(
              color: error ? scheme.onErrorContainer : scheme.onSurfaceVariant),
        ),
      );
}

/// Uzak dosya sistemi hatasını kullanıcı diline çevirir.
///
/// Ham istisna metni ("SocketException: …") kullanıcıya HİÇBİR ŞEY anlatmıyor;
/// buradaki eşleme ona ne yapması gerektiğini söylüyor (adres/port kontrolü,
/// aynı ağ, parola).
String errorTextFor(BuildContext context, Object error) {
  final mapped = RemoteFs.mapError(error);
  return context.t(switch (mapped.error) {
    RemoteError.unreachable => 'nas.error_unreachable',
    RemoteError.auth => 'nas.error_auth',
    RemoteError.notFound => 'nas.error_not_found',
    RemoteError.denied => 'nas.error_denied',
    RemoteError.unsupported => 'nas.error_unsupported',
    RemoteError.unknown => 'nas.error_unknown',
  });
}
