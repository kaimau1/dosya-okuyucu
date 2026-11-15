# OTOMASYON — gözetimsiz iş zinciri

**Kullanıcı izni (2026-11-14):** işleri otomasyonla başlat, istediğin modelde alt ajan aç,
limite göre çalış; test telefonu USB'de (ekranı yalnız gerekince aç); işi bitir, main'e gönder;
token israf etme ama bitmiş iş ver. Gözetimsiz çalış, soru sorma.

"not" projesindeki zincirin aynısı (2026-11-14 taşındı). Bu dosya yalnız YÜRÜTME düzeni + Kuyruk
düzenidir; **Kuyruk, SIRA ve açık işler `PLAN.md`'de** (2026-11-15 birleştirmesi; eski planlar `docs/arsiv/planlar/`).
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
- Eski bulut tetik zinciri (`docs/arsiv/planlar/ZAMANLANMIS_GOREV_ISTEMI.md`, Faz 34–42 `fire_trigger`) tarihseldir
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

## Kuyruk → `PLAN.md` §1

Kuyruk tablosu ve SIRA 2026-11-15'te `PLAN.md` §1'e taşındı (biten satırlar silindi). 👤 maddeler
yapılmaz → `PLAN.md` §3 (ne · nasıl · doğruysa · yanlışsa).
