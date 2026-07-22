# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] Build 48 cihaz doğrulaması: slayt yazı sığdırma (autofit), Word açılış
      ölçeği/görseller, ikon geri geldi mi, zoom-out serbestliği (2026-07-22)

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
