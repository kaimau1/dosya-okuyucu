import 'package:flutter/widgets.dart';

/// **Sağdan sola arayüzde soldan sağa veri** (Faz 16, 2026-10-22).
///
/// KÖK NEDEN: Arapça arayüzde "117 KB · 22 Eki 2026 13:15" gibi bir alt satır
/// tek paragraf olarak çift yönlü algoritmaya giriyordu; sayılar ve ayraçlar
/// "zayıf/nötr" sayıldığı için parçalar karışıyor, ekranda
/// "KB · 22 Eki 2026 13:15 117" görünüyordu. Her parça Unicode **yalıtım**
/// (FSI … PDI) içine alınınca kendi yönünü kendi içinde çözer; parçaların
/// SIRASI ise paragraf yönünü izler (Arapçada ilk parça sağda).
///
/// Soldan sağa dillerde metne dokunulmaz (görünmez karakter eklenmez).
String bidiParts(BuildContext context, String text, {String sep = ' · '}) {
  if (Directionality.maybeOf(context) != TextDirection.rtl) return text;
  return text.split(sep).map((p) => '\u2068$p\u2069').join(sep);
}
