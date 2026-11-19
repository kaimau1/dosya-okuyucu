---
name: oto-bulut
description: BULUT gözetimsiz zincirin yürütücü turu (claude.ai zamanlanmış görev `okuyucu-bulut`) — uzak kilit (`oto-kilit` dalı), main sağlığı (GitHub MCP), PLAN §1 B paketini/dilimini alt ajana verme, CI bekleme (arka plan sleep), birleştirme/[apk], yarım iş devri, bitiriş. Telefonsuz; yalnız kod (B) paketleri. Bulut zamanlanmış görevi ya da "bulutta otomasyonu sür" denince uygula.
---

# Bulut yürütücü turu (telefonsuz)

Yerel `oto-tur`'un (masaüstü + USB telefon) bulut kabına uyarlanmış, KENDİ BAŞINA YETEN hâli
(2026-11-18). Yöntem "not" zinciriyle aynı; farklar aşağıdaki tabloda. Yerel zincir aynen kalır;
ikisi aynı Kuyruk'u (`PLAN.md` §1) paylaşır ve birbirini **uzak kilit** + **`bulutta:` satır
öneki** ile görür. `oto-tur`'u ayrıca OKUMA (bu dosya yeter).

**Kullanıcı izni (2026-11-18, zamanlanmış görev istemi):** gözetimsiz çalış, soru sorma; alt ajan
aç; `main`, `faz-oto-*` ve `oto-kilit` dallarına push et. Oturumun kendi `claude/*`/`ccr-*` dalı
KULLANILMAZ (push'u CI koşturur, kota yer). PR açılmaz. KARAR maddeleri verilmiştir: SORMADAN
uygula; yeni karar → en güvenli + "sabah bakılacak"; 👤 madde → `PLAN.md` §3. Kullanıcıya giden
her metin Türkçe.

## Bulut kabının gerçeği (yerelden farklar)

| Konu | Bulutta |
|---|---|
| Kap | her çalıştırma YENİ kap + taze klon; push edilmeyen her şey kaybolur |
| Telefon / adb | YOK → Cihaz = A/B / evet işi yapılmaz; ölçülecek şey `PLAN.md` §1.8 C2/C3 + `docs/CIHAZ_TESTI.md` |
| Flutter | YOK ve İNDİRİLMEZ (CLAUDE.md §4) → doğrulama = CI |
| `gh` | YOK → CI: GitHub MCP `actions_list` / `actions_get` / `get_job_logs` (owner `kaimau1`, repo `dosya-okuyucu`) |
| Bekleme | ön planda `sleep` engelli → `Bash` `run_in_background: true` ile `sleep 900`; bitince bildirim gelir. Yoklama döngüsü YOK |
| Kilit | `.git/oto.lock` kaplar arası görünmez → uzak dal `oto-kilit`: `bash .claude/skills/oto-bulut/kilit.sh al\|tazele\|birak\|durum` (bırakmak = "SERBEST" commit'i) |
| Dal silme / zorla push | bulut git vekili dal SİLMEYİ reddeder (403, 2026-11-18); zorla push'a güvenme → hiç kullanma. Birleşmiş `faz-oto-*` dalları uzakta kalır, yok sayılır (yerel zincir siler) |
| Limit freni | `get_usage` YOK → fren yok. Limit dolunca oturum kesilir; kimse tazelemediği için kilit 60 dk'da bayatlar, sonraki saatlik çalıştırma kaldığı yerden sürer. Bu yüzden: her adım push'lu, satır `bulutta: sürüyor` main'de, DEVIR.md güncel |
| Actions kotası | ayda ~2000 dk (CLAUDE.md §3) → dilim başına TEK dal CI koşusu: ara push'lar başlıkta `[skip ci]`; main'de test koşmasın diye birleştirme ağacı = yeşil dal ucu ağacı |

## Adımlar

0. **Kilit.** `kilit.sh al` → çıkış 3 (MEŞGUL) ise hiçbir şey yapmadan "başka yürütücü çalışıyor"
   de, BİTİR. Çıkış 1 (push reddi) → tek satır yaz, BİTİR. Sonra `kilit.sh tazele`: her adım
   başında, her bildirimde/uyanışta, her `sleep`'ten önce (işçi de her push'ta tazeler). Çıkış 3
   (KAYIP) = kilit başkasına geçti → elindekini push et, işçilere "commit + push + dur", DUR.
   Arka plan döngüsüyle tazeleme YASAK. İşçi uzun sürerken bekçi: arka planda `sleep 2400`, her
   uyanışta tazele + yeniden kur (işçi bildirimi gelince bekçiyi `TaskStop`).
1. **Depo.** `git fetch origin main && git checkout -B main origin/main` (oturum dalında kalma).
   `git fetch origin '+refs/heads/faz-oto-*:refs/remotes/origin/faz-oto-*'` → uzaktaki zincir
   dalları; `git merge-base --is-ancestor origin/<dal> origin/main` doğruysa dal BİRLEŞMİŞTİR,
   yok say. Birleşmemiş ve satırı olmayan dalın `git show origin/<dal>:DEVIR.md`'sine bak, satıra
   bağla. Klon sığsa ve birleştirme tabanı
   bulunamazsa `git fetch --deepen=300 origin main <dal>`.
2. **main sağlığı.** `actions_list` `method: list_workflow_runs`, `resource_id: build-apk.yml`,
   `workflow_runs_filter: {branch: main}`, `perPage: 3`. Son BİTEN koşu kırmızıysa turun işi onu
   düzeltmek (işçi; istemine `get_job_logs` `run_id` + `failed_only` + `return_content` +
   `tail_lines: 80` kuyruğu). main iki kez üst üste kırmızı → DUR. `[apk]` koşusu sürüyorsa KOD
   içeren main push'u bekler (yalnız `.md`/`docs/`/`.claude/` push'u CI açmaz, serbest).
