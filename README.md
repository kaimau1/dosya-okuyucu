# Dosya Okuyucu

Sade, hızlı ve efektif **çok formatlı dosya okuyucu/düzenleyici** — hem mobil hem
masaüstünde tek Flutter kod tabanı ile. Gemini yapay zeka entegrasyonu, dönüştürme
ve paylaşım özellikleriyle.

## Özellikler

- 🗂️ **Dosya yöneticisi:** telefondaki tüm dosyalar — depolama panosu (doluluk,
  kategoriler, bellek analizi), klasör gezgini, çoklu seçim, kopyala/kes/yapıştır,
  taşı, yeniden adlandır, sil (geri dönüşüm kutusu), paylaş, sıkıştır (.zip),
  favoriler, gizli dosyalar, sıralama, ızgara/liste, özyinelemeli arama
- 🗜️ **Arşivler:** RAR4/RAR5, 7z, ZIP, TAR/GZIP — içeriği çıkarmadan listeleme,
  arşiv içinde arama, tek dosya önizleme/çıkarma, parola korumalı ve çok parçalı
  (part2/r00/7z.002) arşivler; hepsi cihazda, saf Dart, internet yok
- 📄 **Görüntüleme:** PDF, Word (.docx), Excel (.xlsx), Slayt (.pptx), metin ve görsel
- ✏️ **Düzenleme:** Metin/Word içeriğini düzenleme ve kaydetme
- 🔄 **Dönüştürme:** İçeriği PDF’e veya slayt destesine (PDF) çevirme
- 📤 **Paylaşım & Yazdırma:** Dosyaları paylaşma ve yazdırma
- 🤖 **Gemini AI:** Açık dosyaya erişimli sohbet, özet/analiz, kalıcı hafıza (RAG-lite)
- 🎨 Açık/Koyu tema, son açılan dosyalar

## Yol haritası (sonraki sürümler)

- 🔐 Firebase giriş (Google/e-posta) + bulut senkron (build 2)
- 📝 Word/Excel/Slayt için tam düzenleme & özgün formata geri yazma
- 🔁 Formatlar arası zengin dönüşüm (PDF↔Word↔Slayt)
- 📚 AI’ın PDF’lerden otomatik slayt üretmesi (genişletilmiş)

## Yapay zeka anahtarı

Ayarlar → **Gemini API anahtarı** alanına kendi anahtarınızı girin
([aistudio.google.com](https://aistudio.google.com) üzerinden ücretsiz).

## Derleme (CI)

`.github/workflows/build-apk.yml`, her push’ta:

1. Flutter kurar, `flutter create` ile Android platform iskeletini üretir
2. `flutter build apk --release` ile APK derler
3. APK’yı **artifact** olarak yükler ve **GitHub Release** oluşturur

## Yerel geliştirme

```bash
flutter create --org com.dosyaokuyucu --project-name dosya_okuyucu --platforms=android,ios .
flutter pub get
flutter run
```

> Not: `android/`, `ios/` vb. platform klasörleri sürüm kontrolüne dahil değildir;
> `flutter create` ile üretilir (bkz. `.gitignore`).
