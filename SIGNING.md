# APK İmzalama (sabit anahtar = kolay güncelleme)

Android, bir uygulamanın **güncellenebilmesi** için yeni APK'nın önceki kurulumla
**aynı imzaya** sahip olmasını şart koşar. Bu proje, tüm sürümleri **tek ve sabit**
bir anahtarla imzalar; böylece güncellemeler kaldırmadan üstüne kurulur.

Güvenlik için imza anahtarı **repoda tutulmaz**; GitHub **secret** olarak saklanır.

## Kalıcı imzayı etkinleştirme (bir kerelik, ~2 dk)

1. Actions sekmesinde en son **APK Derle & Release** çalışmasını açın.
2. **"İmza anahtarını hazırla"** adımının loglarına bakın. Secret henüz yoksa
   iş akışı otomatik bir anahtar üretir ve şu bloğu yazdırır:
   ```
   ========== ANDROID_KEYSTORE_B64 (kopyala) ==========
   <uzun base64 metni>
   ====================================================
   ```
   Bu base64 metnini (satırlar arası) **kopyalayın**.
3. Repo → **Settings → Secrets and variables → Actions → New repository secret**.
4. **Name:** `ANDROID_KEYSTORE_B64`  •  **Secret:** kopyaladığınız base64.  **Add secret.**
5. Bitti. Bundan sonraki tüm derlemeler **aynı** anahtarla imzalanır → sorunsuz güncelleme.

> Secret eklenene kadar her build kendi geçici anahtarını üretir (sürümler arası
> imza değişebilir). Gerçek kullanıcılara dağıtmadan önce yukarıdaki adımı yapın.

## Anahtar parmak izi (fingerprint)
Her CI çalışmasında **"APK'yı imzala ve doğrula"** adımı, imza sertifikasının
SHA-1/SHA-256 değerini loglar. Google ile giriş (Firebase) için bu SHA-1'i
Firebase Console → Project settings → Your apps bölümüne ekleyin.

## Parola
Keystore parolası iş akışında sabittir (`DosyaOkuyucuKey2026`). Daha yüksek
güvenlik isterseniz parolayı da secret yapıp workflow'da `${{ secrets.* }}`
ile okutabilirsiniz.

## Önemli
`ANDROID_KEYSTORE_B64` secret'ını (ve base64'ün çözümü olan keystore'u) güvenli
bir yerde **yedekleyin**. Kaybolursa aynı imzayla güncelleme yapılamaz; kullanıcıların
uygulamayı kaldırıp yeniden kurması gerekir.
