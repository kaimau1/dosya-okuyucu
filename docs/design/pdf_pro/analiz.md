# PDF Pro — rakip akış analizi (Faz 53 / 1) · 2026-11-08

Kaynaklar: `docs/PDF_PRO_PLANI.md` §2.1 [A1–A3, F1, P1–P3, X1–X3, N1]. Burada yalnız **akış**
(kullanıcı hangi adımı nasıl atıyor) karşılaştırılır; özellik matrisi planın §8'inde.
Maketler: https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW (kaynakları `maket/`).

## 1. Giriş — okumadan düzenlemeye

| Uygulama | Akış | Zayıf yan |
|---|---|---|
| Acrobat | Alt menü → *Edit PDF* → ayrı araç kipi; sayfa yeniden "hazırlanır" (kısa bekleme) | Seçimden doğrudan "düzenle" yok; seçim bırakılır |
| Foxit | Üst menüden *Edit* sekmesi; tüm metin blokları çerçevelenir | Çerçeveler sayfayı kalabalıklaştırır |
| PDFelement | *Edit* düğmesi → satır/paragraf kipi seçimi | Kip değişince yakınlaştırma sıfırlanır (kullanıcı yorumları) |
| Xodo | Açıklama araçları önde; metin düzenleme menü derininde | Mevcut metin düzenleme sınırlı |
| Nutrient | Görüntüleyici kipi olarak "content editing"; aynı ekran | Yalnız LTR, IME bileşik girişi yok |
| **Biz** | Okurken üst çubukta **Düzenle** + seçim levhasında **Düzenle**; aynı ekran, aynı yakınlaştırma; **seçim korunur** (seçimi içeren paragraf doğrudan açılır, imleç seçimin başında) | — |

## 2. Blok seçimi

- Rakiplerin hepsi düzenleme kipinde **bütün blokları belirgin çerçeveyle** gösterir (Foxit/PDFelement
  gri kutu) → okuma bozulur (PS6, ekran görüntüsü 1).
- **Biz:** üç kademeli çerçeve dili — dinlenmede %14 vurgu tonunda 1 px kılavuz, dokununca 2 px vurgu +
  4 tutamaç + küçük etiket ("Paragraf · Calibri 11 pt · belgenin fontu"), düzenlenemeyen blokta kesik
  turuncu çizgi (neden sorulmadan görülür). Dokunma hedefi bloğun kendisi; küçük bloklarda en az 44 px.

## 3. Biçim çubuğu

- Acrobat: altta sabit biçim levhası (yazı tipi, punto, renk, hizalama, liste). Klavye açılınca levha
  kapanır → biçim için klavyeyi kapatmak gerekir.
- Nutrient: **klavyenin üstünde** çubuk (renk, font, punto, B/I). En iyi örnek.
- **Biz:** klavye üstü çubuk: yazı tipi (+ "belge" rozeti = gömülü font kullanılıyor) · punto · B/I/U ·
  renk · hizalama · ⋯ (satır aralığı, liste, üstü çizili, karakter aralığı). Tablette çubuk yerine
  **sağ özellik paneli** (aynı denetimler + konum/genişlik + glif durumu: "Türkçe harfler gömülü
  fontta var").

## 4. Nesne tutamaçları ve yüzen eylemler

- PDFelement/Nutrient: köşe tutamaçlarıyla taşı/boyutlandır; eylemler uzun basma menüsünde.
- Acrobat: seçili nesnenin yanında küçük menü (kopyala/sil).
- **Biz:** seçili bloğun üstünde koyu **yüzen eylem çubuğu**: Düzenle (birincil) · Biçim · Taşı ·
  Kopyala · Sil. Blok ekranın üstündeyse çubuk altına geçer; klavye açıkken gizlenir.

## 5. Kaydetme

| Uygulama | Akış | Zayıf yan |
|---|---|---|
| Acrobat | Otomatik kayıt (bulut/yerel) | Geri dönüş yok; özgün ezilir |
| Foxit / PDFelement | Kaydet / Farklı kaydet iletişim penceresi | Kopya nereye gitti belirsiz |
| Xodo | Değişiklikler anında dosyaya | Geri alma oturum kapanınca biter |
| **Biz** | Üst çubukta dolgulu **Kaydet** + "Kaydedilmedi · N değişiklik" durumu; **artımlı** kayıt (özgün baytlar korunur) + 14 günlük **sürüm geçmişi** ("önceki sürüme dön"); salt okunur konumda tek dokunuşla Belgeler'e kopya, bildirimde **Aç** çalışır (PS3) | — |

## 6. Ne yapıyoruz ki daha iyi

1. **Tek yüzey** — ekran ve yakınlaştırma hiç değişmez (PK2/PK3).
2. **Seçim kaybolmaz** — okumada seçilen metin, düzenlemede imleç konumu olur (PS1).
3. **Gördüğün = yazılan** — alan belgenin gerçek fontuyla çizilir; "belge" rozeti bunu görünür kılar (PK6).
4. **Sessiz geri düşüş yok** — düzenlenemeyen blok kesik çizgiyle işaretli; dokununca neden + 3 seçenek (PK7).
5. **Türkçe/Arapça** — IME ve RTL ayna birinci sınıf (Nutrient'ta yok).
6. **Ücretsiz, çevrimdışı** — hiçbir düzenleme özelliği ücretli katmanda değil.
