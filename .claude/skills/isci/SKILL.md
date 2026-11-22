---
name: isci
description: Gözetimsiz zincirde paket işleyen alt ajanın (işçi) kuralları — dal, DEVIR.md, kanıt→düzelt→kanıt, doğrulama (CI), dokunulmayacaklar, bitiş ve rapor. Kuyruk paketi verilen her alt ajan önce bunu uygular.
---

# İşçi kuralları

"not" projesindeki `isci` skill'inin dosya okuyucuya uyarlanmış hâli (2026-11-14). Kullanıcı izni:
işi bitir, token israf etme ama bitmiş iş ver. Yürütücü ince kalır — CI izleme, kırmızı CI
düzeltme, DEVIR, plan `[x]`, Kuyruk satırı ve sürüm notu satırları İŞÇİNİN işidir.

## Başlangıç

- Depo: Flutter dosya okuyucu/düzenleyici + dosya yöneticisi, **yalnız Android**,
  `C:\Users\sena\Desktop\dosya okuyucu`. Önce `CLAUDE.md`, sonra Kuyruk satırının "Kaynak"
  sütunundaki plan bölümü (ör. `docs/arsiv/planlar/FERRARI_PLANI.md` §0 çalışma kuralları + ilgili Faz). Faz
  planındaki **"Önce bak"** adımı zorunlu; "doğrulanmadı" yazan yer tahmindir, önce koddan doğrula.
- `HAFIZA.md`'yi BAŞTAN SONA OKUMA: son ~30 satır, gerisi + `docs/hafiza/*.md` konuya göre `grep`.
  `graphify-out/GRAPH_REPORT.md` de baştan okunmaz, `grep`. Dal yarımsa ÖNCE dalın `DEVIR.md`'sini
  oku, baştan keşfetme.
- Dal: **`faz-oto-<no>-<kısa-ad>`** (CI yalnız `main`/`claude/**`/`ccr-*`/`faz-*` dallarında koşar;
  CLAUDE.md §4 zincir istisnası). Flutter yolu `C:/src/flutter-3479/bin/flutter.bat` (3.47.9 = CI;
  `C:\src\flutter` 3.47.7 `pub get` kilidini bozar; PATH'te değil — "command not found" SDK yok
  demek değil). Yerel derleme gerekiyorsa önce `flutter pub get`.
- Küçük adımlarla commit + **her commit'ten sonra push** (limit oturumu her an kesebilir; yarım
  iş dalda kalsın). **main'e push YOK.** Faz içindeki her madde AYRI commit (tek `git revert`).

## DEVIR.md (devir notu)

Dalın kökünde, HER push'tan önce güncel, en çok 25 satır: yapılanlar (madde + commit) · şu anki
adım · kök neden/kanıt (dosya:satır) · işe yaramayanlar · sıradaki adım · test/ölçüm komutu.
Ölçüm ham sayıları buraya (sohbette kalmaz). Yürütücü birleştirmeden önce daldan SİLER.

## Yöntem

- **Önce kanıtı üret → düzelt → aynı kanıt yeşil.** Kanıt: başarısız test, ölçüm satırı, ya da
  kod satırıyla gösterilmiş kök neden. Kanıt üretilemiyorsa düzeltme yazma: maddeye
  "üretilemedi: <ne denendi>" yaz, bitir.
- Kök neden, yama değil ("basite kaçma"). Doğrulanmamış şeyi "hipotez" diye işaretle.
- **Tahminle performans düzeltmesi yok** (FERRARI §0.4, PERFORMANS KORUMA ANAYASASI
  `PLAN.md` §0): 📱 maddede önce ölç, değiştir, yeniden ölç; tablo `docs/perf/`.
  Hız işinde kötüleşme SIFIR; madde başı ayrı commit; ölçülemeyen "hızlandırma" birleşmez.
- Görünür yeni alan/kip/sarmalayıcı, liste/ızgara hücresi, görüntüleyici kabuğu → push'tan önce
  **`kasma-kontrol`** skill'i. Cihaz ölçümü → **`ab-olcum`** skill'i.
