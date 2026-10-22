import 'package:flutter/widgets.dart';

/// **Platformdan gelen "sayfa adı" itmelerini yutar** (çökme 2026-10-22,
/// 1.0.393: "Null check operator … while dispatching notifications for
/// WidgetsBindingObserver.didPushRouteInformation").
///
/// KÖK NEDEN: Flutter 3.27'den beri Android'de derin bağlantı varsayılan
/// açık. Uygulama açıkken başka bir uygulamadan dosya açılınca ("Birlikte
/// aç") gelen `content://…` adresi `didPushRouteInformation` ile
/// `MaterialApp`a sayfa adı olarak itiliyordu. Uygulamada adlandırılmış sayfa
/// yok (`routes`/`onGenerateRoute` tanımsız) → Navigator `onUnknownRoute!`
/// ile çöküyordu. Asıl kapı manifestte (`flutter_deeplinking_enabled =
/// false`); bu gözlemci ikinci savunma hattı: `WidgetsApp`ten ÖNCE kayıtlı
/// olduğu için itmeyi o görmeden alır. Gelen dosyalar zaten yerel köprüden
/// (`MainActivity.asViewIntent` → paylaşım alıcısı) açılıyor.
class RouteInformationGuard with WidgetsBindingObserver {
  RouteInformationGuard._();

  static RouteInformationGuard? _instance;

  /// `runApp`ten ÖNCE çağrılır (gözlemci sırası önemli).
  static void install() {
    if (_instance != null) return;
    _instance = RouteInformationGuard._();
    WidgetsBinding.instance.addObserver(_instance!);
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      Future.value(true);

  @override
  // ignore: deprecated_member_use
  Future<bool> didPushRoute(String route) => Future.value(true);
}
