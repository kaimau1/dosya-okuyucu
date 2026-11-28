# PDF tam akıcılık ölçümü — 2026-11-28 (main 49039cdf, `.r8test` PROFİL derlemesi)

Kod değişmedi; yalnız ölçüm. Cihaz: **Huawei tablet DBY-W09 (5VLBB21A27203178)**. Kullanıcının şikâyeti telefonda (v1.3.142);
telefon bu görevde bağlı değildi. Tablet daha güçlüdür, aşağıdaki "yeşil"ler telefonda yeşil demek DEĞİL.
Yöntem: `integration_test/pdf_akicilik_test.dart` (yeni) → `flutter drive --profile`, her yüzey ayrı `traceAction`;
`tool/pdf_akicilik.sh` (koşu) + `tool/pdf_akicilik_ozet.py` (p50/p90/p99). Veri: `tool/make_pdf_akicilik.py` →
`belge_320.pdf` (320 sayfa, 66 MB, 32 başlıklı içindekiler) + `belge_100.pdf`. Pil 25–27 °C, ısı sorunu yok.
Süre kısıtıyla 5 ardışık koşu (kosu3–7); yazı yüzeyi 3, kalem/silgi 4 koşuda ölçülebildi (ilk koşularda test düzeltmeleri sürüyordu, o adımlar çalışmadı).
Rakamlar ms. b = build (UI izleği), r = raster. Mutlak eşik: p99 > 24 ms KIRMIZI. SARI = ortanca p99 eşiğin altında ama en az bir koşuda tek tek kare > 24 ms (takılma kıpırtısı).

## Özet tablo (koşu ortancası; p99 yanında min–maks)

| yüzey | koşu | b p50 | b p90 | b p99 (min–maks) | b maks | r p50 | r p90 | r p99 (min–maks) | r maks | >24 ms kare (toplam) | durum |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pa_acilis_kucuk | 5 | 0.7 | 1.0 | 3.1 (2.4–3.3) | 9.8 | 4.0 | 5.9 | 7.6 (7.1–19.2) | 19.6 | 0 | yeşil |
| pa_acilis_buyuk (320 sf, 66 MB) | 5 | 0.6 | 1.0 | 3.8 (3.6–17.5) | 25.9 | 4.0 | 6.0 | 7.0 (6.6–23.6) | 30.8 | 3 | SARI |
| pa_acilis_buyuk2 (ikinci açılış) | 5 | 0.5 | 1.0 | 5.0 (4.0–5.3) | 22.7 | 4.0 | 5.9 | 6.8 (6.4–9.7) | 16.3 | 0 | yeşil |
| pa_acilis_duzenle | 5 | 0.7 | 1.3 | 2.0 (1.8–2.2) | 24.6 | 3.9 | 5.6 | 6.7 (6.5–16.7) | 30.2 | 2 | SARI |
| pa_sayfa_gecis_yakin | 5 | 0.9 | 6.4 | 12.4 (8.5–13.3) | 15.7 | 3.9 | 6.2 | 9.1 (8.2–11.0) | 15.6 | 0 | yeşil |
| pa_sayfa_gecis_uzak | 5 | 0.8 | 4.6 | 11.8 (11.3–15.6) | 19.9 | 4.3 | 6.5 | 9.3 (7.0–15.8) | 26.4 | 1 | SARI |
| pa_icindekiler_atla | 5 | 0.7 | 2.0 | 6.5 (5.9–10.4) | 54.9 | 4.0 | 6.0 | 8.4 (7.8–8.6) | 11.2 | 3 | SARI |
| pa_kaydir_yavas | 5 | 0.9 | 9.1 | 10.8 (10.0–11.7) | 19.5 | 4.5 | 6.8 | 7.2 (7.2–7.4) | 8.0 | 0 | yeşil |
| pa_kaydir_fling | 5 | 4.3 | 6.3 | 13.4 (11.9–15.2) | 17.4 | 4.2 | 6.5 | 10.4 (7.2–11.6) | 13.2 | 0 | yeşil |
| pa_kaydir_fling_geri | 5 | 4.2 | 6.5 | 10.9 (10.5–14.7) | 24.9 | 4.2 | 6.8 | 8.9 (7.9–11.6) | 16.2 | 1 | SARI |
| pa_tutamac_surukle | 5 | 1.1 | 3.2 | 6.1 (5.3–10.6) | 30.4 | 4.1 | 6.3 | 8.1 (7.2–11.4) | 14.8 | 2 | SARI |
| pa_yakinlastir (kıstırma) | 5 | 0.7 | 7.3 | 10.9 (10.4–15.1) | 41.4 | 4.2 | 6.3 | 9.0 (7.4–9.4) | 11.0 | 3 | SARI |
| pa_kaydir_zoomlu (3x zoom) | 5 | 1.0 | 7.7 | 10.6 (9.5–10.7) | 22.3 | 4.1 | 6.3 | 7.3 (6.9–7.6) | 16.3 | 0 | yeşil |
| pa_duzenle_giris | 5 | 3.0 | 4.1 | 13.0 (6.0–14.3) | 34.1 | 4.4 | 7.6 | 8.7 (8.4–9.0) | 31.3 | 2 | SARI |
| **pa_yazi_ac** (Metin ekle) | 3 | 0.9 | 8.3 | **29.2 (25.4–33.9)** | 67.4 | 4.3 | 7.3 | 9.6 (9.2–10.3) | 24.5 | 13 | **KIRMIZI** |
| pa_yazi_yaz (karakter karakter) | 3 | 1.1 | 2.1 | 3.2 (3.0–3.4) | 9.3 | 4.7 | 7.6 | 8.7 (8.4–9.1) | 17.2 | 0 | yeşil |
| pa_kalem_ciz | 4 | 0.9 | 1.5 | 2.0 (1.9–2.3) | 4.3 | 5.2 | 8.4 | 9.9 (9.4–10.3) | 10.7 | 0 | yeşil |
| pa_silgi | 4 | 0.9 | 10.2 | 12.8 (12.3–13.2) | 29.0 | 5.8 | 9.7 | 10.2 (10.1–10.5) | 10.8 | 2 | SARI |

