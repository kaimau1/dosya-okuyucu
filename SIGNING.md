# APK İmzalama (sabit anahtar = kolay güncelleme)

Android, bir uygulamanın **güncellenebilmesi** için yeni APK'nın önceki kurulumla
**aynı imzaya** sahip olmasını şart koşar. Bu proje, tüm sürümleri **tek ve sabit**
bir anahtarla imzalar; böylece güncellemeler kaldırmadan üstüne kurulur.

Güvenlik için imza anahtarı **repoda tutulmaz**; GitHub **secret** olarak saklanır.

## Kalıcı imzayı etkinleştirme (bir kerelik, ~3 dk)

> **2026-08-28 DEĞİŞİKLİK — anahtar artık CI logunda ÜRETİLMİYOR/BASILMIYOR.**
> Eskiden secret yoksa iş akışı bir anahtar üretip base64'ünü loga yazdırıyordu.
> Depo public olduğu için o logu gören herkes uygulamayı **bizim imzamızla**
> güncelleyebilirdi (sahte güncelleme = kullanıcının cihazında bizim adımıza
> kod çalıştırma). Anahtar artık **yerelde** üretilir; CI'daki geçici anahtar
> yalnız o derlemeyi imzalar ve dışarı çıkmaz.

Anahtarı **kendi bilgisayarınızda** üretin (JDK ile gelen `keytool`):

```bash
keytool -genkeypair -v -keystore release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias dosyaokuyucu \
  -dname "CN=Dosya Okuyucu, O=DosyaOkuyucu, C=TR"
# parola sorulacak — GÜÇLÜ bir parola girin ve parola yöneticinize kaydedin
base64 -w0 release.jks > release.jks.b64   # macOS: base64 -i release.jks -o release.jks.b64
```

Sonra repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret adı | Değer |
|---|---|
| `ANDROID_KEYSTORE_B64` | `release.jks.b64` dosyasının içeriği |
| `ANDROID_KEYSTORE_PASSWORD` | yukarıda girdiğiniz parola |

Bitti — bundan sonraki tüm derlemeler aynı anahtarla imzalanır.

> Secret'lar eklenene kadar her build **geçici** bir anahtar üretir: APK kurulur
> ama bir sonraki sürüm "imza uyuşmuyor" der. Gerçek kullanıcılara dağıtmadan
> önce yukarıdaki adımı yapın.

**`release.jks` ve `release.jks.b64` dosyalarını depoya KOYMAYIN** (`.gitignore`
`*.jks`'i kapsar); şifreli bir yedekte saklayın.

## Anahtar parmak izi (fingerprint)
Her CI çalışmasında **"APK'yı imzala ve doğrula"** adımı, imza sertifikasının
SHA-1/SHA-256 değerini loglar. Google ile giriş (Firebase) için bu SHA-1'i
Firebase Console → Project settings → Your apps bölümüne ekleyin.

## Parola
Keystore parolası **`ANDROID_KEYSTORE_PASSWORD` secret'ında** tutulur; workflow'da
düz metin parola yoktur (repo 2026-07-23'te public yapıldı). Secret tanımlı değilse
CI geçici bir anahtar üretir ve yayınlanan APK kalıcı imzayı taşımaz.

> Geçmiş: 2026-07-23 öncesinde parola workflow'da düz metin sabitti. Repo public
> yapılmadan önce keystore parolası **değiştirildi** (sertifika/parmak izi aynı
> kaldı), böylece git geçmişinde görünen eski parola işe yaramaz.

## Önemli
`ANDROID_KEYSTORE_B64` secret'ını (ve base64'ün çözümü olan keystore'u) güvenli
bir yerde **yedekleyin**. Kaybolursa aynı imzayla güncelleme yapılamaz; kullanıcıların
uygulamayı kaldırıp yeniden kurması gerekir.

## Sürüm numarası (versionCode)

`pubspec.yaml`taki `version: 0.1.0+1` **sabit bırakıldı**; gerçek numara CI'da
`--build-number=${{ github.run_number }}` ile veriliyor (2026-08-28). Yani her
derleme bir öncekinden büyük bir `versionCode` taşır — Android/Play güncellemeyi
ancak bu artarsa kabul eder. Yayınlanan Release etiketiyle (`v0.1.0-build-<n>`)
aynı sayıdır, böylece bir APK'nın hangi koşudan geldiği tek bakışta bellidir.

`--split-per-abi` kullandığımız için Flutter'ın Gradle eklentisi her mimariye
`abi*1000 + numara` biçiminde AYRI bir versionCode verir; armeabi ve arm64
APK'ları birbirini ezmez (Play çoklu APK kuralı da bunu ister).
