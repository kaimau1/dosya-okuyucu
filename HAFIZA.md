# Dosya Okuyucu — Proje Hafızası

> Kararlar, *niye*'leri, denenip reddedilen yollar ve açık durum burada.
> **Append-only:** eski maddeler silinmez, geçersizse "→ güncellendi/iptal" notu düşülür.
> Kod yapısı buraya yazılmaz (bkz. CLAUDE.md §Hafıza haritası).
> KVKK: hasta verisi / TC / ölçüm / token bu dosyaya YAZILMAZ.

## Sabit Kararlar (tarihli, append-only)

- **2026-07-20 — Teknoloji: Flutter (Dart), CI Flutter sürümü 3.29.3.**
  *Niye:* tek kod tabanıyla mobil + masaüstü. 3.29.3 zorunlu: pdfx engine API'si ve
  compileSdk 35 gerektiriyor, daha eski sürümlerde derlenmiyor (build-1 bu yüzden kırmızı).

- **2026-07-20 — AI: Google Gemini, düz REST çağrısı (paket bağımlılığı yok).**
  *Niye:* ücretsiz kota + bağımlılık şişkinliği istenmedi. Anahtar Ayarlar'dan girilir,
  cihazda SharedPreferences'ta saklanır. Varsayılan model `gemini-2.0-flash`.

- **2026-07-20 — Firebase kodu guard'lı; config repoda YOK.**
  *Niye:* config gizli ve kullanıcıya özel. `Firebase.initializeApp()` guard'lı olduğu için
  config yokken uygulama "yerel mod"da çalışır — kurulum kullanıcıyı bloklamaz.
  Aktifleştirme: `flutterfire configure` veya `google-services.json` (FIREBASE_SETUP.md).

- **2026-07-20 — Office düzenleme: cihaz-içi / offline / ücretsiz, ORTA sadakat.**
  Word/PPT'de orijinal XML korunur, sadece metin düğümleri (`w:t` / `a:t`) güncellenir →
  biçim bozulmadan metin düzenleme + geri kaydetme.
  **REDDEDİLEN yol:** sunucu tabanlı OnlyOffice — kullanıcı açıkça ücretsiz/offline istedi.

- **2026-07-20 — İmzalama: tüm APK'lar sabit anahtarla imzalanır.**
  *Niye:* güncelleme uyumu (anahtar değişirse kullanıcı uygulamayı güncelleyemez).
  Anahtar repoda TUTULMAZ; `ANDROID_KEYSTORE_B64` GitHub secret'ından yüklenir. Secret yoksa
  CI geçici anahtar üretip base64'ünü loglar (SIGNING.md). Parola workflow'da sabit:
  `DosyaOkuyucuKey2026`, alias `dosyaokuyucu`.

- **2026-07-20 — Bildirim: başarılı derlemede release linki Gmail *taslağı* olarak hazırlanır**
  (hekimasistanitr@gmail.com). *Niye:* doğrudan gönderme aracı yok, sadece taslak mümkün.

- **2026-07-21 — Hafıza 3 katmana ayrıldı** (bu dosya + CLAUDE.md haritası + graphify).
  *Niye:* CLAUDE.md her oturumda otomatik yükleniyor; append-only karar listesi orada
  büyüyünce her oturumun token maliyeti artıyordu. Kararlar buraya, kurallar orada kaldı.
  graphify kuruldu (390 düğüm / 522 kenar / 22 topluluk) → CLAUDE.md'deki elle yazılmış
  dosya haritası silindi, yerine `graphify-out/GRAPH_REPORT.md` geçti (tek kaynak).
  `graphify-out/cache/` ve tarihli yedek klasörleri .gitignore'a eklendi; rapor+graf commitlenir.

- **2026-07-21 — Slayt görüntüleme: kendi Flutter renderer'ımız** (`services/pptx_render.dart`
  + `widgets/slide_canvas.dart`). Slayt XML'i punto koordinatlara çözülür, Flutter widget'ı
  olarak çizilir: arka plan, düzen/master grafikleri, şekil dolgu+çerçeve, görsel, grup
  dönüşümü, tablo hücreleri, biçimli metin (boyut/kalın/italik/renk/hizalama/madde).
  *Niye:* kullanıcı "PowerPoint'te nasıl görünüyorsa aynısı" istedi; metin listesi yetmiyordu.
  **REDDEDİLEN yol:** WebView + PPTXjs — jQuery bağımlılığı, APK şişmesi, orta sadakat.
  Metin düzenleme kutuya dokununca açılır, `<a:t>` güncellenir → tasarım bozulmaz.
  *Kapsam dışı (bilinçli):* SmartArt, grafik (chart), animasyon, gradient dolgu, gömülü fontlar.

