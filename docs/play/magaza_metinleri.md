# Play Store mağaza metinleri (Faz 11a, 2026-10-22; dürüst Lite + ayrı Pro ilanı)

Başlık ≤ 30, kısa açıklama ≤ 80, uzun ≤ 4000 karakter (bekçi: `test/store_assets_test.dart`).
**Tek kaynak bu dosya:** `python3 tool/magaza_varliklari.py` → `fastlane/metadata/android/` (metin + 512 simge +
1024×500 tanıtım görseli; Faz 42 / 4). Metni burada değiştir, betiği yeniden koştur. Ekran görüntüleri:
`flutter test tool/design_shots_test.dart` → `docs/design/` (son görünüm).

## Türkçe

**Başlık:** Dosya Okuyucu: PDF ve Office

**Kısa açıklama:** Reklamsız PDF, Office okuyucu ve dosya yöneticisi. Dosyalar cihazınızda kalır.

**Uzun açıklama:**

Dosya Okuyucu, telefonunuzdaki belgeler ve dosyalar için hızlı, sade ve tamamen
reklamsız bir yardımcıdır. Temel okuma, dosya yönetimi ve aktarım araçları
ücretsizdir; verileriniz cihazdan çıkmaz.

Lite sürümde neler ücretsiz?

• PDF okuma ve işaretleme: vurgula, yer imi ekle, form doldur, elle imzala,
  parolalı PDF aç, seçili metni kopyala veya çevrimdışı çevir
• Belge tarama ve çevrimdışı OCR: kamerayla sayfa tara, cihaz içi metin tanı
• Word, Excel, PowerPoint: biçimi koruyarak aç ve temel düzenleme yap — mobilde
  rahat okuma/yazım görünümü, taslak kurtarma ve otomatik kaydetme
• Dosya yöneticisi: tür süzgeci, klasör sıralama, çöp kutusu ve geri al, arşiv
  açma/oluşturma (ZIP), USB bellek (salt okunur) ve SD kart, SMB/SFTP/WebDAV,
  şifreli kasa
• Yakındakiler: yakındaki telefona ya da aynı ağdaki tarayıcıya kablosuz dosya
  gönder — sunucuya yüklenmez, ortak Wi-Fi gerekmez
• Medya ve görsel araçları: dahili galeri, video/ses oynatıcı, görsel
  boyutlandırma, kırpma, döndürme, WebP dönüşümü ve QR kodla not paylaşımı
• Göz yormayan kırık beyaz ve koyu tema; Türkçe, İngilizce, Arapça arayüz
• Gizlilik: reklam yok, izleme analitiği yok, hesap zorunluluğu yok

Pro sürümde neler ayrı?

Uygulamada `PRO` rozetiyle açıkça işaretlenen gelişmiş araçlar ayrı Pro
uygulamasındadır: PDF paragraf/sayfa düzenleme, Akıllı Klasörler (çevrimdışı
kural motoru + isteğe bağlı kendi Gemini anahtarınız), belgelerden Sesli Kitap
oluşturma ve video boyut düşürme.

İzinler: Açılışta izin istenmez. Başka uygulamadan gelen bir belgeyi açmak için
ek izin gerekmez. Tüm dosyalara erişim yalnız klasör gezginini ve temizliği
kullanmak istediğinizde, kendi onayınızla istenir.

Microsoft Word, Excel ve PowerPoint, Microsoft Corporation'ın ticari
markalarıdır; bu uygulama Microsoft ile bağlantılı değildir.

## English

**Title:** Dosya Okuyucu: PDF & Office

**Short description:** Ad-free PDF, Office reader & file manager. Files stay offline on your device.

**Full description:**

Dosya Okuyucu is a fast, clean and 100% ad-free companion for your documents
and local storage. Core reading, file management and transfer tools are free
with no account required and no tracking.

Included free in Lite:

• PDF reading & markup: highlights, bookmarks, interactive form filling,
  handwritten signature, password-protected PDFs and offline translation
• Document scanner & on-device OCR: scan pages with your camera offline
• Word, Excel & PowerPoint: open and make basic edits without breaking layout,
  with mobile reading/writing view and draft recovery
• File manager: type filters, per-folder sorting, recycle bin with undo, archive
  browser, USB OTG (read-only) & SD card, SMB/SFTP/WebDAV and encrypted vault
• Nearby transfer: send files wirelessly to a nearby phone or local browser
  without uploading anything to a server
• Media & utilities: built-in gallery and player, precise image resizing/crop,
  QR-code text sharing and gentle paper/dark themes in EN, TR and AR

Separated in the paid Pro app (clearly badged `PRO` inside Lite):

In-place PDF paragraph and page editing, Smart Folders (offline rules + optional
Gemini with your own API key), on-device Audiobook studio and video compression.

Permissions: Nothing is requested at launch. Opening incoming documents needs no
storage permission; "All files access" is asked only if you choose to browse
device folders in the file manager.

Microsoft Word, Excel and PowerPoint are trademarks of Microsoft Corporation;
this app is not affiliated with Microsoft.

## العربية

**العنوان:** Dosya Okuyucu: PDF وOffice

**وصف قصير:** قارئ PDF وOffice ومدير ملفات بلا إعلانات. ملفاتك تبقى على هاتفك.

**الوصف الكامل:**

