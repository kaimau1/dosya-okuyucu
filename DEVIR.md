# DEVIR — B17 Endonezya + Malezya (dal `faz-oto-B17-dil`)
## Dil yapısı planı (karar 2026-11-27)
- Bugün `_table` = `Map<String,(tr,en,ar)>` (54 dosya, ~6.300 anahtar). Demeti 5'liye genişletmek her satıra
  dokunur (paralel B4 dallarıyla çakışma; 12.600 metin bir anda yazılamaz). Seçilen: **dil başı ek tablo**
  `lib/core/l10n/locales/{id,ms}.dart` (`Map<String,String>`, `part of app_strings.dart`); `AppStrings.t` id/ms
  için önce ek tabloya bakar, yoksa İngilizceye düşer. `strings/` dosyalarına dokunulmaz. Bellek: yalnız eklenen metin.
- Bekçi: `l10n_test` (ek tablo anahtarı ana tabloda, yer tutucu Türkçeyle aynı, düşme, id≠ms) + `on_denetim`.
- Sistem dili id/ms → otomatik (supportedLocales + delegate + Android `locales_config.xml`); eski "in" kodunu
  Dart `Locale` "id"ye çevirir. Cavi: Malezya arayüzü Rumi → ms soldan sağa, arayüzde RTL/yazı tipi gerekmez;
  Cavi içerik B16 OCR + sistem Naskh, ek harfler (ڠ چ ڤ ڽ ݢ ۏ) cihazda (CIHAZ_TESTI B17).
## Yapılanlar
- m.1 (11c49908): altyapı, seçici, otomatik seçim, dikte id-ID/ms-MY, ML Kit çeviri dilleri, gizlilik ekranı
  id/ms → İngilizce (hukuk metni 👤), akıllı aramada id/ms. 06774691: `ci/res/xml/locales_config.xml`
  (1. CI'da `locale_config_test` kırmızıydı).
- m.2 (11c49908 + a006d2bb): 590 anahtar × 2 dil — ortak, ana ekran, ayarlar, hata, tanıtım, yan menü, dosya
  yöneticisi, dosya işlemleri, USB/SD, PDF/belge görüntüleyici kabuğu.
## Kalan
- Çeviri dilimleri: PDF araçları/düzenleme (`pse`, `pt`, kalan `pp`), Kitaplık, tarama, ödeme/sürüm (`pro`, `ed`),
  temizlik (`clean`), editörler. Seçim: ekran dosyalarında kullanılan anahtarlardan `locales/id.dart`'ta olmayanlar.
- Wi-Fi'de model indirme seçeneği (§1.16 m.4) — yapılmadı (2026-09-26 kararı mobil veride indirmeyi açtı).
- Ucuz cihaz ölçümü → C2; cihaz turu `docs/CIHAZ_TESTI.md` B17.
## Doğrulama
`PYTHONUTF8=1 python tool/on_denetim.py` · CI `verify` (l10n_test, locale_config_test).
