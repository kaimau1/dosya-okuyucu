# Google Drive girişini çalışır hâle getirme

**Bu bir kod hatası değil, bir kayıt işlemidir.** Google, Android'de hesap
girişini "hangi uygulama soruyor?" sorusunu **paket adı + APK'nın imza parmak
izi (SHA-1)** ikilisiyle cevaplayarak veriyor. Bu ikili Google Cloud'da kayıtlı
değilse Play Services girişi `ApiException: 10` (DEVELOPER_ERROR) ile reddeder —
uygulama ne yaparsa yapsın. Uygulamada görülen belirti:

> Google girişi bu APK için etkinleştirilmemiş…

Kayıt yapılmadan da Drive'a ulaşmanın **çalışan** bir yolu var ve uygulama onu
Drive ekranında düğme olarak sunuyor: *"Sistem seçicisiyle Drive dosyası aç"*.
O yol Android'in Depolama Erişim Çerçevesini kullanır, hiçbir yetki istemez ve
Drive'ın **tamamını** gezdirir. Aşağıdaki adımlar yalnızca uygulama içi Drive
listesini (yükleme + yüklenenleri listeleme) açmak isteyenler içindir.

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

## Adımlar

1. <https://console.cloud.google.com/> → yeni proje (ya da mevcut proje).
2. **API'ler ve Hizmetler → Kitaplık** → *Google Drive API* → **Etkinleştir**.
3. **API'ler ve Hizmetler → OAuth izin ekranı**:
   - Kullanıcı türü: *Harici*.
   - Uygulama adı / destek e-postası / geliştirici e-postası doldurulur.
   - **Kapsam** olarak yalnız `.../auth/drive.file` eklenir. Bu kapsam
     *restricted* değildir; ücretli CASA güvenlik denetimi **gerekmez**
     (uygulamanın "ücretsiz" ilkesi bu yüzden `drive` kapsamını istemiyor —
     bkz. `lib/services/fm/drive_service.dart` sınıf açıklaması).
   - Yayın durumu *Test* bırakılırsa yalnızca **test kullanıcıları** listesine
     eklenen Google hesapları giriş yapabilir. Kendi hesabınızı oraya ekleyin.
4. **Kimlik bilgileri → Kimlik bilgisi oluştur → OAuth istemci kimliği**:
   - Uygulama türü: **Android**
   - Paket adı: `com.dosyaokuyucu.dosya_okuyucu`
   - SHA-1: `F5:5D:0C:09:9F:97:71:3B:7A:1B:8D:B7:E8:6D:6A:0A:DA:EE:9D:B5`
     (ya da uygulamadaki kurulum kartından kopyalayın)
5. Kaydedin. Değişikliğin yayılması birkaç dakika sürebilir.

`google-services.json` indirmeye **gerek yok**: Android'de `google_sign_in`
istemciyi paket adı + SHA-1 üzerinden bulur, dosyadan değil. (Firebase senkronu
ayrı bir konu; o `google-services.json` ister ve yoksa uygulama yerel modda
çalışır.)

## Doğrulama

Uygulama → Drive → **Google ile bağlan**. Hesap penceresi açılıp liste geliyorsa
tamam. Hâlâ "etkinleştirilmemiş" diyorsa sırasıyla: SHA-1 doğru mu (imza secret'ı
ekli mi), paket adı birebir mi, OAuth izin ekranında hesabınız test kullanıcısı mı.

Sınıflandıramadığımız bir hata olursa uygulama ham platform mesajını hata
şeridinde **seçilebilir metin** olarak gösteriyor — bildirirken onu kopyalayın.
