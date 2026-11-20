# DEVIR — R1 (faz-oto-R1-gerileme)
- Yapılan: `AB_SENARYO` senaryo süzgeci (integration_test/perf_senaryolari_test.dart `bolum`, tool/ab_olcum.sh dart-define); 4 A/B koşusu; sonuç tablosu docs/perf/2026-11-20-R1-gerileme.md; PLAN R1 satırı; HAFIZA.
- Kanıt: klasor_5000_kaydirma build p99 R1'de A 28,4/17,5/41,4/23,5/33,0 · B 17,7/19,9/21,3/18,0/18,5 (ters yön).
  slayt_300_acilis_pro0 tek başına A 3,3/2,3/2,7 · B 2,3/6,5/1,3; bağlamda A ort. 36 · B ort. 45;
  zaman çizelgesi: p99 karesinde aynı iş + B'de 12,9 ms Scavenge.
- Kod düzeltmesi yok (suçlu commit yok). Ham: build/ab/20261120-1246..1353 (git dışı).
- Sıradaki: yürütücü CI yeşilse birleştirir (uygulama kodu değişmedi, yalnız test/tool → APK yok).
