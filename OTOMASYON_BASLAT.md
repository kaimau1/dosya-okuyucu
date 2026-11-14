# Otomasyonu başlatma rehberi (başka bir Claude hesabında)

"not" projesinde kullanılan gözetimsiz zincirin (yürütücü/işçi, Kuyruk, limit freni, cihaz A/B,
kasma kontrolü, zamanlanmış görev) dosya okuyucu kopyası. Bu belge, başka bir Claude hesabında
zinciri sıfırdan çalıştırmak için adım adım rehberdir. Kurallar dosyalarda; burada yalnız kurulum.

**Zincirin parçaları (hepsi depoda):**

| Dosya | Ne |
|---|---|
| `CLAUDE.md` §4 "İSTİSNA — Gözetimsiz zincir", §4b, §4c | dal istisnası, gece kuralı, kasma/hız kapıları |
| `OTOMASYON.md` | Kuyruk tablosu, durum sözlüğü, SIRA, FABLE KURALI |
| `.claude/skills/oto-tur/SKILL.md` | yürütücü turu (kilit, limit freni, birleştirme, temizlik, bitiriş) |
| `.claude/skills/isci/SKILL.md` | alt ajan kuralları (dal, DEVIR.md, kanıt→düzelt→kanıt, CI) |
| `.claude/skills/ab-olcum/SKILL.md` | cihaz A/B ölçümü + test telefonu kuralları |
| `.claude/skills/kasma-kontrol/SKILL.md` | görünür arayüz değişikliğinde 8 maddelik kasma listesi |
| `.claude/settings.json` | oturum başında `git pull --rebase --autostash` kancası (zaten vardı) |

---

## (a) Depoyu aç / klonla

- Aynı bilgisayarsa: depo zaten `C:\Users\sena\Desktop\dosya okuyucu`. Bir terminalde
  `git checkout main && git pull --ff-only`.
