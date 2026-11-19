# DEVIR — U4 Akıllı klasörler + Analiz + Yapay zekâ ayarları (dal faz-oto-U4-akilli-klasor)

Yapılanlar (her biri ayrı commit):
1. c8c3b61a durma/başlamama iletileri gerçek neden (SmartHold offline/noKey/noScope, SmartSort.stopText)
2. 1ec3eba4 hayalet kayıt budama (SmartSort.pruneMissing; çöp + takılı olmayan birim korunur)
3. kayıtlı aramalar Akıllı düzeni arar, matches gizleneni eler, PIN, ad "Akıllı aramalar" + giriş kartı
4. aad062ae "Diğer" akıllı klasörü
5. 08c37739 Yapay zekâ ayar sayfası baştan (tiles_smart.dart, SmartSortSettings; MemoryTile silindi)
6. 6e7c4575 Analiz: Tümünü seç 200 sınırı (actions.dart _visible), Kopyalar adı/simgesi, Ayıkla satırı

Şu anki adım: CI doğrulaması (yerel test yok). Kırmızıysa yalnız başarısız parça.
Kök neden kanıtları: smart_sort_screen.dart eski `_run` (stoppedBy → hep sm.stopped "kota"),
smart_sort.dart run başı sessiz `SmartRunResult(0,0)`; smart_folders.dart contents yalnız AiAsk.rank;
analysis_screen.dart `visible.take(200)` ↔ `_toggleSelectAll(visible)`.
Testler: smart_quota_test (noKey, 403 metni), smart_user_cats_test (kota metni, anahtarsız deneme),
smart_sort_test (pruneMissing), new_features_test (SmartFolders + SmartSort), settings_screen_test (AI sayfa düzeni).
Sıradaki: CI yeşil → yürütücü birleştirir (bu dal main'e BİRLEŞTİRİLMEDİ); cihaz turu docs/CIHAZ_TESTI.md U4;
kalan adaylar PLAN U4 satırı (a)–(j).
