# DEVIR — faz-oto-U6-kalan (2026-11-21, kullanıcı bilgisayarı kapattı; yarım)

## Yapılanlar
- c (ece4bdc1): Analiz'de Ayıkla satırı alt yazısı nedene göre döküm (`analysis_screen.dart` `_clutterBy`, `sm.r_*`).
- b (son commit): `appTipFor` (`installed_apps_service.dart`, saf), `CleanupIgnore.ignoreApp/clearApps/ignoredApps`
  (`cleanup_ignore_apps`), `_tipCard` (`installed_apps/views.dart`), menüde "Gizlenen {n} öneriyi geri getir", metinler `46_ui_toplu.dart`.
- a (araştırma, kod değişikliği YOK): Antalia (e7e3b1e3) ve EMA (a2c8a396) HF Space'leri EN SON commit'te — güncelleme yok.
  Yeni ses adayları: Piper tr_TR-dfki CC BY-NC-SA (ret), 99eren99/piper-turkish lisanssız (ret), MMS-TTS NC (ret),
  VITS-OpenBible-Turkish CC-BY-SA ~1 GB .pth (ret), Breeze-TTS-2 NC (ret);
  empiriolabsai/kokoro-turkish Apache-2.0, int8 115 MB, AMA g2p espeak-ng (GPL-3) istiyor + 1 günlük model → şimdilik ret, sabah bakılacak.
  İngilizce: Pocket TTS web (CC-BY-4.0) ≈200 MB (voices.bin 52 MB) çok büyük; Supertonic-2 OpenRAIL-M ≈263 MB (ret);
  Kokoro/Kitten EN espeak (GPL) ister. KARAR (en güvenli): yeni ses eklenmedi.

## Sıradaki adım
1. `test/cleanup_ignore_test.dart`'a `appTipFor` testi (kullanılmayan büyük > önbellek; ignored atlanır; usageKnown=false → null).
2. kasma-kontrol skill'i (Uygulamalar ekranına görünür kart eklendi).
3. PLAN.md U6 satırı: (b)(c) bitti → C2/CIHAZ_TESTI; (a) yukarıdaki karar. HAFIZA.md tarihli kayıt (ses araştırması + kural).
4. docs/CIHAZ_TESTI.md: Uygulamalar öneri kartı + Analiz Ayıkla dökümü. DEVIR.md'yi sil, push, CI izle.
