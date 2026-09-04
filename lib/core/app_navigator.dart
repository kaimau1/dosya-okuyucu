import 'package:flutter/widgets.dart';

/// Uygulamanın **kök gezinme anahtarı** — `context`i olmayan ya da gezinti
/// ağacının DIŞINDA duran yerlerden ekran açmanın tek yolu.
///
/// İki çağıranı var ve ikisi de ağacın dışında:
/// * sistem bildirimine dokunma (`main.dart`, `_openFromNotification`),
/// * ekran altı mini oynatma çubuğu (`MaterialApp.builder` içinde durduğu
///   için kendi `context`inde `Navigator` YOKTUR — bkz. kullanıcı çökmesi
///   2026-09-04, `mini_player_bar.dart`).
///
/// **Niye `main.dart`ta değil de burada:** `main.dart` uygulamanın bütün
/// ekranlarını içeri alıyor; ondan anahtar için içe aktarma yapmak her
/// widget'ı o ağırlığa bağlar (ve döngüsel bağımlılık üretir). Anahtar tek
/// başına, bağımlılıksız bir dosyada.
final navigatorKey = GlobalKey<NavigatorState>();
