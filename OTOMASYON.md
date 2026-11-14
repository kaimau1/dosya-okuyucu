# OTOMASYON — gözetimsiz iş zinciri

**Kullanıcı izni (2026-11-14):** işleri otomasyonla başlat, istediğin modelde alt ajan aç,
limite göre çalış; test telefonu USB'de (ekranı yalnız gerekince aç); işi bitir, main'e gönder;
token israf etme ama bitmiş iş ver. Gözetimsiz çalış, soru sorma.

"not" projesindeki zincirin aynısı (2026-11-14 taşındı). Bu dosya yalnız YÜRÜTME düzeni + Kuyruk
verisidir; açık işlerin kaynağı `KALANLAR.md` ve faz planları (`docs/FERRARI_PLANI.md` …).
Her tur bu dosyayı BİR kez, baştan okur. Başlatma rehberi: `OTOMASYON_BASLAT.md`.

## Nasıl çalışır

- Zamanlanmış görev `okuyucu-devam` (masaüstü uygulaması, saatlik) oturum başlatır; limit dolunca
  oturum ölür, sonraki tetik **kaldığı yerden** sürer (Kuyruk satırı + dalın `DEVIR.md`'si).
  Bilgisayar uyurken görev çalışmaz.
- Zamanlanmış oturum YENİ OTURUM AÇAMAZ. Paket `Agent` aracıyla ALT AJANA verilir:
  `model: "fable" | "opus" | "sonnet"`, `isolation: "worktree"`, istem = "`isci` skill'ini uygula"
  + paketin satırı. `Agent` reddedilirse ya da o model yoksa paket BU oturumda yapılır; Kuyruk'a
  gerçek model yazılır.
- **Yürütücü ince kalır:** CI izleme, kırmızı CI düzeltme, DEVIR, plan `[x]`, Kuyruk satırı ve
  sürüm notu satırları ALT AJANIN işidir; yürütücü raporu, `git log`/diff özetini ve `gh run`
  sonucunu kontrol eder, birleştirir. Paketler büyük (her alt ajan sıfırdan başlar).
- Aynı anda TEK yürütücü. Kilit: `.git/oto.lock` (içinde ISO zaman, 60 dk).
- Dal: `faz-oto-<no>-<kısa-ad>` (CLAUDE.md §4 "İSTİSNA — Gözetimsiz zincir"); CI yeşilse yerelde
  `git merge --no-ff` ile main'e. `gh pr merge` yok (faz PR başlığı her seferinde APK derletir).
- Eski bulut tetik zinciri (`docs/ZAMANLANMIS_GOREV_ISTEMI.md`, Faz 34–42 `fire_trigger`) tarihseldir
  — o fazlar bitti; bu zincir onun yerine geçmez, onunla çakışmaz (ayrı dal adı, yerel görev).

## Bir turun adımları → `oto-tur` skill'i

Yürütücü: **`oto-tur` skill'i** (`.claude/skills/oto-tur/SKILL.md`; kilit, main sağlığı, paket
seçimi, alt ajan, doğrulama, birleştirme/[apk], temizlik, yarım iş devri, limit freni %80/%90,
FABLE KURALI, diriltme yasağı, takılma önleme, bitiriş).

## İşçi kuralları → `isci` skill'i

Alt ajan istemi: "`isci` skill'ini uygula; raporu Türkçe yaz" + paketin Kuyruk satırı + Kaynak
plan bölümü.

## Telefon ve ölçüm → `ab-olcum` skill'i · kasma → `kasma-kontrol` skill'i

Mi Note 10 Lite, USB: MIUI kurulum onayı (`input tap`, koordinat ekrandan), uyandır/kaydır/uyut,
ısı < 37 °C ölçüm / ≥ 40 °C dur, varsayılan kimlikli uygulamaya dokunma (ölçüm `.r8test`), telefon
tek seferde tek işte.

## FABLE KURALI

Fable yalnız önemli karar/plan evresini yapar (mimari, adım planı); uygulama, test, CI, belge
Opus alt ajanlarına. Fable paketi yalnız 5 saatlik limit **%55 altındayken** başlar; üstündeyse
sıradaki Opus/Sonnet paketi alınır, Fable `bekliyor` kalır ve limit yenilenince EN BAŞTA alınır.
Hesapta Fable yoksa Opus. Limit freni: ≥ %80 yeni paket yok, ≥ %90 dur (`oto-tur` 11. adım).

## Kuyruk

