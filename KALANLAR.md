# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] Build 51 cihaz doğrulaması: slayt dikey akış + pinch his + yazı sığdırma
      (yer tutucu), Word tam sayfa açılış + yazma akıcılığı, ikon (2026-07-22)
- [ ] Dal birleştirme (build 52) cihaz doğrulaması: eski .doc/.xls/.ppt açma,
      Excel formül sonucu + satır/sütun çubuğu, belge içi arama, "birlikte aç",
      yeni belge oluşturma, slayt çoğalt/sil/taşı (2026-07-22)

## Sonra yapılacak
- [ ] Faz 2 — Excel canlı hücre: hücrenin içinde yazma + üstte formül çubuğu (fx)
- [ ] Faz 3 — PPTX yerinde metin: popup/bottom-sheet yerine kutunun üstünde overlay editör

## Bilinen eksik-risk
- [ ] Word canlı düzenleme: paragraf eşlemesi indeks tabanlı (DOM `article p` ↔ `w:p`);
      sayı uyuşmazsa sigorta düzenlemeyi kapatıp metin düzenleyiciye yönlendirir.
      Metin kutusu/köprü içeren belgelerde cihazda doğrulanmalı (2026-07-22)
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Word'de zoom % rozeti yok (native WebView zoom ölçeği Flutter'a bildirmiyor);
      istenirse visualViewport JS köprüsü
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)
