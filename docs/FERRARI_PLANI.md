# FERRARİ PLANI — Faz H0–H12: görünüm ve his (2026-11-14)

Kullanıcı bulgusu (tablet videosu + Samsung Dosyalarım karşılaştırması, 2026-11-14):
*"PDF açma, kaydırma, sayfa geçme, akıcılık, açılma hızı, kaydırma konforunda oldukça gerideyiz; arayüz olarak
gerideyiz; bir sürü özelliğimiz var ama makyajımız yok — Ferrari motoru takmış bir Opel gibiyiz."*

**Hedef:** bu plan bittiğinde uygulama, sabit 10 işlemde (§2) Samsung Dosyalarım + Samsung PDF görüntüleyiciyle
yan yana videoda **geride görünmez**. Yeni özellik değil; **hız hissi, okuma konforu, sadelik, tutarlılık**.

**Kapsam dışı:** yeni dosya biçimi, yeni AI özelliği, yeni ağ protokolü. Plan sürerken bunlar açılmaz
(§0 kural 1). Tek istisna kullanıcının açıkça istediği **video kırpma/kesme** (Faz H8).

> Bu belge, ayrıntıyı bilmeyen bir oturumun (alt model dahil) tek fazı baştan sona yapabilmesi için yazıldı.
> Her fazda **"Önce bak"** adımı zorunludur: aşağıdaki dosya yolları 2026-11-14 main'inden (`4e98b725`)
> alınmıştır; "doğrulanmadı" yazan yerler kod okunmadan yazılmış tahmindir — önce doğrula, yanlışsa planı düzelt.

---

## 0. Çalışma kuralları (her faz için geçerli)

1. **Özellik dondurma:** H fazları sürerken yeni özellik eklenmez. Faz içinde "şunu da ekleyeyim" → `KALANLAR.md`'ye yaz, yapma.
2. **Dal + PR:** her faz `faz-HN` dalında (ör. `faz-H4`), iş sonunda PR → CI yeşil → main'e birleştir
   (CLAUDE.md §4 faz istisnası). PR başlığına `[apk]` yaz. Faz içindeki her madde **ayrı commit** (tek `git revert` ile geri alınabilsin).
3. **Doğrulama = CI.** Bulutta `flutter test/analyze` koşturma. 📱 işaretli fazlarda yerel/cihaz ölçümü serbest ve **zorunlu**.
4. **Tahminle performans düzeltmesi yok.** 📱 işaretli maddede önce ölç (H0 tabanı), değiştir, yeniden ölç; tablo
   `docs/perf/2026-11-HN.md`. Ölçülemeyen "hızlandırma" birleşmez. (☁️ maddeler görsel/yapısal; ölçüm istemez.)
5. **Tasarım tokenları zorunlu** — ham değer yazma:
   - boşluk `Gap.xs/sm/md/lg/xl` (4/8/16/24/32), köşe `Radii.*`, yazı `Theme.of(context).textTheme` / `AppType` (`lib/core/theme.dart`)
   - süre/eğri `Motion.short/medium/long`, `Motion.enter/exit/standard`, her zaman `Motion.of(context, …)` (`lib/core/motion.dart`)
   - simge `AppIcons.*`, renk `AppColors`/`context` şema renkleri, titreşim `AppHaptics.selection/step/destructive/done`
   - pencere/levha `lib/widgets/app_dialog.dart`, `app_action_sheet.dart`, `quick_sheets.dart`; bildirim `lib/core/snack.dart`
   - metin: `context.t('anahtar')`; her yeni anahtar `lib/core/l10n/strings/*.dart` içinde **üç dilde** (tr, en, ar).
6. **Bekçi testleri (kırmızı yapan yaygın hatalar):**
   - `test/design_tokens_test.dart`: dosya başına ham `Icons.`, `Color(0x`, `Colors.`, `fontSize:`, `Duration(milliseconds:`,
     `showDialog`, `showModalBottomSheet` sayısı `test/design_tokens_baseline.json` tavanını geçemez; **yeni dosyada tavan 0**.
     Bir dosyayı temizlediysen tavanı düşür (yalnız azalış yazılır).
   - `test/motion_tokens_test.dart`: "animasyonları kaldır" açıkken süre 0 olmalı → `Motion.of` kullan.
   - `test/*_guard_test.dart` (rtl, navigator, route, bare_input …): yeni ekran RTL'de de doğru dizilmeli (`EdgeInsetsDirectional`, `AlignmentDirectional`).
   - Widget içinde `Future.delayed` **yazma** (testte "Timer is still pending"); iptal edilebilir `Timer` kullan, `dispose`'ta iptal et.
   - `await` sonrası `setState`/`context` kullanımından önce `if (!mounted) return;`.
   - Ekran kodunda senkron dosya G/Ç (`existsSync` vb.) ve boş `catch` yasak/tavanlı; gerekçeli yorum yaz.
7. **Commit gövdesi:** kullanıcı diliyle `Yeni: …` / `İyileştirme: …` / `Düzeltme: …` satırları (CLAUDE.md §4). Son satırlar ortamın verdiği `Co-Authored-By` + `Claude-Session`.
8. **Faz sonu:** HAFIZA.md'ye tarihli kayıt (karar / kök neden / tuzak), `docs/CIHAZ_TESTI.md`'ye telefonda bakılacak maddeler,
   bu dosyada fazın kutucukları `[x]`, `KALANLAR.md` Faz H satırı güncel.