- Başka bilgisayarsa: `git clone https://github.com/kaimau1/dosya-okuyucu.git "dosya okuyucu"`.
  Ayrıca gerekenler: Flutter **3.47.9** `C:\src\flutter-3479` (CI ile aynı; PATH'e eklemek
  gerekmez, skill'ler tam yolu kullanır), Android SDK platform-tools (`adb`), Java 17,
  Python 3, Git Bash, GitHub CLI.
- GitHub: `gh auth status` "Logged in" demeli ve hesabın depoya YAZMA izni olmalı (yoksa
  `gh auth login`). Zincir `gh run list/watch/view` ile CI'ı izler, `git push` ile gönderir.
- **İmza anahtarı / `key.properties` / `*.jks` depoya girmez** ve zincirin bunlara ihtiyacı yok
  (APK'yı CI imzalar; GitHub Secrets'ta). Yerel ölçüm derlemesi ayrı kimlikle (`.r8test`) yerel
  hata ayıklama imzasıyla kurulur.

## (b) Claude Code masaüstünde klasörü aç, izin kipi

1. Claude Code masaüstü uygulamasında yeni oturum → klasör: `C:\Users\sena\Desktop\dosya okuyucu`.
2. İzin kipi: **"Bypass permissions" (izinleri atla)** önerilir — gözetimsiz turda her onay
   penceresi turu kilitler. Daha temkinli istersen "Accept edits" + sık kullanılan komutlara izin
   (git, gh, adb, bash betikleri, flutter.bat); ama o zaman gece takılabilir.
   **Önemli:** izin kipi yalnız masaüstünden SENİN yazdığın turda kaydedilir; ilk turu elle başlat.
3. Bu projede kullanılan global araçlar (`CLAUDE.md`'den):
   - **graphify**: proje `graphify-out/` kullanır, güncelleme elle `graphify update .`. Zincir
     graphify'ı AÇMAZ (token); diğer hesapta graphify skill'i yoksa sorun değil.
   - **RTK** (bash token vekili): proje `CLAUDE.md`'si kullanmaz; yalnız eski hesabın global
     ayarıydı. Diğer hesapta kurmak gerekmez.
   - Gerekli MCP/araçlar: masaüstü uygulamasının kendi araçları (`Agent`, zamanlanmış görevler,
     `mcp__ccd_session_mgmt__get_usage` — limit freni bunu okur; yoksa fren "unavailable" yazar
     ve frensiz sürer). GitHub MCP isteğe bağlı (`gh` yeterli).
4. Hesap modelleri: Kuyruk'ta `fable`/`opus`/`sonnet`. Hesapta Fable yoksa yürütücü Opus kullanır
   (FABLE KURALI). Hesap planı (Pro/Max) limit freni eşiklerini değiştirmez (%80/%90).

## (c) Zamanlanmış görev: `okuyucu-devam`

- **Ad:** `okuyucu-devam` · **Sıklık:** saatlik, her saat :55 (cron `55 * * * *`). Limit dolunca
  oturum ölür; sonraki tetik kilide bakıp kaldığı yerden sürer. Bilgisayar uykudaysa görev
  çalışmaz (bu dizüstünde uyku interneti de keser) — gece için uykuyu kapat ya da prize tak.
- **Oluşturma:** masaüstü uygulamasında "Zamanlanmış görevler" bölümünden yeni görev, ya da
  oturumda Claude'a "aşağıdaki istemle `okuyucu-devam` adlı saatlik zamanlanmış görev oluştur"
  de. Görevi SEN oradayken aç (gözetimsiz oturum görev açarken onay ister; "not"ta bu yüzden
  gece devam görevi açılamadı ve iş kesildi). Görevin çalışma klasörü bu depo; model Opus;
  ayarlarda izin kipi varsa "Bypass permissions".
- **Görev isteminin TAM metni** (olduğu gibi yapıştır):

```
Depo: C:\Users\sena\Desktop\dosya okuyucu (Flutter dosya okuyucu, yalnız Android).

1. `.git/oto.lock` dosyasının son değişimi 60 dakikadan yeniyse başka yürütücü çalışıyor demektir: hiçbir şey yapmadan bitir. OTOMASYON.md Kuyruk'ta `bekliyor`/`sürüyor`/`cihaz bekliyor` satır kalmadıysa da hiçbir şey yapmadan bitir.
2. Değilse: `git checkout main && git pull --ff-only`, sonra `oto-tur` skill'ini uygula (kilit, limit freni, paket seçimi, alt ajanlar, birleştirme, temizlik, bitiriş orada). Alt ajanlara `isci` skill'ini kullanmalarını ve raporu Türkçe yazmalarını söyle; cihaz A/B ölçümü ve cihaz turu `ab-olcum` skill'iyle Sonnet alt ajana. Görünür arayüz değişikliğinde işçi `kasma-kontrol` skill'ini uygular.
3. Fable kuralı: limit yenilenince ilk Fable başlar ama yalnız önemli karar/plan evresini yapar; uygulama, test, CI ve belge Opus alt ajanlarına. Fable paketi yalnız 5 saatlik limit %55 altındayken başlar; hesapta Fable yoksa Opus. Limit freni: %80 üstü yeni paket yok, %90 üstü dur.
4. Kullanıcı izni: gözetimsiz çalış, soru sorma; plan KARAR maddelerini sormadan uygula (yeni karar → en güvenli + "sabah bakılacak"); USB'deki test telefonunu `ab-olcum` kurallarıyla kullan (ekran yalnız gerekince, 40 °C üstünde dur, varsayılan kimlikli uygulamaya dokunma). Zincir dalı `faz-oto-<no>-<ad>`; CI yeşilse yerelde `git merge --no-ff` ile main'e birleştir ve push et (APK noktasında başlıkta `[apk]`, gövdede `Yeni:/İyileştirme:/Düzeltme:` satırları). CI kırmızıyken ASLA birleştirme. Birleştirmeden sonra `git grep -nE "^(<<<<<<<|>>>>>>>)"` boş olmalı.
5. Bitirirken: kendi arka plan görevlerini durdur, telefon ekranını kapat (`adb shell input keyevent KEYCODE_SLEEP`), kilidi sil, 5 satırlık Türkçe özet yaz (ne birleşti, ne takıldı, limit ve yenilenme saati, cihaz bekleyenler, sabah bakılacaklar).
```

## (d) Kullanıcı tercih hafızası (diğer hesapta ilk oturumda)

Tercihler projeler arası `.claude memory/`'de durur; yeni hesapta boştur. İlk oturumda Claude'a
"şu tercihleri hafızana yaz" diyerek aşağıdakini ver (proje bilgisi değil, çalışma tercihi):

```
- Kullanıcıya giden her metin Türkçe (ara mesaj, özet, rapor; alt ajan raporu İngilizce gelse bile Türkçe aktar).
- Token tasarrufu: az ve toplu araç çağrısı; büyük dosyayı bir kez oku, çıktıyı kes; yürütücü ince, iş alt ajanda; paketler büyük.
- Limit: 5 saatlik limit %80'e dek tur sürer (iş varken boş bırakma), %80 üstü yeni paket yok, %90 dur. Aynı anda en çok 2 paket alt ajanı (dosyaları çakışmayan).
- Fable yalnız karar/plan evresinde ve limit %55 altındayken; uygulama Opus'ta. Limit yenilenince eski uzun alt ajanı SendMessage ile diriltme (bütün geçmişi yeniden gönderir); DEVIR.md'den yeni ajan aç.
- Cihaz kabul ölçümü en çok 2 tur; sonra "kullanıcı kararı" yazıp ilerle.
- Test telefonu (Mi Note 10 Lite) ekranı arızalı, ısınır: ekranı yalnız gerekince aç, iş bitince KEYCODE_SLEEP; kalıcı ayar değiştirme.
- Ölçmeden "hızlı/akıcı/düzeldi" deme; arayüze dokunan işten sonra cihazda A/B ölç; hız işinde kötüleşme kabul edilmez.
- Planlar kendi başına okunabilir yazılır (dosya yolu, kanıt, kabul ölçütü, "en güvenli" seçenek); basite kaçma, kök neden.
- Tasarım değişikliğinden önce geçmiş kullanıcı isteklerini ara; eski açık istekleri geri alma.
- Devam görevi (zamanlanmış görev) gece başlamadan, kullanıcı oradayken açılır.
```

Kişisel veri, e-posta, parola, anahtar YAZMA (bu listede de yok).

## (e) USB test telefonu (Mi Note 10 Lite — Xiaomi, MIUI, Android 12)

Ayrıntılı kurallar: `.claude/skills/ab-olcum/SKILL.md` "Test telefonu kuralları". Senin bir kez
yapacakların:
1. Ayarlar → Telefon hakkında → "MIUI sürümü"ne 7 kez dokun (Geliştirici seçenekleri açılır).
2. Ayarlar → Ek ayarlar → Geliştirici seçenekleri: **"USB hata ayıklama"**, **"USB üzerinden
   yükle"**, **"USB hata ayıklama (Güvenlik ayarları)"** AÇIK. (Sonuncusu olmadan Claude'un
   `adb shell input tap` dokunuşları çalışmaz; MIUI bunun için Mi hesabı/SIM isteyebilir.)
3. USB ile bağla, telefonda "Bu bilgisayara her zaman izin ver" + Tamam. Bilgisayarda
   `adb devices` → seri numarası `device` görünmeli.
4. Ekran kilidi YOK kalsın (Claude yukarı kaydırarak açar). Telefonda nightly sürüm
   (`com.dosyaokuyucu.dosya_okuyucu`) kalabilir; Claude ona dokunmaz, ölçümü ayrı `.r8test`
   kimliğiyle yapar.

Claude'un yaptıkları (skill'de): her `adb install` / `flutter drive` kurulumunda MIUI "USB
üzerinden yükle" penceresini ekran görüntüsü (`adb exec-out screencap`) ya da `uiautomator dump`
ile bulup "Yükle"ye `adb shell input tap <x> <y>` ile dokunur (koordinat ekrandan; HAFIZA'daki
ölçülmüş değer ≈ (310,2040)); ekranı yalnız gerekince açar, bitince `KEYCODE_SLEEP`; pil
sıcaklığını `dumpsys battery` ile izler (ölçüm < 37 °C, ≥ 40 °C dur); sürüm düşürmede
`install -r -d` yalnız profil/hata ayıklama derlemesinde; telefonu aynı anda tek ajana verir;
ölçüm verisi bozulursa ölçüm uygulamasını temizleyip veriyi yeniden kurar.
Telefon bağlı değilse cihaz işleri `cihaz bekliyor` olur, kod işleri sürer.