Koşu başına ham tablo: `python tool/pdf_akicilik_ozet.py build/pa/kosu*` ile yeniden üretilir.

## KIRMIZI

**`pa_yazi_ac`: düzenleme kipinde "Metin ekle" ile yeni metin kutusu açma** (build p99 29 ms; koşular 25–34; en kötü kare 49–67 ms; koşu başına 3–5 kare > 24 ms).
Raster temiz (p99 ~10). Sorun UI izleğinde: kutu oluşturma + satır içi düzenleyici + klavye açılışı tek karede.
Olası kök (tahmin, timeline ayrıştırılmadı): düzenleme denetleyicisinde kutu kurulurken senkron iş, `setState` ile sayfa katmanının topyekûn yeniden kurulması,
`EditableText` odağı + klavye inset'iyle görüntüleyicinin yeniden yerleşimi.

## SARI

- `pa_icindekiler_atla` (build maks 54.9 ms, 3 kare): içindekiler levhası + uzak sayfaya atlama; atlama sonrası yeni sayfalar bir anda çiziliyor.
- `pa_yakinlastir` (maks 41 ms, 3 kare), `pa_tutamac_surukle` (maks 30 ms, 2 kare): hareket başında tek kare; ölçek değişince görünür sayfa görüntüleri yeniden isteniyor olabilir.
- `pa_duzenle_giris` (maks 34 ms; build p50 3.0 ms, öteki yüzeylerin 3-4 katı): kip girişi (katman + çubuklar + belge olay aboneliği).
- `pa_silgi` (build p90 10 ms, maks 29 ms), `pa_sayfa_gecis_uzak` (raster maks 26 ms), `pa_acilis_buyuk` / `pa_acilis_duzenle` (bir koşuda 25-30 ms), `pa_kaydir_fling_geri` (1 kare 24.9).

## Yeşil ama dikkat

- Kaydırma (yavaş, fling, yakınlaştırılmış): p99 10-15 ms. Ancak **yavaş ve yakınlaştırılmış kaydırmada build p50 ≈ 1 ms iken p90 ≈ 8-9 ms**: kareler iki kümeli (çoğu hafif, birkaç karede bir ağır iş). Periyodik iş (sayfa görüntüsü yerleştirme / `setState`) var; zayıf telefonda bu küme 24 ms'yi aşabilir.
- Fling'de build p50 4.3 ms (yavaşta 1 ms): fırlatmada her karede ek iş var (rozet/tutamaç/ön bellek güncellemesi olası).
- Açılış: büyük PDF ilk sayfa `PDFPRO_PERF acilis_ilk_sayfa` ≈ 0.6-0.9 s, belge ≈ 40-65 ms; kare olarak temiz.
- Kalem çizimi: build 2 ms, raster p99 ~10 ms, yeşil.

## Ölçülemeyen / kapsam dışı

- **Düzenleme kipinde mevcut metne dokunup seçme + yazma**: 5 koşunun 4'ünde ızgara dokunuşuyla metin bloğu seçilemedi (`pse-chip-edit` çıkmadı; yalnız bir koşuda çıktı). Test sınırı mı, gerçek seçme sorunu mu ayırt edilemedi. Yazma "Metin ekle" yolundan (yeni kutu) alındı; `pa_yazi_yaz` yeşil (build p99 3 ms). Klavye sentetik (`enterText`); açılış animasyonu `pa_yazi_ac` içinde.
- Dokunuşlar sentetik `TestGesture` (gerçek kare hattından geçer; parmak ivmesi/gecikmesi farkı olabilir).
- **Telefon ve ısınmış durum ölçülmedi**: bu rapor kullanıcının şikâyetini doğrulamaz ya da çürütmez.

## Sonraki adım (öneri; kod değişikliği yok)

1. Telefonda aynı testi koştur: `.r8test` ağacında `flutter build apk --profile --target=integration_test/pdf_akicilik_test.dart`, sonra `bash tool/pdf_akicilik.sh <apk> <no>` (veri `make_pdf_akicilik.py` + `make_test_tree.py`, betik cihaza iter).
2. `pa_yazi_ac` ve `pa_icindekiler_atla` timeline'larında UI izleği olay sürelerini aç; kök neden oradan.
3. Kaydırmadaki p90 build kümelenmesinin kaynağı (periyodik `setState`) aranmalı.
