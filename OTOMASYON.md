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
| P01 | Ölçüm altyapısı: gözetimsiz A/B betiği (iki derleme/etiket, A,B×2+ sıra, ortanca, en kötü A kıyası, `KARAR:` satırı, ısı beklemesi, MIUI kurulum onayı) + H0.2 büyük PDF senaryosu + H0.3 PDF açılış zaman damgaları | opus | `ab-olcum` "Araç farkı"; FERRARI H0.2–H0.3; `tool/perf_senaryo.sh`, `tool/r8_ab.sh` (`read` bekler) | A/B | hayır | bekliyor |
| P02 | Ferrari H0.1/H0.4 ölçüm tabanı: §2 "10 işlem" bizde (Mi Note 10 Lite), tablo `docs/perf/2026-11-H0.md`; Samsung sütunu 👤 | sonnet | FERRARI H0.1, H0.4, §2 | A/B | hayır | bekliyor — P01'den sonra |
| P03 | Ferrari H6 hareket ve dokunuş (titreşim kapsamı, basma hâli, açılış geçişi + H1.5, liste değişimi, levha birliği, öngörülü geri) | opus | FERRARI H6.1–H6.6, H1.5 | A/B | evet | bekliyor |
| P04 | Ferrari H10 + H11: boş/yükleniyor/hata durumları + görüntüleyici kabuğu tutarlılığı (üst/alt çubuk, Office açılışı, görsel, video denetimleri) | opus | FERRARI H10.1–H10.3, H11.1–H11.5 | A/B | evet | bekliyor — P03 ile paralel değil (levha/çubuk dosyaları ortak) |
| P05 | Ferrari H7 sadeleştirme: bildirim envanteri, ipuçları bir kez, geri alınabilene onay yok, ayarlar düzeni; H7.2 menü kısaltma 👤 → yalnız envanter + öneri `KONTROL_LISTEM.md` | opus | FERRARI H7.1–H7.5 | — | evet | bekliyor |
| P06 | Ferrari H2 PDF kaydırma akıcılığı (önbellek tavanı, bulanık yer tutucu, komşu sayfa, hızlı tutamaç, netleşme, USB okuma hızı) — ölç→değiştir→ölç | opus (plan evresi fable) | FERRARI H2.1–H2.6 | A/B | evet | bekliyor — P01+P02 tabanı gerekir |
| P07 | Ferrari artıkları: H1.4 son sayfa görüntüsü + H8.5 döndür / kareyi fotoğraf kaydet | opus | FERRARI H1.4, H8.5; KALANLAR Faz H | evet | evet | bekliyor |
| P08 | PDF Pro oturum belleği bütçe dışı (+56/+65 MB, bütçe +40): `commitLive` → `needsReplay` hep açık, ikinci tam PDFium belgesi (HAFIZA 2026-11-13 bulgusu) — kök neden + ölçüm | opus | KALANLAR Faz E "Oturum belleği bütçe dışı"; HAFIZA 2026-11-13 | A/B | evet | bekliyor |
| P09 | Telefonla cihaz turu: `CIHAZ_TESTI.md` "Ferrari H1/H3/H4/H5/H8" + "Video düzenle" maddeleri (uiautomator, nightly); Drive/hesap maddeleri "denenmedi" | sonnet | KALANLAR Faz H; `docs/CIHAZ_TESTI.md` | evet | hayır | bekliyor — telefon boşken |
| P10 | Ferrari H9 tablet (kalıcı gezinme sütunu ≥ 840 dp, dönüşte konum, kalem/parmak, içerik genişliği, sürükle-bırak) | opus | FERRARI H9.1–H9.5 | tablet | evet | bekliyor — tablet doğrulaması kullanıcıda |

**SIRA (2026-11-14):** P01 → P03 ∥ P05 → P04 → P09 (telefon boşken) → P02 → P06 → P07 → P08 → P10.
H12 (son kapı, 📱👤) Kuyruk'a hepsi bitince ve kullanıcıyla girer. Güvenlik artıkları (KALANLAR
Faz F) çoğu 👤 — Kuyruk dışı.
