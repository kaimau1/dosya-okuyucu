# Arşiv test dosyaları — kaynak ve lisans

Bu klasördeki `.rar` / `.7z` dosyaları **koni_archive** projesinin test
fixture'larıdır (MIT lisanslı, © 2026 the koni_archive authors —
https://pub.dev/packages/koni_archive). Buraya kopyalandılar çünkü RAR
sıkıştırıcısı özel mülktür: bu sandbox'ta (ve CI'da) gerçek bir `.rar`
ÜRETİLEMEZ, dolayısıyla RAR okumasını doğrulamanın tek yolu hazır dosyalardır.

| Dosya | Ne | Doğruladığı yol |
|---|---|---|
| `normal.rar` | RAR5, `-m3` sıkıştırılmış; `hello.txt`, `empty.txt`, `nested/deep/data.bin` (100 KB), `日本語/ページ001.txt` | RAR5 çözme + Unicode ad + iç içe klasör |
| `solid_rar4.rar` | RAR4 (`-ma4 -m3 -s`), **katı (solid)** arşiv, 5 metin dosyası | Eski RAR4 yolu + solid akış |
| `encrypted.rar` | RAR5, `-psecret` ile şifreli tek dosya | Parola isteme/doğrulama akışı |
| `lzma2_solid.7z` | 7z, LZMA2 solid; RAR fixture'larıyla aynı içerik ağacı | 7z çözme |

Bu dosyalar yalnızca `test/fm_archive_rar_test.dart` tarafından okunur;
uygulamanın APK'sına girmezler (assets değildir).
