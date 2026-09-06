import 'dart:async';

import 'package:flutter/material.dart';

/// Açılan pencereyi **kimliğiyle** kapatan tutamak.
///
/// ## Kök neden (kullanıcı hatası 2026-09-06: *"kopyala gibi işlemler
/// yapıldıktan sonra ekran kararıyor, kapatıp açmak gerekiyor"*)
///
/// Uygulamanın on bir ayrı yerinde aynı kalıp vardı:
///
/// ```dart
/// showDialog(context: context, builder: ...);   // "çalışıyor" penceresi
/// final sonuc = await uzunIs();
/// Navigator.of(context).pop();                  // pencereyi kapat (SANIYORDUK)
/// ```
///
/// `Navigator.pop` bir pencereyi DEĞİL, **yığının en üstündekini** kapatır.
/// Pencere o sırada orada değilse — kullanıcı geri tuşuna bastıysa
/// (`barrierDismissible: false` geri tuşunu ENGELLEMEZ), pencere kendini
/// kapattıysa ya da araya başka bir pencere girdiyse — bu `pop` **arkadaki
/// SAYFAYI** kapatır. Sayfa yığındaki tek sayfaysa `Navigator` boşalır:
/// Flutter hiçbir şey çizemez, ekran kararır ve uygulamanın geri tuşu da
/// kalmadığı için tek çare süreci öldürmektir. Kullanıcının tarifi bu.
///
/// Kopyalama bu tuzağa en açık akıştı: hedef klasör seçme sayfası, çakışma
/// sorusu ve ilerleme penceresi arka arkaya açılıp kapanıyor, işlem küçük
/// dosyalarda pencere daha çizilmeden bitiyor.
///
/// ## Çözüm
/// Pencere `showDialog` yerine [showBusyDialog] ile açılır; geriye dönen
/// tutamak **kendi rotasını** tutar ve yalnız onu kaldırır:
/// * rota çoktan gitmişse hiçbir şey yapılmaz (geri tuşu senaryosu),
/// * rota en üstteyse olağan (animasyonlu) `pop`,
/// * üstüne başka bir pencere binmişse `removeRoute` ile aradan çekilir.
///
/// Böylece bu tutamak **hiçbir koşulda** arkadaki sayfayı kapatamaz.
class BusyDialog {
  final NavigatorState _navigator;
  final ModalRoute<void> _route;
  bool _closed = false;

  BusyDialog._(this._navigator, this._route);

  /// Pencere hâlâ ekranda mı? (Kullanıcı geri tuşuyla kapatmış olabilir.)
  bool get isOpen => !_closed && _route.isActive;

  /// Pencereyi kapatır. Birden çok kez çağrılabilir (ikincisi sessizce geçer);
  /// akışların `catch`/`finally` dallarında aynı kapatma iki yoldan da
  /// gelebiliyor.
  void close() {
    if (_closed) return;
    _closed = true;
    if (!_route.isActive) return;
    if (_route.isCurrent) {
      _navigator.pop();
    } else {
      // Üstünde başka bir rota var: `pop` ONU kapatırdı. `removeRoute` yalnız
      // bu rotayı yığından çıkarır (animasyonsuz — zaten görünmüyor).
      _navigator.removeRoute(_route);
    }
  }
}

/// "Çalışıyor" penceresi açar ve onu kapatacak [BusyDialog] tutamağını döner.
///
/// `showDialog`ın yaptığı işin aynısını yapar (kök gezginde `DialogRoute`,
/// yakalanmış tema, engel etiketi) — tek farkı **rotayı çağırana vermesi**.
/// Gerekçe için [BusyDialog] belgesine bakın.
///
/// [dismissible] varsayılan olarak kapalı: iş sürerken pencereye dokunmak onu
/// kapatmamalı. Geri tuşu yine de çalışır ve artık **güvenlidir** — akış
/// sonunda `close()` çağırdığında ortada kapatılacak pencere kalmamışsa
/// hiçbir şey olmaz.
BusyDialog showBusyDialog(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    builder: builder,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Tema `context`ten yakalanır: pencere kök gezginde açılıyor ve oradaki
    // ağaçta sayfanın teması (yazı ölçeği, renk şeması) yoktur.
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    // `showDialog`ın kendi varsayılanı: odak pencerenin içinde döner,
    // arkadaki sayfaya kaçmaz (klavye/erişilebilirlik gezinmesi).
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  // Sonuç beklenmiyor: pencere `BusyDialog.close()` ile kapatılıyor.
  unawaited(navigator.push<void>(route));
  return BusyDialog._(navigator, route);
}

/// **Kendi sayfasını kapatan** akışlar için güvenli `pop`.
///
/// "İşim bitti, bu sayfayı kapat" demek isteyen kod `Navigator.pop(context)`
/// yazıyor; oysa `pop` "en üsttekini kapat" demek. Sayfanın üstüne bu arada
/// bir pencere ya da başka bir sayfa bindiyse (bir bildirim ekranı, bir
/// paylaşım penceresi) o `pop` YANLIŞ rotayı kapatır ve sayfa geride kalır —
/// zincirin ucunda yine boşalan bir yığın vardır.
///
/// Buradaki kural basit: rota en üstte değilse hiçbir şey yapılmaz. Sayfa
/// kapanmadan kalırsa kullanıcı geri tuşuyla çıkar; yanlış sayfanın
/// kapanmasının böyle bir telafisi yok.
void popOwnPage(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return;
  Navigator.of(context).pop();
}
