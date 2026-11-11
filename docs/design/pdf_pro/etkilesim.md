# PDF Pro — etkileşim belirtimi (Faz 53 / 3) · 2026-11-08

Maketler: https://claude.ai/artifact/PNjvf5wSp5ae2rY56RpNQW (kaynak `maket/`). Renk/aralık tokenları
`lib/core/app_colors.dart` → `PdfEditTokens` (Faz 53 / 4). Süreler `Motion`.
Bütçeler: `PDF_PRO_PLANI.md` §6. Bu belge Faz 54–68 UX işlerinin sözleşmesidir; sapma = önce burayı güncelle.

## 1. Kipler

| Kip | Giriş | Çıkış |
|---|---|---|
| **Okuma** | belge açılır | — |
| **Düzenleme** (aynı ekran) | üst çubuk *Düzenle* · seçim levhası *Düzenle* · bloğa uzun bas → *Düzenle* | ← / geri tuşu / ✓ |
| **Yazma** (düzenleme içinde) | seçili bloğa dokun · yüzen çubukta *Düzenle* · okumadan seçimle gelindiyse doğrudan | ✓ (üst çubuk) · geri tuşu · bloğun dışına dokun |

Kip geçişinde sayfa, yakınlaştırma matrisi ve kaydırma konumu **değişmez** (test: `controller.value` aynı).
Düzenleme kipine geçiş ≤ 150 ms; belge yeniden yüklenmez.

## 2. Hareketler

| Hareket | Okuma | Düzenleme | Yazma |
|---|---|---|---|
| Dokun | çubukları göster/gizle | bloğu seç (tutamaçlar + yüzen çubuk); boşluğa → seçimi bırak | imleci dokunulan karakter arasına koy |
| Çift dokun | yakınlaştır/uzaklaştır | seçili blokta → yazma kipi, sözcük seçili | sözcük seç |
| Uzun bas | metin seç (sistem tutamaçları) | blok bağlam menüsü (Düzenle · Kopyala · Sil · Satır kipine geç) | büyüteç + imleç sürükleme |
| Sürükle (tek parmak) | kaydır | seçili blok tutamacından → taşı/boyutlandır (Faz 57); bloğun dışında → kaydır | seçim tutamacı / imleç |
| İki parmak | yakınlaştır | yakınlaştır | yakınlaştır (imleç ve seçim korunur) |
| Uzun bas + sürükle | seçimi genişlet | — | seçimi genişlet |

Dokunma hedefi en az 44 × 44 dp; küçük blokların görünmez hedefi 44 dp'ye büyütülür, komşu
bloklar çakışırsa dokunulan noktaya en yakın kutu kazanır.

## 3. İmleç ve seçim

- Okumada seçilen aralık → düzenlemede **aynı karakter aralığı** (PDFium karakter dizini → blok içi
  ofset). Eşleşme yoksa seçimle en çok örtüşen blok, imleç seçimin başında (Faz 51 / 6 yedeği).
- İmleç 2 dp, vurgu renginde, `Motion.caretBlink` (500 ms). Seçim dolgusu vurgunun %28'i.
- Seçim tutamaçları Android sistem tutamaçları (EditableText); büyüteç sistemin.
- Donanım klavyesi: ok tuşları, Shift+ok, Ctrl+Z/Y, Ctrl+B/I/U, Esc = yazmadan çık.
- IME bileşik girişi (Türkçe önerili klavye, Arapça) birinci sınıf: bileşim alt çizgisi gösterilir,
  bileşim bitmeden belgeye yazılmaz.

## 4. Yakınlaştırma kuralları

1. **Klavye açılınca görüntüleyici küçülmez** (`EditorChrome.overlayKeyboard` + `freezeBody`).
2. Yazmaya girerken düzenlenen satır klavyenin üstünde kalacak biçimde **kaydırılır**; satırın
   ekrandaki yazı boyu **16–20 sp** aralığında değilse yakınlaştırma 18 sp'ye ayarlanır (yalnız
   giriş anında, `Motion.medium`, `Motion.enter` eğrisi). Yazma sırasında otomatik yakınlaştırma YOK.
3. Yazmadan çıkınca yakınlaştırma **girişten önceki** matrise döner (kullanıcı arada elle
   yakınlaştırdıysa dönmez).
4. Uygula / geri al / yinele yakınlaştırmayı ve kaydırmayı değiştirmez; değişen yalnız o sayfanın pikselleri.

## 5. Çubuklar

- **Üst çubuk** (56 dp telefon, 60 dp tablet): ← · başlık + durum satırı ("Kaydedilmedi · N değişiklik",
  turuncu nokta; kayıtlıysa "Kaydedildi" gri) · geri al · yinele · **Kaydet** (dolgulu) · ⋮. Geri al
  düğmesinin erişilebilirlik adı adım adını taşır ("Geri al: Paragraf düzenlendi").
