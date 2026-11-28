# DEVIR — faz-oto-R8-pdf-akicilik (2026-11-28, kota %97'de durduruldu)

Yapılanlar:
- b405accb test: `PA_IZ=true` dart-define → izde widget/render adları (kök arama; A/B'de kapalı).
- 7f412f07 KÖK (yazi_ac): görüntüleyici ekranı MediaQuery.viewInsets'e (ve geri çağrılarda MediaQuery.of ile tümüne) bağlıydı → klavye canlandırmasının her karesinde tüm ekran + pdfrx katmanı yeniden kuruluyordu (iz: kare 24–67 ms, BUILD 10 + LAYOUT 7–37 ms). Inset artık küçük Builder'larda; belge sonu payı klavye durulunca tek setState (`_mqNoDep`, `_proWatchInset`).
- 97cf17d5 damga: pdfrx yaması `pdfrxOnPageImagePainted` → `acilis_ilk_cizim/ilk_net/kopru` (YAMA.md 3.).
Ölçüm (tablet, 1 tur A=origin/main+damga, B=dal; ms):
- İlk açılış GÖRÜNÜR: A kucuk ilk_cizim 192 kopru 303 | buyuk 249/294 | buyuk2 166/285 · B 149/274 | 83/247 | 130/276. `ilk_sayfa` (eski damga) A 690–945, B 672–733 = 500 ms arka-sayfa gecikmesini ölçen YAPAY damga. Kullanıcı sayfayı köprü kalkınca (~250–310 ms) görüyor; tablette gerçek 900 ms gecikme YOK. Telefonda doğrulanmadı.
- yazi_ac build p90 8.2→4.7, p99 19.0→39.8 (TEK koşu, tek kare; kanıt değil → 2. tur şart). Diğer yüzeyler ±gürültü, p99 hepsi <24 (fling 16, silgi 15.9).
TUZAKLAR: Git Bash'te `--dart-define=OLCUM_VERISI=/sdcard/...` MSYS yol çevirisiyle bozulur → `export MSYS_NO_PATHCONV=1` (yoksa "Bu PDF açılamadı", FPDF_ERR_FILE). prepare_android `python3` ister → shim PATH'e `/c/...` biçiminde. Kurulumda tablet kilitliyse `wm dismiss-keyguard`.
Sıradaki: (1) aynı APK'larla 2. tur B,A (`bash tool/pdf_akicilik.sh <apk> <no>`; taban ağacı silindi → origin/main + 97cf17d5'in body/viewer_screen/pdf_viewer damga kısmıyla yeniden kur, `--target-platform android-arm64`). (2) yazi_ac B kötü kalırsa iz APK (PA_IZ) ile ayrıştır. (3) Kaydırma p90 ~9 ms kümesi: kosu7 izinde her hareketli karede LAYOUT/BUILD 3 + PAINT 3 + SEMANTICS 2 ms (pdfrx `_onMatrixChanged`→`_invalidate`→LayoutBuilder tüm sayfa katmanlarını yeniden kurar) — düzeltilmedi. (4) isLight yolu gözden geçirilmedi. (5) Rapor docs/perf/2026-11-28-R8-pdf-akicilik.md + HAFIZA henüz yazılmadı.
