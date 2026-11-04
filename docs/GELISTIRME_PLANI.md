# GELİŞTİRME PLANI — Faz 34–42 (2026-11-04)

Kaynak: kullanıcı isteği *"görünüm ve işlev olarak geliştir; Excel, Word, Slayt, PDF; belge
taramada profesyonel yöntem; eksiksiz düşün"* + 2026-11-04 kod taraması (`lib/services`,
`lib/screens/editors`, `pdf_*`, `scan_*`). Yürütme sırası **KALANLAR.md → "Faz C"**.
Doğrulama = CI (CLAUDE.md §4); cihazda bakılacaklar `docs/CIHAZ_TESTI.md`'ye.

## Mevcut durum (tarama özeti)
- **Excel:** xlsx okuma/yazma/yama, formül motoru, grafik, veri doğrulama, otomatik süzgeç,
  dondurma, adlandırılmış aralık, bul/değiştir. **Eksik:** özet tablo (pivot), mini grafik
  (sparkline), koşullu biçim *yazma* (A7.5), tablo nesnesi (structured ref), formül
  otomatik tamamlama/yardım balonu zayıf, yazdırma düzeni, parola.
- **Word:** docx düzenleme, değişiklik izleme, yorum, dipnot, içindekiler, üst/alt bilgi,
  sayfa no. **Eksik:** denklem (OMML yalnız okunur), stil galerisi/stil düzenleme, şablonlar,
  mail-merge, sayfa düzeni (kenar boşluğu/sütun) ekranı, karşılaştırma, PDF dışa aktarım
  kalitesi (sayfa kırılımı), belge parolası.
- **Slayt:** pptx okuma/düzenleme, geçiş, animasyon, konuşmacı notu, sunum kipi. **Eksik:**
  ana slayt/yerleşim (master) düzenleme (yalnız okunur), SmartArt (görüntü olarak), slayt
  içi grafik düzenleme, ses/video ekleme, şablon galerisi, sunucu görünümü (zamanlayıcı+not).
- **PDF:** görüntüle/işaretle/kalem/form/imza (görsel)/sayfa işlemleri/birleştir-böl/OCR/çeviri.
  **Eksik:** kalıcı karartma (redaction) doğrulaması, **dijital imza (PKCS#7)**, PDF/A,
  sayfa karşılaştırma, tablo çıkarma (→ Excel), parola/izin düzenleme, sıkıştırma agresif
  kip (A7.4), yer imi düzenleme, damga/filigran şablonları.
- **Tarama:** `cunning_document_scanner` (ML Kit belge tarayıcı sarmalayıcı) → JPEG →
  `scan_enhance/dewarp/prepare/page_ops` → OCR'lı PDF. **Eksik:** canlı kenar kılavuzu ve
  otomatik çekim bizde değil (paket penceresi), yalnız JPEG döner (PDF/OCR bizde),
  belge türü kipleri yok, kimlik/kitap/kartvizit akışı yok, toplu inceleme ızgarası zayıf.

---

## Faz 34 — Pano cilası (bu oturumda başladı)
- [x] Simgeler sadeleşti: parlama kalktı, gölge/gradyan yumuşak (`fm_tile_art.dart`).
- [x] Alt gezinme çubuğu kalktı; alt panel simetrik (Çöp · Drive · **Aktar** · Tara · Yer aç),
      güvenli alan (SafeArea) eklendi; ek düğme varsayılanı "Yer aç" (`home_quick_row.dart`).
- [x] Araçlar çizgisi yukarı çekildi; kutu ızgarası 0,86→0,94 oran; araç çerçevesi ince.
- [ ] Cihazda doğrula: 360×800 dp ve 2× yazı ölçeğinde tüm araç satırı alt panel üstünde.
- [ ] Başka sekmelere erişim (Yeni Dosyalar, Geçmiş, İndirilenler) panodaki kutulardan —
      eski sekme ayarı (`NavTabs`) ve "Ana ekranı düzenle" sayfasını sadeleştir/kaldır.
**Bitti ölçütü:** ekran görüntüsünde 4 sıra kutu + araç satırı + alt panel kayma yok.

## Faz 35 — Pro belge tarayıcı (en büyük kullanıcı değeri)
Karar önerisi (👤 onay): **ML Kit `GmsDocumentScanner`'ı doğrudan kullan** (Kotlin köprüsü,
`ci/` yaması) — `cunning_document_scanner`'ı bırak. Gerekçe: sonuç olarak **PDF + JPEG**
birlikte döner, **canlı kenar + otomatik çekim + parmak/gölge/leke silme + otomatik
döndürme** Google'da hazır; sayfa sınırı, galeri içe aktarma, kip (BASE / BASE_WITH_FILTER /
FULL) seçilebilir. Bizim katman: OCR, sıkıştırma, adlandırma, saklama.
1. **Belge türü kipleri** (tara ekranında hap seçici): Belge · Kimlik/Ehliyet (ön+arka tek A4)
   · Kitap (çift sayfa → 2 sayfaya böl) · Makbuz/Fiş (uzun, ince) · Beyaz tahta · Kartvizit
   (OCR → kişi) · Fotoğraf. Her kip filtre/kırpma varsayılanını belirler.
