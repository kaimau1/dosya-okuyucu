# Firebase Kurulumu (bulut giriş + senkron)

Uygulama, Firebase yapılandırılmadan **yerel modda** sorunsuz çalışır.
Bulut giriş (Google/e-posta) ve cihazlar arası senkronu etkinleştirmek için
aşağıdaki adımları bir kez uygulaman yeterli.

## 1. Firebase projesi oluştur
1. https://console.firebase.google.com → **Add project**
2. Projeyi oluştur (Analytics opsiyonel).

## 2. FlutterFire CLI ile bağla (önerilen)
Yerel geliştirme makinende:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<FIREBASE_PROJECT_ID>
```

Bu komut:
- `android/app/google-services.json` dosyasını indirir,
- `lib/firebase_options.dart` üretir,
- gerekli Gradle eklentilerini ekler.

> `main.dart` içindeki `Firebase.initializeApp()` çağrısı, `firebase_options.dart`
> üretildikten sonra otomatik olarak onu kullanacak şekilde güncellenebilir:
> `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

## 3. Kimlik doğrulama sağlayıcılarını aç
Firebase Console → **Authentication → Sign-in method**:
- **E-posta/Parola**’yı etkinleştir.
- **Google**’ı etkinleştir (Google ile giriş için).
  - Android için SHA-1/SHA-256 parmak izlerini **Project settings → Your apps**
    bölümüne ekle (`./gradlew signingReport` ile alınır).

## 4. Firestore’u aç
Firebase Console → **Firestore Database → Create database** (production/test mode).

Örnek güvenlik kuralları (kullanıcı yalnızca kendi verisine erişir):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 5. CI (GitHub Actions) için
CI’da APK `flutter create` ile üretildiğinden Firebase config gizli tutulabilir:
- `google-services.json` içeriğini **repo secret** olarak sakla,
- workflow’da build öncesi dosyaya yaz (bu repo’da isteğe bağlı bırakılmıştır).

Config eklenmezse CI derlemesi yine başarılı olur; APK yalnızca yerel modda çalışır.

## Veri modeli
`users/{uid}` dokümanı:
- `recents`: son açılan dosyalar (path, name, sizeBytes, openedAtMs)
- `memory`: AI kalıcı hafıza notları
- `updatedAt`: sunucu zaman damgası
