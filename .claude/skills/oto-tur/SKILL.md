---
name: oto-tur
description: Gözetimsiz zincirin yürütücü turu — kilit, main sağlığı, Kuyruk'tan paket seçip alt ajana verme, doğrulama, cihaz kapısı, birleştirme/[apk], temizlik, limit freni, bitiriş. Zamanlanmış görev (`okuyucu-devam`) ya da "otomasyonu sür" denince uygula.
---

# Yürütücü turu

"not" projesindeki `oto-tur` skill'inin dosya okuyucuya uyarlanmış hâli (2026-11-14). Yöntem aynı;
yol, komut, dal ve ölçüm kuralları bu projenin gerçeğine göre. **Kuyruk VERİSİ ve SIRA
`OTOMASYON.md`'de** (paket ayrıntısı Kuyruk satırının "Kaynak" sütunundaki plan maddesinde:
`docs/FERRARI_PLANI.md`, `KALANLAR.md`, `docs/CIHAZ_TESTI.md`…); bu skill yalnız yöntemdir.

**Kullanıcı izni (2026-11-14, "not"taki 2026-11-09 izninin aynısı):** işleri otomasyonla başlat,
istediğin modelde alt ajan aç, limite göre çalış; test telefonu USB'de (ekranı yalnız gerekince
aç); işi bitir, main'e gönder; token israf etme ama bitmiş iş ver. Gözetimsiz çalış, soru sorma.
Plan dosyalarındaki KARAR maddeleri verilmiştir: SORMADAN uygula; yeni karar → en güvenli seçenek
+ "sabah bakılacak". 👤 işaretli (kullanıcı kararı/hesabı gereken) madde yapılmaz:
`KONTROL_LISTEM.md`'ye madde yazılır, paket kalanla sürer.

**Yürütücü ince kalır:** kod, CI izleme, kırmızı CI düzeltme, DEVIR, plan `[x]`, Kuyruk satırı,
sürüm notu satırları ALT AJANIN işidir; yürütücü raporu, `git log`/diff özetini ve `gh run`
sonucunu kontrol eder, birleştirir. Paketleri büyük tut (her alt ajan sıfırdan başlar). Aynı anda
TEK yürütücü.

## Dal kuralı (CLAUDE.md §4 "İSTİSNA — Gözetimsiz zincir")

Proje TEK DAL `main`; zincir paketleri istisnadır: dal **`faz-oto-<no>-<kısa-ad>`** (ör.
`faz-oto-P03-hareket`). Neden bu ad: CI'ın push tetikleyicisi yalnız `main`, `claude/**`, `ccr-*`,
`faz-*` dallarında çalışır — `oto/*` adlı dal CI koşturmaz. Birleştirme **yerelde
`git merge --no-ff`** ile (başlık `Birleştir: …`); **`gh pr merge` KULLANMA** — CI
`Merge pull request #N from …/faz-` başlığını görünce her birleştirmede APK derler, APK sütununu
çiğner.

## Token tasarrufu

Her araç çağrısı bütün bağlamı yeniden gönderir — az ve toplu çağrı. `OTOMASYON.md`'yi BİR kez
oku (tek parça); aynı dosyayı ikinci kez dökme. Paket ayrıntısı için plan dosyasının yalnız ilgili
bölümü (`grep -n` ile yerini bul, `sed -n` ile oku). Büyük çıktıyı `| tail -n 40` / `cut -c1-300`
ile kes. `HAFIZA.md` (170 KB+) ve plan dosyalarını baştan okuma: HAFIZA'nın son ~30 satırı,
gerisi `grep`. Graphify'ı açma. Alt ajan beklerken yoklama yok, bildirimi bekle.

## Adımlar

0. **Kilit** `.git/oto.lock` (içinde ISO zaman). Son değişimi 60 dakikadan yeniyse: hiçbir şey
   yapmadan "başka yürütücü çalışıyor" de ve BİTİR. Değilse şimdi yaz. Her adımın başında ve her
   alt ajan bildiriminde tek `date -u +%FT%TZ > .git/oto.lock` ile tazele; arka plan döngüsüyle
   ASLA (oturum ölünce döngü yaşar, kilit sonsuza dek taze kalır). Eşik tek: 60 dk. Tur nasıl
   biterse bitsin kilidi sil.
1. **Depo.** `git status` temiz olmalı (değilse `git stash push -u -m oto-<tarih>` + Kuyruk
   notuna yaz), `git checkout main && git pull --ff-only`. Uzaktaki `faz-oto-*` dallarına bak;
   satırı olmayan dalı DEVIR'iyle satıra bağla. `graphify-out/.graphify_labels.pending.json` gibi
   izlenmeyen araç dosyalarına dokunma.