2. **Toplu inceleme ızgarası:** sürükle-sırala, tek sayfa döndür/yeniden kırp/filtre
   (Orijinal · Otomatik · Gri · S/B · Renkli-canlı · Gölge-sil), sayfa sil, "sayfa ekle".
3. **Akıllı çıktı:** aranabilir PDF (mevcut OCR katmanı), Word'e (düzenlenebilir), Excel'e
   (tablo algılama → hücreler), TXT; PDF boyutu önizlemesi + kalite (Küçük/Orta/Yüksek).
4. **Otomatik ad + klasör:** `scan_title` (var) ile tarih + ilk başlık; "Taramalar"
   klasörü; bulut/kasa seçeneği (kimlik taramaları kasaya önerilir).
5. **İyileştirme:** `scan_enhance`/`scan_dewarp` kalite metrikleri (keskinlik, eğiklik) ile
   "yeniden çek" önerisi; düşük ışıkta fener önerisi.
6. Test: sayfa işlem birim testleri (sıralama, böl, birleştir), PDF üretimi bayt testleri;
   cihaz: 10 gerçek belge (kağıt, fiş, kimlik, kitap, tahta) — `CIHAZ_TESTI.md`.
**Bitti ölçütü:** tek dokunuşla Belge→PDF; kimlik iki yüz tek sayfa; kitap iki sayfa böler;
OCR'lı PDF aranabilir; 20 sayfa < 15 sn işlenir (orta cihaz).

## Faz 36 — Excel
1. Özet tablo (pivot) oluştur/yenile (satır/sütun/değer/süzgeç, topla-say-ort) — xlsx
   `pivotCache` yazımı veya salt "değer anlık görüntüsü" ilk sürüm.
2. Koşullu biçim yazma: renk ölçeği, veri çubuğu, simge kümesi, formül kuralı (A7.5).
3. Mini grafik (sparkline) çiz + yaz (`x14:sparklineGroups`).
4. Formül: yardım balonu + otomatik tamamlama + hata açıklaması ("#DEĞER! neden"),
   dinamik diziler (FILTER/SORT/UNIQUE), XLOOKUP, LET, SEQUENCE.
5. Tablo nesnesi (ListObject) + biçimli tablo stilleri, yapısal başvuru.
6. Yazdırma düzeni + PDF'e aktar (sayfa sığdır, başlık satırı yinele), parola ile aç/koru.
7. Görünüm: şerit sadeleştirme, hücre düzenleme çubuğu, parmakla seçim tutamakları,
   kaydırmada sabit başlık gölgesi, yoğunluk (kompakt/rahat) ayarı.
**Ölçüt:** 5 örnek gerçek dosyada yaz→aç döngüsü kayıpsız (B4 uyumluluk turu).

## Faz 37 — Word
1. Stil galerisi (Başlık 1–3, Alıntı, Liste) + "stili güncelle"; belge teması/yazı tipleri.
2. Sayfa düzeni ekranı (kenar boşluğu, yön, boyut, sütun, sayfa kesmesi), yazdır önizleme.
3. Denklem düzenleyici (OMML yaz/oku, temel LaTeX girişi), tablo: hücre birleştir/böl,
   kenarlık/gölge, otomatik sığdır, sıralama.
4. Şablonlar (CV, mektup, rapor, fatura, tutanak) — "Yeni belge" sayfasına galeri.
5. Karşılaştır/birleştir iki belge; yorum+değişiklik gezinme çubuğu; belge parolası.
6. Sesle yazma (cihaz STT) ve AI ile yeniden yaz/özetle/çevir (Gemini var) — satır içi.
7. PDF/Docx dışa aktarım kalitesi: sayfa kırılımı, yazı tipi gömme.
**Ölçüt:** 5 gerçek docx düzen kaybı olmadan açılıp kaydedilir.

