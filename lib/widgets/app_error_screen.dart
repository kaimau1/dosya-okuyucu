import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_navigator.dart';
import '../core/l10n/app_strings.dart';

/// Bir widget çizilirken hata olduğunda ekrana konan **kurtarma kartı**.
///
/// ## Kök neden (kullanıcı hatası 2026-09-06)
/// *"kopyala gibi işlemler yapıldıktan sonra ekran kararıyor, kapatıp açmak
/// gerekiyor"*
///
/// Flutter bir `build` hatasında o widget'ın yerine [ErrorWidget] koyar.
/// Geliştirme derlemesinde bu kırmızı-sarı "hata kutusu"dur; **release
/// derlemesinde ise düz gri/siyah bir dikdörtgendir — yazısız, düğmesiz.**
/// Hata ağacın tepesine yakın bir yerde olduysa (ör. `MaterialApp.builder`
/// içindeki mini oynatıcı çubuğu) o dikdörtgen bütün ekranı kaplar: kullanıcı
/// kararmış bir ekran görür ve dokunacak hiçbir şey olmadığı için uygulamayı
/// öldürür.
///
/// Bu ekran o boşluğu doldurur: ne olduğunu söyler ve **geri dönmenin bir
/// yolunu verir**. Hata yine `CrashLog`a yazılır (`FlutterError.onError`
/// kancası), yani kayıt kaybolmuyor.
///
/// **Yerleşim kuralı:** bu widget hiç beklenmedik yerlerde çizilebilir —
/// bir satırın içinde, kaydırılan bir listede, sınırsız yükseklikte. Bu
/// yüzden `Expanded`/`Center` gibi sınır isteyen hiçbir şey KULLANILMAZ;
/// `Column(mainAxisSize: min)` her koşulda ölçülebilir. (Hata widget'ının
/// kendisi hata verirse Flutter'ın kurtaracağı bir şey kalmaz.)
class AppErrorScreen extends StatelessWidget {
  /// Yakalanan hata. Release'te kullanıcıya ayrıntı yazılmaz.
  final FlutterErrorDetails details;

  const AppErrorScreen({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    // Tema OKUNMAZ: hata temanın kendisinde olabilir ve `Theme.of` ikinci bir
    // hata atarsa kurtarma ekranı da çizilemez. Renkler sabit ve nötr.
    // Metinler `AppStrings.current`ten okunuyor, `context.t`ten DEĞİL:
    // `context.t` ağaçtaki `Localizations`a bakar ve buraya düşme sebebimiz
    // tam olarak ağacın bir yerinin çizilememesi olabilir. `current` düz bir
    // statik tablo — hiçbir şey aramaz, hiçbir şey fırlatmaz.
    final str = AppStrings.current;
    const bg = Color(0xFF1C1B1F);
    const fg = Color(0xFFE6E1E5);
    const dim = Color(0xFFA8A2AC);
    return Material(
      color: bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: dim, size: 40),
              const SizedBox(height: 12),
              Text(
                str.t('err.render_failed'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: fg, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                str.t('err.render_logged'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: dim, fontSize: 13),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                Text(
                  '${details.exception}',
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: dim, fontSize: 11),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _button(str.t('err.go_back'), () {
                    final nav = navigatorKey.currentState;
                    if (nav != null && nav.canPop()) nav.pop();
                  }),
                  const SizedBox(width: 12),
                  _button(str.t('err.go_home'), () {
                    navigatorKey.currentState
                        ?.popUntil((route) => route.isFirst);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD0BCFF),
        backgroundColor: const Color(0xFF2B2930),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      child: Text(label),
    );
  }
}
