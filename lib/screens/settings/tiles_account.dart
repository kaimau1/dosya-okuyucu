import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import 'settings_widgets.dart';

/// Hesap ve bulut senkronu.
///
/// Üç durumu da AYNI satır dilinde anlatır: Firebase yoksa "yerel çalışıyor",
/// giriş yapılmışsa e-posta + çıkış, yapılmamışsa giriş formu.
class AccountTile extends StatefulWidget {
  const AccountTile({super.key});

  @override
  State<AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<AccountTile> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.firebaseAvailable) {
      return SettingTile(
        icon: Icons.phone_android_outlined,
        title: context.t('settings.account_local'),
        subtitle: context.t('settings.account_local_note'),
        wrapSubtitle: true,
      );
    }

    if (appState.signedIn) {
      return SettingTile(
        icon: Icons.cloud_done_outlined,
        title: appState.userEmail ?? context.t('settings.signed_in'),
        subtitle: context.t('settings.sync_active'),
        trailing: TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await appState.signOut();
                    return null;
                  }),
          child: Text(context.t('settings.sign_out')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration:
                InputDecoration(labelText: context.t('settings.email')),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _password,
            obscureText: true,
            decoration:
                InputDecoration(labelText: context.t('settings.password')),
          ),
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => appState.signInWithEmail(
                          _email.text, _password.text)),
                  child: Text(context.t('settings.sign_in')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => appState.registerWithEmail(
                          _email.text, _password.text)),
                  child: Text(context.t('settings.register')),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            onPressed:
                _busy ? null : () => _run(() => appState.signInWithGoogle()),
            icon: const Icon(Icons.login),
            label: Text(context.t('settings.google_sign_in')),
          ),
        ],
      ),
    );
  }
}
