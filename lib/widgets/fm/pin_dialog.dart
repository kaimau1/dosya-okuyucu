import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../services/fm/folder_lock.dart';
import '../../services/fm/secure_vault.dart';

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
    builder: (_) => _PinDialog(title: title ?? AppStrings.of(context).t('fm.pin_enter')),
  );
  return ok ?? false;
}

/// PIN kurar/değiştirir (iki kez sorar). Başarılıysa true.
///
/// 2026-10-21 (tek Kasa): PIN kuruluysa önce **mevcut PIN** sorulur —
/// eskiden sorulmuyordu, telefonu eline alan biri PIN'i değiştirip kilitli
/// klasörleri açabiliyordu. Şifreli kasa aynı PIN'i kullandığı için kasanın
/// ana anahtarı yeni PIN'le yeniden sarılır ([SecureVault.changePin]).
Future<bool> setupPin(BuildContext context) async {
  final appState = context.read<AppState>();
  String? oldPin;
  if (appState.fmHasLockPin) {
    oldPin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(
          title: AppStrings.of(context).t('fm.pin_enter'), returnPin: true),
    );
    if (oldPin == null || !context.mounted) return false;
  }
  final newPin = await showDialog<String>(
    context: context,
    builder: (_) => _PinDialog(
        title: AppStrings.of(context).t('fm.pin_new'), setup: true),
  );
  if (newPin == null) return false;
  await syncVaultPin(oldPin, newPin);
  return appState.fmHasLockPin;
}

/// Kasa varsa ana anahtarını [newPin]le yeniden sarar. Kasa kilitliyse
/// [oldPin]le açılıp işten sonra yeniden kilitlenir. Kasa eski bir sürümde
/// AYRI bir PIN'le kurulduysa (eski PIN onu açmaz) kasanın PIN'i değişmez.
Future<bool> syncVaultPin(String? oldPin, String newPin) async {
  final vault = SecureVault.instance;
  if (!vault.exists) return false;
  final wasLocked = !vault.unlocked;
  if (wasLocked) {
    if (oldPin == null || !await vault.unlockWithPin(oldPin)) return false;
  }
  final ok = await vault.changePin(newPin);
  if (wasLocked) await vault.lock();
  return ok;
}

class _PinDialog extends StatefulWidget {
  final String title;
  final bool setup;

  /// Doğrulanan PIN'i `true` yerine kendisi olarak döndür (kasa anahtarını
  /// yeniden sarmak için gerekli).
  final bool returnPin;
  const _PinDialog(
      {required this.title, this.setup = false, this.returnPin = false});

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
        setState(() => _error = context.t('pin.too_short'));
        return;
      }
      // Tekrar kutusu BOŞSA "iki PIN aynı değil" demek kullanıcıyı yanıltıyor:
      // o kutuyu hiç doldurmadığını (hatta gördüğünü) bilmiyor olabilir —
      // görünmezlik hatası temada düzeltildi, ama mesaj da doğru olmalı
      // (kullanıcı hatası 2026-07-30: "eski pin girmedim ki").
      if (_second.text.trim().isEmpty) {
        setState(() => _error = context.t('pin.repeat_empty'));
        return;
      }
      if (pin != _second.text.trim()) {
        setState(() => _error = context.t('pin.mismatch'));
        return;
      }
      await appState.setFmLockPin(pin);
      if (mounted) Navigator.pop(context, pin);
      return;
    }
    if (FolderLock.verify(pin, appState.fmLockPinHash)) {
      Navigator.pop(context, widget.returnPin ? pin : true);
    } else {
      setState(() => _error = context.t('pin.wrong'));
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
              decoration:
                  InputDecoration(labelText: context.t('fm.pin_label')),
              onSubmitted: (_) => widget.setup ? null : _submit(),
            ),
            if (widget.setup) ...[
              const SizedBox(height: Gap.sm),
              TextField(
                controller: _second,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: context.t('fm.pin_repeat')),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('pin.not_encrypted'),
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
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: _submit, child: Text(context.t('common.ok'))),
        ],
      );
}
