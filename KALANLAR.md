# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] Build 53 cihaz doğrulaması (kullanıcı): WhatsApp/"birlikte aç" listesinde
      görünme, odak-noktalı pinch (sayfa kaybolmamalı), Word tam sayfa sığdırma,
      eski .doc/.xls/.ppt açma, Excel formül+satır/sütun, arama, yeni belge,
      slayt çoğalt/sil/taşı, slayt yazı sığdırma (2026-07-22)
- [ ] Build 54 (yalnız CI hızlandırma) sonucu kontrol edilecek — kapanıştan
      sonra push'landı, izlenmedi (2026-07-22)
- [ ] Cihaz doğrulaması bekleyen 3 özellik (APK alınmadı, Actions kotası):
      PDF seçim tutamaçları, slaytta yerinde metin düzenleme, Excel hücre içi
      yazma (2026-07-23)

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