2. **main sağlığı.** `gh run list -b main -L 3` (yoksa GitHub MCP `actions_list`). Son BİTEN
   koşu kırmızıysa bu turun işi onu düzeltmektir (yalnız kırmızı parçanın kayıt kuyruğu:
   `gh run view <id> --log-failed | tail -n 60`). `[apk]` koşusu SÜRÜYORSA bitene dek main'e push
   YOK (art arda push önceki koşuyu iptal eder) — bu sırada dalda çalışılır. main iki kez üst üste
   kırmızı → dur.
3. **Paketi seç** (Kuyruk + SIRA satırı `OTOMASYON.md`'de). `bulutta:` ile başlayan satır başka
   oturumundur: ATLA, dalına dokunma. İlk `sürüyor` (yarım: uzakta `faz-oto-<no>-*` varsa oradan,
   DEVIR.md'den) yoksa SIRA'daki ilk `bekliyor`. `cihaz bekliyor` satırını yalnız telefon bağlıysa
   al (`adb devices`). Satırı `sürüyor` yap (yalnız yerelde; ayrıca push yok).
4. **Yaptır.** `Agent`, `isolation: "worktree"`, `model` Kuyruk satırından (`fable|opus|sonnet`),
   **fork tipi AÇMA**. İstem = "`isci` skill'ini uygula; raporu Türkçe yaz" + paketin Kuyruk satırı
   + Kaynak plan bölümünün yeri (+ dal yarımsa "dalın DEVIR.md'sinden sür"). `Agent` reddedilirse
   ya da model yoksa paket bu oturumda yapılır; Kuyruk'a gerçek model yazılır.
   **Paralellik:** aynı anda EN ÇOK 2 paket alt ajanı (dosyaları çakışmayan — Kaynak'taki "Önce
   bak" dosya listelerini karşılaştır); telefon/A-B ölçümü tek seferde BİR. Biri bitince
   doğrula-birleştir, HEMEN sıradakini başlat.
   **FABLE KURALI:** Fable yalnız önemli karar/plan evresini yapar (mimari, adım planı);
   uygulama, test, CI, belge Opus alt ajanlarına. Limit yenilenince ilk Fable başlar. Fable paketi
   yalnız 5 saatlik limit **%55 altındayken** başlar (tek Fable paketi limitin ~%50'sini yiyebilir;
   "not"ta 2026-11-11 gecesi freni geçip doldurdu); üstündeyse sıradaki Opus/Sonnet paketi, Fable
   `bekliyor` kalır ve limit yenilenince EN BAŞTA alınır. Haftalık Fable kotası sonuna kadar
   kullanılır; bitince ya da hesapta Fable yoksa Opus.
5. **Doğrula.** Raporu oku ama güvenme: `git log origin/<dal>`, diff özeti (`git diff --stat
   main...origin/<dal> | tail -n 40`). Dal push'lu olmalı. CI: `gh run list -b <dal> -L 1` →
   sürüyorsa arka planda `timeout 2700 gh run watch <id> --exit-status` (yoklama döngüsü yok).
   Kırmızıysa YENİ alt ajana yalnız kırmızı parçanın kayıt kuyruğuyla ver (en çok 2 tur; sonra
   `takıldı`). CI 3 parça: kırmızı tek parça `gh run rerun <id> --failed` ile yeniden koşabilir
   (gürültü şüphesinde bir kez).
6. **Cihaz kapısı** (Cihaz = `A/B`) → `ab-olcum` skill'i. Ölçümü yürütücü KENDİ yapmaz:
   `Agent` `model: "sonnet"` alt ajan. Karar ölçüm tablosunun sonuç satırı; kırmızıysa birleştirme
   yok, satır `takıldı: ölçüm` + sayılar. En çok 2 tur → `kullanıcı kararı`, birleştir
   (`[apk]`'sız), sıradakine geç. Telefon yok/ısınmış → `cihaz bekliyor`, `[apk]`'sız.
   Cihaz = `evet` (cihaz turu) → aynı alt ajan düzeni, `docs/CIHAZ_TESTI.md` kayıt satırı.
7. **Birleştir.** Dalda hazır olmalı: Kuyruk satırı `bitti` + sonuç, plan `[x]`, `KALANLAR.md`
   satırı (biten madde SİLİNİR — KALANLAR kuralı), HAFIZA kaydı, cihaz maddeleri
   `docs/CIHAZ_TESTI.md`'de. CI yeşil değilse ASLA birleştirme. `DEVIR.md`'yi daldan sil,
   `git checkout main && git merge --no-ff <dal>` (başlık `Birleştir: <paket adı>`; APK noktasıysa
   başlık sonuna ` [apk]`; gövdede paketin `Yeni:/İyileştirme:/Düzeltme:` satırları +
   `Co-Authored-By` satırı), sonra `git grep -nE "^(<<<<<<<|>>>>>>>)"` BOŞ olmalı, push.
   **Durum için ayrı commit/push atma** — her main push'u CI'ı baştan koşturur ve süren APK'yı
   iptal eder (`.md`/`docs/` yalnız push'u CI koşturmaz ama yine de birleştirmeyle gönder). main
   CI kırmızıysa düzelt ya da `git revert -m 1 <birleştirme>`.
8. **APK noktası** (APK = `evet`): CLAUDE.md §4 — uygulamayı değiştiren main commit'i `[apk]`
   taşır. Birleştirmeden ÖNCE paket arayüze/hıza dokunuyorsa (`ab-olcum` "Ne zaman") cihaz A/B
   ZORUNLU — telefon yoksa birleştirme `[apk]`'sız, satır `cihaz bekliyor`, sonraki APK noktası
   bu ölçümü de kapsar. Sürüm notu: dal commit'lerinin gövdesindeki `Yeni:/İyileştirme:/Düzeltme:`
   satırlarını `tool/surum_notu.sh` toplar (kullanıcı diliyle, teknik terim/dosya adı yok);
   birleştirme gövdesinde de tekrarla. Başlıkta `[minor]` yalnız plan/kullanıcı isterse.
   **APK izlenmez:** dal CI'ı yeşilse birleştir, push, sıradakine geç; yalnız sonraki main
   push'undan ÖNCE `gh run list -b main -L 1` — APK işi sürüyorsa push'u bekletip dalda çalış.
9. **Temizlik:** birleştirince `git worktree remove --force <ağaç>`, `git push origin --delete
   <dal>`, yerel dal silinir; A/B taban ağacı (`../okuyucu_ab`) ölçüm bitince silinir. Silinemeyen
   klasörü tutan Gradle/Java sürecini durdur (`./gradlew --stop` ya da süreç). "Filename too
   long" → PowerShell `Remove-Item -LiteralPath '\\?\C:\...\<ağaç>' -Recurse -Force` +
   `git worktree prune`.
10. **Yarım iş devri:** paket yarıda kalırsa (limit/durdurma) Kuyruk satırı HEMEN
    `sürüyor — dal <ad> (<commit>): bitti <x>, kalan <y>; DEVIR.md'den sür` olur ve main'e push
    edilir ("bekliyor" kalırsa sonraki tur sıfırdan başlar). Önce `git log origin/<dal>..<dal>`
    boş olmalı.
11. **Limit freni.** Her alt ajan başlatmadan ÖNCE, her bildirimde ve birleştirmeden önce
    `mcp__ccd_session_mgmt__get_usage` (ToolSearch ile yükle), "5-hour limit" `percentUsed`:
    ≥ 90 → yeni paket/alt ajan YOK; çalışana "commit + push yap ve dur"; satır `sürüyor`; kilidi
    sil; `resetsAt`'ı özete yaz, bitir (tur başında ≥ 90 ise hiçbir şey yapmadan bitir). ≥ 80 →
    yeni paket başlatma, elindekini bitir. < 80 ve Kuyruk'ta iş varken tur BİTMEZ. Araç
    `unavailable` ise frensiz devam (özete yaz). Limit elverdikçe 3. adıma dön.
    **Uzun alt ajanı DİRİLTME:** limit yenilenince ya da 5 dk'dan uzun aradan sonra eski ajana
    `SendMessage` atma (bütün geçmişini önbelleksiz yeniden gönderir; "not"ta iki Fable ajanı
    1 dakikada limiti 0 → %43 yaptı); YENİ alt ajan, istem "dalın DEVIR.md'sinden sür".
12. **Takılma önleme.** Her arka plan bekleme `timeout` ile (45 dk; tek koşu, döngü yok); dolunca
    `gh run view <id> --json status,conclusion`. Alt ajandan 90 dk bildirim yoksa `SendMessage`
    "commit + push + dur"; dönmezse `TaskStop`, satır `sürüyor`.
13. **Bitiriş.** Dur: art arda 3 `takıldı`; main iki kez üst üste kırmızı; Kuyruk boş; limit.
    Kendi arka plan görevlerini `TaskStop`, telefonu uyut (`adb shell input keyevent
    KEYCODE_SLEEP`; drive için açıldıysa önce `adb shell svc power stayon false`), kilidi sil —
    kilidi silmeden özet yazma — sonra 5 satır Türkçe özet (ne birleşti, ne takıldı, limit/
    `resetsAt`, cihaz bekleyenler, sabah bakılacaklar).
