# Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)

## Hafıza (usta koordineli — 3 katman)
- Kod yapısı        → `graphify-out/`   (oku: `GRAPH_REPORT.md` · güncelle: `graphify update .` — API maliyeti yok)
- Proje ne/niye     → `HAFIZA.md`       (oku: iş başı · yaz: iş sonu karar/bug-kök/tuzak, tarihli append-only)
- Kullanıcı tercihi → `.claude memory/` (otomatik, projeler-arası — proje bilgisi buraya YAZILMAZ)

Yaz kuralı: usta rule 12 / YAZ — kalıcı karar, bug kök nedeni veya yanlış çıkan yol oluştuysa
iş bitmeden HAFIZA.md'ye yaz. KVKK: hasta verisi / TC / ölçüm / token yazma.

## 1) Amaç
Sade, hızlı, ücretsiz, çok formatlı **dosya okuyucu/düzenleyici + dosya yöneticisi**
(2026-07-25: telefondaki tüm dosyalar için pano/gezgin/işlemler — `lib/services/fm/`,
`lib/screens/fm/`; ayrıntı ve kararlar HAFIZA.md). Hem mobil hem
masaüstü (tek Flutter kod tabanı). Gemini AI entegrasyonu, format dönüştürme,
paylaşım, Firebase ile senkron. Piyasadaki yavaş/pahalı programlara alternatif.

> Sabit kararlar, build geçmişi, açık durum ve reddedilen yollar → **HAFIZA.md**

## 2) Mimari / Dosya Haritası
`graphify-out/GRAPH_REPORT.md` — 953 düğüm, 1740 kenar, 49 topluluk (App State Management,
Gemini AI Service, Firebase Auth, PPTX Render/Slide Canvas/Slideshow, Word DocxView, Excel Grid …).
Kod değiştikten sonra `graphify update .` (API maliyeti yok).

## 3) CI/CD (.github/workflows/build-apk.yml)
Push'ta (main / feature dalı, `**.md` hariç): Flutter kur → `flutter create` ile
android iskeleti → AndroidManifest'e INTERNET izni + app adı → minSdk 23 patch →
`flutter pub get` → `flutter build apk --release` → **sabit anahtarla imzala (apksigner)**
→ artifact yükle → **GitHub Release** oluştur (tag `v0.1.0-build-<run_number>`).

## 4) Çalışma Kuralları
- **Dal:** **TEK DAL — `main`.** (2026-07-27: eski 13 `claude/**` dalı silindi; hepsi
  main'in gerisindeydi, hiçbirinde main'de olmayan iş yoktu.) Yeni dal AÇMA;
  iş doğrudan main'e commit edilir. Push: `git push`.
  APK yalnız **main**'e push'ta derlenir (feature dalında sadece `flutter test`).
- **Doğrulama döngüsü:** önce yerelde `C:\src\flutter\bin\flutter.bat test` + `analyze`
  (sürüm 3.44 — uyarılar CI'nin 3.29.3'üyle farklı, bkz. HAFIZA), sonra push → Actions
  logunu izle, kırmızıysa sormadan düzelt. APK derlemesi yalnızca CI'da doğrulanır.
  **Bulut (Linux) oturumunda da doğrulama yapılabilir:** Flutter 3.29.3 (CI ile aynı
  sürüm) indirilip `pub get / analyze / test` koşturulur — ayrıntı ve tuzaklar
  HAFIZA 2026-07-25 §F. Kör push etme.
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