## Faz 38 — Slayt
1. Ana slayt/yerleşim (master/layout) düzenleme: yer tutucu, tema renk/yazı tipi.
2. Şablon galerisi (8 sade tema) + "metinden slayt" (`text_to_slides`, var) için tasarım önerisi.
3. Slayt içi grafik ekle/düzenle (tablo verisinden), SmartArt → düzenlenebilir şekil grubu.
4. Ses/video ekleme + oynatma, sunum kipinde lazer işaretçi, kalem, zamanlayıcı.
5. Sunucu görünümü (not + sonraki slayt + süre), PDF/PNG/video dışa aktarım.
6. Yardımcı çizgi/hizalama/dağıt, katman paneli, animasyon sırası paneli.
**Ölçüt:** 5 gerçek pptx görsel fark < eşik (B4); sunum kipi 60 fps.

## Faz 39 — PDF
1. **Dijital imza (PKCS#7)** — kullanıcı sertifikası/self-signed, görünür imza alanı.
2. Kalıcı karartma (redaction) — metin+görüntüyü gerçekten siler, doğrulama testi.
3. Tablo çıkarma → Excel; sayfa metnini Word'e (düzen korunarak); PDF/A dışa aktarım.
4. İki PDF karşılaştırma (görsel fark + metin farkı).
5. Parola/izin düzenleme, yer imi düzenleme, damga/filigran şablonları, numaralandırma.
6. Okuma: gece kipi (A9.2), kaydırma kilidi, çift sayfa/kitap görünümü, sesli okuma
   (var), metin işaretleme kitapçığı (tüm vurgular tek listede dışa aktar).
7. Agresif sıkıştırma (A7.4).
**Ölçüt:** imzalı PDF Adobe/Chrome'da geçerli görünür (cihaz dışı doğrulama 💻).

## Faz 40 — Ortak görünüm ve deneyim
1. **Tasarım dili:** tüm editör üst çubukları tek yapı (başlık · kaydet · geri/ileri · ⋮),
   alt araç şeridi kaydırılabilir + bağlama duyarlı (seçime göre).
2. Animasyon/hareket: sayfa geçişleri `Motion` tokenlarıyla; boş durum çizimleri.
3. Erişilebilirlik: 2× yazı, TalkBack etiketleri, kontrast denetimi (token bekçisi).
4. Onboarding: ilk açılış 3 ekran (okuyucu · düzenleyici · tara) + örnek belgeler.
5. Ayarlar sadeleşmesi: arama kutusu, gruplar, "önerilenler".
**Ölçüt:** token bekçisi yeşil; 2× yazıda taşma yok (widget testleri).

## Faz 41 — Dosya yöneticisi ve bulut
1. Çift bölme (A7.1), SD kart SAF yazma (A7.2), toplu yeniden adlandırma şablonları.
2. Drive: çevrimdışı kopya, çakışma çözümü, OneDrive/Dropbox (hesap kararı 👤).
3. Arama: içerik içi arama (OCR dahil) dizini, kayıtlı aramalar, akıllı klasörler.
4. Paylaşım: kısa ömürlü bağlantı (yerel ağ), QR ile aktar (var) → toplu.
**Ölçüt:** 50 bin dosyada arama < 1 sn (dizinli).

## Faz 42 — Kalite, performans, yayın
1. Başlangıç süresi/APK boyutu bütçeleri (CI var) — yeni bağımlılık eklenince bütçe kontrolü.
2. Büyük dosya: 100 MB xlsx/pdf akış okuma, bellek tavanı testleri.
3. Çökme günlüğü → "bildir" akışı; A8 ölçüm altyapısı.
4. Sürüm adayı turu (B6) ve mağaza varlıkları.

## Sıra önerisi
**34 → 35 (tarayıcı) → 39 (PDF imza/karartma) → 36 (Excel) → 37 (Word) → 38 (Slayt) → 40 → 41 → 42.**
Gerekçe: tarama ve PDF en sık kullanılan, kullanıcıya en görünür; Excel/Word/Slayt gerçek
dosya uyumluluğu (B4) cihaz/Windows turuna bağlı. Her faz ayrı commit dizisi, CI yeşil,
HAFIZA kaydı, `KALANLAR.md`'den madde silme.
