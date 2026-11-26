# DEVIR — B17 Endonezya + Malezya (dal `faz-oto-B17-dil`)

## Dil yapısı planı (karar 2026-11-27)
- Bugün: `_table` = `Map<String,(tr,en,ar)>` (54 dosya, ~6.300 anahtar). Demeti 5'liye genişletmek 54
  dosyanın HER satırına dokunur (paralel B4 P20 ile çakışma + eksik dil derleme hatası, ama 12.600 metin
  bir anda yazılamaz). Seçilen yol: **dil başı ek tablo** `lib/core/l10n/locales/{id,ms}.dart`
  (`Map<String,String>`, `part of app_strings.dart`); `AppStrings.t` id/ms için önce ek tabloya bakar,
  yoksa İngilizceye düşer. `strings/` dosyalarına dokunulmaz → birleştirme çakışması yok.
- Bekçi: `l10n_test` (ek tablodaki anahtar ana tabloda + yer tutucular Türkçeyle aynı + düşme testi +
  id≠ms "Berkas"/"Fail") ve `tool/on_denetim.py` (ek tablo anahtarı ana tabloda).
- Bellek/APK: yalnız eklenen metin kadar (const harita); eksik anahtar için kopya yok.
- Sistem dili id/ms → otomatik (supportedLocales + delegate). Eski Android "in" kodunu Dart `Locale` "id"ye çevirir.
- Cavi (Jawi): Malezya arayüzü Latin (Rumi) — arayüzde RTL/yazı tipi GEREKMEZ (ms soldan sağa).
  Cavi içerik (PDF/metin) Arapça yazı: B16 Arapça OCR + sistem Naskh yazı tipi; ek harfler
  (ڠ چ ڤ ڽ ݢ ۏ) cihazda bakılacak (CIHAZ_TESTI).

## Yapılanlar
- m.1 altyapı + seçici + otomatik + konuşma dili (id-ID/ms-MY) + çeviri dilleri (ML Kit id/ms) +
  gizlilik ekranı id/ms → İngilizce metin (hukuk metni 👤) + akıllı aramada id/ms eş anlamlıları.
- m.2 ilk çeviri dilimi: 439 anahtar × 2 dil (ortak, ana ekran, ayarlar, hata, tanıtım, yan menü,
  dosya yöneticisi, dosya işlemleri, USB/SD).

## Kalan (sıradaki dilimler, en çok kullanılandan)
- PDF görüntüleyici (`pp`, `vw`, `pse`), Kitaplık/okuyucu, tarama, ödeme/sürüm (`pro`, `ed`), temizlik (`clean`).
- Wi-Fi'de model indirme seçeneği (§1.16 m.4) — yapılmadı (ayrı paket; 2026-09-26 kararı mobil veride
  indirmeyi açtı, seçenek eklenecekse varsayılan kapalı).
- Ucuz cihaz ölçümü → C2.

## Doğrulama
`PYTHONUTF8=1 python tool/on_denetim.py` · CI `verify` (l10n_test).
