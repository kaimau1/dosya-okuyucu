# T1: ölçüm aracı Huawei uyumu — kuru koşu 2026-11-20

Cihaz: Huawei DBY-W09 (USB), `AB_KURU=1 bash tool/ab_olcum.sh origin/main HEAD` — tek A koşusu
(`09f5dc10` profil `.r8test`, senaryo dosyası dal `faz-oto-T1-olcum-huawei`). Pil 28,0 → 30,9 °C.
Karşılaştırma değil (tek taraf); amaç aracın uçtan uca sayı üretmesi.

**Kurulum:** bekçi üç Huawei ekranını kendisi geçti (döküm metninden): "Bilinmeyen kaynaklar" →
DEVAM ET, "Hiçbir tehdit bulunmadı" → YÜKLE, "Yükleme başarılı" → BİTTİ (AÇ'a dokunulmadı).
Önceki koşuda her kurulum 1000–1800 sn takılıyordu.

**Sürücü:** `pano_bosta` artık çökmüyor (bu koşuda 288 kare); 34 senaryonun hepsi yazıldı,
"All tests passed".

| senaryo (yeni) | kare | build p90 | build p99 | raster p90 | raster p99 |
|---|---|---|---|---|---|
| sol_menu_acilis | 215 | 5,36 | 26,69 | 5,70 | 8,29 |
| bellek_analizi_acilis | 274 | 0,55 | 0,81 | 6,11 | 7,16 |
| bellek_analizi_kaydirma | 244 | 1,26 | 10,37 | 6,52 | 7,36 |
| akilli_duzen_acilis | 253 | 0,74 | 1,03 | 6,15 | 6,96 |
| akilli_duzen_kaydirma | 244 | 1,36 | 13,16 | 7,25 | 8,35 |
| ana_sekmeler | 268 | 2,55 | 4,52 | 7,44 | 8,78 |
| pano_bosta | 288 | 0,90 | 1,15 | 4,68 | 5,68 |
| soguk_acilis | 252 | 0,58 | 0,75 | 3,60 | 7,34 |

Not: `sol_menu_acilis` build p99 26,7 ms (> 24 ms) — tek koşu, A/B değil; C2 A/B'sinde bakılacak.
İlk kuru koşuda (`38ff7343`) "Analiz" düğmesi ve şerit sekmeleri bulunamamıştı (pano tembel
liste, bölüm kurulmamıştı) → senaryo kök rotaya dönüp panoyu kaydırarak arar.
