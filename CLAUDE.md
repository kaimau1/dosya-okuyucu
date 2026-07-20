# Dosya Okuyucu — Proje Hafızası (CLAUDE.md)

> Bu dosya projenin **kalıcı hafızasıdır**. Her yeni oturum buradan devam eder.
> Önemli kararlar, mimari, yapılanlar ve yol haritası burada tutulur.
> Not: `**.md` değişiklikleri CI'ı tetiklemez (workflow `paths-ignore`).

## 1) Amaç
Sade, hızlı, ücretsiz, çok formatlı **dosya okuyucu/düzenleyici**. Hem mobil hem
masaüstü (tek Flutter kod tabanı). Gemini AI entegrasyonu, format dönüştürme,
paylaşım, Firebase ile senkron. Piyasadaki yavaş/pahalı programlara alternatif.

## 2) Sabit Kararlar
- **Teknoloji:** Flutter (Dart). CI Flutter sürümü **3.29.3** (pdfx engine API +
  compileSdk 35 gerektirir; daha eski sürümlerde derlenmez).
- **AI:** Google **Gemini**, REST ile (paket bağımlılığı yok). Anahtar Ayarlar'dan
  girilir; cihazda SharedPreferences'ta saklanır. Varsayılan model `gemini-2.0-flash`.
- **Firebase:** Kod hazır ama **config repoda yok**. `Firebase.initializeApp()`
  guard'lı; config yoksa uygulama "yerel mod"da çalışır. Aktifleştirme: `flutterfire
  configure` veya `google-services.json` (bkz. FIREBASE_SETUP.md).
- **Office düzenleme:** Cihaz-içi/offline/ücretsiz, **ORTA sadakat**. Word/PPT'de
  orijinal XML korunur, yalnızca metin düğümleri (`w:t`/`a:t`) güncellenir → biçim
  bozulmadan metin düzenleme + geri kaydetme. (Sunucu tabanlı OnlyOffice YÖNTEMİ
  REDDEDİLDİ — kullanıcı ücretsiz/offline istedi.)
- **İmzalama:** Tüm APK'lar sabit anahtarla imzalanır (güncelleme uyumu). Anahtar
  repoda tutulmaz; `ANDROID_KEYSTORE_B64` **GitHub secret**'ından yüklenir. Secret
  yoksa CI geçici anahtar üretip base64'ünü loglar (bkz. SIGNING.md). Parola workflow'da
  sabit: `DosyaOkuyucuKey2026`, alias `dosyaokuyucu`.
- **Bildirim:** Başarılı derlemede release linki e-posta (Gmail) ile
  hekimasistanitr@gmail.com adresine taslak olarak hazırlanır.

## 3) Mimari / Dosya Haritası
```
lib/
  main.dart                     # giriş; AppState.init (+ Firebase guard'lı)
  core/
    app_state.dart              # tema, API key, recents, AI hafıza, Firebase auth+sync
    theme.dart                  # Material 3, açık/koyu
  models/
    document.dart               # DocKind (pdf/text/spreadsheet/word/slides/image)
    recent_file.dart
  services/
    file_service.dart           # dosya seç/tür tespit/metin çıkarımı
    office_reader.dart          # docx/pptx düz metin çıkarımı (AI bağlamı için)
    gemini_service.dart         # Gemini REST (chat + dosya bağlamı + hafıza)
    conversion_service.dart     # metin→PDF, metin→slayt(PDF)
    firebase_service.dart       # guard'lı init, e-posta/Google giriş, Firestore pull/push
    docx_editor.dart            # .docx paragraf düzenle + biçim koruyarak kaydet
    pptx_editor.dart            # .pptx a:p/a:t düzenle + tasarım koruyarak kaydet
    xlsx_editor.dart            # .xlsx hücre düzenle + kaydet (excel paketi)
  screens/
    home_screen.dart            # son dosyalar; türe göre yönlendirme
    viewer_screen.dart          # pdf(pdfx)/metin/görsel + dönüştür/paylaş
    chat_screen.dart            # AI sohbet + "hafızaya kaydet"
    settings_screen.dart        # API key/model/tema/hesap(senkron)/AI hafıza
    editors/
      spreadsheet_editor_screen.dart  # Excel benzeri grid
      word_editor_screen.dart         # Word benzeri sayfa
      slides_editor_screen.dart       # 16:9 slayt kartları
  widgets/file_type_icon.dart
