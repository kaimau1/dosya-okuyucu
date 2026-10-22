# Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)

## Hafıza (usta koordineli — 3 katman)
- Kod yapısı        → `graphify-out/`   (oku: `GRAPH_REPORT.md` · güncelle: `graphify update .` — API maliyeti yok)
- Proje ne/niye     → `HAFIZA.md`       (oku: iş başı · yaz: iş sonu karar/bug-kök/tuzak, tarihli append-only)
  (HAFIZA.md = dizin; eski tarihli kayıtlar `docs/hafiza/YYYY-MM.md` — gerekince ara; ~600 satırı geçince `python tool/hafiza_arsivle.py`)
- Kullanıcı tercihi → `.claude memory/` (otomatik, projeler-arası — proje bilgisi buraya YAZILMAZ)

Yaz kuralı: usta rule 12 / YAZ — kalıcı karar, bug kök nedeni veya yanlış çıkan yol oluştuysa
iş bitmeden HAFIZA.md'ye yaz. KVKK: hasta verisi / TC / ölçüm / token yazma.

## 1) Amaç
Sade, hızlı, ücretsiz, çok formatlı **dosya okuyucu/düzenleyici + dosya yöneticisi**
(2026-07-25: telefondaki tüm dosyalar için pano/gezgin/işlemler — `lib/services/fm/`,
`lib/screens/fm/`; ayrıntı ve kararlar HAFIZA.md). **Yalnız Android**
(K10, 2026-10-21: masaüstü/iOS hedefi kaldırıldı). Gemini AI entegrasyonu, format dönüştürme,
paylaşım. (Firebase senkronu 2026-09-26'da kaldırıldı — HAFIZA.) Piyasadaki yavaş/pahalı programlara alternatif.

> Sabit kararlar, build geçmişi, açık durum ve reddedilen yollar → **HAFIZA.md**
> **Faz planı (2026-10-21) → `docs/FAZ_PLANI.md`** — sıradaki iş, kararlar (K1–K12) ve her fazın
> açılış istemi orada; yeni bir oturum işe oradaki durum tablosundan başlar.

## 2) Mimari / Dosya Haritası
`graphify-out/GRAPH_REPORT.md` — 16.323 düğüm, 23.141 kenar, 573 topluluk (2026-10-21) (App State Management,
Gemini AI Service, Firebase Auth, PPTX Render/Slide Canvas/Slideshow, Word DocxView, Excel Grid …).
Kod değiştikten sonra `graphify update .` (API maliyeti yok).

## 3) CI/CD (.github/workflows/build-apk.yml — Faz 1 düzeni, 2026-10-21)
`changes` → **`verify`** (pub get → analyze → test [+ `ci/` değiştiyse Kotlin denetimi]; her dalda)
∥ **`apk`** (sürüm no → `ci/prepare_android.sh` [iskelet + tüm yamalar, yerelde de koşar] →
`flutter build apk --obfuscate` → apksigner → içerik/16 KB/boyut bütçesi denetimi → artifact + Dart sembolleri)
→ **`release`** (ikisi yeşilse): main → tek **`nightly`** sürüm (üzerine yazılır, "en son" işaretli,
`releases/latest/download/dosya-okuyucu.apk` sabit); **`v*` etiketi** → kalıcı sürüm (arm + arm64 + AAB).
Eski sürümler budanır (nightly hariç son 10). Push'ta yalnız arm64; 32-bit + AAB etikette/elle.
Yalnız `test/**`/`tool/**` değişen push APK derlemez; `**.md`, `docs/**`, `graphify-out/**` hiç koşturmaz.
Art arda push → önceki koşu iptal.

## 4) Çalışma Kuralları
- **Dal:** **TEK DAL — `main`.** (2026-07-27: eski 13 `claude/**` dalı silindi; hepsi
  main'in gerisindeydi, hiçbirinde main'de olmayan iş yoktu.) Yeni dal AÇMA;
  iş doğrudan main'e commit edilir. Push: `git push`.
  Bulut oturumu (`claude/*`, `ccr-*`) dal açtıysa iş main'e girince o uzak dal silinir.
  APK yalnız **main**'e push'ta derlenir (feature dalında sadece `flutter test`).
- **Doğrulama döngüsü:** önce yerelde `C:\src\flutter\bin\flutter.bat test` + `analyze`
  (2026-10-21'den beri yerel ve CI AYNI sürüm: **3.44.6**), sonra push → Actions logunu
  izle, kırmızıysa sormadan düzelt. Yerel APK: temiz kopyada `bash ci/prepare_android.sh`
  + `flutter build apk` (Git Bash'te `python3` yoksa `python`a yönlendiren bir kabuk
  betiği PATH'e). **Bulut (Linux) oturumunda** Flutter 3.44.6 indirilip
  `pub get / analyze / test` koşturulur — tuzaklar HAFIZA 2026-07-25 §F. Kör push etme.
  **`ci/*.kt` değiştiyse `tool/check_kotlin.sh` koştur** (kotlinc + Android
  taslakları; yoksa sessizce atlar). Kotlin yalnız CI'da derleniyordu ve tek
  satırlık bir tür hatası 13 dakikalık bir derleme turunu yakıyordu — bkz.
  HAFIZA 2026-09-02 (on birinci tur).
- **Commit mesajı sonu:** `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  ve `Claude-Session:` satırı.
- Bilinen derleme tuzakları (CardThemeData, platform klasörleri, keystore) → **HAFIZA.md**

## 5) Bağlantılar
- Son release: https://github.com/kaimau1/dosya-okuyucu/releases
- Actions: https://github.com/kaimau1/dosya-okuyucu/actions