Durum: `bekliyor` · `sürüyor` · `bitti` · `takıldı: <neden>` · `cihaz bekliyor` · `kullanıcı kararı`.
Model: `fable` · `opus` · `sonnet` (+ "plan evresi fable"). Cihaz: `—` · `evet` (cihaz turu) ·
`A/B` (ölçüm kapısı) · `tablet`. APK: `evet` (birleştirme başlığında `[apk]`) · `hayır`.
Satır ≤ ~300 karakter; ayrıntı Kaynak'taki plan bölümünde. 👤 maddeler yapılmaz →
`KONTROL_LISTEM.md`.

| No | İş | Model | Kaynak | Cihaz | APK | Durum |
|---|---|---|---|---|---|---|
| P01 | Ölçüm altyapısı: gözetimsiz A/B betiği (iki derleme/etiket, A,B×2+ sıra, ortanca, en kötü A kıyası, `KARAR:` satırı, ısı beklemesi, MIUI kurulum onayı) + H0.2 büyük PDF senaryosu + H0.3 PDF açılış zaman damgaları | opus | `ab-olcum` "Araç farkı"; FERRARI H0.2–H0.3; `tool/perf_senaryo.sh`, `tool/r8_ab.sh` (`read` bekler) | A/B | hayır | bitti — `tool/ab_olcum.sh` (+`ab_karar.py`), H0.2 senaryo, H0.3 `PDFPRO_PERF acilis_*`; cihaz kuru denemesi DEVIR/HAFIZA |
| P02 | Ferrari H0.1/H0.4 ölçüm tabanı: §2 "10 işlem" bizde (Mi Note 10 Lite), tablo `docs/perf/2026-11-H0.md`; Samsung sütunu 👤 | sonnet | FERRARI H0.1, H0.4, §2 | A/B | hayır | bekliyor — P01'den sonra |
| P03 | Ferrari H6 hareket ve dokunuş (titreşim kapsamı, basma hâli, açılış geçişi + H1.5, liste değişimi, levha birliği, öngörülü geri) | opus | FERRARI H6.1–H6.6, H1.5 | A/B | evet | bitti — main #95 (2026-11-14, başka oturum); H6.4 → P13 |
| P04 | Ferrari H10 + H11: boş/yükleniyor/hata durumları + görüntüleyici kabuğu tutarlılığı (üst/alt çubuk, Office açılışı, görsel, video denetimleri) | opus | FERRARI H10.1–H10.3, H11.1–H11.5 | A/B | evet | kullanıcı kararı — A/B 2 tur KALDI (gürültü şüphesi: 1. tur klasör/galeri/soğuk sıçramaları 2. turda tekrarlanmadı; 2. turda galeri build p90 +%32, pdf_buyuk_50 build p99 +%21; B her çiftte 2–3 °C sıcak başladı), `[apk]`'sız birleşti; tablo docs/perf/2026-11-14-ab-a3c43e8-c8c2915.md |
| P05 | Ferrari H7 sadeleştirme: bildirim envanteri, ipuçları bir kez, geri alınabilene onay yok, ayarlar düzeni; H7.2 menü kısaltma 👤 → yalnız envanter + öneri `KONTROL_LISTEM.md` | opus | FERRARI H7.1–H7.5 | — | evet | bitti — dal faz-oto-P05-sade, CI 43588435506 yeşil: H7.1 bildirim envanteri, H7.3 ipuçları bir kez + sıfırla, H7.4 çöpe atmada onay yok, H7.5 doğrulandı; H7.2 👤 KONTROL_LISTEM 20 |
| P06 | Ferrari H2 PDF kaydırma akıcılığı (önbellek tavanı, bulanık yer tutucu, komşu sayfa, hızlı tutamaç, netleşme, USB okuma hızı) — ölç→değiştir→ölç | opus (plan evresi fable) | FERRARI H2.1–H2.6 | A/B | evet | bekliyor — P01+P02 tabanı gerekir |
| P07 | Ferrari artıkları: H1.4 son sayfa görüntüsü + H8.5 döndür / kareyi fotoğraf kaydet | opus | FERRARI H1.4, H8.5; KALANLAR Faz H | evet | evet | bitti — cihaz bekliyor: dal faz-oto-P07-artik; H1.4 son sayfa görüntüsü (PDF kabuğu → A/B gerekir) + H8.5 döndür / kareyi kaydet; CIHAZ_TESTI "Ferrari H1.4 + H8.5" |
| P08 | PDF Pro oturum belleği bütçe dışı (+56/+65 MB, bütçe +40): `commitLive` → `needsReplay` hep açık, ikinci tam PDFium belgesi (HAFIZA 2026-11-13 bulgusu) — kök neden + ölçüm | opus | KALANLAR Faz E "Oturum belleği bütçe dışı"; HAFIZA 2026-11-13 | A/B | evet | bekliyor |
| P09 | Telefonla cihaz turu: `CIHAZ_TESTI.md` "Ferrari H1/H3/H4/H5/H8" + "Video düzenle" maddeleri (uiautomator, nightly); Drive/hesap maddeleri "denenmedi" | sonnet | KALANLAR Faz H; `docs/CIHAZ_TESTI.md` | evet | hayır | bekliyor — telefon boşken |
| P10 | Ferrari H9 tablet (kalıcı gezinme sütunu ≥ 840 dp, dönüşte konum, kalem/parmak, içerik genişliği, sürükle-bırak) | opus | FERRARI H9.1–H9.5 | tablet | evet | bekliyor — tablet doğrulaması kullanıcıda |
| P11 | Genel cihaz turu (tek telefonla yapılabilenler): `CIHAZ_TESTI.md` baştan sona — Faz 34–42 cihaz maddeleri, Güvenlik G2.6/G3/G4/G6/G8.1/"genel elle tur"/"4. tur", A8.2 soğuk açılış doğrulaması; iki telefon/Bluetooth/AI anahtarı gerekenler "denenmedi" + `KONTROL_LISTEM.md`; kırmızılar Kuyruk'a yeni satır | sonnet | KALANLAR B2, Faz C, Faz F; `docs/CIHAZ_TESTI.md` | evet | hayır | bekliyor — telefon boşken |
| P12 | Excel hızı: B3.3a 10 bin × 20 açılış 7,7–8,9 sn → ≤ 1,5 sn; B3.1 K23 FrameTiming %99; B3.4 kaydırma sürerken pinch; Faz 36 perf A/B | opus (plan evresi fable) | KALANLAR B3.1, B3.3a, B3.4; FAZ_PLANI K23 | A/B | evet | bekliyor |
| P13 | Liste/ızgara hızı: B3.3b 5.000 öğe kaydırma, B3.3c Fotoğraflar ızgarası donma, B3.3 Faz 4 bütçeleri (soğuk açılış ≤ 1,2 sn, %99 ≤ 24 ms), Ferrari H6.4 liste değişim animasyonu (2.000+ öğede kapalı, ölç) | opus | KALANLAR B3.3, B3.3b, B3.3c; FERRARI H6.4 | A/B | evet | bekliyor |
| P14 | Word: B3.3d kapanış/menü takılması kök neden, B3.2 Mobil görünüm editörü (K18) telefonda onay, Faz 37 perf A/B; Slayt Faz 38 perf A/B | opus | KALANLAR B3.2, B3.3d; Faz C | A/B | evet | bitti — A/B bekliyor: Word/Slayt cihaz senaryoları + 300 sayfa/slayt verisi hazır (Faz 37/38 = pro bayrağı kapalı/açık); B3.3d kök neden üretilemedi (telefon meşguldü, HC tek aday); B3.2 → KONTROL_LISTEM 30 |
| P15 | Güvenlik kod artıkları: G6.5 ses sunucusu rastgele yol öneki, G7.1/G7.3 artıkları, G7.4 kayıtta makro, G9.9 ses motoru dosyaları, G10.2 tek belgelik kapatma, G1 imzasız kısayol kolu; 👤 olanlar (G0 e-posta, G9.8 SIGN_CERT, G8.5, G9.5, G9.7, G12.6, Android 7 kararı) → `KONTROL_LISTEM.md` | opus | KALANLAR Faz F; `docs/GUVENLIK_PLANI.md` | evet | evet | bitti — dal `faz-oto-P15-guvenlik`: G6.5 önek, G1 kısayol, G7.3 yazıcılar, G7.4 makro testi, G9.9 SHA-256; G7.1/G10.2 karar (yapılmadı, en güvenli); 👤 → KONTROL_LISTEM 24–29; cihaz `CIHAZ_TESTI.md` "Güvenlik P15" |
| P16 | PDF Pro metin: Faz 57 taşma/çakışma uyarısı + seçenekler, Faz 56 font seçici (belge fontu → aile → paket), Faz 58/7 metne bağlantı ekle/düzenle/kaldır | opus (plan evresi fable) | KALANLAR Faz E; `docs/PDF_PRO_PLANI.md` 56–58 | A/B | evet | bekliyor — Ferrari bitince (plan sürerken yeni özellik yok) |
| P17 | PDF Pro nesne/işaret: Faz 59 hizalama kılavuzu + tutunma, çoklu seçim/grup, katmanlar (OCG), kamera; Faz 60 serbest metin/bulut/damga, basınçlı kalem + avuç içi reddi, XFDF | opus | KALANLAR Faz E; PDF_PRO_PLANI 59–60 | A/B | evet | bekliyor |
| P18 | PDF Pro Faz 61 form + imza tek yüzey, form oluşturma, düz PDF'te alan algılama; Faz 65/3 form otomatik doldurma + akıllı karartma önerisi | opus (plan evresi fable) | PDF_PRO_PLANI 61, 65 | evet | evet | bekliyor |
| P19 | PDF Pro Faz 62 OCR Pro: görünmez katman, arka plan renkli satır düzenleme | opus (plan evresi fable) | PDF_PRO_PLANI 62 | evet | evet | bekliyor |
| P20 | PDF Pro Faz 63 sayfa stüdyosu (küçük resim ızgarası, geri alınabilir sayfa komutları) | opus | PDF_PRO_PLANI 63 | A/B | evet | bekliyor |
| P21 | PDF Pro Faz 64/3–5 parola/izin, meta veri, optimize, PDF/A, yazdır bu kipte; AES-256 (R6) kilit açma; `PdfEditorScreen` emekliliği (filigran + taranmış satır düzeltme yeni kipe) | opus | KALANLAR Faz E; PDF_PRO_PLANI 64 | evet | evet | bekliyor |
| P22 | PDF Pro kalite + ölçüm: başarı %94 → %98 (Type3 aralık, `/Rotate`, açılı metin), Faz 54 ölçüm açıkları (50 sayfa artımlı kayıt, oturum belleği), Faz 66/1,4,5 · 67 · 68 büyük belge/pil, görsel cila | opus | KALANLAR Faz E; PDF_PRO_PLANI 54, 66–68 | A/B | evet | bekliyor — P08 sonrası |
| P23 | UDF (UYAP) okuyucu: biçim araştırması (açık kaynak örnek dosya, yapı), okuma görüntüleyicisi, testler; örnek bulunamazsa `kullanıcı kararı` | opus (plan evresi fable) | KALANLAR Faz D "UDF" | evet | evet | bekliyor |
| P24 | Bağımlılık bakımı: override'lar (`xml`, `pointycastle`, `dartssh2`) — yeni sürüm varsa kaldır; açık Dependabot dalları; Faz 44/48/50 Mi Note artıkları (P5 kuyruğu, xlsx 100 bin uzun kaydırma) | opus | KALANLAR Faz D | A/B | evet | bekliyor |
| P25 | A9.1 levha/pencere birliği: kalan ham `showModalBottomSheet`/`showDialog` → `showAppSheet`/`showAppConfirm`/`showAppPrompt`, parti parti önce/sonra PNG (`tool/design_shots_*`) dalda; onay 👤 `KONTROL_LISTEM.md` → birleştirme onaydan sonra | opus | KALANLAR A9.1 | A/B | evet | bekliyor — P04 sonrası |
| P26 | Mağaza ekran görüntüleri telefonda (son görünüm, TR/EN/AR; düzenleme turu, Yakındakiler, beyaz tema, iş sonucu) → `docs/play/` | sonnet | KALANLAR B2 "Mağaza ekran görüntüleri" | evet | hayır | bekliyor — en sonda (son görünüm) |
| P27 | Ferrari H12 son kapı: §2 "10 işlem" son ölçüm + rakip kıyası; kullanıcı bakışı 👤 | sonnet | FERRARI H12 | A/B | evet | bekliyor — hepsi bitince, kullanıcıyla |

**SIRA (2026-11-14, güncel):** P01 ∥ P05 → P04 ∥ P15 → P09 (telefon) → P02 → P06 → P07 → P08 →
P12 → P13 → P14 → P10 → P11 (telefon) → P16 → P17 → P18 → P19 → P20 → P21 → P22 → P23 → P24 →
P25 → P26 → P27. Paralel kural: kod paketi ∥ kod paketi (dosyaları çakışmayan); telefon/A-B
tek seferde BİR — A/B bekleyen paket, telefon boşalınca ölçülür. 👤 maddeler yapılmaz,
`KONTROL_LISTEM.md`'ye yazılır (B5 Play/Pro/izin, OpenSubtitles, Faz S fiyat/ad, `v*` etiketi,
Xiaomi 13T/GMS'li ikinci cihaz, Faz 53 maket onayı, külliyat üreticileri).
