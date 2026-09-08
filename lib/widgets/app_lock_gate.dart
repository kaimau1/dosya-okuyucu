import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../services/fm/folder_lock.dart';

/// **Uygulama kilidi perdesi** — açılışta PIN sorar.
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulamada klasör kilidi vardı ama uygulamanın kendisi korumasızdı:
/// telefonu eline alan biri **bütün dosyaları** görebiliyordu; kilit yalnız
/// seçilmiş klasörleri gizliyordu. Bu bir dosya yöneticisi — açıldığında
/// telefondaki her şeyi gösteriyor.
///
/// ## Dürüst sınır (klasör kilidiyle aynı)
/// Bu bir **perde**, cihaz güvenliği değil: dosyalar şifrelenmiyor ve başka
/// bir uygulamayla ya da bilgisayara takarak görülebilirler. Amaç, telefonu
/// eline alan birinin bu uygulamadan gezinememesi.
///
/// ## Yerleşim — niye `HomeScreen`in içinde değil
/// Perde ana ekranın **üstünde** duruyor ve ekran ancak PIN doğrulanınca
/// altından çıkıyor. `initState`te bir pencere açmak yeterli olmazdı:
/// pencereyi kapatan (geri tuşu) kilitli ekrana düşerdi.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  /// Bu oturumda kilit açıldı mı? **Süreç ömrü boyunca** hatırlanıyor:
  /// kullanıcı uygulamayı arka plana alıp geri döndüğünde PIN'i yeniden
  /// sormak, dosya taşırken başka bir uygulamaya bakan kullanıcıyı her
  /// seferinde durdururdu.
  bool _unlocked = false;
  final _controller = TextEditingController();
  String? _error;

  /// Arka arkaya yanlış deneme sayısı ve bekleme sayacı.
  ///
  /// **Niye gerekli:** dört haneli bir PIN'in 10 000 olasılığı var ve
  /// yazılımsal bir denemenin bedeli sıfır. Beşinci yanlıştan sonra artan
  /// bir bekleme koymak, kaba kuvvet denemesini pratik olmaktan çıkarıyor;
  /// PIN'ini yanlış giren gerçek kullanıcıyı ise (ilk dört deneme serbest)
  /// hiç etkilemiyor.
  int _wrongTries = 0;
  int _waitSeconds = 0;
  Timer? _waitTimer;

  @override
  void dispose() {
    _waitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppState appState) {
    if (_waitSeconds > 0) return;
    if (FolderLock.verify(_controller.text, appState.fmLockPinHash)) {
      setState(() => _unlocked = true);
      return;
    }
    _wrongTries++;
    setState(() {
      _error = AppStrings.of(context).t('lock.app_wrong');
      _controller.clear();
    });
    if (_wrongTries >= 5) _startWait();
  }

  /// Beşinci yanlıştan sonra 5, 10, 20… saniye (60'ta durur).
  void _startWait() {
    final seconds = (5 * (1 << (_wrongTries - 5))).clamp(5, 60);
    setState(() => _waitSeconds = seconds);
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _waitSeconds--);
      if (_waitSeconds <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (_unlocked || !appState.appLock) return widget.child;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(context.t('lock.app_title'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enabled: _waitSeconds == 0,
                  decoration: InputDecoration(
                    labelText: context.t('lock.app_prompt'),
                    errorText: _waitSeconds > 0
                        ? context.t('lock.app_wait', {'n': _waitSeconds})
                        : _error,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(appState),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _waitSeconds > 0 ? null : () => _submit(appState),
                    child: Text(context.t('common.ok')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
