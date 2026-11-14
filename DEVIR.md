# DEVIR — faz-oto-P13-liste (P13 liste/ızgara hızı)

- Kanıt (B3.3b): `build/klasor_5000_kaydirma.timeline.json` (2026-11-13, ana ağaç) — 51 kare, UI toplam
  412 ms; SEMANTICS 230 ms (%56), LAYOUT 74, PAINT 55, BUILD 47. En kötü kare 19,2 ms = SEMANTICS 8,7 +
  LAYOUT 6,3 + BUILD 3,9. Kök: `testWidgets` `semanticsEnabled: true` varsayılanı → senaryo TalkBack-açık
  kullanıcıyı ölçüyor; satır başına SemanticsNode her karede yeniden gönderiliyor (kaydırma dönüşümü;
  ~172 `Dart_StringToUTF8`/kare). Flutter'a özgü, satır başına 1 düğüm — kod tarafında kısılacak pay yok.
- Yapıldı 1: `integration_test/perf_senaryolari_test.dart` — anlam ağacı elle (ensureSemantics) açık,
  sonda kapatılıp `klasor_5000_kaydirma_sk`, `galeri_2000_kaydirma_sk` (ısınmış ikinci ziyaret).
- Yapıldı 2 (H6.4): `fm_file_list_view.dart` `_FreshRows`/`_FreshTint` — yeni satır sönen ön plan rengi
  (Motion.pulse; ≤ 2.000 öğe, ≤ 20 yeni, yalnız sayı artınca). Kapanma YAPILMADI (sabit satır boyu G14 +
  kasma 6). Test `test/fm_list_fresh_test.dart`.
- Yapılamadı: B3.3c (SurfaceFlinger `--latency`, telefon başka ölçümde), soğuk açılış `am start -W`.
- Sıradaki: CI yeşil → belgeler (OTOMASYON P13, KALANLAR, FERRARI H6.4, HAFIZA, CIHAZ_TESTI) → bitir.
- Ölçüm: `bash tool/ab_olcum.sh` (yürütücü) — senaryolar yukarıda + mevcut 11.
