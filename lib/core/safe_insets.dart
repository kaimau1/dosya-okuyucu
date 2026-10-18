import 'package:flutter/widgets.dart';

/// Kaydırılabilir içeriğin iç boşluğuna **sistem gezinme çubuğunun payını**
/// ekler.
///
/// Kullanıcı 2026-10-18 (ekran görüntüsüyle, "Uygulamanın kapladığı alan"
/// ekranındaki "Android uygulama ayarlarını aç" düğmesi): *"böyle işaretli
/// gibi altta kalan, basılamayan şeyler var; onları bul ve düzelt"*.
///
/// **Kök neden:** uygulama kenardan kenara çiziliyor (`SystemUiMode
/// .edgeToEdge`; targetSdk 36'da Android bunu zaten dayatıyor), yani içerik
/// sistem gezinme çubuğunun ALTINA uzanıyor. `ListView`/`GridView`/
/// `SingleChildScrollView` `padding` verilmezse bu payı `MediaQuery`den
/// kendiliğinden ekler; ama `padding: EdgeInsets.all(16)` gibi AÇIK bir
/// değer verilince eklemez. Listenin en sonundaki öğe — ekranın son düğmesi —
/// sonuna kadar kaydırıldığında bile 48 dp'lik üç düğmeli gezinme çubuğunun
/// altında kalıyor ve dokunuşlar çubuğa gidiyordu. Aynı sınıfta 70'ten
/// fazla liste ve alt levha (eylem menüsü: "AI ve dönüştür" bölümü) vardı.
///
/// **Neden her durumda güvenli:** `Scaffold` alt çubuğu (`bottomNavigationBar`)
/// olan ekranda gövdenin `MediaQuery` alt payını zaten sıfırlıyor; `SafeArea`
/// da içindekilere sıfır veriyor; klavye açıkken Flutter alt payı sıfırlıyor.
/// Yani pay yalnız içerik gerçekten çubuğun altına uzandığında eklenir.
T withNavInset<T extends EdgeInsetsGeometry>(BuildContext context, T base) {
  final inset = MediaQuery.paddingOf(context).bottom;
  if (inset <= 0) return base;
  final EdgeInsetsGeometry out = switch (base) {
    EdgeInsets b => b + EdgeInsets.only(bottom: inset),
    EdgeInsetsDirectional b => b + EdgeInsetsDirectional.only(bottom: inset),
    _ => base.add(EdgeInsets.only(bottom: inset)),
  };
  return out as T;
}
