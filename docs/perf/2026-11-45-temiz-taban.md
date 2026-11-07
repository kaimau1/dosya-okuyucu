# Temiz taban — reklam/gereksiz uygulamalar kaldırıldıktan sonra (2026-11-07)

**Neden yeni taban:** tabletten 25 reklam/gereksiz paket `pm uninstall --user 0` ile
kaldırıldı (liste + geri yükleme: `docs/CIHAZ_TESTI.md` → "Cihaz notu"). Arka plan yükü
değiştiği için Faz 44 tablosu artık kıyas tabanı değil. **Faz 45–47 cihaz kapısı bu tabloya göre.**

**Yapı:** main `79a1f2e` (Faz 44 birleşmesi; Flutter 3.47.9, pdfrx 1.3.5), profil APK, `.r8test`
kimliği. **Cihaz:** MatePad DBY-W09, Android 12, GMS yok, 120 Hz, erişilebilirlik kapalı.
Medyanlar: P1 10 koşu, P5 5 koşu, P10 3 örnek, senaryolar 2 geçerli koşu (3. koşunun
zaman çizelgesi boş geldi — sürücü sorunu, uygulama değil).

**Kapı (kullanıcı kararı, 2026-11-07):** birleşmeyi yalnız hissedilir gerileme durdurur —
kaydırma p99 > 24 ms, görünür donma/kasma, soğuk açılış ~+100 ms üstü, bellek +%20 üstü, çökme.
Küçük % farkları tabloya yazılır, PR'da gerekçelendirilir.

| # | Ölçüm | taban (medyan) | aralık |
|---|---|---|---|
| P1 | Soğuk açılış `am start -W` TotalTime (ms) | 988 | 954–1470 (ilk koşu ısınma) |
| P2 | Pano boşta kare / 10 sn (SurfaceFlinger BLAST katmanı) | 0 | 3/3 |
| P3 | 5.000 öğe kaydırma build p99 / raster p99 (ms) | 19,6 / 9,5 | 17,9–21,3 / 9,3–9,6 |
| P4 | 2.000 görsel galeri build p99 / raster p99 | 19,0 / 11,7 | 18,8–19,1 / 8,6–14,8 |
| P5 | PDF-B TotalTime (ms) | 995 | 957–1004 |
| P5 | PDF-B FrameTiming p99 (ms) | 21,2 | 11,6–26,8 |
| P5 | PDF-B raster p99 (ms) | 10,3 | 6,9–10,5 |
| P5 | PDF-B ≥25 ms kare / en uzun kare | 13 / 84 | 11–19 / 63–109 |
| P5 | PDF-B PSS (MB) | 348 | 302–438 |
| P7 | 100 s. PDF kaydırma build p99 / raster p99 | 18,2 / 16,2 | 16,9–19,6 / 13,3–19,1 |
| P8 | xlsx 100 bin kaydırma build p99 / raster p99 | 31,5 / 14,1 | 27,2–35,8 / 10,7–17,4 |
| P8 | xlsx açılış build p99 | 7,5 | 2,0–13,0 |
| P10 | Pano boşta PSS (MB) | 286 | 286–286 |

Notlar: P5 FrameTiming p99 koşudan koşuya 11–27 ms oynuyor (PDF-B ağır belge, en uzun kare
zaten Faz 43'ten beri 60–110 ms); kapıda medyan + "≥25 ms kare sayısı" birlikte okunur.
P8 xlsx kaydırma build p99'u Faz 44'te de 40 ms'ydi (senaryo kare sayısı az, 4–33 kare).

**Yöntem değişikliği:** P2 artık `dumpsys SurfaceFlinger --latency 'SurfaceView[...](BLAST)#0'`
ile sayılıyor (BLAST'sız `SurfaceView[...]#0` katmanı kaydırırken de 0 döner — yanlış sıfır).
