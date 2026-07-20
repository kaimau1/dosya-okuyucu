import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKey;
  bool _obscure = true;

  static const _models = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: context.read<AppState>().apiKey);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final model = _models.contains(appState.model) ? appState.model : _models.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AccountSection(),
          const Divider(height: 40),
          Text('Yapay Zeka (Gemini)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API anahtarı',
              hintText: 'AIza...',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (v) => appState.setApiKey(v),
          ),
          const SizedBox(height: 6),
          Text(
            'Anahtar cihazınızda saklanır. aistudio.google.com adresinden '
            'ücretsiz alabilirsiniz.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: model,
            decoration: const InputDecoration(labelText: 'Model'),
            items: _models
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => v == null ? null : appState.setModel(v),
          ),
          const Divider(height: 40),
          Text('Görünüm', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
            ],
            selected: {appState.themeMode},
            onSelectionChanged: (s) => appState.setThemeMode(s.first),
          ),
          const Divider(height: 40),
          Row(
            children: [
              Text('AI Kalıcı Hafıza',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${appState.memory.length} not',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (appState.memory.isEmpty)
            const Text('Henüz kayıtlı not yok. AI sohbetinde bir yanıtı '
                '“Hafızaya kaydet” ile ekleyebilirsiniz.')
          else
            ...appState.memory.asMap().entries.map(
                  (e) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(e.value,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => appState.removeMemory(e.key),
                      ),
                    ),
                  ),
                ),
          const Divider(height: 40),
          const _AboutSection(),
        ],
      ),
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection();
  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
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
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final title = Text('Hesap & Senkron',
        style: Theme.of(context).textTheme.titleMedium);

    if (!appState.firebaseAvailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bulut senkron için Firebase henüz '
                      'yapılandırılmamış. Uygulama şu an yerel modda çalışıyor.'),
                  const SizedBox(height: 6),
                  Text(
                    'Etkinleştirmek için depo kökündeki FIREBASE_SETUP.md '
                    'adımlarını izleyin (flutterfire configure).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (appState.signedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(appState.userEmail ?? 'Giriş yapıldı'),
              subtitle: const Text('Bulut senkron aktif'),
              trailing: TextButton(
                onPressed: _busy ? null : () => _run(() async {
                  await appState.signOut();
                  return null;
                }),
                child: const Text('Çıkış'),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-posta'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Parola'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() =>
                        appState.signInWithEmail(_email.text, _password.text)),
                child: const Text('Giriş'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => appState.registerWithEmail(
                        _email.text, _password.text)),
                child: const Text('Kayıt ol'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              _busy ? null : () => _run(() => appState.signInWithGoogle()),
          icon: const Icon(Icons.login),
          label: const Text('Google ile giriş'),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hakkında', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Dosya Okuyucu • sürüm 0.1.0\n'
            'Çok formatlı, hızlı ve sade dosya okuyucu/düzenleyici.'),
      ],
    );
  }
}
