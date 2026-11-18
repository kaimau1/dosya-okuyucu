# DEVIR — B1 dilim: ses/video (dal faz-oto-B1-duzen2)
- Yapılan: Files API (`GeminiService.uploadFile/deleteFile`), `SmartSortInput` audio/video türü,
  `prepare` (≤14 MB satır içi izolatta base64, üstü Files API, anahtar başına), `avBlock` (video:
  media_resolution low + video_metadata 0s–60s), taksonomi `audio`/`video` (sabit kategori, alt tür,
  dil, kalite; video yanlışlıkla → Ayıkla), SmartRecord `lg`/`ql`, l10n, Ayıkla video hücresi.
- Sıradaki: birim testleri (istek gövdesi, Files API sahte ağ, şema, yanıt→kayıt), eski testlerde
  mp3/mp4 → null beklentisi güncellenmeli; PLAN/HAFIZA/CIHAZ_TESTI; DEVIR sil; [skip ci]'siz push.