- Görünüş/yer değiştirmeden önce o dosya/özellik için `HAFIZA.md` + `docs/hafiza/` içinde
  "kullanıcı" kararlarını `grep` et (ör. satır simgesi, filtreler, güncelleme şeridi kararları);
  geçmiş kullanıcı isteğini geri alan iş yapılmaz (planla çelişirse kullanıcı kararı kazanır;
  planı düzelt, HAFIZA'ya yaz).
- Tasarım tokenları ve bekçiler (FERRARI §0.5–0.6): `Gap/Radii/AppType/Motion.of/AppIcons/
  AppHaptics`, metin `context.t()` + üç dil (tr, en, ar), `design_tokens_baseline.json` tavanı
  yalnız düşer (yeni dosyada 0), widget'ta `Future.delayed` yok, `await` sonrası `mounted`.
- **KARAR** çıkarsa: plandaki **"En güvenli"** seçenek + maddeye "sabah bakılacak". 👤 madde
  yapılmaz: `PLAN.md` §3'e ne · nasıl · doğruysa · yanlışsa biçiminde madde. Kullanıcıya
  soru sorma. Madde kapsamı dışına çıkma; plan dondurması sürerken yeni özellik ekleme (fikir →
  `PLAN.md` §1 yeni satır `bekliyor`).
- **Dokunma:** imza anahtarı/keystore (`*.jks`, `key.properties`, base64'leri — içeriğini
  yazdırma), GitHub Secrets, `SIGNING.md` düzeni, erişimi/izni GEVŞETEN değişiklik, kullanıcı
  verisi silen/taşıyan göç (gerekirse önce yedek + geri alınabilir göç), telefondaki varsayılan
  kimlikli uygulama (`com.dosyaokuyucu.dosya_okuyucu`) — ölçüm yalnız `….r8test` kimliğiyle.
- **KVKK:** HAFIZA/plan/ölçüm tablosuna hasta verisi, TC, kişisel dosya adı, token yazma; ölçüm
  tablosunda dosya adı yerine takma ad (`tool/pdf_profil.sh` düzeni).
- Telefon: yalnız işin gerektirdiği an, tek seferde bir iş; kurallar `ab-olcum`'da. Telefon
  gerektiren doğrulama yapılamazsa "yazıldı, cihazda doğrulanmadı" + `docs/CIHAZ_TESTI.md`'ye
  madde (kullanıcının yapacağıysa ayrıca `PLAN.md` §3). Google/Drive girişi isteyen akış:
  "denenmedi".

## Doğrulama (DOĞRULAMA = CI, kullanıcı kararı 2026-11-04)

- Yerelde `flutter test`/`flutter analyze` KOŞTURMA (bu makinede yerel test "Building native
  assets failed" verir; CI `verify` 3 parça test eder). İstisna: plan maddesi açıkça yerel/cihaz
  ölçümü istiyorsa (📱💻 fazlar).
- `dart format lib` / toplu biçimlendirme YOK — yalnız kendi eklediğin yeni dosya.
- **Her push'tan önce `python3 tool/on_denetim.py`** (Flutter gerekmez, ≈1 sn): çeviri anahtarı,
  erişilemeyen dosya, kırık import, testte gerçek G/Ç. Kırmızıysa push etme, düzelt (2026-11-22:
  dal koşularının ~%35'i ilk push'ta kırmızıydı, çoğu bu sınıftandı).
- Yeni widget testi yazarken: `testWidgets` içinde `await File(..).writeAsBytes` YOK (`*Sync`);
  imleç yanıp sönen ekranda (Word/Excel düzenleyici, odaklı TextField) `pumpAndSettle` YOK
  (sınırlı `pump`); şerit düğmesine dokunmadan önce `ensureVisible`. Silinen dosyanın testini de sil.
- Push sonrası `gh run list -b <dal> -L 1`; sürüyorsa `timeout 2700 gh run watch <id>
  --exit-status` (arka planda, yoklama döngüsü yok). Kırmızıysa YALNIZ başarısız parçanın kayıt
  kuyruğu (`gh run view <id> --log-failed | tail -n 60`), düzelt, push — en çok 2 tur, sonra
  `takıldı`. Testi atlama/kapatma YASAK. CI yeşil olmadan "bitti" denmez.
- Arka planda başlattığın her komut (`flutter`, `gh run watch`, `adb`, betik) `timeout` ile;
  raporu yazmadan önce hepsini bitir/öldür. Uzun çıktıyı kes (`| tail -n 40`).
- `ci/*.kt` değişikliğini CI Kotlin denetimi yakalar; `ci/MediaTranscode.kt` gibi denetim
  dışındaki Kotlin hatası ancak APK derlemesinde çıkar (HAFIZA) — API'yi kaynak jar'dan doğrula.

## Bulut kipi (yürütücü `oto-bulut` ise — yukarıdakileri şu farklarla uygula; 2026-11-18)

- Kap geçici; telefon/adb, Flutter ve `gh` YOK. Windows yolları ve `flutter.bat` geçersiz,
  Flutter İNDİRİLMEZ; yerel test/analiz yok, CI doğrular. Dart'ı dikkatle yaz: `flutter analyze`
  info düzeyinde de sıfır ister (kullanılmayan import, `const`, `await` sonrası `mounted`).
- Dal: yürütücünün verdiği `faz-oto-<no>-<ad>` — uzakta varsa VE main'e birleşmemişse
  (`git merge-base --is-ancestor origin/<dal> origin/main` yanlış) `git checkout -B <dal>
  origin/<dal>`; yoksa ya da birleşmişse `git checkout -B <dal> origin/main`. Oturumun
  `claude/*`/`ccr-*` dalına push YOK. Zorla push ve dal silme YOK (bulut vekili silmeyi reddeder).
- **Push düzeni (Actions kotası):** her commit'ten sonra push (kap her an gidebilir) ama ara
  commit başlığının sonunda `[skip ci]`. Her push'tan önce `bash .claude/skills/oto-bulut/kilit.sh
  tazele` — çıkış 3 (KAYIP) → DEVIR.md + `[skip ci]` push, DUR, rapora yaz.
- **CI'a gönderiş (dilim bitince, bir kez):** `git merge origin/main` (çakışmayı çöz) → PLAN
  satırı/maddeleri + HAFIZA + `docs/CIHAZ_TESTI.md` güncel → **DEVIR.md'yi SİL** (devir bilgisi bu
  commit'in gövdesine) → KOD içeren ve başlığında `[skip ci]` OLMAYAN son commit → push. Bu uç,
  CI'ın koştuğu ve main'e AYNEN gireceği uçtur: sonrasına commit ekleme (yalnız `.md` push'u CI
  açmaz ama ucu değiştirir, main'de tam takım koşturur).
- CI'ı BEKLEME/izleme — yürütücü bekler. Kırmızıysa yürütücü seni kayıt kuyruğuyla yeniden
  çağırır: düzelt, aynı gönderiş kuralıyla push (testi atlama/kapatma YASAK).
- Cihaz: Cihaz = A/B/evet maddesinin KODU yazılır, ölçüm/tur yapılmaz → `PLAN.md` §1.8 C2 (ölçüm)
  ya da C3 (tur) maddesi "(bulut <tarih>, <kısa sha>)" + `docs/CIHAZ_TESTI.md`. Ölçmeden
  yapılamayan hız maddesi (📱, "ölç → değiştir → ölç") YAZILMAZ, C2'ye taşınır. Görünür
  değişiklikte `kasma-kontrol` yine uygulanır (cihazsız maddeleri) + dokunulan yüzeyin bütçe testi.
- PLAN satırı: Durum `bulutta: sürüyor — …` kalır; dilim bittiyse "dilim <x> main'e gidiyor,
  kalan <y>"; paket tamamen bittiyse satır silinir.
- Rapora ekle: "CI ucu: <sha>" ya da "yarım: <sha>, DEVIR.md'de".

## Bitiş (dalda, birleştirmeden önce hazır olmalı)

- Kuyruk satırı (`PLAN.md` §1): kod bitti + A/B/cihaz bekliyorsa maddeyi ilgili **C paketine** (§1, 2026-11-18 büyük paketler) taşı ve durumu yaz; tamamen bittiyse SİL (yalnız KENDİ satırın; SIRA satırına
  dokunma); arşivdeki plan dosyaları GÜNCELLENMEZ; HAFIZA.md'ye tarihli kayıt (kalıcı karar / bug kök nedeni /
  yanlış çıkan yol — sır ve kişisel veri yok); cihazda bakılacaklar `docs/CIHAZ_TESTI.md`.
- Uygulamayı değiştiren commit'lerin GÖVDESİNDE kullanıcı diliyle `Yeni: …` / `İyileştirme: …`
  / `Düzeltme: …` satırları (tek cümle, teknik terim/dosya adı yok; `tool/surum_notu.sh`
  bunları toplar). Commit sonu `Co-Authored-By` satırı (ortamın verdiği).
- Yarıda kalırsan: Kuyruk satırı `sürüyor — dal <ad> (<commit>): bitti <x>, kalan <y>;
  DEVIR.md'den sür`, `git log origin/<dal>..<dal>` boş.
- **Rapor ≤ 15 satır, Türkçe:** ne değişti (dosyalar), hangi test/ölçüm kırmızıdan yeşile döndü,
  doğrulanamayan ne kaldı, dal adı, son commit, CI sonucu.
