# Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)

## Hafıza (usta koordineli — 3 katman)
- Kod yapısı        → `graphify-out/`   (oku: `GRAPH_REPORT.md`'yi BAŞTAN SONA OKUMA, konuya göre `grep` · güncelle: `graphify update .` — API maliyeti yok)
- Proje ne/niye     → `HAFIZA.md`       (oku: iş başı YALNIZ son ~30 satır, gerisi + `docs/hafiza/` konuya göre `grep` · yaz: iş sonu karar/bug-kök/tuzak, tarihli append-only)
  (HAFIZA.md = dizin; eski tarihli kayıtlar `docs/hafiza/YYYY-MM.md` — gerekince ara; ~600 satırı geçince `python tool/hafiza_arsivle.py`)
- Kullanıcı tercihi → `.claude memory/` (otomatik, projeler-arası — proje bilgisi buraya YAZILMAZ)

**Token tasarrufu (2026-11-04, kullanıcı kararı):** dosyaları tümüyle değil gereken kısmıyla oku;
yerel test yok (§4); kullanıcıya yanıtlar KISA — ne yapıldı + gerekirse tek soru, uzun özet/rapor yazma.

Yaz kuralı: usta rule 12 / YAZ — kalıcı karar, bug kök nedeni veya yanlış çıkan yol oluştuysa
iş bitmeden HAFIZA.md'ye yaz. KVKK: hasta verisi / TC / ölçüm / token yazma.

## 1) Amaç
Sade, hızlı, ücretsiz, çok formatlı **dosya okuyucu/düzenleyici + dosya yöneticisi**
(2026-07-25: telefondaki tüm dosyalar için pano/gezgin/işlemler — `lib/services/fm/`,
`lib/screens/fm/`; ayrıntı ve kararlar HAFIZA.md). **Yalnız Android**
(K10, 2026-10-21: masaüstü/iOS hedefi kaldırıldı). Gemini AI entegrasyonu, format dönüştürme,
paylaşım. (Firebase senkronu 2026-09-26'da kaldırıldı — HAFIZA.) Piyasadaki yavaş/pahalı programlara alternatif.

> Sabit kararlar, tuzaklar, reddedilen yollar ve güncel durum → **HAFIZA.md**
> **Açık işlerin TEK listesi (2026-11-15) → `PLAN.md`**: §0 hız anayasası · §1 Kuyruk + SIRA
> (kod ve telefon işleri) · §2 kapsam dışı · §3 kullanıcının işleri (👤). Telefonda adım adım
> bakılacaklar `docs/CIHAZ_TESTI.md`. Eski planlar (KALANLAR, KONTROL_LISTEM, FAZ, DUZENLEME,
> GELISTIRME, YUKSELTME, PDF_PRO, GUVENLIK, FERRARI, SURUM) → `docs/arsiv/planlar/` — yalnız
> ayrıntı/karar kaynağı; yeni plan dosyası AÇILMAZ, yeni iş `PLAN.md`'ye satır olur.

## 2) Mimari / Dosya Haritası
`graphify-out/GRAPH_REPORT.md` — 23.268 düğüm, 35.421 kenar, 721 topluluk (2026-11-02) (App State Management,
Gemini AI Service, Firebase Auth, PPTX Render/Slide Canvas/Slideshow, Word DocxView, Excel Grid …).
Kod değiştikten sonra `graphify update .` (API maliyeti yok).

## 3) CI/CD (.github/workflows/build-apk.yml — Faz 1 düzeni, 2026-10-21)
`changes` (+ test seçimi) → **`verify`** ×3 parça (pub get → analyze → seçili test [+ `ci/` değiştiyse Kotlin denetimi]; her dalda)
∥ **`apk`** (sürüm no → `ci/prepare_android.sh` [iskelet + tüm yamalar, yerelde de koşar] →
`flutter build apk --obfuscate` → apksigner → içerik/16 KB/boyut bütçesi denetimi → artifact + Dart sembolleri)
→ **`release`** (ikisi yeşilse): main (**başlıkta `[apk]`** ya da faz PR birleşmesi — 2026-11-05; işaretsiz main push'u APK/sürüm üretmez) → tek **`nightly`** sürüm (üzerine yazılır, "en son" işaretli,
`releases/latest/download/dosya-okuyucu.apk` sabit); **`v*` etiketi** → kalıcı sürüm (arm + arm64 + AAB).
**Sürüm adı** (2026-11-05): `ANA.ARA` `lib/core/app_version.dart`'ta (elle; başlıkta `[minor]` ara haneyi +1 yapar), son hane = main'de yayınlanan APK sayısı (`tool/surum_hesapla.sh`), versionCode = koşu no. Sürümde hem `dosya-okuyucu.apk` (sabit bağlantı) hem `dosya-okuyucu-v<sürüm>.apk`.
Eski sürümler budanır (nightly hariç son 10). Push'ta yalnız arm64; 32-bit + AAB etikette/elle.
Yalnız `test/**`/`tool/**` değişen push APK derlemez; `**.md`, `docs/**`, `graphify-out/**` hiç koşturmaz.
Art arda push → önceki koşu iptal.
**ACTIONS KOTASI (2026-11-17, depo ÖZEL oldu; "not" ile aynı kural):** ücretsiz plan ayda ~2000 dk, 1 Aralık'ta sıfırlanır.
Ara push yok — iş sonunda TEK push. main'e doğrudan push tam takım koşturur (≈ 3×10 dk); onun yerine dala push →
CI yeşil → `git push origin HEAD:main` (hızlı ileri, başlıkta `[apk]`): `tool/ci_test_secimi.sh` aynı commit dalda yeşilse
testleri atlar, main'de yalnız APK + yayın koşar. `[tam]`, elle tetik, okuyucu derlemesi yalnız kullanıcı isteyince.

## 4) Çalışma Kuralları
- **Dal:** **TEK DAL — `main`** (faz işleri hariç, aşağıya bak). (2026-07-27: eski 13 `claude/**` dalı silindi; hepsi
  main'in gerisindeydi, hiçbirinde main'de olmayan iş yoktu.) Yeni dal AÇMA;
  iş doğrudan main'e commit edilir. Push: `git push`.
  Bulut oturumu (`claude/*`, `ccr-*`) dal açtıysa iş main'e girince o uzak dal silinir.
  APK yalnız **main**'e push'ta, commit BAŞLIĞINDA `[apk]` varsa (ya da `faz-NN` PR birleşmesinde) derlenir;
  uygulamayı değiştiren main commit'ine `[apk]` yaz (feature dalında sadece `flutter test`).
- **İSTİSNA — Geliştirme fazları (2026-11-04, kullanıcı kararı):** `docs/arsiv/planlar/GELISTIRME_PLANI.md`
  Faz 34–42 işleri **`faz-NN` dalında** yapılır ve iş sonunda **MUTLAKA PR açılıp main'e
  BİRLEŞTİRİLİR** (CI yeşilken; faz ancak birleşmeyle biter). Birleşince sıradaki faz görevi
  `fire_trigger` ile tetiklenir (bkz. `docs/arsiv/planlar/ZAMANLANMIS_GOREV_ISTEMI.md`). Bu istisna yalnız
  faz işleri içindir; öteki işler yine doğrudan main'e.
- **İSTİSNA — Gözetimsiz zincir (2026-11-14, kullanıcı isteği; faz istisnasıyla aynı mantık):**
  `PLAN.md` Kuyruk paketleri **`faz-oto-<no>-<kısa-ad>`** dalında yapılır (CI yalnız
  `main`/`claude/**`/`ccr-*`/`faz-*` dallarında koşar); CI yeşilse yürütücü yerelde
  `git merge --no-ff` ile main'e birleştirir (başlık `Birleştir: …`, APK noktasında ` [apk]`),
  birleşince dal silinir. `gh pr merge` kullanılmaz (faz PR başlığı her seferinde APK derletir).
- **Doğrulama = CI (2026-11-04, kullanıcı kararı — token tasarrufu):** yerelde/bulutta
  `flutter test`/`analyze` KOŞTURMA, Flutter İNDİRME. Push et → CI `verify` işi test eder;
  Actions sonucuna koşu bitince bir kez bak (sık yoklama yapma), kırmızıysa logdan
  yalnız hatalı adımı oku ve sormadan düzelt. Kullanıcı açıkça isterse yerel test yapılır
  (Windows: `C:\src\flutter-3479\bin\flutter.bat`, CI **3.47.9** — Faz 44; `C:\src\flutter`
  3.47.7 `pub get` kilidini bozar — HAFIZA).
  `ci/*.kt` değişikliğini de CI `verify` (Kotlin denetimi) yakalar; `tool/check_kotlin.sh`
  yalnız kotlinc zaten kuruluysa koşturulur (HAFIZA 2026-09-02).
- **Test seçimi + 3 parça (2026-11-05, kullanıcı kararı):** `verify` 3 parçada paralel
  (`Doğrulama (0/3)`…`(2/3)`; analyze + Kotlin 0. parçada); kırmızı parça Actions →
  "Re-run failed jobs" ile tek başına yeniden koşar. Dalda yalnız main'den ayrılınca
  değişenlerin ETKİLEDİĞİ testler (`tool/ci_test_secimi.sh` + `tool/etkilenen_testler.py`;
  pubspec/assets/fixture/.github değişirse tam takım). main'de birleştirme ağacı yeşil PR
  başıyla aynıysa doğrulama atlanır. Tam takım: başlıkta `[tam]`, `v*` etiketi, elle tetik.
  `hooks/pre-push` kaldırıldı (push öncesi yerel tam test YOK); `tool/test_gate.sh` elle kalır.
- **Sürüm notu (2026-11-10, kullanıcı kararı):** uygulamayı değiştiren her commit'in GÖVDESİNE
  son kullanıcının anlayacağı dille satırlar yaz: `Yeni: …` · `İyileştirme: …` · `Düzeltme: …`
  (teknik terim/dosya adı yok, tek cümle). CI `tool/surum_notu.sh` bir önceki sürümden bu yana
  bu satırları toplayıp Release notuna, uygulama da güncelleme sonrası "Yenilikler" penceresine koyar.
- **Commit mesajı sonu:** `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  ve `Claude-Session:` satırı.
- Bilinen derleme tuzakları (CardThemeData, platform klasörleri, keystore) → **HAFIZA.md**
- `dart format lib` / toplu biçimlendirme ÇALIŞTIRMA (yalnız kendi eklediğin dosya); uzun komut
  çıktısını kes (`| tail -n 40`); imza anahtarı/keystore/`key.properties` içeriğini yazdırma,
  commit'leme, hafızaya yazma.

## 4b) Gece / zamanlanmış görev kuralı (2026-11-14, "not" projesinden aynen)
- Gözetimsiz zincir: yürütücü **`oto-tur` skill'ini**, alt ajan **`isci` skill'ini** uygular;
  Kuyruk ve SIRA `PLAN.md` §1'de (yürütme düzeni `OTOMASYON.md`); zamanlanmış görev `okuyucu-devam` (istem `OTOMASYON_BASLAT.md`).
- Plan KARAR maddeleri verilmiştir: SORMADAN uygula; yeni karar → en güvenli seçenek + "sabah
  bakılacak". 👤 madde yapılmaz → `PLAN.md` §3.
- Dalda çalış (yukarıdaki zincir istisnası) → CI yeşilse main'e birleştir; **CI kırmızıyken
  main'e ASLA birleştirme**; main kırmızıysa düzelt ya da `git revert -m 1`.
- Telefon gerektiren ölçüm/doğrulama yapılamazsa "yazıldı, cihazda doğrulanmadı" +
  `docs/CIHAZ_TESTI.md`. Kullanıcı verisini silen/taşıyan göç: önce yedek, geri alınabilir göç.
- Limit freni (5 saatlik): ≥ %80 yeni paket yok, ≥ %90 dur; Fable yalnız %55 altında ve yalnız
  karar/plan evresinde. Kullanıcıya giden her metin Türkçe.

## 4c) Kasma ve hız kapıları (bağlayıcı)
- **Kasma kontrol listesi:** liste/ızgaraya, görüntüleyici kabuğuna ya da ana ekrana GÖRÜNÜR yeni
  alan, kip ya da sarmalayıcı eklerken push'tan önce **`kasma-kontrol` skill'ini** uygula (8 madde).
- **ÖLÇÜM KAPISI:** PDF görüntüleyici, dosya listesi, ana ekran, üst/alt çubuk, klavye ya da
  geçişe dokunan iş `[apk]`'dan önce cihazda A/B ölçülür (taban = önceki `[apk]` profil
  derlemesi, ölçüm kimliği `.r8test`). Ayrıntı ve telefon kuralları: **`ab-olcum` skill'i**.
- **HIZ SÖZLEŞMESİ** (hız anayasası, `PLAN.md` §0): gerileme > %10 ya
  da kare p99 > 24 ms = birleştirme yok; hız işlerinde kötüleşme SIFIR; mandallar
  (`design_tokens_baseline.json`, `PerfBudget`, APK bütçesi) yalnız düşer. **Ölçmeden
  "akıcı/hızlı" denmez.**

## 5) Bağlantılar
- Son release: https://github.com/kaimau1/dosya-okuyucu/releases
- Actions: https://github.com/kaimau1/dosya-okuyucu/actions
