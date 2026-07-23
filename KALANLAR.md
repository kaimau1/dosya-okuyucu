# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] **Cihaz doğrulaması (kullanıcı)** — 2026-07-23 14:30'da yerel derleme telefona
      kuruldu, içindekiler test edilmedi: Excel hücre içi yazma (seçili hücreye
      ikinci dokunuş), slaytta yerinde metin düzenleme, PDF seçim tutamaçları,
      Gemini model listesinin Ayarlar'da otomatik dolması. Ayrıca eski liste:
      WhatsApp "birlikte aç", odak-noktalı pinch, Word tam sayfa sığdırma,
      eski .doc/.xls/.ppt açma, arama, yeni belge, slayt çoğalt/sil/taşı.
- [ ] **CI kotası:** Actions dakikası bitti → APK/Release işleri saniyeler içinde
      log'suz düşüyor (build 62'den beri yeni Release YOK). Karar bekliyor:
      kotayı bekle / repo'yu public yap (önce keystore parolasını secret'a taşı)
      / harcama limitini artır. Geliştirme bu arada yerel derlemeyle sürüyor.

## Sonra yapılacak
- [ ] Excel: dondurulmuş bölme (frozen pane) desteği — kullanıcının SAHU dosyasında var,
      şu an yok sayılıyor (tek parça kaydırma)
- [ ] Yol haritası #2: Firebase config + gerçek senkron (kullanıcı `flutterfire configure`)

## Bilinen eksik-risk
- [ ] Word canlı düzenleme: paragraf eşlemesi indeks tabanlı (DOM `article p` ↔ `w:p`);
      sayı uyuşmazsa sigorta düzenlemeyi kapatıp metin düzenleyiciye yönlendirir.
      Metin kutusu/köprü içeren belgelerde cihazda doğrulanmalı (2026-07-22)
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Word'de zoom % rozeti yok (native WebView zoom ölçeği Flutter'a bildirmiyor);
      istenirse visualViewport JS köprüsü
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)
