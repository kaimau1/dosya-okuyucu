# Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)

## Hafıza (usta koordineli — 3 katman)
- Kod yapısı        → `graphify-out/`   (oku: `GRAPH_REPORT.md` · güncelle: `graphify update .` — API maliyeti yok)
- Proje ne/niye     → `HAFIZA.md`       (oku: iş başı · yaz: iş sonu karar/bug-kök/tuzak, tarihli append-only)
- Kullanıcı tercihi → `.claude memory/` (otomatik, projeler-arası — proje bilgisi buraya YAZILMAZ)

Yaz kuralı: usta rule 12 / YAZ — kalıcı karar, bug kök nedeni veya yanlış çıkan yol oluştuysa
iş bitmeden HAFIZA.md'ye yaz. KVKK: hasta verisi / TC / ölçüm / token yazma.

## 1) Amaç
Sade, hızlı, ücretsiz, çok formatlı **dosya okuyucu/düzenleyici**. Hem mobil hem
masaüstü (tek Flutter kod tabanı). Gemini AI entegrasyonu, format dönüştürme,
paylaşım, Firebase ile senkron. Piyasadaki yavaş/pahalı programlara alternatif.

> Sabit kararlar, build geçmişi, açık durum ve reddedilen yollar → **HAFIZA.md**

## 2) Mimari / Dosya Haritası
`graphify-out/GRAPH_REPORT.md` — 390 düğüm, 522 kenar, 22 topluluk (App State Management,
Gemini AI Service, Firebase Authentication Service, Word/Slides/Spreadsheet Editor …).
Kod değiştikten sonra `graphify update .` (API maliyeti yok).

## 3) CI/CD (.github/workflows/build-apk.yml)
Push'ta (main / feature dalı, `**.md` hariç): Flutter kur → `flutter create` ile
android iskeleti → AndroidManifest'e INTERNET izni + app adı → minSdk 23 patch →
`flutter pub get` → `flutter build apk --release` → **sabit anahtarla imzala (apksigner)**
→ artifact yükle → **GitHub Release** oluştur (tag `v0.1.0-build-<run_number>`).

## 4) Çalışma Kuralları
- **Dal:** `claude/multi-format-file-reader-c9gh78`. Push: `git push -u origin <dal>`.
- **Doğrulama döngüsü:** önce yerelde `C:\src\flutter\bin\flutter.bat test` + `analyze`
  (sürüm 3.44 — uyarılar CI'nin 3.29.3'üyle farklı, bkz. HAFIZA), sonra push → Actions
  logunu izle, kırmızıysa sormadan düzelt. APK derlemesi yalnızca CI'da doğrulanır.
- **Commit mesajı sonu:** `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  ve `Claude-Session:` satırı.
- Bilinen derleme tuzakları (CardThemeData, platform klasörleri, keystore) → **HAFIZA.md**

## 5) Bağlantılar
- Son release: https://github.com/kaimau1/dosya-okuyucu/releases
- Actions: https://github.com/kaimau1/dosya-okuyucu/actions
