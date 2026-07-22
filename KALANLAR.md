# KALANLAR — canlı kalan-iş listesi (biten madde silinir)

## Yarım kalan
- [ ] Build 53 cihaz doğrulaması (kullanıcı): WhatsApp/"birlikte aç" listesinde
      görünme, odak-noktalı pinch (sayfa kaybolmamalı), Word tam sayfa sığdırma,
      eski .doc/.xls/.ppt açma, Excel formül+satır/sütun, arama, yeni belge,
      slayt çoğalt/sil/taşı, slayt yazı sığdırma (2026-07-22)
- [ ] Build 54 (yalnız CI hızlandırma) sonucu kontrol edilecek — kapanıştan
      sonra push'landı, izlenmedi (2026-07-22)

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
