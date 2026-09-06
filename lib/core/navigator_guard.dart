import 'package:flutter/widgets.dart';

/// **Boşalan gezinti yığınını yakalayan son emniyet ağı.**
///
/// ## Kök neden (kullanıcı hatası 2026-09-06)
/// *"kopyala gibi işlemler yapıldıktan sonra ekran kararıyor, kapatıp açmak
/// gerekiyor"*
///
/// Flutter'da `Navigator`ın yığını boşalırsa çizecek hiçbir sayfa kalmaz:
/// ekran kararır. Geri tuşu da bir işe yaramaz (kapatacak rota yok), yani
/// kullanıcının tek çıkışı uygulamayı öldürmektir — kullanıcının anlattığı
/// tam olarak bu.
///
/// Asıl sebep bir sayfa fazladan kapatan `Navigator.pop` çağrılarıydı ve
/// onlar kaynağında düzeltildi (bkz. `core/busy_dialog.dart`). Ama "hiçbir
/// yerde bir daha asla fazladan `pop` olmayacak" diye bir güvence yoktur:
/// uygulamada 110'dan fazla `pop` çağrısı var ve her yeni akış bir tane daha
/// ekliyor. Bu gözlemci, hatanın **sonucunu** ortadan kaldırır: yığın
/// boşalırsa kök ekran geri konur.
///
/// Kullanıcı için fark şu: kararan ve öldürülmesi gereken bir uygulama yerine
/// ana ekrana dönen bir uygulama.
///
/// **Sessiz çalışır:** hiçbir uyarı göstermez. Buraya düşmek bir hatadır ama
/// kullanıcıya "bir hata oldu" demek, onun için hiçbir şeyi değiştirmeyen bir
/// korku mesajıdır; gördüğü şey ana ekrana dönmüş bir uygulamadır.
class NavigatorStackGuard extends NavigatorObserver {
  /// Yığın boşaldığında geri konacak kök ekran.
  final WidgetBuilder rootBuilder;

  NavigatorStackGuard(this.rootBuilder);

  /// Ekrandaki rota sayısı (pencereler ve sayfalar birlikte).
  int _count = 0;

  /// Kurtarma iki kez sıraya girmesin (aynı karede `didPop` + `didRemove`
  /// gelebiliyor).
  bool _recovering = false;

  @visibleForTesting
  int get routeCount => _count;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _count++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _count--;
    _checkEmpty();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _count--;
    _checkEmpty();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // Sayı değişmez: biri gitti, biri geldi.
  }

  void _checkEmpty() {
    if (_count > 0 || _recovering) return;
    _recovering = true;
    // Kurtarma KARE SONUNA bırakılır: `didPop` gezginin kendi güncellemesinin
    // ortasında çağrılıyor, o sırada `push` etmek "setState during build"
    // hatası verir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recovering = false;
      final nav = navigator;
      // Arada yeni bir sayfa açılmış olabilir (ör. bildirime dokunma) —
      // o zaman kurtarmaya gerek yok.
      if (nav == null || _count > 0) return;
      nav.push(PageRouteBuilder<void>(
        pageBuilder: (context, _, __) => rootBuilder(context),
        transitionDuration: Duration.zero,
      ));
    });
  }
}
