import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../services/fm/folder_lock.dart';

/// PIN sorar ve doğruysa true döner.
///
/// **Dürüst uyarı arayüzde de yazar:** bu kilit dosyaları şifrelemez, yalnız
/// bu uygulamadaki listelerden gizler. Kullanıcı "şifreli kasa" sanıp oraya
/// gerçekten hassas bir şey koyarsa yanlış bir güven satmış oluruz.
Future<bool> askPin(BuildContext context, {String? title}) async {
  final appState = context.read<AppState>();
  if (!appState.fmHasLockPin) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(title: title ?? 'PIN girin'),
  );
  return ok ?? false;
}

/// PIN kurar/değiştirir (iki kez sorar). Başarılıysa true.
Future<bool> setupPin(BuildContext context) async {
  final appState = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _PinDialog(title: 'Yeni PIN', setup: true),
  );
  if (ok != true) return false;
  if (!context.mounted) return false;
  return appState.fmHasLockPin;
}

class _PinDialog extends StatefulWidget {
  final String title;
  final bool setup;
  const _PinDialog({required this.title, this.setup = false});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final pin = _first.text.trim();
    if (widget.setup) {
      if (pin.length < 4) {
        setState(() => _error = 'PIN en az 4 haneli olmalı.');
        return;
      }
      if (pin != _second.text.trim()) {
        setState(() => _error = 'İki PIN aynı değil.');
        return;
      }
      await appState.setFmLockPin(pin);
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (FolderLock.verify(pin, appState.fmLockPinHash)) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'PIN yanlış.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _first,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'PIN'),
              onSubmitted: (_) => widget.setup ? null : _submit(),
            ),
            if (widget.setup) ...[
              const SizedBox(height: Gap.sm),
              TextField(
                controller: _second,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'PIN (tekrar)'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Bu kilit dosyaları ŞİFRELEMEZ: yalnız bu uygulamadaki '
                'listelerden gizler. Telefon bilgisayara takılırsa ya da başka '
                'bir dosya yöneticisi kullanılırsa dosyalar görülebilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Gap.sm),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(onPressed: _submit, child: const Text('Tamam')),
        ],
      );
}
