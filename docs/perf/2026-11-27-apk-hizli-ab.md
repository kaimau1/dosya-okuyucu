# Hızlı A/B (kısaltılmış) — 2026-11-27, Huawei tablet DBY-W09

Taban 83f94a50 (son [apk]) · Aday e9ecadb8 (main ucu) · `.r8test` profil, `tool/ab_olcum.sh`, AB_SENARYO=pdf_100, sıra ABBA (A,B,B,A; tek koşu çifti x2), başlangıç ısısı A 24,9 / B 25,1 °C.

| senaryo | ölçü | A ortanca | B ortanca | fark % |
|---|---|---|---|---|
| PDF açılış | build p99 | 12.9 | 7.5 | -42 |
| PDF açılış | raster p99 | 8.6 | 7.5 | -13 |
| PDF açılış | belge damgası ms | 69.0 | 39.5 | -43 |
| PDF açılış | ilk sayfa ms | 700.5 | 676.5 | -3 |
| PDF kaydırma | build p90 / p99 | 5.9 / 9.7 | 5.4 / 10.2 | -8 / +5 |
| PDF kaydırma | raster p90 / p99 | 5.9 / 8.0 | 6.1 / 8.5 | +2 / +7 |
| soğuk açılış | build p99 | 1.2 | 1.0 | -16 |

En yüksek kare p99 = 10.3 ms (< 24 ms). Hiçbir fark > %10 ve > 3 ms birlikte değil.

Klavye senaryosu (arama/İçindekiler aç-kapa): ölçülmedi — otomatik senaryo yok, adb ile gfxinfo Flutter karelerini güvenilir ölçmez (skill kuralı); süre kısıtı nedeniyle atlandı. Cihazda doğrulanmadı.

Ayrıntılı tablo: `docs/perf/2026-11-27-ab-83f94a5-e9ecadb.md`.

KARAR: YEŞİL — PDF açılış+kaydırma gerilemedi (açılış belirgin iyi); klavye ölçülmedi.