9. **Bitti tanımı (faz):** tüm maddeler `[x]` ya da gerekçeyle "yapılmadı"; CI yeşil; 📱 fazda ölçüm tablosu var; kullanıcıya **tek ekran görüntüsü/video isteği** ile telefonda onay sorulur.
10. **Tasarım ekran görüntüsü:** görünümü değişen her ekran için `tool/design_shots_*_test.dart` düzeniyle öncesi/sonrası görüntü
    (yeni dosya `tool/design_shots_fazH<N>_test.dart`; elle koşturulur, CI'da koşmaz) → `docs/design/fazH<N>/`.

Ortam işaretleri: ☁️ bulutta yapılır · 💻 yerel Windows · 📱 cihaz gerekir · 👤 kullanıcı kararı.
Boyut: **K** (≤ yarım gün) · **O** (1–2 gün) · **B** (3+ gün).

---

## 1. Tasarım ilkeleri (karar verirken buna bak)

1. **İçerik önce:** belge/dosya ekranın ≥ %85'i. Çubuk, şerit, rozet ancak gerektiğinde görünür.
2. **Bir ekranda tek vurgu rengi**, tek birincil eylem. Gerisi nötr.
3. **Boşluk cömert:** liste satırı ≥ 64 dp (tablette 72), yatay kenar `Gap.md`+; sıkışık satır yok.
4. **Yazı hiyerarşisi 3 kademe:** başlık (büyük, kalın) · gövde · ikincil (soluk, küçük). Dördüncü boy icat etme.
5. **Her dokunuş 100 ms içinde görünür tepki verir** (basma hâli, dalga ya da titreşim). İş uzunsa önce iskelet/yer tutucu gelir, boş beyaz ekran asla.
6. **Hareket kısa ve anlamlı:** 120–320 ms (`Motion`), nereden geldiyse oraya döner. Süs animasyonu yok.
7. **Aynı anda en çok bir geçici bildirim.** Bilgi notu 3–4 sn; eylem gerektirmiyorsa hiç gösterme.
8. **Menü ≤ 6 madde;** fazlası "Diğer" altına. Sık kullanılan üstte.
9. **Tablet ayrı düşünülür:** ≥ 840 dp'de iki bölme; içerik satır genişliği sınırlı (okunabilirlik).
10. **Varsayılan sade, güç isteyene açık:** ileri seçenekler ayarlardan/uzun basıştan gelir.

---

## 2. Ölçüm seti — "10 işlem" (H0'da taban, H12'de kapı)

Aynı cihazda (kullanıcının tableti + Mi Note 10 Lite), aynı dosyalarla, bizde ve Samsung'da ekran kaydı + kronometre:

| # | İşlem | Ölçülen |
|---|---|---|
| 1 | USB'deki 231 MB PDF'e dokun → ilk sayfa net | sn |
| 2 | Aynı PDF, 50 sayfa hızlı kaydır | boş sayfa görülen toplam süre, kare p90/p99 |
| 3 | 600. sayfaya git (tutamaç / sayfaya git) | sn |
| 4 | İki parmakla yakınlaştır, bırak → netleşme | sn |
| 5 | PDF'i kapat, yeniden aç → kaldığı sayfa net | sn |
| 6 | Uygulama soğuk açılış → ana ekran etkileşimli | sn |
| 7 | 2.000 dosyalı klasörü aç, sona kaydır | sn, kare p99 |
| 8 | Belgeler → yalnız PDF süz → ada göre sırala | dokunuş sayısı, sn |
| 9 | 1 GB video aç → oynat → 10 dk ileri sar | sn |
| 10 | Fotoğraf klasörü aç → resme dokun → yana kaydır | sn, kare p99 |

Araçlar: `tool/perf_senaryo.sh`, `tool/pdf_profil.sh`, `integration_test/perf_senaryolari_test.dart` (USB/PDF senaryosu
yoksa H0'da eklenir), ekran kaydı. Kare ölçümü yalnız `flutter drive --profile` ile (HAFIZA 2026-11-13: `input swipe` ölçümü yanıltır).

---

## 3. Fazlar

Öneri sırası: **H0 → H1 → H2 → H4 → H3 → H8 → H6 → H7 → H5 → H9 → H10 → H11 → H12.**
H1, H4, H6, H7, H10 buluttan başlanabilir; H0, H2, H12 cihazsız bitmez.

---

### Faz H0 — Ölçüm tabanı ve rakip videosu 📱💻 · K

**Amaç:** "geride" sözünü sayıya çevirmek; sonraki fazların kapısı.

- [ ] H0.1 §2'deki 10 işlemi bizde ve Samsung'da kaydet; tablo `docs/perf/2026-11-H0.md` (iki cihaz sütunu).
- [ ] H0.2 `integration_test/perf_senaryolari_test.dart`'a "büyük PDF aç + 50 sayfa kaydır" senaryosu (yoksa). Dosya `OLCUM_VERISI` altında; USB yolu parametre.
- [ ] H0.3 PDF açılışında zaman damgaları: dokunuş → `PdfDocument` hazır → ilk sayfa bitmap'i → küçük resim şeridi. Debug/profil logu (`PDFPRO_PERF` biçimi, HAFIZA 2026-11-13).
- [ ] H0.4 2026-11-14 düzeltmesinin (form taraması baş+son, küçük resim gecikmesi — PR #90) etkisi: öncesi/sonrası 1. işlem.

**Bitti:** tablo var; en kötü 3 işlem adlandırılmış; H1/H2 madde sırası buna göre güncellenmiş.

---

### Faz H1 — PDF açılış hissi ☁️ (H1.4 📱) · O

**Önce bak:** `lib/screens/viewer_screen.dart` (initState ~614–623, `_offerFormFilling`, `_restoreReadingPage`),
`lib/screens/viewer/body.dart` (`PdfViewer.file` ~59, `_withPdfSidePanel` ~556), `lib/widgets/pdf_resume_note.dart`,
`lib/services/fm/pdf_thumbnail.dart`, `lib/services/fm/entry_opener.dart`, `lib/widgets/pdf_page_frame.dart`.

- [x] H1.1 **Kapak köprüsü:** belge yüklenene kadar boş zemin yerine dosya listesindeki kapak küçük resmi (varsa `PdfThumbnail`
      önbelleğinden) sayfa çerçevesi içinde, ortalanmış ve yumuşak gösterilir; ilk gerçek sayfa gelince `Motion.short` ile solar.
      Küçük resim yoksa sayfa oranında nötr kâğıt iskeleti. Kabul: açılışta hiçbir karede düz boş ekran yok.
- [x] H1.2 **Açılış notlarını tekleştir:** "N. sayfadan devam" hapı + "doldurulabilir form" SnackBar'ı aynı anda çıkmasın.
      Form bilgisi SnackBar olmaktan çıkar → üst çubukta küçük "Form" rozeti/düğmesi (dokununca `_fillPdfForm`). Devam hapı 3 sn.
      Kabul: açılışta en çok bir geçici öğe; alt kenarı kapatan şerit yok.
- [x] H1.3 **Yan şerit tercihi:** ≥ 840 dp'de küçük resim şeridi aç/kapa düğmesi (üst çubuk), tercih `SharedPreferences`'ta kalıcı;
      varsayılan **kapalı** (içerik önce). Açıkken güncel sayfa şeritte görünür kalır (kaydırınca şerit de izler).
- [ ] H1.4 📱 **Son sayfa görüntüsü:** kapanırken görünen sayfanın düşük çözünürlüklü görüntüsü (≤ 200 KB JPEG, yol SHA-1'i adıyla,
      en çok 50 belge, uygulama önbellek dizini) saklanır; yeniden açılışta H1.1 köprüsü kapak yerine bunu kullanır.
      Kasa/özel dosyada **saklanmaz** (`PrivateZone.isPrivatePath`). Kabul: §2 işlem 5'te içerik < 0,3 sn'de görünür.
- [ ] H1.5 (H6.3 ile birlikte yapılacak — 2026-11-14) Açılış geçişi: dosya satırından görüntüleyiciye `Motion.medium` ile büyüyen geçiş (bkz. H6.3; burada yalnız PDF).

**Durum (2026-11-14):** H1.1–H1.3 yapıldı (dal `ccr-1904fd13-pttu60` → main). Kapak yalnız listede ÜRETİLMİŞSE gelir
(`PdfThumbnail.cachedCover` üretmez); köprü `onViewerReady` + `Motion.medium` sonra solar (gerçek "ilk bitmap" olayı pdfrx'te
yok — 📱 cihazda beyaz kare görülürse süre ayarlanır). Form düğmesi İçindekiler'in yerine geçer (üst çubukta en çok 3 eylem).
H1.4 📱 bekliyor (KALANLAR), H1.5 → H6.3.

**Tuzaklar:** pdfrx boy değişince sayfa başına atlar (HAFIZA 2026-10-23) → köprü `Stack` katmanı olsun, görünüm boyunu değiştirme.
`_pdfSearcher` yalnız `onViewerReady`'de kurulur. Zamanlayıcılar iptal edilebilir olmalı (§0.6).

---

### Faz H2 — PDF kaydırma akıcılığı 📱💻 · B

**Önce bak:** `lib/screens/viewer/body.dart` `PdfViewerParams` (~65–200), `lib/core/device_profile.dart` (`pdfImageCacheBytes`),
`third_party/` altındaki pdfrx yaması (HAFIZA "pdfrx yama"), `docs/PDF_PRO_PLANI.md` bütçeler, `docs/perf/`.

- [ ] H2.1 **Önbellek tavanı ölç:** `pdfImageCacheBytes` high = 64 MB. Tablette tam çözünürlüklü sayfa ≈ 16 MB → ~4 sayfa.
      96 / 128 / 192 MB dene; §2 işlem 2 + PSS tablosu. Karar: boş sayfa süresi ≥ %30 düşüyor ve PSS bütçesi (PDF_PRO_PLANI) aşılmıyorsa yükselt; yalnız `DeviceTier.high`.
- [ ] H2.2 **Bulanık yer tutucu:** hızlı kaydırmada beyaz sayfa yerine düşük çözünürlüklü (≤ 48 dpi) görüntü. Önce pdfrx'in kendi
      aşamalı çizimi yeterli mi ölç (doğrulanmadı); yetmiyorsa görülen sayfaların küçük görüntülerini (LRU, ≤ 24 MB) tutan katman.
- [ ] H2.3 **Komşu sayfa ön çizimi:** kaydırma yönünde +2 sayfa önceden çizilsin (pdfrx `cacheExtent` benzeri parametre — adını kaynakta doğrula).
- [ ] H2.4 **Hızlı tutamaç:** mevcut `PdfViewerScrollThumb` (body.dart ~177) sürüklenirken sayfa numarası + küçük önizleme balonu;
      sürükleme sırasında ana görünüm çizimi bekletilir, bırakınca çizer. Kabul: §2 işlem 3 ≤ Samsung.
- [ ] H2.5 **Yakınlaştırma netleşmesi:** bırakınca yeniden çizim gecikmesi ölç (§2 işlem 4); gerekiyorsa kademeli (önce görünen bölge).
- [ ] H2.6 USB yolu: dosya okuma hızı ölç (sıralı / rastgele). Yavaşsa ilk açılışta arka planda uygulama önbelleğine kopyalama **önerisi**
      (👤 karar: yer kaplar) — yalnız ölçüm kötüyse.

**Kapı:** §2 işlem 1–5'in hiçbiri H0'a göre kötüleşmez; işlem 2'de boş sayfa süresi ≥ %50 azalır ya da Samsung'la eşit.

---

### Faz H3 — PDF okuma konforu ☁️📱 · B

**Önce bak:** `lib/screens/viewer/pdf_reading_aids.dart`, `pdf_reading_pro.dart`, `pdf_navigation.dart`, `body.dart` (görselde çift dokunma ~363;
PDF'te çift dokunma **yok gibi — doğrula**), `lib/widgets/pdf_page_navigator.dart`, `lib/widgets/pinch_zoom_area.dart`.

- [x] H3.1 **Çift dokunma:** PDF'te çift dokununca dokunulan noktaya ~2,5× yakınlaşır; tekrar çift dokununca genişliğe sığar. Animasyon `Motion.medium`.
      *(Doğrulandı: PDF'te çift dokunuş yalnız kelime SEÇİYORDU — seçim katmanı. Artık pdfrx `onGeneralTap` (tanıyıcı zaten kurulu);
      seçim katmanında `doubleTapSelectsWord: false`, kelime uzun basışla.)*
- [x] H3.2 **Akıllı yakınlaştırma:** çift dokunulan yerdeki metin sütunu/görsel kutusu bulunabiliyorsa (pdfrx sayfa metin kutuları / PDF Pro nesne sınırları)
      o kutu genişliğe oturur. Bulunamazsa H3.1 davranışı. *(PDF Pro `PdfEditBridge.content`; sütun = çevredeki satır aralıklarının
      birleşimi, boşluk > %2 genişlik ayrı sütun; saf hesap `services/pdf/pdf_reading_zoom.dart`.)*
- [x] H3.3 **Görsel kipi:** sayfadaki görsele uzun basış → "Görseli büyüt": siyah zemin, tam ekran, sıkıştır-yakınlaştır, aşağı çekince kapanır.
      (Radyoloji atlası kullanımı.) Görsel bulma: PDF Pro nesne katmanı (`lib/screens/pdf_editor/layer_objects.dart`) — yeniden yazma, onu kullan.
      *(Not: `layer_objects.dart` düzenleyicinin YENİ eklenen nesneleri; sayfanın kendi görselleri PDF Pro'nun nesne okumasında
      (`PdfEditBridge.content`, blok katmanının `_itemAt`'ı da bunu kullanır) — o kullanıldı. Görsel bölgesi yüksek çözünürlükte
      çizilir (≤ 3072 px); ekran `widgets/pdf_image_zoom.dart`. Sayfanın %85'ini kaplayan görsel (taranmış sayfa) sayılmaz.)*
- [x] H3.4 **Kenar boşluğu kırpma:** aç/kapa; sayfa içerik sınırı ilk 5 sayfanın düşük çözünürlüklü taramasından (izolatta) kestirilir, tüm belgeye uygulanır. Tercih belge başına hatırlanır (`PdfZoomMemory` yanına).
      *(Yalnız YATAY + tek sütun: pdfrx sayfayı kırpmadan çizer, üst/alt için sayfalar üst üste binmeli — sonraki sayfanın
      kenarı öncekinin metnini örter. Paylar `pdf_crop_v1`, açılışta düzen ilk karede kırpılmış.)*
- [x] H3.5 **Sayfa sayfa geçiş kipi:** sürekli kaydırmaya ek; kenara dokun / yana kaydır → sonraki sayfa, sayfa ekrana sığar. Ayar görüntüleme menüsünde.
      *(Okuma ayarları "Sayfa sayfa çevir", tek sütun, `pdf_paged`. Kenar şeridi %25; yukarı/aşağı kaydırma da çevirir; RTL'de ters;
      yakınken serbest gezinme; ses tuşları da sayfayı sığdırarak çevirir.)*
- [x] H3.6 **Sürükleyici okuma:** kaydırırken çubuklar gizlenir (var: `Motion.readingIdle`), tek dokunuş geri getirir; durum çubuğu da gizlensin (tercih).
      *(Çubuk + dokunuş zaten vardı. Eklenen: "Okurken durum çubuğunu da gizle" (`pdf_hide_status`); yalnız durum çubuğu
      (`SystemUiMode.manual` + alt), gizliyken içerik payı eski boyda tutulur — PDF sayfa başına atlamaz.)*
- [x] H3.7 Sayfa rozeti (N / toplam): yalnız kaydırma sırasında görünür, 1,5 sn sonra solar. *(`Motion.badgeLinger`; sayfaya git ⋮ menüsünde.)*

**Durum (2026-11-14):** H3.1–H3.7 kodda bitti (dal `faz-H3`, her madde ayrı commit). 📱 cihaz turu `CIHAZ_TESTI.md` "Ferrari H3".

---

### Faz H4 — Dosya listesi: Samsung düzeyi ☁️ · B

**Önce bak:** `lib/widgets/fm/fm_entry_tiles.dart`, `fm_file_list_view.dart`, `fm_list_controls.dart`, `fm_type_chips.dart`,
`fm_quick_filters.dart`, `fm_path_bar.dart`, `fm_entry_thumbs.dart`, `fm_fast_scroller.dart`, `lib/screens/fm/browser_screen.dart`,
`lib/screens/fm/category_screen.dart`, `lib/widgets/section_header.dart`. Karşılaştırma görüntüleri: kullanıcının 2026-11-14 fotoğrafları
(Samsung: büyük başlık "Belgeler / 8,90 GB", altında `Tümü · PDF · DOC` çipleri, "Dosya görünümü ▾", sağda "↓≡ Tarih | ↓", ferah satırlar).

- [x] H4.1 (2026-11-14: 52 dp, `titleMedium`, bilgi solda/boyut sağda, ≥ 64/72 dp; bölücü eklenmedi — satırlarda yoktu) **Satır ölçüsü:** küçük resim 48–56 dp, ad `titleMedium` tek/iki satır, altında ikincil satır (tarih solda, boyut sağda hizalı),
      satır yüksekliği ≥ 64 dp (≥ 840 dp'de 72). İnce bölücü yalnız metin hizasından başlar. Tek kaynak: `fm_entry_tiles.dart`.
- [x] H4.2 (**KALDIRILDI 2026-11-14, kullanıcı: "önce büyük başlık sonra üste çıkmaz, gereksiz"** — başlık + özet yeniden yalnız üst çubukta; eski not:) (2026-11-14: `FmLargeTitle` + `FmTitleCollapse`; eşikle katlanır — sürekli değil, liste dışında olduğu için; kategori + klasör) **Büyük başlık:** kategori/klasör ekranında büyük başlık + toplam boyut; kaydırınca üst çubuğa küçülür (`SliverAppBar` büyük başlık düzeni).
- [—] H4.3 (2026-11-14 kullanıcı: *"filtreler mantık olarak bizimki kalsın"* → uygulanmaz) **Tür çipleri:** kategori ekranında `Tümü` + o kategoride gerçekten bulunan türler (PDF, DOC, XLS, PPT …), tek satır, yatay kaydırılır,
      seçili çip dolu vurgu. Mevcut `fm_type_chips.dart`/`fm_quick_filters.dart` **sadeleştirilir** (yenisi yazılmaz). Kullanıcı: "filtrelerini daha çok beğendim".
- [—] H4.4 (aynı kullanıcı kararı: sıralama/süzgeç "Analiz ve diğer" hapında kalır) **Sıralama satırı:** çiplerin altında solda görünüm seçici ("Liste / Izgara / Ayrıntı"), sağda "Sırala: Tarih ▾" + yön oku. Tek dokunuşla yön değişir (§2 işlem 8).
- [x] H4.5 (2026-11-14: `SliverMainAxisGroup` + sabitlenmiş başlık; liste ve ızgara) **Tarih grupları:** tarihe göre sıralıyken "Bugün · Bu hafta · Bu ay · Daha eski" bölüm başlıkları (yapışkan).
- [x] H4.6 (zaten vardı: haplar, son parça vurgulu, ters kaydırma — `fm_path_bar.dart`) **Yol çubuğu:** `USB depolama alanı 1 › Kitaplar` biçimi; son parça vurgulu; her parça dokunulur; taşarsa baştan kısalır.
- [x] H4.7 (doğrulandı: `recommendDeferredLoadingForContext`, `fm_entry_thumbs.dart`) **Küçük resimler:** kaydırma hızlıyken üretim bekler, durunca üretilir (mevcut davranışı doğrula); yer tutucu tür simgesi anında.
- [x] H4.8 (2026-11-14: `PressScale` 0,98; titreşim, "N / toplam seçildi", 5 eylem + Diğer zaten vardı) **Seçim kipi:** uzun basışta satır hafif içe basılır + `AppHaptics.selection`; üstte "N seçildi", altta en çok 5 eylem + "Diğer".
- [x] H4.9 (soluk, %60) Satır sonu ⋮ düğmesi kaldırılır ya da soluklaşır (uzun basış + seçim çubuğu yeter) — 👤 karar; varsayılan: soluk.

**Kabul:** aynı klasörün bizde ve Samsung'da ekran görüntüsü yan yana konduğunda bizimki daha sıkışık/kalabalık görünmüyor; §2 işlem 8 dokunuş sayısı ≤ Samsung.

---

### Faz H5 — Ana ekran sadeleştirme ☁️👤 · O

**Önce bak:** `lib/screens/fm/dashboard_screen.dart` + `dashboard/`, `lib/widgets/fm/home_quick_row.dart`, `recent_strip.dart`,
`smart_inbox.dart`, `fm_category_tile.dart`, `dashboard_layout_sheet.dart`, HAFIZA "Pano", "kartlar".

- [x] H5.1 (2026-11-14, envanter aşağıda) Envanter: ana ekranda ilk açılışta görünen her öğeyi listele (kart, sıra, rozet, düğme). Hedef: ilk ekranda ≤ 4 bölüm.
- [x] H5.2 (2026-11-14: `DashboardLayout.sections` = son dosyalar · kategoriler · bellek · araçlar · favoriler · hızlı klasörler; "Son açılanlar" yeni kurulumda görünür; kaydı olanın sırası/gizledikleri korunur, eski kayıtta hiç geçmeyen `recent` yine gizli) Varsayılan düzen: (1) arama, (2) son dosyalar şeridi, (3) kategoriler ızgarası, (4) depolama. Gerisi ("araçlar", AI, öneriler) alta ya da "Diğer"e.
      Kullanıcının özelleştirdiği düzen **bozulmaz** (`custom_cards_v1`, pano düzeni kayıtları).
- [x] H5.3 (doğrulandı, değişiklik yok: `FmCategoryGrid` sabit sütunlu tek boy, simge ailesi temadan tek, alt satır yalnız bilgi varsa, renk yalnız simgede) Kategori kutuları tek boy, tek simge ailesi, sayı/boyut ikincil satırda. Renk: yalnız simge zemini.
- [x] H5.4 (zaten var: `_StorageHero` "kullanılan / toplam" + 6 dp kategori çubuğu, 2026-10-18 kullanıcı tasarımı korunur; USB/SAF/ham USB ayrı kart) Depolama satırı Samsung'daki gibi: "Dahili depolama 65,6 GB / 128 GB" + ince çubuk; USB takılıyken ayrı satır.
- [x] H5.5 (2026-11-14: güncelleme şeridi TEK SATIR — "Yeni sürüm var · v1.2.3" + Güncelle; kapatma düğmesi EKLENMEDİ — 2026-11-10 kullanıcı kararı "kalıcı uyarı"; çökme uyarısı ve akıllı bildirim alanı zaten olay yokken çizilmiyor) "Yeni sürüm var" şeridi ve benzeri kalıcı uyarılar tek satır, kapatılabilir.

**H5.1 envanteri (2026-11-14, telefon, tek sütun):** üst çubuk = arama kapsülü (AI · yenile · ayarlar içinde) ·
[koşullu] çökme uyarısı · [koşullu] güncelleme şeridi · [koşullu] akıllı bildirim alanı (süren iş / bellek dolu / ağ paylaşımı) ·
[koşullu] izin kartı · [koşullu] tarama ilerlemesi · **bölümler** (eski varsayılan: bellek panosu → kategoriler 11 kutu → araçlar →
favoriler → hızlı klasörler; "Son açılanlar" gizli) · "Ana ekranı düzenle" + "Alt paneli düzenle" · son tarama satırı.
Koşullu öğeler olay yokken çizilmez. Yeni varsayılanla ilk ekran: **arama · son dosyalar · kategoriler · bellek** (4 bölüm).

---

### Faz H6 — Hareket ve dokunuş ☁️ · O

**Önce bak:** `lib/core/motion.dart`, `lib/core/page_transitions.dart`, `lib/core/app_haptics.dart` (18 dosyada kullanılıyor), `lib/widgets/motion.dart`.

- [x] H6.1 **Titreşim kapsamı:** `AppHaptics` çağrılmayan şu yerleri tamamla: seçim başlat/bitir, sürükle-bırak al/bırak, silme onayı (`destructive`),
      iş bitti (`done`), kaydırıcı/tutamaç kademeleri (`step`), sayfa sonu. Liste: `grep -rL "AppHaptics" lib/screens lib/widgets` ile eksikleri çıkar.
      *(2026-11-14: seçim dokunuşu/kapatma + sürükleyerek seçimde her yeni öğe; 7 yeniden sıralama listesi + 3 `LongPressDraggable` (kendi
      ayarsız titreşimi kapatıldı, bekçi test); yıkıcı onay `showAppConfirm` tek kapı; iş bitti `JobNotifications.onFinished`; kademeli
      kaydırıcılar `AppHaptics.slider`. Sayfa sonu: PDF sayfa seçici/gezinme zaten `step` — ayrı "son sayfa" titreşimi eklenmedi.)*
- [x] H6.2 **Basma hâli:** dokunulabilir her yüzeyde `InkWell`/basma ölçeği (0,98) — basılınca tepki ≤ 100 ms. Çıplak `GestureDetector` satırlarını bul, düzelt.
      *(2026-11-14: kitaplık kapakları, Fotoğraflar karesi, Benzer görseller, galeri şeridi, tarama sayfa kartı → `PressScale` (70 ms). Kalan
      çıplak `GestureDetector`ler düzenleyici kanvasları (hücre, slayt nesnesi, PDF katmanı) — basma ölçeği orada yanlış olur, bilinçli dışarıda.
      `PressScale` süreleri `Motion.of`'a bağlandı.)*
- [x] H6.3 **Açılış geçişi:** dosya satırı → görüntüleyici: küçük resimden büyüyen kapsayıcı geçişi (`Hero` ya da `OpenContainer` benzeri el yapımı; yeni paket ekleme).
      Geri dönüşte aynı satıra küçülür. `Motion.reduced` açıkken düz geçiş.
      *(2026-11-14: GÖRSEL için yapıldı — `FmFileListView` satır/ızgara → galeri Hero (`fmMediaHeroTag`). PDF/Office görüntüleyicisine kapsayıcı
      geçişi YAPILMADI: açılış hissi H1.4 cihaz ölçümüne bağlı (ağır ilk kare + büyüme animasyonu takılma riski); H11.3 ile birlikte ele alınacak.)*
- [ ] H6.4 **Liste değişimleri:** silme/taşıma sonrası satır `Motion.short` ile kapanır; yeni gelen satır belirir (2.000+ öğede kapalı — ölç).
      *Yapılmadı (2026-11-14):* liste H4'te `SliverMainAxisGroup` + `SliverPrototypeExtentList` gruplarına bölündü; satır kapanışı için
      `SliverAnimatedList`e geçmek sabit satır boyu (hızlı kaydırıcı, sürükle-seç dizin hesabı) varsayımını bozar ve "2.000+ öğede ölç" şartı
      cihaz ister (§0.4) → H2/H12 ölçüm turuna bırakıldı (`KALANLAR.md`).
- [x] H6.5 **Levhalar:** tüm alt levhalar aynı köşe, aynı tutamaç, aynı açılış eğrisi (`app_action_sheet.dart` tek kaynak; ham `showModalBottomSheet` tavanını düşür).
      *(2026-11-14: denetim — 55 ham çağrının HİÇBİRİ köşe/tutamaç/eğri vermiyor, hepsi `AppTheme.bottomSheetTheme`'den; tek bilinçli istisna
      `quick_sheets` yüzen kartı. Bekçi `test/sheet_consistency_guard_test.dart`. Tavanı düşürmek = 55 çağrıyı `showAppSheet`'e taşımak; görünür
      fark yok, ayrı temizlik işi.)*
- [x] H6.6 **Öngörülü geri:** Android 14+ geri hareketi önizlemesi tüm ana rotalarda (manifest `enableOnBackInvokedCallback` + `PopScope` denetimi; `ci/AndroidManifest.xml`).
      *(2026-11-14: manifest zaten açıktı ama önizleme YOKTU — kök neden HAFIZA. `FastPageTransitionsBuilder` içine `_PredictiveBackPreview`.
      `PopScope(canPop: false)` olan 3 rota hareketi üstlenmez (onay penceresi çalışır). 3 widget testi.)*

**Durum (2026-11-14):** H6.1–H6.3, H6.5, H6.6 yapıldı; H6.4 gerekçeyle ölçüm turuna bırakıldı. 📱 cihaz bakışı `CIHAZ_TESTI.md` "Ferrari H6".

---

### Faz H7 — Sadeleştirme: bildirim, menü, ipucu ☁️👤 · O

**Önce bak:** `lib/core/snack.dart`, `lib/widgets/menu_kit.dart`, `doc_more_sheet.dart`, `lib/screens/viewer/shell_menus.dart`,
`lib/widgets/fm/fm_more_sheet.dart`, `legacy_banner.dart`, `crash_notice.dart`.

- [x] H7.1 **Bildirim envanteri:** `grep -rn "showSnackBar\|Toasts\.\|showSnackBarReplacing" lib` → tablo (ne zaman, kaç sn, gerekli mi). Kural §1.7: bilgi 3–4 sn,
      başarı bildirimi yalnız sonuç görünmüyorsa, aynı anda tek bildirim. Gereksizleri kaldır.
      *(2026-11-14, oto P05) Envanter (144 dosya, ~620 çağrı; `showSnack`/`showSnackOn`/`showSnackBarReplacing` + ekran içi `_snack` yardımcıları):*

      | Tür | Sayı | Süre | Karar |
      |---|---|---|---|
      | Tek kaynak `lib/core/snack.dart` | — | bilgi 3 sn (`kSnackInfo`), düğmeli 6 sn (`kSnackAction`) | **aynı anda tek bildirim zaten var** (yeni eskisinin yerine geçer, kuyruk yok); kalıcı iş kartı ayrı yuvada |
      | Hata / olmadı | ~150 | 3 sn (+ "Kopyala") | kalır — sonuç başka yerde görünmüyor |
      | Düğmeli (Geri al, Aç, Karşılaştır…) | 32 | 6 sn | kalır |
      | Açık süre verilen | 19 | 6–15 sn | düğmeliler ve uzun gerekçe metinleri (PDF ret, Drive giriş hatası 8 sn) kalır; **düğmesiz bilgi 6 sn → 3 sn:** USB çıkarıldı, arka planda alma açık/kapalı, davet gönderildi |
      | Başarı, sonuç ekranda görünüyor | 2 | — | **kaldırıldı:** boyutlandırma ön ayarı kaydedildi/silindi (çip hemen yanında belirir/kaybolur) |
      | Öğretici başarı ("Kaydedildi. Kalıcı yer için…", PDF düzenle "dokun, yaz", biçim boyacısı) | 6 | 3 sn | H7.3: bir kez |
      | Pano "kopyalandı" | ~12 | 3 sn | kalır — Android 13+ sistem de gösterir ama MIUI'de göstermeyebilir; SDK denetimi yerel kanal ister (**sabah bakılacak**, `KONTROL_LISTEM.md`) |
- [ ] H7.2 **Menü envanteri:** her ⋮ menüsü ve alt levha için madde sayısı. > 6 ise: sık kullanılan 5 + "Diğer". Sıra: kullanım sıklığı (👤 kullanıcıya liste gösterilip onay alınır).
- [x] H7.3 **İpuçları bir kez:** her ipucu/keşif balonu tek sefer gösterilir (`SharedPreferences` bayrağı), ayarlarda "İpuçlarını sıfırla".
      *(2026-11-14, oto P05: `lib/core/once_hints.dart` (`hint_once.<id>` bayrağı) — düzenleyicilerde "Kaydedildi. Kalıcı yer için ⋮ >
      Paylaş/Dışa aktar." ilk kayıtta bir kez, sonra yalnız "Kaydedildi"; PDF düzenle "dokun, yaz" ve Excel biçim boyacısı ipucu bir kez
      (taranmış sayfa açıklaması durum bilgisi olduğundan her seferinde). Ayarlar › Hakkında › "İpuçlarını yeniden göster" hepsini + tarama
      rehberi sayacını sıfırlar. Tarama rehberi 3 kez kuralı (2026-10-18 kullanıcı şikâyetinden) KORUNDU — **sabah bakılacak**. Yapay zekâ
      sekmelerinin tek satır açıklaması (`_TabIntro`, 2026-11-07 kullanıcı isteği) ve boş durum metinleri ipucu sayılmadı. Test `test/once_hints_test.dart`.)*
- [x] H7.4 **Onay pencereleri:** geri alınabilen işlemde onay sorma, "Geri al" bildirimi ver (çöp kutusuna taşıma vb.). Geri alınamayanlarda onay kalır.
      *(2026-11-14, oto P05: 55 `showAppConfirm` denetlendi. Ana kapı `deleteEntries` (gezgin, liste, seçim): çöpe atmada onay zaten ayara bağlıydı
      ("Silmeden önce sor") ve "Geri al" kartı vardı — ayarın varsayılanı **KAPALI** yapıldı; açıkça açanın kaydı korunur. Kalıcı silme onayı
      hiçbir koşulda atlanmaz (`needsDeleteConfirm`, bekçi test). Bilinçli kalanlar: toplu/algoritmanın seçtiği çöpe atmalar (benzer fotoğraf
      "fazlaları sil", boyutlandırma "eskilerin hepsini çöpe at") — kullanıcı tek tek seçmediği için; slayt/sayfa/etiket/kategori silme ve
      geri alınamayan işler (kalıcı silme, kasa, çöpü boşalt, karartma, sıkıştırma) onaylı.)*
- [ ] H7.5 **Ayarlar:** en çok kullanılan 6 ayar üstte; gerisi başlıklı gruplarda; arama var (`settings_search.dart`).

---

### Faz H8 — Video kırpma / kesme ☁️📱 · B (kullanıcı isteği 2026-11-14)

**Önce bak:** `ci/MediaTranscode.kt` (Media3 `Transformer`, `start`/`probe`/`cancel`), `lib/services/fm/video_transcode.dart`,
`lib/models/media_resize.dart`, `lib/widgets/fm/media_resize_sheet.dart`, `lib/screens/fm/media_player_screen.dart`,
iş sistemi (`lib/screens/fm/jobs_screen.dart`). Örnek arayüz: kullanıcının Google Fotoğraflar ekran görüntüsü (alt şeritte kare önizlemeli zaman çizelgesi, iki tutamaç, "Kaydet").

- [x] H8.1 **Yerel taraf:** `start` çağrısına `startMs`/`endMs` → `MediaItem.ClippingConfiguration`. Yeniden kodlamasız hızlı kesim için Media3 kırpma iyileştirmesi
      (`experimentalSetTrimOptimizationEnabled` — sürümde var mı doğrula; yoksa yeniden kodla). Kotlin değişikliği → CI Kotlin denetimi.
- [x] H8.2 **Kes ekranı:** üstte video önizleme (oynat/duraklat), altta kare şeridi (10–12 küçük kare, arka planda üretilir), iki tutamaç + süre etiketi
      ("00:12 – 01:05 · 53 sn"). Tutamaç sürüklenirken önizleme o kareye gider; `AppHaptics.step`.
- [x] H8.3 **Kaydet:** varsayılan **kopya** (`ad_kesit.mp4`, özgün korunur); iş sistemi üzerinden (ilerleme şeridi + bildirim), bitince "Aç / Paylaş".
- [x] H8.4 **Giriş noktaları:** video oynatıcı üst çubuğu "Kes" + dosya uzun basış menüsü "Videoyu kes". Lite/Pro yerleşimi `docs/SURUM_PLANI.md`'ye göre (👤).
- [ ] H8.5 (sesi kapat ✔ 2026-11-14; döndür + kareyi kaydet kaldı) Aynı ekranda sonra: döndür (90°), sesi kapat, kareyi fotoğraf olarak kaydet — ayrı commit'ler, her biri küçük.
- [x] H8.6 Test: süre/aralık doğrulama birim testi; yerel kanal sahte (mock) ile iş akışı testi. Cihaz: 3 farklı video (dikey, 4K, uzun) → `CIHAZ_TESTI.md`.

**Durum (2026-11-14):** H8.1–H8.4, H8.6 yapıldı. Giriş noktası tek: dosya işlemleri levhası ("Bu dosya" bölümü) —
oynatıcının ⋮'ı aynı levhayı açtığı için üst çubuğa ayrıca düğme konmadı (oynatıcıda zaten 7 simge var). Kotlin
`experimentalSetTrimOptimizationEnabled` (Media3 1.5.1) — ses kaldırılırken kapalı. Lite/Pro: `Feature.media` (boyut düşürmeyle aynı, Pro).
📱 cihaz turu `CIHAZ_TESTI.md` "Ferrari H8".

**Ek (2026-11-14, kullanıcı isteği — dondurma istisnası):** kes ekranı **"Videoyu düzenle"** oldu: aradan istendiği kadar
bölüm silme, bölge sesini kapatma, bölgeye ses ekleme (özgün sesi kıs / karıştır), tüm sesi kaldırma, Geri al. Model
`lib/models/video_edit.dart` (kaynak zamanı → çıktı zamanı), yerel `edit` (Media3 Composition: kırpılmış parçalar + `addGap`'li
ses sırası). Cihaz turu `CIHAZ_TESTI.md` "Video düzenle".

**Tuzaklar:** HAFIZA "Video küçültmede dikey→yatay bozulması" (döndürme meta verisi); kesimde aynı tuzak. Anahtar kare sınırı: hızlı kesimde başlangıç birkaç kare kayabilir — arayüzde yazma, yalnız kabul et.

---

### Faz H9 — Tablet ☁️📱 · O

**Önce bak:** `lib/screens/fm/dual_pane_screen.dart`, `browser_screen.dart`, `lib/core/display_mode.dart`, body.dart `_withPdfSidePanel`, HAFIZA "tablet".

- [ ] H9.1 ≥ 840 dp: solda kalıcı gezinme sütunu (Son dosyalar, kategoriler, depolamalar — Samsung görüntüsündeki gibi), sağda içerik. Sütun daraltılabilir.
- [ ] H9.2 Yatay/dikey dönüşte konum ve seçim korunur; düzen atlamaz.
- [ ] H9.3 Kalem: kalem dokunuşu çizer/seçer, parmak kaydırır (PDF işaretleme açıkken). Avuç içi reddi (doğrulanmadı: mevcut davranış).
- [ ] H9.4 Belge görüntüleyicide içerik genişliği sınırı: metin belgelerinde satır ≤ ~80 karakter, ortalanmış.
- [ ] H9.5 Sürükle-bırak: bölmeler arası dosya taşıma; başka uygulamaya bırakma (var mı doğrula).

---

### Faz H10 — Boş, yükleniyor, hata durumları ☁️ · K

**Önce bak:** `lib/widgets/empty_art.dart`, `app_error_screen.dart`, `live_progress.dart`, `lib/core/busy_dialog.dart`, `user_error.dart`.

- [ ] H10.1 Her liste ekranı için boş durum: çizim + tek cümle + (varsa) tek eylem. Envanter: `grep -rn "isEmpty" lib/screens | …` ile boş listede yalnız metin gösterenleri bul.
- [ ] H10.2 Yükleniyor: 300 ms'den uzun süren her açılışta iskelet (dönen çember yalnız belirsiz kısa işte). Ekranı kilitleyen `busy_dialog` kullanımını azalt → iş sistemi.
- [ ] H10.3 Hata: ham istisna metni yok; "ne oldu + ne yapabilirsin" tek cümle + "Yeniden dene". (Ham hata bekçisi zaten var.)

---

### Faz H11 — Görüntüleyici kabuğu tutarlılığı ☁️ · O

**Önce bak:** `lib/widgets/doc_action_bar.dart`, `editor_top_bar.dart`, `pdf_action_bars.dart`, `office_shell.dart`, `office_ribbon.dart`,
`lib/screens/fm/media_player_screen.dart`, `image_gallery_screen.dart`.

- [ ] H11.1 PDF / Word / Excel / Slayt / metin / görsel / video görüntüleyicilerinde üst çubuk aynı düzen: geri · ad (tek satır, soluk alt satır) · en çok 3 eylem · ⋮.
- [ ] H11.2 Alt eylem çubuğu: en çok 5 eylem, aynı simge boyu/etiket stili; okurken gizlenir.
- [ ] H11.3 Office belgeleri açılışı: H1.1 köprüsünün aynısı (kapak/iskelet), ilk sayfa önce.
- [ ] H11.4 Görsel görüntüleyici: siyah zemin, çubuklar tek dokunuşla gizlenir, aşağı çekince kapanır, yana kaydırma akıcı (§2 işlem 10).
- [ ] H11.5 Video oynatıcı: denetimler 3 sn sonra solar; çift dokunma ±10 sn; yatay sürükleme sarma; dikey sürükleme ses/parlaklık (var olanı doğrula, eksikleri ekle).

---

### Faz H12 — Son kapı 📱👤 · K

- [ ] H12.1 §2'deki 10 işlem yeniden, bizde ve Samsung'da; tablo `docs/perf/2026-11-H12.md`. Kapı: hiçbir işlemde Samsung'dan > %20 yavaş değiliz ya da gerekçesi yazılı.
- [ ] H12.2 Yan yana video kullanıcıya gösterilir; kullanıcı "geride" dediği her yeri işaretler → `KALANLAR.md`.
- [ ] H12.3 Erişilebilirlik: dokunma hedefi ≥ 48 dp, metin karşıtlığı (tema `_readable` denetimi), büyük yazı tipinde taşma yok, ekran okuyucu etiketleri.
- [ ] H12.4 Tasarım görüntüleri güncel (`docs/design/`), `design_tokens_baseline.json` tavanları düşürülmüş.
- [ ] H12.5 Özellik dondurma kalkar (§0.1).

---

## 4. Faz bağımlılıkları ve tahmini büyüklük

| Faz | Ortam | Boyut | Önce gereken |
|---|---|---|---|
| H0 Ölçüm tabanı | 📱💻 | K | — |
| H1 PDF açılış | ☁️ (+📱 H1.4) | O | — (H0 varsa ölçümlü) |
| H2 PDF kaydırma | 📱💻 | B | H0 |
| H3 PDF okuma konforu | ☁️📱 | B | H1 |
| H4 Dosya listesi | ☁️ | B | — |
| H5 Ana ekran | ☁️👤 | O | H4 |
| H6 Hareket ve dokunuş | ☁️ | O | H4 (H6.3 için H1) |
| H7 Sadeleştirme | ☁️👤 | O | — |
| H8 Video kes | ☁️📱 | B | — |
| H9 Tablet | ☁️📱 | O | H4, H5 |
| H10 Boş/yükleniyor/hata | ☁️ | K | — |
| H11 Görüntüleyici kabuğu | ☁️ | O | H1 |
| H12 Son kapı | 📱👤 | K | hepsi |

---

## 5. Açılış istemi (yeni oturuma aynen yapıştır)

```
docs/FERRARI_PLANI.md Faz H<N>'i yap. Önce §0 kurallarını ve §1 ilkelerini oku, sonra fazın "Önce bak" dosyalarını
(yalnız ilgili kısımlarını) oku ve plandaki varsayımları doğrula; yanlış olan varsa planı düzelt. Her maddeyi ayrı
commit'le, faz-H<N> dalında yap; bitince PR aç ([apk]), CI yeşilse main'e birleştir. HAFIZA.md, CIHAZ_TESTI.md ve
plandaki kutucukları güncelle. 📱 işaretli maddeleri yapamıyorsan atla ve KALANLAR.md'ye "cihaz bekliyor" diye yaz.
Sonunda bana yalnız: ne değişti (3–5 madde) + telefonda bakmam gereken şeyler.
```

---

## 6. Bu planın dayandığı gözlemler (2026-11-14)

- Video (tablet, USB'de 200–700 MB kitaplar): bizde sayfalar ve yan şerit uzun süre boş; "25. sayfadan devam" + "doldurulabilir form"
  aynı anda; form uyarısı ders kitaplarında da çıkıyor (yanlış alarm). Samsung'da da hızlı kaydırmada boş sayfa var ama kısa.
- Kod: form taraması dosyanın tamamını okuyordu (PR #90'da baş+son 4 MB'a indirildi); yan şerit küçük resimleri ana sayfalarla aynı
  çizim sırasında (PR #90'da 900 ms gecikme); `pdfImageCacheBytes` high = 64 MB.
- Altyapı **var**: `Motion`, `AppHaptics`, `Gap/Radii`, tasarım bekçisi, iskeletler, hızlı kaydırıcı, iki bölme. Eksik olan özellik değil;
  bunların her ekranda aynı özenle uygulanması ve PDF çizim hattının ölçülerek ayarlanması.
- Hiçbir performans iddiası cihazda ölçülmedi → H0 bu yüzden ilk faz.
