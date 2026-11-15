# Ana ekran tasarım önerileri (2026-11-15)

Durum: **öneri, karar bekliyor.** Uygulama kodu değişmedi.

| Pano | Önizleme | Kaynak |
|---|---|---|
| A · Sakin | [A-sakin.png](A-sakin.png) | `maket/Main.dc.html` |
| B · Bento | [B-bento.png](B-bento.png) | `maket/B-Bento.dc.html` |
| C · Koyu başlık | [C-koyu-baslik.png](C-koyu-baslik.png) | `maket/C-Liste.dc.html` |
| Simge takımı | [D-simgeler.png](D-simgeler.png) | `maket/D-Simgeler.dc.html` |
| Yazı ölçeği | [E-yazi.png](E-yazi.png) | `maket/E-Yazi.dc.html` |
| Metinler (şimdi → yeni) | [F-metinler.png](F-metinler.png) | `maket/F-Metinler.dc.html` |

Canlı tuval (yalnız hesap sahibine açık): https://claude.ai/artifact/ASEPoHKhQdRX3MPNJVE5xK

## Notlar
- Önizlemeler varsayılan ayarla çekildi: simgeler renkli; A kiremit, B ve C yeşil vurgu.
  Tuvalde her panonun "Tweaks" düğmesinden vurgu rengi ve "Simgeler: Renkli / Tek renk" değişir.
- Son açılanlar'daki saatler örnektir; küçük görseller yer tutucudur.
- Kaynaklar Claude Design tuvali biçimindedir (`docs/design/pdf_pro/maket/` ile aynı);
  tek başına tarayıcıda açılmaz, PNG'lere bakın.
- Maket genişliği 412; kutu adları dört sütunda 13, liste ve kartlarda 14.

## Bilerek değişmeyenler
- Harici bellek kutusu takılı değilken de görünür (kullanıcı isteği, `tools.dart`).
- Araçlar'da dört kutu + "Tümü (5)".
- İçerik ve düğmeler aynı; değişen renk, yerleşim, boyut, simge, yazı ve metin.

## Karar bekleyenler
1. Yön: A, B ya da C (parçalar birleştirilebilir).
2. Simgeler renkli mi, tek renk mi.
3. Kutu adlarında cümle düzeni ("Önemli dosyalar"): öteki ekranların başlıklarını da etkiler.