‏Dosya Okuyucu تطبيق سريع وبلا إعلانات لقراءة مستنداتك وإدارة ملفاتك على
الهاتف. الأدوات الأساسية مجانية بالكامل دون حساب ودون تتبّع.

الميزات المجانية في Lite:

• قراءة PDF والتعليق: تمييز النص، الإشارات المرجعية، تعبئة النماذج، التوقيع
  اليدوي، فتح الملفات المحمية بكلمة مرور والترجمة دون إنترنت
• ماسح المستندات والتعرّف على النصوص (OCR) على الجهاز دون رفع إلى السحابة
• Word وExcel وPowerPoint: فتح وتحرير أساسي مع الحفاظ على التنسيق واستعادة
  المسودات
• مدير ملفات متكامل: سلة محذوفات مع تراجع، أرشيف ZIP، دعم USB (للقراءة فقط)
  وبطاقة SD، وSMB/SFTP/WebDAV وخزنة مشفّرة
• الأجهزة القريبة: إرسال الملفات لاسلكيًا إلى هاتف قريب أو متصفح محلي دون
  وسيط أو خادم
• أدوات الصور والوسائط: معرض ومشغّل، تغيير حجم الصور بدقة ومشاركة النص برمز QR

الميزات الاحترافية في تطبيق Pro المنفصل (الموسومة بوضوح بشعار PRO):

تحرير فقرات وصفحات PDF مباشرة، المجلدات الذكية (قواعد محلية + مفتاح Gemini
اختياري)، إنشاء الكتب الصوتية على الجهاز وضغط الفيديو.

الأذونات: لا يُطلب أي إذن عند التشغيل، ولا يحتاج فتح الملفات الواردة إلى إذن
تخزين. يُطلب الوصول إلى كل الملفات فقط عند رغبتك في تصفّح المجلدات.

‏Microsoft Word وExcel وPowerPoint علامات تجارية لشركة Microsoft Corporation؛
وهذا التطبيق غير تابع لها.

## Pro — Türkçe

**Başlık:** Dosya Okuyucu Pro: PDF ve AI

**Kısa açıklama:** Tek seferlik Pro. Abonelik yok (yalnız ekstra Akıllı Klasör için).

**Uzun açıklama:**

Dosya Okuyucu Pro; Lite sürümdeki tüm ücretsiz okuyucu ve dosya yöneticisi
araçlarına ek olarak gelişmiş üretkenlik paketini tek seferlik lisansla sunar.
Reklam yok, temel özelliklerde abonelik yok, veri toplama yok.

• Gelişmiş PDF stüdyosu: paragrafları yerinde düzenle, sayfa ekle/çıkar/döndür,
  birleştir, böl, filigran ekle ve gelişmiş tarama araçları
• Akıllı Klasörler: fatura, banka dekontu, resmi evrak, sağlık ve ekran
  görüntülerini baştan tür/klasör seçerek cihaz içinde internet gerekmeden
  otomatik kategorilere ayır (500 dosyaya kadar başlangıç hakkı dahil;
  daha fazla bulut analizi isteğe bağlı abonelik veya kendi Gemini anahtarınla)
• Sesli Kitap Stüdyosu: PDF, Word veya metinlerini doğal Türkçe AI sesleriyle
  bölümlü sesli kitaba çevir ve çevrimdışı dinle
• Video boyut düşürme: yer açma ve paylaşım için tahmini boyut görerek sıkıştır
• Gelişmiş Word ve Slayt araçları: tablo, resim, biçimlendirme ve sunum araçları

## Pro — English

**Title:** Dosya Okuyucu Pro: PDF & AI

**Short description:** PDF editor, smart folders, audiobooks & video shrink. One-time purchase.

**Full description:**

Dosya Okuyucu Pro includes everything in Lite plus the complete power-user suite
with a one-time purchase — no ads, no core subscriptions, no tracking.

• Full PDF Editor: edit paragraphs in place, merge/split, reorder/rotate pages
  and add watermarks
• Smart Folders: choose which file types and folders to scan, organize
  invoices, bank receipts, official records and screenshots offline (500-file
  starter allowance included; extra cloud quota is optional via subscription
  or your own Gemini key)
• Audiobook Studio: convert documents into chaptered offline audiobooks
• Video Shrink: preview estimated output size and compress large videos locally
• Pro Word & Slides tools for richer document workflows

## Pro — العربية

**العنوان:** Dosya Okuyucu Pro: PDF وAI

**وصف قصير:** محرر PDF، مجلدات ذكية، كتب صوتية وضغط فيديو. شراء لمرة واحدة.

**الوصف الكامل:**

يضم Dosya Okuyucu Pro كل ميزات Lite مع الحزمة الاحترافية الكاملة بشراء لمرة
واحدة دون إعلانات أو اشتراكات:

• محرر PDF متكامل: تعديل الفقرات في مكانها، الدمج والتقسيم وإدارة الصفحات
• المجلدات الذكية: اختر الأنواع والمجلدات قبل الفحص وصنّف الفواتير والإيصالات
  والمستندات الرسمية محليًا دون إنترنت (تشمل 500 ملف مجانًا؛ الزيادة اختيارية)
• استوديو الكتب الصوتية لتحويل المستندات إلى ملفات صوتية مقسّمة إلى فصول
• ضغط الفيديو محليًا مع تقدير الحجم قبل البدء
• أدوات متقدمة لمستندات Word والعروض التقديمية
