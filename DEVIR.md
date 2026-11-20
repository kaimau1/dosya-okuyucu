# DEVIR — B13 m.1 açılış geçişi (dal faz-oto-B13-acilis) — BİTTİ (KALDI)

- 9d147697 + de8cecca: ölçüm senaryosu `acilis_gecis` (integration_test). Uygulama kodu YOK.
- Denenen geçiş (659158e1, daldan çıkarıldı): satır şeridinden büyüyen ClipRect → A/B KALDI.
- A/B (Huawei, A=c136fd28 ×3, B=56f885b1 ×3): ms pdf 135→119 · pptx 314→354 · xlsx 293→342 ·
  docx 757→739; gecis_pptx_acilis build p99 20,2→34,1; gecis_pdf_kapanis build p99 5,9→9,5.
  Tablo `docs/perf/2026-11-20-ab-c136fd2-56f885b.md`.
- Taban ağaçları silindi, ekran uyutuldu. Birleştirme yürütücüde (APK değiştirmez — yalnız senaryo + belge).