- **2026-07-21 — DÜZELTME: yerelde Flutter VAR** (`C:\src\flutter`, sürüm 3.44.6).
  Artık doğrulama = `flutter test` + `flutter analyze` (yerel), sonra CI derlemesi.
  **Dikkat:** yerel 3.44 ≠ CI 3.29.3 → yerelde `withOpacity` "deprecated" uyarısı verir ama
  CI'da GEREKLİ, `withValues`'a çevirme (3.29'da yok). Uyarı normaldir, hata değildir.

- **2026-07-21 — Word: gömülü docx-preview + WebView; Excel: excel paketinin kendi stili.**
  *Niye:* Word'ün sayfa akışı (satır/sayfa kırma, stil mirası) elle yazılırsa %70 sadakatte
  kalıyor; olgun motor `assets/word/`e gömüldü (jszip MIT + docx-preview Apache-2.0, LICENSES.txt).
  İnternet gerekmez, WebView yalnızca yerel dosya açar. Excel'de tam tersi: `excel` paketi
  genişlik/yükseklik/stil/birleşik hücre bilgisini zaten veriyor → kendi styles.xml ayrıştırıcım
  YAZILMADI. **REDDEDİLEN yol:** Excel için WebView (x-spreadsheet) — gereksiz, ızgara Flutter'da daha iyi.

- **2026-07-21 — Sunum modu + animasyon yaklaşımı.** `p:timing/mainSeq` içindeki her `p:par`
  bir tıklama adımı sayılır; hedefler `p:spTgt@spid` (+ `p:pRg` paragraf aralığı). Efekt türü/süresi
  OKUNMAZ — beliriş jenerik (fade + hafif kayma). *Niye:* PowerPoint'te 100+ efekt var, akış
  önemli, efektin kendisi değil. Sunum modu tam ekran + yatay + zoom (InteractiveViewer).

## Build Geçmişi

| # | Sonuç | Not |
|---|---|---|
| build-1 | ❌ | pdfx engine API + compileSdk 34 (Flutter 3.24.5 uyumsuz) |
| build-2 | ✅ | Flutter 3.29.3'e yükseltildi |
| build-3 | ✅ | Firebase (guard'lı) eklendi, minSdk 23 |
| build-4 | ✅ | Office biçimli editörler (Excel / Word / Slayt) |
| build-5 | ✅ | Sabit imza (apksigner + secret bootstrap) — imzalı release üretildi |
| build-8 | ✅ | PPTX gerçek tasarım renderer'ı + CI'ya `flutter test` adımı (4/4 yeşil) |
| build-9 | ❌ | Secret'a yapışan CR → `base64: invalid input` (aşağıdaki tuzak) |
| build-10 | ✅ | **Kalıcı imzalı ilk sürüm** (SHA-256 `9eef6704…`), telefona kuruldu ve açıldı |
| build-11 | ✅ | Tam ekran sunum modu + zoom; kaldırmadan güncelleme ilk kez çalıştı |
| build-12..16 | ✅ | Animasyon adımları, Word sayfa görünümü (WebView), Excel ızgarası. APK 57 MB |

## Açık Durum / Bekleyenler

- ~~Kalıcı imza — kullanıcı aksiyonu bekliyor~~ → **ÇÖZÜLDÜ 2026-07-21:** kalıcı keystore
  üretildi ve `ANDROID_KEYSTORE_B64` secret'ı olarak eklendi. Artık her CI derlemesi AYNI
  anahtarla imzalanır → yeni APK eskisinin üstüne kurulur.
  - Anahtar dosyası: `C:\Users\sena\Desktop\dosya-okuyucu-imza\release.jks` (repo DIŞINDA).
    Parmak izi SHA-256 `9E:EF:67:04:C8:6F:74:76:...:4C:57:37:18`, alias `dosyaokuyucu`.
  - **Bu dosyayı kaybetmek = bir daha güncelleme yayınlayamamak.** Yedekle (repoya değil).
  - Parola workflow'da açık yazıyor ama repo PRIVATE; anahtar dosyası olmadan parola işe yaramaz.
- ~~main dalı yok~~ → **ÇÖZÜLDÜ 2026-07-21:** `main` oluşturuldu ve reponun varsayılan dalı
  yapıldı; yerel çalışma da `main`e alındı. Eski `claude/multi-format-file-reader-c9gh78` dalı
  aynı commit'te duruyor (silinmedi). Artık PR açılabilir.
- **Firebase config:** gerçek senkron için kullanıcı `flutterfire configure` yapmalı.

## Bilinen Riskler / Tuzaklar

- ~~Yerelde Flutter YOK~~ → **güncellendi 2026-07-21:** `C:\src\flutter\bin\flutter.bat` ile
  yerelde `test`/`analyze` çalışıyor; APK derlemesi yine CI'da doğrulanır.
- **Slaytta metin kutudan taşarsa** Column "RenderFlex overflowed" (sarı-siyah şerit) verir.
  Çözüm: `OverflowBox` (metin PowerPoint'teki gibi taşar, kırpılmaz). Widget testi yakaladı —
  `test/pptx_render_test.dart` bu yüzden var, silme.
- **Flutter API uyumu:** `withOpacity` / `value:` kullanıldı (3.29 uyumu).
  `CardThemeData` KULLANMA — sürüm hassas, derlemeyi kırar.
- **Platform klasörleri (`android/`, `ios/`) repoda yok**, CI'da `flutter create` ile üretilir.
  Yerelde de aynı adım gerekir (README).
- **Gizli anahtar / keystore repoya COMMIT EDİLMEZ** — güvenlik sınıflandırıcısı da engeller.
- **2026-07-21 TUZAK — `excel` paketinde iki hata (4.0.6):**
  1) Hizalama HİÇBİR dosyada okunmuyor: `parse.dart:445` `<alignment>` çocuğu yerine üst `<xf>`
     düğümünün özniteliklerine bakıyor. Çözüm: sayı/tarih hücrelerini varsayılan olarak sağa
     yasladık; açık hizalama beklemeyin (paket düzelirse kod kendiliğinden çalışır).
  2) `getColumnWidth/getRowHeight`, dosyada `defaultColWidth` yoksa **null hatası fırlatıp
     uygulamayı çökertiyor** (ICD10Listesi.xlsx'te yakalandı) → `xlsx_editor` içinde try/catch.
  *Ders:* gerçek dosyalarla duman testi yapmadan "çalışıyor" deme; sentetik dosya bu iki hatayı
  da göstermedi.
- **2026-07-21 TUZAK — Flutter'da çift dokunuş tek dokunuşu 300 ms geciktirir**
  (`kDoubleTapTimeout`). Sunum modunda dokunarak geçişte his gecikmeli; test de bu süreyi
  ilerletmeli (`pumpAndSettle` tek başına yetmez, zamanlayıcı kare planlamaz).
- **2026-07-21 TUZAK — örtük animasyon (AnimatedOpacity/AnimatedSlide) yapı değişirse oynamaz:**
  görünür durumda widget'ı sarmalayıp gizli durumda sarmalamazsan geçiş anında olur. İki durumda
  da aynı ağaç kalmalı (`_Reveal`).
- **2026-07-21 TUZAK — PowerShell borusu secret'a CR ekler:** `... | gh secret set X` ile
  yazılan base64'ün sonuna CRLF yapışıyor, CI'da `base64 -d` "invalid input" veriyor (build-9).
  Secret yazarken bash yönlendirmesi kullan: `gh secret set X < dosya` (dosyada CR/LF olmasın).
  Workflow artık `printf '%s' | tr -d '\r\n \t' | base64 -d` ile kendini koruyor.
- **İmza değişirse telefona kurulmaz:** `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Android, imzası
  farklı APK'yı mevcut verinin üstüne kurdurmaz → tek yol eskisini kaldırmak (uygulama verisi,
  yani kayıtlı Gemini anahtarı ve son dosyalar silinir). 2026-07-21'deki sabit anahtardan sonra
  bu bir daha yaşanmamalı. Kurulum: `adb install -r <apk>`; adb `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
- `**.md` değişiklikleri CI'ı tetiklemez (workflow `paths-ignore`).
- **2026-07-21 TUZAK — graphify sandbox'ta çalışmaz:** ajan sandbox'ı DNS'i kesiyor,
  hata "Connection error" diye görünüyor → kota sanılıp boşuna key/model değiştiriliyor.
  Kök neden: `generativelanguage.googleapis.com` çözülemiyor. graphify'ı ağ erişimiyle çalıştır.
- **2026-07-21 TUZAK — repoda oturum başı otomatik `git pull` hook'u var**
  (`.claude/settings.json`, commit `d58fa94`). Oturum ortasında sessizce yeni commit
  getirebilir; beklenmedik bir üst commit görürsen sebebi budur, panik yapma.

## Yol Haritası (öncelik kullanıcıyla netleşecek)

1. Office ileri düzenleme: Excel formül + satır/sütun ekleme; Word biçim araç çubuğu
   (kalın/italik/liste); slayta yeni slayt/görsel ekleme.
2. Firebase config ile gerçek senkron + Google Sign-In SHA ekleme.
3. Format dönüştürme zenginleştirme (PDF ↔ Word ↔ Slayt).
4. AI: PDF'den otomatik slayt üretimi (genişletilmiş), kaynakları bağlama alma.
5. Masaüstü (Windows/macOS/Linux) build hedefleri + iOS.
