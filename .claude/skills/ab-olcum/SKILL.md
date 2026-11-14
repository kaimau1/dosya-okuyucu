---
name: ab-olcum
description: Cihazda A/B hız ölçümü (ÖLÇÜM KAPISI / HIZ SÖZLEŞMESİ) ve USB test telefonu kuralları — taban/aday profil derlemesi (.r8test), perf_senaryo.sh / pdf_profil.sh, eşikler, MIUI kurulum onayı, ekran/ısı. [apk] öncesi, Cihaz=A/B ya da Cihaz=evet paketinde çağır.
---

# Cihaz A/B ölçümü + test telefonu

"not" projesindeki `ab-olcum` skill'inin dosya okuyucuya uyarlanmış hâli (2026-11-14). Gerekçe
("not", kullanıcı 2026-11-10): "son güncellemelerden sonra kasma yeniden başladı… zamanında
kontrol et" — kök neden testleri yeşil geçen küçük bir arayüz değişikliğiydi; kimse ölçmemişti.

> **Tek komut (P01, 2026-11-14):** `timeout 14400 bash tool/ab_olcum.sh [A_ref] [B_ref]` (arka
> planda; A varsayılan main'deki son `[apk]`, B = HEAD). İki ref'i `../okuyucu_ab_<sha>`
> worktree'lerinde `.r8test` profil derler (güncel senaryo dosyası ikisine kopyalanır), A,B,A,B
> (`AB_TUR=2`) `flutter drive --use-application-binary` koşar; pil < 37 °C bekler, ≥ 40 °C koşu
> geçersiz; MIUI kurulum penceresini arka plan bekçisi onaylar (önce ekran görüntüsü). Tablo
> `docs/perf/<tarih>-ab-<A>-<B>.md`, son satır `KARAR:`; çıkış 0 GEÇTİ · 1 KALDI · 2 YETERSİZ ·
> 3 cihaz bekliyor. `BUYUK_PDF=/storage/<usb>/x.pdf` (H0.2 büyük PDF), `AB_KURU=1` (tek A
> koşusu), `AB_TUT=1` (ağaçlar kalır). Karar kuralı + öz denetim: `python tool/ab_karar.py
> --deneme`. Ayrıca: `tool/perf_senaryo.sh` (tek derleme), `tool/pdf_profil.sh` (PDF açılış +
> kaydırma, KARE/PSS), `tool/r8_ab.sh` (`read` bekler → **gözetimsiz KULLANILMAZ**). PDF açılış
> damgaları logcat'te `PDFPRO_PERF faz=acilis_{ekran,belge,ilk_sayfa,kucuk_resim}` (H0.3).
> Aşağıdaki elle yöntem betik çalışmazsa yedektir.

## Ne zaman (bağlayıcı)

- **ÖLÇÜM KAPISI:** PDF görüntüleyici (açılış, kaydırma, yakınlaştırma), dosya listesi/ızgara,
  ana ekran, görüntüleyici kabuğu (üst/alt çubuk, klavye), geçiş/levha animasyonuna dokunan iş
  `[apk]`'ya girmeden önce cihazda A/B ölçülür.
- **HIZ SÖZLEŞMESİ (bu projede PERFORMANS KORUMA ANAYASASI, `docs/GELISTIRME_PLANI.md`, +
  `docs/FERRARI_PLANI.md` §0.4, §2):**
  1. Dokunulan yüzeyin cihazsız bütçe/perf testi olmalı (`test/perf/*_perf_test.dart`,
     `startup_budget_test`, `image_budget_test`, `perf_offload_test`, `root_rebuild_test`) —
     yoksa işin parçası olarak YAZILIR.
  2. Gerileme **> %10 ya da kare p99 > 24 ms** = birleştirme yok (anayasa 8d); özellik bayrakla
     kapalı gelir ya da kök neden çözülür. Ferrari kapısı: §2 "10 işlem"de Samsung'dan > %20 yavaş
     değiliz ya da gerekçe yazılı (H12).
  3. Hız/akıcılık işlerinde kötüleşme SIFIR; madde başı ayrı commit, kötüleştiren tek commit geri
     alınır (`git revert`), iyiler yeniden ölçülüp birleşir. İyileşme kanıtlanamayan değişiklik
     yapılmaz.
  4. Mandallar (`test/design_tokens_baseline.json` tavanları, `PerfBudget` sınırları, CI APK
     boyut bütçesi) yalnız düşer.
  **Ölçmeden "akıcı/hızlı/düzeldi" denmez.**
- **Yürütücü ölçümü KENDİ yapmaz:** `Agent` `model: "sonnet"` alt ajan ("taban ve aday profil
  derlemesi, aynı senaryo, tabloyu ve karar satırını getir; raporu Türkçe yaz").

## Taban ve aday derleme (ölçüm kimliği `com.dosyaokuyucu.dosya_okuyucu.r8test`)

- Taban (A) = son `[apk]` commit'i (`git log --grep='\[apk\]' -1 --format=%H main`):
  `git worktree add ../okuyucu_ab <commit>`. Aday (B) = dal başı. İkisinde de aynı adımlar.
- Flutter PATH'te değil: `export PATH="/c/src/flutter-3479/bin:$PATH"` (3.47.9 = CI).
- İskelet + yamalar + ölçüm kimliği: `DOSYA_R8TEST=1 bash ci/prepare_android.sh`. TUZAK (HAFIZA
  2026-11-13): ikinci koşuda "Desugaring yamalanamadı"da durur → manifest + PickerActivity
  authority'sini elle `….r8test.documents` yap; yoksa `INSTALL_FAILED_CONFLICTING_PROVIDER`.
- Yerel imza anahtarı ≠ CI anahtarı → `.r8test` asla yayın paketinin üstüne kurulmaz; varsayılan
  kimlikli uygulamaya (`com.dosyaokuyucu.dosya_okuyucu`, telefondaki nightly) DOKUNMA — imza farkı
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` verir, kaldırıp kurmak veriyi siler.
  Kurulumdan sonra doğrula: `adb shell pm list packages | grep r8test`.
- Ölçüm bitince taban ağacı silinir: `git worktree remove --force ../okuyucu_ab` (silinemiyorsa
  tutan Gradle/Java sürecini durdur).

## Koşu (elle yöntem — `tool/ab_olcum.sh` çalışmazsa)

1. Ölçüm verisi (bir kez, temiz): `python tool/make_test_tree.py olcum_verisi` →
   `adb push olcum_verisi/. /sdcard/Android/data/com.dosyaokuyucu.dosya_okuyucu.r8test/files/olcum/`.
2. Her ağaçta: `OLCUM_VERISI=/sdcard/Android/data/com.dosyaokuyucu.dosya_okuyucu.r8test/files/olcum
   timeout 3600 bash tool/perf_senaryo.sh <A|B>` (arka planda, `timeout` ile). Sıra A, B, A, B
   (en az 2'şer); her senaryo için p90/p99 build + raster ortancası.
3. PDF işi: `bash tool/pdf_profil.sh /sdcard/Download/<dosya>.pdf "<takma ad>"
   com.dosyaokuyucu.dosya_okuyucu.r8test` (KVKK: tabloya takma ad).
4. Kare ölçümü YALNIZ `flutter drive --profile` ile: adb `input swipe` düzeneği düşük güçlü
   SoC'de ana iş parçacığını yer, `vsync_gecikme` 150+ ms sahte takılma gösterir (HAFIZA
   2026-11-13). `adb shell dumpsys gfxinfo <paket>` Flutter karelerini tam görmez — yalnız
   yardımcı, kanıt değil; SF aralığı da kanıt değil (anayasa 8c, `FrameTiming` esas).
5. Sonuç tablosu `docs/perf/<tarih>-<paket>.md` (A ve B sütunu, fark %, son satır
   `KARAR: GEÇTİ|KALDI` + gerekçe). Ham sayılar DEVIR'e.

## Karar eşikleri

- Bir senaryoda B ortancası A'nın en kötü koşusundan da kötü VE fark > %10 VE > 3 ms, ya da
  p99 > 24 ms → KALDI. ("not" deneyimi: tek koşu karşılaştırması gürültüde yanlış alarm verir;
  bu yüzden en kötü A koşusuyla kıyas + mutlak ms payı.)
- Hız hissi paketinde (Ferrari H1/H2 vb.) eşik yok: hiçbir senaryo kötüleşmez, hedef senaryo
  ölçülebilir iyileşir.
- **En çok 2 tur:** kabul ölçümü 2 turda da kırmızıysa satıra `kullanıcı kararı` + sayılar yaz,
  birleştir (`[apk]`'sız), sıradakine geç — saatlerce ölçüm döngüsü yok.
- Ölçüm verisi bozulursa (aynı APK'da ani 2–3 kat sıçrama; "not"ta veri yeniden kurulunca oldu):
  `adb shell pm clear com.dosyaokuyucu.dosya_okuyucu.r8test`, ölçüm verisini temiz yeniden it,
  aynı APK'yı iki kez ölç (A=A) — sıçramanın veri mi kod mu olduğunu kanıtla.
- Telefon yoksa/ısınmışsa satır `cihaz bekliyor`, birleştirme `[apk]`'sız. Yapılamayan ölçüm:
  "yazıldı, cihazda doğrulanmadı" + `docs/CIHAZ_TESTI.md` maddesi.

## Test telefonu kuralları (Mi Note 10 Lite — Xiaomi, MIUI, Android 12, USB)

Ekranı arızalı; sürekli açık kalınca ısınır ("sadece ihtiyaç halinde ekranı aç"); kilit yok,
yukarı kaydırarak açılır. **Telefon aynı anda TEK ajanda / tek işte.** Diğer cihazlar (Xiaomi
13T, tablet) yalnız kullanıcı bağladığında.
- `adb devices` boşsa cihaz işi atlanır (`cihaz bekliyor`). Birden çok cihaz varsa `-s <seri>`.
- **Telefonda açık olması gerekenler (kullanıcı bir kez açar):** Geliştirici seçenekleri →
  "USB hata ayıklama", "USB üzerinden yükle", "USB hata ayıklama (Güvenlik ayarları)" (MIUI;
  ikincisi olmadan dokunuş/`input` komutları çalışmaz, MIUI bunun için Mi hesabı isteyebilir).
- **Kurulum onayı:** `adb install` ve `flutter drive` kurulumu MIUI "USB üzerinden yükle"
  penceresi açar (`com.miui.securitycenter` `AdbInstallActivity`; "Reddet" geri sayımlı). Kurulum
  komutunu arka planda başlat, ekranı uyandır, pencereyi bul ve "Yükle"ye dokun:
  `adb exec-out screencap -p > <scratchpad>/ekran.png` (Read ile bak) ya da `adb shell uiautomator dump
  /sdcard/ui.xml && adb pull /sdcard/ui.xml` (ROM istisna basar ama dosyayı yazar; UTF-8 oku) →
  düğmenin `bounds` merkezine `adb shell input tap <x> <y>`. HAFIZA'daki (310,2040) bu cihazda
  ölçülmüş değerdir; koordinatı her seferinde ekrandan doğrula (yön/klavye/ROM değişebilir).
- **Ekran yalnız gerekince:** `adb shell input keyevent KEYCODE_WAKEUP` → `adb shell input swipe
  540 1800 540 600` (kilit kaydırması); iş bitince `adb shell input keyevent KEYCODE_SLEEP`.
  Derleme beklerken ekran KAPALI. Ekran ~30 sn'de kararır: uyandırma ile dokunuşları aynı
  komutta gönder. Kalıcı ayar değiştirme; TEK istisna: `flutter drive` koşusu sırasında ekran
  uyursa sürücü kopar ("Service connection disposed") → yalnız koşu süresince
  `adb shell svc power stayon true`, biter bitmez `svc power stayon false` + `KEYCODE_SLEEP`.
- **Isı:** ölçümden önce ve uzun işte 10 dk'da bir `adb shell dumpsys battery | grep
  temperature` (onda bir °C). Ölçüm başlatma < 370 (37 °C). **≥ 400 (40 °C): işi durdur, ekranı
  kapat, soğumasını bekle** (en çok 30 dk; hâlâ sıcaksa `cihaz bekliyor`, o koşu GEÇERSİZ).
- **Sürüm düşürme:** `adb install -r -d <apk>` yalnız debuggable/profil derlemesinde işe yarar;
  yayın APK'sında `INSTALL_FAILED_VERSION_DOWNGRADE` geçmez. Kaldır-kur yalnız `.r8test`
  kimliğinde (veri gider); varsayılan kimlikte ASLA.
- MIUI'de `am kill` süreci öldürmez → `am force-stop <paket>`. `flutter drive` sonrası `.r8test`
  kalkabilir: `pm list packages` ile kontrol et.
- Okuma için ekran görüntüsü yerine `uiautomator dump` (başlık metni, durum yazısı ucuz gelir);
  ölçüm koşusu SIRASINDA dump alma (semantiği açar, kareyi bozar).
- Cihaz turu (Cihaz = `evet`): nightly APK'yı (CI imzalı, telefondakiyle aynı imza)
  `gh release download nightly -p dosya-okuyucu.apk -D <scratch>` ile al, `adb install -r` (onay
  penceresi yukarıdaki gibi). Sonuç `docs/CIHAZ_TESTI.md` koşu kaydı biçiminde
  (`- <tarih> · Mi Note 10 Lite · <sürüm> · <madde> ✔/✘ …`). Google/Drive girişi isteyen madde
  "denenmedi". Telefondaki test kopyalarını (`/sdcard/Download/PdfPro/` vb.) iş bitince sil.
- Python heredoc'ta `\b` geri silmeye döner (regex bozulur); `python -` heredoc'suz REPL açar.
  Git Bash'te `/sdcard` yolları için `export MSYS_NO_PATHCONV=1`.
