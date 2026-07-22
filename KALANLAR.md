# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] Build 48 cihaz doğrulaması: slayt yazı sığdırma (autofit), Word açılış
      ölçeği/görseller, ikon geri geldi mi, zoom-out serbestliği (2026-07-22)

## Sonra yapılacak
- [ ] Faz 1 — Word canlı düzenleme: WebView contenteditable + JS köprüsü → `w:t`
      geri yazımı; kullanıcı kararı gereği B/I/U biçim çubuğu İLK sürümde dahil (2026-07-22)
- [ ] Faz 2 — Excel canlı hücre: hücrenin içinde yazma + üstte formül çubuğu (fx)
- [ ] Faz 3 — PPTX yerinde metin: popup/bottom-sheet yerine kutunun üstünde overlay editör

## Bilinen eksik-risk
- [ ] Excel pinch: kaydırma sürerken başlayan pinch ilk denemede tutmayabilir
      (ilk parmağın sahipliği scrollable'da kalır); cihazda rahatsız ederse iyileştirilecek
- [ ] Word'de zoom % rozeti yok (native WebView zoom ölçeği Flutter'a bildirmiyor);
      istenirse visualViewport JS köprüsü
- [ ] Koyu temada Word WebView kanvası açık kalıyor (sayfa zaten beyaz; bilinçli erteleme)
