# Telefonda Office Gibi Düzenleme — Araştırma ve Faz Planı (Faz 20–33)

> **Tarih:** 2026-10-23 · **İncelenen sürüm:** `main` @ `525f24b`
> **Kullanıcı isteği (2026-10-23):** *"Word, Excel, PDF, slayt, metin, görsel
> düzenlemeleri üzerine — özellikle Word'de yazı yazma/düzenleme/değiştirme,
> Excel'de yazma/düzenleme — detaylı bir araştırma yap. Bilgisayardaki kadar
> detaylı olamaz ama telefonda bir kişi en azından rahatlıkla belgelerini
> düzenleyebilsin, yazılarını değiştirmek kolay olsun, Excel'de rahatça
> düzenleme yapsın, slaytındaki yazıları zorlanmadan düzenleyebilsin; bunu da
> canlı, kasmadan, ferah biçimde yapabilsin; alışık olunan Office programlarına
> benzesin. Detaylı fazlar oluştur, kod değiştirme, planı yap, main'e merge et."*
>
> **Yöntem:** altı editörün kodu satır satır okundu (Word, Excel, Slayt, PDF,
> metin, görsel — ayrı ayrı denetim; en kritik iddialar kodda yeniden
> doğrulandı), `HAFIZA.md` / `KALANLAR.md` / `docs/CIHAZ_TESTI.md` geçmişi,
> gömülü `docx-preview` motorunun kaynağı; Microsoft 365 (Word/Excel/PowerPoint
> Android), Google Dokümanlar/E-Tablolar, Apple Numbers, WPS'in mobil düzenleme
> dili; Android klavye (IME) + `contenteditable` sorunları, Flutter'ın metin
> girişi altyapısı, editör kütüphaneleri ve gömülü ofis motorları üzerine web
> araştırması (kaynaklar §11).
>
> **Bu belge bir PLANDIR — kod değişikliği içermez.** `docs/FAZ_PLANI.md`'nin
> devamıdır (Faz 0–19 orada); numaralar oradan sürer. Her faz ayrı bir oturumda
> uygulanır; fazın sonundaki **"Açılış istemi"** yeni oturuma aynen yapıştırılır.

---

## İçindekiler

