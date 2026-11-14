# DEVIR — P14 (faz-oto-P14-word)

- Yapıldı: ölçüm verisi `word_300.docx` + `slayt_300.pptx` (`tool/make_test_tree.py`);
  senaryolar `perf_senaryolari_test.dart` sonunda: word_300_{acilis,menu,kaydirma,kapanis},
  word_mobil_{acilis,kaydirma}_pro{0,1}, slayt_300_{acilis,kaydirma,kapanis}_pro{0,1};
  `ab_olcum.sh` veri denetimi `slayt_300.pptx`'e bakıyor (yeni dosyalar itilsin).
- Telefon (24cc5034) P04 A/B ölçümünde (`ab_olcum.sh a3c43e89 origin/faz-oto-P04-kabuk`,
  15:13 başladı) → bu pakette cihaz KULLANILMADI.
- B3.3d kök neden: üretilemedi (cihaz yok). Kod okuması: `DocxView` tek şüpheli
  `displayWithHybridComposition: true` (lib/widgets/docx_view.dart:500); kapanışta/menüde
  Dart tarafında ağır iş yok (dispose yalnız dinleyici; didChangeDependencies kare başı değil).
- B3.2: kullanıcı bakışı → KONTROL_LISTEM; kod silme onaydan sonra.
- Sıradaki: telefon boşalınca `timeout 14400 bash tool/ab_olcum.sh` (A = son [apk], B = bu dal);
  word_300_kapanis/menu raster p99 > 24 ms ise HC suçlu adayı güçlenir → B3.3d seçenekleri.
