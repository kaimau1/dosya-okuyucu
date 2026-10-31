# Dosya Okuyucu — Kapsamlı İnceleme Raporu ve Faz Planı

> **Tarih:** 2026-10-21 · **İncelenen sürüm:** `main` @ `a066e8e` (v1.0.379)
> **Yöntem:** kodun tamamı üzerinde betikli tarama (dosya erişilebilirlik grafiği,
> sembol referans sayımı, desen aramaları), CI ile aynı sürümde (Flutter 3.29.3)
> `flutter analyze` + tam test takımı, son CI koşusunun (#379) adım adım süreleri,
> 180 çözümlenmiş paketin LICENSE dosyalarının taranması, yerel kütüphanelerin
> (`.so`) ELF hizalama ölçümü, gömülü fontların ad tablolarının okunması,
> HAFIZA.md / KALANLAR.md geçmişi.
>
> **Bu belge bir PLANDIR — kod değişikliği içermez.** Her faz ayrı bir oturumda,
> sırayla uygulanmak üzere yazıldı. Fazlar tamamlandıkça §0'daki durum tablosu
> güncellenir.
>
> **Ek (2026-10-22) — görsel ve kullanım deneyimi turu:** `main` @ `0772995`
> üzerinde ikinci bir tarama (liste/süzgeç/boyutlandırma akışları satır satır,
> simge/renk/yazı/RTL kullanım sayımları, erişilebilirlik testleri, Android 16
> davranış değişiklikleri ve rakip uygulama araştırması). Bulgular **§3.14**
> (G1–G21), yeni kararlar **K13–K17**, yeni fazlar **Faz 13–19** ve kalan
> fazlarla birlikte **bulutta yapılabilenleri öne alan yürütme sırası §0.1**.
>
> **Ek (2026-10-23) — düzenleme turu ("telefonda Office gibi düzenleme"):**
> `main` @ `525f24b` üzerinde altı editörün (Word, Excel, Slayt, PDF, metin,
> görsel) denetimi + M365/Google/Apple mobil düzenleme dili + Android klavye ve
> editör motoru araştırması. Ayrı belge: **`docs/DUZENLEME_PLANI.md`** — bulgular
> (ED/W/X/SL/PD/TX/IM), kararlar **K18–K25**, fazlar **Faz 20–33**, kendi
> yürütme sırası (D1–D14) ve her fazın açılış istemi.

---

## İçindekiler

0. [Bu belge nasıl kullanılır + durum tablosu](#0-bu-belge-nasıl-kullanılır)
   — [0.1 Yürütme sırası (2026-10-22, bulut önce)](#01-yürütme-sırası-2026-10-22--bulutta-yapılabilenler-önce)
1. [Yönetici özeti](#1-yönetici-özeti)
2. [Mevcut durum — ölçümler](#2-mevcut-durum--ölçümler)
3. [Bulgular (alan alan)](#3-bulgular) — [3.14 Görsel ve kullanım deneyimi (G1–G21)](#314-görsel-ve-kullanım-deneyimi-2026-10-22)
4. [Senin vermen gereken kararlar (K1–K17)](#4-kararlar)
5. [Hedef bilgi mimarisi (sadeleşmiş menü ağacı)](#5-hedef-bilgi-mimarisi)
6. [Fazlar (Faz 0 – Faz 19)](#6-fazlar)
7. [Ekler](#7-ekler)

---

## 0. Bu belge nasıl kullanılır

- **Sıra:** Faz 0 → Faz 10 bu sırayla yapıldı. **2026-10-22'den itibaren sıra
  §0.1'deki yürütme tablosudur** (faz numarası değil): bulut oturumunda
  bitirilebilen işler önce, telefon gerektirenler tek bir cihaz turunda, hesap/
  karar gerektirenler en sonda. Her faz bir oturum; büyük olanlar gerekirse iki
  oturuma bölünür — fazın içinde "Bölünürse" satırı nerede kesileceğini söyler.
- **Oturum açılışı:** fazın sonundaki **"Açılış istemi"** kutusunu yeni oturuma
  aynen yapıştır. İstem; bu belgenin ilgili bölümünü okumayı, kabul ölçütlerini
  sağlamayı, HAFIZA'ya yazmayı ve main'e birleştirmeyi zaten içeriyor.
- **Her fazın "bitti" tanımı (ortak):**
  1. `flutter analyze` 0 sorun, `flutter test` tamamı yeşil (Flutter 3.29.3 —
     ya da Faz 7'den sonra yeni sürüm);
  2. fazın **kabul ölçütleri** tek tek işaretli;
  3. HAFIZA.md'ye tarihli kayıt (karar + kök neden + tuzak);
  4. bu belgede durum satırı ✅ + tarih + sürüm numarası;
  5. main'e birleştirilmiş, CI yeşil.
- **Kararlar:** §4'teki K1–K12 Faz 0'da cevaplandı; K13–K17 (2026-10-22)
  ilgili fazın başında sorulur ve cevap §4 tablosuna yazılır. Sonraki fazlar
  bu cevaplara göre dallanır; cevap yoksa fazdaki "varsayılan" (öneri)
  uygulanır.

### Durum tablosu

| Faz | Konu | Ön koşul | Durum |
|---|---|---|---|
| 0 | Kararlar + proje hijyeni (HAFIZA/KALANLAR/README/graphify) | — | ✅ 2026-10-21 — K1–K12; HAFIZA 13.046 → 330 satırlık dizin + `docs/hafiza/` arşivi (içerik birebir, `tool/hafiza_arsivle.py`); 37 cihaz maddesi → `CIHAZ_TESTI.md`; README/CLAUDE.md; graphify güncel. Uzak dal silme izinle engellendi — kullanıcıda |
| 1 | CI/CD hızlandırma ve sürüm hattı | 0 | ✅ 2026-10-21 — C1–C12; verify 4,5 dk; main süresi Gradle önbelleği dolduktan sonra yeniden ölçülecek (bkz. HAFIZA) |
| 2 | Sadeleştirme I — ölü kod, eski yollar, özellik birleştirme/çıkarma | 0, 1 | ✅ 2026-10-21 — ölü kod, İnsanlar, görünüm 10/10/6→4/3/3, Geçmiş/Aktar/Depolama/AI/tek Kasa; satır ölçütü K5/K8 kararlarıyla tutmadı (bkz. Faz 2 notu) |
| 3 | Sadeleştirme II — uzun dosyaları bölme + durum yönetimi | 2 | ✅ 2026-10-21 — 19 ekran + çeviri tablosu + formül motoru bölündü (800+ satırlı ekran yok); kök yalnız `AppearanceState`i izliyor; Browse/Clipboard/Remotes/AI bildiricileri ayrılmadı (bkz. HAFIZA) |
| 4 | Performans — düşük donanım profili ve ölçüm | 3 | 🟡 2026-10-21 — profil + bütçeler + açılış kuyruğu + P2-P12 kodda (P10: arama isolate'i, 2026-10-21 (5)); **cihaz kaydırma/RSS ölçümü bekliyor** (`docs/perf/2026-10-21.md`; soğuk açılış 1.0.379'da ~620 ms ölçüldü) |
| 5 | Son kullanıcı iletişimi altyapısı (hata dili, izin/boş/çevrimdışı durumları) | 3 | ✅ 2026-10-21 — `UserError`, `PermissionGate`, `ensureAiKey`, Yardım iskeleti, bekçiler; servis içi boş catch'ler sınıflandırılmadı (bkz. HAFIZA) |
| 6 | Klasör içi / gezgin / filtre / simge yeniden tasarımı | 4, 5 | ✅ 2026-10-21 — `583f5a3`: FmFileListView, yol hapları geri gider (B1/B2), simge tablosu, tablet iki bölme (HAFIZA kaydı yazılmamıştı — commit mesajından) |
| 7 | Bağımlılık diyeti, Flutter yükseltmesi, lisans uyumu, APK boyutu | 2, K1–K5 | ✅ 2026-10-21 — `dc9e613` excel/lisans/font + (5): **Flutter 3.44.6** (CI varsayılanı), kullanımdan kaldırmalar, AGP 9 yamaları, `receive_sharing_intent` 1.8.1; K2 Media3 → Faz 10'da yapıldı |
| 8 | PDF akışı (tek çatı) | 6, 7 | ✅ 2026-10-21 — tek "Düzenle" kapısı (6 kip), eski yol silindi (K12), "yazı ekle" yedeği, Aa levhası, örnek set + duman; vurgu+CropBox cihazda (bkz. HAFIZA (4)) |
| 9 | Office ve metin akışları (Word, Excel, Slayt, Metin/CSV/MD) | 6, 7 | ✅ 2026-10-21 — Y1 (tablo hücresi, seçime punto, resim ekle/sil), Y2 (grafik, köşegen, sayfa taşı), Y4, büyük metin, eski Office dönüştür; Word yazım köprüsü hatası bulundu-düzeltildi; 10 bin satır ölçümü cihazda |
| 10 | Medya akışları (görsel, video, ses, galeri) + temel görsel düzenleyici | 6, 7 | 🟡 2026-10-21 — görsel düzenleyici, PiP (`SYSTEM_ALERT_WINDOW` kalktı), tek motor (`audioplayers` kalktı), Media3 Transformer (FFmpeg + `video_compress` kalktı); örnek medya seti ve cihaz turu bekliyor (bkz. HAFIZA (5)) → **10b** (☁️, yürütme sırası 2) + cihaz turu | · **10b ✅ 2026-10-22** — örnek set `test/fixtures/media/` + `media_fixture_smoke_test`; B11: çıktı doğru, `probeSize` ham ölçüyordu → düzeltildi; FLAC etiketleri eklendi
| 11 | Ticari yayın hazırlığı (Play politikaları, ilk açılış, gelir modeli, mağaza) — 2026-10-22: **11a** bulut kısmı · **11b** hesap/cihaz kısmı | 8–10 | 🟡 11a ✅ 2026-10-22 (rehber, PopScope/tahminli geri, Keystore, Yardım/Sorun bildir, docs/play, politika) · 11b 👤 (Pro/Billing, Play Console) |
| 12 | Kapanış — uçtan uca hata avı, cihaz doğrulama turu, sürüm adayı — 2026-10-22: **12a** betikli hata avı (bulut) · **12b** cihaz turu · **12c** RC | 11 | 🟡 12a ✅ 2026-10-22 (`tool/scan_setstate_after_await.py`) · 12b 📱 · 12c 👤 |
| 13 | **Ortak tür süzgeci** — her listede PDF/Word/Excel… ayrı seçilir; Son açılanlar'a süzgeç, sıralama, gruplama, çoklu seçim | 6 | ✅ 2026-10-22 (cihaz maddeleri bekliyor) — `FmType` + `FmFilter.types` + `FmTypeChips`; 10 ekran; Son açılanlar yenilendi; K17 (c) `ListMemory`; PNG `docs/design/faz13/`; sapmalar HAFIZA 2026-10-22 (3) |
| 14 | **Görsel boyutlandırma 2.0** — oran kilidi; yüzde/piksel/uzun kenar/en-boy oranı/hedef dosya boyutu; ön ayarlar; WebP/HEIC; düzenleyicide "Boyut" | 10b | ✅ 2026-10-23 (cihaz maddeleri bekliyor) — **14a** 2026-10-22 · **14b**: HEIC/WebP (`b505ced`) + Media3 `LAYOUT_SCALE_TO_FIT(_WITH_CROP)` düzen kipleri, videoda uzun kenar/oran/dosya boyutu (bit hızı), kırpma çapası, kullanıcı ön ayarı kaydet/sil, canlı önizleme küçük resmi, konum kaldırma, düzenleyicide Boyut sekmesi + levhayla aynı oranlar + canlı ölçü + basılı tut → özgün — HAFIZA 2026-10-23 (13) |
| 15 | **Görsel dil birliği** — simge, renk, yazı, hareket tokenları + bekçi testler + kontrast | 6 | ✅ 2026-10-23 (cihaz maddeleri bekliyor) — **15a** 2026-10-22 · **15b**: ham `Icons.*` 547 → 0 ve `Colors.*` 98 → 0 (artık tavan değil kural), sabit punto 148 → 47 (`AppType`/`context.type`; kalanlar belge içeriği/hesaplanan boy), `Color(0x…)` 101 → 91 (kalanlar içerik/kimlik sabiti), elle pencere 85 → 53 (`showAppConfirm` 26, `showAppPrompt` 6); levhalar (56) `showAppSheet`e taşınmadı — HAFIZA 2026-10-23 (13) |
| 16 | **Erişilebilirlik + Arapça (RTL) + büyük yazı** | 15 | ✅ 2026-10-22 (cihaz maddeleri bekliyor: TalkBack, sistem dil seçimi) — kılavuz testleri 10 ekran × tema × TR/AR, RTL dönüşümü + `rtl_guard_test`, `bidiParts`, yazı ölçeği 2,0×, satırda "Seç" eylemi, `localeConfig`; Arapça PNG `docs/design/faz16/ar`; HAFIZA 2026-10-22 (6); **2026-10-23** (kalan iki madde kapandı): asimetrik `Positioned` → `PositionedDirectional` (+bekçi), iş ilerlemesi `liveRegion` (%10 adım, `LiveProgress`) |
| 17 | **Liste ve gezinme cilası** — kalan ~10 liste ekranı ortak bileşene, klasör başına hafıza, iki parmakla sütun, panoda "Son açılanlar" şeridi, eylem sayfası | 13, 15 | ✅ 2026-10-22 (bulut; kaydırma ölçümü cihazda) |
| 18 | **Görüntüleyici ve medya deneyimi** — okuma kipi, video jestleri, galeri, geniş ekran | 15 | ✅ 2026-10-22 (bulut; jest hissi/parlaklık cihazda) |
| 19 | **Sistem entegrasyonu ve ilk izlenim** — açılış ekranı, başlatıcı kısayolları, pencere öğeleri, sistem rengi (K13), dokunsal geri bildirim | 15 | ✅ 2026-10-22 (bulut; görünüş cihazda) |
| 20 | **Ortak düzenleme çekirdeği** (geri al/yinele, taslak + otomatik kaydetme, klavye üstü çubuk, Aa paneli) + doğrulanmış 6 hata — ayrıntı `docs/DUZENLEME_PLANI.md` | — | ✅ 2026-10-23 |
| 21 | **Word: canlı düzenlemenin acil onarımı + motor denemesi** (K18) — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-23 (K18 = b-ii) |
| 22 | **Word Mobil görünüm editörü I** (model, yazma, seçim) — `DUZENLEME_PLANI.md` | 21 | ✅ 2026-10-23 |
| 23 | **Word II** (biçim, şerit, Aa paneli, stiller) — `DUZENLEME_PLANI.md` | 22 | ✅ 2026-10-24 |
| 24 | **Word III** (Ekle, tablo, resim, Düzen, üst/alt bilgi, Gözden Geçir) — `DUZENLEME_PLANI.md` | 23 | ✅ 2026-10-29 |
| 25 | **Excel I** (veri girişi, sayı/formül tuş takımı, işaret kipi, tutamaklar, doğruluk) — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-23 |
| 26 | **Excel II** (bağımlılık grafiği, ızgara çizimi, büyük sayfa) — `DUZENLEME_PLANI.md` | 25 | ✅ 2026-10-23 |
| 27 | **Excel III** (Hücreleri biçimlendir, Veri, Görünüm, form görünümü, CSV) — `DUZENLEME_PLANI.md` | 26 | ✅ 2026-10-29 (küçük kalanlar DUZENLEME_PLANI'nda) |
| 28 | **Slayt I** (yerinde metin, kutuya yakınlaş, anahat, notlar) — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-23 |
| 29 | **Slayt II** (taşı/boyutlandır, şekil/tablo, düzenden yeni slayt, şerit) — `DUZENLEME_PLANI.md` | 28 | ✅ 2026-10-29 (29a + 29b) |
| 30 | **Metin / kod / Markdown düzenleyici** — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-28 |
| 31 | **PDF düzenleme deneyimi** (yerinde metin, nesne katmanı, ortak kabuk) — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-30 |
| 32 | **Görsel düzenleyici 2.0** — `DUZENLEME_PLANI.md` | 20 | ✅ 2026-10-29 |
| 33 | **Düzenleme turu kapanışı** (tablet, klavye, erişilebilirlik, Office uyumluluğu, cihaz turu) — `DUZENLEME_PLANI.md` | 20–32 | 🟡 2026-10-31 bulut kısmı ✅ · cihaz kısmı 📱 (sıra 12 cihaz turuyla birlikte) |

### 0.1 Yürütme sırası (2026-10-22) — bulutta yapılabilenler önce

Kullanıcı isteği (2026-10-22): *"faz 11, 12 ve kalanlar var; onun dışında tamamen
görsele ve kullanım deneyimine yönelik yeni fazlar yap; kalanlarla beraber uzak
ortamda yapabileceklerini en başta olmak üzere."*

**Ortam işaretleri:** ☁️ = bulut (uzak) oturumunda baştan sona bitirilebilir ·
📱 = telefon gerekir (yerel Windows oturumu + USB'li telefon) · 👤 = kullanıcının
hesabı/kararı gerekir (Play Console, Billing, depo ayarı).

| Sıra | İş | Ortam | Neden bu sırada |
|---|---|---|---|
| 1 | **Faz 13** — Ortak tür süzgeci + Son açılanlar | ☁️ | Kullanıcının doğrudan şikâyeti (*"son dosyalarda PDF vs ayrı filtreleyemiyorum"*); tamamı birim + widget testiyle doğrulanır |
| 2 | **Faz 10b** — örnek medya seti + duman testleri (Faz 10'un kalanı) | ☁️ | Faz 14'ün test zemini: EXIF yönlü JPEG, PNG, WebP, (HEIC), MP4/MKV + altyazı, MP3/FLAC/M4A etiketli — bulutta Python/ffmpeg ile üretilir |
| 3 | **Faz 14** — Görsel boyutlandırma 2.0 | ☁️ (+📱) | İkinci doğrudan şikâyet (*"istediğim oranda görüntü boyutlarını değiştiremiyorum"*). Dart motoru, arayüz, testler bulutta; yerel kodlayıcı (WebP/HEIC) ve video kipleri cihaz turunda doğrulanır |
| 4 | **Faz 15** — Görsel dil birliği | ☁️ | Sonraki UX fazları aynı tokenlarla yazılsın diye erken; tasarım PNG'leri bulutta üretilir (`tool/design_shots_test.dart`) |
| 5 | **Faz 16** — Erişilebilirlik + RTL + büyük yazı | ☁️ (+📱 TalkBack) | Faz 15'in tokenlarına dayanır |
| 6 | **Faz 17** — Liste ve gezinme cilası | ☁️ (+📱 kaydırma ölçümü) | Faz 13'ün süzgecini kalan ekranlara taşır |
| 7 | **Faz 18** — Görüntüleyici ve medya deneyimi | ☁️ (+📱 jest hissi) | |
| 8 | **KALANLAR (bulut kısmı)** — `onReorder → onReorderItem` göçü; ham USB yazmayı sağlamlaştırma (bellek içi FAT/exFAT görüntüsüyle yarıda-kesilme testleri); R8 koruma kurallarının yazılması | ☁️ (+📱) | Kod + test bulutta; USB takma ve R8'li APK'nın açılışı cihaz turunda |
| 9 | **Faz 11a** — yayın hazırlığının bulut kısmı | ☁️ | İlk açılış rehberi, tahminli geri (`PopScope`), gizlilik + Play beyan metinleri, Gemini anahtarı Keystore, Yardım/SSS, "Sorun bildir", mağaza metinleri ve ekran görüntüleri. **UX fazlarından SONRA**: mağaza görselleri ve ilk açılış son görünümü göstersin |
| 10 | **Faz 19** — Sistem entegrasyonu ve ilk izlenim | ☁️ + 📱 | XML/Kotlin bulutta yazılır; başlatıcıda/ana ekranda görünüş ancak telefonda görülür |
| 11 | **Faz 12a** — betikli hata avı | ☁️ | Bütün kod değişikliklerinden sonra, cihaz turundan önce |
| 12 | **Cihaz turu (= Faz 12b)** — Faz 4 ölçümleri, Faz 10 cihaz turu, Faz 13–19 cihaz maddeleri, R8, USB, `docs/CIHAZ_TESTI.md` | 📱 | Telefon gerektiren her şey TEK oturumda; kırmızılar aynı oturumda düzeltilir |
| 13 | **Faz 11b** — Play Console, Billing ürünleri, iç test kanalı, depo private (K7), CASA (K5) | 👤📱 | Hesap ve ödeme kararları |
| 14 | **Faz 12c** — sürüm adayı, `v1.x.0` etiketi, Play kapalı test → üretim | 👤 | |

> **Durum 2026-10-23:** sıra 1–11'in (bulutta yapılabilen her şey) tamamı bitti — son tur
> 14b, 15b, 16'nın kalan iki maddesi ve slayta görsel ekleme (HAFIZA 2026-10-23 (13)).
> **Sıradaki iş: sıra 12, cihaz turu** (`docs/CIHAZ_TESTI.md` — en alttaki 2026-10-23 bölümü
> dahil). Bulutta kalan isteğe bağlı iş: 56 levhanın `showAppSheet`e taşınması (görünüm
> farkı riskli; levha başına bakılarak yapılmalı) ve 53 özel pencerenin (seçenek listesi,
> çok alanlı form) ortak bileşene alınması.
>
> **Ek 2026-10-23 — düzenleme turu:** kullanıcı Word/Excel/slayt/PDF/metin/görsel
> düzenlemeyi "telefonda Office gibi, kasmadan" istedi → **`docs/DUZENLEME_PLANI.md`**
> (Faz 20–33). Bu fazlar neredeyse tamamen ☁️; cihaz turundan (sıra 12) **önce**
> yürütülebilir. Kendi sırası: **D1 = Faz 20 → D2 = Faz 21 (+ kısa 📱 kontrol
> noktası) → Faz 25 → 26 → 22 → 23 → 28 → 30 → 24 → 27 → 29 → 32 → 31 → 33**.
> Faz 33'ün cihaz kısmı sıra 12 cihaz turuyla birleştirilirse telefon oturumu bir kez yapılır.
>
> **Durum 2026-10-23:** Faz 20 ✅ · Faz 21 ✅ (K18 = b-ii) · Faz 22 ✅ · Faz 25 ✅ · Faz 26 ✅ ·
> Faz 28 ✅. **2026-10-24: Faz 23 ✅.** **2026-10-29: Faz 24 ✅, Faz 27 ✅, Faz 29 ✅, Faz 32 ✅. 2026-10-30: küçük kalanlar (sekme sürükle, slayt ⇥, Word bağlantı düzenle, Tab ayarı, yan yana Markdown) — sıradaki: Faz 31, sonra 33.** Sıradaki: **Faz 30** (metin/kod/Markdown — D8; bulguları
> HAFIZA 2026-10-24'te: metin kaydı kodlamayı UTF-8'e çeviriyor), sonra Faz 24.

> **Durum 2026-10-31:** Faz 20–32'nin bütün bulut kalanları ve Faz 33'ün bulut kısmı bitti
> (HAFIZA 2026-10-31). **Bulutta yapılacak faz işi kalmadı;** sıradaki: sıra 12 cihaz turu
> (+ Faz 33 cihaz kısmı), sonra 11b/12c (hesap). İsteğe bağlı bulut işi olarak yalnız
> 53 levhanın / 49 pencerenin ortak bileşene taşınması duruyor (görsel fark riski; levha
> başına cihazda bakılarak yapılmalı — faz işi değil).

**Bulut oturumu ne yapabilir / ne yapamaz** (HAFIZA 2026-07-25 §F, 2026-10-21 (5)):

- **Yapabilir:** Flutter **3.44.6** Linux sürümünü indirip `flutter pub get /
  analyze / test` (CI ile aynı sürüm; `git config --global --add safe.directory`
  gerekir); tasarım PNG'leri (`flutter test tool/design_shots_test.dart` →
  `docs/design/`) üretip kullanıcıya göstermek; örnek dosya setleri
  (`tool/write_fixtures_test.dart`, Python, ffmpeg, Poppler); main'e push → CI
  APK + nightly (kullanıcı telefona kurar); `tool/check_kotlin.sh` (kotlinc
  yoksa sessizce atlar — o zaman Kotlin değişikliği küçük tutulur, CI derlemesi
  beklenir).
- **Yapamaz:** telefona kurma, kare süresi/RSS/pil ölçümü, kamera/OCR/Play
  Hizmetleri, gerçek USB/SD/NAS, TalkBack, başlatıcı/pencere öğesi görünüşü,
  Play Console; `graphify update .` (bulutta kurulu değil — yerelde koşturulur).
- **Kural:** bir faz bulutta bittiğinde cihazla doğrulanacak maddeleri
  `docs/CIHAZ_TESTI.md`'ye ekler; faz "✅ (cihaz maddeleri bekliyor)" diye
  işaretlenir ve sıra 12'deki turda kapanır.

---

## 1. Yönetici özeti

**Genel sağlık iyi:** `flutter analyze` **0 sorun**, **2600 test yeşil** (9
atlanan: canlı sunucu testleri), main'den erişilemeyen tek bir Dart dosyası yok,
kök neden yazma kültürü güçlü, uzun işler için ortak iş/bildirim sistemi kurulmuş.
Sorunlar "kod bozuk" sınıfında değil; **kapsam, sadelik, ticari uygunluk ve
düşük donanım** sınıfında:

1. **Kapsam patlaması.** ~155 bin satır, 87 ekran, 207 servis. Birbirinin işini
   yapan ekran kümeleri var: 5 ayrı "geçmiş" ekranı, 4 ayrı gizlilik mekanizması,
   9 temizlik/depolama ekranı, 7 PDF düzenleme yüzeyi, 5 ayrı aktarım yolu.
   Kullanıcı neyin nerede olduğunu bulmakta zorlanır; her yeni özellik bakım
   yükünü katlıyor.
2. **Lisans riskleri (ticari yayın için engelleyici olabilir):**
   - `syncfusion_flutter_pdf` + `_core` **ticari lisanslı** (ücretsiz "Community
     License" yalnız şartları sağlayanlara). 7 dosyada kullanılıyor. Uygulama
     içindeki lisans penceresi bunu yanlışlıkla "ticari kullanıma açık" diye
     yazıyor.
   - **Lato ve Merriweather** fontları OFL "Reserved Font Name" taşıyor;
     depo bunları **altkümeleyip (değiştirip) aynı adla** dağıtıyor — OFL §3'e
     aykırı.
   - Uygulama içinde 3. taraf lisans sayfası yok (`showLicensePage` hiç
     çağrılmıyor); BSD/MIT/Apache atıfları kullanıcıya gösterilmiyor.
   - FFmpeg (LGPL v3) uyumu yapılmış ama boyut ve yükümlülük maliyeti var.
3. **Play Store engelleri:** Google Drive **tam `drive` kapsamı** kullanıyor →
   Google'ın *restricted* kapsamı, yayın için **yıllık ücretli CASA güvenlik
   denetimi** şart. Ayrıca 6 hassas izin için Play beyanı gerekiyor, tahminli
   geri (predictive back) manifestte **geçici** olarak kapalı.
4. **Düşük donanım:** cihaz sınıfı (RAM/çekirdek) hiç algılanmıyor; görsel
   önbelleği her cihazda sabit **160 MB**; bütün uygulama tek `AppState`'i
   izliyor; PDF her açılışta **tüm sayfaların metnini** çıkarıyor; pano her
   açılışta **yüklü uygulamaların boyutunu** tarıyor; takılabilir bellek için
   **5 sn'de bir yoklama**; gizli sekmelerdeki animasyonlar durmuyor.
5. **Kullanıcı iletişimi:** **103 yerde ham hata metni** (`FileSystemException…
   errno = 13` gibi) ekrana basılıyor; iki yerde sabit Türkçe
   `'Dosya açılamadı: $e'`; ilk açılış rehberi ve izin açıklaması yok; AI için
   kullanıcıdan **kendi Gemini API anahtarını** alması isteniyor (tüketici için
   aşılmaz bir eşik).
6. **APK 78 MB (arm64).** Bunun **~32 MB'ı iki kalem:** ML Kit çeviri motoru
   (16,4 MB) ve FFmpeg (15,5 MB).
7. **CI 12,5 dk.** Testler (3 dk 46 sn) derlemeden önce sıralı koşuyor;
   eşzamanlı koşu iptali yok; her main push'u herkese açık bir Release basıyor
   (379 sürüm birikti).
8. **Klasör gezgini:** yol çubuğuna dokunmak **yeni sayfa açıyor** (geri tuşu ters
   yöne gider), sıralama/filtre 13 maddelik ⋮ menüsünde gizli, gezginde filtre
   yok, satır yüksekliği `ListTile` tavanına (56 dp) takılı, her `build`'de
   liste yeniden sıralanıyor.
9. **Süreç borcu:** HAFIZA.md **848 KB** (her oturumda okunması ~250 bin token),
   KALANLAR.md 70 açık madde (36'sı cihaz doğrulaması, bir kısmı bayat),
   graphify çıktısı 2026-07-31'den beri güncellenmemiş.

**Önerilen sıra mantığı:** önce kararlar ve hijyen (Faz 0), sonra her fazı
hızlandıran CI (Faz 1), sonra **çıkar → böl → hızlandır** (Faz 2-4) — çıkarılacak
koda performans ve tasarım emeği harcanmasın diye. Kullanıcı iletişimi
altyapısı (Faz 5) tasarım fazından önce gelir ki yeni ekranlar onu kullanarak
yazılsın. Bağımlılık/lisans (Faz 7) format fazlarından önce gelir çünkü PDF ve
medya fazlarının yolu K1/K2 kararlarına bağlı.

**2026-10-22 eki — görsel ve kullanım deneyimi.** Faz 0–10'dan sonra kod
sağlam ama **"kolay ve tutarlı"** sınıfında boşluklar var (§3.14):

1. **Süzgeç her ekranda başka:** tür süzgeci üç ayrı yerde üç ayrı biçimde
   yazılmış; PDF'i ayrı seçmek yalnız *Belgeler* kutusunda mümkün. **Son
   açılanlar**'da hiç süzgeç, sıralama ve çoklu seçim yok; *Yeni gelenler*,
   *İndirilenler*, *Önemli*, *Üretilenler*, *Çöp kutusu*, *Kasa*'da tür süzgeci
   yok (G1–G3).
2. **Boyutlandırma "istenen oranda" yapılamıyor:** yüzde %10–95 ile sınırlı,
   en×boy alanlarında oran kilidi yok (ikisi birden yazılınca görüntü esniyor),
   büyütme sessizce engelleniyor, en-boy oranı değiştirme/kenar boşluğu ve
   "en çok 200 KB" gibi hedef boyut yok, ayar hatırlanmıyor, WebP/HEIC yok (G4).
3. **Görsel dil yarım birleşmiş:** 1.344 ham simge kullanımına karşılık 93
   `AppIcons`; üç glif ailesi karışık; 338 sabit renk, 114 sabit punto, 95 sabit
   süre (G5–G8).
4. **Erişilebilirlik ve Arapça doğrulanmıyor:** `meetsGuideline` testi 0;
   Arapça arayüzde aynalanmayan ~150 boşluk/hizalama/ok kullanımı (G9–G10).
5. **Büyük ekran:** geniş düzen yalnız gezginde; Android 16 (hedef API 36,
   Play'de Ağustos 2026'dan beri zorunlu) büyük ekranda yön kilidini yok sayıyor
   (G17).

Bunlar yedi yeni fazda (13–19) toplandı; sıra §0.1'de — **önce bulutta bitenler**.

---

## 2. Mevcut durum — ölçümler

| Ölçü | Değer | Not |
|---|---|---|
| Dart kodu (`lib/`) | **155.585 satır**, 404 dosya | 87 ekran, 207 servis, 63 widget dosyası |
| Kotlin (`ci/*.kt`) | 5.218 satır, 8 dosya | MainActivity 1.719 satır |
| Testler | 244 dosya, 42.060 satır, **2600 yeşil / 9 atlanan** | yerelde 4 dk 34 sn |
| `flutter analyze` | **0 sorun** | Flutter 3.29.3 |
| Çeviri tablosu | `app_strings.dart` 8.317 satır, ~2.770 anahtar × 3 dil | tek dosya, 453 KB |
| 800 satırı aşan dosya | **21** | en büyüğü 4.065 (viewer) |
| Doğrudan bağımlılık | ~50 (çözümlenen 180 paket) | çoğu sürüm-sabit (Flutter 3.29.3 duvarı) |
| APK (arm64) | **~78 MB** (v1.0.375: 78,1; 32-bit 85,7) | kırılım §3.9 |
| CI süresi (#379, main) | **12 dk 36 sn** | test 3:46, derleme 5:24, önbellek 1:48 |
| Ayar sayısı | 57 ayar kaydı (`settings_catalog.dart`) | |
| Tema | 10 aile × açık/koyu, 9 arayüz yazı tipi, 6 liste yerleşimi | |
| KALANLAR.md | 70 açık madde (36 cihaz doğrulaması) | bazıları bayat (ör. "APK ~199 MB") |
| HAFIZA.md | 848 KB, 12.754 satır | |

---

## 3. Bulgular

Her bulgu bir kimlik taşır (P = performans, U = arayüz, D = ölü/fazla kod,
Y = yarım, F = fazla özellik, N = yeni özellik, I = iletişim, C = CI,
S = boyut, B = hata, L = lisans/politika). Fazlar bu kimliklere atıf yapar.

### 3.1 Performans — "en düşük telefonda bile akıcı"

> Zaten doğru olanlar (yeniden ele alınmasın): görsel çözme ve ağır ayrıştırma
> izolatlarda; video küçük resmi kuyruğu en çok 2 eşzamanlı ve en yeni önce;
> `MediaQuery.*Of` daraltması yapılmış; medya oturumu 30 sn'de bir tazeleniyor;
> `Timer.periodic`'lerin hepsi iş süresince ya da ekran açıkken yaşıyor;
> kenar önbellekleri (`DiskCache`) sınırlı; arama dizini RAM'de tutulmuyor
> (HAFIZA 2026-09-23, 2026-10-17 (3)).

| # | Bulgu | Kanıt | Etki | Öneri |
|---|---|---|---|---|
| P1 | **Cihaz sınıfı algılanmıyor.** RAM, çekirdek sayısı, `isLowRamDevice` hiçbir yerde okunmuyor. | `grep isLowRamDevice/totalMem` → 0 | 2-3 GB'lık telefonda da 16 GB'lık telefonla aynı bütçe | **"Hafif profil"**: açılışta yerel kanaldan (Extras.kt) RAM/çekirdek/`isLowRamDevice` okunur → görsel önbelleği, küçük resim eşzamanlılığı, animasyonlar, 120 Hz, otomatik tarama, eager işler buna göre ayarlanır. Ayarlarda "Otomatik / Hafif / Tam". |
| P2 | Görsel önbelleği **sabit 160 MB** | `lib/main.dart:69` | 2 GB'lık cihazda sistem baskısı, arka plandaki uygulamaların öldürülmesi | Hafif profilde 48-64 MB, orta 96 MB, güçlü 160 MB. |
| P3 | **Bütün uygulama tek `AppState`'i izliyor.** Kök `MaterialApp` `context.watch<AppState>()` ile kuruluyor; her `addRecent` (her dosya açılışı), `addMemory`, `saveRemote`'ta iki `ThemeData` baştan üretiliyor. 65 yerde tüm AppState izleniyor (`watch`/`Consumer`), yalnız 1 yerde `context.select` var. | `lib/main.dart:304`, `lib/core/app_state.dart:793` | Her dosya açılışında gereksiz yeniden kurulum dalgası | AppState'i odaklı bildiricilere böl (Görünüm, Gezinti, Son dosyalar, Pano/kopyala, Uzak bağlantılar, AI); kök yalnız tema/dil/yazı ölçeğini `select` ile izlesin. (Faz 3) |
| P4 | **PDF her açılışta tüm metni çıkarıyor** (100 bin karaktere kadar, sayfa sayfa) — yalnız AI sohbet bağlamı için. | `lib/screens/viewer_screen.dart:3517` → `_extractPdfText` (:1298) | Büyük PDF'te açılışta CPU + pil, düşük cihazda ilk sayfaların çiziminde takılma | Tembel: yalnız AI, çeviri, sesli okuma ya da "belgede ara" istendiğinde; sonuç dosya özeti anahtarlı küçük disk önbelleğinde. |
| P5 | **Pano açılışında yüklü uygulamalar + boyutları** sorgulanıyor (tüm paketler + `StorageStatsManager`). Önbellek yalnız süreç içi 5 dk. | `dashboard_screen.dart:197` → `installed_apps_service.dart:247` | Her soğuk açılışta saniyeler süren yerel iş | Kart görünür olunca tembel yükle; sonucu prefs'te 6 sa sakla; hafif profilde kapat. |
| P6 | Takılabilir bellek için **5 sn'de bir yoklama** (pano açıkken). | `volume_watcher.dart:75,102` | Boşta bile periyodik uyanma | Yerel `ACTION_MEDIA_MOUNTED/UNMOUNTED/EJECT` + USB yayınlarına bağlan (MainActivity'de USB yayını zaten var); yoklama yalnız yedek, 30 sn. |
| P7 | **Gizli sekmeler çalışmaya devam ediyor.** `HomeScreen` `IndexedStack` kullanıyor, `TickerMode` yok → bir kez açılmış sekmenin animasyonları (iskelet nabzı, kutu nabzı) ve dinleyicileri arka planda sürüyor. | `lib/screens/home_screen.dart:245` | Görünmeyen ekran için kare planlama | Seçili olmayan çocukları `TickerMode(enabled: false)` ile sar; ağır sekmeler `FsEvents`'i yalnız görünürken işlesin. |
| P8 | Gezgin listesi **her `build`'de yeniden sıralanıyor** (`_sorted` getter). Sürükleyerek seçimde her `setState` = O(n log n). | `browser_screen.dart:170-174` | 5-10 bin öğeli klasörde seçim sırasında takılma | Sıralı listeyi yükleme ve sıralama değişiminde bir kez hesapla, alanda tut. |
| P9 | Küçük resim çözme genişliği sabit **×3** (ekran yoğunluğu değil). | `fm_entry_icon.dart:535,600,694,806` | 2× ekranlı ucuz telefonda gereğinden 2,25 kat bellek | `size × devicePixelRatio` (üst sınırlı). |
| P10 | Arama: her sorguda 10 MB'lık dizin dosyası izolatta **baştan okunup** süzülüyor. | `services/fm/search_index.dart` (tasarım notu) | Her harfte izolat + disk + ayrıştırma | Arama ekranı açıkken **uzun ömürlü izolat** dizini bellekte tutsun (ekran kapanınca bırakılsın); sorgu gecikmesi (debounce) 250 ms. |
| P11 | **Açılış kalabalığı:** ilk saniyelerde ~12 bağımsız asenkron iş (TempSweep, SecureVault.clearTemp, SdUnion.syncOnLaunch, JobStore, NativeExtras×2, Playback/Reading/Subtitle konumları, AiIndex, SmartFolders, DashboardLayout, ToolUsage, depolama dizini). | `lib/main.dart:191-221`, `dashboard_screen.dart:179-198` | Düşük cihazda ilk etkileşim gecikir | **Açılış bütçesi**: kritik olmayanlar ilk kareden 2-3 sn sonra, TEK sıralı kuyrukta. |
| P12 | Yüksek tazeleme hızı **varsayılan açık**. | `app_state.dart:128` | 90/120 Hz pil tüketimi | Hafif profilde varsayılan kapalı. |
| P13 | **Ölçüm altyapısı yok** (açılış süresi, kare süresi, bellek). | — | İyileştirme "hissiyat"la yapılıyor | `integration_test` + `traceAction` senaryoları (açılış, 5 bin öğeli klasörde kaydırma, galeri, PDF açılışı) + düşük cihaz protokolü (Ek D). |

### 3.2 Arayüz — klasör içleri, filtre görünümü, simgeler, yerleşimler

Ana ekran (pano) 2026-10-18'de baştan tasarlandı ve kullanıcı "fena değil"
diyor — **dokunulmayacak**. Sorun klasörün içinde ve ondan türeyen listelerde.

| # | Bulgu | Kanıt |
|---|---|---|
| U1 | **Yol çubuğu dokununca yeni sayfa açıyor** (`push`); yığın büyüyor, geri tuşu kullanıcıyı az önce çıktığı derin klasöre götürüyor. | `browser_screen.dart:481-490` |
| U2 | Sıralama (4 ölçüt + yön), gizli dosyalar, favori, kilit, otomatik düzenle, tümünü seç, boş klasörler, listeyi dışa aktar, yenile → **tek ⋮ menüsünde 13 madde**. Hangi sıralamanın açık olduğu ekranda görünmüyor. | `browser_screen.dart:563-652` |
| U3 | **Gezginde filtre yok.** Kategori ekranlarındaki `FmQuickFilters`/`FmFilterSheet` (tür/tarih/boyut) gezgine bağlı değil — iki ayrı dünya. | `widgets/fm/fm_quick_filters.dart`, `fm_filter_sheet.dart` |
| U4 | Satır `ListTile` → `leading` yuvası **56 dp tavanında** (KALANLAR'da açık madde); alt satır tek aralıklı yazı (`MonoText`) — kalabalık listede "teknik" görünüyor. | `widgets/fm/fm_entry_tiles.dart:56-80` |
| U5 | **6 yerleşim** (liste, ayrıntı, 2/3/4/5 sütun). Kullanıcıya fazla seçenek; sütun sayısı ekran genişliğinden türemeli. | `models/fm_layout.dart:11-29` |
| U6 | Boş klasör eski stil (ortada gri simge + metin); 2026-10-17'de yazılan `FmEmptyState` burada kullanılmıyor. | `browser_screen.dart:~780-792` |
| U7 | "+" yalnız yeni klasör / Word / Excel / metin. "Buraya tara", "Buraya içe aktar", "Yapıştır" yok; yapıştırma ayrı bir alt şerit. | `browser_screen.dart:866-912` |
| U8 | Seçim çubuğundaki "yukarısını seç / aşağısını seç / tersini seç" simgeleri (`expand_less`, `expand_more`, `swap_horiz`) anlamını söylemiyor. | `browser_screen.dart:661-700` |
| U9 | **Simge dili karışık:** gezgin ve menülerde ham `Icons.*` (`search`, `add`, `folder_open`, `lock_outline`, `content_cut`, `copy_outlined`) — dolu/çizgi/yuvarlak karışık; araç kutularında `FmTintedIcon` var, gezginde yok. | gezgin, `entry_actions.dart`, seçim çubuğu |
| U10 | Kategori / arama / indirilenler / yeni dosyalar / son açılanlar aynı satırı kullanıyor ama **başlık, sıralama ve filtre çubukları ekran ekran farklı**. | 6 liste ekranı |
| U11 | **Geniş ekran/tablet düzeni yok** (Play "büyük ekran kalitesi" yönergeleri). | — |

**Hedef tasarım (Faz 6'nın sözleşmesi):**

- **Tek liste bileşeni** `FmFileListView` — gezgin, kategori, arama, indirilenler,
  yeni dosyalar, son açılanlar, AI sonuçları hepsi bunu kullanır. Başlık,
  sıralama, filtre, gruplama, seçim, boş/yükleniyor/hata durumları tek yerde.
- **Üst çubuk:** başlık + altında tek satır **yol hapları** (yatay kayar; dokununca
  `popUntil` ile o klasöre **geri** gider, yeni sayfa açmaz). Sağda yalnız
  `Ara` · `Görünüm` · `⋮`.
- **Yapışkan alt başlık (araç şeridi):** solda "142 öğe · 3,2 GB", sağda
  **Sırala: Ad ↑** (tek dokunuşla menü, yön oku görünür) ve **Filtre** (etkin
  filtre sayısı rozetli). Filtre çipleri: Tümü · Klasörler · Belgeler · Görseller
  · Videolar · Ses · Arşiv · APK + açılır "Tarih", "Boyut" çipleri — mevcut
  `FmQuickFilters` mantığı yeniden kullanılır.
- **Gruplama:** tarihe göre sıralıyken "Bugün / Bu hafta / Bu ay / Daha eski",
  türe göre sıralıyken tür başlıkları (yapışkan). Ada göre sıralıyken hızlı
  kaydırma çubuğunda harf göstergesi (`FmFastScroller` var).
- **Satır (kendi `Row`umuz, `ListTile` değil):** 64 dp (yoğun 56 / rahat 72),
  48 dp önizleme/simge, ad tek satır, alt satır orantılı yazıyla "boyut · tarih"
  (klasörde "N öğe"), sağda 48 dp dokunma alanlı ⋮. Seçimde simgenin yerini
  animasyonlu onay dairesi alır (önizleme soluk kalır).
- **Izgara:** sütun sayısı genişlikten (`maxCrossAxisExtent`), kare küçük resim,
  altında 2 satır ad; klasör kartı farklı (klasör çizimi + öğe sayısı).
- **Yerleşim seçenekleri 6 → 3:** Liste · Ayrıntılı liste · Izgara (+ yalnız
  medya ekranlarında Galeri). Ayar her ekran türü için ayrı hatırlanır.
- **Seçim:** üstte sayaç + toplam boyut + "Tümü / Ters çevir" metinli menü;
  altta 5 eylem (Taşı · Kopyala · Paylaş · Sil · Daha fazla).
- **"+" düğmesi bağlamsal:** Yeni klasör · Yeni belge · Buraya tara · Buraya
  içe aktar; panoda öğe varsa düğme **"Yapıştır (3)"** olur.
- **Simge sistemi:** tek glif ailesi (`Icons.*_rounded`), üç boy (20/24/32 dp),
  araç simgeleri tonlu kare zeminde (`FmTintedIcon`), dosya türü renkleri tek
  kaynaktan (`FmColors`), açık/koyu temada kontrast ≥ 3:1. Bekçi test: gezgin
  ve menü dosyalarında `Icons.*_outlined`/çıplak glif kullanımı kırmızı.
- **Durumlar:** iskelet (var), `FmEmptyState` (boş klasör/filtre sonucu boş),
  izin yok, okunamayan klasör, kilitli klasör — hepsi aynı bileşen.
- **≥ 840 dp:** iki bölme (solda klasör ağacı/birimler, sağda liste).

### 3.3 Ölü kod, gereksiz kod, uzun dosyalar

**İyi haber:** main'den erişilemeyen dosya yok (404/404). Ölü kod sembol
düzeyinde ve sınırlı.

| # | Bulgu | Ayrıntı |
|---|---|---|
| D1 | **Hiç kullanılmayan semboller** (tanım dışında 0 referans, testlerde de yok) | 19 işlev/alan + 12 renk sabiti — liste Ek C |
| D2 | **Yalnız testte kullanılan** 25 sembol | `@visibleForTesting` ile işaretlenmeli ya da test başka yoldan yazılmalı (Ek C) |
| D3 | **Eski PDF kelime-bazlı yerinde düzenleme yolu** (~1.600 satır + `viewer_screen` içindeki `_startInlineEdit` zinciri) — paragraf motoru (`PdfEditorScreen`) ile paralel ikinci yol | `services/pdf_edit_flow.dart` 259, `services/pdf_content_editor.dart` 247, `services/pdf/pdf_text_replace.dart` 669, `widgets/pdf_inline_editor.dart` 437. KALANLAR'da "cihaz doğrulamasından sonra sil" diye bekliyor → K12 |
| D4 | `cupertino_icons` bağımlılığı **hiç kullanılmıyor** | `grep CupertinoIcons` → 0 |
| D5 | `video_compress` FFmpeg'in yedeği — iki video motoru | K2'ye göre biri kalkar |
| D6 | `excel` paketi + kendi `xlsx_reader` / `xlsx_editor` / `xlsx_save_patch` / `xlsx_writer` | `excel` yalnız 4 dosyada; `archive ^3` kilidinin (pdfrx 2.x, image 4.4+, Flutter yükseltmesi önünde) **tek sebebi** → Faz 7/9 |
| D7 | `ci/build-trigger.txt` — eski "commit ile tetikleme" artığı | silinmeli |
| D8 | `graphify-out/graph.json` 5,5 MB, 2026-07-31'den beri bayat; CLAUDE.md "953 düğüm" diyor, rapor "6941 düğüm" — tutarsız | Faz 0 |
| D9 | Manifest: `requestLegacyExternalStorage` (API 30+ hedefte etkisiz), `INSTALL_SHORTCUT` (yalnız Android ≤7) | temizlik |
| D10 | **21 dosya 800 satırı aşıyor** | Ek B — bölme önerileriyle |

### 3.4 Yarım kalan özellikler

| # | Özellik | Eksik olan | Kaynak |
|---|---|---|---|
| Y1 | Word düzenleme | Tablo düzenleme yok; resim ekleme/taşıma yok; yazı tipi/punto yalnız paragraf düzeyinde | KALANLAR "Word" |
| Y2 | Excel düzenleme | Grafik ekleme, köşegen doldurma, sayfa taşıma yok (`excel 4.0.6` sınırı); hizalama okuma hatası (paket) | KALANLAR "Excel" |
| Y3 | PDF düzenleme | `/ToUnicode`'suz belgeler, iki yana yaslı satırın yeniden yaslanması, CropBox kaydırılmış sayfada vurgu; **iki paralel düzenleme yolu** (D3) | KALANLAR "PDF turu" |
| Y4 | Seçili metin çevirisi | Yalnız PDF'te; Word/Excel/Slayt'ta yok | KALANLAR |
| Y5 | SD kartla birleşik depolama | Android ≤10'da salt okunur (SAF yazma yok), eşik ve serbest klasör yok | KALANLAR |
| Y6 | Tahminli geri (predictive back) | Manifestte **geçici** kapalı (`enableOnBackInvokedCallback="false"`); Android 16 hedefinde bu kaçış kalıcı değil | `ci/AndroidManifest.xml` |
| Y7 | SMB | Yalnız SMB2.1'e kadar, port değiştirilemiyor (paket sınırı) | KALANLAR |
| Y8 | Google Drive | Tam kapsam yayın engeli (L5) — ya kapsam daralacak ya özellik kalkacak | `drive_service.dart:18-30` |
| Y9 | EPUB | Uzantı "belge" sayılıyor ve indirme süzgecinde var ama **okuyucu yok** (arşiv gibi açılıyor) | `models/fs_entry.dart:85`, `archive_ops.dart:124` |
| Y10 | Masaüstü / iOS | CLAUDE.md hedefi ama hiç derlenmiyor, platform kodu Android'e özel | — |
| Y11 | **36 cihaz doğrulaması** maddesi | Kodla kapatılamaz; Faz 12'de tek seferlik test turu | KALANLAR |

### 3.5 Fazla / çakışan özellikler → birleştirme ve sadeleştirme

| Küme | Bugün (ayrı ekran/mekanizma) | Öneri |
|---|---|---|
| **Geçmiş** | Son açılanlar · Yaptıklarım · Son işlemler (geri al) · İşlemler (iş kuyruğu) · Yeni dosyalar | **Tek "Geçmiş" ekranı**, 4 bölüm: Açılanlar · Üretilenler · İşlemler (canlı + geçmiş + geri al) · Yeni gelenler |
| **Gizlilik** | Gizli dosyalar (`HiddenVault`) · Şifreli kasa (`SecureVault`) · Klasör kilidi (PIN) · Uygulama kilidi | **Tek "Kasa"**: gizleme = şifreli kasaya taşıma (eski gizliler bir kez taşınır); tek PIN/biyometri hem kasa hem uygulama kilidi için; klasör kilidi kasa PIN'ini kullanır |
| **Depolama & temizlik** | Bellek analizi · Yer aç · Yinelenenler · Benzerler · Sohbet medyası · Sohbet kovası · İndirilenler (yaş) · Klasör haritası · Boş klasörler · Uygulamanın kapladığı alan | **Tek "Depolama" merkezi**: üstte doluluk + "Yer aç" önerileri; sekmeler Büyük/eski · Kopyalar · Benzerler · Sohbet medyası · Klasör haritası |
| **Aktarım** | Ağdan erişim (FTP sunucusu) · Tarayıcıdan paylaş (HTTP + QR) · Yakındaki cihaz · Ağ depolama (NAS istemcisi) · Google Drive · İndirmeler | **Tek "Aktar" merkezi**: Bilgisayarla (FTP + tarayıcı tek ekranda, iki sekme) · Telefonla (yakındaki cihaz) · Ağ depolama · İndirmeler. Drive → K5 |
| **PDF düzenleme** | Görüntüleyicide satır içi düzenleme · PDF düzenleyici · PDF araçları · Kalem · İmza · Form · AI ile düzenle · Okuma görünümü | **Tek PDF çatısı**: görüntüleyici + alt çubukta "Düzenle" → kip seçimi (Metin · Kalem · İmza · Form · Sayfalar · AI). Eski yol silinir (D3) |
| **Oynatıcılar** | Video oynatıcı · Müzik çalar · Yüzen oynatıcı (`SYSTEM_ALERT_WINDOW`) · Mini çubuk | Yüzen pencere → **Android PiP** (izin gerektirmez, Play'de sorunsuz); ses + video tek motor (K2 ile birlikte) |
| **AI** | AI Merkezi · Belge sohbeti · AI eylemleri · Akıllı klasörler · Faturalar | AI Merkezi tek giriş; Faturalar ve Akıllı klasörler onun alt bölümü (ayrı pano kutusu değil) |
| **Görünüm ayarları** | 10 tema ailesi × 5 simge dili · 9 arayüz yazı tipi · 6 yerleşim | **4 tema** (Açık, Koyu, OLED, + 1 renkli) · **3 yazı tipi** (Sistem/Inter, okuma serifi, tek aralıklı) · **3 yerleşim** |

**Çıkarılmaya / gizlenmeye aday özellikler (karar K8):**

| Özellik | Neden aday | Risk/maliyet | Öneri |
|---|---|---|---|
| SD kartla birleşik depolama (şarjda otomatik taşıma) | Kullanıcı dosyalarını arka planda kendiliğinden taşıyor — veri kaybı/şikâyet riski yüksek, niş | 638 satır Kotlin + 617 satır ekran | Kaldır ya da "Deneysel" altına al, varsayılan kapalı |
| Ham USB **yazma** (kendi FAT/exFAT yazma sürücümüz) | Günlüksüz dosya sistemine kendi kodumuzla yazmak = bozulma riski; Android zaten çoğu USB'yi bağlıyor | `services/fm/usb` 3.328 satır | Okuma kalsın, **yazma kalksın** |
| Yüzen video oynatıcı | `SYSTEM_ALERT_WINDOW` Play'de dikkat çeker; PiP aynı işi izinsiz yapar | 671 satır Kotlin | PiP ile değiştir |
| Faturalar ve giderler | Dosya yöneticisinin çekirdeği değil, kapsam kayması | 2 dosya + günlük iş | AI Merkezi içine indir ya da kaldır |
| Anılar → İnsanlar (yüz algılama) | ML Kit yüz modeli + KVKK hassasiyeti, düşük cihazda ağır tarama | 1 paket + tarama | Kaldır; "Bu gün" ve "Yerler" kalsın |
| USB teşhis ekranı | Geliştirici aracı | 275 satır | Geliştirici menüsüne (7 kez "Sürüm"e dokun) |
| Uygulamalar → son kullanım (PACKAGE_USAGE_STATS) | Özel izin + Play beyanı | 1 paket (`app_usage`) | Kaldır; boyut ve kurulum tarihi yeter |
| Tema/yazı tipi/yerleşim çeşitliliği | Bakım yükü, APK (fontlar), test yükü | 4,2 MB font | §3.5 son satır |

### 3.6 Eksik / gerekli yeni özellikler

**Ticari yayın için zorunlu:**

| # | Özellik | Neden |
|---|---|---|
| N1 | **İlk açılış rehberi** (3 adım: ne yapar → izin açıklaması → gizlilik/AI) | MANAGE_EXTERNAL_STORAGE için Play'in beklediği "belirgin açıklama"; bugün pano üstünde düz bir izin kartı var |
| N2 | **Uygulama içi lisanslar sayfası** (`showLicensePage` + fontlar/JS için `LicenseRegistry.addLicense`) | BSD/MIT/Apache atıf yükümlülüğü (L4) |
| N3 | **Anahtarsız AI deneyimi** | Tüketici Gemini anahtarı almaz; anahtar yoksa AI düğmeleri tek bir "AI'yı etkinleştir" kartına iner (K4) |
| N4 | **Gelir modeli altyapısı** (Play Billing — K6) | Ticari amaç |
| N5 | Play İçi Değerlendirme + Uygulama İçi Güncelleme (yalnız Play derlemesinde) | Mağaza puanı ve güncel sürüm |
| N6 | **"Sorun bildir"**: hata kaydını + cihaz bilgisini e-postayla gönderme (bugün yalnız paylaş) | Destek kanalı |

**Güçlü kullanıcı beklentisi:**

| # | Özellik | Neden |
|---|---|---|
| N7 | **Temel görsel düzenleyici** (kırp, döndür, parlaklık/kontrast, işaretle) | Galeride "Araçlar" var ama kırpma yok; rakiplerin hepsinde var |
| N8 | **Android PiP** (yüzen pencerenin yerine) | §3.5 |
| N9 | Klasör içi filtre + yapışkan sıralama şeridi | U2/U3 |
| N10 | Tablet iki bölme | U11 |
| N11 | Uygulama içi **Yardım / SSS** (izinler, kasa PIN'i, ağ paylaşımı nasıl çalışır) | "Ne oluyor?" sorusunun kalıcı cevabı |
| N12 | EPUB okuyucu **ya da** EPUB'ın belge listesinden çıkarılması | Y9 — yarım bırakılmamalı |

### 3.7 Son kullanıcı iletişimi — "ne oluyor?" soru işareti

> İyi olan (korunmalı): uzun işler için ortak iş sistemi (şerit + bildirim +
> kalan/geçen süre, "… tamamlandı/başarısız/durduruldu" başlıkları), iskelet
> yükleme, `FmEmptyState`, çeviri bekçisi testi (`l10n_literals_test`).

| # | Bulgu | Kanıt |
|---|---|---|
| I1 | **103 yerde ham hata metni** kullanıcıya gösteriliyor (`'$e'`, `{'error': e}`) — ör. "FileSystemException: Cannot open file, path = …, OS Error: Permission denied, errno = 13" | ör. `word_editor_screen.dart:132`, `slides_editor_screen.dart:148,166,264`, `spreadsheet_editor_screen.dart:328`, `pdf_tools_screen.dart:136,178`, `pdf_editor_screen.dart:158,204,223,522` |
| I2 | **Sabit Türkçe + ham hata:** `'Dosya açılamadı: $e'` (İngilizce/Arapça arayüzde de Türkçe) | `services/fm/entry_opener.dart:207,293` |
| I3 | Lisans penceresi **tamamen sabit Türkçe** ve Syncfusion için **yanlış** bilgi veriyor | `screens/settings/tiles_system.dart:321-345` |
| I4 | Diğer sabit metinler: `'Görünüm'` varsayılan başlığı, `'Varsayılan'`, `'Öğe N'`, `'Video'` tür adı | `fm_layout_sheet.dart:13`, `viewer_screen.dart:304`, `chart_painter.dart:78`, `entry_opener.dart:267` |
| I5 | **348 `catch (_)`**, bunların 158'i tamamen boş `{}` (19'u ekran kodunda). Çoğu bilinçli "en iyi çaba" ama kullanıcı eylemine bağlı olanlar sessiz kalmamalı — ör. tarama sonrası klasör oluşturma hatası yutuluyor, ardından taşıma deneniyor | `scan_result_screen.dart:686` vb. |
| I6 | **İzin reddi durumları dağınık:** bildirim izni reddedilince işler sessizce bildirimsiz koşuyor (main.dart yorumu); kamera, kullanım erişimi, üstte gösterme, tüm dosyalar izinleri için ortak "İzin gerekli → neden → Ayarlara git" bileşeni yok | `lib/main.dart:90-93` |
| I7 | **İlk açılış yok** (N1) | — |
| I8 | AI anahtarı yokken AI düğmeleri görünüyor; basınca "anahtar gerekli" uyarısı çıkıyor — tüketici için çıkmaz sokak | `ai_actions.dart:41`, `pdf_editor_screen.dart:387`, `similar_screen.dart:225` |
| I9 | Çevrimdışı durumu için ortak bileşen yok (AI, Drive, NAS, indirme ayrı ayrı) | — |

**Öneri (Faz 5):** `core/user_error.dart` — `UserError.from(Object e)`:
`FileSystemException` (EACCES/EPERM → "izin yok", ENOSPC → "yer kalmadı",
ENOENT → "dosya taşınmış ya da silinmiş", EROFS → "salt okunur bellek",
EEXIST → "aynı adda dosya var"), `SocketException`/`TimeoutException` →
"bağlantı yok", `PdfException` → "PDF bozuk ya da parolalı", Gemini 401/429 →
"anahtar geçersiz / kota doldu", bilinmeyen → "Beklenmeyen bir hata oldu" +
**"Ayrıntı"** düğmesi (ham metin yalnız orada) + otomatik `CrashLog` kaydı.
Bekçi test: ekran kodunda `'$e'` ve `{'error': e}` desenleri kırmızı.

### 3.8 GitHub APK derleme akışı

**Ölçüm (#379, main, toplam 12 dk 36 sn):**

| Adım | Süre |
|---|---|
| Flutter kurulumu | 28 sn |
| Gradle & pub önbelleği geri yükleme | 55 sn |
| İskelet + 9 yama adımı + pub get + ikon | ~14 sn |
| `flutter analyze` | 31 sn |
| `flutter test` | **3 dk 46 sn** |
| `flutter build apk` (arm + arm64) | **5 dk 24 sn** |
| İmza, denetim, artifact, Release | ~20 sn |
| Önbellek kaydetme (post) | 53 sn |

| # | Sorun | Öneri | Kazanç |
|---|---|---|---|
| C1 | Test, derlemeden **önce ve sıralı** | `verify` (analyze+test) ve `apk` **paralel** iş; `release` ikisine `needs` | ~4 dk duvar süresi |
| C2 | **Eşzamanlılık iptali yok** — art arda iki push iki tam derleme | `concurrency: {group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true}` | boşa giden koşular |
| C3 | Flutter SDK önbelleksiz | `subosito/flutter-action` `cache: true` | ~20 sn |
| C4 | Her push'ta 2 mimari | Push'ta yalnız `android-arm64`; 32-bit + AAB yalnız sürüm etiketinde/elle | ~1,5-2 dk |
| C5 | **Her main push'u herkese açık Release** (379 sürüm, her biri ~160 MB) | main push → artifact + tek **"nightly" ön sürüm** (üzerine yazılır); `v*` etiketi → gerçek Release; eski sürümleri budayan adım (son 10) | depolama, karışıklık |
| C6 | Release adımı 5 adımda elle tekrar (3 deneme + 2 bekleme) | Tek adımda `gh release` + üstel bekleme döngüsü | YAML sadeliği |
| C7 | 9 ayrı Android yama adımı (python/sed) YAML içinde | `ci/prepare_android.sh` (tek betik, yerelde de koşar, `check_kotlin.sh` gibi) | bakım |
| C8 | `paths-ignore` yalnız `**.md` | `graphify-out/**`, `docs/**`, `tool/**`, `.claude/**`, `hooks/**` da; yalnız `test/**` değişirse APK değil yalnız `verify` | gereksiz derlemeler |
| C9 | `--obfuscate --split-debug-info` yok | Ekle; sembolleri artifact olarak sakla (çökme izini çözmek için) | libapp.so küçülür (ölçülecek) |
| C10 | APK boyut bütçesi ve **16 KB sayfa hizası** denetimi yok | `zipalign -c -P 16 -v 4` + ELF `LOAD` hizası denetimi; arm64 APK > bütçe ise kırmızı | Play şartı güvencesi |
| C11 | `ci/*.kt` yalnız APK derlemesinde derleniyor | `ci/**` değişince `verify`'da `tool/check_kotlin.sh` | 13 dk'lık turu korur |
| C12 | Test adımının adı "Testler (pptx render)" yanıltıcı; `test` işinde zaman aşımı yok | düzelt | — |

**Hedef:** main push'ta duvar süresi **12,5 → ~7 dk**, özellik dalında
**~4,5 → ~3 dk**. Depo **private** yapılırsa (K7) aylık 2.000 ücretsiz dakika bu
optimizasyonlarla ~250 derlemeye yeter.

### 3.9 APK boyutu

v1.0.362 arm64 APK'sının ölçülmüş kırılımı (HAFIZA 2026-09-26), sonrasında
yapılanlar işlenmiş:

| Kalem | MB | Durum / öneri | Olası kazanç |
|---|---|---|---|
| `libapp.so` (Dart kodumuz) | 21,6 | Sadeleştirme (Faz 2) + `--obfuscate --split-debug-info` (C9) + `excel` paketinin çıkması | −3…−6 (tahmin, ölçülecek) |
| `libtranslate_jni.so` (ML Kit çeviri) | **16,4** | **K3:** kaldır → çeviri Gemini'yle ya da "Google Çeviri'de aç" | −16,4 |
| FFmpeg (avcodec/avfilter/…) | **15,5** | **K2:** Media3 Transformer (Apache 2.0, donanım kodlayıcı) | −14…−15 |
| Gömülü OCR | 12,4 | ✅ Play Hizmetleri'ne taşındı (2026-09-26) | — |
| `libflutter.so` | 11,1 | sabit | 0 |
| PDFium | 5,0 | sabit (wasm 2,0 MB ✅ çıkarıldı) | 0 |
| Fontlar (18 dosya) | 4,2 | Carlito/Tinos/Arimo Latin+Türkçe altkümesi (RFN'siz oldukları için serbest); arayüz fontları 7 → 2 | −2…−3 |
| dex | 3,5 | `google_sign_in`/Drive (K5), `app_usage`, `installed_apps` sadeleşirse | −0,5…−1 |

**Hedef:** K2 + K3 kabul edilirse arm64 **~78 → ~40-45 MB**; edilmezse
**~70 MB**. Play'de AAB ile her cihaz yalnız kendi mimarisini indirir; 32-bit ayrı
APK derdi kalkar.

### 3.10 Format akışları — durum ve kontrol listesi

Her format için uçtan uca akış: **aç → görüntüle → ara → düzenle → kaydet
(üzerine / kopya) → paylaş → dönüştür → yazdır → son açılanlar/kaldığı yer**.

| Format | Görüntüleme | Düzenleme | Bilinen boşluklar / riskler |
|---|---|---|---|
| **PDF** | pdfrx/PDFium, metin seçimi (kendi katmanımız), ara, içindekiler, gece modu, okuma görünümü, kaldığı yer | Vurgu, kalem, imza, form, sayfa araçları (Syncfusion), paragraf motoru, AI düzenleme | 7 yüzey (F-PDF), iki düzenleme yolu (D3), açılışta tüm metin (P4), Syncfusion lisansı (L1), `/ToUnicode`'suz belgeler (Y3) |
| **Word (.docx)** | WebView + docx-preview (gömülü JS) | Canlı paragraf düzenleme, B/I/U, hizalama, font/punto (paragraf) | Tablo/resim düzenleme yok (Y1), seçili metin çevirisi yok (Y4), ham hata (I1) |
| **Excel (.xlsx/.csv)** | Kendi ızgaramız + biçim motoru + formül motoru (2.580 satır) | Hücre, satır/sütun, biçim, formül | Grafik ekleme/sayfa taşıma yok (Y2), `excel` paketi kilidi (D6), 4.025 satırlık ekran (Ek B) |
| **Slayt (.pptx)** | Kendi çizicimiz (şekil, grafik, tablo, animasyon adımları), sunum modu | Metin, B/I/U/punto, slayt çoğalt/sil/taşı | Tanımsız geometriler kutu düşüyor (bilinçli), cihaz doğrulaması bekleyen 3 tur |
| **Eski Office (.doc/.xls/.ppt)** | Salt okunur metin çıkarımı | — | Beklenen davranış: "salt okunur" rozeti + "DOCX'e dönüştür" önerisi |
| **Metin / kod / CSV / Markdown** | Satır no., kaydırma, okuma ayarları | Düz metin düzenleme | Çok büyük dosyada (> 5 MB) tek seferde yükleme → parçalı okuma; kodlama algılama testleri |
| **Görsel** | Galeri, yakınlaştırma, EXIF, döndürme | Boyut düşürme | **Kırpma/temel düzenleyici yok** (N7); `resize_compare_screen.dart:485` `cacheWidth`'siz |
| **Video** | ExoPlayer, altyazı, hız, A-B, kaldığı yer, yüzen oynatıcı | FFmpeg ile boyut düşürme | Yüzen oynatıcı → PiP (N8); FFmpeg/`video_compress` ikiliği (D5, K2) |
| **Ses** | `audioplayers`, medya oturumu, kilit ekranı, çalma listesi | — | İki ayrı oynatma motoru (video_player + audioplayers) |
| **Arşiv** | RAR4/5, 7z, zip, tar, gz — çıkarmadan listeleme | Sıkıştır (zip/7z, AES) | EPUB'ın arşiv gibi açılması (Y9) |

Faz 8-10, bu tablonun her satırı için **örnek dosya seti** (`test/fixtures/`)
ve **duman testi** ister: aç → kaydet → yeniden aç → içerik aynı mı.

### 3.11 Doğrulanmış hatalar (kod okuyarak tespit edildi)

| # | Hata | Kanıt | Etki |
|---|---|---|---|
| B1 | `_sorted` getter'ı `context.watch` çağırıyor ve **dokunma geri çağrısından** (`_openEntry`) çağrılıyor → hata ayıklama derlemesinde Provider iddia hatası; her çağrıda yeniden sıralama | `browser_screen.dart:170-174, 203` | debug'da kırmızı ekran, release'te israf |
| B2 | Yol çubuğu `push` ile yeni gezgin açıyor (U1) | `browser_screen.dart:481-490` | geri tuşu ters yöne gider, yığın şişer |
| B3 | Sabit Türkçe + ham hata (I2) | `entry_opener.dart:207,293` | EN/AR arayüzde Türkçe ve teknik metin |
| B4 | Lisans penceresinde Syncfusion için yanlış "ticari kullanıma açık" ifadesi + sabit Türkçe (I3) | `tiles_system.dart:340-345` | hukuki olarak yanıltıcı beyan |
| B5 | Lato ve Merriweather **altkümelenip aynı adla** dağıtılıyor (L2) | `tool/fetch_ui_fonts.py:34-43,67`, font `name` tablosunda "Reserved Font Name" | OFL ihlali |
| B6 | `FONTS-NOTICE.txt` Carlito için RFN yazıyor, dosyada yok; Lato/Merriweather'ın RFN'si yazmıyor | `assets/fonts/FONTS-NOTICE.txt` | yanlış belge |
| B7 | Gizli sekmelerde animasyon/dinleyici sürüyor (P7) | `home_screen.dart:245` | pil |
| B8 | KALANLAR'da bayat maddeler ("APK ~199 MB (build 123)", graphify) | `KALANLAR.md` | yanlış öncelik |
| B9 | README bayat: "her push'ta APK derler", "Yol haritası"ndaki maddeler yapılmış | `README.md` | yanlış bilgi |
| B10 | CLAUDE.md'deki graf istatistiği raporla çelişiyor (953 vs 6941 düğüm) | `CLAUDE.md` §2 | yanlış harita |

> Not: B1-B4 ve B7 küçük ama doğrudan düzeltilebilir; ilgili fazlarda (Faz 2, 4,
> 5, 6) ilk iş olarak kapatılmalı. Fazlarda ayrıca sistematik hata avı var
> (Faz 12 + her format fazının duman testleri).

### 3.12 Lisans, telif ve Play politikası

**Bağımlılık lisans taraması** (180 paket, LICENSE dosyaları okundu): büyük
çoğunluk BSD-3 / MIT / Apache-2.0 — ticari kullanım serbest, yükümlülük atıf.
İstisnalar:

| # | Bileşen | Lisans | Risk | Eylem |
|---|---|---|---|---|
| L1 | `syncfusion_flutter_pdf`, `syncfusion_flutter_core` | **Syncfusion ticari / Community License** | **YÜKSEK** | K1: (a) Community License'a başvur (ücretsiz; yıllık brüt gelir < 1 M USD, ≤ 5 geliştirici, ≤ 10 çalışan, dış yatırım < 3 M USD şartları) ve lisans belgesini sakla; ya da (b) kaldır — kullanılan 7 dosya: `pdf_tools.dart`, `pdf_page_edit.dart`, `pdf_annotator.dart`, `pdf_content_editor.dart`, `pdf/pdf_form.dart`, `pdf/pdf_markup.dart`, `pdf/pdf_scanned_retype.dart` |
| L2 | **Lato, Merriweather** fontları | OFL 1.1 + **Reserved Font Name** | **ORTA** (kolay düzelir) | Değiştirilmiş dosya RFN'yi kullanamaz: (a) değiştirilmemiş özgün dosyalar, (b) yeniden adlandırılmış altküme, ya da (c) **kaldır** (önerilen — §3.5 yazı tipi sadeleşmesi) |
| L3 | FFmpeg 8.1.2 (`ffmpeg-kit-min`) | LGPL v3 | ORTA | Uyum yapılmış (GPL kodlayıcı yok, dinamik bağlı, kaynak bağlantısı). Kalan: H.264/AAC çözücülerinin patent soruları ve LGPL yükümlülüklerinin sürdürülmesi. K2 ile Media3'e geçilirse tamamen kalkar |
| L4 | Tüm BSD/MIT/Apache paketleri + docx-preview (Apache-2.0) + JSZip (MIT seçimi) + fontlar (OFL) + Roboto Slab (Apache) | izin verici | DÜŞÜK ama **yükümlülük var** | Uygulama içi lisans sayfası yok → `showLicensePage` + gömülü varlıklar için `LicenseRegistry.addLicense` (N2); Apache NOTICE dosyaları dahil |
| L5 | Google Drive `drive` kapsamı | Google API politikası | **YÜKSEK** (yayın engeli) | Restricted kapsam → yayın için yıllık ücretli CASA denetimi. K5: `drive.file`'a dön ya da Drive ekranını kaldırıp Android'in sistem belge seçicisini (Drive kendi sağlayıcısını sunuyor) kullan |
| L6 | "Word / Excel / PowerPoint" adları ve marka renklerine benzeyen tonlar | Microsoft ticari markaları | DÜŞÜK-ORTA | Uygulama adı, simgesi ve mağaza başlığında kullanılmamalı; arayüzde "Belge (DOCX)", "Tablo (XLSX)", "Sunum (PPTX)" gibi tanımlayıcı adlar; mağaza metninde "Microsoft Word dosyalarıyla uyumlu" + marka notu |
| L7 | Gemini API | Google API şartları | DÜŞÜK | Kullanıcı kendi anahtarını girerse sorumluluk onda; ücretsiz katmanda verilerin model iyileştirmede kullanılabileceği gizlilik politikasında ve AI ilk kullanımında açıkça yazılmalı |
| L8 | ML Kit (OCR, çeviri, yüz) | Google ML Kit şartları | DÜŞÜK | Ücretsiz, ticari serbest; Play Hizmetleri bağımlılığı gizlilik politikasında belirtilmeli |
| L9 | **Depo herkese açık** ve LICENSE dosyası yok | — | ORTA | Kod okunabilir/kopyalanabilir durumda; ticari yayından önce **private** (K7) + `LICENSE` (Tüm hakları saklıdır) |

**Play politikası — beyan gerektiren izin ve davranışlar:**

| İzin / davranış | Play durumu | Gerekçe metni hazırlanmalı mı | Öneri |
|---|---|---|---|
| `MANAGE_EXTERNAL_STORAGE` | Dosya yöneticisi için **izinli**, beyan formu + belirgin açıklama | Evet | N1 ilk açılış rehberi |
| `QUERY_ALL_PACKAGES` (`installed_apps`'ten) | Dosya yöneticisi için izinli, beyan | Evet | "Uygulamalar" ekranı kalırsa |
| `REQUEST_INSTALL_PACKAGES` | Dosya yöneticisi için izinli, beyan | Evet | APK kurulumu |
| `PACKAGE_USAGE_STATS` | Özel izin | Evet | K8 ile kaldırılması önerildi |
| `SYSTEM_ALERT_WINDOW` | İnceleme riski | — | PiP ile kaldır (N8) |
| Ön plan servisi türleri (`dataSync`, `mediaPlayback`) | Play Console'da tür beyanı + video | Evet | Android 15'te `dataSync` günlük süre sınırı — uzun kopyalamalar için not |
| Hedef API 36 / tahminli geri | Opt-out geçici | — | Y6: `PopScope`'a geçiş (Faz 11) |
| **16 KB bellek sayfası** (Android 15+ için zorunlu) | Zorunlu | — | Ölçüldü: `libflutter.so` (0x10000), FFmpeg'in 9 `.so`'su ve `libpdfium.so` (0x4000) **uyumlu ✔**. `libapp.so` ve `libtranslate_jni.so` derlenmiş APK'da CI'da denetlenmeli (C10) |
| Veri güvenliği formu, gizlilik politikası URL'si | Zorunlu | — | Politika uygulama içinde var (`assets/privacy/`); herkese açık bir adreste de yayımlanmalı (ör. GitHub Pages) |
| Play App Signing + AAB | Zorunlu | — | AAB üretimi workflow'da var (elle) |

### 3.13 Süreç ve proje hijyeni

| # | Bulgu | Öneri |
|---|---|---|
| H1 | **HAFIZA.md 848 KB** — CLAUDE.md her oturumun başında okunmasını istiyor (~250 bin token) | `HAFIZA.md` → **dizin** (Sabit Kararlar + Bilinen Tuzaklar + Reddedilen Yollar, ≤ 600 satır) + `docs/hafiza/2026-07.md`, `2026-08.md`… aylık arşiv (append-only kuralı arşivde sürer) |
| H2 | KALANLAR.md 70 madde, bayat olanlar var, cihaz doğrulamaları iş maddeleriyle karışık | İki dosya: `KALANLAR.md` (yalnız gerçek iş, faz numarasıyla) + `docs/CIHAZ_TESTI.md` (telefonda bakılacaklar listesi — Faz 12'de tek turda) |
| H3 | graphify bayat (2026-07-31), bulut oturumlarında kurulu değil | Faz 0'da yerelde `graphify update .`; CLAUDE.md'deki istatistik düzeltilir |
| H4 | CLAUDE.md "TEK DAL main" diyor; bulut oturumları her seferinde `claude/*` dalı açıyor (uzak depoda 30+ dal birikti) | CLAUDE.md'ye kural: "oturum dalı main'e birleştirildikten sonra uzak dal silinir" |
| H5 | README bayat (B9) | Faz 0'da güncelle |

### 3.14 Görsel ve kullanım deneyimi (2026-10-22)

> **Yöntem:** `main` @ `0772995` (Flutter 3.44.6). Liste, süzgeç, boyutlandırma,
> düzenleyici, galeri, oynatıcı ve pano akışları satır satır okundu; simge/renk/
> yazı/hareket/RTL kullanımları `grep` ile sayıldı (sayımlar aşağıda, komutlar
> Ek E); Android 16 davranış değişiklikleri, Material You, Material 3 Expressive
> ve rakip görsel boyutlandırma uygulamaları web'de araştırıldı (kaynaklar Ek E).
> Bulgu kimliği **G** (görsel/kullanım). Zaten iyi olanlar — yeniden ele
> alınmasın: Faz 6'nın `FmEntryRow` satırı (56 dp tavanı kalktı), yol hapları,
> `FmListToolbar` sıralama şeridi; galerideki Hero geçişi, aşağı çekip kapatma ve
> çift dokunuşla yakınlaştırma; Fotoğraflar'da iki parmakla sütun; PDF sayfa
> rozeti + `PdfPageNavigator`; ses oynatıcıda uyku zamanlayıcısı/hız/çalma
> listesi; boyutlandırmada "şu an → sonra" kartı ve tahmini boyut.

#### 3.14.1 Süzgeçler — "son dosyalarda PDF'i ayrı süzemiyorum"

| # | Bulgu | Kanıt |
|---|---|---|
| G1 | **Son açılanlar'da süzgeç yok.** Yalnız ad araması var; tür/tarih/boyut çipi, sıralama (sabit: son açılma), gruplama, ızgara ve **çoklu seçim** yok (`selected: const {}` — her dokunuş açar). Toplu "geçmişten kaldır" yok; yalnız "tümünü temizle". | `screens/fm/open_history_screen.dart:150-178` |
| G2 | **Tür süzgeci üç ayrı yerde, üç ayrı biçimde; PDF yalnız birinde ayrı.** (a) Gezgin: `FmTypeChips` — `FmCategory` düzeyinde, "Belgeler" tek çip (`fm_file_list_view.dart:392`, yalnız `browser_screen.dart:220`'de kullanılıyor). (b) Kategori ekranı: PDF/Word/Excel/Slayt/Metin çipleri **yalnız Belgeler kutusunda** (`showDocKinds`, `category_screen.dart:503`). *Yeni gelenler* aynı ekranı bu bayrak olmadan açıyor (`new_files_screen.dart:156`) → karışık listede PDF'i ayırmanın tek yolu süzgeç sayfasında uzantı işaretlemek (3 dokunuş). (c) Arama: `FmCategory` çipleri, alt tür yok (`search_screen.dart:564`). (d) İndirilenler, Önemli, Üretilenler, Çöp kutusu, Kasa: **tür süzgeci hiç yok**. | dosyalar solda |
| G3 | **Süzgeç/sıralama hafızası yok.** Ekrandan çıkınca süzgeç sıfırlanıyor; gezginde sıralama tek global ayar (`appState.setFmSort`), klasör başına değil ("İndirilenler tarihe, Müzik ada göre" yapılamıyor). | `browser_screen.dart:215` |

> Karşılaştırma: Google Drive'ın tür süzgeci PDF'i Belgeler'den **ayrı** bir
> seçenek olarak sunuyor ve çipler birlikte kullanılabiliyor (Ek E). Bizim
> `FmQuickFilters`'ın "sayı = dokununca kalan dosya" ilkesi bundan iyi; eksik
> olan tek şey alt tür düzeyi ve her ekranda aynı bileşen.

#### 3.14.2 Görsel boyutlandırma — "istediğim oranda değiştiremiyorum"

| # | Bulgu | Kanıt |
|---|---|---|
| G4a | Yüzde kaydırıcısı **%10–95**, 5'er adım; elle sayı girilemiyor; %100 üstü yok. | `widgets/fm/media_resize_sheet.dart:164-165` |
| G4b | **Serbest en × boy'da oran kilidi yok.** İki alan bağımsız; ikisi birden yazılınca görüntü **esniyor** (oran bozulur). Biri yazılınca öteki alanda görünmüyor (yalnız "sonra" satırında). | `models/media_resize.dart:504-531` |
| G4c | Kaynaktan büyük değer **sessizce kaynağa kırpılıyor** (büyütme yasak); kullanıcı istediği ölçüyü alamıyor, nedeni alanın altındaki küçük notta. | aynı yer |
| G4d | **En-boy oranı değiştirme yok** (1:1, 4:5, 16:9, A4…); kırpma ayrı ekranda, **kenar boşluğu (dolgu)** seçeneği hiç yok. Videoda oran değişince Media3 `LAYOUT_STRETCH_TO_FIT` ile görüntü esniyor. | `ci/MediaTranscode.kt:129` |
| G4e | **Hedef dosya boyutu yok** ("en çok 200 KB / 1 MB" — resmî başvuru/form yüklemelerinin tipik şartı); yalnız JPEG kalite kaydırıcısı. Rakip boyutlandırıcılar yüzde + piksel + oran + toplu işi birlikte sunuyor (Ek E). | — |
| G4f | Fotoğraf kademeleri **video dilinde** (480p/540p/720p/1080p = kısa kenar); fotoğrafta beklenen "uzun kenar 1280/1600/2048 px". | `models/media_resize.dart:12` |
| G4g | **Son ayar hatırlanmıyor**, kayıtlı ön ayar (preset) yok — her seferinde 1080p varsayılanı. | `screens/fm/resize_actions.dart:54` (`initial` verilmiyor) |
| G4h | Çıktı JPEG/PNG(/BMP/TGA); **WebP yok** (`image` paketi yazamıyor). **HEIC kaynak** `image` paketiyle çözülemiyor → küçültme "Görüntü çözülemedi" ile başarısız (kod okuması — cihazda doğrulanacak); oysa görsel düzenleyici HEIC'i platform çözücüsüyle açıyor (iki ayrı motor). Saf Dart çözme 12 MP'de düşük cihazda yavaş ve tüm bitmap'i belleğe alıyor. | `services/fm/image_resize.dart:39-50, 194-230` |
| G4i | **Giriş noktası gizli:** galeri alt çubuğunda "Boyut" yok (yalnız ⋮ → eylem sayfası); görsel düzenleyicide boyut sekmesi yok — kırp ve boyutlandır iki ayrı akış. | `image_gallery_screen.dart:434-460` |
| G4j | Kırpma oranları 6 tane (serbest, 1:1, 4:3, 3:4, 16:9, 9:16): **Orijinal, 4:5, 5:4, 3:2, 2:3, 21:9, A4, özel a:b yok**; kırpma kutusunun piksel ölçüsü yazmıyor. | `screens/image_edit_screen.dart:52-59` |
| G4k | **Fotoğrafa da çift sayı yuvarlaması** uygulanıyor (`even()` video kodlayıcı şartı): 1081 yazan 1080 alıyor. | `models/media_resize.dart:493` |
| G4l | **Şüphe — doğrulanacak (B11):** `image` paketi EXIF yönünü uygulamadan ölçüyor; dikey çekilmiş (Orientation = 6/8) fotoğrafta "genişlik 1080" ham (yatay) kenara uygulanabilir → çıktı beklenenden küçük/yan. Faz 10b örnek setindeki EXIF yönlü JPEG ile test edilecek. **→ 2026-10-22 (10b) sonuç:** çıktı DOĞRU (`image` 4.3 çözücüsü yönü uyguluyor, piksel testiyle); hatalı olan `ImageResizer.probeSize`'dı (ham başlık ölçüsü → levha dikey fotoğrafa "400×300" diyordu) — düzeltildi. | `image_resize.dart` `_resizeSync` |

#### 3.14.3 Görsel dil tutarlılığı (ölçüldü)

| # | Ölçü | Değer | Not |
|---|---|---|---|
| G5 | Ham `Icons.*` (`app_icons.dart` dışında) | **1.344** | `AppIcons.*` yalnız 93 kez; Faz 6'nın simge sistemi yalnız gezgine uygulandı |
| G5 | Glif ailesi karışımı | `_outlined` 373 · `_rounded` 189 · eksiz 744 | aynı ekranda üç aile |
| G6 | Sabit `Color(0x…)` (tema/görünüm dosyaları dışında) | **150** | koyu temada kontrast riski |
| G6 | Doğrudan `Colors.black/white/grey/red/…` | **188** | |
| G7 | Sabit `fontSize:` | **114** | `TextTheme` rollerini atlıyor; yazı ölçeği ayarı her yere eşit yansımıyor |
| G8 | Sabit `Duration(milliseconds:` | 95 | hareket tokenı yok |
| G8 | Cihazın "animasyonları kaldır" ayarını (`disableAnimations`) dikkate alan yer | **2** | |
| G9 | Erişilebilirlik kılavuz testi (`meetsGuideline`: 48 dp hedef, etiketli hedef, metin kontrastı) | **0** | Flutter'ın hazır kılavuzları hiç koşturulmuyor |

#### 3.14.4 Arapça (RTL) ve büyük yazı

| # | Bulgu | Sayı |
|---|---|---|
| G10 | Arapça arayüzde aynalanmayan yerleşim: `EdgeInsets.only(left:/right:)` 27 · asimetrik `EdgeInsets.fromLTRB` 24 · `Alignment.*Left/*Right` 36 · `TextAlign.left/right` 21 · yöne duyarsız ok simgeleri (`arrow_back/forward`, `chevron_left/right`) 43. `EdgeInsetsDirectional` yalnız 22 yerde. | ~150 |
| G10 | Yazı ölçeği testleri 1,4×'te; Android 14+ **doğrusal olmayan ölçek 2,0×'e** kadar çıkıyor. | — |

#### 3.14.5 Listeler, gezinme, ana ekran

| # | Bulgu | Kanıt |
|---|---|---|
| G11 | `FmFileListView`'i 5 ekran kullanıyor (gezgin, kategori, arama, indirilenler, son açılanlar). **Dosya gösterip kullanmayanlar:** Çöp kutusu, Arşiv içi, Kasa, Gizli dosyalar, Yinelenenler, Benzerler, Sohbet temizliği, Önemli, Üretilenler (+ İşlemler listesi) — sıralama/süzgeç/boş durum her birinde farklı ya da yok (U10'un devamı). | `grep FmFileListView` |
| G12 | Izgarada iki parmakla sütun değiştirme yalnız Fotoğraflar'da; gezgin ve kategoride yok. | `photos/grid.dart:234` |
| G13 | İndirilenler'in `_sorted` getter'ı **her `build`'de** süzüp sıralıyor (B1'in kardeşi). | `downloads_screen.dart:96` |
| G14 | 5.000 öğede **yukarı** kaydırmada p99 50 ms (KALANLAR); satır yüksekliği sabitlenmemiş. | `docs/perf/2026-10-21.md` |
| G15 | **Panoda son açılan dosyalar görünmüyor** — "az önce açtığım dosya" iki dokunuş (Geçmiş kutusu → Açılanlar). | `services/fm/dashboard_layout.dart:21` |
| G16 | Dosya eylem sayfası ~27 eylem, 4 grup; en sık 5 eylem için üstte hızlı sıra yok. | `entry_actions/sheet.dart:124-240` |
| G17 | **Geniş ekran düzeni yalnız gezginde** (≥ 840 dp). Pano, görüntüleyiciler, düzenleyiciler, ayarlar telefona göre. Android 16'da hedef API 36 olan uygulama **sw ≥ 600 dp ekranda yön/yeniden boyut kısıtlarını yok sayar**; Play hedef API 36'yı Ağustos 2026'dan beri istiyor, API 37'de bu davranıştan çıkış yolu kalmıyor (Ek E). | `browser_screen.dart:201` |

#### 3.14.6 Görüntüleyici, medya, sistem

| # | Bulgu | Kanıt |
|---|---|---|
| G18 | Video oynatıcıda **parlaklık kaydırması, uzun basışta 2× hız, kontrol kilidi** yok (ses kaydırması, çift dokunuşla ±10 sn, hız, altyazı var). | `media_player/actions.dart:138-229` |
| G19 | Galeride slayt gösterisi, "Önemli"ye ekle, "Farklı kullan" (duvar kâğıdı/kişi fotoğrafı — `ACTION_ATTACH_DATA`) yok. | `image_gallery_screen.dart:434-460` |
| G20 | Okurken üst/alt çubukları gizleyen **tam ekran okuma kipi** PDF/metin/Word görüntüleyicisinde bulunamadı (kod taraması — Faz 18'de cihazda doğrulanır). | `screens/viewer/` |
| G21 | **Sistem entegrasyonu eksikleri:** Material You (duvar kâğıdı rengi) seçeneği yok (`ColorScheme.fromSeed` sabit tohumla); başlatıcı simgesine uzun basınca kısayol yok (yalnız sabitlenmiş kısayol var); Android 12 açılış ekranı varsayılan (`flutter create`); ana ekran pencere öğeleri Android 12 görünüm kurallarına göre gözden geçirilmedi; `HapticFeedback` 13 yerde dağınık, ayarla kapatılamıyor; Android 13 uygulama başına dil (`localeConfig`) yok. | `core/theme.dart:244`, `ci/Extras.kt:396,445`, `ci/res/` |

---

## 4. Kararlar

Faz 0'da cevaplanacak. **"Öneri"** sütunu benim tavsiyem; cevabını **"Karar"**
sütununa yaz. **K13–K17 (2026-10-22)** ilgili fazın başında sorulur; cevap
yoksa "Öneri" uygulanır.

| # | Soru | Seçenekler | Öneri | Etkilediği faz | Karar |
|---|---|---|---|---|---|
| K1 | Syncfusion PDF | (a) Community License başvurusu, kod değişmez · (b) kaldır, kendi PDF motorumuz + `pdf` paketi + pdfrx 2.x | **Kısa vadede (a)** (şartları sağlıyorsan bugün ücretsiz ve risksiz); Faz 8'de (b)'nin maliyeti yeniden ölçülür | 7, 8 |  **(a)** Community License — 2026-10-21 |
| K2 | Video motoru | (a) FFmpeg kalsın (15,5 MB, LGPL yükümlülüğü) · (b) Android Media3 Transformer (Apache 2.0, donanım kodlayıcı, ~1-2 MB) | **(b)** — boyut + lisans + patent sadeliği. *Not: 2026-09-26'da "ffmpeg kalsın" kararı verilmişti; ticari hedef ve boyut isteğiyle yeniden soruluyor* | 7, 10 |  **(b)** Media3 Transformer (Faz 10) — 2026-10-21 |
| K3 | Cihaz-içi çeviri (ML Kit, 16,4 MB) | (a) kalsın (çevrimdışı) · (b) kaldır → Gemini çevirisi + "Google Çeviri'de aç" | **(b)** — APK'nın %21'i tek özellik için | 7 |  **(a) kalsın** — çevrimdışı çeviri sürer — 2026-10-21 |
| K4 | AI erişimi | (a) kullanıcı kendi Gemini anahtarı (bugün) · (b) bizim sunucumuz üzerinden (ücretli, Pro'ya bağlı) · (c) cihaz-içi Gemini Nano (yalnız yeni amiral gemisi telefonlar) | **(a) + anahtarsız temiz deneyim** (N3); gelir modeli netleşince (b) | 5, 11 |  **(a)** kendi anahtarı + anahtarsız temiz deneyim — 2026-10-21 |
| K5 | Google Drive | (a) tam `drive` kapsamı (CASA denetimi şart) · (b) `drive.file` (yalnız uygulamanın dosyaları) · (c) Drive ekranı kalkar, sistem belge seçicisi + "Drive'a gönder" paylaşımı | **(c)** — `google_sign_in` ve 1.900+ satır kalkar, yayın engeli kalmaz | 2, 7 |  **(a) tam kapsam kalsın** — Drive ekranı kalır; yayından önce CASA — 2026-10-21 |
| K6 | Gelir modeli | ücretsiz · reklam · tek seferlik Pro · abonelik | **Reklamsız + tek seferlik Pro** (Play Billing). Reklam SDK'sı APK'yı, gizliliği ve "hızlı/sade" ilkesini bozar | 11 |  **Reklamsız + tek seferlik Pro** — 2026-10-21 |
| K7 | Depo görünürlüğü | public (Actions ücretsiz) · private (2.000 dk/ay) | **Ticari yayından önce private** (Faz 1 sonrası dakika yeter) | 1, 11 |  **Ticari yayından önce private** (şimdilik public) — 2026-10-21 |
| K8 | Çıkarılacak/gizlenecek özellikler (§3.5 aday tablosu) | her satır için Kaldır / Deneysel / Kalsın | Tablodaki öneriler | 2 |  SD birleşik → **Deneysel, varsayılan kapalı** · ham USB yazma → **kalsın + sağlamlaştır** (güvenli yazma sırası, geri-okuma doğrulaması, yarıda kalanı onarma; Faz 4/10) · yüzen oynatıcı → **PiP** (Faz 10) · Faturalar → **AI Merkezi içine** · Anılar→İnsanlar → **kaldır** · USB teşhis → **geliştirici menüsü** · son kullanım (app_usage) → **kalsın** · görünüm → **sadeleştir** (4 tema/3 font/3 yerleşim) — 2026-10-21 |
| K9 | En düşük Android | 24 (7.0, bugün) · 26 (8.0) | **24 kalsın** (düşük donanım hedefi) | — |  **24 kalsın** — 2026-10-21 |
| K10 | Masaüstü / iOS | şimdi · yayından sonra · hiç | **Yayından sonra** — şimdilik yalnız Android | 0 |  **Hiç** — yalnız Android (CLAUDE.md hedefi güncellendi) — 2026-10-21 |
| K11 | Dağıtım kanalı | yalnız Play · Play + GitHub Releases | **Play (AAB)**; GitHub Releases yalnız iç test (nightly) | 1, 11 |  **Play (AAB) + GitHub nightly** — 2026-10-21 |
| K12 | Eski PDF kelime-bazlı düzenleme yolu | cihazda paragraf motoru doğrulanınca sil · hemen sil | **Faz 8'de**: paragraf motorunun reddettiği belgelerde "sayfaya yazı ekle" yedeğiyle değiştirilip silinir | 8 |  **Faz 8'de sil** — 2026-10-21 |
| K13 | **Sistem rengi (Material You)** (2026-10-22) | (a) 5. görünüm "Sistem rengi" — Android 12+'da duvar kâğıdından (`dynamic_color`, BSD-3) · (b) ekleme (K8'deki 4 tema sadeliği korunur) | **(a)**, yalnız Android 12+'da listelenir; ana ekran pencere öğeleri de aynı renkleri alır | 19 |  |
| K14 | **Boyutlandırmada büyütme** (2026-10-22) | (a) yasak (bugün; sessizce kaynağa kırpılıyor) · (b) izinli + "büyütmek netlik eklemez" uyarısı | **(b)** — kullanıcı "istediğim oranda" diyor; uyarı dürüstlüğü korur | 14 | (b) — cevap yok, öneri uygulandı (14a; yalnız fotoğrafta, videoda büyütme yok) |
| K15 | **Görsel çıktı motoru** (2026-10-22) | (a) saf Dart `image` paketi (bugün) · (b) Android yerel (BitmapFactory + ExifInterface + `Bitmap.compress`) birincil, Dart yedek | **(b)** — HEIC okuma (Android 9+), WebP yazma, EXIF'i koruma, `inSampleSize` ile düşük cihazda hız ve bellek; Dart yolu test referansı ve yedek kalır | 14 |  |
| K16 | **Panoya "Son açılanlar" şeridi** (2026-10-22) | (a) varsayılan görünür · (b) eklenir ama varsayılan gizli ("Ana ekranı düzenle"den açılır) · (c) eklenmez | **(b)** — pano tasarımı 2026-10-18 kararıyla korunuyor; mevcut kullanıcının ekranı kendiliğinden değişmez (`DashboardLayout` "yeni kimlik görünür eklenir" kuralına bilinçli istisna) | 17 |  |
| K17 | **Süzgeç/sıralama hafızası** (2026-10-22) | (a) her ekran son süzgecini kalıcı hatırlar · (b) her açılışta temiz · (c) karışık | **(c)** sıralama + yerleşim ekran başına **kalıcı**; tür/tarih süzgeci **oturum boyunca** (uygulama yeniden açılınca temiz) — "liste neden boş?" şaşkınlığı olmasın | 13, 17 | (c) — cevap yok, öneri uygulandı (Faz 13) |

---

## 5. Hedef bilgi mimarisi

Bugün 87 ekran; hedef **aynı yetenekleri ~55 ekranda** ve 5 ana kapıdan
sunmak. Alt çubuk özelleştirilebilir kalır (2026-10-18 kararı).

```
Ana ekran (pano — mevcut tasarım korunur)
├─ Bellek panosu ──────────► Depolama merkezi
│                             ├─ Yer aç (öneriler)
│                             ├─ Büyük / eski dosyalar (İndirilenler yaşı dahil)
│                             ├─ Kopyalar · Benzerler
│                             ├─ Sohbet medyası
│                             └─ Klasör haritası · Boş klasörler · Uygulama boyutu
├─ Kategoriler (Görseller, Videolar, Ses, Belgeler, Arşivler, APK) ─► FmFileListView
├─ Klasörler / birimler (dahili, SD, USB, ağ) ─────────────────────► Gezgin (FmFileListView)
└─ Araçlar
   ├─ Tara · PDF araçları · Dönüştür · Metni tanı (OCR)
   ├─ Aktar: Bilgisayarla (FTP + tarayıcı/QR) · Telefonla · Ağ depolama · İndirmeler
   ├─ Kasa (şifreli; gizli dosyalar + klasör kilidi + uygulama kilidi tek PIN)
   ├─ Geçmiş: Açılanlar · Üretilenler · İşlemler · Yeni gelenler
   ├─ AI Merkezi: Sohbet · Akıllı klasörler · (Faturalar)
   └─ Uygulamalar (APK)
Ayarlar (57 → ~35 ayar; Görünüm · Dosyalar · Depolama · Gizlilik · AI · Hakkında/Lisanslar/Yardım)
```

---

## 6. Fazlar

### Faz 0 — Kararlar ve proje hijyeni

**Amaç:** Sonraki 12 fazın dayandığı kararları netleştirmek ve her oturumun
okuduğu belgeleri hafifletmek.

**Yapılacaklar:**
1. §4'teki K1–K12'yi kullanıcıyla tek tek geç, "Karar" sütununu doldur.
2. **HAFIZA bölünmesi (H1):** `HAFIZA.md` → dizin (Sabit Kararlar, Bilinen
   Tuzaklar, Reddedilen Yollar, Build Geçmişi özeti; ≤ 600 satır). Tarihli tur
   kayıtları `docs/hafiza/YYYY-MM.md` arşivlerine **kelimesi kelimesine**
   taşınır (silme yok — append-only ilkesi arşivde sürer). CLAUDE.md'deki
   "oku: iş başı" kuralı dizini işaret eder, arşiv yalnız gerektiğinde aranır.
3. **KALANLAR ayrımı (H2):** gerçek işler faz numarasıyla `KALANLAR.md`'de;
   cihaz doğrulamaları `docs/CIHAZ_TESTI.md`'ye; bayat maddeler (B8) kapatılır.
4. README güncelle (B9), CLAUDE.md istatistiği ve "oturum dalı birleştirildikten
   sonra silinir" kuralı (B10, H4). Birleştirilmiş eski `claude/*` ve `ccr-*`
   uzak dallarının listesi çıkarılıp **kullanıcı onayıyla** silinir.
5. Yerelde `graphify update .` (H3) — bulut oturumunda kurulu değil, kullanıcı
   kendi makinesinde koşturur.

**Kabul ölçütleri:** K1–K12 dolu · HAFIZA.md ≤ 600 satır ve arşivlerin toplamı
eski dosyayla aynı içerik (satır sayısı kontrolü) · KALANLAR'da cihaz maddesi
kalmamış · README güncel.

**Risk:** düşük (yalnız belge). Kod değişmez → CI APK derlemez (`**.md`).

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 0'ı uygula. Önce §4 kararlarını
> benimle tek tek geç (her birinde önerini ve etkisini kısaca söyle), cevapları
> tabloya yaz; sonra HAFIZA/KALANLAR/README/CLAUDE.md hijyen adımlarını yap.
> Hiçbir kaydı silme, arşive taşı. Bitince durum tablosunu güncelle ve main'e
> birleştir.

---

### Faz 1 — CI/CD hızlandırma ve sürüm hattı

**Amaç:** Her sonraki fazın doğrulama döngüsünü kısaltmak; Release kirliliğini
bitirmek; Play şartlarını (16 KB, boyut bütçesi) otomatik denetlemek.

**Ön koşul:** Faz 0 (K7, K11 kararları).

**Yapılacaklar (§3.8):**
1. C2 `concurrency` + iptal.
2. C1 iş bölümü: `verify` (pub get → analyze → test; her dalda, main dahil) ∥
   `apk` (derleme) → `release` (`needs: [verify, apk]`, yalnız main/etiket).
   Eski `test` işinin "main'de koşma" koşulu kalkar.
3. C3 Flutter önbelleği; Gradle için `gradle/actions/setup-gradle` (main dışı
   salt okunur önbellek).
4. C4 push'ta yalnız arm64; `v*` etiketi ya da elle tetiklemede arm + arm64 +
   AAB.
5. C5 sürüm stratejisi: main → artifact + tek `nightly` ön sürüm (üzerine
   yazılır, `make_latest: false`); `v*` etiketi → gerçek Release. Eski
   sürümleri budayan adım (son 10 kalsın — **ilk koşudan önce kullanıcı onayı**).
6. C6 Release tek adım (`gh release create/upload` + 3 deneme, 30/90/240 sn).
7. C7 Android yamaları `ci/prepare_android.sh`'a taşınır (davranış birebir;
   yerelde `bash ci/prepare_android.sh` ile denenebilir). `ci/build-trigger.txt`
   silinir (D7).
8. C8 `paths-ignore` genişler; yalnız `test/**` değişen push'ta `apk` atlanır.
9. C9 `--obfuscate --split-debug-info=build/symbols`; semboller artifact.
   Öncesi/sonrası `libapp.so` boyutu adım özetine yazılır.
10. C10 denetimler: `zipalign -c -P 16 -v 4`, APK içindeki her `.so` için ELF
    `LOAD` hizası ≥ 0x4000, arm64 APK boyut bütçesi (başlangıç: 80 MB; Faz 7'de
    düşürülür).
11. C11 `ci/**` değişince `verify` içinde `tool/check_kotlin.sh`.
12. C12 adım adları, `timeout-minutes`.

**Kabul ölçütleri:** main push duvar süresi ≤ 8 dk (iki ölçüm) · özellik dalı
≤ 3,5 dk · art arda iki push'ta ilki iptal · 16 KB denetimi yeşil · nightly
ön sürüm tek kayıt olarak güncelleniyor · `v1.1.0` gibi bir etiketle gerçek
Release çıkıyor.

**Doğrulama:** iş akışı değişikliği bir özellik dalında `workflow_dispatch` ile
denenir, sonra main.

**Risk:** orta — imza/sürüm numarası adımları bozulursa güncelleme kurulmaz.
Sürüm numarası ve imza adımlarına **dokunulmaz**, yalnız taşınır; ilk koşuda
`apksigner verify --print-certs` çıktısı önceki sürümle karşılaştırılır.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 1'i (CI/CD) uygula. §3.8'deki
> C1–C12'yi yap; imza ve sürüm numarası davranışını değiştirme. Eski sürümleri
> budama adımını etkinleştirmeden önce bana sor. Ölçtüğün yeni süreleri
> durum tablosuna ve HAFIZA'ya yaz, main'e birleştir.

---

### Faz 2 — Sadeleştirme I: ölü kod, eski yollar, özellik birleştirme/çıkarma

**Amaç:** Kapsamı küçültmek — sonraki performans ve tasarım emeği çıkacak koda
harcanmasın.

**Ön koşul:** Faz 0 (K5, K8, K10), Faz 1.

**Yapılacaklar:**
1. **Ölü kod (D1, D4, D7, D9):** Ek C listesi silinir; `cupertino_icons`
   kalkar; manifest temizliği. Test-yalnız semboller `@visibleForTesting` (D2).
2. **K8'e göre çıkarılanlar:** her biri için ekran + servis + Kotlin + manifest
   girdisi + ayar + çeviri anahtarları + testler birlikte kalkar. Kullanıcı
   verisine dokunan özellik (SD birleşik depolama, kasa) kalkıyorsa: açılışta
   bir kez **geri alma/taşıma yolu** (ör. SD işi kaldırılır ama taşınmış dosyalar
   yerinde kalır, kullanıcıya bir kez bilgi verilir).
3. **Birleştirmeler (§3.5):**
   - Geçmiş tek ekran (4 bölüm). Bildirim/iş yönlendirmeleri
     (`job_navigation.dart`) yeni ekrana bağlanır.
   - Kasa birleşimi: `HiddenVault` öğeleri ilk açılışta `SecureVault`'a
     taşınır (önce şifreli kopya + doğrulama, sonra eski kayıt — veri kaybı
     testi şart); klasör kilidi ve uygulama kilidi aynı PIN/biyometriyi kullanır.
   - Depolama merkezi (sekme iskeleti; iç ekranlar şimdilik olduğu gibi gömülür,
     yeniden tasarım Faz 6'da).
   - Aktar merkezi (FTP + HTTP/QR tek ekranda iki sekme).
   - AI Merkezi altına Akıllı klasörler + Faturalar.
4. **K5 (c) ise:** `drive_screen.dart`, `drive_service.dart`, `drive_cache.dart`,
   `google_sign_in`, ilgili ayar ve gizlilik politikası satırları kalkar;
   "Drive'a gönder" paylaşım menüsünden.
5. **Görünüm sadeleşmesi:** tema 10 → 4 aile, arayüz fontu 9 → 3 (Lato ve
   Merriweather kalkar → L2 kendiliğinden kapanır), yerleşim 6 → 3. Eski tercih
   değerleri en yakın yeni değere **eşlenir** (kullanıcının seçimi sıfırlanmaz).
6. Ayarlar 57 → ~35: kalkan özelliklerin ayarları, birleşen ekranların tekrar
   eden ayarları.

**Kabul ölçütleri:** ekran sayısı ≤ 60 · `lib/` satır sayısı en az %12 azalmış
(hedef ≤ 137 bin) · kaldırılan her özellik için "tercih göçü" testi · kasa göçü
testi (gidiş-dönüş, yarıda kesilme) · analyze 0, test yeşil · APK boyutu
adım özetinde düşüş gösteriyor.

**Bölünürse:** 2a = 1, 2, 4, 5, 6 (silme ağırlıklı) · 2b = 3 (birleştirmeler).

> **Sonuç notu (2026-10-21):** K5 (Drive kalsın), K8 (SD birleşik Deneysel, USB yazma ve
> app_usage kalsın) ve K12 (eski PDF yolu Faz 8'de) en büyük silme adaylarını tuttu; bu yüzden
> `lib/` yalnız 155.585 → 155.475 satıra indi ve ekran dosyası sayısı (iki merkez eklendiği
> için) 69 → 71 oldu. Kullanıcının gördüğü kapı sayısı ise azaldı: panodan 11 ayrı araç kutusu
> 2 merkeze, 5 geçmiş ekranı 1'e, 2 gizlilik yolu 1 kasaya indi. Manifest temizliği (D9)
> bilinçli yapılmadı (Android 10 ve 7 için gerekli). Yeni iş: **ham USB yazmayı sağlamlaştır**
> (K8) — güvenli yazma sırası, geri-okuma doğrulaması, kirli bayrakla onarım → Faz 4 ya da 10.

**Risk:** orta — kullanıcı verisi taşıyan göçler. Her göç önce kopyala →
doğrula → sonra sil; geri alınabilir.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 2'yi uygula. §4'teki K5/K8
> kararlarına göre çıkar; §3.5'teki birleştirmeleri yap. Kullanıcı verisine
> dokunan her göç için önce kopyala-doğrula-sil sırası ve testi yaz. Kabul
> ölçütlerindeki sayıları ölç, HAFIZA'ya yaz, main'e birleştir.

---

### Faz 3 — Sadeleştirme II: uzun dosyaları bölme + durum yönetimi

**Amaç:** Okunabilir, değiştirilebilir kod; gereksiz yeniden kurulumların
kaynağını kurutmak.

**Ön koşul:** Faz 2.

**Yapılacaklar:**
1. **Bölme (Ek B):** davranış değiştirmeyen taşıma. Kural: bir dosya bir
   sorumluluk; ekran dosyası ≤ 800 satır, servis ≤ 1.000 (formül motoru gibi
   tablolar hariç ama o da kategori dosyalarına).
   - `viewer_screen.dart` (4.065) → `viewer/pdf_view.dart`, `text_view.dart`,
     `image_view.dart`, `viewer_menus.dart`, `viewer_shell.dart`.
   - `spreadsheet_editor_screen.dart` (4.025) → ızgara, formül çubuğu, sayfa
     sekmeleri, araç şeridi, iletişim pencereleri, seçim/klavye.
   - `dashboard_screen.dart` (3.285) → `dashboard/` altında hero, birimler,
     kategori ızgarası, hızlı dock, durum kartları.
   - `formula_engine.dart` (2.580) → ayrıştırıcı + işlev kategorileri
     (matematik, metin, tarih, arama, mantık).
   - `entry_actions.dart` (1.803) → eylem tanımları / levha / yürütücüler.
   - `app_strings.dart` (8.317) → alan başına `part` dosyaları
     (`l10n/fm.dart`, `l10n/pdf.dart`…); üç dilli kayıt yapısı ve "eksik dil =
     derleme hatası" güvencesi korunur.
2. **AppState'in parçalanması (P3):** `AppearanceState` (tema, dil, yazı
   ölçeği, font), `BrowseState` (yerleşim, sıralama, gizli, kilitli klasörler),
   `RecentsState`, `ClipboardState`, `RemotesState`, `AiSettingsState`.
   `MaterialApp` yalnız `AppearanceState`'i izler. `context.watch<AppState>()`
   kullanan 65 yer `select`/ilgili bildiriciye geçer. Prefs anahtarları
   **değişmez** (göç gerekmesin).
3. B1 (`_sorted`) burada kapanır: sıralı liste alanda.

**Kabul ölçütleri:** 800 satırı aşan ekran dosyası yok · kökte `AppState`
izleyen yok · "dosya aç → MaterialApp yeniden kurulmuyor" testi (yeniden kurulum
sayacıyla) · analyze 0, test yeşil (test dosyaları yalnız import yolu değişir).

**Risk:** düşük-orta (büyük ama mekanik). Her bölme ayrı commit; testler her
committe yeşil.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 3'ü uygula. Ek B'deki dosyaları
> davranış değiştirmeden böl, AppState'i §Faz 3 madde 2'deki bildiricilere ayır
> (prefs anahtarları aynı kalsın). Her bölme ayrı commit olsun, her committe
> testler yeşil. HAFIZA'ya yaz, main'e birleştir.

---

### Faz 4 — Performans: düşük donanım profili ve ölçüm

**Amaç:** En düşük donanımlı telefonda akıcı; boşta sıfır iş; arka planda gereksiz
CPU/RAM/pil yok.

**Ön koşul:** Faz 3.

**Yapılacaklar (§3.1):**
1. **Ölçüm önce (P13):** `integration_test` senaryoları — soğuk açılış, 5.000
   öğeli klasörde kaydırma + sürükleyerek seçim, 2.000 fotoğraflı galeri,
   100 sayfalık PDF açılışı, 10 bin satırlık Excel. `traceAction` özetleri
   (ortalama/90./99. yüzdelik kare süresi) `docs/perf/` altına; Ek D protokolü.
2. **Cihaz profili (P1):** `Extras.kt`'ye `deviceClass()` (toplam RAM,
   `isLowRamDevice`, çekirdek sayısı, `mediaPerformanceClass`) → Dart
   `DeviceProfile.low/mid/high`. Ayarlarda "Başarım: Otomatik / Hafif / Tam".
3. Profile bağlananlar: görsel önbelleği (P2), küçük resim eşzamanlılığı
   (2 → 1), nabız/giriş animasyonları, 120 Hz varsayılanı (P12), otomatik
   yeniden tarama, açılış işleri (P11), yüz/benzer görsel taramaları.
4. P4 PDF metni tembel · P5 uygulama boyutları tembel + kalıcı önbellek ·
   P6 birim değişimi yayınla · P7 `TickerMode` · P8 (Faz 3'te kapandıysa ölç) ·
   P9 küçük resim `dpr` · P10 uzun ömürlü arama izolatı.
5. **Açılış bütçesi (P11):** `StartupQueue` — kritik olmayan işler ilk kareden
   2 sn sonra, sırayla, her biri en çok 1 izolat.
6. **Boşta denetim:** pano açık, hiçbir iş yokken 60 sn boyunca planlanan kare
   ve zamanlayıcı sayısı 0 (testle: `SchedulerBinding` kare sayacı).

**Kabul ölçütleri (Ek D cihazında, profile derleme):** soğuk açılış ilk kare
≤ 1,2 sn, etkileşim ≤ 2 sn · 5.000 öğeli klasörde kaydırmada 99. yüzdelik kare
≤ 24 ms · galeride 2.000 fotoğraf kaydırma sonrası bellek (RSS) ≤ 350 MB
(hafif profilde ≤ 250 MB) · boşta kare/zamanlayıcı 0 · ölçümler öncesi/sonrası
tabloyla HAFIZA'da.

**Risk:** düşük-orta. Hiçbir iyileştirme ölçümsüz birleşmez.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 4'ü uygula. Önce Ek D'deki
> senaryoların ölçüm testlerini yaz ve öncesi değerlerini al; sonra P1–P13'ü
> uygula ve her birinin etkisini aynı ölçümle göster. Cihaz profili ayarını
> ekle. Sonuç tablosunu HAFIZA'ya ve `docs/perf/`'e yaz, main'e birleştir.

---

### Faz 5 — Son kullanıcı iletişimi altyapısı

**Amaç:** Hiçbir özellikte "ne oluyor, bir şey oldu mu?" sorusu kalmasın; ham
hata metni, sessiz başarısızlık ve açıklamasız izin kalmasın.

**Ön koşul:** Faz 3 (tasarım fazından önce gelir — yeni ekranlar bu altyapıyla
yazılsın).

**Yapılacaklar (§3.7):**
1. `core/user_error.dart` — `UserError.from(e)` (eşleme tablosu §3.7) +
   ortak gösterim: kısa mesaj + "Ayrıntı" + "Yeniden dene" + otomatik
   `CrashLog`. 103 ham hata yeri buna geçer (I1); I2-I4 sabit metinler
   çeviriye.
2. **Sessiz catch denetimi (I5):** 348 yerin listesi çıkarılır; her biri
   "bilinçli en iyi çaba" (yorumla gerekçe) ya da "kullanıcıya söyle" olarak
   işaretlenir. Kullanıcı eylemine bağlı olanların hepsi ikinci sınıfta.
3. **İzin bileşeni (I6):** `PermissionGate` — neden gerekli, ne olursa ne
   olmaz, "Ayarlara git", geri dönünce kendini tazeler. Tüm dosyalar, bildirim,
   kamera, kullanım erişimi, üstte gösterme (kalırsa), konum (Anılar → Yerler).
   Bildirim izni yoksa uzun iş başlatıldığında bir kez söylenir.
4. **Çevrimdışı bileşeni (I9)** ve **AI anahtarsız durumu (I8, N3).**
5. **Bekçi testler:** ekran kodunda `'$e'` / `{'error': e}` deseni; `catch (_) {}`
   ekran kodunda gerekçe yorumu olmadan; çeviri bekçisinin kaçırdığı
   `_snack(context, '…')` ve çok satırlı dize desenleri.
6. Yardım/SSS ekranı iskeleti (N11) — içerik Faz 11'de tamamlanır.

**Kabul ölçütleri:** ekran kodunda ham hata deseni 0 · gerekçesiz boş catch 0 ·
EN ve AR arayüzde Türkçe metin 0 (bekçi testi) · her izin için reddedildi
senaryosu widget testi · "dosya izni yok / yer yok / dosya yok" için birim test.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 5'i uygula. `UserError` ve
> `PermissionGate` altyapısını kur, §3.7'deki I1–I9'u kapat, bekçi testleri ekle.
> Sessiz catch listesini sınıflandırıp gerekçeleri yaz. HAFIZA'ya yaz, main'e
> birleştir.

---

### Faz 6 — Klasör içi / gezgin / filtre / simge yeniden tasarımı

**Amaç:** §3.2'deki hedef tasarım: tek liste bileşeni, görünür sıralama/filtre,
modern satır ve ızgara, tutarlı simge dili, tablet düzeni.

**Ön koşul:** Faz 4 (ölçümler hazır — tasarım akıcılığı bozmasın), Faz 5.

**Yapılacaklar:**
1. Önce **görsel tasarım taslağı:** liste, ızgara, seçim, filtre levhası, boş
   durum, tablet — açık/koyu. Testte `RepaintBoundary.toImage` ile PNG üretilip
   (HAFIZA 2026-10-17 (3) D yöntemi) kullanıcıya gösterilir; **onaydan sonra**
   uygulanır.
2. `FmFileListView` + `FmEntryRow` (kendi `Row`umuz — 56 dp tavanı kalkar,
   KALANLAR maddesi kapanır) + `FmEntryCard` (ızgara) + `FmListToolbar`
   (sayaç, sıralama, filtre, gruplama) + `FmPathBar` (`popUntil`, B2 kapanır).
3. Gezgin, kategori, arama, indirilenler, yeni dosyalar, son açılanlar, AI
   sonuç listesi, seçici kipi bu bileşene geçer (U10).
4. Filtreler gezgine (U3); yerleşim 3'e (U5); boş durum (U6); bağlamsal "+"
   (U7); metinli seçim menüsü (U8).
5. **Simge sistemi (U9):** `core/app_icons.dart` — uygulamadaki tüm eylem
   simgeleri tek tabloda (anlamsal adlar: `AppIcons.move`, `AppIcons.share`…),
   tek glif ailesi, üç boy; dosya türü renkleri `FmColors`'tan; bekçi test.
6. **Tablet (U11):** ≥ 840 dp'de iki bölme.
7. Erişilebilirlik: dokunma hedefleri ≥ 48 dp, `Semantics` etiketleri, 1,4×
   yazı ölçeğinde taşma yok (mevcut duman testi deseni).

**Kabul ölçütleri:** 8 liste ekranı tek bileşeni kullanıyor · yol hapına
dokunmak yığını büyütmüyor (test) · sıralama ve etkin filtre ekranda görünüyor ·
Faz 4 ölçümlerinde kaydırma metrikleri kötüleşmemiş · 360 dp ve 1,4× yazıda
taşma yok · onaylı tasarım PNG'leri `docs/design/` altında.

**Bölünürse:** 6a = 1-3 (bileşen + gezgin) · 6b = 4-7.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 6'yı uygula. Önce §3.2'deki hedef
> tasarımın PNG taslaklarını (açık/koyu, liste/ızgara/seçim/filtre/boş/tablet)
> üret ve bana göster; onayımdan sonra `FmFileListView` ve simge sistemini kur,
> 8 liste ekranını taşı. Faz 4 ölçümlerini yeniden koş. HAFIZA'ya yaz, main'e
> birleştir.

---

### Faz 7 — Bağımlılık diyeti, Flutter yükseltmesi, lisans uyumu, APK boyutu

**Amaç:** Lisans risklerini kapatmak, APK'yı küçültmek, 3.29.3 sürüm duvarını
yıkmak (pdfrx 2.x, güncel ML Kit, Syncfusion yeni sürümleri, AGP 9 zinciri).

**Ön koşul:** Faz 2, K1-K5 kararları.

**Yapılacaklar:**
1. **Lisans (L1-L4, B4-B6):** K1 (a) ise Community License belgesi
   `docs/lisans/` altına (repo private değilse kişisel bilgi olmadan); uygulama
   içi lisans sayfası (`showLicensePage` + fontlar/JS/FFmpeg için
   `LicenseRegistry`) (N2); yanlış lisans metni düzeltilir; FONTS-NOTICE
   düzeltilir; kalan fontlar için RFN denetimi testi (altkümelenen fontun `name`
   tablosunda "Reserved Font Name" varsa kırmızı).
2. **K2 (b):** `ci/MediaTranscode.kt` — Media3 Transformer (çözünürlük, kare
   sayısı, bit hızı, sesi at); `ffmpeg_kit_flutter_new_min` + `video_compress`
   kalkar; `video_transcode.dart` arayüzü aynı kalır; LICENSES.md güncellenir.
3. **K3 (b):** `google_mlkit_translation` kalkar; çeviri Gemini (anahtar
   varsa) + "Google Çeviri'de aç" (`ACTION_PROCESS_TEXT`/paylaşım).
4. **`excel` paketinin çıkması (D6):** okuma zaten kendi `xlsx_reader`'ımızda;
   yazma `xlsx_save_patch`/`xlsx_writer`'a taşınır. Böylece `archive ^4`,
   `image` 4.4+, pdfrx 2.x yolu açılır.
5. **Flutter yükseltmesi:** HAFIZA 2026-08-28'e göre 3.44.x'te testler zaten
   yeşil; asıl iş Android zinciri (AGP/Gradle/Kotlin/NDK) — Faz 1'deki
   `flutter_version` girdisiyle deneme derlemesi, yeşilse varsayılan taşınır;
   sabitlenmiş paketler (`video_player_android`, `audioplayers_android`,
   ML Kit, Syncfusion, `permission_handler`…) tek tek güncellenir. `withOpacity`
   gibi kullanımdan kaldırmalar temizlenir.
6. **Boyut (§3.9):** font altkümeleri, `cupertino_icons` (Faz 2'de), boyut
   bütçesi CI'da yeni değere indirilir.
7. `installed_apps`/`app_usage` sadeleşmesi (K8 sonucuna göre).

**Kabul ölçütleri:** lisans taramasında "ticari/GPL/RFN ihlali" 0 (K1 (a)
seçildiyse belgeyle) · uygulama içi lisans sayfası tüm paketleri ve gömülü
varlıkları listeliyor · arm64 APK ≤ hedef (K2+K3 evet: ≤ 48 MB; hayır: ≤ 72 MB) ·
CI yeni Flutter sürümünde yeşil · 16 KB denetimi yeşil.

**Bölünürse:** 7a = 1-3, 6 (lisans + boyut) · 7b = 4-5 (excel + Flutter).

**Risk:** yüksek (sürüm yükseltmesi). Yükseltme ayrı dalda; APK telefonda
kurulup temel akışlar (aç, kopyala, PDF, video) elle denenmeden main'e girmez.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 7'yi uygula. §4'teki K1–K3
> kararlarına göre bağımlılıkları değiştir, lisans sayfasını ve RFN denetimini
> ekle, `excel` paketini çıkar, sonra Flutter yükseltmesini Faz 1'deki deneme
> girdisiyle dene. APK boyutunu öncesi/sonrası ölç. Yükseltme APK'sı telefonda
> denenmeden main'e birleştirme — bana sor.

---

### Faz 8 — PDF akışı (tek çatı)

**Amaç:** PDF'te görüntüleme → düzenleme → araçlar → kaydetme tek, anlaşılır
akış; yedi yüzeyin tek çatıya inmesi; eski yolun silinmesi.

**Ön koşul:** Faz 6, Faz 7 (K1, K12).

**Yapılacaklar:**
1. Görüntüleyicide alt çubuk: Ara · Düzenle · Araçlar · Paylaş · ⋮.
   "Düzenle" → kip seçici (Metin · Kalem · İmza · Form · Sayfalar · AI);
   hepsi aynı kaydetme akışı (üzerine yaz / kopya, `PdfEditJournal` güvencesi).
2. **K12:** paragraf motorunun reddettiği belgeler için "sayfaya yazı kutusu
   ekle" yedeği; ardından D3'teki eski yol (~1.600 satır + görüntüleyicideki
   zincir + testleri) silinir.
3. K1 (b) seçildiyse Syncfusion'ın 7 kullanımı kendi motorumuza/pdfrx 2.x'e
   taşınır (sayfa döndür/sil/sırala/birleştir/böl, vurgu, form, parola).
4. Y3 maddeleri: `/ToUnicode`'suz fontlarda AGL tablosu, iki yana yaslı satır,
   CropBox kaydırması.
5. Okuma: P4 tembel metin (Faz 4'te yapıldıysa doğrula), kaldığı yer, gece
   modu, okuma görünümü — tek "Aa" levhası.
6. **Örnek dosya seti** (`test/fixtures/pdf/`): metinli, taranmış, parolalı,
   formlu, döndürülmüş, CropBox'lı, Türkçe karakterli, 300+ sayfa. Her biri için
   aç → düzenle → kaydet → yeniden aç → içerik doğrulama testi.

**Kabul ölçütleri:** PDF düzenleme giriş noktası 1 · eski yol silinmiş · örnek
setin tamamında duman testi yeşil · Faz 4 PDF açılış ölçümü kötüleşmemiş.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 8'i uygula. PDF'i §Faz 8'deki tek
> çatıya indir, K12'ye göre eski düzenleme yolunu yedeğiyle değiştirip sil,
> K1 kararına göre Syncfusion'ı koru ya da taşı. Örnek PDF setini ve duman
> testlerini kur. HAFIZA'ya yaz, main'e birleştir.

**Sonuç (2026-10-21):** kabul ölçütleri — düzenleme giriş noktası 1 (alt çubukta
"Düzenle"; seçim çubuğundaki "Düzenle" de aynı düzenleyiciye gider) ✅ · eski yol silindi
✅ · örnek setin tamamında duman testi yeşil (`pdf_fixture_smoke_test`, 18 test) ✅ ·
PDF açılış ölçümü: cihaz yok, ölçülmedi (Faz 4'ün kendisi de bekliyor). K1 (a) → Syncfusion
kaldı. Y3: AGL ve iki yana yaslama paragraf motorunda zaten vardı; CropBox "yazı ekle"
için ölçüldü, vurgu için cihazda (`docs/CIHAZ_TESTI.md`).

---

### Faz 9 — Office ve metin akışları

**Amaç:** Word, Excel, Slayt ve metin dosyalarında uçtan uca akışın (§3.10)
eksiksiz ve hatasız olması; yarım kalanların (Y1, Y2, Y4) kapanması.

**Ön koşul:** Faz 6, Faz 7 (`excel` çıkmış olmalı).

**Yapılacaklar:**
1. **Word:** tablo hücre metni düzenleme (yapı değil, içerik), resim ekleme/
   silme (konumlandırma satır içi), seçili metin çevirisi (JS köprüsü, Y4),
   karakter düzeyinde punto (seçim aralığı → run bölme).
2. **Excel:** kendi yazıcımızla sayfa taşıma/yeniden adlandırma, hizalama okuma
   (paket hatası artık yok), köşegen doldurma, basit grafik ekleme (sütun/çizgi/
   pasta — PPTX tarafındaki çizici yeniden kullanılır).
3. **Slayt:** cihaz doğrulamasında çıkanlar; seçili metin çevirisi.
4. **Metin:** > 5 MB dosyada parçalı okuma ve sanal liste, kodlama algılama
   testleri (UTF-8/UTF-16/Windows-1254/ISO-8859-9), CSV ayırıcı tespiti.
5. **Eski Office:** "salt okunur" rozeti + "DOCX/XLSX'e dönüştür ve düzenle".
6. **Örnek dosya seti** (`test/fixtures/office/`) + aç-düzenle-kaydet-yeniden
   aç duman testleri; Word/Excel'de "masaüstü Office'te açılıyor mu" kontrolü
   için sonuç dosyaları `docs/CIHAZ_TESTI.md`'ye eklenir.

**Kabul ölçütleri:** Y1, Y2, Y4 kapalı · örnek setin tamamında duman testi
yeşil · 10 bin satırlık Excel'de Faz 4 metrikleri korunmuş.

**Bölünürse:** 9a = Word + Metin · 9b = Excel + Slayt.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 9'u uygula. §3.10'daki Word, Excel,
> Slayt ve metin satırlarını ve Y1/Y2/Y4'ü kapat; örnek dosya setini ve duman
> testlerini kur. HAFIZA'ya yaz, main'e birleştir.

**Sonuç (2026-10-21):** Y1 ✅ (tablo hücre metni, seçime punto/yazı tipi, resim ekle/sil
— taşıma yok) · Y2 ✅ (grafik ekleme, köşegen doldurma, sayfa taşıma; hizalama okuma
Faz 7'de) · Y4 ✅ (Excel aralığı, slayt kutusu) · metin: > 5 MB parçalı okuma, kodlama ve
CSV testleri ✅ · eski Office rozeti + dönüştür ✅ · örnek set + duman testleri ✅; Office
çıktıları LibreOffice'te açıldı, Microsoft Office ve 10 bin satır ölçümü cihaz listesinde.
Ek bulgu: Word canlı yazımı Flutter'a hiç gitmiyordu (HAFIZA 2026-10-21 (4)).

---

### Faz 10 — Medya akışları (görsel, video, ses, galeri)

**Amaç:** Medya görüntüleme/yönetme/düzenleme akışlarının tamamlanması;
temel görsel düzenleyici; PiP.

**Ön koşul:** Faz 6, Faz 7 (K2).

**Yapılacaklar:**
1. **Temel görsel düzenleyici (N7):** kırp (oran ön ayarları), döndür/çevir,
   parlaklık/kontrast/doygunluk, işaretle (kalem/ok/metin) — `image` paketiyle
   izolatta, tarama stüdyosundaki kırpma bileşeni yeniden kullanılır; kaydetme
   "kopya olarak" varsayılan.
2. **PiP (N8):** yüzen pencere servisi + `SYSTEM_ALERT_WINDOW` kalkar
   (`FloatingPlayer.kt` 671 satır).
3. **Tek oynatma motoru:** ses de `video_player`/Media3 ExoPlayer üzerinden ya
   da tersi — iki motordan biri kalkar (medya oturumu tek yerde).
4. Galeri/Fotoğraflar: Faz 6 bileşenleriyle uyum, 2.000+ öğede ölçüm, seçim
   ve kaydırma kilidi korunur.
5. Video küçültme (K2'ye göre Media3) — önizleme + boyut tahmini + karşılaştırma
   ekranı (var) korunur.
6. Örnek medya seti (EXIF yönlü JPEG, HEIC, WebP, PNG, MP4/MKV/altyazı,
   MP3/FLAC/M4A etiketli) + duman testleri.

**Kabul ölçütleri:** kırp/döndür/ayar/işaretle çalışıyor ve özgün dosyaya
dokunmadan kopya üretiyor · PiP'te uygulamadan çıkınca video sürüyor ·
`SYSTEM_ALERT_WINDOW` manifestten kalkmış · tek oynatma motoru.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 10'u uygula. Temel görsel
> düzenleyiciyi ekle, yüzen oynatıcıyı PiP ile değiştir, ses/video motorunu
> teke indir; örnek medya setini ve duman testlerini kur. HAFIZA'ya yaz, main'e
> birleştir.

**Faz 10b — kalan (2026-10-22, ☁️ bulut, yürütme sırası 2):** madde 6 — örnek
medya seti `test/fixtures/media/` (üreteci `tool/write_fixtures_test.dart`'a ya
da `tool/make_media_fixtures.py`'ye): EXIF Orientation 1/3/6/8 JPEG (aynı sahne,
yönü belli olsun diye köşede renkli işaret), PNG (saydam), WebP, GIF (hareketli),
HEIC (bulutta üretilemezse küçük, lisansı açık bir örnek ya da cihaz maddesi),
MP4 (H.264/AAC, 3 sn) + MKV + `.srt`, MP3/FLAC/M4A (etiket + kapak). Duman
testleri: görsel düzenleyici (kırp/döndür → kopya → yön doğru), boyutlandırma
(her biçimde çıktı açılıyor, **B11 EXIF yönü şüphesi**), ses etiket okuyucu,
altyazı ayrıştırıcı. Galeride 2.000 fotoğraf RSS ölçümü 📱 cihaz turunda.

> **Açılış istemi (10b):** `docs/FAZ_PLANI.md` Faz 10b'yi uygula (bulut). Örnek
> medya setini üreten aracı yaz, seti `test/fixtures/media/`a koy, duman
> testlerini kur; §3.14 G4l (B11, EXIF yönü) şüphesini bu setle test et ve
> sonucu yaz (düzeltme Faz 14'te). Cihaz maddelerini `docs/CIHAZ_TESTI.md`ye
> ekle. HAFIZA'ya yaz, main'e birleştir.

---

### Faz 11 — Ticari yayın hazırlığı

**Amaç:** Play Store'a çıkışa hazır, politika uyumlu, gelir modeli kurulmuş
sürüm.

**Ön koşul:** Faz 8-10, K4, K6, K7, K11.

**Yapılacaklar:**
1. **İlk açılış rehberi (N1):** 3 ekran — ne yapar · izinler (her biri neden,
   reddedilirse ne olur) · gizlilik + AI veri açıklaması. Seçici kipinde yok.
2. **Play beyanları (§3.12):** her hassas izin için gerekçe metni ve kısa video
   senaryosu `docs/play/` altında; ön plan servisi tür beyanları.
3. **Tahminli geri (Y6):** `WillPopScope`/`onBackPressed` bağımlılıkları
   `PopScope`'a; manifest opt-out kalkar; geri davranışı testleri (açık
   pencereyi kapatma, düzenlemeden çıkarken sorma, kararan ekran koruması).
4. **Gelir modeli (N4, K6):** Play Billing — Pro kilidi tek yerden
   (`ProGate`); Pro'ya giren özellik listesi kullanıcıyla netleşir; satın alma
   geri yükleme.
5. Play İçi Değerlendirme + Güncelleme (N5) — yalnız Play derlemesinde
   (derleme bayrağı).
6. **Gizlilik:** politika (3 dil) güncellenir (kalkan/eklenen özellikler,
   Gemini ücretsiz katman notu, ML Kit/Play Hizmetleri), herkese açık URL;
   Veri güvenliği formu taslağı `docs/play/veri_guvenligi.md`.
7. Gemini anahtarı Keystore sarmalı depolama (bugün prefs'te düz).
8. **Mağaza:** başlık/açıklama (TR/EN/AR), ekran görüntüleri (Faz 6 PNG
   yöntemiyle), marka notu (L6).
9. **K7:** depo private + `LICENSE` (tüm hakları saklı); README'de lisans notu.
10. Yardım/SSS içeriği (N11), "Sorun bildir" (N6).

**Kabul ölçütleri:** iç test kanalına (Play Console internal testing) AAB
yüklenip inceleme uyarısı almadan yayımlanıyor · ilk açılış + izin reddi
senaryoları test edilmiş · satın alma ve geri yükleme test hesabında çalışıyor.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 11'i uygula. İlk açılış rehberini,
> tahminli geri geçişini, Play Billing'i (K6), gizlilik ve Play beyan
> belgelerini hazırla. Depoyu private yapmadan ve Billing ürün kimliklerini
> belirlemeden önce bana sor. HAFIZA'ya yaz, main'e birleştir.

**Bölünme (2026-10-22):**

- **11a — ☁️ bulut (yürütme sırası 9, UX fazlarından sonra):** madde 1 (ilk
  açılış — Faz 15'in tokenlarıyla, Faz 16'nın erişilebilirlik testleriyle),
  madde 3 (tahminli geri: `WillPopScope`/`onBackPressed` → `PopScope`; Android
  16'da hedef API 36 olan uygulamada `onBackPressed` hiç çağrılmıyor, manifest
  kaçışı **geçici** — Ek E), madde 2 ve 6'nın metinleri (`docs/play/`, politika
  3 dil), madde 7 (Keystore — Kotlin + `check_kotlin.sh`), madde 8'in metinleri
  ve **ekran görüntüleri** (`tool/design_shots_test.dart` yöntemiyle, son
  görünümden), madde 10 (Yardım/SSS içeriği — bugün 50 satırlık iskelet;
  "Sorun bildir"). Billing kodu `ProGate` arayüzüyle yazılabilir ama ürün
  kimlikleri olmadan **kapalı bayrakla** birleşir.
- **11b — 👤📱 (yürütme sırası 13):** madde 4'ün ürün kimlikleri ve test
  hesabında satın alma/geri yükleme, madde 5, madde 9 (depo private + LICENSE),
  Play Console iç test yüklemesi, K5 CASA denetimi.

> **Açılış istemi (11a):** `docs/FAZ_PLANI.md` Faz 11a'yı uygula (bulut).
> İlk açılış rehberini, `PopScope` geçişini (manifest kaçışını kaldır, geri
> davranışı testleri), Keystore'lu anahtar saklamayı, Yardım/SSS + "Sorun
> bildir"i, gizlilik ve Play beyan metinlerini, mağaza metinlerini ve ekran
> görüntülerini hazırla. Billing'i kapalı bayrakla bırak. Cihaz maddelerini
> `docs/CIHAZ_TESTI.md`ye ekle, HAFIZA'ya yaz, main'e birleştir.

---

### Faz 12 — Kapanış: hata avı, cihaz doğrulama turu, sürüm adayı

**Amaç:** Yayına çıkacak sürümün (RC) uçtan uca doğrulanması.

**Ön koşul:** Faz 11.

**Yapılacaklar:**
1. **Sistematik hata avı:** `await` sonrası `mounted`, `initState`'te kalıtılan
   bağımlılık, `dispose` edilmeyen denetleyici/akış, ana izlekte senkron G/Ç
   (`*Sync` çağrılarının ekran kodundaki 39 `existsSync` dahil), sınırsız büyüyen
   önbellek/liste, zaman aşımı olmayan ağ çağrısı — her sınıf için betikli tarama
   + bulgu listesi + düzeltme.
2. **Cihaz doğrulama turu:** `docs/CIHAZ_TESTI.md` (Faz 0'da ayrıştırılan ~36
   madde + Faz 6-11'in ekledikleri) en az iki cihazda: biri düşük donanımlı
   (Ek D), biri güncel. Sonuçlar listeye işlenir, kırmızılar düzeltilir.
3. **Kararlılık:** 48 saat iç test; `CrashLog` + Play Console Android Vitals
   (ANR/çökme oranı).
4. Sürüm notları, `v1.x.0` etiketi, AAB → Play kapalı test → üretim.

**Kabul ölçütleri:** açık "kırmızı" cihaz maddesi 0 · ANR oranı < %0,47, çökme
< %1,09 (Play eşikleri) · Faz 4 metrikleri hedefte.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 12'yi uygula. §Faz 12'deki hata
> sınıflarını betikle tara ve düzelt; `docs/CIHAZ_TESTI.md`'yi benimle telefonda
> tek tek geçelim. Sürüm adayını etiketlemeden önce bana sor.

**Bölünme (2026-10-22):**

- **12a — ☁️ bulut (yürütme sırası 11):** madde 1 (betikli hata avı). Taramaya
  eklenenler: Faz 13–19'un yeni bekçi testleri (simge/renk/RTL/`meetsGuideline`)
  tüm `lib/`'de yeşil mi; `setState` sonrası `mounted`; yeni süzgeç/boyutlandırma
  prefs anahtarlarının göç testi.
- **12b — 📱 cihaz turu (yürütme sırası 12):** madde 2 + bekleyen bütün cihaz
  işleri tek oturumda: Faz 4 ölçümleri (Ek D), Faz 10 cihaz turu (galeri RSS),
  Faz 13–19 cihaz maddeleri, R8'li APK açılışı, ham USB yazma, TalkBack,
  başlatıcı kısayolları/pencere öğeleri/açılış ekranı görünüşü. En az iki cihaz
  (biri düşük donanımlı).
- **12c — 👤 (yürütme sırası 14):** madde 3-4 (48 saat iç test, Vitals, RC
  etiketi, Play kapalı test → üretim).

> **Açılış istemi (12a):** `docs/FAZ_PLANI.md` Faz 12a'yı uygula (bulut).
> §Faz 12 madde 1'deki hata sınıflarını ve 12a'daki ek taramaları betikle tara,
> bulgu listesini yaz, düzelt. HAFIZA'ya yaz, main'e birleştir.
>
> **Açılış istemi (12b):** `docs/FAZ_PLANI.md` cihaz turunu (12b) yapalım:
> `docs/CIHAZ_TESTI.md`'yi ve Ek D ölçümlerini benimle telefonda tek tek geç;
> ölçüm verisini telefona koymadan önce bana söyle (`.nomedia`, iş bitince sil —
> HAFIZA 2026-10-22 tuzağı). Kırmızıları aynı oturumda düzelt, main'e birleştir.

---

> **Faz 13–19 (2026-10-22) — görsel ve kullanım deneyimi.** Hepsinin ortak
> kuralları: (1) önce **tasarım PNG'leri** (açık/koyu, 360 dp; gerekiyorsa
> Arapça) `tool/design_shots_test.dart` yöntemiyle üretilip kullanıcıya
> gösterilir, onay beklenirken model ve testlerle ilerlenir; (2) yeni ekran/
> bileşen Faz 5 (`UserError`, `PermissionGate`) ve Faz 15 tokenlarıyla yazılır;
> (3) cihazla doğrulanacak her şey `docs/CIHAZ_TESTI.md`'ye madde olarak girer
> (sıra 12'deki turda kapanır); (4) prefs anahtarı değişen her yerde eski
> değeri yeni değere eşleyen göç testi.

### Faz 13 — Ortak tür süzgeci ve "Son açılanlar" yenilemesi

**Amaç:** Hangi listede olursa olsun **"yalnız PDF'ler"** (ya da yalnız Word,
yalnız videolar…) tek dokunuşla süzülebilsin; süzgeç her ekranda aynı yerde,
aynı görünüşte ve aynı mantıkla çalışsın. Son açılanlar gerçek bir liste ekranı
olsun.

**Kanıt:** G1, G2, G3, G13. **Ön koşul:** Faz 6. **Ortam:** ☁️ tamamı
(yürütme sırası 1). **Karar:** K17.

**Yapılacaklar:**
1. **Tek tür modeli** (saf Dart, `models/fm_type.dart`): üst türler (Klasör,
   Belge, Görsel, Video, Ses, Arşiv, APK, Diğer) + belge alt türleri (**PDF**,
   Word, Excel, Sunum, Metin/Kod, E-kitap, Eski Office). Uzantı → tür eşlemesi
   **tek kaynaktan**: bugün `FsEntry.category` ve `FileService.kindForExtension`
   (DocKind) ayrı tablolar — birleşir. `FmFilter`'a `types` (çoklu) alanı;
   `signature`, `matches`, JSON ve birim testleri.
2. **Tek bileşen** — `FmTypeChips` baştan: tek yatay satır
   `Tümü · PDF 12 · Word 3 · Excel 2 · Görsel 40 · Video 5 · … · Tarih ▾ · Boyut ▾ · ✕ Temizle`.
   Yalnız listede **bulunan** türler; sayılar öteki ölçütlere bağlı ("dokununca
   kaç dosya kalır" — `FmQuickFilters` ilkesi); çoklu seçim (PDF + Word);
   belgeler tek alt türdeyse "Belgeler" tek çip, birden çok alt türdeyse alt
   türler düz çip. `FmQuickFilters`'ın kaynak/birim/açılma çipleri aynı satırda,
   tür çiplerinden SONRA (tek satır kuralı, `kFmFilterBarHeight`).
3. **Uygulanacak ekranlar (hepsi aynı bileşen):** Son açılanlar · Yeni
   gelenler · İndirilenler · Arama (bugünkü kategori çipleri yerine) · Gezgin ·
   Kategori ekranları (Belgeler'deki `_docKindChips` kalkar) · Önemli ·
   Üretilenler · Çöp kutusu · Kasa. (Fotoğraflar/galeri kendi kaynak satırını
   korur; orada yalnız Görsel/Video/GIF/Ekran görüntüsü alt türleri.)
4. **Son açılanlar yenilemesi (G1):** `FmListToolbar` (sırala: Son açılma ↓ ·
   Ad · Boyut · Tür), tarih grupları (Bugün · Dün · Bu hafta · Bu ay · Daha
   eski — `FmGroupHeader`), liste/ızgara, **çoklu seçim** + toplu eylemler
   (Paylaş · Taşı · Sil · **Geçmişten kaldır**), satırda "geçmişten kaldır",
   arama korunur. "Tümünü temizle" ⋮ menüsüne iner.
5. **Hafıza (K17, G3):** sıralama + yerleşim ekran başına kalıcı
   (`list.<ekran>.sort|layout`); tür/tarih süzgeci oturum boyunca.
6. **Boş sonuç:** "Bu süzgeçle dosya yok" + **"Süzgeci temizle"** düğmesi
   (`FmEmptyState`).
7. G13: İndirilenler'in sıralı/süzülmüş listesi alanda, yalnız veri/süzgeç
   değişince hesaplanır.

**Kabul ölçütleri:** madde 3'teki 10 ekranın her birinde, liste PDF içeriyorsa
"PDF" çipi tek dokunuşla yalnız PDF'leri gösteriyor (ekran başına widget testi)
· PDF + Word çoklu seçim testi · çip sayısı = dokununca kalan dosya testi ·
Son açılanlarda sıralama/gruplama/çoklu seçim/"geçmişten kaldır" testleri ·
360 dp'de ve 2,0× yazıda taşma yok · analyze 0, test yeşil · PNG'ler
`docs/design/faz13/` (Son açılanlar: süzgeçsiz, PDF seçili, seçim; Yeni
gelenler: PDF seçili; açık/koyu).

**Bölünürse:** 13a = 1-3 (model + bileşen + ekranlar) · 13b = 4-7.

**Risk:** düşük. Süzgeç mantığı saf Dart ve testli; ekranlar tek bileşene
geçtiği için davranış farkı testte görünür.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 13'ü uygula (bulut oturumu:
> Flutter 3.44.6'yı indir, HAFIZA 2026-07-25 §F tuzaklarına bak). §3.14 G1–G3
> ve G13'ü kapat: tek tür modelini ve `FmTypeChips` bileşenini kur, Faz 13
> madde 3'teki 10 ekrana uygula, Son açılanlar'ı yenile (K17 cevabı yoksa
> öneriyi uygula). Önce Son açılanlar ve Yeni gelenler için PNG taslağı üretip
> bana göster; onay beklerken model ve testlerle ilerle. HAFIZA'ya yaz, durum
> tablosunu güncelle, main'e birleştir.

---

### Faz 14 — Görsel boyutlandırma 2.0: kolay ve istenen oranda

**Amaç:** Bir fotoğrafı (ya da 50 fotoğrafı) **istenen ölçüye, orana ya da dosya
boyutuna** iki dokunuşta getirmek; sonucu başlamadan önce görmek; aynı ayarı bir
dahaki sefere hazır bulmak.

**Kanıt:** G4a–G4l, G19 (galeri giriş noktası). **Ön koşul:** Faz 10b (örnek
set + B11 sonucu). **Ortam:** ☁️ model, arayüz, Dart motoru, testler, PNG'ler;
Kotlin (`ci/ImageCodec.kt`) bulutta yazılır, **yerel kodlayıcı ve video kipleri
📱 cihaz turunda** doğrulanır (yürütme sırası 3). **Kararlar:** K14, K15.

**Yapılacaklar:**
1. **Model** (saf Dart, `models/media_resize.dart` genişler; eski JSON iş
   tarifleri açılmaya devam eder):
   - **Yüzde:** %1–400 (K14: %100 üstü uyarıyla), kaydırıcı + elle sayı + hızlı
     çipler (%25 · %50 · %75 · %150 · %200).
   - **Piksel:** genişlik × yükseklik + **🔗 oran kilidi (varsayılan açık)** —
     biri yazılınca öteki alanda **anında** hesaplanır. Kilit kapalıyken
     "kutuya nasıl sığsın": **Sığdır** (oran korunur, kutunun içinde) ·
     **Doldur ve kırp** (kutuyu doldurur, taşanı keser; çapa orta/üst/alt/sol/
     sağ) · **Kenar boşluğu ekle** (beyaz · siyah · bulanık arka plan · saydam
     (PNG/WebP)) · **Esnet** (oranı bilerek bozar — açık etiketle).
   - **Uzun kenar:** 720 · 1080 · 1280 · 1600 · 2048 · 3840 px + özel
     (fotoğrafın doğal dili; video kademeleri videoda kalır — G4f).
   - **En-boy oranı:** Orijinal · 1:1 · 4:5 · 5:4 · 3:2 · 2:3 · 4:3 · 3:4 ·
     16:9 · 9:16 · 21:9 · A4 (1:√2) · özel a:b — kırp ya da boşluk ekle.
   - **Dosya boyutu hedefi:** ≤ 100 KB · 200 KB · 500 KB · 1 MB · 2 MB · özel.
     Algoritma: kalite ikili araması (95 → 40), yetmezse %85'lik adımlarla
     ölçek; en çok 8 kodlama; ulaşılamazsa "en yakın 230 KB" raporu. PNG
     hedefinde JPEG/WebP'ye geçme önerisi.
   - **Çift sayı kuralı yalnız videoda** (G4k); fotoğraf tek sayı alabilir.
   - **Ölçüler görünen yönde** (EXIF Orientation uygulanmış) — B11 düzeltmesi.
2. **Arayüz** — levha baştan: üstte **canlı önizleme kartı** (küçük resim; oran/
   kırp/boşluk kipinde kesik çizgili çerçeve) + "Şu an 4000×3000 · 4,2 MB →
   Sonra 1600×1200 · ≈ 380 KB"; kip seçici (segmentli: Yüzde · Piksel · Uzun
   kenar · Oran · Dosya boyutu); altta biçim (Aynı · JPEG · PNG · **WebP**),
   kalite, **meta veri** ("Tarih ve kamera bilgisi korunur" · "Konumu kaldır"
   anahtarı). Toplu seçimde "kaynaktan küçük 3 dosya atlanacak" önceden
   söylenir; ad deseni `ad_1600x1200.jpg`.
3. **Ön ayarlar (G4g):** "Son kullanılan" kendiliğinden + kullanıcının
   kaydettikleri (ör. "Profil 640×640", "Başvuru ≤ 200 KB", "Paylaşım 4:5 ·
   1080"); 3-4 hazır öneri; levhanın en üstünde tek dokunuşluk çipler.
4. **Motor (K15):** `ci/ImageCodec.kt` (MethodChannel): `BitmapFactory`
   (`inSampleSize` ile bellek dostu çözme; HEIC Android 9+), ölçek/kırp/boşluk
   `Canvas`, `Bitmap.compress` (JPEG · PNG · WEBP lossy/lossless),
   `ExifInterface` ile EXIF kopyası (tarih, kamera; yön sıfırlanır çünkü
   pikseller döndürüldü; konum isteğe göre silinir). Saf Dart `image` yolu
   **yedek ve test referansı** olarak kalır (yerel kanal yoksa/başarısızsa).
5. **Video (Media3):** aynı kip dili (yüzde · piksel kilitli · uzun kenar ·
   oran); `Presentation` düzeni **`LAYOUT_SCALE_TO_FIT`** (boşluk) /
   **`LAYOUT_SCALE_TO_FIT_WITH_CROP`** (kırp); `LAYOUT_STRETCH_TO_FIT` yalnız
   "Esnet" seçilince (bugün her zaman — G4d). Hedef dosya boyutu videoda bit
   hızından (hedef × 8 / süre − ses).
6. **Giriş noktaları (G4i):** galeri alt çubuğuna **"Boyut"**; görsel
   düzenleyiciye **"Boyut" sekmesi** (kırp → boyut → kaydet tek akış);
   düzenleyicide kırpma oranları madde 1'deki listeye genişler, kırpma kutusunda
   canlı "1080 × 1350" etiketi, özel oran girişi, **basılı tut → özgünü gör**.
7. **Testler:** her kip için `targetSize` tablo testleri (yatay/dikey/kare,
   EXIF 1/3/6/8, tek sayı); kilit davranışı ve canlı karşı alan widget testi;
   dosya boyutu hedefi arama testi (Dart motoruyla); eski iş tarifi JSON'u göç
   testi; ön ayar kaydet/sil testi.

**Kabul ölçütleri:** "1600" yazınca yükseklik alanı anında doluyor · kilit kapalı
+ 1080×1080 → Sığdır/Doldur/Boşluk/Esnet dört farklı ve doğru çıktı (piksel
testi) · %150 uyarıyla çalışıyor (K14) · 3 MB örnek "≤ 200 KB" ile ≤ 200 KB
çıkıyor ya da en yakın değer raporlanıyor · dikey EXIF'li fotoğrafta genişlik
doğru kenara uygulanıyor · son ayar ve ön ayarlar hatırlanıyor · özgün dosyaya
dokunulmuyor (varsayılan kopya) · WebP/HEIC/video kip maddeleri
`docs/CIHAZ_TESTI.md`'de · PNG'ler `docs/design/faz14/`.

**Bölünürse:** 14a = 1-3, 6-7 (Dart; mevcut motorla — kullanıcının şikâyeti
burada kapanır) · 14b = 4-5 (yerel motor + video).

**Risk:** orta. Yerel kodlayıcı cihaz farklılıkları → Dart yedeği + çıktı
doğrulaması (dosya açılıyor mu, ölçü doğru mu) her işte; özgün dosya varsayılan
korunur.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 14'ü uygula (bulut; önce 14a).
> §3.14 G4a–G4l'yi kapat: boyutlandırma modelini beş kiple ve oran kilidiyle
> genişlet, levhayı canlı önizlemeli yeniden kur, ön ayarları ekle, galeri ve
> düzenleyiciye "Boyut" girişini koy. K14/K15 cevabı yoksa öneriyi uygula. Önce
> levhanın PNG taslağını göster. 14b'de `ci/ImageCodec.kt` ve Media3 düzen
> kiplerini yaz, `tool/check_kotlin.sh` koştur, cihaz maddelerini
> `docs/CIHAZ_TESTI.md`ye ekle. HAFIZA'ya yaz, main'e birleştir.

---

### Faz 15 — Görsel dil birliği: simge, renk, yazı, hareket

**Amaç:** Uygulamanın her ekranı aynı simge ailesini, aynı renk rollerini, aynı
yazı ölçeğini ve aynı hareket hızını kullansın; bir sonraki tasarım değişikliği
tek dosyadan yapılabilsin.

**Kanıt:** G5–G8 (sayımlar §3.14.3). **Ön koşul:** Faz 6. **Ortam:** ☁️
(yürütme sırası 4).

**Yapılacaklar:**
1. **Simge:** `AppIcons` bütün uygulamaya — 1.344 ham `Icons.*` → anlamsal ad
   (`AppIcons.share`, `AppIcons.trash`…); tek aile `_rounded`; üç boy (20/24/
   32). Bekçi test: `Icons.` yalnız `core/app_icons.dart`'ta (bilinçli
   istisnalar izin listesinde, faz boyunca küçülür).
2. **Renk:** anlamsal tokenlar `ThemeExtension<AppColors>` — `success`,
   `warning`, `danger`, `info`, dosya türü renkleri (`FmColors` buraya bağlanır),
   `scrim`, `mediaChrome` (medya üstü siyah perde), `selection`. 150
   `Color(0x…)` + 188 `Colors.*` → token; bilinçli sabitler (görsel düzenleyici
   kalem paleti, belge içi renkler) izin listesinde. Bekçi test.
3. **Yazı:** 114 sabit `fontSize` → `TextTheme` rolleri (gerekirse 2 ek rol:
   `labelTiny`, `dataMono`); `ui_font_scale_test` tüm rollere genişler.
4. **Hareket:** `core/motion.dart` — kısa 120 · orta 220 · uzun 320 ms +
   eğriler; 95 sabit süre → token; **`MediaQuery.disableAnimations` açıkken
   süreler 0** (bugün 2 yer).
5. **Kontrast testi:** 4 tema (+ K13 sistem rengi) × açık/koyu: metin ≥ 4,5:1,
   simge/kenar ≥ 3:1 (WCAG) birim testi; tutmayan çiftler düzeltilir.
6. **Bileşen tutarlılığı:** levhalar tek `AppSheet` (tutamaç, başlık, alt
   düğme satırı, `SafeArea`), iletişim pencereleri tek `AppDialog` (birincil
   eylem sağda/sonda, yıkıcı eylem `danger` rengi), boş/yükleniyor/hata tek
   aile (`FmEmptyState`, iskelet, `UserError`).
7. **Önce/sonra PNG'leri:** 12 ana ekran (pano, gezgin, kategori, Son
   açılanlar, arama, galeri, PDF, Word, Excel, ayarlar, eylem sayfası,
   boyutlandırma) açık/koyu → `docs/design/faz15/`.

**Kabul ölçütleri:** üç bekçi test (simge/renk/punto) yeşil, §3.14.3
sayımları izin listesi dışında 0 · kontrast testi yeşil · animasyonları kaldır
açıkken geçiş testi 0 ms · PNG onayı · analyze 0, test yeşil.

**Bölünürse:** 15a = 1, 4, 7 (simge + hareket) · 15b = 2, 3, 5, 6.

**Risk:** düşük-orta (geniş ama mekanik). Ekran ekran ayrı commit; her commitde
testler yeşil.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 15'i uygula (bulut). §3.14.3
> sayımlarını yeniden ölç, simge/renk/yazı/hareket tokenlarını kur, ekranları
> taşı, bekçi testleri ve kontrast testini ekle. Önce 12 ekranın "önce" PNG'lerini
> çıkar, taşımadan sonra "sonra"larını göster. HAFIZA'ya yaz, main'e birleştir.

---

### Faz 16 — Erişilebilirlik, Arapça (RTL) ve büyük yazı

**Amaç:** Görme/motor güçlüğü olan kullanıcı ve Arapça arayüz kullanıcısı
uygulamayı Türkçe kullanıcı kadar rahat kullansın; bu **testle** güvence altına
alınsın.

**Kanıt:** G9, G10. **Ön koşul:** Faz 15. **Ortam:** ☁️ (+📱 TalkBack turu,
sistem dil seçimi) (yürütme sırası 5).

**Yapılacaklar:**
1. **Kılavuz testleri:** `meetsGuideline(androidTapTargetGuideline)`,
   `labeledTapTargetGuideline`, `textContrastGuideline` — 15 ana ekranda
   (bugün 0).
2. **RTL:** G10 listesi → `EdgeInsetsDirectional`, `AlignmentDirectional`,
   `TextAlign.start/end`, `PositionedDirectional`; yön oklarına
   `matchTextDirection`/yönlü `AppIcons` (Faz 15). Bekçi test: ekran/bileşen
   kodunda `EdgeInsets.only(left:|right:)` ve `TextAlign.left|right` yok
   (bilinçli istisna: belge içeriği çizimi). Arapça PNG'ler (5 ekran).
3. **Büyük yazı:** 1,0×–**2,0×** (Android 14+ doğrusal olmayan ölçek) taşma
   testleri 360 dp'de; satırlar 2,0×'te iki satıra iner, kesilmez.
4. **TalkBack anlamları:** simge düğme etiketleri; küçük resim → "PDF, Kira
   sözleşmesi, 120 KB, dün"; seçim durumu `selected`; iş ilerlemesi
   `liveRegion`; sürükleyerek seçimin erişilebilir karşılığı (uzun bas →
   "Seç" eylemi).
5. **Animasyonları kaldır:** Faz 15 tokenlarıyla her yerde.
6. **Uygulama başına dil (Android 13+):** `res/xml/locales_config.xml` (tr, en,
   ar) + manifest `android:localeConfig` (`ci/prepare_android.sh`); Dart
   tarafı sistem dilini izliyor — sistem ayarlarından seçilen dil uygulamaya
   yansısın.

**Kabul ölçütleri:** kılavuz testleri 15 ekranda yeşil · RTL bekçi testi
yeşil · 2,0× yazıda taşma 0 · Arapça PNG onayı · TalkBack ve sistem dil
seçimi maddeleri `docs/CIHAZ_TESTI.md`'de.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 16'yı uygula (bulut). §3.14 G9–G10'u
> kapat: kılavuz testleri, RTL dönüşümü + bekçi, 2,0× yazı testleri, TalkBack
> anlamları, uygulama başına dil. Arapça PNG'leri göster. Cihaz maddelerini
> ekle, HAFIZA'ya yaz, main'e birleştir.

---

### Faz 17 — Liste ve gezinme cilası

**Amaç:** Dosya gösteren her ekran aynı liste gibi davransın; sık yapılan şeyler
(az önce açılan dosya, sık kullanılan eylem, klasöre özel sıralama) bir dokunuş
yakın olsun.

**Kanıt:** G3, G11, G12, G14, G15, G16. **Ön koşul:** Faz 13, 15. **Ortam:** ☁️
(+📱 kaydırma ölçümü) (yürütme sırası 6). **Karar:** K16.

**Yapılacaklar:**
1. **Ortak liste (G11):** Çöp kutusu, Arşiv içi, Kasa, Gizli dosyalar,
   Yinelenenler, Benzerler, Sohbet temizliği, Önemli, Üretilenler →
   `FmFileListView` + `FmListToolbar` + Faz 13 süzgeci (ekranın doğasına göre:
   Yinelenenlerde grup başlıkları korunur). İşlemler (dosya değil iş listesi)
   yalnız ortak boş durum ve başlık dili.
2. **Klasör başına hafıza (G3):** sıralama menüsünde "Yalnız bu klasör"
   anahtarı; varsayılan global ayar sürer.
3. **İki parmakla sütun (G12):** Fotoğraflar'daki mantık ortak bileşene →
   gezgin ve kategori ızgaraları.
4. **Yukarı kaydırma (G14, KALANLAR):** satır/başlık yüksekliği
   `itemExtentBuilder` ile sabit; ölçüm 📱 (Ek D) — p99 ≤ 16 ms hedefi.
5. **Panoda "Son açılanlar" şeridi (G15, K16):** yatay, küçük resimli 10 öğe +
   "Tümü →" (Faz 13'ün ekranına); `DashboardLayout`'a `recent` bölümü — K16 (b)
   ise varsayılan gizli (birleştirme kuralına testli istisna).
6. **Eylem sayfası (G16):** üstte 5'li **hızlı sıra** (Paylaş · Taşı · Kopyala
   · Yeniden adlandır · Sil); altında gruplar; dosya türüne göre ilk grup
   (görselde Düzenle/Boyut, PDF'te Düzenle/Araçlar, arşivde Çıkar).
7. **"Geri al" tutarlılığı:** silme, taşıma, yeniden adlandırma, geçmişten
   kaldırma, kasaya taşıma — hepsinde aynı snackbar (süre, metin, eylem);
   eksik olanlar listelenip tamamlanır.
8. **Arama:** Faz 13 tür çipleri + "bu klasörde / her yerde" kapsam çipi; son
   aramalar korunur.

**Kabul ölçütleri:** madde 1'deki ekranlar ortak bileşeni kullanıyor (bekçi:
`lib/screens/fm` içinde dosya satırı için `ListTile` yok) · klasör başına
sıralama testi · iki parmak testi · pano şeridi testi (K16'ya göre görünürlük) ·
eylem sayfası hızlı sıra testi · yukarı kaydırma ölçümü cihaz listesinde ·
PNG'ler `docs/design/faz17/`.

**Bölünürse:** 17a = 1, 4, 7 · 17b = 2, 3, 5, 6, 8.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 17'yi uygula (bulut). §3.14 G11–G16'yı
> kapat; K16 cevabı yoksa öneriyi uygula. Pano şeridi ve eylem sayfası için önce
> PNG göster. Kaydırma ölçümünü cihaz listesine ekle, HAFIZA'ya yaz, main'e
> birleştir.

---

### Faz 18 — Görüntüleyici ve medya deneyimi

**Amaç:** Okurken ve izlerken arayüz geri çekilsin, alışılmış jestler çalışsın;
tablet ve yatay ekranda alan boşa gitmesin.

**Kanıt:** G17–G20. **Ön koşul:** Faz 15. **Ortam:** ☁️ (+📱 jest hissi,
parlaklık, geniş ekran) (yürütme sırası 7).

**Yapılacaklar:**
1. **Okuma kipi (G20):** PDF, metin, Word, slayt görüntüleyicisinde aşağı
   kaydırınca üst/alt çubuk gizlenir, yukarı kaydırma ya da dokunuşla geri gelir;
   Aa levhasında "Tam ekran" (sistem çubukları gizli) anahtarı; alt çubuk sırası
   biçimler arasında aynı (Ara · Düzenle · Paylaş · Aa · ⋮).
2. **Video (G18):** sol yarıda parlaklık kaydırması (pencere parlaklığı, çıkışta
   geri), uzun basışta 2× hız (bırakınca eski hız), **kontrol kilidi**, yatay
   kaydırmayla sarma + zaman balonu, yön kilidi düğmesi; çift dokunuş
   (±10 sn) ve ses kaydırması korunur.
3. **Galeri (G19):** slayt gösterisi (3/5/10 sn), "Önemli"ye ekle (yıldız),
   **"Farklı kullan"** (duvar kâğıdı/kişi — `ACTION_ATTACH_DATA`), "Boyut"
   (Faz 14), yukarı kaydırınca bilgi paneli (EXIF, konum varsa harita
   bağlantısı).
4. **Geniş ekran (G17):** ≥ 600 dp yatayda pano iki sütun; ≥ 840 dp
   görüntüleyicide yan panel (içindekiler / sayfa küçük resimleri / AI sohbet);
   düzenleyici şeritleri geniş ekranda tek satır; ayarlar liste-ayrıntı.
   Android 16 büyük ekran kuralı (yön kilidi yok sayılır) için her ekranın
   yatayda testi (1280×800).
5. **Ses:** mini çubuk ve tam ekran Faz 15 tokenlarıyla; kilit ekranı kapak
   görseli (📱).

**Kabul ölçütleri:** okuma kipi 4 biçimde aynı davranış (widget testi) · video
jest testleri (sahte motorla — `media_player_layout_test` deseni) · galeri slayt
gösterisi testi · 1280×800 ve 600 dp yatayda taşma yok, iki bölme PNG'leri ·
jest hissi/parlaklık/kapak cihaz listesinde.

**Bölünürse:** 18a = 1, 4 · 18b = 2, 3, 5.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 18'i uygula (bulut). §3.14 G17–G20'yi
> kapat: okuma kipi, video jestleri, galeri eylemleri, geniş ekran düzenleri.
> Geniş ekran PNG'lerini göster, cihaz maddelerini ekle, HAFIZA'ya yaz, main'e
> birleştir.

---

### Faz 19 — Sistem entegrasyonu ve ilk izlenim

**Amaç:** Uygulama Android'in bir parçası gibi görünsün: açılırken, başlatıcıda,
ana ekranda ve bildirimde aynı kimlik; dokunsal geri bildirim ölçülü ve tutarlı.

**Kanıt:** G21. **Ön koşul:** Faz 15. **Ortam:** ☁️ kod/XML/Kotlin + 📱 görünüş
(yürütme sırası 10). **Karar:** K13.

**Yapılacaklar:**
1. **Açılış ekranı (Android 12 SplashScreen API):** marka simgesi + temaya uygun
   zemin; koyu modda beyaz parlama yok (`values-night`); Android ≤ 11'de aynı
   renk (`ci/prepare_android.sh` + `ci/res/`).
2. **Başlatıcı kısayolları:** simgeye uzun basınca *Ara · Tara · İndirilenler ·
   Son açılanlar* (statik `shortcuts.xml`) + son açılan 2 dosya (dinamik).
3. **Pencere öğeleri** (`StorageWidget`, `RecentWidget`): Android 12 köşe
   yarıçapı, `previewLayout`, boyutlandırılabilir, koyu tema, K13 (a) ise
   sistem renkleri.
4. **Sistem rengi (K13):** (a) ise 5. görünüm "Sistem rengi" (`dynamic_color`);
   Android 12 altında listelenmez; Faz 15 kontrast testine girer.
5. **Dokunsal geri bildirim:** 13 dağınık `HapticFeedback` → `AppHaptics`
   (seçim başlangıcı, sürükleyerek seçim adımı, yıkıcı onay, iş bitti);
   Ayarlar'da kapatılabilir.
6. **Bildirimler:** iş bildirimlerinde ilerleme stili tutarlı; bitince "Aç /
   Klasörde göster" eylemleri; çoklu işte gruplama.
7. *(İsteğe bağlı)* Hızlı Ayarlar kutucuğu: "Bilgisayara aktar" (FTP) aç/kapa.

**Kabul ölçütleri:** `check_kotlin.sh` yeşil (kotlinc varsa) · CI APK'sında
`shortcuts.xml`, `locales_config`, splash kaynakları var (APK içerik denetimine
eklenir) · `AppHaptics` bekçi testi (ham `HapticFeedback` yok) · görünüş
maddeleri (splash açık/koyu, kısayollar, pencere öğeleri, sistem rengi)
`docs/CIHAZ_TESTI.md`'de.

> **Açılış istemi:** `docs/FAZ_PLANI.md` Faz 19'u uygula (bulut). §3.14 G21'i
> kapat: açılış ekranı, başlatıcı kısayolları, pencere öğeleri, K13 kararına göre
> sistem rengi, `AppHaptics`, bildirim eylemleri. APK içerik denetimine yeni
> kaynakları ekle. Cihaz maddelerini yaz, HAFIZA'ya yaz, main'e birleştir.

---

## 7. Ekler

### Ek A — Doğrudan bağımlılıklar (özet)

| Paket | İş | Lisans | Not / öneri |
|---|---|---|---|
| `pdfrx` 1.3.x | PDF görüntüleme (PDFium) | MIT (+ PDFium BSD) | Flutter yükseltmesiyle 2.x (Faz 7) |
| `syncfusion_flutter_pdf/_core` 31.1.19 | PDF yazma işleri | **Syncfusion ticari/Community** | K1 |
| `pdf`, `printing` | PDF üretimi, yazdırma | Apache-2.0 | kalır |
| `excel` 4.0.6 | xlsx yazma | MIT | **çıkar** (D6) — `archive ^3` kilidi |
| `archive` ^3, `xml`, `koni_archive` | zip/xml/RAR/7z | MIT | kalır |
| `webview_flutter(_android)` | Word görünümü | BSD-3 | kalır |
| `google_mlkit_text_recognition` | OCR (Play Hizmetleri) | MIT (ML Kit şartları) | kalır |
| `google_mlkit_translation` | çeviri (16,4 MB) | MIT | K3 |
| `google_mlkit_face_detection` | Anılar → İnsanlar | MIT | K8 (kaldırma önerisi) |
| `ffmpeg_kit_flutter_new_min` | video küçültme (15,5 MB) | **LGPL v3** | K2 |
| `video_compress` | video küçültme yedeği | MIT | çıkar (D5) |
| `video_player(_android)`, `audioplayers(_android)` | oynatıcılar | BSD-3 / MIT | tek motora (Faz 10) |
| `fc_native_video_thumbnail` | video küçük resmi | BSD-3 | kalır |
| `flutter_local_notifications` 17.2.4 | iş bildirimleri | BSD-3 | Flutter yükseltmesinde güncelle |
| `permission_handler` 11.3.1 | izinler | MIT | güncelle |
| `installed_apps`, `app_usage` | uygulamalar ekranı | Apache-2.0 / MIT | `app_usage` çıkar (K8) |
| `google_sign_in` | Drive | BSD-3 | K5 (c) ise çıkar |
| `dartssh2`, `ftpconnect`, `webdav_client`, `smb_connect`, `multicast_dns` | NAS | MIT/BSD/Apache | kalır |
| `background_downloader` | indirmeler | MIT | kalır |
| `cunning_document_scanner` | belge tarayıcı (ML Kit) | MIT | kalır |
| `flutter_tts` | sesli okuma | MIT | kalır |
| `receive_sharing_intent`, `open_filex`, `share_plus`, `url_launcher`, `file_picker` | sistem entegrasyonu | Apache/BSD/MIT | kalır |
| `image`, `crypto`, `pointycastle`, `mime`, `barcode`, `http` | yardımcılar | MIT/BSD/Apache | kalır |
| `wakelock_plus`, `flutter_displaymode` | ekran | BSD-3 / MIT | kalır |
| `cupertino_icons` | — | MIT | **kullanılmıyor → çıkar** |

### Ek B — 800 satırı aşan dosyalar ve bölme önerisi

| Satır | Dosya | Öneri (Faz 3) |
|---|---|---|
| 8.317 | `core/l10n/app_strings.dart` | alan başına `part` dosyaları (yapı aynı) |
| 4.065 | `screens/viewer_screen.dart` | `viewer/` → pdf / metin / görsel / menüler / kabuk |
| 4.025 | `screens/editors/spreadsheet_editor_screen.dart` | ızgara / formül çubuğu / sekmeler / araç şeridi / pencereler / klavye |
| 3.285 | `screens/fm/dashboard_screen.dart` | `dashboard/` → hero, birimler, kategori ızgarası, dock, kartlar |
| 2.580 | `services/formula_engine.dart` | ayrıştırıcı + işlev kategorileri |
| 1.803 | `screens/fm/entry_actions.dart` | tanımlar / levha / yürütücüler |
| 1.688 | `services/pptx_render.dart` | şekil / metin / grafik / tema |
| 1.672 | `screens/fm/photos_screen.dart` | zaman ekseni / ızgara / seçim / filtre |
| 1.627 | `screens/scan_result_screen.dart` | stüdyo / araçlar / kayıt motoru |
| 1.486 | `services/xlsx_editor.dart` | model / yapısal işlemler / biçim |
| 1.447 | `screens/fm/ai_hub_screen.dart` | sohbet / kaynak kartları / analiz |
| 1.437 | `services/xlsx_reader.dart` | paylaşılan dizeler / stiller / sayfa |
| 1.335 | `services/xlsx_save_patch.dart` | (Faz 7'de `excel` çıkınca yeniden düzenlenir) |
| 1.234 | `screens/editors/slides_editor_screen.dart` | liste / düzenleme / dışa aktarma |
| 1.215 | `screens/fm/analysis_screen.dart` | (Faz 2'de Depolama merkezine) |
| 1.204 | `screens/fm/drive_screen.dart` | (K5 (c) ise silinir) |
| 1.175 | `screens/pdf_editor_screen.dart` | (Faz 8 tek çatı) |
| 1.160 | `screens/pdf_tools_screen.dart` | (Faz 8 tek çatı) |
| 1.155 | `screens/editors/word_editor_screen.dart` | köprü / araç şeridi / kaydetme |
| 1.076 | `services/fm/job_queue.dart` | kuyruk / izlenen iş / kalıcılık |
| 1.058 | `widgets/pdf_select_layer.dart` | seçim / tutamaçlar / çizim |

(+ `pdf_ink_screen` 1.057, `excel_format` 1.035, `browser_screen` 1.023 —
Faz 6'da zaten yeniden yazılıyor.)

### Ek C — Ölü semboller

**Hiç kullanılmayan (tanım dışında 0 referans; testlerde de yok):**
`hideToast` (`core/snack.dart:204`), `downloadsExists` (`screens/fm/downloads_screen.dart`),
`ImportantScreen.existingPath`, `AiPool.activeModel`, `AiPool.cooldownUntil`,
`DocTranslate.charCount`, `AiAnalyzer.remainingBudget`, `AiExtract.isReadable`,
`AiIndex.analyzedCount`, `AiIndex.clearSuggestion`, `FileDigest.chunkBytes`,
`FolderSizeCache.isPending`, `FsEvents.flushUnreadableNow`,
`StoragePermission.hasMediaAccess`, `PdfPageEdit.pointSizeAtInBackground`,
`writeTempPng` (`services/perspective.dart`), `OfficeIcons.clearFormat`,
`OfficeIcons.gridlines` (`widgets/office_ribbon.dart`), `ExifReader.readGps`;
`core/theme.dart` → `Paper` sınıfındaki 12 renk sabiti (`accentDark`, `accentWellDark`, `bandDark`, `cardDark`,
`dangerDark`, `edgeDark`, `inkFaintDark`, `inkSoftDark`, `okDark`, `pageEdge`,
`ruleDark`, `wellDark`).

**Yalnız testlerde kullanılan (`@visibleForTesting` adayı):**
`ScreenAwake.holders/isHeld`, `HomeScreen.debugResetStartFolder`,
`DocumentScanner.buildPdf`, `ActivityLog.resetCache`, `AiIndex.docTypeCounts`,
`ApkIcon.readIconBytes`, `FfmpegVideo.remainingText`, `FileDigest.md5Of`,
`FileTags.deleteTag/renameTag/setTags`, `FolderSizeCache.pendingCount`,
`ImageRotate.turnsForOrientation`, `MediaDuration.seed`,
`PasteConflict.collisionsIn`, `PlaybackPositions.savePending`,
`SafeWrite.fileLooksValid`, `LegacyText.extractFromStream`, `scanTextOps`,
`PdfAnnotator.addHighlight`, `Perspective.rotateToPng/warpToPng`,
`PptxRender.debugParseGradient`, `XlsLegacy.parseWorkbookStream`.

> Yöntem: her genel sembolün `lib/` ve `test/` içindeki kelime sınırlı
> geçişleri sayıldı (yorumlar hariç). Uzantı (`extension`) üyeleri adla
> çağrılmadığı için listeye alınmadı. Silmeden önce her biri bir kez daha
> `grep -rnw` ile doğrulanmalı.

### Ek D — Düşük donanım test protokolü

- **Referans cihaz:** Android Go ya da 2-3 GB RAM, 4-8 çekirdek Cortex-A53/A55,
  720p ekran (ör. Samsung Galaxy A03/A04e, Xiaomi Redmi A-serisi). İkinci cihaz:
  güncel orta sınıf.
- **Derleme:** `flutter run --profile` (release'e en yakın, ölçüm açık).
- **Veri:** test klasörü üreticisi (`tool/make_test_tree.py` — Faz 4'te yazılır):
  5.000 dosyalı klasör, 2.000 fotoğraf, 100 sayfalık PDF, 10 bin satırlık XLSX,
  200 slaytlık PPTX.
- **Senaryolar ve metrikler:** soğuk açılış (ilk kare, etkileşim), klasörde
  kaydırma + seçim (kare süreleri), galeri kaydırma (RSS), PDF açılışı (ilk sayfa
  süresi, açılıştan sonraki 10 sn CPU), boşta pano (60 sn'de kare/zamanlayıcı
  sayısı), 1 saat müzik çalma (pil %), ekran kapalı 1 saat (uyanma sayısı —
  `adb shell dumpsys batterystats`).
- **Kayıt:** her ölçüm öncesi/sonrası `docs/perf/<tarih>.md`'ye.

### Ek E — 2026-10-22 görsel/kullanım taramasının yöntemi ve kaynakları

**Sayım komutları** (depo kökünde; §3.14.3–3.14.4 değerleri `main` @ `0772995`):

```bash
grep -rn "Icons\.[a-z_]*" lib --include=*.dart | grep -v lib/core/app_icons.dart | wc -l   # 1344
grep -rn "AppIcons\.[a-zA-Z]*" lib | wc -l                                                 # 93
grep -rno "Icons\.[a-z_]*_outlined" lib | grep -v app_icons | wc -l                        # 373
grep -rno "Icons\.[a-z_]*_rounded"  lib | grep -v app_icons | wc -l                        # 189
grep -rn "Color(0x" lib --include=*.dart \
  | grep -v "lib/core/theme.dart\|lib/core/skin.dart\|lib/core/fm_colors\|palette" | wc -l # 150
grep -rn "Colors\.\(black\|white\|grey\|red\|blue\|green\|orange\|amber\)" lib | wc -l     # 188
grep -rn "fontSize: [0-9]" lib | wc -l                                                      # 114
grep -rn "Duration(milliseconds" lib | wc -l                                                # 95
grep -rn "disableAnimations\|reduceMotion\|accessibleNavigation" lib | wc -l               # 2
grep -rln "meetsGuideline" test | wc -l                                                     # 0
grep -rnE "EdgeInsets\.only\([^)]*(left|right):" lib | wc -l                                # 27
grep -rn "EdgeInsetsDirectional" lib | wc -l                                                # 22
grep -rn "Alignment\.center\(Left\|Right\)\|Alignment\.\(top\|bottom\)\(Left\|Right\)" lib | wc -l  # 36
grep -rn "TextAlign\.\(left\|right\)" lib | wc -l                                           # 21
grep -rn "Icons.arrow_back\b\|Icons.arrow_forward\b\|Icons.chevron_right\|Icons.chevron_left" lib | wc -l  # 43
grep -rln "FmFileListView" lib/screens                                                      # 5 ekran
```

Asimetrik `EdgeInsets.fromLTRB` (24) sol ve sağ değeri farklı olanlar sayılarak
bulundu. Sayılar faz başında yeniden ölçülür; kabul ölçütleri bu tabloya göre.

**Web kaynakları (2026-10-22'de okundu):**

- Android 16 davranış değişiklikleri — hedef API 36'da kenardan kenara çıkış
  özniteliği devre dışı; tahminli geri animasyonları varsayılan açık,
  `onBackPressed` çağrılmıyor, `enableOnBackInvokedCallback="false"` geçici
  kaçış: <https://developer.android.com/about/versions/16/behavior-changes-16>
- Android 16'da yön ve yeniden boyut değişiklikleri — sw ≥ 600 dp'de
  `screenOrientation`/`resizeableActivity`/en-boy kısıtları yok sayılır; Play
  hedef API 36'yı Ağustos 2026'da, 37'yi Ağustos 2027'de ister, API 37'de çıkış
  yolu yok: <https://android-developers.googleblog.com/2025/01/orientation-and-resizability-changes-in-android-16.html>,
  <https://developer.android.com/develop/adaptive-apps/guides/app-orientation-aspect-ratio-resizability>
- Material You / dinamik renk — `dynamic_color` paketi (`DynamicColorBuilder`,
  Android 12+): <https://pub.dev/documentation/dynamic_color/latest/>
- Material 3 Expressive — Flutter çekirdeğinde resmî destek bulunamadı; yalnız
  üçüncü taraf paketler (ör. `material_3_expressive`, Flutter ≥ 3.44 ister).
  **Öneri: şimdilik eklenmez**, yalnız hareket/şekil fikirleri Faz 15
  tokenlarına alınır: <https://pub.dev/documentation/material_3_expressive/1.0.8/>
- Google Drive tür süzgeci (PDF, Belgeler'den ayrı bir tür; çipler birlikte
  kullanılır, tek tek ya da toptan temizlenir):
  <https://support.google.com/drive/answer/2375114?hl=en>
- Görsel boyutlandırıcılarda beklenen kipler (yüzde, piksel, en-boy oranı,
  toplu iş, kırpma, PNG/JPEG çıktı): <https://androidauthority.com/best-photo-resizer-apps-android-1076507>
