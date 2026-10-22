part of '../app_strings.dart';

/// Çeviri tablosunun 2. bölümü (çoğunlukla `vw`, `fm` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t2 = {
  'ea.sec_move': ('Taşı ve kopyala', 'Move & copy', 'نقل ونسخ'),
  'ea.sec_file': ('Dosya işlemleri', 'File actions', 'إجراءات الملف'),
  'vw.fullscreen': ('Tam ekran', 'Full screen', 'ملء الشاشة'),
  'vw.fullscreen_hint': ('Durum ve gezinme çubukları gizlenir', 'Hides the status and navigation bars', 'يخفي شريطي الحالة والتنقل'),
  'ea.sec_this': ('Bu dosya', 'This file', 'هذا الملف'),
  'ea.sec_ai': ('AI ve dönüştür', 'AI & convert', 'الذكاء الاصطناعي والتحويل'),
  'ea.pick_folder': ('klasör seç', 'pick folder', 'اختر مجلدًا'),
  'ea.compress': ('Sıkıştır', 'Compress', 'ضغط'),
  'ea.compress_hint': (
    'ZIP · 7z · parolalı',
    'ZIP · 7z · password',
    'ZIP · 7z · بكلمة مرور',
  ),
  'ea.resize': ('Boyut düşür', 'Reduce size', 'تصغير الحجم'),
  'ea.resize_hint': (
    'çözünürlük / kare sayısı',
    'resolution / frame rate',
    'الدقة / معدل الإطارات',
  ),
  'ea.tag': ('Etiketle', 'Tag', 'وسم'),
  'ea.tag_hint': ('kişi / grup', 'person / group', 'شخص / مجموعة'),
  'ea.image_insight': (
    'Görselde ne var?',
    'What is in this image?',
    'ما الموجود في الصورة؟',
  ),
  'ea.image_insight_hint': ('metin tanı', 'recognize text', 'تعرّف على النص'),
  'ea.clip_hint': ('yapıştırmak için', 'to paste later', 'للصق لاحقًا'),
  'ea.shared_hint': (
    'ağdan paylaşılır',
    'shared over the network',
    'يُشارَك عبر الشبكة',
  ),
  // Sil düğmesinin metni DÜRÜST olmak zorunda: çöp kutusu kapalıyken
  // "çöp kutusuna" yazmak tutulmayan bir sözdür (bkz. deleteActionText).
  'ea.delete_trash': ('Sil — çöp kutusuna', 'Delete — to trash', 'حذف — إلى المهملات'),
  'ea.delete_permanent': ('KALICI SİL', 'DELETE PERMANENTLY', 'حذف نهائي'),
  'fm.open_with_other': ('Başka uygulamayla aç', 'Open with another app', 'فتح بتطبيق آخر'),
  'fm.move_to': ('Taşı…  (klasör seç)', 'Move…  (pick folder)', 'نقل…  (اختر مجلدًا)'),
  'fm.copy_to': ('Kopyala…  (klasör seç)', 'Copy…  (pick folder)', 'نسخ…  (اختر مجلدًا)'),
  'fm.move_here': ('Buraya taşı', 'Move here', 'انقل هنا'),
  'fm.copy_here': ('Buraya kopyala', 'Copy here', 'انسخ هنا'),
  'fm.extract_here': ('Buraya çıkar', 'Extract here', 'استخرج هنا'),
  'fm.show_archive': ('Arşiv içeriğini göster', 'Show archive contents', 'عرض محتويات الأرشيف'),
  'fm.compress_pw': (
    'Sıkıştır (ZIP / 7z, parolalı)',
    'Compress (ZIP / 7z, password)',
    'ضغط (ZIP / 7z، بكلمة مرور)',
  ),
  'fm.reveal': ('Konumunu aç', 'Show location', 'إظهار الموقع'),
  'fm.ai_summary': ('AI ile özetle', 'Summarize with AI', 'تلخيص بالذكاء الاصطناعي'),
  'fm.image_insight': (
    'Bu görselde ne var? (metin tanı)',
    'What is in this image? (recognize text)',
    'ما الموجود في هذه الصورة؟ (تعرّف على النص)',
  ),
  'fm.type': ('Tür', 'Type', 'النوع'),
  'fm.folder': ('Klasör', 'Folder', 'مجلد'),
  'fm.modified': ('Değiştirilme', 'Modified', 'تاريخ التعديل'),
  'fm.last_opened': ('Son açılma', 'Last opened', 'آخر فتح'),
  'fm.not_computed': ('Hesaplanmadı', 'Not computed', 'غير محسوب'),
  'fm.computing': ('Hesaplanıyor…', 'Computing…', 'جارٍ الحساب…'),
  'fm.items_count': ('{n} öğe', '{n} items', '{n} عنصر'),
  'fm.delete_permanent_title': (
    'Kalıcı olarak silinsin mi?',
    'Delete permanently?',
    'حذف نهائيًا؟',
  ),
  'fm.delete_trash_title': (
    'Çöp kutusuna taşınsın mı?',
    'Move to trash?',
    'نقل إلى المهملات؟',
  ),
  'fm.delete_permanent_body': (
    '{label} KALICI olarak silinecek. Bu işlem geri alınamaz. '
        '(Çöp kutusu ayarlardan kapalı.)',
    '{label} will be deleted PERMANENTLY. This cannot be undone. '
        '(Trash is disabled in settings.)',
    'سيتم حذف {label} نهائيًا. لا يمكن التراجع عن هذا. '
        '(سلة المهملات معطّلة من الإعدادات.)',
  ),
  'fm.delete_trash_body': (
    '{label} çöp kutusuna taşınacak. Geri Dönüşüm Kutusu’ndan geri '
        'yükleyebilirsiniz.',
    '{label} will be moved to the trash. You can restore it from the Recycle '
        'Bin.',
    'سيتم نقل {label} إلى المهملات. يمكنك استعادته من سلة المحذوفات.',
  ),
  'fm.delete_permanent_action': ('{what} kalıcı sil', 'Delete {what} permanently', 'حذف {what} نهائيًا'),
  'fm.delete_trash_action': ('{what} çöpe taşı', 'Move {what} to trash', 'نقل {what} إلى المهملات'),
  'fm.renamed': ('Yeni ad: {name}', 'Renamed to {name}', 'الاسم الجديد: {name}'),
  'fm.trashed_n': ('{n} öğe çöp kutusuna taşındı', '{n} item(s) moved to trash', 'نُقل {n} عنصر إلى سلة المهملات'),
  'fm.undo': ('Geri alındı.', 'Undone.', 'تم التراجع.'),
  'fm.undo_action': ('Geri al', 'Undo', 'تراجع'),
  'fm.deleting': ('Siliniyor', 'Deleting', 'جارٍ الحذف'),
  'fm.undo_failed': ('Geri alınamadı: {error}', 'Could not undo: {error}', 'تعذّر التراجع: {error}'),
  'fm.deleted_partial': (
    '{ok} öğe silindi, {fail} öğe silinemedi.',
    '{ok} items deleted, {fail} could not be deleted.',
    'تم حذف {ok} عنصر، وتعذّر حذف {fail}.',
  ),
  'fm.trashed_partial': (
    '{ok} öğe çöp kutusuna taşındı, {fail} öğe taşınamadı: {error}',
    '{ok} items moved to trash, {fail} could not be moved: {error}',
    'تم نقل {ok} عنصر إلى المهملات، وتعذّر نقل {fail}: {error}',
  ),
  'fm.transfer_done': (
    '{n} öğe “{where}” klasörüne {verb}.',
    '{n} items were {verb} to “{where}”.',
    'تم {verb} {n} عنصر إلى «{where}».',
  ),
  'fm.transfer_stopped': (
    'Durduruldu · {n} öğe “{where}” klasörüne çoktan {verb} '
        '(süren aktarma yarıda kesilemiyor).',
    'Stopped · {n} items were already {verb} to “{where}” '
        '(a transfer in progress cannot be cut off).',
    'تم الإيقاف · {n} عنصر تم {verb}ه بالفعل إلى «{where}» '
        '(لا يمكن قطع نقل جارٍ).',
  ),
  'fm.transfer_errors': (
    '{n} öğe {verb}, {fail} öğe aktarılamadı: {error}',
    '{n} items {verb}, {fail} could not be transferred: {error}',
    'تم {verb} {n} عنصر، وتعذّر نقل {fail}: {error}',
  ),
  'fm.verb_moved': ('taşındı', 'moved', 'النقل'),
  'fm.verb_copied': ('kopyalandı', 'copied', 'النسخ'),
  'fm.important_copied': (
    '{n} öğe “{folder}” klasörüne kopyalandı.',
    '{n} items copied to “{folder}”.',
    'تم نسخ {n} عنصر إلى «{folder}».',
  ),
  'fm.copy_failed': ('Kopyalanamadı: {error}', 'Could not copy: {error}', 'تعذّر النسخ: {error}'),
  'fm.move_failed': (
    '{n} öğe taşınamadı: {error}',
    '{n} items could not be moved: {error}',
    'تعذّر نقل {n} عنصر: {error}',
  ),
  'fm.rename_failed': (
    'Yeniden adlandırılamadı: {error}',
    'Could not rename: {error}',
    'تعذّرت إعادة التسمية: {error}',
  ),
  'fm.zip_failed': ('Sıkıştırılamadı: {error}', 'Could not compress: {error}', 'تعذّر الضغط: {error}'),
  'fm.extract_failed': ('Çıkarılamadı: {error}', 'Could not extract: {error}', 'تعذّر الاستخراج: {error}'),
  'fm.zipping': ('Sıkıştırılıyor', 'Compressing', 'جارٍ الضغط'),
  'fm.encrypting': ('Şifreleniyor (AES-256)', 'Encrypting (AES-256)', 'جارٍ التشفير (AES-256)'),
  'fm.extracting': ('Çıkarılıyor', 'Extracting', 'جارٍ الاستخراج'),
  'fm.trashing': ('Çöp kutusuna taşınıyor', 'Moving to trash', 'جارٍ النقل إلى المهملات'),
  'fm.copying_important': (
    'Önemli dosyalara kopyalanıyor',
    'Copying to important files',
    'جارٍ النسخ إلى الملفات المهمة',
  ),
  'fm.copying_shared': (
    'Paylaşılan klasörüne kopyalanıyor',
    'Copying to the Shared folder',
    'جارٍ النسخ إلى مجلد المشترك',
  ),
  'fm.extracted_to': (
    '“{name}” klasörüne çıkarıldı.',
    'Extracted to “{name}”.',
    'تم الاستخراج إلى «{name}».',
  ),
  'fm.created_archive': ('“{name}” oluşturuldu.', '“{name}” created.', 'تم إنشاء «{name}».'),
  'fm.entry_clip_copied': (
    '“{name}” panoya kopyalandı. Hedef klasörde “Yapıştır”a dokunun.',
    '“{name}” copied to clipboard. Tap “Paste” in the destination folder.',
    'تم نسخ «{name}» إلى الحافظة. اضغط «لصق» في المجلد الوجهة.',
  ),
  'fm.entry_clip_cut': (
    '“{name}” panoya kesildi. Hedef klasörde “Yapıştır”a dokunun.',
    '“{name}” cut to clipboard. Tap “Paste” in the destination folder.',
    'تم قص «{name}» إلى الحافظة. اضغط «لصق» في المجلد الوجهة.',
  ),

  // ── Görüntüleyici (PDF / metin / görsel / tablo) ──────────────────────────
  'vw.tools': ('Araçlar', 'Tools', 'الأدوات'),
  'vw.rotate': ('Döndür', 'Rotate', 'تدوير'),
  'vw.rotate_right': ('90° sağa döndür', 'Rotate 90° right', 'تدوير 90° لليمين'),
  'vw.rotate_left': ('90° sola döndür', 'Rotate 90° left', 'تدوير 90° لليسار'),
  'vw.rotate_failed': ('Döndürülemedi: {error}', 'Could not rotate: {error}', 'تعذّر التدوير: {error}'),
  'vw.zoom_in': ('Yakınlaştır', 'Zoom in', 'تكبير'),
  'vw.zoom_out': ('Uzaklaştır', 'Zoom out', 'تصغير'),
  'vw.text_bigger': ('Yazıyı büyüt', 'Larger text', 'تكبير الخط'),
  'vw.text_smaller': ('Yazıyı küçült', 'Smaller text', 'تصغير الخط'),
  'vw.page_layout': ('Sayfa düzeni', 'Page layout', 'تخطيط الصفحة'),
  'vw.one_column': ('Tek sütun', 'Single column', 'عمود واحد'),
  'vw.two_columns': ('2 sütun', '2 columns', 'عمودان'),
  'vw.four_columns': ('4 sütun', '4 columns', '4 أعمدة'),
  'vw.night_on': ('Gece modu', 'Night mode', 'الوضع الليلي'),
  'vw.night_off': ('Gece modunu kapat', 'Turn off night mode', 'إيقاف الوضع الليلي'),
  'vw.image_to_pdf': ('Resmi PDF yap', 'Image to PDF', 'تحويل الصورة إلى PDF'),
  'vw.image_to_pdf_body': (
    'Resim tam çözünürlükte, kırpılmadan PDF’e gömülecek.\n\n',
    'The image will be embedded in the PDF at full resolution, uncropped.\n\n',
    'ستُضمَّن الصورة في PDF بدقتها الكاملة وبدون اقتصاص.\n\n',
  ),
  'vw.still_loading': (
    'Belge hâlâ yükleniyor…',
    'The document is still loading…',
    'لا يزال المستند قيد التحميل…',
  ),
  'vw.page_of': ('{n}. sayfa (toplam {total})', 'Page {n} (of {total})', 'الصفحة {n} (من {total})'),
  'vw.page_jump_failed_total': (
    '{target}. sayfaya gidilemedi; {landed}. sayfada kalındı (toplam {total}).',
    'Could not jump to page {target}; stayed on page {landed} (of {total}).',
    'تعذّر الانتقال إلى الصفحة {target}؛ بقيت على {landed} (من {total}).',
  ),
  'vw.goto_page': ('Sayfaya git…', 'Go to page…', 'الانتقال إلى صفحة…'),
  'vw.goto_page_short': ('sayfaya git', 'go to page', 'انتقل إلى صفحة'),
  'vw.find_in_doc': ('Belgede ara…', 'Search in document…', 'ابحث في المستند…'),
  'vw.find_in_doc_short': ('Belgede ara', 'Search in document', 'ابحث في المستند'),
  'vw.dont_save': ('Kaydetme', 'Don’t save', 'عدم الحفظ'),
  'vw.image_only': ('Sadece resim', 'Image only', 'الصورة فقط'),
  'vw.doc_info': ('Belge bilgisi', 'Document info', 'معلومات المستند'),
  'vw.highlight': ('Vurgula', 'Highlight', 'تمييز'),
  'fm.drive_subtitle': ('Buluttaki dosyalar', 'Files in the cloud', 'الملفات في السحابة'),
  'fm.memory_analysis': ('Bellek Analizi', 'Storage analysis', 'تحليل التخزين'),
  'fm.new_files': ('Yeni Dosyalar', 'New files', 'ملفات جديدة'),
  'fm.new_files_note': (
    'Son gelenler',
    'Latest arrivals',
    'أحدث الملفات',
  ),
  'fm.scan_document': ('Belge Tara', 'Scan a document', 'مسح مستند'),
  'fm.last_scan': (
    'Son tarama: {date} · {n} dosya',
    'Last scan: {date} · {n} files',
    'آخر فحص: {date} · {n} ملف',
  ),
  'fm.duplicates_title': ('Yinelenen dosyalar', 'Duplicate files', 'ملفات مكررة'),
  'fm.enter_password': ('Parola gir', 'Enter password', 'أدخل كلمة المرور'),
  'fm.clear_finished': ('Bitenleri temizle', 'Clear finished', 'مسح المنتهية'),
  'fm.ask_gemini': ('Gemini’ye sor', 'Ask Gemini', 'اسأل Gemini'),
  'fm.new_word_doc': (
    'Word belgesi (.docx)',
    'Word document (.docx)',
    'مستند Word ‏(.docx)',
  ),
  'fm.existing_tags': (
    'Var olan etiketler',
    'Existing tags',
    'الوسوم الموجودة',
  ),
  'fm.pin_enter': ('PIN girin', 'Enter PIN', 'أدخل رمز PIN'),
  'fm.pin_new': ('Yeni PIN', 'New PIN', 'رمز PIN جديد'),
  'fm.pin_label': ('PIN', 'PIN', 'رمز PIN'),
  'fm.pin_repeat': ('PIN (tekrar)', 'PIN (again)', 'رمز PIN (تكرار)'),
  'vw.select_ocr_running': (
    'Metin tanınıyor…',
    'Recognizing text…',
    'جارٍ التعرف على النص…',
  ),
  'vw.select_ocr_none': (
    'Sayfada seçilebilir metin bulunamadı',
    'No selectable text found on this page',
    'لا يوجد نص قابل للتحديد في هذه الصفحة',
  ),
  'vw.rotated_right': (
    '{n}. sayfa sağa döndürüldü',
    'Page {n} rotated right',
    'تم تدوير الصفحة {n} لليمين',
  ),
  'vw.rotated_left': (
    '{n}. sayfa sola döndürüldü',
    'Page {n} rotated left',
    'تم تدوير الصفحة {n} لليسار',
  ),
  'vw.speak': ('Sesli oku', 'Read aloud', 'قراءة صوتية'),
  'vw.speaking': ('Sesli okuma  {n} / {total}', 'Reading aloud  {n} / {total}', 'قراءة صوتية  {n} / {total}'),
  'vw.toc': ('İçindekiler', 'Contents', 'المحتويات'),
  'vw.no_toc': ('Bu belgede içindekiler yok', 'This document has no contents', 'لا يحتوي هذا المستند على فهرس'),
  'vw.fill_form': ('Formu doldur', 'Fill form', 'تعبئة النموذج'),
  'vw.form_detected': (
    'Bu belge doldurulabilir bir form.',
    'This document is a fillable form.',
    'هذا المستند نموذج قابل للتعبئة.',
  ),
  'vw.print': ('Yazdır', 'Print', 'طباعة'),
  'vw.ai_edit': ('AI ile düzenle', 'Edit with AI', 'تحرير بالذكاء الاصطناعي'),
  'vw.translate_doc': ('Belgeyi çevir', 'Translate document', 'ترجمة المستند'),
  'vw.to_pdf': ('PDF’e dönüştür', 'Convert to PDF', 'تحويل إلى PDF'),
  'vw.to_slides': ('Slayta dönüştür', 'Convert to slides', 'تحويل إلى شرائح'),
  'vw.slides_share': ('Sunum (.pptx)', 'Presentation (.pptx)', 'عرض تقديمي (.pptx)'),
  'ais.with_ai': ('AI ile hazırla', 'Build with AI', 'إنشاء بالذكاء الاصطناعي'),
  'ais.with_ai_hint': (
    'Belgeyi okuyup özetler; başlık, madde ve konuşmacı notu yazar',
    'Reads and summarises the document; writes titles, bullets and notes',
    'يقرأ المستند ويلخّصه؛ يكتب العناوين والنقاط وملاحظات المتحدث',
  ),
  'ais.quick': ('Hızlı (AI\'sız)', 'Quick (no AI)', 'سريع (بدون ذكاء اصطناعي)'),
  'ais.quick_hint': (
    'Metni olduğu gibi böler — ücretsiz ve çevrimdışı',
    'Splits the text as it is — free and offline',
    'يقسّم النص كما هو — مجاني وبدون إنترنت',
  ),
  'ais.as_pptx': ('Sunum (.pptx)', 'Presentation (.pptx)', 'عرض تقديمي (.pptx)'),
  'ais.as_pptx_hint': (
    'Düzenlenebilir — PowerPoint\'te de açılır',
    'Editable — opens in PowerPoint too',
    'قابل للتحرير — يُفتح في PowerPoint أيضًا',
  ),
  'ais.as_pdf': ('Deste (PDF)', 'Deck (PDF)', 'مجموعة شرائح (PDF)'),
  'ais.as_pdf_hint': (
    'Herkes açar, düzeni bozulmaz',
    'Opens anywhere, layout stays put',
    'يُفتح في كل مكان ولا يتغيّر تخطيطه',
  ),
  'ais.working': (
    'Sunum hazırlanıyor…',
    'Building the presentation…',
    'يجري إعداد العرض التقديمي…',
  ),
  'ais.job_done': ('{n} slayt hazır', '{n} slides ready', '{n} شريحة جاهزة'),
  'ais.job_name': ('AI sunumu', 'AI presentation', 'العرض التقديمي بالذكاء الاصطناعي'),
  'ais.failed': (
    'Sunum hazırlanamadı: {error}',
    'Could not build the presentation: {error}',
    'تعذّر إعداد العرض التقديمي: {error}',
  ),
  'vw.slides_no_text': (
    'Bu belgede slayta çevrilecek metin yok.',
    'This document has no text to turn into slides.',
    'لا يوجد في هذا المستند نص لتحويله إلى شرائح.',
  ),
  'vw.file_ops': ('Dosya işlemleri (taşı, kopyala…)', 'File operations (move, copy…)', 'عمليات الملفات (نقل، نسخ…)'),
  'vw.ocr': ('Metni tanı (OCR)', 'Recognize text (OCR)', 'التعرّف على النص (OCR)'),
  'vw.ocr_short': ('Metni tanı', 'Recognize text', 'التعرّف على النص'),
  'vw.ocr_running': ('Metin tanınıyor…', 'Recognizing text…', 'جارٍ التعرّف على النص…'),
  'vw.ocr_page': ('Sayfa {n} / {total} taranıyor…', 'Scanning page {n} / {total}…', 'جارٍ فحص الصفحة {n} / {total}…'),
  'vw.ocr_job_name': ('Metin tanıma', 'Text recognition', 'التعرّف على النص'),
  'vw.image_pdf_job_name': ('Resimden PDF', 'Image to PDF', 'تحويل الصورة إلى PDF'),
  'vw.ocr_finishing': ('Bitiriliyor…', 'Finishing…', 'جارٍ الإنهاء…'),
  'vw.ocr_failed': ('OCR başarısız: {error}', 'OCR failed: {error}', 'فشل التعرّف على النص: {error}'),
  'vw.ocr_none': ('Metin bulunamadı (OCR).', 'No text found (OCR).', 'لم يُعثر على نص (OCR).'),
  'vw.ocr_first': (
    'Metin bulunamadı. Önce “Metni tanı (OCR)” çalıştırın.',
    'No text found. Run “Recognize text (OCR)” first.',
    'لم يُعثر على نص. شغّل «التعرّف على النص (OCR)» أولًا.',
  ),
  'vw.ocr_text': ('Tanınan metin', 'Recognized text', 'النص المتعرَّف عليه'),
  'vw.ocr_in_pdf': (
    'İçindeki yazılar da PDF içinde aranabilir/kopyalanabilir olsun mu? '
        '(Metin tanıma birkaç saniye sürer, görüntüyü değiştirmez.)',
    'Should the text inside also be searchable/copyable in the PDF? '
        '(Text recognition takes a few seconds and does not alter the image.)',
    'هل تريد أن يكون النص بداخلها قابلًا للبحث/النسخ داخل PDF؟ '
        '(يستغرق التعرّف بضع ثوانٍ ولا يغيّر الصورة.)',
  ),
  'vw.ocr_also': ('Yazıları da tanı', 'Also recognize text', 'تعرّف على النص أيضًا'),
  'vw.scanning_text': ('Yazılar taranıyor…', 'Scanning text…', 'جارٍ فحص النص…'),
  'vw.copy_all': ('Tümünü kopyala', 'Copy all', 'نسخ الكل'),
  'vw.copied_all': ('Tümü kopyalandı', 'All copied', 'تم نسخ الكل'),
  'vw.copied_chars': ('Kopyalandı ({n} karakter)', 'Copied ({n} characters)', 'تم النسخ ({n} حرفًا)'),
  'vw.selected_text': ('Seçili metin', 'Selected text', 'النص المحدد'),
  'vw.no_text_to_translate': ('Çevrilecek metin yok.', 'No text to translate.', 'لا يوجد نص للترجمة.'),
  'vw.highlighted': ('Vurgulandı', 'Highlighted', 'تم التمييز'),
  'vw.highlight_remove': ('Vurguyu kaldır', 'Remove highlight', 'إزالة التمييز'),
  'vw.highlight_removed': (
    '{n} vurgu kaldırıldı.',
    '{n} highlight(s) removed.',
    'تمت إزالة {n} تمييز.',
  ),
  'vw.highlight_none_here': (
    'Seçtiğiniz yerde vurgu yok.',
    'There is no highlight where you selected.',
    'لا يوجد تمييز في المكان الذي حددته.',
  ),
  'vw.highlight_hint': ('Vurgula', 'Highlight', 'تمييز'),
  'vw.highlight_failed': ('Vurgulama başarısız: {error}', 'Highlighting failed: {error}', 'فشل التمييز: {error}'),
  'vw.word_count': ('Sözcük sayısı / bilgi', 'Word count / info', 'عدد الكلمات / معلومات'),
  'vw.word': ('Sözcük', 'Words', 'كلمات'),
  'vw.line': ('Satır', 'Lines', 'أسطر'),
  'vw.chars': ('Karakter', 'Characters', 'أحرف'),
  'vw.chars_nospace': ('Karakter (boşluksuz)', 'Characters (no spaces)', 'أحرف (بدون مسافات)'),
  'vw.paragraph': ('Paragraf', 'Paragraphs', 'فقرات'),
  'vw.doc_content': ('Belge içeriği…', 'Document content…', 'محتوى المستند…'),
  'vw.preparing': ('Hazırlanıyor…', 'Preparing…', 'جارٍ التحضير…'),
  'vw.pdf_preparing': ('PDF hazırlanıyor…', 'Preparing the PDF…', 'جارٍ تحضير ملف PDF…'),
  'vw.pdf_loading': (
    'PDF henüz yükleniyor, birazdan tekrar deneyin.',
    'The PDF is still loading; try again shortly.',
    'لا يزال ملف PDF قيد التحميل؛ حاول بعد قليل.',
  ),
  'vw.pdf_exported': ('PDF olarak dışa aktarıldı', 'Exported as PDF', 'تم التصدير بصيغة PDF'),
  'vw.pdf_failed': ('PDF oluşturulamadı: {error}', 'Could not create PDF: {error}', 'تعذّر إنشاء PDF: {error}'),
  'vw.image_failed': ('Görsel görüntülenemedi.', 'The image could not be displayed.', 'تعذّر عرض الصورة.'),
  'vw.table_empty': ('Tablo boş veya okunamadı.', 'The table is empty or unreadable.', 'الجدول فارغ أو غير قابل للقراءة.'),
  'vw.no_viewer': (
    'Bu dosya türü için yerleşik görüntüleyici yok.\nBaşka bir uygulamayla '
        'açabilir veya AI’a sorabilirsiniz.',
    'There is no built-in viewer for this file type.\nYou can open it with '
        'another app or ask the AI.',
    'لا يوجد عارض مدمج لهذا النوع من الملفات.\nيمكنك فتحه بتطبيق آخر أو سؤال '
        'الذكاء الاصطناعي.',
  ),
  'vw.link_title': ('Bağlantıyı aç', 'Open link', 'فتح الرابط'),
  'vw.link_body': (
    'Bu belge sizi şu adrese götürmek istiyor:\n\n{url}\n\n'
        'Tanımadığınız adreslere dikkat edin.',
    'This document wants to take you to:\n\n{url}\n\n'
        'Be careful with addresses you do not recognize.',
    'يريد هذا المستند نقلك إلى:\n\n{url}\n\nكن حذرًا مع العناوين غير المعروفة.',
  ),
  'vw.link_failed': ('Bağlantı açılamadı', 'Could not open the link', 'تعذّر فتح الرابط'),
  'vw.link_failed_e': ('Bağlantı açılamadı: {error}', 'Could not open the link: {error}', 'تعذّر فتح الرابط: {error}'),
  'vw.unsaved_title': ('Kaydedilmemiş düzenleme var', 'You have unsaved edits', 'لديك تعديلات غير محفوظة'),
  'vw.unsaved_body': (
    'Belgede yaptığınız değişiklikler henüz kaydedilmedi. “Kaydetme” '
        'derseniz belge düzenlemeden önceki hâline döner.',
    'Your changes to the document have not been saved. If you choose “Don’t '
        'save”, the document reverts to its state before editing.',
    'لم تُحفظ تغييراتك على المستند. إذا اخترت «عدم الحفظ»، سيعود المستند إلى '
        'حالته قبل التحرير.',
  ),
  'vw.save_edits': ('Düzenlemeleri kaydet', 'Save edits', 'حفظ التعديلات'),
  'vw.edits_applied': (
    'Yaptığınız düzenlemeler bu belgeye işlendi.',
    'Your edits have been applied to this document.',
    'تم تطبيق تعديلاتك على هذا المستند.',
  ),
  'vw.page_number': ('Sayfa numarası (1 – {count})', 'Page number (1 – {count})', 'رقم الصفحة (1 – {count})'),
  'vw.page_jump_failed': (
    '{target}. sayfaya gidilemedi; {landed}. sayfada kalındı.',
    'Could not jump to page {target}; stayed on page {landed}.',
    'تعذّر الانتقال إلى الصفحة {target}؛ بقيت على الصفحة {landed}.',
  ),
  'vw.searching': ('aranıyor…', 'searching…', 'جارٍ البحث…'),
  'vw.no_readable_text': (
    'Okunacak metin bulunamadı. Taranmış belgede önce “Metni tanı (OCR)”.',
    'No readable text found. On a scanned document, run “Recognize text (OCR)” first.',
    'لم يُعثر على نص قابل للقراءة. في مستند ممسوح ضوئيًا، شغّل «التعرّف على النص (OCR)» أولًا.',
  ),

  // ── Arşiv görüntüleyici ───────────────────────────────────────────────────
  'arc.search': ('Arşiv içinde ara…', 'Search in archive…', 'ابحث في الأرشيف…'),
  'arc.no_match': ('Eşleşen dosya yok', 'No matching file', 'لا يوجد ملف مطابق'),
  'arc.extract_all': ('Tümünü çıkar', 'Extract all', 'استخراج الكل'),
  'arc.extract_one': ('Bu dosyayı çıkar', 'Extract this file', 'استخراج هذا الملف'),
  'arc.opening': ('Açılıyor', 'Opening', 'جارٍ الفتح'),
  'arc.open_failed': ('Arşiv açılamadı: {error}', 'Could not open archive: {error}', 'تعذّر فتح الأرشيف: {error}'),
  'arc.extracted_file': ('{name} çıkarıldı', '{name} extracted', 'تم استخراج {name}'),
  'arc.encrypted': ('şifreli', 'encrypted', 'مشفّر'),
  'arc.multipart': ('çok parçalı', 'multi-part', 'متعدد الأجزاء'),
  'arc.ratio': ('sıkıştırma %{pct}', '{pct}% compressed', 'ضغط {pct}%'),

  // ── Otomatik düzenle ──────────────────────────────────────────────────────
  'org.title': ('Otomatik düzenle', 'Auto-organize', 'التنظيم التلقائي'),
  'org.by_what': ('Neye göre ayrılsın?', 'Group by what?', 'التجميع حسب ماذا؟'),
  'org.include_sub': ('Alt klasörler dahil', 'Include subfolders', 'تضمين المجلدات الفرعية'),
  'org.include_sub_note': (
    'Kapalıyken yalnız bu klasördeki dosyalar düzenlenir; mevcut alt '
        'klasörlerinize dokunulmaz.',
    'When off, only files in this folder are organized; your existing '
        'subfolders are left untouched.',
    'عند الإيقاف، تُنظَّم ملفات هذا المجلد فقط؛ ولا تُمس مجلداتك الفرعية الحالية.',
  ),
  'org.preview': ('Önizleme', 'Preview', 'معاينة'),
  'org.nothing': ('Düzenlenecek dosya yok', 'Nothing to organize', 'لا شيء لتنظيمه'),
  'org.nothing_body': (
    'Bu klasörde düzenlenecek dosya yok.',
    'There are no files to organize in this folder.',
    'لا توجد ملفات لتنظيمها في هذا المجلد.',
  ),
  'org.all_placed': (
    'Her şey zaten yerinde görünüyor ({n} dosya zaten doğru klasörde.)',
    'Everything already looks in place ({n} files are already in the right folder.)',
    'يبدو أن كل شيء في مكانه ({n} ملف موجود بالفعل في المجلد الصحيح.)',
  ),
  'org.plan': (
    '{files} dosya → {folders} klasör',
    '{files} files → {folders} folders',
    '{files} ملف ← {folders} مجلد',
  ),
  'org.action': ('{n} dosyayı düzenle', 'Organize {n} files', 'نظّم {n} ملف'),
  'org.confirm_title': ('Düzenlensin mi?', 'Organize?', 'هل تريد التنظيم؟'),
  'org.confirm_body': (
    '{files} dosya, {folders} klasöre taşınacak. Dosyalar aynı klasörün '
        'içinde yer değiştirir; silinmez. İşlem geçmişinden geri alabilirsiniz.',
    '{files} files will be moved into {folders} folders. Files are rearranged '
        'inside the same folder; nothing is deleted. You can undo it from the '
        'operation history.',
    'سيتم نقل {files} ملف إلى {folders} مجلد. تُعاد ترتيب الملفات داخل المجلد '
        'نفسه ولا يُحذف شيء. يمكنك التراجع من سجل العمليات.',
  ),
  'org.working': ('Düzenleniyor', 'Organizing', 'جارٍ التنظيم'),
  'org.done': ('{n} dosya düzenlendi.', '{n} files organized.', 'تم تنظيم {n} ملف.'),
  'org.partial': (
    'Bazı dosyalar taşınamadı: {error}',
    'Some files could not be moved: {error}',
    'تعذّر نقل بعض الملفات: {error}',
  ),
  'org.open_folder': ('Klasörü aç', 'Open folder', 'فتح المجلد'),

  // ── Yüklü uygulamalar ─────────────────────────────────────────────────────
  'apps.not_found': ('Uygulama bulunamadı', 'No app found', 'لم يُعثر على تطبيق'),
  'apps.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'apps.sort_installed': ('Kurulum tarihine göre', 'By install date', 'حسب تاريخ التثبيت'),
  'apps.sort_idle': (
    'En uzun kullanılmayan önce',
    'Longest unused first',
    'الأطول دون استخدام أولًا',
  ),
  'apps.show_system': ('Sistem uygulamalarını göster', 'Show system apps', 'إظهار تطبيقات النظام'),
  'apps.hide_system': ('Sistem uygulamalarını gizle', 'Hide system apps', 'إخفاء تطبيقات النظام'),
  'apps.uninstall': ('Kaldır', 'Uninstall', 'إلغاء التثبيت'),

  // ── Uygulamayı APK olarak paylaşma (kullanıcı isteği 2026-08-29) ─────────
  'apk.share': ('APK olarak paylaş', 'Share as APK', 'مشاركة كملف APK'),
  'apk.save': (
    'APK\'yı İndirilenler\'e kaydet',
    'Save APK to Downloads',
    'حفظ APK في التنزيلات',
  ),
  'apk.extracting': ('APK hazırlanıyor…', 'Preparing APK…', 'جارٍ تحضير APK…'),
  'apk.not_found': (
    'Bu uygulamanın APK dosyası okunamadı.',
    'The APK file of this app could not be read.',
    'تعذّرت قراءة ملف APK لهذا التطبيق.',
  ),
  'apk.failed': ('APK çıkarılamadı: {error}', 'Could not extract APK: {error}',
      'تعذّر استخراج APK: {error}'),
  'apk.saved': ('{name} kaydedildi', '{name} saved', 'تم حفظ {name}'),
  // Parçalı (App Bundle) kurulum uyarısı — dürüstlük meselesi: yalnız
  // base.apk paylaşmak karşı tarafta "uygulama yüklenmedi" demek olabilir.
  'apk.split_title': (
    'Bu uygulama parçalı kurulmuş',
    'This app is installed in parts',
    'هذا التطبيق مثبَّت على أجزاء',
  ),
  'apk.split_body': (
    'Play\'den kurulan uygulamalar base.apk + ekran/dil/işlemci parçaları '
        'olarak durur ({n} parça). Kod base.apk\'ta ama kütüphaneler ve '
        'kaynaklar parçalarda: tek başına base.apk karşı tarafta '
        'kurulmayabilir ya da açılır açılmaz çökebilir.',
    'Apps installed from Play are stored as base.apk plus screen/language/CPU '
        'parts ({n} parts). The code is in base.apk but the libraries and '
        'resources are in the parts: base.apk alone may fail to install or '
        'crash on launch.',
    'التطبيقات المثبتة من Play تُخزَّن كـ base.apk مع أجزاء الشاشة واللغة '
        'والمعالج ({n} أجزاء). الشيفرة في base.apk لكن المكتبات والموارد في '
        'الأجزاء: قد لا يُثبَّت base.apk وحده أو ينهار عند التشغيل.',
  ),
  'apk.split_all': (
    'Tümü (.apks — önerilen)',
    'All parts (.apks — recommended)',
    'كل الأجزاء (.apks — موصى به)',
  ),
  'apk.split_base': ('Yalnız base.apk', 'base.apk only', 'base.apk فقط'),
  'apk.split_note': (
    '.apks dosyası bütün parçaları taşır; karşı tarafta "Split APKs Installer" '
        'gibi bir kurulum aracıyla açılır.',
    'An .apks file carries every part; the receiver installs it with a tool '
        'such as “Split APKs Installer”.',
    'يحمل ملف .apks كل الأجزاء؛ يثبّته المستلم بأداة مثل «Split APKs Installer».',
  ),
  'apps.app_info': ('Uygulama bilgisi (sistem ayarı)', 'App info (system settings)', 'معلومات التطبيق (إعدادات النظام)'),
  'apps.color_legend': ('Renk = kullanılmama süresi', 'Colour = time unused', 'اللون = مدة عدم الاستخدام'),
  'apps.never_opened': ('hiç açılmadı', 'never opened', 'لم يُفتح قط'),
  'apps.today': ('bugün', 'today', 'اليوم'),
  // Kullanım verisi tutulan pencereden (2 yıl) daha eski kurulumlarda kayıt
  // olmayabilir; "hiç açılmadı" demek uydurma olurdu (2026-08-28).
  // Çökme sonrası panoda görünen tek satır (2026-08-28).
  'crash.notice': (
    'Uygulama beklenmedik şekilde hata verdi ({n} kayıt). Raporu gör.',
    'The app hit an unexpected error ({n} reports). See the report.',
    'واجه التطبيق خطأً غير متوقع ({n} سجل). اعرض التقرير.',
  ),
  // ── PDF: sayfa numarası ve filigran (2026-08-28) ────────────────────────
  'pt.page_numbers': ('Sayfa numarası ekle', 'Add page numbers', 'إضافة أرقام الصفحات'),
  'pt.pn_skip_first': ('Kapak sayfasını atla', 'Skip the cover page', 'تخطّي صفحة الغلاف'),
  'pt.pn_skip_first_sub': (
    'İlk sayfa numarasız kalır, numara 2\'den başlar',
    'The first page stays unnumbered; numbering starts at 2',
    'تبقى الصفحة الأولى بلا رقم ويبدأ الترقيم من ٢',
  ),
  'pt.pn_with_total': ('"3 / 12" biçiminde', 'Use the "3 / 12" format', 'بصيغة «٣ / ١٢»'),
  'pt.pn_right': ('Sağ alta hizala', 'Align to the bottom right', 'محاذاة إلى أسفل اليمين'),
  'pt.op_page_numbers': ('Sayfa numarası ekleniyor', 'Adding page numbers', 'جارٍ إضافة أرقام الصفحات'),
  'pt.export_images': ('Sayfaları görsel yap (PNG)', 'Export pages as images (PNG)', 'تصدير الصفحات كصور (PNG)'),
  'pt.op_export_images': ('Görseller üretiliyor', 'Creating images', 'جارٍ إنشاء الصور'),
  'pt.export_images_count': ('{n} sayfa görseli', '{n} page images', '{n} صورة صفحة'),
  'pt.export_images_limit': (
    'Tek seferde en fazla {n} sayfa: önce sayfaları seçin.',
    'At most {n} pages at a time: select the pages first.',
    'بحد أقصى {n} صفحة في المرة: اختر الصفحات أولًا.',
  ),
  'pt.export_images_failed': (
    'Sayfa görseli üretilemedi',
    'Could not create page images',
    'تعذّر إنشاء صور الصفحات',
  ),
  'pt.watermark': ('Filigran ekle', 'Add watermark', 'إضافة علامة مائية'),
  'pt.watermark_hint': ('Örn. TASLAK, KOPYA', 'e.g. DRAFT, COPY', 'مثال: مسودة، نسخة'),
  'pt.op_watermark': ('Filigran ekleniyor', 'Adding watermark', 'جارٍ إضافة العلامة المائية'),
  'apps.long_ago': (
    '2 yıldan uzun',
    'over 2 years',
    'أكثر من سنتين',
  ),
  'apps.days_ago': ('{n} gün önce', '{n} days ago', 'قبل {n} يوم'),
  'apps.usage_needed': (
    'Son açılma tarihleri için izin gerekli',
    'Permission is required for last-opened dates',
    'يلزم إذن لمعرفة تواريخ آخر فتح',
  ),
  'apps.usage_body': (
    'Android’in “Kullanım erişimi” iznini verirsen hangi uygulamayı en son ne '
        'zaman açtığın görünür ve uzun süredir kullanılmayanlar renklenir. '
        'Veri cihazdan çıkmaz.',
    'If you grant Android’s “Usage access” permission, you can see when you '
        'last opened each app and long-unused ones are highlighted. No data '
        'leaves the device.',
    'إذا منحت إذن «الوصول إلى بيانات الاستخدام» من Android، يمكنك رؤية آخر مرة '
        'فتحت فيها كل تطبيق وتُميَّز التطبيقات غير المستخدمة. لا تغادر أي بيانات الجهاز.',
  ),
  'apps.usage_hint': (
    'Açılan ayar sayfasından “Dosya Okuyucu”ya izin verip geri dönün.',
    'Grant the permission to “Dosya Okuyucu” on the settings page that opens, '
        'then come back.',
    'امنح الإذن لتطبيق «Dosya Okuyucu» في صفحة الإعدادات التي تُفتح ثم عُد.',
  ),

  // ── Yer aç (temizlik) ─────────────────────────────────────────────────────
  'clean.trash': ('Çöp kutusunu boşalt', 'Empty the trash', 'تفريغ سلة المهملات'),
  'clean.trash_detail': (
    '{n} öğe · zaten silinmiş dosyalar',
    '{n} items · files already deleted',
    '{n} عنصر · ملفات محذوفة بالفعل',
  ),
  'clean.duplicates': (
    'Yinelenen dosyaları temizle',
    'Clean up duplicate files',
    'تنظيف الملفات المكررة',
  ),
  'clean.duplicates_detail': (
    '{n} fazladan kopya · her gruptan biri kalır',
    '{n} extra copies · one from each group is kept',
    '{n} نسخة زائدة · يُحتفظ بواحدة من كل مجموعة',
  ),
  'clean.stale_downloads': ('Eski indirilenler', 'Old downloads', 'تنزيلات قديمة'),
  'clean.stale_downloads_detail': (
    '{n} dosya · 180+ gündür açılmamış',
    '{n} files · not opened for 180+ days',
    '{n} ملف · لم تُفتح منذ أكثر من 180 يومًا',
  ),
  'clean.apk': ('Kurulum dosyaları (APK)', 'Installer files (APK)', 'ملفات التثبيت (APK)'),
  'clean.apk_detail': (
    '{n} dosya · uygulama kurulduysa gereksiz',
    '{n} files · unnecessary once the app is installed',
    '{n} ملف · غير لازمة بعد تثبيت التطبيق',
  ),
  'clean.big_videos': ('Büyük videolar', 'Large videos', 'فيديوهات كبيرة'),
  'clean.big_videos_detail': (
    '{n} video · 100 MB üzeri (tek tek seçin)',
    '{n} videos · over 100 MB (select them individually)',
    '{n} فيديو · أكبر من 100 ميغابايت (اخترها واحدًا واحدًا)',
  ),
  'clean.confirm_title': ('Temizlensin mi?', 'Clean up?', 'هل تريد التنظيف؟'),
  'clean.title': ('Yer aç', 'Free up space', 'تحرير مساحة'),
  'clean.analyzing': ('Yer aç: depolama çözümleniyor', 'Free up space: analysing storage', 'تحرير مساحة: جارٍ تحليل التخزين'),
  'clean.analyzing_name': ('Yer aç: depolama çözümlemesi', 'Free up space: storage analysis', 'تحرير مساحة: تحليل التخزين'),
  'clean.reading_index': ('Depolama okunuyor…', 'Reading storage…', 'جارٍ قراءة وحدة التخزين…'),
  'clean.reading_trash': ('Çöp kutusu okunuyor…', 'Reading the trash…', 'جارٍ قراءة المهملات…'),
  'clean.reading_downloads': ('İndirilenler inceleniyor…', 'Inspecting downloads…', 'جارٍ فحص التنزيلات…'),
  'clean.finding_dupes': (
    'Yinelenen dosyalar aranıyor (bayt bayt)…',
    'Looking for duplicate files (byte by byte)…',
    'جارٍ البحث عن الملفات المكررة (بايت ببايت)…',
  ),
  'clean.nothing': ('Temizlenecek belirgin bir şey yok', 'Nothing obvious to clean', 'لا شيء واضح للتنظيف'),
  'clean.nothing_body': (
    'Temizlenecek belirgin bir şey bulunamadı 🎉\nDepolaman düzenli görünüyor.',
    'Nothing obvious to clean 🎉\nYour storage looks tidy.',
    'لا شيء واضح للتنظيف 🎉\nيبدو تخزينك مرتبًا.',
  ),
  'clean.recoverable': ('{size} kazanılabilir', '{size} can be freed', 'يمكن تحرير {size}'),
  'clean.suggestions': ('{n} öneri', '{n} suggestions', '{n} اقتراح'),
  'clean.free_action': ('{size} yer aç', 'Free {size}', 'حرّر {size}'),
  'clean.pick_one': ('Bir öneri seçin', 'Pick a suggestion', 'اختر اقتراحًا'),
  'clean.personal_warning': (
    'Dikkat: bunlar kişisel dosyalar olabilir',
    'Careful: these may be personal files',
    'انتبه: قد تكون هذه ملفات شخصية',
  ),
  'clean.confirm_body': (
    '{n} öneri · {size} yer açılacak.\n\nDosyalar çöp kutusuna taşınır '
        '(ayarlarda kapatılmadıysa), İşlem geçmişinden geri alabilirsiniz.',
    '{n} suggestions · {size} will be freed.\n\nFiles are moved to the trash '
        '(unless disabled in settings); you can undo from the operation history.',
    '{n} اقتراح · سيتم تحرير {size}.\n\nتُنقل الملفات إلى المهملات (ما لم يُعطَّل '
        'ذلك في الإعدادات)، ويمكنك التراجع من سجل العمليات.',
  ),
  'clean.cleaning': ('Yer aç: {size} temizleniyor', 'Free up space: cleaning {size}', 'تحرير مساحة: جارٍ تنظيف {size}'),
  'clean.cleaning_name': ('Yer aç: {size} temizliği', 'Free up space: {size} clean-up', 'تحرير مساحة: تنظيف {size}'),
  'clean.cleaned_detail': (
    '{size} boşaltıldı · {n} öneri uygulandı',
    '{size} freed · {n} suggestions applied',
    'تم تحرير {size} · طُبّق {n} من الاقتراحات',
  ),
  'clean.reanalyze': ('Yeniden çözümle', 'Re-analyse', 'إعادة التحليل'),
  'clean.open_trash': ('Çöp kutusunu aç', 'Open the trash', 'فتح المهملات'),
  'clean.see_files': ('{n} dosyayı gör', 'See {n} files', 'عرض {n} ملف'),
  'clean.dupes_note': (
    'Kopya taraması dosyaları bayt bayt karşılaştırır, biraz sürebilir.',
    'Duplicate scanning compares files byte by byte; it can take a while.',
    'يقارن فحص التكرارات الملفات بايتًا ببايت، وقد يستغرق بعض الوقت.',
  ),

  // ── Bellek analizi ────────────────────────────────────────────────────────
  'ana.by_type': ('Türlere göre', 'By type', 'حسب النوع'),
  'ana.largest': ('En büyük dosyalar', 'Largest files', 'أكبر الملفات'),
  'ana.search_all': ('Tüm dosyalarda ara…', 'Search all files…', 'ابحث في كل الملفات…'),
  'ana.searching': ('Aranıyor…', 'Searching…', 'جارٍ البحث…'),
  'ana.results': ('Arama sonuçları', 'Search results', 'نتائج البحث'),
  'ana.result_count': ('{n} sonuç', '{n} results', '{n} نتيجة'),
  'ana.total_summary': (
    '{n} dosya · {size}',
    '{n} files · {size}',
    '{n} ملف · {size}',
  ),
  'ana.scope_all': ('Tümü', 'All', 'الكل'),
  'ana.filter_count': ('{n} filtre', '{n} filters', '{n} مرشّح'),
  'ana.no_result': ('Sonuç bulunamadı.', 'No results found.', 'لم يُعثر على نتائج.'),
  'ana.no_files': ('Gösterilecek dosya yok.', 'No files to show.', 'لا توجد ملفات لعرضها.'),
  'ana.no_scan': ('Henüz tarama sonucu yok.', 'No scan results yet.', 'لا توجد نتائج فحص بعد.'),
  'ana.usage_unreadable': (
    'Doluluk bilgisi okunamadı.',
    'Storage usage could not be read.',
    'تعذّرت قراءة معلومات الاستخدام.',
  ),
  'ana.used_free': ('{used} kullanıldı · {free} boş', '{used} used · {free} free', '{used} مستخدم · {free} فارغ'),
  'ana.trend': (
    'Son {days} günde en çok büyüyen: {category}',
    'Grew the most in the last {days} days: {category}',
    'الأكثر نموًا في آخر {days} يوم: {category}',
  ),
  'ana.free_space': ('Yer aç (temizlik önerileri)', 'Free up space (cleanup suggestions)', 'تحرير مساحة (اقتراحات التنظيف)'),
  'ana.free_space_note': (
    'Çöp kutusu, kopyalar, eski indirilenler ve büyük dosyalar',
    'Trash, duplicates, old downloads and large files',
    'المهملات والنسخ المكررة والتنزيلات القديمة والملفات الكبيرة',
  ),
  'ana.find_dupes': ('Yinelenen dosyaları bul', 'Find duplicate files', 'البحث عن الملفات المكررة'),
  'ana.find_dupes_note': (
    'Birebir aynı dosyaları bulur, bir kopyayı bırakıp kalanları çöpe taşır',
    'Finds byte-identical files, keeps one copy and moves the rest to the trash',
    'يعثر على الملفات المتطابقة تمامًا، ويبقي نسخة واحدة وينقل الباقي إلى المهملات',
  ),

  // ── Klasör haritası (bellek analizi → hangi klasör ne kadar yer kaplıyor) ──
  'fmap.title': ('Klasör haritası', 'Folder map', 'خريطة المجلدات'),
  'fmap.note': (
    'Klasörleri boyuta göre sıralar; içine girerek yerin nerede gittiğini bulun',
    'Ranks folders by size; drill in to find where the space went',
    'يرتّب المجلدات حسب الحجم؛ ادخل إليها لمعرفة أين ذهبت المساحة',
  ),
  'fmap.summary': (
    '{n} dosya · {size}',
    '{n} files · {size}',
    '{n} ملف · {size}',
  ),
  'fmap.empty': (
    'Bu klasörde ölçülecek dosya yok.',
    'No files to measure in this folder.',
    'لا توجد ملفات لقياسها في هذا المجلد.',
  ),

  // ── Çöp kutusu ────────────────────────────────────────────────────────────
  'trash.title': ('Geri Dönüşüm Kutusu', 'Recycle Bin', 'سلة المحذوفات'),
  'trash.empty': ('Çöp kutusu boş', 'The trash is empty', 'سلة المهملات فارغة'),
  'trash.search': ('Çöp kutusunda ara', 'Search the trash', 'ابحث في المهملات'),
  'trash.search_hint': ('Çöp kutusunda ara…', 'Search the trash…', 'ابحث في المهملات…'),
  'trash.restore': ('Geri yükle', 'Restore', 'استعادة'),
  'trash.delete_forever': ('Kalıcı sil', 'Delete permanently', 'حذف نهائي'),
  'trash.empty_action': ('Boşalt', 'Empty', 'تفريغ'),
  'trash.count_size': ('{n} öğe · {size}', '{n} items · {size}', '{n} عنصر · {size}'),
  'trash.filtered': ('{n} / {total} öğe', '{n} / {total} items', '{n} / {total} عنصر'),
  'trash.restored': (
    '“{name}” geri yüklendi → {where}',
    '“{name}” restored → {where}',
    'تمت استعادة «{name}» ← {where}',
  ),
  'trash.restore_failed': (
    'Geri yüklenemedi: {error}',
    'Could not restore: {error}',
    'تعذّرت الاستعادة: {error}',
  ),
  'trash.delete_one_body': (
    '“{name}” geri alınamaz şekilde silinecek.',
    '“{name}” will be deleted irreversibly.',
    'سيتم حذف «{name}» بشكل نهائي.',
  ),
  'trash.deleted_one': (
    '“{name}” kalıcı olarak silindi.',
    '“{name}” was deleted permanently.',
    'تم حذف «{name}» نهائيًا.',
  ),
  'trash.empty_confirm_title': (
    'Çöp kutusu boşaltılsın mı?',
    'Empty the trash?',
    'هل تريد تفريغ سلة المهملات؟',
  ),
  'trash.empty_confirm_body': (
    '{n} öğe ({size}) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    '{n} items ({size}) will be deleted permanently. This cannot be undone.',
    'سيتم حذف {n} عنصر ({size}) نهائيًا. لا يمكن التراجع عن هذا.',
  ),
  'trash.emptying': ('Çöp kutusu boşaltılıyor', 'Emptying the trash', 'جارٍ تفريغ المهملات'),
  'trash.emptied': (
    'Çöp kutusu boşaltıldı · {n} öğe · {size} yer açıldı.',
    'Trash emptied · {n} items · {size} freed.',
    'تم تفريغ المهملات · {n} عنصر · تحرير {size}.',
  ),
  'trash.empty_stopped': (
    'Durduruldu — {n} öğe silindi.',
    'Stopped — {n} items deleted.',
    'تم الإيقاف — تم حذف {n} عنصر.',
  ),
  'trash.empty_partial': (
    '{ok} öğe silindi, {fail} öğe silinemedi: {error}',
    '{ok} items deleted, {fail} could not be deleted: {error}',
    'تم حذف {ok} عنصر، وتعذّر حذف {fail}: {error}',
  ),

  // ── Önemli dosyalar ───────────────────────────────────────────────────────
  'important.title': ('Önemli Dosyalar', 'Important files', 'الملفات المهمة'),
  'important.search': ('Önemli dosyalarda ara', 'Search important files', 'ابحث في الملفات المهمة'),
  'important.missing': (
    'Önemli dosyalar klasörü yok',
    'The important-files folder does not exist',
    'مجلد الملفات المهمة غير موجود',
  ),
  'important.explain': (
    'Kimlik, fatura, sözleşme gibi kaybolmaması gereken dosyaları tek yerde '
        'toplayın. Klasör ana bellekte oluşturulur.\n\nDosya eklemek: herhangi '
        'bir dosyaya uzun basın → “Taşı” ya da “Kopyala” → “Önemli Dosyalar”. '
        'Konu başlıklarına göre alt klasörler de açabilirsiniz.',
    'Keep files you must not lose — ID, invoices, contracts — in one place. '
        'The folder is created in internal storage.\n\nTo add a file: long-press '
        'any file → “Move” or “Copy” → “Important files”. You can also create '
        'subfolders per topic.',
    'اجمع الملفات التي لا يجب أن تفقدها — الهوية والفواتير والعقود — في مكان '
        'واحد. يُنشأ المجلد في الذاكرة الداخلية.\n\nلإضافة ملف: اضغط مطولًا على '
        'أي ملف ← «نقل» أو «نسخ» ← «الملفات المهمة». يمكنك أيضًا إنشاء مجلدات '
        'فرعية حسب الموضوع.',
  ),
  'important.create_folder': ('Klasörü oluştur', 'Create the folder', 'إنشاء المجلد'),
  'important.open_in_browser': ('Klasörü gezginde aç', 'Open folder in browser', 'فتح المجلد في المستعرض'),
  'important.subfolders': ('Alt klasörler', 'Subfolders', 'المجلدات الفرعية'),
  'important.new_subfolder': ('Yeni alt klasör', 'New subfolder', 'مجلد فرعي جديد'),
  'important.by_type': ('Türlere göre', 'By type', 'حسب النوع'),
  'important.no_subfolder': (
    'Henüz alt klasör yok. “Yeni” ile konu başlıkları (Faturalar, Kimlik, '
        'Sözleşmeler…) açabilirsiniz. Dosya eklemek için herhangi bir dosyaya '
        'uzun basıp “Taşı”/“Kopyala” deyin.',
    'No subfolders yet. Use “New” to create topics (Invoices, ID, Contracts…). '
        'To add a file, long-press any file and choose “Move”/“Copy”.',
    'لا توجد مجلدات فرعية بعد. استخدم «جديد» لإنشاء مواضيع (فواتير، هوية، '
        'عقود…). لإضافة ملف، اضغط مطولًا على أي ملف واختر «نقل»/«نسخ».',
  ),

  // ── İndirilenler ──────────────────────────────────────────────────────────
  'downloads.title': ('İndirilenler', 'Downloads', 'التنزيلات'),
  'downloads.search': ('İndirilenler içinde ara', 'Search downloads', 'ابحث في التنزيلات'),
  'downloads.search_hint': ('İndirilenler içinde ara…', 'Search downloads…', 'ابحث في التنزيلات…'),
  'downloads.empty': (
    'İndirilenler klasörü boş',
    'The downloads folder is empty',
    'مجلد التنزيلات فارغ',
  ),
  'downloads.no_result': ('“{q}” için sonuç yok.', 'No results for “{q}”.', 'لا نتائج لـ«{q}».'),
  'downloads.count': (
    '{n} dosya · alt klasörler dahil',
    '{n} files · including subfolders',
    '{n} ملف · بما في ذلك المجلدات الفرعية',
  ),
  'downloads.selected': ('{n} / {total} seçildi', '{n} / {total} selected', 'تم تحديد {n} / {total}'),
  'downloads.sort': ('Sırala', 'Sort', 'ترتيب'),
  'downloads.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'downloads.sort_newest': ('En yeni önce', 'Newest first', 'الأحدث أولًا'),
  'downloads.sort_oldest': (
    'En eski (silme adayları) önce',
    'Oldest (deletion candidates) first',
    'الأقدم (مرشحة للحذف) أولًا',
  ),
  'downloads.sort_largest': ('En büyük önce', 'Largest first', 'الأكبر أولًا'),
  'downloads.select_old': ('Eskileri seç', 'Select old ones', 'حدّد القديمة'),
  'downloads.folder_view': (
    'Klasör görünümü (alt klasörlerde gez)',
    'Folder view (browse subfolders)',
    'عرض المجلدات (تصفّح المجلدات الفرعية)',
  ),
  'downloads.last_opened': ('son açılma: {when}', 'last opened: {when}', 'آخر فتح: {when}'),
  'downloads.ancient_hint': (
    '{n} dosya 6 aydır dokunulmamış · ',
    '{n} files untouched for 6 months · ',
    '{n} ملف لم يُلمس منذ 6 أشهر · ',
  ),

  // ── Klasör seçici ─────────────────────────────────────────────────────────
  'picker.title': ('Hedef klasör', 'Destination folder', 'المجلد الوجهة'),
  'picker.parent': ('Üst klasör', 'Parent folder', 'المجلد الأصل'),
  'picker.summary': ('{n} öğe · {name}', '{n} items · {name}', '{n} عنصر · {name}'),
  'picker.source_itself': ('Kaynağın kendisi', 'The source itself', 'المصدر نفسه'),
  'picker.unreadable': (
    'Bu klasör okunamıyor (izin yok).',
    'This folder cannot be read (no permission).',
    'تعذّرت قراءة هذا المجلد (لا يوجد إذن).',
  ),
  'picker.no_subfolder': (
    'Bu klasörde alt klasör yok.\nAşağıdaki düğmeyle buraya koyabilir ya da '
        'üstteki “yeni klasör” ile bir tane açabilirsiniz.',
    'This folder has no subfolders.\nUse the button below to place items here, '
        'or create one with “new folder” above.',
    'لا توجد مجلدات فرعية هنا.\nاستخدم الزر أدناه للوضع هنا، أو أنشئ مجلدًا '
        'عبر «مجلد جديد» بالأعلى.',
  ),

  // ── Dosya açma ────────────────────────────────────────────────────────────
  'open.opening': ('Dosya açılıyor…', 'Opening file…', 'جارٍ فتح الملف…'),
  'open.with_what': ('{kind} neyle açılsın?', 'Open {kind} with?', 'بماذا تفتح {kind}؟'),
  'open.kind_image': ('Görsel', 'Image', 'صورة'),
  'open.kind_audio': ('Ses dosyası', 'Audio file', 'ملف صوتي'),
  'open.in_app_player': (
    'Uygulama içi oynatıcı',
    'Built-in player',
    'المشغّل المدمج',
  ),
  'open.in_app_hint': (
    'Hızlı açılır, uygulamadan çıkmazsın',
    'Opens fast, you stay in the app',
    'يفتح بسرعة وتبقى داخل التطبيق',
  ),
  'open.other_app': ('Başka uygulama', 'Another app', 'تطبيق آخر'),
  'open.other_app_hint': (
    'Kendi medya oynatıcın / galerin',
    'Your own media player / gallery',
    'مشغّل الوسائط / المعرض الخاص بك',
  ),
  'open.remember': ('Bunu hatırla', 'Remember this', 'تذكّر هذا'),
  'open.remember_hint': (
    'Ayarlardan değiştirebilirsin',
    'You can change it in Settings',
    'يمكنك تغييره من الإعدادات',
  ),
  'open.no_app': (
    'Bu dosya türünü açabilen bir uygulama bulunamadı.',
    'No app found that can open this file type.',
    'لم يُعثر على تطبيق يمكنه فتح هذا النوع من الملفات.',
  ),
  'open.not_found': (
    'Dosya bulunamadı (taşınmış ya da silinmiş olabilir).',
    'File not found (it may have been moved or deleted).',
    'لم يُعثر على الملف (ربما تم نقله أو حذفه).',
  ),

  // ── Uzak depolama (NAS) ───────────────────────────────────────────────────
  'nas.title': ('Ağ depolama', 'Network storage', 'التخزين الشبكي'),
  'nas.subtitle': ('NAS · FTP · SFTP · SMB', 'NAS · FTP · SFTP · SMB', 'NAS · FTP · SFTP · SMB'),
  'nas.empty': (
    'Kayıtlı bağlantı yok. Sunucunuzu elle ekleyin ya da ağda arayın.',
    'No saved connections. Add your server manually or scan the network.',
    'لا توجد اتصالات محفوظة. أضف خادمك يدويًا أو ابحث في الشبكة.',
  ),
  'nas.add': ('Bağlantı ekle', 'Add connection', 'إضافة اتصال'),
  'nas.edit': ('Bağlantıyı düzenle', 'Edit connection', 'تعديل الاتصال'),
  'nas.scan': ('Ağda ara', 'Scan network', 'البحث في الشبكة'),
  'nas.scanning': ('Ağ taranıyor…', 'Scanning the network…', 'جارٍ فحص الشبكة…'),
  'nas.scan_none': (
    'Ağda sunucu bulunamadı. Sunucu ve telefon AYNI Wi-Fi ağında mı?',
    'No server found. Are the server and the phone on the SAME Wi-Fi network?',
    'لم يُعثر على خادم. هل الخادم والهاتف على نفس شبكة Wi-Fi؟',
  ),
  'nas.scan_found': ('{n} sunucu bulundu', '{n} servers found', 'تم العثور على {n} خادم'),
  'nas.protocol': ('Protokol', 'Protocol', 'البروتوكول'),
  'nas.name': ('Ad', 'Name', 'الاسم'),
  'nas.name_hint': ('Ev NAS', 'Home NAS', 'NAS المنزل'),
  'nas.host': ('Sunucu adresi', 'Server address', 'عنوان الخادم'),
  'nas.host_hint': ('192.168.1.10', '192.168.1.10', '192.168.1.10'),
  'nas.webdav_host_hint': (
    'https://sunucu/dav',
    'https://server/dav',
    'https://server/dav',
  ),
  'nas.port': ('Port', 'Port', 'المنفذ'),
  'nas.user': ('Kullanıcı adı', 'Username', 'اسم المستخدم'),
  'nas.password': ('Parola', 'Password', 'كلمة المرور'),
  'nas.domain': ('Etki alanı / çalışma grubu', 'Domain / workgroup', 'النطاق / مجموعة العمل'),
  'nas.initial_path': ('Başlangıç klasörü', 'Starting folder', 'المجلد الابتدائي'),
  'nas.save_password': ('Parolayı kaydet', 'Save password', 'حفظ كلمة المرور'),
  'nas.save_password_note': (
    'Parola cihazda DÜZ METİN saklanır. Kapatırsanız her bağlanışta sorulur.',
    'The password is stored on the device in PLAIN TEXT. If you turn this off, '
        'it is asked each time you connect.',
    'تُحفظ كلمة المرور على الجهاز كنص عادي. إذا أوقفت هذا الخيار، سيتم سؤالك '
        'عند كل اتصال.',
  ),
  'nas.password_prompt': (
    '“{name}” için parola',
    'Password for “{name}”',
    'كلمة مرور «{name}»',
  ),
  'nas.test': ('Bağlantıyı sına', 'Test connection', 'اختبار الاتصال'),
  'nas.test_ok': ('Bağlantı başarılı.', 'Connection succeeded.', 'نجح الاتصال.'),
  'nas.connecting': ('Bağlanılıyor…', 'Connecting…', 'جارٍ الاتصال…'),
  'nas.delete_confirm': (
    '“{name}” bağlantısı silinsin mi? (Sunucudaki dosyalara dokunulmaz.)',
    'Delete the connection “{name}”? (Files on the server are untouched.)',
    'هل تريد حذف الاتصال «{name}»؟ (لن تُمس الملفات على الخادم.)',
  ),
  'nas.upload_here': ('Buraya yükle', 'Upload here', 'ارفع هنا'),
  'nas.uploading': ('Yükleniyor…', 'Uploading…', 'جارٍ الرفع…'),
  'nas.upload_done': ('Yüklendi.', 'Uploaded.', 'تم الرفع.'),
  'nas.downloading': ('İndiriliyor…', 'Downloading…', 'جارٍ التنزيل…'),
  'nas.new_folder': ('Yeni klasör', 'New folder', 'مجلد جديد'),
  'nas.folder_name': ('Klasör adı', 'Folder name', 'اسم المجلد'),
};
