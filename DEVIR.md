# DEVIR — R3 (a) PDF/Excel geçiş gerilemesi (faz-oto-R3-gecis)

- Kök: bd691226 `lib/core/page_transitions.dart` `_FastPageTransition` alttaki sayfaya
  `ScaleTransition(secondaryAnimation 1.0→0.982)` ekledi. Ölçek ötelemeden farklı olarak alttaki
  sayfanın her karede kesirli ölçekte yeniden rasterlanmasına yol açar.
  Kanıt: tablet bisect #10 (b2da4963↔bd691226 2+2) gecis_pdf_acilis raster p90 +%73 / p99 +%49;
  bu commit'in geçişe dokunan TEK değişikliği bu ölçek (theme.dart = statik bileşen temaları).
- Düzeltme: ölçek kaldırıldı (tema/görsel aynı). Bekçi: test/page_transitions_test.dart.
- Sıradaki: tablette A/B (taban main 500431a9 ya da e05e099b, `AB_SENARYO=acilis_gecis`),
  gecis_pdf_acilis + gecis_xlsx_kapanis raster p90/p99 tabana dönmeli. Yeşilse birleştir.
- Dönmezse hipotez 2: theme.dart FAB elevation 0→2 / ElevatedButton gölgesi (alttaki ekranda).
