# Google Drive girişini çalışır hâle getirme

**Bu bir kod hatası değil, bir kayıt işlemidir.** Google, Android'de hesap
girişini "hangi uygulama soruyor?" sorusunu **paket adı + APK'nın imza parmak
izi (SHA-1)** ikilisiyle cevaplayarak veriyor. Bu ikili Google Cloud'da kayıtlı
değilse Play Services girişi `ApiException: 10` (DEVELOPER_ERROR) ile reddeder —
uygulama ne yaparsa yapsın. Uygulamada görülen belirti:

> Google girişi bu APK için etkinleştirilmemiş…

Kayıt yapılmadan da Drive'a ulaşmanın **çalışan** bir yolu var ve uygulama onu
Drive ekranında düğme olarak sunuyor: *"Sistem seçicisiyle Drive dosyası aç"*.
O yol Android'in Depolama Erişim Çerçevesini kullanır ve hiçbir yetki istemez.
Aşağıdaki adımlar uygulama içi Drive **gezgini** (klasörlerde dolaşma, klasör
oluşturma, yükleme, yeniden adlandırma, silme) içindir.

> ### Kapsam: tam erişim — bedeliyle birlikte
> Uygulama 2026-08-05'ten beri `.../auth/drive` (tam Drive) kapsamını istiyor;
> önceki `drive.file` yalnız uygulamanın kendi yüklediklerini gösteriyordu.
> **Tam kapsam Google'ın *restricted* kapsamı:** OAuth izin ekranı **Test**
> modundayken ücretsiz çalışır (en fazla 100 test kullanıcısı, e-postaları elle
> eklenir). Uygulamayı **yayınlamak** (Play Store / herkese açık) için Google
> yıllık ve **ücretli** üçüncü taraf güvenlik denetimi (CASA) şart koşuyor.
> Play Store hedefi bu kapsamla birlikte yeniden değerlendirilmeli.

## Gereken iki değer

| Değer | |
| --- | --- |
| Paket adı | `com.dosyaokuyucu.dosya_okuyucu` |
| İmza SHA-1 | `F5:5D:0C:09:9F:97:71:3B:7A:1B:8D:B7:E8:6D:6A:0A:DA:EE:9D:B5` |

Bu SHA-1, CI'ın kalıcı imza anahtarına aittir (build 219 logundan doğrulandı;
`ANDROID_KEYSTORE_B64` secret'ı ekli olduğu için **tüm derlemelerde aynıdır**).
En kolay yol yine de uygulamanın kendisi: Drive ekranında giriş
"etkinleştirilmemiş" hatası verdiğinde açılan **kurulum kartı** iki değeri de
kopyala düğmesiyle gösterir — üstelik SHA-1'i kurulu APK'nın kendi imzasından
okur, yani her zaman doğrudur.

SHA-1'i elle de alabilirsiniz:

```
keytool -printcert -jarfile dosya-okuyucu.apk
```

> **Not:** SHA-1 imza anahtarına bağlıdır. `ANDROID_KEYSTORE_B64` secret'ı
> tanımlı olduğu sürece her derleme aynı anahtarla imzalanır ve yukarıdaki
> değer geçerli kalır. Secret silinirse CI her koşuda geçici anahtar üretir →
> SHA-1 değişir ve kayıt geçersiz olur.

## Konsolda neresi? (yeni "Google Auth Platform" arayüzü)

Google eski tek sayfalık **OAuth izin ekranı**nı alt başlıklara böldü; eski
adlarla arayan kaybolur. Karşılıklar:

| Ne yapacaksınız | Yeni menü | Doğrudan bağlantı |
| --- | --- | --- |
| Drive API'yi açmak | **API'ler ve Hizmetler → Kitaplık** (Auth Platform'da DEĞİL) | <https://console.cloud.google.com/apis/library/drive.googleapis.com> |
| **Kapsam** eklemek | Google Auth Platform → **Data Access** | <https://console.cloud.google.com/auth/scopes> |
| **Test kullanıcısı** + yayın durumu | Google Auth Platform → **Audience** | <https://console.cloud.google.com/auth/audience> |
| Android istemcisi (paket adı + SHA-1) | Google Auth Platform → **Clients** | <https://console.cloud.google.com/auth/clients> |
| Uygulama adı / destek e-postası | Google Auth Platform → **Branding** | — |

## Adımlar

1. <https://console.cloud.google.com/> → yeni proje (ya da mevcut proje).
2. **API'ler ve Hizmetler → Kitaplık** → *Google Drive API* → **Etkinleştir**.
   Bu adım atlanırsa giriş çalışır ama HER çağrı 403 döner — en sık yapılan
   hata bu (uygulama artık bunu ayırt edip söylüyor).
3. **Data Access** → *Add or remove scopes* →
   `https://www.googleapis.com/auth/drive` eklenir ve **Update/Save** denir.
   Yalnız `drive.file` YETMEZ: gezgin bütün klasörleri listeler. Google bunu
   "kısıtlı" diye işaretler — Test modunda sorun değil.
4. **Audience**:
   - Kullanıcı türü *Harici (External)*.
   - Yayın durumu ***Testing* bırakılmalı**; *Publish* derseniz Google
     doğrulama + ücretli CASA denetimi ister (bkz. yukarıdaki kutu).
   - **Test users** bölümüne kendi Gmail adresinizi ekleyin (en fazla 100).
     Listede olmayan hesap, hesap seçer seçmez pencereden düşer.
5. **Clients → Create client**:
   - Uygulama türü: **Android**
   - Paket adı: `com.dosyaokuyucu.dosya_okuyucu`
   - SHA-1: `F5:5D:0C:09:9F:97:71:3B:7A:1B:8D:B7:E8:6D:6A:0A:DA:EE:9D:B5`
     (ya da uygulamadaki kurulum kartından kopyalayın)
6. Kaydedin. Değişikliğin yayılması birkaç dakika sürebilir.

`google-services.json` indirmeye **gerek yok**: Android'de `google_sign_in`
istemciyi paket adı + SHA-1 üzerinden bulur, dosyadan değil. (Firebase senkronu
ayrı bir konu; o `google-services.json` ister ve yoksa uygulama yerel modda
çalışır.)

## Doğrulama

Uygulama → Drive → **Google ile bağlan**. Hesap penceresi açılıp Drive'ınızın
klasörleri geliyorsa tamam.

## Sorun giderme

Uygulama hatayı artık sınıflandırıp **ne yapılacağını** yazıyor; ayrıca
Google'ın kendi mesajını seçilebilir metin olarak gösteriyor (bildirirken onu
kopyalayın). Sık görülenler:

| Ekranda | Anlamı ve çözümü |
| --- | --- |
| "Google girişi bu APK için etkinleştirilmemiş" | Paket adı + SHA-1 kayıtlı değil → adım 4 |
| "Google Drive API bu projede etkin değil" | **Adım 2 atlanmış** → Kitaplık'tan Drive API'yi açın |
| "Hesap bağlandı ama Drive izni verilmemiş" | Jeton eski/dar kapsamlı → uygulamada **Bağlantıyı kes**, sonra yeniden bağlanın ve izin penceresini onaylayın |
| Giriş açılıyor ama hesap seçilince kapanıyor | Hesabınız **test kullanıcıları** listesinde değil → adım 3 |

> **Kapsam büyütüldüğünde yeniden izin şart.** Uygulama daha önce `drive.file`
> ile bağlandıysa elinizdeki jeton dar kapsamlıdır ve yeni sürümde 403 verir.
> Bir kez **Bağlantıyı kes → Google ile bağlan** yapmak yeterli.