## (f) İlk tur: ne olur, nasıl izlenir

1. İlk turu elle başlat (izin kipi kaydolsun): oturuma "`oto-tur` skill'ini uygula" yaz.
   İstersen önce `okuyucu-devam` görevini oluştur (c), sonra görevi "Şimdi çalıştır" ile tetikle.
2. Beklenen akış: kilit `.git/oto.lock` yazılır → main CI sağlığı (`gh run list -b main`) →
   Kuyruk'tan **P01** (ölçüm altyapısı: gözetimsiz A/B betiği — bu depoda "not"taki tek komutluk
   A/B aracı yok, ilk iş onu yazmak) Opus alt ajanına `faz-oto-P01-…` dalında verilir; paralel
   ikinci paket (SIRA'da P03 ∥ P05) dosyalar çakışmıyorsa başlar → alt ajan her commit'te push
   eder, CI'ı izler → yeşilse yürütücü main'e birleştirir → limit elverdikçe sıradaki.
3. İzleme:
   - `OTOMASYON.md` Kuyruk "Durum" sütunu (main'de; her birleştirmede güncellenir).
   - GitHub Actions: https://github.com/kaimau1/dosya-okuyucu/actions (dal `faz-oto-*` koşuları).
   - Yarım iş: dalın `DEVIR.md`'si (`git show origin/<dal>:DEVIR.md`).
   - Sabah bakılacaklar: Kuyruk satırlarında "sabah bakılacak", senin yapacakların
     `KONTROL_LISTEM.md`, telefonda bakılacaklar `docs/CIHAZ_TESTI.md`.
   - Takılırsa: `.git/oto.lock` 60 dk'dan eskiyse sonraki tetik kendiliğinden sürer; kilit
     elle silinebilir. Zinciri durdurmak için görevi duraklat.
4. APK: `[apk]` başlıklı birleştirmelerden sonra CI "nightly" sürümünü günceller
   (`releases/latest/download/dosya-okuyucu.apk`); sürüm notu commit gövdelerindeki
   `Yeni:/İyileştirme:/Düzeltme:` satırlarından otomatik.
