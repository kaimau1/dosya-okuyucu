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
  sütunundaki plan bölümü (ör. `docs/FERRARI_PLANI.md` §0 çalışma kuralları + ilgili Faz). Faz
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
  `docs/GELISTIRME_PLANI.md`): 📱 maddede önce ölç, değiştir, yeniden ölç; tablo `docs/perf/`.
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
  yapılmaz: `KONTROL_LISTEM.md`'ye ne · nasıl · doğruysa · yanlışsa biçiminde madde. Kullanıcıya
  soru sorma. Madde kapsamı dışına çıkma; plan dondurması sürerken yeni özellik ekleme (fikir →
  `KALANLAR.md`).
- **Dokunma:** imza anahtarı/keystore (`*.jks`, `key.properties`, base64'leri — içeriğini
  yazdırma), GitHub Secrets, `SIGNING.md` düzeni, erişimi/izni GEVŞETEN değişiklik, kullanıcı
  verisi silen/taşıyan göç (gerekirse önce yedek + geri alınabilir göç), telefondaki varsayılan
  kimlikli uygulama (`com.dosyaokuyucu.dosya_okuyucu`) — ölçüm yalnız `….r8test` kimliğiyle.
- **KVKK:** HAFIZA/plan/ölçüm tablosuna hasta verisi, TC, kişisel dosya adı, token yazma; ölçüm
  tablosunda dosya adı yerine takma ad (`tool/pdf_profil.sh` düzeni).
- Telefon: yalnız işin gerektirdiği an, tek seferde bir iş; kurallar `ab-olcum`'da. Telefon
  gerektiren doğrulama yapılamazsa "yazıldı, cihazda doğrulanmadı" + `docs/CIHAZ_TESTI.md`'ye
  madde (kullanıcının yapacağıysa ayrıca `KONTROL_LISTEM.md`). Google/Drive girişi isteyen akış:
  "denenmedi".

## Doğrulama (DOĞRULAMA = CI, kullanıcı kararı 2026-11-04)

- Yerelde `flutter test`/`flutter analyze` KOŞTURMA (bu makinede yerel test "Building native
  assets failed" verir; CI `verify` 3 parça test eder). İstisna: plan maddesi açıkça yerel/cihaz
  ölçümü istiyorsa (📱💻 fazlar).
- `dart format lib` / toplu biçimlendirme YOK — yalnız kendi eklediğin yeni dosya.
- Push sonrası `gh run list -b <dal> -L 1`; sürüyorsa `timeout 2700 gh run watch <id>
  --exit-status` (arka planda, yoklama döngüsü yok). Kırmızıysa YALNIZ başarısız parçanın kayıt
  kuyruğu (`gh run view <id> --log-failed | tail -n 60`), düzelt, push — en çok 2 tur, sonra
  `takıldı`. Testi atlama/kapatma YASAK. CI yeşil olmadan "bitti" denmez.
- Arka planda başlattığın her komut (`flutter`, `gh run watch`, `adb`, betik) `timeout` ile;
  raporu yazmadan önce hepsini bitir/öldür. Uzun çıktıyı kes (`| tail -n 40`).
- `ci/*.kt` değişikliğini CI Kotlin denetimi yakalar; `ci/MediaTranscode.kt` gibi denetim
  dışındaki Kotlin hatası ancak APK derlemesinde çıkar (HAFIZA) — API'yi kaynak jar'dan doğrula.

## Bitiş (dalda, birleştirmeden önce hazır olmalı)

- Kuyruk satırı (`OTOMASYON.md`) `bitti` + tek satır sonuç (yalnız KENDİ satırın; SIRA satırına
  dokunma); plan maddesi `[x]` + tarih + sonuç (ya da gerekçeli "yapılmadı"); `KALANLAR.md`'de
  biten madde silinir / güncellenir; HAFIZA.md'ye tarihli kayıt (kalıcı karar / bug kök nedeni /
  yanlış çıkan yol — sır ve kişisel veri yok); cihazda bakılacaklar `docs/CIHAZ_TESTI.md`.
- Uygulamayı değiştiren commit'lerin GÖVDESİNDE kullanıcı diliyle `Yeni: …` / `İyileştirme: …`
  / `Düzeltme: …` satırları (tek cümle, teknik terim/dosya adı yok; `tool/surum_notu.sh`
  bunları toplar). Commit sonu `Co-Authored-By` satırı (ortamın verdiği).
- Yarıda kalırsan: Kuyruk satırı `sürüyor — dal <ad> (<commit>): bitti <x>, kalan <y>;
  DEVIR.md'den sür`, `git log origin/<dal>..<dal>` boş.
- **Rapor ≤ 15 satır, Türkçe:** ne değişti (dosyalar), hangi test/ölçüm kırmızıdan yeşile döndü,
  doğrulanamayan ne kaldı, dal adı, son commit, CI sonucu.