3. **Paketi seç** (`PLAN.md` §1 SIRA + tablo; BİR kez oku). Alınır: **B satırı**, Durum `bekliyor`
   ya da `bulutta: sürüyor`. Alınmaz: C satırları, `kullanıcı kararı`, `cihaz bekliyor`,
   `takıldı`, yerel zincirin CANLI işi (başında `bulutta:` olmayan `sürüyor`, ya da DEVIR'inde
   "bulut" geçmeyen birleşmemiş `faz-oto-<no>-*` dalı — son commit'i < 3 saat).
   **Devralma (yerelin yarım işi):** B satırı önek olmadan `sürüyor` ve dalının son commit'i
   ≥ 3 saat (yerel işçi her commit'te push eder; 3 saat sessizlik = bilgisayar uyudu ya da tur
   bitti) → bulut devralır: Durum `bulutta: sürüyor (<tarih>) — dal <ad> (yerelden devralındı)`,
   işçiye "dalın DEVIR.md'sinden sür" (telefon gerektiren kalan → C2). Paketin içinden yalnız
   telefonsuz maddeler: 📱 / "ölç → değiştir → ölç" / ölçümsüz anlamsız hız maddesi YAPILMAZ
   (C2'ye madde olur). 👤 kararı bekleyen madde atlanır, kalan yapılır. Önce `bulutta: sürüyor`
   (DEVIR'den sür), yoksa SIRA'daki ilk uygun. Uygun B kalmadıysa → 9. adım (Kuyruk boş).
   **Günlük dilim sınırı YOK** (kullanıcı 2026-11-18: "iş bitene kadar devam"): uygun B kaldıkça
   dilim açılır — istemde eski `GÜNLÜK DİLİM = N` yazsa da YOK SAY; durdurucular yalnız 9. adımdakiler
   (kota/fatura hatası dahil).
   **Sahiplen** (işçiden ÖNCE, paralel ikinciyle birlikte TEK commit): Durum
   `bulutta: sürüyor (<YYYY-AA-GG>) — dal faz-oto-<no>-<ad>`; yalnız `PLAN.md` değişir, başlık
   `PLAN: <no> bulutta sürüyor [skip ci]`, `git push origin main`. Yerel `oto-tur` bu satırı atlar.
   Push reddedilirse `git pull --rebase origin main`; satır bu arada başkasınca alındıysa bırak,
   sıradakine geç.
4. **Yaptır.** `Agent`, `isolation: "worktree"`, model satırdan (yoksa `opus`); fork tipi AÇMA.
   İstem = "`isci` skill'ini **Bulut kipi** bölümüyle uygula; raporu Türkçe yaz" + satırın tamamı
   + Kaynak bölümünün yeri (`grep -n` satır no) + dal adı + **dilim** + (dal varsa) "dalın
   DEVIR.md'sinden sür". **Dilim:** B paketleri birkaç oturumluk; işçiye tek CI koşusuna sığan,
   kendi başına çalışan, yeşil olabilecek bir parça ver (ör. B1: şema + Office/metin özütü; B4:
   P16) — bitince main'e girer, kalan sonraki dilimde (aynı dal adı, main'den yeniden).
   **Paralellik:** en çok 2 işçi, dosyaları çakışmayan paketlerde. **Fable:** limit okunamadığı
   için yalnız satırında "(… evresi fable)" yazan paketin plan/şema evresinde ve oturumun İLK alt
   ajanı olarak; uygulama Opus. `Agent` reddedilir ya da model yoksa iş bu oturumda, aynı
   kurallarla yapılır.
5. **CI bekle ve doğrula.** Raporu oku ama güvenme: `git fetch origin <dal>`,
   `git log --oneline origin/main..origin/<dal> | tail -n 20`,
   `git diff --stat origin/main...origin/<dal> | tail -n 30`. `kilit.sh tazele` → arka planda
   `sleep 900` → uyanınca `actions_list` (`branch: <dal>`, `perPage: 1`); koşunun `head_sha`'sı
   dalın ucu olmalı. Sürüyorsa `sleep 600` (en çok 4 bakış ≈ 55 dk; sonra `takıldı: CI bitmedi`).
   Ucun koşusu yoksa (son push yalnız `.md` ya da `[skip ci]`): işçiye "kod içeren, `[skip ci]`'siz
   commit'le push et" — elle tetik (`workflow_dispatch`) KULLANMA (tam takım + APK = kota).
   Kırmızı → YENİ işçi, istem: kırmızı parçanın kayıt kuyruğu (`get_job_logs` `failed_only`,
   `tail_lines: 80`) + "dalı düzelt, push" — en çok 2 tur, sonra satır `takıldı: CI` (+ kuyruğun
   2 satırı). Kota/fatura hatası (işler başlamıyor, "spending limit"/"billing") → yeni CI açma,
   §3'e madde, DUR.
6. **Birleştir** (CI yeşil değilse ASLA). Yeşil uçta hazır olmalı: DEVIR.md YOK (işçi siler),
   PLAN satırı/maddeleri güncel (biten madde silinir, kalan yazılı), HAFIZA kaydı, cihazda
   bakılacaklar CIHAZ_TESTI + §1.8. `git merge-base --is-ancestor origin/main origin/<dal>` doğru
   olmalı — değilse (main kodla ilerlemiş) işçiye "`git merge origin/main`, push" (dal CI'ı
   yeniden, seçili testlerle), yeşilse sür; main yalnız `.md` ile ilerlediyse beklemeden birleştir
   (main'de tam takım koşar, kabul). Sonra:
   `git fetch origin main <dal> && git checkout -B main origin/main && git merge --no-ff
   origin/<dal>` — başlık `Birleştir: <paket/dilim>` (+ APK noktasıysa ` [apk]`), gövde: dalın
   `Yeni:/İyileştirme:/Düzeltme:` satırları + `Co-Authored-By` (ortamın verdiği).
   `git grep -nE "^(<<<<<<<|>>>>>>>)"` BOŞ olmalı → `git push origin main`. Durum için ayrı
   commit/push YOK. Paket TAMAMEN bittiyse satır işçinin dalında zaten silinmiştir.
7. **APK noktası** — istemdeki **ÖLÇÜMSÜZ APK**:
   - `evet` (kullanıcı 2026-11-18: "her sabah APK istiyorum"; CLAUDE.md §4c bulut istisnası):
     uygulamayı değiştiren birleştirme `[apk]` taşır — yalnız son 4 saatte main'de `[apk]` yoksa
     (`git log origin/main --since='4 hours ago' -E --grep='\[apk\]' --oneline` boş); varsa
     `[apk]`'sız, sonraki taşır (kota). Ölçülmeyen her kapı yüzeyi C2'ye "ölçülmedi (<tarih>,
     <kısa sha>)". Sabah APK'sı → aşağıdaki **Sabah denetimi**.
   - `hayır` (CLAUDE.md §4c ÖLÇÜM KAPISI): kapı yüzeyine (PDF görüntüleyici, dosya listesi, ana
     ekran, üst/alt çubuk, klavye, geçiş) varsayılan AÇIK dokunan iş `[apk]`'sız — C2'ye "A/B
     bekliyor: <ne> (main <kısa sha>)", yerel zincir telefonla ölçüp `[apk]` yapar; main'de A/B
     bekleyen iş varken hiçbir `[apk]` atılmaz.
   APK koşusu İZLENMEZ; yalnız sonraki KOD içeren main push'undan önce tek `actions_list` (main,
   `perPage: 1`) — sürüyorsa bekle (kod push'u süren APK'yı iptal eder).
   **Sabah denetimi** (`evet` iken; her 3. adımdan önce ve 9. adımda, tek `date` + `git log`):
   son APK'nın commit'i `S=$(git log origin/main -E --grep='\[apk\]' -1 --format=%H)`; ondan beri
   uygulama değişikliği var mı: `git log $S..origin/main --oneline -- lib ci android assets
   pubspec.yaml`. Türkiye saati (UTC+3) 04:00–09:00 arasındaysa ve değişiklik varsa: bu penceredeki
   ilk uygulama değiştiren birleştirme 4 saat kuralına bakmadan `[apk]` taşır. TR 06:30'u geçtiyse,
   değişiklik hâlâ APK'sızsa ve 30 dk içinde birleştirme beklenmiyorsa: main'de BİR KEZ elle tetik —
   GitHub MCP `actions_run_trigger` (`run_workflow`, `build-apk.yml`, ref `main`; tam takım + APK
   ≈ 50 dk). Önce `actions_list` (`branch: main`, `event: workflow_dispatch`, `perPage: 1`): bugün
   tetik varsa YAPMA (günde en çok 1). Araç yoksa özete "sabah APK'sı çıkmadı: <neden>". Bu koşu
   bitmeden kod içeren main push'u YOK.
8. **Temizlik + sıradaki.** Birleşince işçinin çalışma kopyası `git worktree remove --force <yol>`;
   uzak dal SİLİNMEZ (vekil reddeder; birleşmiş dal 1. adımda yok sayılır, aynı adlı sonraki dilim
   `origin/main`'den yeniden başlar — ileri sarma olduğu için düz push yeter). Yarım kalan iş (limit/durdurma/KAYIP) → satır HEMEN
   `bulutta: sürüyor — dal <ad> (<kısa sha>): bitti <x>, kalan <y>; DEVIR.md'den sür` +
   `[skip ci]` commit + main push; önce `git log origin/<dal>..<dal>` boş olmalı.
   **Uzun alt ajanı DİRİLTME:** uzun aradan sonra eski ajana `SendMessage` atma (bütün geçmişini
   yeniden gönderir) — YENİ işçi, "DEVIR.md'den sür". İşçiden 120 dk ses yoksa (bekçi uyanışında)
   `SendMessage` "DEVIR + commit + push + dur"; dönmezse `TaskStop`.
   Sonra 3. adıma dön. **Bağlam tasarrufu:** bu oturumda 3 birleştirme olduysa ya da bağlam
   özetlendiyse (compaction) yeni dilim AÇMA → 9. adım; sonraki saatlik çalıştırma taze bağlamla
   sürer.
9. **Bitiriş.** Dur: art arda 3 `takıldı`; main iki kez üst üste kırmızı; uygun B kalmadı; kota;
   KAYIP. Kendi arka plan görevlerini `TaskStop`, `git status` temiz ve `git log origin/main..main`
   BOŞ, sonra `kilit.sh birak` — kilidi bırakmadan özet yazma — sonra 5 satır Türkçe özet: ne
   birleşti (sha, `[apk]` var mı), ne takıldı, kalan, cihazda bakılacaklar (C2), sabah
   bakılacaklar. Zincir bir DUR koşuluyla bittiyse (limit hariç) `PushNotification` ile tek satır.

## Token tasarrufu

Her araç çağrısı bütün bağlamı yeniden gönderir — az ve toplu çağrı, bağımsız okumalar tek
mesajda. `PLAN.md` §1'i BİR kez oku; paket ayrıntısı `grep -n` + `sed -n`. `HAFIZA.md` (230 KB+)
baştan okunmaz (son ~30 satır, gerisi `grep`), graphify açılmaz. Çıktıyı kes (`| tail -n 40`,
`cut -c1-300`); CI kaydının yalnız kırmızı parçasının kuyruğu. İşçi beklerken yoklama yok.