```
- **Not:** `android/`, `ios/` vb. platform klasörleri repoda YOK; CI'da `flutter create`
  ile üretilir (bkz. `.gitignore`). Yerelde de aynı adımla üretilir (README).

## 4) CI/CD (.github/workflows/build-apk.yml)
Push'ta (main / feature dalı, `**.md` hariç): Flutter kur → `flutter create` ile
android iskeleti → AndroidManifest'e INTERNET izni + app adı → minSdk 23 patch →
`flutter pub get` → `flutter build apk --release` → **sabit anahtarla imzala (apksigner)**
→ artifact yükle → **GitHub Release** oluştur (tag `v0.1.0-build-<run_number>`).

## 5) Build Geçmişi
- build-1 ❌ pdfx engine API + compileSdk 34 (Flutter 3.24.5 uyumsuz)
- build-2 ✅ Flutter 3.29.3'e yükseltildi
- build-3 ✅ Firebase (guard'lı) eklendi, minSdk 23
- build-4 ✅ Office biçimli editörler (Excel/Word/Slayt)
- build-5 ✅ Sabit imza (apksigner + secret bootstrap) — imzalama adımı yeşil, imzalı release üretildi

## 6) Açık Durum / Bekleyenler
- **build-5 ✅ doğrulandı:** İmzalama adımı yeşil; imzalı release üretildi.
- **Kalıcı imza (kullanıcı aksiyonu bekliyor):** build-5 logundaki base64'ü
  `ANDROID_KEYSTORE_B64` secret'ı olarak ekle (SIGNING.md). Eklenene kadar her build
  kendi geçici anahtarını üretir; gerçek dağıtımdan önce bu yapılmalı.
- **PR:** Depoda `main` dalı yok (ilk push feature dalına yapıldı) → PR açılamadı.
  main oluşturulursa PR açılabilir (kullanıcı izni gerekir; feature dalına push yapılıyor).
- **Firebase config:** Gerçek senkron için kullanıcı `flutterfire configure` yapmalı.

## 7) Yol Haritası (öncelik sırası kullanıcıyla netleşecek)
1. Office ileri düzenleme: Excel formül/satır-sütun ekleme; Word biçim araç çubuğu
   (kalın/italik/liste); slayta yeni slayt/görsel ekleme.
2. Firebase config ile gerçek senkron + Google Sign-In SHA ekleme.
3. Format dönüştürme zenginleştirme (PDF↔Word↔Slayt).
4. AI: PDF'den otomatik slayt üretimi (genişletilmiş), kaynakları bağlama alma.
5. Masaüstü (Windows/macOS/Linux) build hedefleri + iOS.

## 8) Çalışma Kuralları / İpuçları
- **Dal:** `claude/multi-format-file-reader-c9gh78`. Push: `git push -u origin <dal>`.
- **Doğrulama döngüsü:** Yerelde Flutter YOK → CI derlemesi doğrulamadır. Push et,
  Actions logunu izle, kırmızıysa sormadan düzelt.
- **Flutter API uyumu:** withOpacity/`value:` kullanıldı (3.29 uyumu). CardThemeData
  KULLANMA (sürüm hassas).
- **Commit mesajı sonu:** `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  ve `Claude-Session:` satırı.
- **Gizli anahtar/keystore'u repoya COMMIT ETME** (güvenlik sınıflandırıcısı engeller;
  secret kullan).
- E-posta: Gmail sadece **taslak** oluşturur (doğrudan gönderme aracı yok).

## 9) Bağlantılar
- Son release: https://github.com/kaimau1/dosya-okuyucu/releases
- Actions: https://github.com/kaimau1/dosya-okuyucu/actions