- **Alt araç çubuğu** (64 dp, 7 öğe): Metin · Görsel · İşaretle · İmza · Form · Sayfalar · Daha fazla.
  Etkin araç: vurgu kuyusunda hap (44 × 28) + kalın etiket. Yatayda ve tablette sol **ray** olur.
- **Bağlamsal ikinci çubuk** (52 dp, yatay kaydırılabilir yongalar): seçili araca göre değişir —
  Metin: Metin kutusu · Paragraf/Satır · Bul ve değiştir; Görsel: Ekle · Değiştir · Kırp; İşaretle:
  Vurgula · Altını çiz · Not · Çiz; Sayfalar: Döndür · Ekle · Sil · Sırala.
- **Yüzen eylem çubuğu**: seçili bloğun 8 dp üstünde (sığmazsa altında), koyu zemin; klavye açıkken gizli.
- **Klavye üstü biçim çubuğu** (52 dp): yazı tipi (+ "belge" rozeti) · punto · B · I · U · renk ·
  hizalama · ⋯. Tablette biçim çubuğu yerine sağ özellik paneli (320 dp).
- Boşta (dokunuş yok) hiçbir çubuk animasyon çizmez — 0 kare.

## 6. Hareket süreleri (Motion)

| Olay | Süre | Eğri |
|---|---|---|
| Blok seç/bırak (çerçeve, tutamaç) | `Motion.short` 120 ms | `enter`/`exit` |
| Yüzen çubuk görün/gizlen | `Motion.short` | ölçek 0,96→1 + saydamlık |
| Bağlamsal çubuk değişimi | `Motion.medium` 220 ms | çapraz geçiş |
| Kip geçişi (çubuklar) | `Motion.medium` | kaydırarak |
| Yazmaya giriş yakınlaştırması | `Motion.medium` | `enter` |
| Levha (PK7, kaydet) | `Motion.long` 320 ms | `showAppSheet` |

"Animasyonları kaldır" açıkken hepsi 0 (`Motion.of`).

## 7. Haptik

- Blok seçildi: `HapticFeedback.selectionClick`.
- Uzun bas menüsü: `HapticFeedback.mediumImpact` (sistem uzun basmasıyla aynı).
- Taşırken kılavuz çizgisine yapışma: `selectionClick` (Faz 57).
- Kaydedildi: haptik yok (bildirim yeterli). Hata: `HapticFeedback.heavyImpact` YOK — sessiz kal.

## 8. Geri tuşu

Sırayla, ilk uyan tüketir:
1. Açık levha/menü → kapat.
2. Yazma kipi → yazmadan çık (değişiklik bellekte kalır, geri alınabilir).
3. Seçili blok → seçimi bırak.
4. Düzenleme kipi → okuma kipine dön (kaydedilmemiş değişiklik bellekte; durum satırı görünür kalır).
5. Okuma kipi, kaydedilmemiş değişiklik var → "Değişiklikler kaydedilsin mi?" (Kaydet · Kaydetme · Vazgeç).
6. Aksi halde ekran kapanır.

> **Faz 54 ara durumu (2026-11-11):** oturum henüz okuma kipinde yaşamıyor — düzenleme kipinden
> çıkış (4) kirliyse soruyu (5) HEMEN sorar ve oturumu kapatır; "değişiklik bellekte kalır" Faz 57'de
> gelir. Blok seçimi geri tuşuyla değil boşluğa dokunarak bırakılır (3 atlanır).

## 9. Durumlar

- **Yükleniyor:** gösterge yalnız 300 ms'yi aşarsa; sayfa okunur kalır, dokunuşlar kuyruğa alınmaz.
- **Metin yok:** "Bu sayfa taranmış görünüyor" + Metni tanı (OCR) · Metin kutusu ekle.
- **Düzenlenemeyen blok (PK7):** kesik turuncu çerçeve; dokununca levha: neden + Eşleşen yazı tipiyle
  yaz · Satır kipine geç · Üstüne metin kutusu.
- **Kayıt hatası:** değişiklik kaybolmaz; Belgeler'e kopya (birincil) · Başka konum.
- **Kaydedildi bildirimi:** kök gezginle açar (PS3); gövdeye dokunmak da açar.

## 10. RTL

Arapçada (`Directionality.rtl`) çubuklar, ray, panel ve yüzen çubuk aynalanır; geri/yinele simgeleri
yön değiştirir; sayfa içeriği AYNALANMAZ (PDF kendi yönünde). Blok etiketi blok başına (sağa) yaslanır.