0. [Nasıl kullanılır + durum tablosu + yürütme sırası](#0-nasıl-kullanılır)
1. [Özet — tek sayfada](#1-özet)
2. [Bugünkü durum — editör editör denetim](#2-bugünkü-durum)
3. [Araştırma: alışık olunan uygulamalar telefonda nasıl düzenletiyor](#3-araştırma-alışık-olunan-uygulamalar)
4. [Teknik araştırma: klavye, editör motorları, akıcılık](#4-teknik-araştırma)
5. [Tasarım ilkeleri — "Office gibi, telefona göre"](#5-tasarım-ilkeleri)
6. [Kararlar (K18–K25)](#6-kararlar)
7. [Performans bütçeleri](#7-performans-bütçeleri)
8. [Test ve doğrulama stratejisi](#8-test-ve-doğrulama)
9. [Fazlar (Faz 20 – Faz 33)](#9-fazlar)
10. [Bilinçli kapsam dışı](#10-bilinçli-kapsam-dışı)
11. [Kaynaklar](#11-kaynaklar)

---

## 0. Nasıl kullanılır

- **Sıra:** faz numarası değil, aşağıdaki **yürütme sırası** tablosu. Önce ortak
  çekirdek (Faz 20), sonra Word'ün acil onarımı ve motor kararı (Faz 21), sonra
  en çok kazandıranlar.
- **Oturum açılışı:** fazın **"Açılış istemi"** kutusunu yeni oturuma yapıştır.
  İstem; bu belgenin ilgili bölümünü okumayı, kabul ölçütlerini sağlamayı,
  HAFIZA'ya yazmayı, durum tablosunu güncellemeyi ve main'e birleştirmeyi içerir.
- **Her fazın "bitti" tanımı** (`FAZ_PLANI.md` §0 ile aynı): `flutter analyze`
  0 sorun · `flutter test` yeşil (Flutter **3.44.6**) · kabul ölçütleri tek tek
  işaretli · HAFIZA'ya tarihli kayıt · bu belgede ve `FAZ_PLANI.md` durum
  tablosunda ✅ + tarih · main'e birleştirilmiş, CI yeşil · cihaz maddeleri
  `docs/CIHAZ_TESTI.md`'de.
- **Kararlar:** §6'daki K18–K25 ilgili fazın başında kullanıcıya sorulur; cevap
  yoksa **"Öneri"** uygulanır ve tabloya "(cevap yok, öneri uygulandı)" yazılır.
  **K18 istisnadır:** Faz 21'deki ölçümlü deneme + 📱 kontrol noktası olmadan
  verilmez.
- **Ortam işaretleri:** ☁️ bulut oturumunda baştan sona · 📱 telefon gerekir ·
  👤 kullanıcı kararı/hesabı. Bu planın **neredeyse tamamı ☁️**: Flutter
  editörleri `flutter test` ile (IME simülasyonu dahil) bulutta doğrulanır; Word
  WebView köprüsü Playwright + Chromium'da (`tool/check_word_bridge.js`).
  Telefon yalnız iki yerde şart: **Faz 21 sonundaki kısa kontrol noktası**
  (gerçek klavyelerle yazma hissi — kullanıcı kendi telefonunda nightly APK ile
  ~10 dk) ve **Faz 33 cihaz turu**.

### Durum tablosu

| Faz | Konu | Ön koşul | Ortam | Durum |
|---|---|---|---|---|
| 20 | **Ortak düzenleme çekirdeği** — geri al/yinele, taslak + otomatik kaydetme, klavye üstü çubuk, Aa paneli, kısayollar, ölçüm + **doğrulanmış 6 hata** | — | ☁️ | ✅ 2026-10-23 |
| 21 | **Word: canlı düzenlemenin acil onarımı + motor denemesi** (K18 kapısı) | 20 | ☁️ + 📱 kısa | ✅ 2026-10-23 (21a + 21b ölçüm; **K18 📱 kontrol noktası bekliyor**) |
| 22 | **Word Mobil görünüm editörü I** — belge modeli, yazma, seçim, yazım denetimi | 21 (K18) | ☁️ | ⬜ |
| 23 | **Word II** — biçimlendirme, Office şeridi, klavye üstü çubuk, Aa paneli, stiller | 22 | ☁️ | ⬜ |
| 24 | **Word III** — Ekle (tablo, resim, bağlantı), Düzen, üst/alt bilgi, Gözden Geçir | 23 | ☁️ | ⬜ |
| 25 | **Excel I** — veri girişi: hücre içi düzenleme, sayı/formül tuş takımı, işaret kipi, seçim tutamakları + doğruluk hataları | 20 | ☁️ | ✅ 2026-10-23 |
| 26 | **Excel II** — hesap motoru (bağımlılık grafiği) + büyük sayfa akıcılığı (ızgara çizimi) | 25 | ☁️ | 🟡 2026-10-23 26a kısmen (kalıcı motor + bağımlılık grafiği, `<v>`, O(n) düzeltmeleri); **kalan:** K23 ızgara denemesi, okuma sınırı şeridi, `test/perf` kıyasları, paylaş/indir kaydetmesi isolate'e |
| 27 | **Excel III** — Hücreleri biçimlendir, Veri, Görünüm, form görünümü, CSV düzenleme | 26 | ☁️ | ⬜ |
| 28 | **Slayt I** — yerinde metin düzenleme (kutuya yakınlaş), zengin metin, anahat, notlar | 20 | ☁️ | ⬜ |
| 29 | **Slayt II** — taşı/boyutlandır/döndür, şekil/metin kutusu/tablo ekle, düzenden yeni slayt, küçük resim şeridi | 28 | ☁️ | ⬜ |
| 30 | **Metin / kod / Markdown düzenleyici** | 20 | ☁️ | ⬜ |
| 31 | **PDF düzenleme deneyimi** — yerinde metin, nesne katmanı, ortak kabuk, sayfa üstünde form | 20 | ☁️ | ⬜ |
| 32 | **Görsel düzenleyici 2.0** — önizleme vekili, filtreler, taşınabilir metin, bulanıklaştır | 20 | ☁️ | ⬜ |
| 33 | **Kapanış** — tablet/donanım klavyesi, erişilebilirlik + RTL, Office uyumluluk turu, cihaz turu | 20–32 | ☁️ + 📱 | ⬜ |

### Yürütme sırası

| Sıra | İş | Neden bu sırada |
|---|---|---|
| D1 | **Faz 20** | Herkesin üstüne kurulacağı zemin; içindeki 6 doğrulanmış hata (biri Excel dosyasını Excel'de bozuyor) beklemeye gelmez |
| D2 | **Faz 21** (+ 📱 kontrol noktası) | Word en çok istenen ve bugün en kırılgan editör: Word'de kaydedilmiş çok sayfalı belgelerde canlı düzenleme büyük olasılıkla hiç açılmıyor (W1). Önce onarım, sonra veriye dayalı motor kararı |
| D3 | **Faz 25** | Excel'in çekirdeği olgun; giriş deneyimi düzelince en hızlı ve en görünür kazanç. K18 cevabını beklerken yapılır |
| D4 | **Faz 26** | Excel'de her tuşta tüm görünür formüller yeniden hesaplanıyor; 25'in yeni girişi akıcı olsun |
| D5 | **Faz 22** | K18 kararıyla Word'ün yeni editörü |
| D6 | **Faz 23** | Word biçimlendirme — kullanıcının "Office'e benzesin" isteğinin merkezi |
| D7 | **Faz 28** | Slaytta yazı düzeltme (bugün ~7 dp'lik yazıyla düzenleniyor) |
| D8 | **Faz 30** | Küçük ve bağımsız; çabuk kazanç |
| D9 | **Faz 24** | Word'ün geri kalanı |
| D10 | **Faz 27** | Excel'in geri kalanı |
| D11 | **Faz 29** | Slayt nesneleri |
| D12 | **Faz 32** | Görsel düzenleyici |
| D13 | **Faz 31** | PDF — çekirdeği (paragraf motoru) zaten var; deneyim cilası |
| D14 | **Faz 33** | Tüm cihaz maddeleri tek turda (FAZ_PLANI sıra 12 cihaz turuyla birleştirilebilir) |

> **FAZ_PLANI ile ilişki:** FAZ_PLANI §0.1 sıra 12 (cihaz turu) bekliyor. Bu
> plandaki işler bulut işi olduğu için cihaz turundan **önce** yürütülebilir;
> cihaz turu Faz 33'le birleştirilirse telefon oturumu bir kez yapılır.

---

## 1. Özet

**Ne istendi:** telefonda Word'de yazıyı değiştirmek, Excel'de veri girmek,
slayttaki yazıyı düzeltmek — **kolay, akıcı, tanıdık**. Masaüstü kadar derin
olması gerekmiyor; günlük işin rahat yapılması gerekiyor.

**Bugün ne var:** uygulama bu konuda sıfırdan başlamıyor — Excel'in kendi
ızgarası, 178 işlevli formül motoru, doldurma tutamağı, koşullu biçimi var;
Word'de sayfa görünümünde canlı yazma, B/I/U, renk, liste var; slaytta
kutunun üstünde yazma var; PDF'te paragraf yeniden dizen bir motor var. **Sorun
derinlik değil, yazma deneyiminin kendisi:**

1. **Word'de yazma kırılgan ve küçük.** Düzenleme, DOM paragraf sırası ↔
   `document.xml` paragraf sırası *indeks eşlemesine* dayanıyor. Gömülü
   docx-preview, Word'ün her kayıtta yazdığı `w:lastRenderedPageBreak`
   işaretinde paragrafı **ikiye bölüyor** (kaynakta doğrulandı) → sayı tutmuyor →
   sigorta canlı düzenlemeyi **kapatıyor**. Yani gerçek hayattaki çok sayfalı Word
   belgelerinin çoğunda "Düzenle" büyük olasılıkla çalışmıyor. Çalıştığında da:
   **Enter yeni paragraf açmıyor** (satır sonu ekliyor), paragraf başında geri
   silme düzenlemeyi kapatıyor, yazı sayfa ~0,5 ölçekte (11 pt ≈ 5–6 piksel)
   düzenleniyor, geri al yok, yazım denetimi kapalı, araç çubuğu klavyenin
   üstünde değil ekranın tepesinde, düzenlenen paragraftaki köprü/alan/dipnot
   başvurusu kaydette siliniyor.
2. **Excel'de giriş masaüstü mantığında.** 100 % yakınlaştırmada hücre içinde
   düzenleme hiç açılmıyor (30×72 dp eşiği) — her şey formül çubuğundan;
   sayı klavyesi yok; ok/Tab tuşları yok; formül yazarken hücreye dokunup
   başvuru eklenemiyor (dokunmak formülü onaylıyor); aralık genişletme
   tutamağı yok. **İki ciddi doğruluk hatası:** Türkçe işlev adları (`TOPLA`,
   `;`) dosyaya olduğu gibi yazılıyor → masaüstü Excel `#AD?` gösterir;
   satır/sütun silmek silinen satırın biçimini/yüksekliğini **üstteki satıra
   yazıyor**. Satır ekleyince formül başvuruları kaymıyor. Her tuş vuruşunda
   görünen bütün formüller yeni bir motorla baştan hesaplanıyor.
3. **Slaytta yazı mikroskobik.** Telefonda slayt ~0,37 ölçekte; 18 pt yazı
   ~7 dp'de düzenleniyor, kutuya yakınlaşma yok. Biçim tüm kutuya ya hep ya hiç;
   paragraf içi karışık biçim kayıtta kayboluyor; boş yer tutucuya yazılamıyor;
   şekil taşınamıyor/eklenemiyor; geri al yok.
4. **Ortak altyapı yok:** geri al yalnız Excel'de tam, otomatik kaydetme/taslak
   hiçbir editörde yok, PDF/görsel editörleri Office kabuğunun dışında, metin
   editöründe satır numaraları bir kaçış hatası yüzünden "$i" yazıyor.

**Strateji (tek paragraf):** *Tanıdık Office dili* (aynı sekme adları, aynı
simgeler, M365 mobilin "yazarken şerit gizli, klavyenin üstünde hızlı çubuk;
**Aa** ile biçim paneli" düzeni) + *telefona göre yazma yüzeyi* (Word'de
M365'in yaptığı gibi **Mobil görünümde** okunur boyutta yazma; slaytta kutuya
yakınlaşma; Excel'de Excel mobil/Numbers tarzı giriş ve uygulama içi sayı tuş
takımı) + *Flutter'ın yerel klavye altyapısı* (Android'de WebView
`contenteditable`'ın bilinen, bitmeyen klavye hataları yerine) + *ortak çekirdek*
(geri al/yinele, taslak ve otomatik kaydetme, isolate'te kaydetme) +
*ölçülen performans bütçeleri*. Dosya sadakati ilkesi korunur: özgün XML
korunur, yalnız dokunulan düğüm değişir, tanınmayan içerik silinmez.

---

## 2. Bugünkü durum

Kimlikler: **ED** ortak · **W** Word · **X** Excel · **SL** slayt · **PD** PDF ·
**TX** metin · **IM** görsel. (FAZ_PLANI'nin P/U/D/Y/F/N/I/C/S/B/L/G
kimlikleriyle çakışmasın diye.) ✔ = kodda yeniden doğrulandı.

### 2.1 Ortak

| # | Bulgu | Kanıt |
|---|---|---|
| ED1 | Ortak geri al/yinele yok. `core/undo_stack.dart` var; Excel tam kullanıyor, Word yalnız yedek editörde (paragraf ekle/sil), slayt ve metin editöründe hiç yok; PDF/kalem/görsel kendi listelerini tutuyor | `core/undo_stack.dart`, `sheet_edit.dart:612` |
| ED2 | **Otomatik kaydetme ve taslak (çökme kurtarma) hiçbir editörde yok**; Word'de çıkışta "kaydedilmedi" sorusu yalnız düzenleme kipindeyken | `word_editor_screen.dart:156-160` |
| ED3 | Kaydetme UI izleğinde senkron (Word `editor.save()` zip dahil, Excel `editor.save()`) — büyük dosyada donma | `docx_editor.dart:544-592`, `spreadsheet/file_ops.dart:10,44,51` |
| ED4 | Klavyeye bağlı araç çubuğu altyapısı yok: Word ve Excel'in şeridi tepede, klavye açıkken alt çubuk klavyenin arkasında | `office_shell.dart:189-195`, `word/shell.dart:222-291` |
| ED5 | PDF düzenleyici, PDF kalem, görsel düzenleyici düz `Scaffold` + `NavigationBar` — Office editörleriyle aynı görünmüyor | `pdf_editor_screen.dart`, `image_edit_screen.dart` |
| ED6 | Donanım klavyesi kısayolu (Ctrl+Z/B/…) hiçbir editörde yok; Excel'de ok/Tab işlemiyor | `spreadsheet/*` (`Shortcuts` yok) |

### 2.2 Word (.docx)

Mimari: WebView + gömülü docx-preview 0.3.7 → "Düzenle" ile sayfa
`contenteditable` olur; paragraf değişince 250 ms sonra segmanlar
(`[metin,b,i,u,yazıtipi,boyut,renk,vurgu]`) Dart'a gider, `DocxEditor.setRuns`
paragrafı yeniden kurar. Yedek: paragraf başına bir `TextFormField`.

| # | Bulgu | Kanıt | Etki |
|---|---|---|---|
| W1 ✔ | **Sayfa kırmada paragraf bölünüyor → canlı düzenleme kapanıyor.** `breakPages:true` + `ignoreLastRenderedPageBreak:false`; docx-preview `splitBySection` `w:lastRenderedPageBreak` (ve sayfa sonu) içeren paragrafı iki `<p>`'ye ayırıyor; DOM sayısı > `w:p` sayısı → `_onParagraphCount` düzenlemeyi kapatıyor. Word bu işareti her kayıtta yazar | `assets/word/viewer.html:158-162, 315-321`; docx-preview `splitBySection`; `word/actions.dart:77-83` | Word'de kaydedilmiş çok sayfalı belgelerin çoğunda "Düzenle" çalışmıyor olabilir. Köprü testi tek sayfalık örnekle koşuyor, yakalamıyor |
| W2 | **Enter yeni paragraf açmıyor** (`insertLineBreak` → `w:br`) | `viewer.html:698-704` | Word'deki en temel hareket yok |
| W3 | Paragraf başında geri silme / paragraflar arası seçimi silmek → `structureChanged` → düzenleme kapanıyor; içinde `\n` olan yapıştırma da | `viewer.html:651-661, 691, 705-710` | Yazarken "düzenleme kendiliğinden kapandı" |
| W4 | **`setRuns` içerik siliyor:** düzenlenen paragraftaki köprü, alan, yer imi, dipnot başvurusu, sekme, satır içi resim kayboluyor; paragraf içi farklı biçimler ilk run'ın `rPr`'iyle eziliyor; stilden gelen kalın `w:b` olarak gömülüyor, kapatılamıyor (`w:val="0"` yazılmıyor) | `docx_editor.dart:268-314, 814-817` | Sessiz veri kaybı |
| W5 | Canlı kipte geri al/yinele yok (düğmeler hep pasif) | `word_editor_screen.dart:167-172` | |
| W6 | Yazı sayfa görünümünde ~0,5 ölçekte düzenleniyor (11 pt ≈ 5–6 px); klavye açılıp kapanınca `fitPage` iki kez yeniden yerleşim | `viewer.html:97-100, 1069` | Okunmaz, zahmetli |
| W7 | Biçim çubuğu tepede (`AppBar.bottom`), klavyenin üstünde değil; hizalama/liste/renk durumu yansımıyor; üstü çizili ve iki yana yasla düğmesi yok | `word/shell.dart:222-291, 241-246` | |
| W8 | Yazım denetimi, otomatik düzeltme, otomatik büyük harf bilinçli KAPALI | `viewer.html:331-333` | Telefon klavyesinin yarısı devre dışı |
| W9 | Resim ekle/sil tüm belgeyi baştan çiziyor: imleç başa atlıyor, geri al yığını siliniyor | `word/actions.dart:307-321` | |
| W10 | Eksik: stiller (Başlık 1…), girinti, satır aralığı, liste düzeyi, tablo satır/sütun, resim boyutu, sayfa sonu, üst/alt bilgi düzenleme, köprü ekleme, yorum, izlenen değişiklik, sözcük sayısı | denetim | |
| W11 | Yedek editör: tüm paragrafları tek seferde kuruyor (sanal liste değil); **canlı kipte düzenlenmiş (`rich`) bir paragraf yedek editörde değiştirilirse kayıtta atlanıyor** (doğrulanmalı — `save()` `rich` paragrafı atlıyor ✔) | `word/page.dart:6-50`, `docx_editor.dart:543-550` | Sessiz veri kaybı olasılığı |
| W12 | Her paragraf gönderiminde tüm belge sorgusu (`paraList()`), her öğede `getComputedStyle`; kaydırma her karede köprüye mesaj | `viewer.html:654, 1114-1127` | Düşük cihazda yazma kasması |

**Zaten iyi olanlar (korunacak):** sayfa görünümünün sadakati (okuma için),
Türkçe katlamalı bul/değiştir, seçimi çevir / AI ile düzelt köprüsü, Symbol/
Wingdings madde imi düzeltmesi, RTL (`docx_rtl_test`), liste için `w:numPr` +
üretilen `numbering.xml`.

### 2.3 Excel (.xlsx)

Mimari: `XlsxSheet.rows` (yoğun metin) + `layout.cells` (seyrek; stil, önbellek
değeri) iki kopya; okuma `compute()`'ta; çizim hücre başına widget ağacı
(MetaData → GestureDetector → CustomPaint → Align → Text), satırlar
`ListView.builder`, sütunlar elle pencereleme, 4 `ScrollController` eşitlemesi;
kaydetme özgün paketi koruyan kendi yazıcımız (`XlsxPackageWriter` +
`XlsxSavePatch`).

| # | Bulgu | Kanıt | Etki |
|---|---|---|---|
| X1 ✔ | **Türkçe işlev adı ve `;` dosyaya ham yazılıyor.** Motor `TOPLA(A1;A2)`'yi hesaplıyor, otomatik tamamlama Türkçe adları öneriyor; `XlsxPackageWriter` formülü olduğu gibi `<f>` içine yazıyor | `formula_engine.dart:585-775`, `formula/parser.dart:199,234`, `xlsx_package.dart:564-566` | Masaüstü Excel / Google E-Tablolar `#AD?` gösterir — **dosya bozulmuş gibi görünür** |
| X2 ✔ | **Satır/sütun silme, silinen satırın hücre stillerini, yüksekliğini, gizli bayrağını bir üstteki satıra yazıyor** (`_shiftLayoutRows/_shiftKeys/_shiftSet` `k == at`'i düşürmüyor) | `xlsx_editor.dart:893-985` | Silmeden sonra üst satırın biçimi değişir |
| X3 | Satır/sütun ekle-silde **formül başvuruları**, birleştirmeler, koşullu biçim, doğrulama, not, autoFilter ve oturum biçim haritaları kaydırılmıyor | `xlsx_editor.dart:855-984` | `=TOPLA(A1:A10)` satır ekleyince yanlış aralık |
| X4 | Sıralama formül hücrelerini SONUÇLA değil formül METNİYLE karşılaştırıyor; ve O(n²) (`captureRow` her satırda `maxCols` tarıyor) | `headers.dart:163-190`, `xlsx_editor.dart:776` | Yanlış sıra; 10 bin satırda ~100 M işlem |
| X5 | 100 % yakınlaştırmada hücre içi düzenleme açılmıyor (≥ 30×72 dp eşiği; varsayılan hücre ~20×64) → hep formül çubuğu | `spreadsheet_editor_screen.dart:290-291`, `edit_ops.dart:277-288` | Excel mobil gibi değil |
| X6 | Klavye: `keyboardType` yok (sayı klavyesi yok), ok/Tab yok, klavye üstü çubuk yok; Enter son satırda duruyor; ızgara kullanılan alan + 60×26'da bitiyor | `edit_ops.dart:116-120, 357-362` | Veri girişi yavaş |
| X7 | Formül yazarken hücreye dokunmak formülü onaylıyor — **başvuru ekleme (işaret kipi) yok**; işlev ipucu (bağımsız değişken) yok | `edit_ops.dart:340-349`, `formula_bar.dart:177-244` | Telefonda formül yazmak zor |
| X8 | Tek dikdörtgen seçim; aralık genişletme tutamağı yok (`_select(extend:)` hiç çağrılmıyor); her seçili hücre kendi çerçevesini çiziyor | `grid.dart:224-271`, `sheet_cell.dart:233-240` | |
| X9 | **Her `setState`'te** (formül çubuğunda her tuş) yeni `FormulaEngine` (ızgara + önizleme + durum çubuğu = 3), görünür bütün formüller baştan; `maxCols` her çağrıda tüm satırları tarıyor; `mergeAt`/`condRuleAt` hücre başına doğrusal; renk ölçeği min/max her çizimde | `grid.dart:8`, `formula_bar.dart:252`, `dialogs.dart:173-198`, `xlsx_editor.dart:175-201`, `widgets.dart:157-178` | Büyük sayfada yazarken kasma |
| X10 | Formüller önbellek değeri (`<v>`) olmadan yazılıyor | `xlsx_package.dart:37-59, 564` | Excel dışı önizleyicilerde (e-posta/Drive önizlemesi) formül hücreleri boş |
| X11 | Bölme dondurma **oluşturulamıyor** (yalnız var olan açılıp kapanıyor); süzgeç **oluşturulamıyor**; dikey hizalama/girinti/döndürme, üstü çizili/altı çizili, özel sayı biçimi, kalın/çift kenarlık düzenlenemiyor; sütun boyutu ve sayfa işlemleri geri alınamıyor | `file_ops.dart:112-129`, `ribbon.dart:294-302`, `dialogs.dart:91-159` | |
| X12 | Grafik ve görseller ızgarada çizilmiyor (eklenen bile); CSV/TSV yalnız salt okunur görüntüleyicide açılıyor | `ribbon.dart:384-414`, `file_service.dart:176-196` | |

**Zaten iyi olanlar:** formül motoru (178 işlev, Türkçe takma adlar, Excel hata
değerleri), canlı sonuç önizlemesi, doldurma tutamağı (çapraz + çift dokunuş),
iç pano (başvuru kaydırmalı, biçim dahil), koşullu biçim çizimi, metin taşması
ve otomatik satır yüksekliği, ham-pointer pinch zoom, 17 widget testi.

### 2.4 Slayt (.pptx)

| # | Bulgu | Kanıt |
|---|---|---|
| SL1 ✔ | Yazılan `\n` `a:t` içine ham yazılıyor (`a:br`/yeni `a:p` değil); `a:t`'si olmayan (boş) paragrafa yazılan metin **kaydedilmiyor** (`_writeText` erken dönüyor) | `pptx_editor.dart:108-115, 470-479` |
| SL2 | Paragraf metni ilk `a:t`'ye toplanıp diğerleri boşaltılıyor → **paragraf içi karışık biçim (bir kelimesi kalın) kayboluyor** | `pptx_editor.dart:470-479` |
| SL3 | Yazı ~0,37 ölçekte (18 pt ≈ 7 dp) düzenleniyor; kutuya yakınlaşma yok | `slides/views.dart:85-132` |
| SL4 | Biçim (B/I/U/punto) tüm kutuya ya hep ya hiç; yazarken görünmüyor (TextField stili ilk run'dan) ; renk/hizalama/madde yok | `slides/views.dart:541-572`, `slide_canvas.dart:395-405` |
| SL5 | Yalnız metni olan şekle dokunulabiliyor → boş yer tutucu ("Başlık eklemek için dokunun") doldurulamıyor | `slide_canvas.dart:132` |
| SL6 | Geri al/yinele yok; şekil taşı/boyutlandır/ekle yok; düzenden yeni slayt yok; küçük resim şeridi yok; notlar salt okunur | denetim |
| SL7 | Tüm deste UI izleğinde ayrıştırılıp çiziliyor; her paragraf onayında slayt baştan çiziliyor; `_fitScale` her build'de iki geçiş | `slides/actions.dart:16-24`, `pptx_editor.dart:397,433`, `slide_canvas.dart:324-356` |

**İyi olanlar:** kendi çizicimizin sadakati, yerinde (kutunun üstünde) yazma
fikri, klavye üstünde biçim çubuğu (Word'den önde!), sunum modu, görsel ekleme.

### 2.5 PDF

| # | Bulgu | Kanıt |
|---|---|---|
| PD1 | Metin düzenleme **diyalogda** (8 satırlık alan), sayfa üzerinde değil | `pdf_editor/views.dart:431-533` |
| PD2 | Reddedilen durumlar (yazı tipinde harf yok, sığmıyor …) yalnız hata olarak; tek dokunuşla alternatif yok | `pdf_paragraph_layout.dart:81-160` |
| PD3 | "Yazı ekle" sonradan taşınamıyor/düzenlenemiyor (damga), tek yazı tipi ve renk | `pdf_text_stamp.dart` |
| PD4 | Her işlem: tüm dosyanın anlık görüntüsü + tam yazma + görüntüleyiciyi yeniden yükleme; yinele yok | `pdf_editor/actions.dart:90-104` |
| PD5 | Formlar sayfada değil, liste olarak dolduruluyor | `pdf_form_screen.dart` |
| PD6 | Görsel yalnız bir köşeden boyutlanıyor; `InkPainter.shouldRepaint` hep true | `pdf_edit_overlay.dart:198-296`, `pdf_ink/widgets.dart:118` |

### 2.6 Metin / kod / Markdown

| # | Bulgu | Kanıt |
|---|---|---|
| TX1 ✔ | **Satır numaraları her satırda "$i" yazıyor** (`'\$i'` kaçış hatası) | `screens/viewer/widgets.dart:66` |
| TX2 | Satır numarası sütunu sarmalı satırda kayıyor; her tuşta tüm metin bölünüp N `Text` yeniden kuruluyor | `widgets.dart:34-86` |
| TX3 | Sözdizimi renklendirme, Markdown önizleme, geri al/yinele düğmesi, klavye üstü çubuk yok | denetim |
| TX4 | 5 MB'a kadar tek `TextField` tüm belgeyi yerleştiriyor | `viewer/widgets.dart` |

### 2.7 Görsel düzenleyici

| # | Bulgu | Kanıt |
|---|---|---|
| IM1 | Her kaydırıcı adımında tam çözünürlüklü görüntü (8192 px'e kadar) renk matrisiyle yeniden boyanıyor → kasma | `image_edit.dart:175-195` |
| IM2 | İşaretlemede her noktada tüm nokta listesi kopyalanıp `setState` | `image_edit_screen.dart:394-398` |
| IM3 | Kanvasta yakınlaştırma/kaydırma yok; metin diyalogla, boyutsuz, sonradan taşınamıyor; fırça kalınlığı sabit | `image_edit_screen.dart:383-440, 590-645`, `image_edit.dart:122` |
| IM4 | Filtre, serbest döndürme, dikey çevirme, bulanıklaştırma, şekil, silgi yok; yinele yok; kaydırıcı geri al sınırını (30) aşıyor | `image_edit_screen.dart:102-106, 768` |

---

## 3. Araştırma: alışık olunan uygulamalar

Ayrıntılı bağlantılar §11'de.

### 3.1 Microsoft 365 — Word (Android telefon)

- **Şerit gizli yazılır.** Şerit "Şeridi göster" (kalem/yukarı ok) ile açılır;
  sekmeler **Giriş · Ekle · Çiz · Düzen · Gözden Geçir · Görünüm**. Microsoft'un
  kendi ipucu: *"Yazmak istiyorsan önce şeridi gizle."* Geri tuşu önce klavyeyi,
  sonra şeridi kapatır.
- **Mobil görünüm (reflow):** belge önce *Yazdırma Düzeni*nde açılır; üstteki
  düğmeyle **Mobil görünüm**e geçilir — telefonda **okuma, metin düzenleme ve
  yorum** için. Düzeni değiştiren işlemlerde (üst/alt bilgi, resim boyutlandırma/
  döndürme) Word kendiliğinden Yazdırma Düzeni'ne döner.
  → *Bizim için ders:* telefonda yazmanın doğru yüzeyi sayfanın küçültülmüş
  hâli değil, **ekran genişliğine akan metin**.
- Seçim: çift dokunuş kelime, **üç dokunuş paragraf**, tutamaklarla genişletme.

### 3.2 Microsoft 365 — Excel (Android)

- **Dokun = seç, çift dokun = hücrede düzenle**; hassas düzenleme için
  formül çubuğuna dokun → imleç, **✓** ile onay. Çift dokunuş beceriksizce
  yapılırsa yeni giriş başlatıp içeriği silebiliyor (bilinen tuzak → bizde
  "yazmaya başlamak değiştirir, düzenlemek için ikinci dokunuş" ayrımı net
  olmalı).
- **fx** düğmesi işlev kitaplığını açar; Formüller > **Otomatik Toplam**.
- Seçim tutamağını sürükle = aralık; **tutamağı fırlat = veri kenarına kadar**.
- Sayı biçimli hücrede Android'de sayı klavyesi kendiliğinden geliyor (forum
  raporu); "123" ile elle geçiş. Microsoft Garage bir dönem tabletler için
  ayrı bir **"Keyboard for Excel"** (sayı + işleç tuş takımı) yayımladı —
  sistem klavyesinin elektronik tablo için yetersiz olduğunun kabulü.

### 3.3 Google E-Tablolar / Dokümanlar

- E-Tablolar: köşede doldurma tutamağı; mobilde **bağlam menüsünden
  "Otomatik doldur"**; seri sürdürme (1,2,3 → 4,5,6).
- Dokümanlar telefonda **"A" (Biçim)** düğmesiyle alttan **Metin / Paragraf**
  sekmeli panel; tabletlerde (2024) **yazarken açık kalan sağ biçim paneli**,
  geri al/yinele hep üst sağda. Alt kenarda yatay kayan biçim çubuğu deneniyor.
  → *Ders:* biçim paneli **yazmayı bölmemeli**; telefonda alttan panel, tablette
  yan panel.

### 3.4 Apple Numbers

- **Formül klavyesi** ve iPhone'da ayrı **sayı klavyesi**; tuşu aşağı
  sürükleyip bırakarak ikinci karakteri girme. → *Ders:* elektronik tabloya
  **uygulamanın kendi tuş takımı** (K20).

### 3.5 Microsoft 365 — PowerPoint (Android)

- **Dokun = nesneyi seç** (tutamaklar), **çift dokun = metin kutusunda klavye**;
  tutamakla boyutlandır, döndürme tutamağıyla döndür; Microsoft'un ipucu:
  *"şekli ekle, seçimi bırak, **yakınlaş**, sonra boyutlandır/döndür."*
  → *Ders:* küçük ekranda **düzenlerken yakınlaşma** işin parçası; biz bunu
  kendiliğinden yapalım (kutuya yakınlaş).
- Düzen/asıl slayttaki kutular mobilde tutamaksız olabiliyor (yer tutucu
  kalıtımı) — biz yer tutucuyu slayta kopyalayarak düzenletiriz.

### 3.6 WPS / Polaris (rakip)

- WPS < 35 MB, tek uygulamada tüm ofis; Word'e benzeyen araç çubuğu; araçlar
  menüsü şeritte. Ekran düzeni sürüme göre değişiyor; ortak payda: **alt kenarda
  "Araçlar" paneli + klavye üstü kısa çubuk.**

### 3.7 Ortak desen (bizim tasarımın iskeleti)

| Durum | Ne görünür |
|---|---|
| Okuma | Belge + üstte ince çubuk (geri, ad, ↶ ↷ yok) + alt eylem çubuğu |
| Düzenleme, klavye **kapalı** | Üst çubuk (geri · ad + "Kaydedildi" · ↶ · ↷ · ⋮) + **sekmeli şerit** (Giriş/Ekle/…) |
| Düzenleme, klavye **açık** | Üst çubuk + **klavyenin hemen üstünde tek satır hızlı çubuk** (K T A, liste, hizalama, renk, **Aa**, ⌄) — şerit gizli |
| **Aa** | Klavye iner, **aynı yükseklikte** biçim paneli çıkar (Yazı · Paragraf · Stiller); belge kıpırdamaz; klavye simgesiyle geri |
| Seçim | Yerel tutamaklar + büyüteç + bağlam çubuğu (Kes · Kopyala · Yapıştır · Biçim · Çevir · AI) |

---

## 4. Teknik araştırma

### 4.1 Android klavyesi ve `contenteditable` — neden WebView'da yazma kırılgan

- Android IME'leri (`Gboard`, `Samsung Klavye`, `SwiftKey`) WebView'daki
  `contenteditable`'ı **tek uzun düz metin** gibi görür; HTML yapısı bundan
  sapar (ProseMirror ekibi). W3C editing görev gücü yazışmalarındaki raporlar
  (2017–2018): Gboard'da birleştirme olayları eksik ya da yanlış türde,
  `keydown.preventDefault()` etkisiz (Chromium mühendisi "hata gibi" dedi),
  `beforeinput` atlanabiliyor; Gboard paylaşılan metni doğrudan değiştirip
  `preventDefault`'u yok sayabiliyor; Samsung klavyede WebView içinde **yeni
  satır yağmuru** — geçici çözümü "kırılgan, klavye güncellemesiyle bozulabilir".
- Sorun eski ama **bitmedi**: ProseMirror 2025'te hâlâ Android klavye düzeltmesi
  yayımlıyor (1.40.1: bazı Android klavyelerde resimli bloklarda geri silme
  Enter sayılıyor; 1.41.2: SwiftKey'de geri silme Enter sayılıyor).
- **Bizim koddaki karşılığı:** Enter'ı `keydown`'da yakalıyoruz (W2), yapıştırmayı
  düz metne indiriyoruz, yazım denetimini kapatıyoruz (W8) — hepsi bu sınıfın
  yamaları. Kalıcı olarak düzelmez, ancak **kovalanır**.

### 4.2 Flutter'ın metin girişi

- Flutter Android'de klavyeye kendi `InputConnection`'ıyla bağlanır — uygulamadaki
  diğer bütün metin alanlarının (Excel formül çubuğu, slayt kutusu, arama) zaten
  kullandığı yol; WebView/Chromium'un `contenteditable` katmanı araya girmez.
- **Belge editörleri için delta modeli:** `TextInputConfiguration(
  enableDeltaModel: true)` + `DeltaTextInputClient.updateEditingValueWithDeltas`
  → klavye değişiklikleri ekleme/silme/değiştirme/birleştirme-bölgesi deltaları
  olarak gelir; IME'ye belgenin tamamı değil **yalnız imlecin paragrafı**
  verilebilir (super_editor'ün mimarisi). Android tarafında
  `enableIMEPersonalizedLearning` ayrı (Gboard öğrenmesi).
- **Kalemle el yazısı (Scribe):** `EditableText.stylusHandwritingEnabled` —
  Android 14+ ve etkin kalemde `TextField`'da kendiliğinden.
- **Yazım denetimi:** `SpellCheckConfiguration` (Android'in yazım denetimi
  servisi) — kırmızı dalga + öneri menüsü.
- **Test edilebilirlik:** `tester.testTextInput` ile IME (birleştirme bölgesi,
  delta) bulutta `flutter test`'le simüle edilir → editör davranışı telefon
  olmadan doğrulanır. WebView köprüsü ise yalnız Playwright/Chromium'da
  (Android WebView ≠ masaüstü Chromium klavye davranışı) ve gerçek telefonda.
- **Klavye animasyonu:** Android 11+ `WindowInsetsAnimation` ile ekleme
  payı kare kare değişir; Flutter motoru IME eklemesini eşzamanlamaya çalışıyor
  ama üçüncü taraf paketler (`flutter_keyboard_controller`, `keyboard_insets`)
  "Scaffold gövdesi animasyon sonunda tek sıçramada küçülüyor" diyor →
  **Faz 20'de ölçülür**, gerekirse klavye üstü çubuk kendi yerel eklem dinleyicisi
  (Kotlin, `WindowInsetsAnimationCompat`) ile sürülür.

### 4.3 Word editörü için motor seçenekleri

| Seçenek | Artı | Eksi | Değerlendirme |
|---|---|---|---|
| **(a)** Bugünkü WebView `contenteditable`'ı onarmak | Sayfa görünümünde WYSIWYG; mevcut kod | §4.1'in bitmeyen klavye kuyruğu; indeks eşleme; 0,5 ölçekte yazma; her yapısal işlem köprü + yeniden çizim; testleri yalnız Playwright/cihaz; WebView belleği | **Kısa vadede onar (Faz 21a)**, kalıcı yüzey yapma |
| **(b)** Flutter-yerel **Mobil görünüm** editörü + kendi DOCX modelimiz | Yerel IME (Gboard/Samsung motor tarafından), delta modeli, yazım denetimi, Scribe, yerel tutamak/büyüteç; 120 Hz; **bulutta `flutter test`le tam test**; okunur boyut; M365'in telefondaki yaklaşımı | Yapım emeği; sayfa düzenini birebir göstermez (önizleme WebView'da kalır) | **Öneri (K18)** |
| (b-i) …motor olarak **super_editor** (MIT) | Olgun belge editörü, mobil IME + tutamaklar, belge düzeyi seçim | Kararlı sürüm uzun süredir yok (0.3.0-dev.x), API değişken, bağımlılık ağacı, sürüm duvarı riski | Faz 21b'de ölçülür |
| (b-ii) …**kendi ince çekirdeğimiz** (belge düzeyinde tek `DeltaTextInputClient`, IME'ye yalnız imlecin paragrafı; düzen `RenderParagraph`) | Bağımlılık yok, tam kontrol, yalnız ihtiyacımız kadar | Seçim/tutamak/büyüteç elle | Faz 21b'de ölçülür |
| (b-iii) Paragraf başına ayrı `TextField` | Basit | Paragraflar arası seçim yok; boş paragrafta geri silme klavyeye göre olay üretmiyor | **Reddedilir** (yalnız bugünkü yedek editörde kalır) |
| (c) WebView içinde **ProseMirror** (MIT) + DOCX↔şema | Web'in en iyi editörü | Yine `contenteditable` (4.1); iki dil, iki model; test yine Playwright | Reddedilir |
| (d) Gömülü **LibreOffice / Collabora** (MPL-2.0) | Tam sadakat | APK **+70–75 MB** (Collabora Office Android 25.04 ≈ 74 MB), yerel derleme zinciri; "sade, hızlı" ilkesine aykırı | Reddedilir |
| (e) OnlyOffice | — | AGPL + sunucu; 2026-07-20'de reddedildi | Reddedilir |

### 4.4 Excel ızgarası için çizim seçenekleri

- Bugün: hücre başına 5 katmanlı widget ağacı + elle sütun pencereleme +
  4 kaydırıcı eşitlemesi.
- **Tek boyacı** (görünür bölgeyi tek `RenderBox`/`CustomPainter` çizer, metin
  düzeni LRU önbellekte) — Sheets/Excel'in yaptığı.
- **`two_dimensional_scrollables` `TableView`** (Flutter ekibi, BSD-3): iki
  boyutlu tembel kurulum, `pinnedRowCount/pinnedColumnCount` = **bölme dondurma**
  doğal. Hücre hâlâ widget ama tek kaydırma sistemi.
- Karar K23 — Faz 26 başında ölçümlü deneme.

### 4.5 Metin/kod editörü

- **`re_editor`** (Reqable, MIT): büyük metin için düzeni/çizimi/olayları
  kendisi yapıyor (TextField sarmalayıcısı değil), `re_highlight` ile ~100 dil,
  kod katlama. Etkinlik/bakım ve Türkçe IME Faz 30 başında denenir (K25).

---

## 5. Tasarım ilkeleri

1. **Tanıdık dil.** Sekme adları Türkçe Office'le aynı:
   Word **Giriş · Ekle · Düzen · Gözden Geçir · Görünüm**; Excel **Giriş · Ekle ·
   Formüller · Veri · Gözden Geçir · Görünüm**; PowerPoint **Giriş · Ekle ·
   Tasarım · Geçişler · Slayt Gösterisi · Görünüm**. Simgeler tek kaynaktan
   (`OfficeIcons`). Bağlamsal sekme: tabloya dokununca **Tablo**, resme
   dokununca **Resim**, şekle dokununca **Şekil** (Office'teki gibi renkli).
2. **Yazarken şerit gizli, araç klavyenin üstünde.** Klavye açıkken tek satır
   (44 dp, yatay kayan) hızlı çubuk; klavye kapanınca sekmeli şerit. Geri tuşu:
   önce panel/klavye, sonra seçim, sonra düzenleme kipi, en son ekran.
3. **"Aa" paneli klavyenin yerini alır**, belge zıplamaz: son klavye yüksekliği
   hatırlanır, panel o yükseklikte açılır (mesajlaşma uygulamalarının emoji
   paneli davranışı). Panelde sekmeler; panelde yapılan değişiklik **canlı**
   belgeye yansır.
4. **Yazı okunur boyutta düzenlenir.** Word'de Mobil görünüm; slaytta kutuya
   yakınlaş; Excel'de hücre editörü en az 16 sp; PDF'te paragrafın üstünde
   yakınlaştırılmış alan. Hiçbir yerde 5–7 px yazıyla düzenleme yok.
5. **Her şey geri alınabilir.** ↶ ↷ hep üst çubukta; yazma kelime/duraklama
   gruplarıyla geri alınır (Word gibi); yapısal ve biçim işlemleri tek adım.
6. **İş kaybolmaz.** Taslak günlüğü (çökme/pil bitmesi), otomatik kaydetme
   (K21), "Kaydediliyor… / Kaydedildi 14:32" durumu, çıkışta tek tip soru.
7. **Akıcılık bir özellik.** Tuşla ekrandaki harf arası ≤ 1 kare; kaydetme,
   ayrıştırma, yeniden hesaplama ve ağır çizim UI izleğinde değil; düzenleme
   hiçbir zaman tüm belgeyi yeniden çizmez; modal diyalog yerine panel.
   Bütçeler §7'de, her faz ölçer.
8. **Seçim yerel ve cömert.** Çift dokunuş kelime, üç dokunuş paragraf,
   tutamak + büyüteç, bağlam çubuğu; Excel'de tutamakla aralık + fırlatma.
9. **Sadakat:** özgün XML korunur, yalnız dokunulan düğüm değişir; tanınmayan
   içerik (alan kodu, köprü, yer imi, içerik denetimi, SmartArt) **dokunulmaz
   ada** olarak gösterilir ve korunur, sessizce silinmez.
10. **Telefona özel kolaylıklar** (masaüstünde olmayan): Word **anahat/gezinti**
    (başlıklara atla), Excel **form görünümü** (satırı kart olarak doldur),
    slayt **anahat görünümü** (tüm metinleri tek listede düzelt), PDF/görselde
    **bulanıklaştır** (kişisel bilgi gizleme).
11. **Herkes için:** TalkBack etiketleri ("Kalın, açık"), 2,0× yazı ölçeğinde
    taşmayan şerit, Arapça (RTL) yazma her editörde, donanım klavyesi kısayolları.

### 5.1 Ekran şemaları

**Word — Mobil görünümde yazarken (klavye açık)**
```
┌───────────────────────────────────────┐
│ ←  Rapor.docx            ↶  ↷   ⋮    │  ← üst çubuk; altında "Kaydedildi 14:32"
│    Word · Kaydedildi 14:32            │
├───────────────────────────────────────┤
│ Başlık 1                               │
│ Proje Özeti                            │  ← ekran genişliğine akan metin,
│                                        │    gerçek punto oranları
│ Bu raporda 2026 yılının ilk yarısında  │
│ yapılan çalışmalar|                    │  ← yerel imleç + tutamaklar
│ • Saha ölçümleri                       │
├───────────────────────────────────────┤
│ ↶ │ K │ T │ A │ • │ 1. │ ⇤ ⇥ │ ≡ │ A̲ │ Aa │ ⌄ │  ← klavye üstü çubuk
├───────────────────────────────────────┤
│            [ Android klavyesi ]        │
└───────────────────────────────────────┘
```

**Word — "Aa" paneli (klavyenin yerinde, aynı yükseklikte)**
```
├───────────────────────────────────────┤
│  Yazı   │  Paragraf  │  Stiller   ⌨   │
│  Calibri ▾        11 ─●──── [11]  − + │
│  [K] [T] [A] [S] [x²] [x₂]  Temizle   │
│  Renk  ● ● ● ● ● ● ● ●  Vurgu ● ● ●   │
└───────────────────────────────────────┘
```

**Excel — sayı girerken (uygulama tuş takımı)**
```
│ B4 │ fx │ =TOPLA(B1:B3)          ✗ ✓ │  ← formül çubuğu, B1:B3 mavi
├────┬─────────┬─────────┬─────────────┤
│    │    A    │    B    │      C      │
│  1 │ Ocak    │ ┊ 1.250 ┊ (mavi çerçeve)│
│  2 │ Şubat   │ ┊   980 ┊             │
│  3 │ Mart    │ ┊ 1.430 ┊             │
│  4 │ Toplam  │ [=TOPLA(B1:B3)|]      │  ← hücre içi editör
├───────────────────────────────────────┤
│ ← → ↑ ↓ │ ⇥ │ ↵ │ = │ Σ │ fx │ ABC  │  ← klavye üstü çubuk
│  7  8  9  │  +  −  ( )  │  ⌫         │
│  4  5  6  │  ×  ÷  ;  : │  $         │  ← uygulama içi tuş takımı
│  1  2  3  │  %  ^  =  & │  ↵         │
│  0   ,    │  <  >  " "  │  ⇥         │
└───────────────────────────────────────┘
```

**Slayt — kutuya yakınlaşmış düzenleme**
```
┌───────────────────────────────────────┐
│ ←  Sunum.pptx · 3/12      ↶  ↷   ✓   │
├───────────────────────────────────────┤
│   ┌─────────────────────────────────┐ │  ← kanvas kutuya yakınlaştı
│   │ 2026 Hedefleri|                 │ │    (yazı ≈ 16–20 sp)
│   └─────────────────────────────────┘ │
├───────────────────────────────────────┤
│ ↶ │ K │ T │ A │ − 24 + │ ● │ ≡ │ • │ Aa │ ⌄ │
├───────────────────────────────────────┤
│            [ Android klavyesi ]        │
└───────────────────────────────────────┘
```

---

## 6. Kararlar

| # | Soru | Seçenekler | Öneri | Faz | Karar |
|---|---|---|---|---|---|
| K18 | **Word'ün kalıcı düzenleme yüzeyi/motoru** | (a) bugünkü WebView `contenteditable` onarılarak sürer · (b) Flutter-yerel **Mobil görünüm** editörü + kendi DOCX modelimiz — motor (b-i) super_editor ya da (b-ii) kendi ince çekirdeğimiz · (c) WebView'da ProseMirror · (d) gömülü LibreOffice/Collabora | **(b)**; b-i/b-ii seçimi Faz 21b ölçümüyle; (a) yalnız geçiş dönemi için onarılır (21a). (c)(d) reddedilir — §4.3 | 21, 22 | |
| K19 | **Sayfa görünümünde (yazdırma düzeni) düzenleme** | (a) kalsın (onarılmış WebView yolu) · (b) Faz 22–23 eşdeğerliğe ulaşınca sayfa görünümü salt okunur önizleme; "Düzenle" Mobil görünümü açar (M365 dili) | **Geçişte (a), Faz 23 bitince (b)**. Kullanıcıya ayar sunulmaz (sadelik) | 21, 23 | |
| K20 | **Excel'de sayı/formül girişi** | (a) sistem klavyesi (+ sayı kipi) · (b) **uygulama içi sayı/formül tuş takımı** + tek dokunuşla sistem klavyesine geçiş | **(b)** — işleçler, `;`, `:`, `$`, parantez, oklar tek ekranda; sayı biçimli hücrede kendiliğinden | 25 | |
| K21 | **Otomatik kaydetme** | (a) yok (bugün) · (b) her zaman özgün dosyaya (M365) · (c) **taslak günlüğü her zaman** + dosyaya otomatik kaydetme ayarı | **(c), ayar varsayılan AÇIK**; başka uygulamadan gelen ve geri yazılamayan dosyalarda (`content://` salt okunur, e-posta eki) ilk kayıtta "Kopya olarak kaydet" önerisi | 20 | |
| K22 | **Formül dili** | (a) dosyadaki gibi (İngilizce ad, `,` ayırıcı) · (b) **arayüz diline göre**: Türkçe arayüzde Türkçe ad + `;` + virgül ondalık gösterilir ve girilir; dosyaya her zaman İngilizce + `,` + nokta | **(b)** + Ayarlar'da "Formülleri İngilizce göster" | 20 (X1), 25 | |
| K23 | **Excel ızgara çizimi** | (a) bugünkü hücre widget'ları + O(n) düzeltmeleri · (b) tek boyacı (kendi `RenderBox`) · (c) `two_dimensional_scrollables` `TableView` | Faz 26 başında 1 günlük **ölçümlü deneme**; bütçeyi (§7) tutan en basit seçenek. Eski ızgara bir sürüm boyunca bayrakla geri dönüş yolu | 26 | |
| K24 | **Excel'de not (yorum) yazma** | (a) kapsam dışı kalsın (KALANLAR kararı: VML riski) · (b) asgari VML şablonuyla yaz, masaüstü doğrulaması | **(b)**, cihazda masaüstü Excel'de doğrulanana kadar "Deneysel" etiketiyle | 27 | |
| K25 | **Metin/kod editörü motoru** | (a) `TextField` geliştir · (b) `re_editor` (MIT) | Faz 30 başında deneme; Türkçe IME + 5 MB açılış sorunsuzsa **(b)** | 30 | |

---

## 7. Performans bütçeleri

"Orta cihaz" = 6 GB RAM / 2022 orta sınıf; "düşük" = FAZ_PLANI Faz 4 hafif profil
(≤ 3 GB). Bulutta ölçülebilenler **kıyas testleri** (`test/perf/`, `perf`
etiketi; CI eşiği ×3 gevşek), cihazda ölçülenler `FrameTiming` + `KARE` günlüğü
(HAFIZA 2026-10-23 (11): SF `--latency` takılma ölçüsü DEĞİLDİR).

| Ölçü | Orta | Düşük | Ölçüm |
|---|---|---|---|
| Tuş → ekranda harf (Word/Slayt/Excel/Metin) | ≤ 1 kare | ≤ 2 kare | cihaz: `EditorPerf` tuş damgası → ilk kare; bulut: bir tuşun model + düzen maliyeti ≤ 4 ms (1000 paragraflık belgede) |
| Paragraf böl/birleştir (Enter/geri silme) | ≤ 8 ms | ≤ 16 ms | kıyas testi |
| Biçim düğmesi → görünür | ≤ 1 kare | ≤ 2 kare | widget testi + cihaz |
| Word 20 sayfa: aç → düzenlemeye hazır | ≤ 1,2 s | ≤ 2,5 s | kıyas + cihaz |
| Word 300 sayfa: ilk ekran | ≤ 1,5 s (kalanı arka planda) | ≤ 3 s | |
| Excel 10 bin × 20: aç | ≤ 1,5 s | ≤ 3 s | |
| Excel hücre onayı → bağımlılar hesaplı | ≤ 16 ms (≤ 1000 bağımlı) | ≤ 33 ms | kıyas testi |
| Excel / Word / slayt kaydırma | %99 kare ≤ 16 ms | ≤ 33 ms | `FrameTiming` |
| Slayt: düzenlemeye gir (yakınlaşma animasyonu) | takılmasız 60/120 Hz | 60 Hz | cihaz |
| Kaydetme | UI izleğinde ≤ 4 ms; gerisi isolate | aynı | test: kaydetme çağrısı `compute`'a gidiyor |
| Görsel ayar kaydırıcısı | kare ≤ 8 ms (önizleme vekili) | ≤ 16 ms | cihaz |
| Ek bellek | Word 300 s ≤ +150 MB; Excel 100 bin hücre ≤ +120 MB | yarısı | cihaz RSS |

---

## 8. Test ve doğrulama

1. **Gidiş-dönüş (round-trip):** ayrıştır → değiştirmeden kaydet → XML eşit
   (öznitelik sırası/boşluk hariç); bir düzenleme → **yalnız hedef düğüm
   farklı**. Yardımcı: `test/helpers/xml_diff.dart`.
2. **Örnek set genişler** (`test/fixtures/office/`, üretici betik
   `tool/write_fixtures_test.dart` ya da Python): Word —
   `word_kaydedilmis_cok_sayfa.docx` (`lastRenderedPageBreak` + ortasında sayfa
   kıran paragraf), `kopru_alan_dipnot.docx`, `stiller_basliklar.docx`,
   `liste_duzeyli.docx`, `tablo_birlesik.docx`, `ustbilgi_altbilgi.docx`,
   `yorum_izlenen.docx`, `arapca_rtl.docx`, `uzun_300_sayfa.docx`; Excel —
   `formul_zinciri.xlsx`, `turkce_formul.xlsx`, `10k_satir.xlsx`,
   `100k_hucre.xlsx`, `dondurulmus_suzgecli.xlsx`; Slayt —
   `duzenler_yer_tutucular.pptx`, `karisik_bicim.pptx`, `notlar.pptx`,
   `grup_donuk.pptx`.
3. **"Onarımsız açılıyor mu":** bulutta LibreOffice başsız
   (`soffice --headless --convert-to pdf`) — yoksa kurulum oturum başında;
   masaüstü Word/Excel/PowerPoint ve Google uygulamaları cihaz turunda.
4. **IME simülasyonu:** `tester.testTextInput` (birleştirme bölgesi, delta
   ekleme/silme/değiştirme, Türkçe `ğüşıöçİ`, Arapça); Enter/geri silme
   sınırları; yapıştırma.
5. **WebView köprüsü:** `node tool/check_word_bridge.js` (Playwright +
   Chromium) — çok sayfalı örnekle genişler; Faz 21a'da CI'a isteğe bağlı adım
   olarak değerlendirilir.
6. **Tasarım PNG'leri:** `tool/design_shots_faz2x_test.dart` →
   `docs/design/faz2x/` (açık/koyu, TR/AR, klavye açık/kapalı benzetimi).
7. **Kıyas testleri:** `test/perf/` (`dart_test.yaml`'da `perf` etiketi).
8. **Cihaz maddeleri** her fazda `docs/CIHAZ_TESTI.md` en altına; Faz 33'te
   tek turda kapanır.

---

## 9. Fazlar

### Faz 20 — Ortak düzenleme çekirdeği ("Edit Kit") + doğrulanmış hatalar

**Amaç:** Bütün editörler aynı geri al/yinele, taslak/otomatik kaydetme,
kaydetme durumu, klavye üstü çubuk, biçim paneli ve kısayol altyapısını
paylaşsın; sonraki fazlar bunun üstüne yazılsın. Kanıtlanmış hatalar ilk iş.

**Kanıt:** ED1–ED6, X1, X2, W11, SL1, TX1, IM4. **Ön koşul:** —. **Ortam:** ☁️.
**Kararlar:** K21, K22 (yalnız dosyaya yazma yönü).

**Yapılacaklar:**
0. **Doğrulanmış hatalar** — her biri önce KIRMIZI test, sonra düzeltme:
   - **X1:** kaydederken formül, motorun ayrıştırıcısıyla dosya biçimine
     çevrilir: Türkçe ad → İngilizce (`_aliases` ters tablosu), `;` → `,`,
     ondalık virgül → nokta; tırnak içindeki metne dokunulmaz.
     `=EĞER(A1>0;"a;b";TOPLA(B1:B3))` → `<f>IF(A1>0,"a;b",SUM(B1:B3))</f>`.
     Okurken ters yön Faz 25'te (K22).
   - **X2:** `_shiftLayoutRows/_shiftLayoutCols/_shiftKeys/_shiftSet` silmede
     (`delta < 0`) `k == at` kaydını düşürür. Test **üstteki** satırın stil,
     yükseklik ve gizli bayrağını da denetler (bugünkü test denetlemiyor).
   - **W11:** canlı kipte düzenlenmiş (`rich`) paragraf yedek editörde
     değiştirilince kayıtta atlanıyor mu — önce test; doğruysa `rich` paragrafta
     metin değişimi `setRuns` segmanlarını yeniden üretir.
   - **SL1:** slaytta `\n` → yeni `a:p` (özelliklerini kopyalayarak) ya da
     `a:br`; `a:t`'si olmayan paragrafa yazınca `a:r` + `a:t` oluşturulur
     (`endParaRPr` biçimiyle).
   - **TX1:** satır numarası `'\$i'` → `'$i'`; widget testi "1, 2, 3" görür.
   - **IM4:** kaydırıcı geri al girişleri sınırı (30) uygular.
1. **`core/edit/edit_history.dart`:** `EditCommand { apply(), revert(), label,
   tryMerge(next) }` + `EditHistory` (en çok 200 adım + bellek tavanı); **yazma
   birleştirme** (aynı hedefe 1 sn içinde ardışık yazım tek adım; kelime
   sınırında ve imleç atlayınca kesilir — Word gibi); adımla birlikte seçim/
   imleç geri yüklenir; `canUndo/canRedo` `ValueListenable`. `UndoStack` ve
   `SheetUndoStack` bunun ince sarmalayıcısı olur — Excel'in mevcut widget
   testleri değişmeden yeşil.
2. **`EditSession`:** kirli durum; `DocTitle` durum satırı
   "Kaydediliyor… / Kaydedildi 14:32 / Kaydedilmedi"; `PopScope` ile **tek tip
   çıkış sorusu** (`showAppConfirm`: Kaydet · Kaydetme · İptal) — Word, Excel,
   Slayt, Metin, PDF, Görsel; uygulama arka plana geçince (`AppLifecycle.paused`)
   taslak yazılır.
3. **`DraftJournal`:** uygulama verisinde `drafts/<kaynak-özeti>.bin` + meta
   (kaynak yol, boy, mtime, editör türü, saat); her 3 sn'de ya da 20 komutta bir,
   isolate'te. Açılışta kaynak değişmemiş ve taslak daha yeniyse belgenin üstünde
   şerit: "Kaydedilmemiş değişiklikler bulundu — **Geri yükle** · Sil". Kayıttan/
   vazgeçmeden sonra silinir; 7 günden eski taslaklar temizlenir. KVKK: yalnız
   cihazda, uygulama verisinde; yedeğe ve paylaşıma girmez.
4. **Otomatik kaydetme (K21):** Ayarlar > Belgeler > "Otomatik kaydet"
   (varsayılan açık) + belge başına kapatma (⋮). Yazma `SaveCoordinator` ile:
   serileştirme + zip + `SafeWrite` **isolate'te**, aynı anda tek kaydetme, araya
   giren değişiklik sıraya; yazılamayan kaynakta ilk kayıtta "Kopya olarak
   kaydet" önerisi.
5. **`EditorChrome`** (`OfficeShell`'in düzenleme kipi): üst çubuk
   `[← | ad + durum | ↶ ↷ | ⋮]`; şerit iki durumlu — klavye kapalı: sekmeli
   tam şerit; klavye açık: **`KeyboardAccessoryBar`** (klavyenin hemen üstünde,
   44 dp, yatay kayan; öğeleri editör verir; sağda **Aa** ve **⌄** sabit). Geri
   tuşu sırası §5 madde 2.
6. **`FormatPanelHost`:** "Aa" → klavye iner, **son klavye yüksekliğinde** alt
   panel açılır; sekmeleri editör verir; ⌨ ile klavyeye dönüş; geçişte belge
   kaymaz (widget testi: imleç satırının ekran konumu değişmez).
7. **Klavye animasyonu ölçümü:** `MediaQuery.viewInsetsOf` kare kare mi
   değişiyor — widget testinde benzetim + cihaz maddesi; gerekirse
   `ci/KeyboardInsets.kt` (`WindowInsetsAnimationCompat`) ile çubuğun konumu
   yerelden sürülür (`tool/check_kotlin.sh`).
8. **`EditorShortcuts`:** donanım klavyesi Ctrl+Z/Y/S/F/B/I/U/C/X/V/A, Esc
   (Flutter `Shortcuts/Actions`); editörler eylemleri kaydeder.
9. **`EditorPerf`:** tuş olayı → ilk kare süresi (`FrameTiming` +
   `SchedulerBinding`), `KARE` günlüğüne editör etiketi; geliştirici menüsünde
   isteğe bağlı köşe sayacı.
10. **PNG'ler:** `tool/design_shots_faz20_test.dart` — üst çubuğun üç durumu,
    klavye üstü çubuk, Aa paneli, taslak kurtarma şeridi, çıkış sorusu
    (açık/koyu, TR/AR) → `docs/design/faz20/`.

**Kabul ölçütleri:** 6 hata kırmızı→yeşil testli · Excel'in 17 widget testi +
`sheet_edit_test` yeşil (yeni geçmişle) · altı editörde aynı çıkış sorusu ·
taslak kurtarma testi (oturum nesnesi atılır, ekran yeniden açılır, şerit
çıkar, geri yükleme içeriği getirir) · Word/Excel kaydetme çağrısı isolate'e
gidiyor (test) · Aa ↔ klavye geçişinde belge konumu sabit (test) · PNG'ler.

**Bölünürse:** 20a = madde 0–2 · 20b = 3–10.

**Risk:** düşük–orta. Excel geçmiş göçü mevcut testlerle korunur; otomatik
kaydetme yanlış dosyaya yazamasın diye kaynak boy+mtime denetimi (dış
değişiklikte "dosya başka yerde değişti" uyarısı, üstüne yazmaz).

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 20'yi uygula (bulut). Önce
> madde 0'daki altı doğrulanmış hatayı kırmızı testlerle kanıtla ve düzelt (X1
> formül dosya biçimi, X2 satır silme kayması, W11, SL1, TX1, IM4). Sonra
> `core/edit/` altında EditHistory, EditSession, DraftJournal, SaveCoordinator,
> EditorChrome + KeyboardAccessoryBar + FormatPanelHost, EditorShortcuts ve
> EditorPerf'i kur; Excel'in geri al yığınını yeni geçmişe taşı, çıkış sorusunu
> altı editörde birleştir. K21 cevabı yoksa öneriyi uygula. Önce PNG taslağını
> göster. HAFIZA'ya yaz, DUZENLEME_PLANI ve FAZ_PLANI durum tablolarını
> güncelle, main'e birleştir.

---

### Faz 21 — Word: canlı düzenlemenin acil onarımı + motor denemesi (K18 kapısı)

**Amaç:** (1) Bugünkü sayfa görünümünde yazmanın gerçek Word belgelerinde de
çalışması ve sessiz veri kaybının bitmesi; (2) Word'ün kalıcı düzenleme motoruna
**ölçümle** karar verilmesi.

**Kanıt:** W1–W9, W12. **Ön koşul:** Faz 20. **Ortam:** ☁️ + 📱 (kısa kontrol
noktası, kullanıcı). **Kararlar:** K18, K19.

**Yapılacaklar — 21a onarım (bugünkü WebView yolu):**
1. **Önce kanıt:** Word'ün kaydettiği gibi `w:lastRenderedPageBreak` içeren
   (biri paragraf ortasında) çok sayfalı örnek üret; `tool/check_word_bridge.js`'e
   "düzenleme açıldı mı, paragraf sayısı tuttu mu" adımı → bugün **kırmızı**
   olmalı (W1'in kanıtı). Sonuç HAFIZA'ya.
2. **Kimlik tabanlı eşleme:** WebView'a gönderilen **kopyada** her `w:p`'nin
   başına görünmez yer imi `w:bookmarkStart w:name="_fkp<i>"` (+ `bookmarkEnd`)
   eklenir — docx-preview yer imini `<span id="_fkp<i>">` olarak çizer
   (kaynakta doğrulandı: `renderBookmarkStart`). JS indeksi işaretten okur;
   işaretsiz `<p>` (docx-preview'ın sayfa kırmada böldüğü ikinci yarı) bir
   öncekinin devamıdır; düzenlemede yarıların segmanları birleşip tek `w:p`'ye
   yazılır. Sigorta kalır ama ölçütü "işaretli paragraf sayısı". Kaydedilen
   dosyaya işaret **girmez** (test).
3. **Enter = yeni paragraf, geri silme = birleştir:** `beforeinput`
   (`insertParagraph` / paragraf başında `deleteContentBackward`) yakalanır;
   bölme/birleştirme DOM'da yerinde yapılır (tarayıcının kendi bölmesi ya da
   elle `Range` ile), yeni `<p>` aynı anda işaretlenir (`data-fkp`) ve Dart'a
   `{split:i, at:offset}` / `{merge:i}` gider → `DocxEditor.splitParagraph` /
   `mergeWithPrevious` XML'i böler/birleştirir (pPr kopyalanır, run'lar bölünür).
   Tüm belge yeniden çizilmez; işaretler yeniden numaralanır. Faz 20 komutu
   olarak geri alınabilir. İçinde satır sonu olan yapıştırma aynı yoldan çok
   paragrafa bölünür. (Yer imi `w:id`'leri belgedekilerle çakışmayacak bir
   aralıktan seçilir.)
4. **`setRuns` artık silmez:** düzenlenen paragraftaki köprü, alan, yer imi,
   dipnot başvurusu, sekme, satır içi resim **dokunulmaz ada** — DOM'da
   `contenteditable=false` çip, segman listesinde yer tutucu, XML'de özgün düğüm
   yerinde kalır. Paragraf içi farklı `rPr`'ler segman başına korunur; ilk run
   şablonu yalnız yeni yazılan metne. Stilden gelen kalın kapatılınca
   `w:b w:val="0"`.
5. **Yazarken okunur boyut:** düzenlemeye girince WebView akış (`setFlow`)
   kipine geçer ya da imlecin sayfası ekran genişliğine sığdırılır (~0,9 ölçek);
   klavye açılıp kapanınca `fitPage` yeniden yerleşimi tek sefer.
6. **Klavye:** yazım denetimi, otomatik düzeltme, otomatik büyük harf AÇIK
   (ayardan kapatılabilir); her gönderimde `paraList()` yerine önbellek;
   `segsOf` yalnız değişen paragrafta; kaydırma mesajı yalnız sayfa değişince.
7. **Araç çubuğu klavyenin üstüne** (Faz 20 `KeyboardAccessoryBar`); hizalama/
   liste/renk durumları yansır; üstü çizili ve iki yana yasla düğmesi.
8. **Geri al/yinele** paragraf düzeyi anlık görüntü komutlarıyla (yazma
   birleştirmeli) — "harf harf geri alma yok" kararı (KALANLAR) bu fazla kalkar.
9. **Resim ekle/sil** tüm belgeyi yeniden çizmez: yalnız etkilenen paragrafın
   DOM'u; imleç ve geri al korunur.

**Yapılacaklar — 21b motor denemesi (K18):**
10. Deneme kodu `lib/labs/word_editor/` altında, **Geliştirici menüsünde
    "Yeni Word editörü (deneme)"** bayrağının arkasında (main'e girer ama
    kullanıcı açmadıkça görünmez — tek dal kuralı). İki aday aynı görevle:
    - **b-i:** super_editor (MIT) — `pub get` çözümlemesi (Flutter 3.44.6), APK
      farkı (arm64), lisans dosyaları;
    - **b-ii:** kendi ince çekirdeğimiz — belge düzeyinde tek
      `DeltaTextInputClient`, IME'ye yalnız imlecin paragrafı; paragraf
      `RenderParagraph`; seçim + tutamak + büyüteç asgari.
11. Görev: 3 örnek (kısa mektup, 40 sayfa tablolu rapor, Arapça) salt metin
    modeliyle (Faz 22 modeli değil) — yaz, Enter, geri silme ile birleştir,
    paragraflar arası seç-sil, yapıştır, K/T/A.
12. **Ölçüm tablosu** (HAFIZA'ya): pub çözümleme; APK farkı; 1000 paragrafta
    açılış ve kaydırma kare süresi (profil testi); IME testleri
    (`testTextInput`: Türkçe karakter, birleştirme bölgesi, delta, otomatik
    düzeltme değiştirmesi); paragraflar arası seçim; bellek; kod satırı.
13. **📱 Kontrol noktası (kullanıcı, ~10 dk, nightly APK):** Ayarlar >
    Geliştirici > "Yeni Word editörü (deneme)". Kontrol listesi
    `docs/CIHAZ_TESTI.md`'de: Gboard ve (varsa) Samsung Klavye ile `ğüşıöçİ`,
    kaydırarak yazma, sesle yazma, otomatik düzeltme önerisine dokunma, Enter/
    geri silme ile paragraf birleştirme, uzun basışla seçim + tutamak,
    kopyala-yapıştır, "akıcı mı" hissi (1–5), eski düzenleme ile karşılaştırma.
    Sonuç → **K18** satırı.

**Kabul ölçütleri:** çok sayfalı Word-kaydedilmiş örnekte düzenleme açılıyor
(Playwright testi, önce kırmızıydı) · Enter yeni paragraf: kaydet → yeniden aç →
paragraf sayısı ve metin doğru; LibreOffice onarımsız açıyor · köprü/alan/
dipnot içeren paragrafı düzenleyince hepsi yerinde (birim testi) · geri al
yazmayı geri alıyor · yazım denetimi açık · K18 + K19 tabloda (kontrol
noktasının sonucuyla).

**Bölünürse:** 21a = 1–9 · 21b = 10–13.

**Risk:** orta–yüksek (JS köprüsü, Android WebView ≠ Chromium). Sigorta (sayım)
korunur; kontrol noktası WebView klavye davranışını da sorar.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 21'i uygula (bulut). 21a:
> önce W1'i çok sayfalı Word-kaydedilmiş örnek + `tool/check_word_bridge.js`
> ile kırmızı kanıtla; yer imi işaretli kimlik tabanlı eşlemeyi, Enter/geri silme
> ile paragraf böl/birleştir komutlarını, setRuns'ın köprü/alan/dipnotu
> korumasını, okunur boyutta düzenlemeyi, klavye üstü çubuğu ve geri al/yinele'yi
> yap. 21b: `lib/labs/word_editor/` altında geliştirici bayrağı arkasında
> super_editor ve kendi ince çekirdeğimizle iki deneme kur, ölçüm tablosunu
> HAFIZA'ya yaz, kullanıcı kontrol listesini `docs/CIHAZ_TESTI.md`'ye ekle ve
> K18'i kullanıcıya sor. HAFIZA'ya yaz, durum tablolarını güncelle, main'e
> birleştir.

---

### Faz 22 — Word Mobil görünüm editörü I: belge modeli ve yazma

**Amaç:** Telefonda bir Word belgesinde yazmanın, silmenin, seçmenin bir not
uygulaması kadar akıcı olduğu ve **dosyayı bozmayan** editör.

**Kanıt:** W1–W6, W8, W12; §3.1 (M365 Mobil görünüm). **Ön koşul:** Faz 21,
K18 = (b). **Ortam:** ☁️. (K18 (a) çıkarsa bu faz "WebView yolunun
derinleştirilmesi" olarak yeniden yazılır.)

**Yapılacaklar:**
1. **Belge modeli** `lib/services/docx/`:
   - `DocxPackage` — zip parçaları; değişmeyenler bayt olarak taşınır.
   - `DocxStyles` — `docDefaults` → tablo/paragraf/karakter stili zinciri
     (`basedOn`) → doğrudan biçim; tema yazı tipleri ve renkleri; Flutter
     `TextStyle` önbelleği.
   - `DocxNumbering` — `abstractNum/num/lvl`, düzey sayaçları, madde imleri
     (Symbol/Wingdings eşlemesi `core/symbol_fonts.dart`).
   - Blok düğümleri: `ParagraphNode`, `TableNode` (hücrede paragraflar),
     `OpaqueBlock` (içerik denetimi, metin kutusu, bölüm sonu, tanınmayan).
     Satır içi: `TextRun`, `OpaqueInline` (köprü — metni düzenlenebilir —,
     alan, yer imi, dipnot başvurusu, sekme, resim, sembol, yorum çapası).
   - Her düğüm özgün `XmlElement`'ine bağlı; değişmeyen düğüm kayıtta
     baytı baytına aynı. Kalıcı kimlik `w14:paraId` (yoksa bellek içi).
2. **Ayrıştırma isolate'te**; büyük belgede ilk 50 paragraf önce, kalanı
   arka planda (ilk ekran bütçesi §7).
3. **Görünüm:** `SliverList` tembel (yalnız görünen paragraflar); başlık/
   gövde stilleri gerçek punto oranıyla (ekrana ölçekli); madde/numara girintili;
   tablo ekrana sığar, sığmazsa yatay kaydırılır; resim genişliğe sığar; sayfa
   sonu ince çizgi + "Sayfa sonu"; üst/alt bilgi gösterilmez (sayfa
   görünümünde).
4. **Yazma** (K18 motoruyla): tam IME — birleştirme bölgesi, otomatik düzeltme,
   kaydırarak yazma, sesle yazma, kalemle el yazısı; **Enter** paragrafı böler
   (stil devam eder; boş liste öğesinde Enter listeden çıkar; başlıkta Enter →
   `w:next` stili); **geri silme** birleştirir; paragraflar arası seç-sil;
   yapıştır (düz metin + kendi panomuzdan biçimli); Türkçe büyük/küçük (İ/ı).
5. **Seçim:** çift dokunuş kelime, üç dokunuş paragraf, tutamak + büyüteç;
   bağlam çubuğu **Kes · Kopyala · Yapıştır · Tümünü seç · Biçim · Çevir ·
   AI ile düzelt** (mevcut çeviri/AI akışları yeni seçime bağlanır).
6. **Yazım denetimi:** `SpellCheckConfiguration` (Android servisi, belge dili),
   öneri menüsü; ayardan kapatılabilir.
7. **Kaydetme:** yalnız kirli düğümler serileştirilir; gerekirse
   `numbering.xml`/`styles.xml`; Faz 20 oturumu (taslak, otomatik kaydetme,
   isolate).
8. **Sayfa görünümü önizlemesi:** "Sayfa düzeni" düğmesi güncel modelden bayt
   üretip mevcut WebView görüntüleyicisinde açar (K19 — geçişte orada da
   düzenleme açık kalır).
9. **Giriş:** Word ekranında "Düzenle" → Mobil görünüm editörü (K19 geçiş
   kuralına göre); okuma her zamanki gibi sayfa görünümünde.
10. **Testler:** örnek setin tamamında değişmeden kaydet = XML eşit; bir kelime
    değiştir → yalnız o `w:p` farklı; köprü/alan/dipnot/içerik denetimi korunur;
    IME simülasyonu (Türkçe/Arapça, birleştirme bölgesi, otomatik düzeltme);
    Enter/geri silme sınır durumları (liste, başlık, tablo hücresi, belge başı/
    sonu); kıyas: 1000 paragrafta tuş maliyeti, 300 sayfada ilk ekran.

**Kabul ölçütleri:** §8 madde 1 örnek setin tamamında yeşil · LibreOffice
onarımsız açıyor · tuş maliyeti ve ilk ekran §7 bütçesinde · Arapça paragrafta
sağdan sola yazma doğru · PNG'ler (`docs/design/faz22/`).

**Bölünürse:** 22a = 1–3, 7, 10 (model + gidiş-dönüş + salt okunur Mobil
görünüm) · 22b = 4–6, 8–9 (yazma, seçim, yazım denetimi).

**Risk:** yüksek (yeni editör). Azaltma: dokunulmaz ada ilkesi (bilinmeyen =
korunur), gidiş-dönüş testleri her örnekte, eski yol K19 geçişi boyunca durur.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 22'yi uygula (bulut; K18
> cevabına göre). Önce 22a: `lib/services/docx/` belge modelini (stiller,
> numaralandırma, dokunulmaz adalar, kalıcı kimlik) ve gidiş-dönüş testlerini
> kur, salt okunur Mobil görünümü çiz. Sonra 22b: K18 motoruyla yazma, Enter/
> geri silme, seçim + bağlam çubuğu, yazım denetimi, kaydetme. Örnek seti §8'e
> göre genişlet, kıyas testlerini yaz, PNG'leri üret. HAFIZA'ya yaz, durum
> tablolarını güncelle, main'e birleştir.

---

### Faz 23 — Word II: biçimlendirme, Office şeridi, Aa paneli, stiller

**Amaç:** Word'deki günlük biçim işlerinin (kalın, başlık yapma, liste, hizala,
renk) tanıdık yerde ve tek dokunuşta olması.

**Kanıt:** W7, W10 (biçim kısmı), §3.1/§3.3. **Ön koşul:** Faz 22. **Ortam:** ☁️.
**Karar:** K19'un ikinci yarısı (bu faz bitince sayfa görünümü salt okunur).

**Yapılacaklar:**
1. **Giriş sekmesi** (klavye kapalı): Pano (Yapıştır ▾ [biçimli / düz metin] ·
   Kes · Kopyala · **Biçim boyacısı**) · Yazı tipi (ad, boyut, A+ A−, **K T A
   S**, x² x₂, Yazı rengi ▾, Vurgu ▾, Biçimi temizle) · Paragraf (Madde ▾,
   Numara ▾, **çok düzeyli**, Girinti − +, hizalama ×4, Satır aralığı ▾
   1,0/1,15/1,5/2,0, paragraf öncesi/sonrası) · **Stiller** galerisi
   (belgenin kendi stilleri: Normal, Başlık 1–3, Konu Başlığı, Alt Konu Başlığı,
   Alıntı, Liste Paragrafı — her çip kendi biçimiyle önizlemeli).
2. **Klavye üstü çubuk (Word):** ↶ · K · T · A · • · 1. · ⇤ ⇥ (liste düzeyi /
   girinti) · hizalama (dokundukça döner) · yazı rengi (son kullanılan) · Aa · ⌄.
3. **Aa paneli:** **Yazı** (ad listesi — her ad kendi yazı tipinde; boyut
   kaydırıcı + sayı + − +; renk ızgarası: tema renkleri + standart + son
   kullanılanlar) · **Paragraf** (hizalama, girinti, aralık, satır aralığı,
   listeler + düzey) · **Stiller** (dikey liste, canlı önizleme).
4. **Durum yansıtma:** seçimdeki her özellik düğmede; karışık seçimde "—"/yarı
   durum; stil adı şeritte.
5. **Biçim boyacısı:** tek dokunuş bir kez, çift dokunuş kilitli (Office gibi).
6. **Stil doğruluğu:** stil uygula = `w:pStyle`; stilden gelen biçim "doğrudan"
   gösterilmez; doğrudan biçimi temizle; stil kalınını kapatmak `w:b w:val="0"`.
7. **Görünüm sekmesi:** Mobil görünüm ↔ Sayfa düzeni, yakınlaştır, **gezinti**
   (başlık listesi → atla), sözcük sayısı (Gözden Geçir'e de).
8. **K19 (b):** sayfa görünümü salt okunur önizleme olur; WebView düzenleme
   köprüsü (21a) kaldırılır ya da yalnız yedek olarak gizlenir — karar HAFIZA'ya.
9. **RTL:** Arapça paragrafta `w:bidi`, hizalama aynalanır, liste imi sağda.
10. **PNG'ler** (`docs/design/faz23/`): Giriş sekmesi, klavye üstü çubuk, Aa
    paneli üç sekme, stil galerisi, koyu tema, Arapça.

**Kabul ölçütleri:** her düğme gidiş-dönüş testli (uygula → kaydet → aç → aynı;
masaüstü Word maddesi CIHAZ_TESTI'nde) · klavye açık/kapalı geçişte doğru çubuk
(widget testi) · Aa ↔ klavye geçişinde belge kaymıyor · stil uygulanınca
doğrudan biçim yazılmıyor (XML testi) · 2,0× yazı ölçeğinde şerit taşmıyor.

**Bölünürse:** 23a = 1–4 · 23b = 5–10.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 23'ü uygula (bulut). Word
> Mobil görünüm editörüne M365 dilinde Giriş sekmesi, klavye üstü çubuk, Aa
> paneli (Yazı · Paragraf · Stiller), biçim boyacısı, çok düzeyli listeler ve
> stil galerisini ekle; durum yansıtmayı tamamla; K19'un ikinci yarısını uygula.
> Önce PNG taslaklarını göster. HAFIZA'ya yaz, durum tablolarını güncelle,
> main'e birleştir.

---

### Faz 24 — Word III: Ekle, tablo, resim, Düzen, üst/alt bilgi, Gözden Geçir

**Amaç:** Telefonda bir Word belgesini baştan sona hazırlayabilmek: tablo,
resim, bağlantı, sayfa ayarı, yorum.

**Kanıt:** W9, W10. **Ön koşul:** Faz 23. **Ortam:** ☁️.

**Yapılacaklar:**
1. **Ekle sekmesi:**
   - **Tablo:** ızgara seçici (8×8 dokun-sürükle) → `w:tbl` (tema "Tablo Kılavuzu"
     stili). Tabloya dokununca bağlamsal **Tablo** sekmesi: satır üste/alta,
     sütun sola/sağa, satır/sütun sil, tabloyu sil, başlık satırı, bantlı satır,
     hücre gölgesi; hücreler arasında ⇥ ile ilerleme, son hücrede ⇥ yeni satır.
   - **Resim:** galeri/kamera; seçince tutamaklar — **oran kilitli
     boyutlandırma**, hizalama (sol/orta/sağ), değiştir, sil, alternatif metin;
     (M365 gibi boyut değişince önizleme sayfa görünümünde doğrulanabilir).
   - **Bağlantı:** ekle/düzenle/kaldır (`w:hyperlink` + ilişki); okumada
     dokununca aç (onaylı).
   - **Sayfa sonu**, yatay çizgi, tarih/saat, **Sembol** (son kullanılanlar +
     sık: © ® ™ € ₺ § ° ± × ÷ → • ✓ + Unicode arama).
2. **Düzen sekmesi:** Kenar boşlukları (Normal/Dar/Orta/Geniş), Yönlendirme,
   Boyut (A4/A5/Letter/Legal), Sütunlar (1/2) → `w:sectPr`; Sayfa düzeni
   önizlemesinde görülür.
3. **Üst bilgi / alt bilgi:** düzenle (metin + sayfa numarası alanı ekle; ilk
   sayfa farklı) — ayrı parça (`headerN.xml`); M365 gibi bu iş sayfa görünümünde
   önizlenir.
4. **Gözden Geçir:** **Sözcük sayısı** (sayfa, sözcük, karakter boşluklu/
   boşluksuz, paragraf); yazım denetimi aç/kapa; **Yorumlar** (oku, yanıtla,
   yeni, sil, çözüldü — `comments.xml` + ilişki + içerik türü); **İzlenen
   değişiklikler:** göster/gizle + "Tümünü kabul et / reddet"; izlenen değişiklik
   içeren paragraf düzenlenirse bilgi şeridi.
5. **Bul/Değiştir** Mobil görünümde (Türkçe katlama, büyük/küçük, tam sözcük;
   tümünü değiştir tek geri al adımı).
6. **Dipnot ekle** (isteğe bağlı, 24b sonu).

**Kabul ölçütleri:** her ekleme gidiş-dönüş testli + LibreOffice onarımsız ·
tablo bağlamsal sekmesi widget testi · yorum ekle → masaüstü Word'de görünüyor
(CIHAZ_TESTI) · "Tümünü kabul et" sonrası `w:ins/w:del` kalmıyor (XML testi).

**Bölünürse:** 24a = 1, 5 · 24b = 2–4, 6.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 24'ü uygula (bulut). Word
> Mobil görünüm editörüne Ekle (tablo + bağlamsal Tablo sekmesi, resim
> tutamakları, bağlantı, sayfa sonu, sembol), Düzen (kenar boşluğu, yön, boyut,
> sütun), üst/alt bilgi düzenleme ve Gözden Geçir (sözcük sayısı, yorumlar,
> izlenen değişikliklerde tümünü kabul/reddet) ekle. Gidiş-dönüş testleri +
> PNG'ler. HAFIZA'ya yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 25 — Excel I: veri girişi, Excel mobil gibi

**Amaç:** Telefonda hücre doldurmanın, formül yazmanın, aralık seçmenin Excel
mobil kadar rahat — sayı girişinde daha da rahat — olması; dosyayı bozan
doğruluk hatalarının bitmesi.

**Kanıt:** X3, X5–X8, X1 (okuma yönü), §3.2–3.4. **Ön koşul:** Faz 20.
**Ortam:** ☁️. **Kararlar:** K20, K22.

**Yapılacaklar:**
0. **Doğruluk önce:** satır/sütun ekle-silde formül başvuruları (tüm
   sayfalardaki, başka sayfaya başvurular dahil), birleştirmeler, koşullu biçim
   aralıkları, doğrulamalar, notlar, autoFilter ve oturum biçim haritaları
   kaydırılır — `sheet_edit.dart`'taki başvuru kaydırıcısı ortaklaşır; silinen
   hücreye başvuru `#BAŞV!`. Sıralama formül hücresini **sonucuyla**
   karşılaştırır.
1. **Hücre içi düzenleme her yakınlaştırmada:** düzenleme kutusu hücrenin
   üstünde açılır, içerik sığmazsa sağa/aşağı büyüyen yüzer editör (Excel gibi);
   en az 16 sp; 30×72 dp eşiği kalkar; formül çubuğu eşzamanlı.
2. **İki dokunuş dili:** dokun = seç · seçiliye tekrar dokun / çift dokun =
   düzenle (imleç dokunulan konuma) · seçili hücrede klavye açıkken yazmaya
   başlamak = içeriği değiştir · formül çubuğuna dokun = mevcut içeriği düzenle
   (masaüstündeki F2). Yanlışlıkla silmeye karşı: değiştirme tek geri al adımı.
3. **Klavye üstü çubuk (Excel):** ✗ · ✓ · ← → ↑ ↓ (düzenlemede imleç, değilken
   seçim) · ⇥ · ↵ · = · Σ · fx · **123/ABC**. Enter aşağı, ⇥ sağa; ⇥ ile
   girilen satırda Enter, satırın başındaki sütuna döner (Excel davranışı).
4. **Uygulama içi sayı/formül tuş takımı (K20):** Faz 20 panel ana bilgisayarında,
   klavye yüksekliğinde (§5.1 şeması): rakamlar, `,`, işleçler `+ − × ÷ ^ % &`,
   `( ) ; : $ = < > "`, ⌫, ↵, ⇥, oklar; sayı/para/yüzde/tarih biçimli hücrede
   kendiliğinden açılır; **ABC** ile sistem klavyesine; uzun basışla ikincil
   karakter.
5. **İşaret kipi (point mode):** formül yazarken hücreye dokun → başvuru eklenir
   (`A1`), sürükle → aralık (`A1:B5`), sayfa sekmesine dokun → `Sayfa2!A1`;
   formüldeki her başvuru renklenir, ızgarada aynı renkte çerçeve (Excel'in
   aralık bulucusu); **$** düğmesi döngüsü `A1 → $A$1 → A$1 → $A1` (F4).
6. **İşlev yardımı:** otomatik tamamlama + **bağımsız değişken ipucu**
   (`DÜŞEYARA(`**`aranan_değer`**`; tablo_dizisi; sütun_indis_sayısı;
   [aralık_bak])` — etkin bağımsız değişken kalın); **fx** → kategorili işlev
   kitaplığı (Son kullanılanlar, Mali, Mantıksal, Metin, Tarih ve Saat, Arama ve
   Başvuru, Matematik, İstatistik) + bir cümlelik açıklama (TR/EN/AR).
7. **Formül dili (K22):** Türkçe arayüzde Türkçe ad + `;` + virgül ondalık
   gösterilir ve girilir; dosyaya İngilizce (Faz 20 X1); okurken İngilizce →
   Türkçe; ayar "Formülleri İngilizce göster".
8. **Seçim tutamakları:** seçili aralığın sol-üst ve sağ-alt köşesinde yuvarlak
   tutamak — sürükle = genişlet/daralt; **fırlat = veri kenarına kadar**
   (Ctrl+ok); aralığa **tek dış çerçeve** + yarı saydam dolgu (hücre başına
   çizgi değil); başlıkta sürükleyerek çoklu satır/sütun.
9. **Bağlam menüsü** (seçime ikinci dokunuş / uzun bas): Kes · Kopyala ·
   Yapıştır · **Özel yapıştır** (değerler / biçim / formüller / devrik) ·
   Temizle ▾ (içerik / biçim / tümü) · Doldur ▾ (aşağı / sağa / seri) ·
   Ekle / Sil (satır, sütun, hücreleri kaydırarak) · Sırala · Not.
10. **Otomatik tamamlama (metin):** sütunda daha önce yazılmış değerle
    başlayınca gri tamamlama; ⇥/✓ kabul.
11. **Akıllı giriş (Türkçe yerel ayar):** `1.234,56` sayı · `%15` yüzde biçimli ·
    `₺100`/`100 TL` para · `23.10.2026`, `23 Eki` tarih · `14:30` saat · `1/2`
    tarihe dönüşmeden önce uyarı · `007` metin (mevcut kural).
12. **Izgara sınırsız hissi:** kenara yaklaşınca 100 satır / 26 sütun büyür;
    Enter son satırda durmaz.
13. **Veri doğrulama listesi** hücrede açılır ok + seçim levhası.

**Kabul ölçütleri:** widget testleri — dokun/düzenle/✓/↵/⇥/ok, yazmaya başlama
değiştirir, işaret kipiyle aralık ekleme + renkli çerçeve, tuş takımı, tutamak
sürükleme/fırlatma, özel yapıştır · formül çevirici tablo testi (30 formül
TR↔EN; tırnak içi `;` korunur) · satır ekleyince `=TOPLA(A1:A10)` →
`=TOPLA(A1:A11)`, silinen hücreye başvuru `#BAŞV!` · Excel'in mevcut testleri
yeşil · PNG'ler (`docs/design/faz25/`: hücre içi editör, tuş takımı, işaret
kipi, tutamaklar, bağlam menüsü).

**Bölünürse:** 25a = 0–3, 7, 12 · 25b = 4–6, 8–11, 13.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 25'i uygula (bulut). Önce
> madde 0'ın doğruluk hatalarını (ekle/silde başvuru kaydırma, sonuçla sıralama)
> kırmızı testlerle düzelt. Sonra hücre içi yüzer editör, iki dokunuş dili,
> klavye üstü çubuk, uygulama içi sayı/formül tuş takımı (K20), işaret kipi +
> renkli başvurular, bağımsız değişken ipucu + fx kitaplığı, Türkçe formül dili
> (K22), seçim tutamakları, bağlam menüsü, otomatik tamamlama ve akıllı giriş.
> Önce PNG taslağını göster. HAFIZA'ya yaz, durum tablolarını güncelle, main'e
> birleştir.

---

### Faz 26 — Excel II: hesap motoru ve büyük sayfa akıcılığı

**Amaç:** 10 bin satırlık bir sayfada da yazarken, kaydırırken, sıralarken
kasmamak.

**Kanıt:** X4, X9, X10. **Ön koşul:** Faz 25. **Ortam:** ☁️ (+📱 ölçüm Faz 33).
**Karar:** K23.

**Yapılacaklar:**
1. **Kalıcı motor + bağımlılık grafiği:** sayfa açılınca formüller bir kez
   ayrıştırılır (AST önbelleği); hücre → bağımlılar grafiği; değişen hücrenin
   yalnız bağımlıları topolojik sırayla yeniden hesaplanır; döngüsel başvuru
   uyarısı; sonuçlar modelde; `build` hesap yapmaz (ızgara, önizleme ve durum
   çubuğu aynı motoru paylaşır). Uçucu işlevler (`BUGÜN`, `ŞİMDİ`, `S_SAYI_ÜRET`,
   `DOLAYLI`, `KAYDIR`) her hesapta. Ağır ilk hesap (≥ 5 bin formül) isolate'te.
2. **Kaydette `<v>` önbellek değeri** yazılır (`fullCalcOnLoad` kalır) — Excel
   dışı önizleyiciler sonucu görür.
3. **Izgara çizimi (K23):** deneme → (b) tek boyacı ya da (c) `TableView`;
   metin düzeni LRU önbelleği (içerik + stil + genişlik anahtarlı); seçim/
   tutamak/işaret kipi çerçeveleri ayrı `RepaintBoundary` katmanı (seçim
   değişince hücreler yeniden çizilmez); dondurulmuş bölmeler tek kaydırma
   sisteminde (4 denetleyici eşitlemesi kalkar). Eski ızgara bir sürüm boyunca
   geliştirici bayrağıyla.
4. **O(n) düzeltmeleri:** `maxCols` önbellek; `mergeAt`/`condRuleAt` ızgara
   dizini; renk ölçeği/veri çubuğu min-max kural başına önbellek; sıralama
   O(n log n) (satır başına bir kez yakala); durum çubuğu toplamı artımlı;
   `completionsFor` listesi bir kez sıralanır.
5. **Kaydetme isolate'te** (`XlsxPackageWriter` + `XlsxSavePatch` +
   `XlsxChartWriter` saf Dart → `compute`).
6. **Okuma sınırları dürüst:** 1024 sütun / 200 bin satır üstü kesiliyorsa
   kullanıcıya şerit (bugün sessiz); yanıltıcı 16384 yorumu düzelir.
7. **Kıyas testleri:** 10 bin × 20 ve 100 bin hücre örnekleri; §7 bütçeleri.

**Kabul ölçütleri:** §7 Excel satırları bulut kıyasında · hücre onayında
yalnız bağımlılar hesaplanıyor (sayaçlı test) · eski/yeni ızgara aynı PNG (piksel
farkı eşik altı) · mevcut 22 Excel test dosyası yeşil · kaydetme UI'yi bloklamıyor.

**Bölünürse:** 26a = 1–2, 4–5 · 26b = 3, 6–7.

**Risk:** orta–yüksek (çizim katmanı). Azaltma: K23 denemesi, görsel eşitlik
testi, bayrakla geri dönüş.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 26'yı uygula (bulut).
> Kalıcı formül motoru + bağımlılık grafiği kur, `<v>` önbelleğini yaz, O(n)
> darboğazlarını kaldır, kaydetmeyi isolate'e al. K23 için tek boyacı ile
> `TableView`'ı 10 bin satırlık örnekte ölçüp kullanıcıya sun, seçileni uygula,
> eski ızgarayı bir sürüm bayrakla tut. HAFIZA'ya ölçümleri yaz, durum
> tablolarını güncelle, main'e birleştir.

---

### Faz 27 — Excel III: Biçim, Veri, Görünüm, form görünümü ve CSV

**Amaç:** Excel'in günlük biçim ve veri araçlarının tanıdık yerlerinde olması;
telefona özel rahat veri girişi; CSV'nin düzenlenebilmesi.

**Kanıt:** X11, X12. **Ön koşul:** Faz 26. **Ortam:** ☁️. **Karar:** K24.

**Yapılacaklar:**
1. **Şerit (M365 adları):** Giriş · Ekle · Formüller · Veri · Gözden Geçir ·
   Görünüm; klavye kapalıyken tam şerit, açıkken klavye üstü çubuk.
2. **Hücreleri biçimlendir paneli** (Aa karşılığı, alt panel):
   - **Sayı:** Genel · Sayı (ondalık, binlik, negatif kırmızı/parantez) · Para
     (₺ $ € £, simge konumu) · Muhasebe · Tarih (TR biçimleri) · Saat · Yüzde ·
     Kesir · Bilimsel · Metin · **Özel** (biçim kodu + canlı önizleme);
   - **Hizalama:** yatay 6, dikey 3, girinti, kaydır, birleştir ve ortala,
     yön (0/90/−90/45);
   - **Yazı tipi:** ad, boyut, K T A S, renk;
   - **Kenarlık:** ön ayar ızgarası + çizgi (ince/orta/kalın/çift/kesik) + renk;
   - **Dolgu:** tema renkleri + standart + son kullanılanlar.
3. **Hücre stilleri** (İyi/Kötü/Nötr, Başlık 1–4, Toplam, Not) ve **Tablo olarak
   biçimlendir** (bantlı satır, başlık satırı + süzgeç; önce biçim + autoFilter,
   `tableN.xml` isteğe bağlı).
4. **Veri:** çok düzeyli **Sırala** (sütun + yön, başlık satırı var/yok);
   **Süzgeç oluştur/kaldır** (bugün yalnız var olan) + değer/sayı/tarih/metin
   süzgeçleri + arama kutusu; **Yinelenenleri kaldır**; **Metni sütunlara böl**;
   **Veri doğrulama oluştur** (liste / sayı aralığı / tarih) ve uygula (geçersiz
   girişte uyarı).
5. **Görünüm:** **Bölmeleri dondur oluştur** (seçili hücreye göre / ilk satır /
   ilk sütun / çöz); kılavuz çizgileri; başlıklar; formül çubuğu; dosyadaki
   `zoomScale` uygulanır.
6. **Satır/sütun:** gizle/göster menüsü (0 boyut hilesi yerine); başlık
   kenarına çift dokun = sığdır; boyut değişiklikleri geri alınabilir.
7. **Sayfa sekmeleri:** renk, gizle/göster, çoğalt, sürükle-bırak sıralama —
   hepsi geri alınabilir.
8. **Form görünümü** (telefona özel): seçili satır kart olarak — başlıklar
   etiket, hücreler alan; ‹ › satır, "Yeni kayıt"; sayı alanında tuş takımı,
   doğrulama listesinde açılır liste. Veri girişi ızgaradan çok daha rahat.
9. **Grafikler ızgarada çizilir** (`xlsx_chart` + `chart_painter`): dokun =
   seç, sürükle = taşı, köşe = boyut; tür ve aralık düzenle.
10. **Notlar (K24):** yaz/düzenle/sil — asgari VML şablonu, "Deneysel" etiketi;
    masaüstü Excel doğrulaması CIHAZ_TESTI'nde.
11. **CSV/TSV düzenleme:** CSV aynı ızgarada açılır (bugün salt okunur);
    ayırıcı, kodlama, satır sonu, tırnaklama korunur; biçim düğmeleri gizli,
    "Biçim CSV'de saklanmaz — XLSX olarak kaydet?" önerisi.

**Kabul ölçütleri:** her biçim/veri işlemi gidiş-dönüş testli + LibreOffice
onarımsız · dondurma oluştur → kaydet → Excel'de aynı (CIHAZ_TESTI) · CSV
düzenle-kaydet aynı ayırıcı ve kodlamayla (test) · form görünümü widget testi ·
PNG'ler.

**Bölünürse:** 27a = 1–2, 4–6 · 27b = 3, 7–11.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 27'yi uygula (bulut). Excel
> şeridini M365 adlarıyla düzenle; Hücreleri biçimlendir panelini (Sayı/Özel,
> Hizalama, Yazı tipi, Kenarlık, Dolgu), hücre stillerini, Veri araçlarını
> (çok düzeyli sırala, süzgeç oluştur, yinelenenleri kaldır, metni sütunlara böl,
> doğrulama oluştur), dondurma oluşturmayı, form görünümünü, ızgarada grafik
> çizimini, notları (K24) ve CSV düzenlemeyi ekle. PNG'ler. HAFIZA'ya yaz, durum
> tablolarını güncelle, main'e birleştir.

---

### Faz 28 — Slayt I: yerinde metin düzenleme, anahat, notlar

**Amaç:** Slayttaki yazıyı zorlanmadan, okunur boyutta, biçimiyle birlikte
düzeltmek.

**Kanıt:** SL2–SL5, SL6 (geri al, notlar), SL7. **Ön koşul:** Faz 20.
**Ortam:** ☁️.

**Yapılacaklar:**
1. **Seç / düzenle ayrımı (PowerPoint mobil):** dokun = şekli seç
   (tutamaklar; bağlam çubuğu: Metni düzenle · Kes · Kopyala · Sil · Çoğalt ·
   Öne/Arkaya); ikinci dokunuş / çift dokunuş = metin düzenleme, imleç dokunulan
   yerde.
2. **Kutuya yakınlaş:** düzenlemeye girince kanvas, kutu ekran genişliğinin
   ~%90'ı olacak ve klavyenin üstünde kalacak biçimde animasyonla yakınlaşır
   (`Motion` tokenları, ~300 ms); çıkınca geri döner; yazı ≥ 16 sp eşdeğeri.
3. **Zengin metin:** kutunun paragrafları tek düzenlenebilir alan; run'lar
   `TextSpan` → **seçime göre biçim** (run bölme) ve canlı görünüm (K T A, punto,
   renk, hizalama, madde/numara, girinti düzeyi); karışık biçim korunur
   (`_writeText` yerine run düzeyinde yazıcı); `a:br` ↔ satır sonu, `a:p` ↔
   Enter.
4. **Boş yer tutucular:** düzenin istem metni ("Başlık eklemek için dokunun")
   gri çizilir; dokununca yazılır (gerekirse slayta `p:sp` yer tutucu kopyası).
5. **Canlı sığdırma:** `normAutofit` kutuda yazdıkça yazı küçülür, `spAutoFit`
   kutu büyür (PowerPoint davranışı); mevcut iki geçişli ölçüm önbelleklenir.
6. **Klavye üstü çubuk (Slayt):** ↶ · K · T · A · punto − + · renk · hizalama ·
   • · 1. · Aa · ⌄; **Aa paneli:** Yazı · Paragraf · (Faz 29'da) Şekil.
7. **Anahat görünümü:** tüm slaytların başlık + gövde metinleri tek kaydırılabilir
   liste — yazım hatası düzeltmenin en hızlı yolu; dokununca slayta git; burada
   yapılan düzenleme slayta yansır.
8. **Konuşmacı notları düzenleme:** slaytın altında açılır not alanı; not yoksa
   `notesSlide` oluşturulur (notesMaster yoksa asgari şablon + ilişki + içerik
   türü).
9. **Geri al/yinele** (Faz 20) — metin, biçim, yapısal (çoğalt/sil/taşı/görsel)
   işlemler.
10. **Performans:** ayrıştırma isolate'te; slayt görünüm modelleri tembel
    (görünür ±2); düzenlenen yalnız şekil yeniden çizilir; `_fitScale` önbellekli.

**Kabul ölçütleri:** karışık biçimli paragraf düzenlenip kaydedilince diğer
run'lar aynen (XML testi) · boş yer tutucuya yazı → kaydet → PowerPoint'te başlık
olarak görünüyor (LibreOffice + CIHAZ_TESTI) · yakınlaşmada yazı ≥ 16 sp (widget
testi ölçer) · not ekle → kaydet → yeniden aç · 50 slaytlık destede açılış ve
kaydırma §7 · PNG'ler (`docs/design/faz28/`).

**Bölünürse:** 28a = 1–3, 6, 9 · 28b = 4–5, 7–8, 10.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 28'i uygula (bulut). Slaytta
> seç/düzenle ayrımını, kutuya yakınlaşmayı, seçime göre zengin metin biçimini
> (karışık run'lar korunarak), boş yer tutucuya yazmayı, canlı sığdırmayı, klavye
> üstü çubuk + Aa panelini, anahat görünümünü, konuşmacı notu düzenlemeyi ve geri
> al/yinele'yi yap; ayrıştırmayı isolate'e al. Önce PNG taslağını göster.
> HAFIZA'ya yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 29 — Slayt II: nesneler ve slaytlar

**Amaç:** Slaytta kutuyu yerleştirmek, şekil/tablo eklemek, yeni slaytı doğru
düzenle açmak — PowerPoint mobilde olduğu gibi.

**Kanıt:** SL6. **Ön koşul:** Faz 28. **Ortam:** ☁️.

**Yapılacaklar:**
1. **Taşı / boyutlandır / döndür:** 8 tutamak + döndürme tutamağı; oran kilidi
   (görselde varsayılan; köşe tutamağı); **hizalama kılavuzları** (slayt merkezi/
   kenarları + diğer şekillerin kenar/merkezleri) + hafif titreşim; donanım
   klavyesinde ok = 1 pt itme; `a:off/a:ext/rot` yazımı; grup içindeki şekilde
   grup dönüşümü tersine çevrilir.
2. **Ekle:** Metin kutusu · Şekil (dikdörtgen, yuvarlatılmış dikdörtgen, elips,
   üçgen, sağ ok, çizgi, yıldız — `prstGeom`, çizicinin bildikleri) · Görsel
   (var) · **Tablo** (satır×sütun seçici, `a:tbl` + tema tablo stili; hücreye
   dokun → yaz, ⇥ ile ilerle).
3. **Şekil biçimi** (Aa paneli "Şekil" sekmesi + bağlamsal **Şekil** sekmesi):
   dolgu (tema renkleri), çizgi (renk, kalınlık, kesik), saydamlık; Öne getir /
   Arkaya gönder; Sil / Çoğalt / kopyala-yapıştır (slaytlar arası).
4. **Yeni slayt:** düzen galerisi (`slideLayouts` küçük resimleri: Başlık Slaytı,
   Başlık ve İçerik, Bölüm Üst Bilgisi, İki İçerik, Yalnız Başlık, Boş) → yer
   tutucular kalıtılır; **Düzeni değiştir**; **Slaytı gizle**.
5. **Küçük resim şeridi:** dikey telefonda altta yatay şerit (PowerPoint mobil),
   yatay/tablette solda dikey; sürükle-bırak sıralama; uzun bas: çoğalt / sil /
   gizle / yeni. **Slayt sıralayıcı** ızgara görünümü.
6. **Tasarım:** slayt arka plan rengi; renk seçicide tema renkleri; **Geçişler:**
   Yok / Soldur / İt / Sil (asgari `p:transition`; sunum modunda oynar).

**Kabul ölçütleri:** taşı/boyutlandır → kaydet → LibreOffice/PowerPoint'te aynı
konum (EMU testi) · düzenden yeni slayt yer tutucularıyla açılıyor · tablo ekle →
onarımsız · küçük resim şeridinde sürükle-bırak sırası `sldIdLst`'e yazılıyor ·
PNG'ler.

**Bölünürse:** 29a = 1–3 · 29b = 4–6.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 29'u uygula (bulut). Slayta
> tutamakla taşı/boyutlandır/döndür + hizalama kılavuzlarını, metin kutusu/şekil/
> tablo eklemeyi, şekil biçimini, düzen galerisinden yeni slaytı, küçük resim
> şeridi + slayt sıralayıcıyı ve basit geçişleri ekle. Gidiş-dönüş testleri +
> PNG'ler. HAFIZA'ya yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 30 — Metin, kod ve Markdown düzenleyici

**Amaç:** Not, kod, yapılandırma ve Markdown dosyalarını telefonda rahatça
düzenlemek.

**Kanıt:** TX2–TX4. **Ön koşul:** Faz 20 (TX1 orada düzelir). **Ortam:** ☁️.
**Karar:** K25.

**Yapılacaklar:**
1. **Motor (K25):** `re_editor` denemesi — Türkçe IME (testTextInput), 5 MB
   açılış, kaydırma, APK farkı, bakım durumu; tutmazsa geliştirilmiş `TextField`.
2. Doğru **satır numaraları** (sarmalı satırda hizalı), geçerli satır vurgusu,
   **sözdizimi renklendirme** (uzantıya göre; > 1 MB'da kapalı ya da isolate),
   parantez eşleme, Enter'da girinti koruma, Tab = 2/4 boşluk ayarı, `() [] {}
   ""` otomatik kapatma (ayar).
3. **Klavye üstü çubuk (Metin/Kod):** ⇥ · `{ }` · `( )` · `[ ]` · `"` · `;` ·
   `=` · `< >` · `/` · ← → (imleç) · Bul.
4. **Bul/Değiştir:** büyük/küçük, tam sözcük, düzenli ifade, eşleşme sayısı;
   tümünü değiştir tek geri al adımı.
5. **Markdown:** Düzenle | Önizle sekmesi (telefon), yan yana (tablet); MD araç
   çubuğu (Başlık ▾, K, T, liste, numaralı, onay kutusu, bağlantı, kod, alıntı,
   tablo şablonu); önizleme mevcut `MarkdownText` ile.
6. ↶ ↷, otomatik kaydetme (Faz 20); alt bilgi satırında **kodlama + satır
   sonu** (UTF-8 · LF) ve değiştirme.
7. 5 MB üstü salt okunur kalır; "satır aralığını düzenle" (seçilen aralığı aç →
   düzenle → yerine yaz) isteğe bağlı.

**Kabul ölçütleri:** satır numaraları sarmalı satırlarda hizalı (widget testi) ·
2 MB dosyada tuş maliyeti §7 · Markdown önizleme testi · kodlama/satır sonu
korunuyor (test) · PNG'ler.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 30'u uygula (bulut). K25 için
> `re_editor`'ü dene ve kullanıcıya sun; seçilen motorla doğru satır numarası,
> sözdizimi renklendirme, klavye üstü kod çubuğu, gelişmiş bul/değiştir,
> Markdown önizleme + araç çubuğu, kodlama/satır sonu göstergesini yap. HAFIZA'ya
> yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 31 — PDF düzenleme deneyimi

**Amaç:** PDF'teki yazıyı sayfanın üstünde değiştirmek; eklenen yazı/imza/
görseli sonradan da düzenleyebilmek; PDF editörünün Office editörleriyle aynı
görünmesi.

**Kanıt:** ED5, PD1–PD6. **Ön koşul:** Faz 20. **Ortam:** ☁️.

**Yapılacaklar:**
1. **Ortak kabuk:** `PdfEditorScreen`, kalem, imza, form → Faz 20
   `EditorChrome` (aynı üst çubuk, ↶ ↷, durum); kip seçici şerit sekmesi gibi:
   **Metin · Çiz · İmzala · Form · Sayfalar · AI**.
2. **Yerinde metin düzenleme:** paragrafa dokun → sayfada aynı konum/genişlikte
   düzenleme alanı (yakınlaşmış), altındaki özgün metin gizlenir; yazı tipi
   gömülü fonttan yüklenebiliyorsa o, değilse en yakın; her duraklamada
   (300 ms) arka planda yeniden dizgi önizlemesi; **ret satır içinde**
   ("Bu yazı tipinde 'ğ' yok") + tek dokunuş alternatif: **"Üstüne yaz"** (beyaz
   kutu + yeni metin, Carlito/Noto). Diyalog yedek kalır.
3. **Biçim:** kalın/renk/boyut — paragraf motorunun izin verdiği ölçüde (aynı
   ailenin kalın kesimi belgede varsa); "yazı ekle" nesnelerinde serbest.
4. **Nesne katmanı:** "Yazı ekle", şekil, görsel, imza kaydedilene kadar
   **seçilebilir / taşınabilir / düzenlenebilir** nesneler (bugün damga); 4 köşe
   + oran kilidi; kaydette tek geçişte yazılır.
5. **Geri al/yinele:** dosya anlık görüntüsü yerine işlem listesi (komut);
   yinele eklenir; sayfa değişiminde tüm PDF'i yeniden okuma kalkar; kaydetme
   isolate'te ve tek seferde.
6. **Formlar sayfa üzerinde:** alana dokun → yerinde giriş (metin, onay kutusu,
   açılır liste, tarih seçici); klavye üstü çubuk ‹ › ✓ (önceki/sonraki alan).
7. **İmza:** yerleştirme tutamakları, kayıtlı imzalar, baş harf.
8. `InkPainter.shouldRepaint` gerçek karşılaştırma.

**Kabul ölçütleri:** yerinde düzenleme widget testi (alan paragrafın kutusunda) ·
reddedilen örnekte "Üstüne yaz" çıktısı doğru (`pdftotext` ile) · eklenen yazı
kaydetmeden önce taşınıp düzenlenebiliyor · 20 işlemlik oturumda disk kopyası
yok (test) · formlar sayfada dolduruluyor · PNG'ler.

**Bölünürse:** 31a = 1–2, 5 · 31b = 3–4, 6–8.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 31'i uygula (bulut). PDF
> düzenleme ekranlarını Faz 20 kabuğuna taşı; paragraf metnini sayfa üzerinde
> canlı önizlemeli düzenlet (ret durumunda "Üstüne yaz" alternatifi); eklenen
> yazı/şekil/görsel/imzayı kaydedilene kadar düzenlenebilir nesne yap; geri alı
> işlem listesine çevir, yinele ekle; formları sayfa üstünde doldurt. PNG'ler.
> HAFIZA'ya yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 32 — Görsel düzenleyici 2.0

**Amaç:** Fotoğraf düzenlemenin kasmadan, galeri uygulamaları kadar tanıdık
olması; kişisel bilgiyi gizleme aracı.

**Kanıt:** IM1–IM4. **Ön koşul:** Faz 20. **Ortam:** ☁️.

**Yapılacaklar:**
1. **Önizleme vekili:** ekran boyunda küçültülmüş görüntüde canlı ayar
   (kaydırıcı her kare), tam çözünürlük yalnız kaydette isolate'te → IM1 kökten
   kalkar; işaretlemede nokta başına `setState` yerine `ValueNotifier` + yalnız
   boya katmanı.
2. **Kanvas:** iki parmakla yakınlaştır/kaydır (düzenlerken de), çift dokun sığdır.
3. **Kırp ve döndür:** serbest açı düzeltme (−45…45, ızgara), dikey çevir, oran
   listesi (Faz 14 ile aynı).
4. **Ayarla:** + sıcaklık, ton, pozlama, vurgu/gölge (yaklaşık), canlılık,
   keskinlik, vinyet; her biri tek dokunuşla sıfır.
5. **Filtreler:** 10 hazır (Canlı, Sıcak, Soğuk, Siyah-Beyaz, Sepya, Solgun,
   Dram, Mat, Retro, **Belge**) — renk matrisi; canlı küçük resimler; şiddet
   kaydırıcısı.
6. **İşaretle:** kalem / vurgulayıcı / silgi; kalınlık + saydamlık + renk;
   şekiller (dikdörtgen, elips, ok, çizgi); **metin nesnesi** (taşı, boyutlandır,
   döndür, düzenle, yazı tipi, arka plan kutusu); **bulanıklaştır / pikselleştir
   fırçası** (yüz, plaka, kimlik numarası gizleme); nesne seç/sil.
7. **Yinele** + Faz 20 geçmişi; kaydırıcı adımları birleştirilir.

**Kabul ölçütleri:** 4000×3000 görüntüde kaydırıcı sırasında kare bütçesi (§7,
cihaz) · bulutta: önizleme ve çıktı aynı düzenlemeyi aynı oranda uyguluyor
(piksel testi, küçültülmüş karşılaştırma) · metin nesnesi kaydetmeden önce
taşınıp düzenlenebiliyor · bulanıklaştırma çıktıda geri döndürülemez (bölge
piksel testi) · PNG'ler.

**Bölünürse:** 32a = 1–3, 7 · 32b = 4–6.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 32'yi uygula (bulut). Görsel
> düzenleyiciye önizleme vekili (kasma kökten), pinch-zoom kanvas, serbest
> döndürme, genişletilmiş ayarlar, 10 filtre, kalınlık/saydamlıklı işaretleme,
> taşınabilir metin nesnesi, bulanıklaştırma fırçası ve yinele ekle. PNG'ler.
> HAFIZA'ya yaz, durum tablolarını güncelle, main'e birleştir.

---

### Faz 33 — Kapanış: tablet, donanım klavyesi, erişilebilirlik, uyumluluk, cihaz turu

**Amaç:** Düzenleme turunun telefonda, tablette ve gerçek Office'te doğrulanması.

**Ön koşul:** Faz 20–32. **Ortam:** ☁️ + 📱.

**Yapılacaklar:**
1. **Tablet / yatay / DeX:** Google Dokümanlar tabletteki gibi **kalıcı sağ
   biçim paneli** (Aa paneli yan bölmede, yazarken açık kalır); slayt şeridi
   solda; Excel'de geniş formül çubuğu.
2. **Donanım klavyesi:** kısayol tablosu (Ctrl+…, Excel ok/⇥/↵/F2/Ctrl+ok,
   Shift+ok seçim, Ctrl+Shift+ok aralık); **Ctrl+/** kısayol yardım sayfası.
3. **Erişilebilirlik:** şerit/çubuk TalkBack etiketleri + durum ("Kalın, açık"),
   editör içeriği erişilebilir (paragraf, hücre adresi + değer, slayt şekli),
   2,0× yazıda şerit taşmıyor; `meetsGuideline` testleri editör ekranlarına.
4. **RTL:** Arapça yazma Word/Excel/Slayt/Metin'de; şerit aynalı; `rtl_guard`
   bekçisi yeni dosyalara.
5. **Uyumluluk turu:** örnek setin düzenlenmiş çıktıları masaüstü
   Word/Excel/PowerPoint + Google Dokümanlar/E-Tablolar/Slaytlar + LibreOffice'te
   onarımsız açılıyor — tablo `docs/CIHAZ_TESTI.md`.
6. **Cihaz performans ölçümü** (düşük cihaz profili dahil): §7 tablosu
   doldurulur, aşımlar aynı oturumda düzeltilir.
7. **Cihaz turu:** Faz 20–32'nin cihaz maddeleri tek oturumda (FAZ_PLANI sıra 12
   cihaz turuyla birleştirilebilir).

**Kabul ölçütleri:** §7 tablosu cihaz değerleriyle dolu ve bütçe içinde ·
uyumluluk tablosu tam · TalkBack ile Word'de bir paragraf yazılıp kalın
yapılabiliyor · Arapça üç editörde doğru.

> **Açılış istemi:** `docs/DUZENLEME_PLANI.md` Faz 33'ü uygula. Bulut kısmı:
> tablet yan paneli, donanım klavyesi kısayolları + yardım sayfası,
> erişilebilirlik ve RTL testleri. Cihaz kısmı (yerel oturum + USB'li telefon):
> §7 performans tablosunu ölç, uyumluluk turunu yap, `docs/CIHAZ_TESTI.md`
> maddelerini kapat; kırmızıları aynı oturumda düzelt. HAFIZA'ya yaz, durum
> tablolarını güncelle, main'e birleştir.

---

## 10. Bilinçli kapsam dışı

Telefonda "rahat düzenleme" hedefinin dışında kalanlar — istenirse ayrı faz:

- Makrolar (VBA), Power Query, pivot tablo **oluşturma**, dinamik dizi
  işlevleri (`FİLTRE`, `BENZERSİZ`, `SIRALA`, `LET`) — motor sonra genişleyebilir.
- SmartArt ve denklem (OMML) **düzenleme** (görüntülenir, dokunulmaz ada olarak
  korunur).
- Gerçek zamanlı ortak düzenleme, bulut senkronu.
- İzlenen değişikliklerde tek tek kabul/reddet (Faz 24: tümü), izlenen değişiklik
  **kaydetme** kipi.
- Slayt animasyonu yazma (sunumda oynatılıyor), ses/video ekleme.
- Eski ikili biçimlerde (.doc/.xls/.ppt) yazma — "DOCX/XLSX/PPTX'e dönüştür ve
  düzenle" yolu var.
- PDF'te serbest yeniden akış (paragraf motoru sınırı; "Üstüne yaz" yedeği var),
  PDF'i Word'e dönüştürüp düzenleme (ayrı dönüştürme işi).
- Şifreli (parola korumalı) Office dosyalarını düzenleme.

---

## 11. Kaynaklar

**Microsoft 365 mobil**
- [Word for Android phones: Animated tips](https://support.microsoft.com/en-US/Word/word-for-android-phones-animated-tips) — şerit, "yazmadan önce şeridi gizle", Mobil görünüm, üç dokunuşla paragraf
- [Show or hide the ribbon in Word for mobile devices](https://support.microsoft.com/en-us/topic/b8a5b4c3-a187-45b7-a945-718e0524bfe1)
- [Use Word views to read or edit your document](https://support.microsoft.com/en-us/office/use-word-views-to-read-or-edit-your-document-bb918d39-fa40-461c-b503-873eddbdda43) — Mobil görünüm ↔ Yazdırma Düzeni
- [Excel for Android touch guide](https://support.microsoft.com/en-us/office/excel-for-android-touch-guide-aef977da-6adf-4724-b054-8ca4bb1d7afb) — seçim tutamağı, fırlatma
- [Excel for Android phones: Animated tips](https://support.microsoft.com/en-US/Excel/excel-for-android-phones-animated-tips) — fx, işlev kitaplığı
- [How to use Excel on Android phones (Noble Desktop)](https://blog.nobledesktop.com/how-to-use-excel-on-android-phones) — formül çubuğu ✓, çift dokunuş tuzağı
- [Excel numeric keypad on iPad and Android (Tech Community)](https://techcommunity.microsoft.com/discussions/excelgeneral/excel-numeric-keypad-on-ipad-and-android/3908657)
- [Microsoft'un Excel için klavyesi (wwwhatsnew)](https://wwwhatsnew.com/?p=214318)
- [PowerPoint for Android touch guide](https://support.microsoft.com/en-us/powerpoint/powerpoint-for-android-touch-guide) — çift dokunuş metin, tutamaklar
- [PowerPoint for Android phones: Animated tips](https://support.microsoft.com/en-US/PowerPoint/powerpoint-for-android-phones-animated-tips) — "yakınlaş, sonra boyutlandır"

**Google / Apple / rakipler**
- [Google Docs Android tablet redesign (9to5Google)](https://9to5google.com/2023/08/18/google-docs-android-tablet-redesign/)
- [Google Docs Android formatting sidebar (9to5Google)](https://9to5google.com/2024/02/16/google-docs-android-sidebar/)
- [Docs/Sheets/Slides formatting sidebar (PhoneArena)](https://www.phonearena.com/news/google-docs-slides-sheets-update-formatting-sidebar_id155434)
- [Autofill in Google Sheets mobile (The Bricks)](https://www.thebricks.com/resources/how-to-autofill-in-google-sheets-mobile)
- [Simplified data entry in Numbers for iPhone and iPad (Apple)](https://support.apple.com/en-gb/119889)
- [Collabora Office Android sürümleri (APKMirror)](https://www.apkmirror.com/apk/collabora-productivity-limited/collabora-office-rc/)

**Android klavye ve contenteditable**
- [contenteditable on Android is the absolute worst (ProseMirror forum)](https://discuss.prosemirror.net/t/contenteditable-on-android-is-the-absolute-worst/3810)
- [Samsung keyboard within Android WebView causes a spam of new lines (ProseMirror forum)](https://discuss.prosemirror.net/t/samsung-keyboard-within-android-webview-causes-a-spam-of-new-lines/5246)
- [W3C Editing TF — Android IME olayları (2017-06)](https://lists.w3.org/Archives/Public/public-editing-tf/2017Jun/0006.html)
- [ProseMirror changelog](https://prosemirror.net/docs/changelog) — 2025 Android klavye düzeltmeleri (1.40.1, 1.41.2)

**Flutter ve Android altyapısı**
- [TextInputConfiguration.enableDeltaModel](https://api.flutter.dev/flutter/services/TextInputConfiguration/enableDeltaModel.html) · [DeltaTextInputClient](https://api.flutter.dev/flutter/services/DeltaTextInputClient-mixin.html)
- [EditableText.stylusHandwritingEnabled](https://api.flutter.dev/flutter/widgets/EditableText/stylusHandwritingEnabled.html) · [Scribe](https://api.flutter.dev/flutter/services/Scribe-class.html)
- [Control and animate the software keyboard (Android)](https://developer.android.com/develop/ui/views/layout/sw-keyboard)
- [Flutter issue #118761 — klavye/gezinme çubuğu animasyon eşzamanı](https://github.com/flutter/flutter/issues/118761)
- [flutter_keyboard_controller](https://pub.dev/documentation/flutter_keyboard_controller/latest/) · [keyboard_insets](https://pub.dev/documentation/keyboard_insets/latest/)

**Editör kütüphaneleri**
- [Super Editor](https://pub.dev/documentation/super_editor/latest/)
- [How we built AppFlowy's rich-text editor](https://appflowy.com/blog/how-we-built-a-highly-customizable-rich-text-editor-for-flutter)
- [A comparison between rich text editors for Flutter (Walturn)](https://www.walturn.com/insights/a-comparison-between-various-rich-text-editors-for-flutter)
- [re_editor (pub.dev)](https://pub.dev/packages/re_editor)
