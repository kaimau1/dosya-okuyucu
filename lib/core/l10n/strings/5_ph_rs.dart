part of '../app_strings.dart';

/// Çeviri tablosunun 5. bölümü (çoğunlukla `ph`, `rs` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t5 = {
  'pt.continue': ('Devam et', 'Continue', 'متابعة'),
  'pt.extracting': ('Sayfalar çıkarılıyor…', 'Extracting pages…', 'جارٍ استخراج الصفحات…'),
  'pt.extracted': (
    'Seçili sayfalar ayrı PDF olarak çıkarıldı',
    'The selected pages were extracted as a separate PDF',
    'تم استخراج الصفحات المحددة كملف PDF منفصل',
  ),
  'pt.extract_failed': (
    'Çıkarma başarısız: {error}',
    'Extraction failed: {error}',
    'فشل الاستخراج: {error}',
  ),
  'pt.merged': ('{n} PDF eklendi', '{n} PDFs added', 'تمت إضافة {n} ملف PDF'),
  'pt.compress_title': ('Belgeyi sıkıştır', 'Compress the document', 'ضغط المستند'),
  'pt.compress_body': (
    'Belge ({size}) baştan yazılarak küçültülecek: veri akışları en yüksek '
        'oranda sıkıştırılır, eski sürüm artıkları atılır. Görüntü kalitesi '
        'DEĞİŞMEZ.\n\n'
        'Bu yüzden taranmış (resim ağırlıklı) belgelerde kazanç küçük olur. '
        'İşlem büyük belgelerde bir dakikayı bulabilir; arka planda çalışır, '
        'ilerlemeyi görürsünüz.',
    'The document ({size}) is rewritten to make it smaller: data streams are '
        'compressed as hard as possible and leftovers from older revisions are '
        'dropped. Image quality does NOT change.\n\n'
        'That is why the gain is small on scanned (image-heavy) documents. On '
        'large documents this can take a minute; it runs in the background and '
        'you can watch the progress.',
    'يُعاد كتابة المستند ({size}) لتصغيره: تُضغط تدفقات البيانات إلى أقصى حد '
        'وتُحذف بقايا المراجعات القديمة. جودة الصورة لا تتغيّر.\n\n'
        'لذلك يكون المكسب صغيرًا في المستندات الممسوحة ضوئيًا (كثيفة الصور). قد '
        'تستغرق العملية دقيقة في المستندات الكبيرة؛ تعمل في الخلفية ويمكنك '
        'متابعة التقدّم.',
  ),
  'pt.compress': ('Sıkıştır', 'Compress', 'ضغط'),
  'pt.size_change': (
    'Boyut {before} → {after}',
    'Size {before} → {after}',
    'الحجم {before} ← {after}',
  ),
  'pt.already_compact': (
    'Bu belge zaten sıkışık ({size}) — kazanç yok',
    'This document is already compact ({size}) — nothing to gain',
    'هذا المستند مضغوط بالفعل ({size}) — لا مكسب',
  ),
  'pt.set_password': ('Parola koy', 'Set a password', 'تعيين كلمة مرور'),
  'pt.new_password': ('Yeni parola', 'New password', 'كلمة المرور الجديدة'),
  'pt.remove_password': ('Parolayı kaldır', 'Remove the password', 'إزالة كلمة المرور'),
  'pt.unsaved_title': (
    'Kaydedilmemiş değişiklik',
    'Unsaved changes',
    'تغييرات غير محفوظة',
  ),
  'pt.unsaved_body': (
    'Çıkarsanız yaptığınız düzenlemeler kaybolur.',
    'If you leave, your edits are lost.',
    'إن خرجت ستفقد تعديلاتك.',
  ),
  'pt.stay': ('Kal', 'Stay', 'البقاء'),
  'pt.leave': ('Çık', 'Leave', 'الخروج'),
  'pt.scan_append': ('Sayfa tara ve ekle', 'Scan and append a page', 'امسح صفحة وأضفها'),
  'pt.merge_other': (
    'Başka PDF ekle (birleştir)',
    'Add another PDF (merge)',
    'أضف ملف PDF آخر (دمج)',
  ),
  'pt.compress_menu': (
    'Sıkıştır (boyut küçült)',
    'Compress (reduce size)',
    'ضغط (تصغير الحجم)',
  ),
  'pt.open_failed': ('Açılamadı: {error}', 'Could not open: {error}', 'تعذّر الفتح: {error}'),
  'pt.rotate_all': ('Tümünü döndür', 'Rotate all', 'تدوير الكل'),
  'pt.extract': ('Çıkar', 'Extract', 'استخراج'),
  'pt.forward': ('Öne', 'Forward', 'للأمام'),
  'pt.backward': ('Arkaya', 'Backward', 'للخلف'),

  // ── Fotoğraflar ───────────────────────────────────────────────────────────
  'ph.loading': ('Dosyalar yükleniyor…', 'Loading files…', 'جارٍ تحميل الملفات…'),
  'ph.empty': (
    'Burada gösterilecek dosya yok.',
    'There are no files to show here.',
    'لا توجد ملفات لعرضها هنا.',
  ),
  'ph.no_match': (
    'Aramanıza/filtrenize uyan dosya yok.',
    'No file matches your search/filter.',
    'لا يوجد ملف يطابق بحثك/عامل التصفية.',
  ),
  'ph.verifying': (
    'Kopyalar bayt bayt doğrulanıyor…',
    'Verifying the copies byte by byte…',
    'جارٍ التحقق من النسخ بايتًا ببايت…',
  ),
  'ph.not_identical': (
    'Bayt bayt doğrulamada birebir kopya çıkmadı — hiçbir şey silinmedi.',
    'Byte-by-byte verification found no exact copies — nothing was deleted.',
    'لم يجد التحقق بايتًا ببايت نسخًا متطابقة — لم يُحذف شيء.',
  ),
  'ph.show': ('Göster', 'Show', 'عرض'),
  'ph.search_in': ('{title} içinde ara', 'Search in {title}', 'ابحث في {title}'),
  'ph.search_in_hint': ('{title} içinde ara…', 'Search in {title}…', 'ابحث في {title}…'),
  'ph.find_similar': (
    'Benzer görüntüleri bul (yeniden sıkıştırılmış kopyalar)',
    'Find similar images (re-compressed copies)',
    'ابحث عن صور متشابهة (نسخ أُعيد ضغطها)',
  ),
  'ph.layout': ('Görünüm: {name}', 'Layout: {name}', 'العرض: {name}'),
  'ph.selected_of': (
    '{n} / {total} seçildi',
    '{n} / {total} selected',
    'تم تحديد {n} / {total}',
  ),
  'ph.select_above': ('Üstündekileri de seç', 'Also select above', 'حدّد ما فوقه أيضًا'),
  'ph.select_below': ('Altındakileri de seç', 'Also select below', 'حدّد ما تحته أيضًا'),
  'ph.clear_selection': ('Seçimi kaldır', 'Clear selection', 'إلغاء التحديد'),
  'ph.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'ph.all_count': ('Tümü ({n})', 'All ({n})', 'الكل ({n})'),
  'ph.chip_count': ('{label} ({n})', '{label} ({n})', '{label} ({n})'),
  'ph.cat_empty': (
    'Bu kategoride dosya bulunamadı.',
    'No files found in this category.',
    'لم يُعثر على ملفات في هذه الفئة.',
  ),
  'ph.group_deselect': ('Grubun seçimini kaldır', 'Deselect group', 'إلغاء تحديد المجموعة'),
  'ph.group_select': ('Grubu seç', 'Select group', 'تحديد المجموعة'),

  'ph.delete_dupes_title': (
    'Kopyalar silinsin mi?',
    'Delete the copies?',
    'هل تريد حذف النسخ؟',
  ),
  'ph.delete_dupes_body': (
    '{n} fazladan kopya ({size}) {fate}. Her gruptan en eski dosya korunur.',
    '{n} extra copies ({size}) {fate}. The oldest file in each group is kept.',
    '{n} نسخة زائدة ({size}) {fate}. يُحتفظ بأقدم ملف في كل مجموعة.',
  ),
  'ph.fate_trash': (
    'çöp kutusuna taşınacak',
    'will be moved to the trash',
    'ستُنقل إلى سلة المهملات',
  ),
  'ph.fate_permanent': (
    'KALICI olarak silinecek (çöp kutusu ayarlardan kapalı)',
    'will be deleted PERMANENTLY (the trash is turned off in settings)',
    'ستُحذف نهائيًا (سلة المهملات مُعطّلة في الإعدادات)',
  ),
  'ph.hidden_dupes': (
    '{n} yinelenen kopya gizlendi',
    '{n} duplicate copies hidden',
    'تم إخفاء {n} نسخة مكررة',
  ),
  // Süzgeç şeridindeki pilin ÜSTÜNDE yazan kısa biçim; uzun biçim
  // (`ph.hidden_dupes`) pilin ipucunda ve menü başlığında durur. Şerit tek
  // satır ve yatay kaydırmalı — uzun metin sağdaki kaynak çiplerini ekran
  // dışına itiyordu (2026-08-09).
  'ph.hidden_dupes_short': (
    '{n} kopya gizli',
    '{n} duplicates hidden',
    '{n} نسخة مخفية',
  ),
  'ph.clean': ('Temizle', 'Clean up', 'تنظيف'),
  'ph.similar_title': ('Benzer: {title}', 'Similar: {title}', 'مشابه: {title}'),
  // 2026-09-26 galeri turu.
  'ph.similar_short': ('Benzerleri bul', 'Find similar', 'ابحث عن المتشابه'),
  'ph.sorted_header': ('{n} dosya · {sort}', '{n} files · {sort}', '{n} ملف · {sort}'),
  'ph.view': ('Görünüm', 'View', 'العرض'),
  'ph.view_scale': ('Zaman ölçeği', 'Time scale', 'المقياس الزمني'),
  'ph.view_columns': ('Sütun sayısı', 'Columns', 'عدد الأعمدة'),
  'ph.pinch_hint': (
    'İpucu: ızgarada iki parmakla sıkıştırarak uzaklaştır, açarak yakınlaştır.',
    'Tip: pinch the grid with two fingers to zoom out, spread to zoom in.',
    'تلميح: اقرص الشبكة بإصبعين للتصغير، وباعدهما للتكبير.',
  ),
  'ph.empty_hint': (
    'Yeni fotoğraf ve videolar çekildikçe burada görünür.',
    'New photos and videos appear here as they are taken.',
    'تظهر الصور ومقاطع الفيديو الجديدة هنا فور التقاطها.',
  ),
  'ph.no_match_hint': (
    'Süzgeçleri temizlemeyi dene.',
    'Try clearing the filters.',
    'جرّب مسح عوامل التصفية.',
  ),
  'ph.clear_filters': ('Süzgeçleri temizle', 'Clear filters', 'مسح عوامل التصفية'),
  'ph.fast_scroll': ('Hızlı kaydırma tutamacı', 'Fast scroll handle', 'مقبض التمرير السريع'),

  // ── AI sohbeti ────────────────────────────────────────────────────────────
  'chat.export_short': ('Aktar', 'Export', 'تصدير'),
  'chat.export_slides': ('Sunum (PDF)', 'Presentation (PDF)', 'عرض تقديمي (PDF)'),
  'chat.title': ('AI Sohbet', 'AI Chat', 'محادثة الذكاء الاصطناعي'),
  'chat.answer_title': ('AI Yanıtı', 'AI answer', 'إجابة الذكاء الاصطناعي'),
  'chat.deck_title': ('AI Sunumu', 'AI presentation', 'عرض الذكاء الاصطناعي'),
  'chat.key_required': ('API anahtarı gerekli', 'API key required', 'مفتاح API مطلوب'),
  'chat.key_required_body': (
    'AI özelliklerini kullanmak için Gemini API anahtarınızı girin.',
    'Enter your Gemini API key to use the AI features.',
    'أدخل مفتاح Gemini API لاستخدام ميزات الذكاء الاصطناعي.',
  ),
  'chat.saved_to_memory': (
    'Kalıcı hafızaya kaydedildi',
    'Saved to permanent memory',
    'تم الحفظ في الذاكرة الدائمة',
  ),
  'chat.export_failed': (
    'Dışa aktarılamadı: {error}',
    'Export failed: {error}',
    'فشل التصدير: {error}',
  ),
  'chat.copied': ('Panoya kopyalandı', 'Copied to the clipboard', 'تم النسخ إلى الحافظة'),
  'chat.context': ('Bağlam: {name}', 'Context: {name}', 'السياق: {name}'),
  'chat.quick_summarize': ('Özetle', 'Summarise', 'لخّص'),
  'chat.quick_summarize_prompt': (
    'Bu dosyayı kısa ve öz biçimde özetle.',
    'Summarise this file briefly and concisely.',
    'لخّص هذا الملف بإيجاز ووضوح.',
  ),
  'chat.quick_points': ('Ana noktalar', 'Key points', 'النقاط الرئيسية'),
  'chat.quick_points_prompt': (
    'Bu dosyanın ana noktalarını madde madde çıkar.',
    'List the key points of this file as bullet points.',
    'استخرج النقاط الرئيسية لهذا الملف على شكل نقاط.',
  ),
  'chat.quick_simple': ('Basit anlat', 'Explain simply', 'اشرح ببساطة'),
  'chat.quick_simple_prompt': (
    'Bu dosyayı sade, teknik olmayan bir dille açıkla.',
    'Explain this file in plain, non-technical language.',
    'اشرح هذا الملف بلغة بسيطة وغير تقنية.',
  ),
  'chat.empty_file': (
    'Bu dosya hakkında soru sor ya da aşağıdan hızlı bir komut seç. '
        'Yanıtları kalıcı hafızaya kaydedebilirsin.',
    'Ask a question about this file or pick a quick command below. You can '
        'save the answers to permanent memory.',
    'اطرح سؤالًا عن هذا الملف أو اختر أمرًا سريعًا بالأسفل. يمكنك حفظ الإجابات '
        'في الذاكرة الدائمة.',
  ),
  'chat.empty_general': (
    'Dosyalarını özetlet, sorular sor, düzenleme öner, PDF’den slayt planı '
        'çıkart. Yanıtları kalıcı hafızaya kaydedebilirsin.',
    'Have your files summarised, ask questions, get editing suggestions, or '
        'draft a slide outline from a PDF. You can save the answers to '
        'permanent memory.',
    'لخّص ملفاتك، واطرح الأسئلة، واحصل على اقتراحات تحرير، أو استخرج مخطط '
        'شرائح من ملف PDF. يمكنك حفظ الإجابات في الذاكرة الدائمة.',
  ),
  'chat.export': ('Dışa aktar', 'Export', 'تصدير'),
  'chat.save_to_memory': ('Hafızaya kaydet', 'Save to memory', 'حفظ في الذاكرة'),
  'chat.ask_hint': ('Bir şey sor…', 'Ask something…', 'اسأل شيئًا…'),

  // ── PDF formu doldurma ────────────────────────────────────────────────────
  'pf.title': ('Formu doldur — {name}', 'Fill form — {name}', 'تعبئة النموذج — {name}'),
  'pf.save': ('Doldur ve kaydet', 'Fill and save', 'تعبئة وحفظ'),
  'pf.page': ('Sayfa {n}', 'Page {n}', 'الصفحة {n}'),
  'pf.other_fields': ('Diğer alanlar', 'Other fields', 'حقول أخرى'),
  'pf.read_only': ('salt okunur', 'read-only', 'للقراءة فقط'),
  'pf.flatten': (
    'Doldurduktan sonra kilitle',
    'Lock after filling',
    'قفل بعد التعبئة',
  ),
  'pf.flatten_sub': (
    'Alanlar sayfaya işlenir; karşı taraf değiştiremez. Geri alınamaz.',
    'Values are drawn onto the page; nobody can change them afterwards. This '
        'cannot be undone.',
    'تُطبع القيم على الصفحة ولا يمكن تغييرها لاحقًا. لا يمكن التراجع.',
  ),
  'pf.note': ('Form dolduruldu', 'Form filled', 'تم ملء النموذج'),
  'pf.note_flat': (
    'Form dolduruldu ve kilitlendi',
    'Form filled and locked',
    'تم ملء النموذج وقفله',
  ),
  'pf.no_fields': (
    'Bu PDF doldurulabilir form alanı taşımıyor.',
    'This PDF has no fillable form fields.',
    'لا يحتوي هذا الملف على حقول قابلة للتعبئة.',
  ),
  'pf.no_fields_hint': (
    'Yazı yazmak için PDF düzenleyicideki metin aracını, imza için '
        '⋮ → İmzala\'yı kullanabilirsiniz.',
    'To add text use the text tool in the PDF editor; to sign use ⋮ → Sign.',
    'لإضافة نص استخدم أداة النص في محرر PDF، وللتوقيع استخدم ⋮ ← توقيع.',
  ),
  'pf.failed': ('Form doldurulamadı: {error}', 'Could not fill the form: {error}',
      'تعذّرت تعبئة النموذج: {error}'),

  // ── Boyut düşürme ─────────────────────────────────────────────────────────
  'rs.title': (
    'Boyut düşür ({n} dosya)',
    'Reduce size ({n} files)',
    'تصغير الحجم ({n} ملف)',
  ),
  'rs.now': ('Şu an', 'Now', 'الآن'),
  'rs.after': ('Sonra', 'After', 'بعد'),
  'rs.fps_value': ('{n} fps', '{n} fps', '{n} إطار/ث'),
  'rs.bitrate': ('{n} Mbps', '{n} Mbps', '{n} ميغابت/ث'),
  'rs.no_audio': ('sessiz', 'muted', 'بلا صوت'),
  'rs.estimate': (
    'Tahmini: {before} → ≈ {after}',
    'Estimated: {before} → ≈ {after}',
    'المتوقع: {before} → ≈ {after}',
  ),
  'rs.estimate_gain': ('≈ %{n} kazanç', '≈ {n}% saved', '≈ توفير {n}%'),
  'rs.estimate_note': (
    'Gerçek boyut içeriğe göre değişir; kesin sonuç işlem bitince görünür.',
    'The real size depends on the content; the exact result appears when the '
        'job finishes.',
    'يعتمد الحجم الفعلي على المحتوى؛ تظهر النتيجة الدقيقة عند انتهاء العملية.',
  ),
  'rs.and_more': (
    've {n} dosya daha · toplam {size}',
    'and {n} more files · {size} total',
    'و{n} ملفات أخرى · الإجمالي {size}',
  ),
  'rs.no_change_warning': (
    'Bu ayarlar bu dosyayı küçültmüyor: çözünürlük ve kare sayısı aynı kalıyor. '
    'Daha düşük bir çözünürlük ya da kare sayısı seçin.',
    'These settings do not shrink this file: resolution and frame rate stay the '
    'same. Pick a lower resolution or frame rate.',
    'هذه الإعدادات لا تصغّر هذا الملف: الدقة ومعدل الإطارات كما هما. اختر دقة أو '
    'معدل إطارات أقل.',
  ),
  'rs.resolution': ('Çözünürlük', 'Resolution', 'الدقة'),
  'rs.width': ('Genişlik (px)', 'Width (px)', 'العرض (بكسل)'),
  'rs.height': ('Yükseklik (px)', 'Height (px)', 'الارتفاع (بكسل)'),
  'rs.custom_note': (
    'Yalnız birini yazarsan diğeri en/boy oranından hesaplanır ve resim '
        'bozulmaz. İKİSİNİ de yazarsan verdiğin ölçü aynen uygulanır — oran '
        'tutmuyorsa görüntü gerilir. Kaynaktan büyütme yapılmaz: kaynaktan '
        'büyük bir değer yazarsan kaynağın ölçüsünde kalır.',
    'If you fill in only one, the other is derived from the aspect ratio and '
        'the image is not distorted. If you fill in BOTH, your exact numbers '
        'are used — if the ratio does not match, the image is stretched. '
        'Nothing is upscaled: a value larger than the source keeps the source '
        'size.',
    'إذا ملأت واحدًا فقط فسيُحسب الآخر من نسبة الأبعاد ولن تتشوّه الصورة. وإذا '
        'ملأت الاثنين فستُطبَّق قياساتك حرفيًا — وإن لم تتطابق النسبة فستُمطّ '
        'الصورة. لا يجري أي تكبير: القيمة الأكبر من المصدر تُبقي حجم المصدر.',
  ),
  'rs.jpeg_quality': ('JPEG kalitesi (fotoğraf)', 'JPEG quality (photos)', 'جودة JPEG (الصور)'),
  'rs.format': ('Biçim (fotoğraf)', 'Format (photos)', 'الصيغة (الصور)'),
  'rs.video_quality': ('Video sıkıştırma', 'Video compression', 'ضغط الفيديو'),
  'rs.fps': ('Kare sayısı (fps)', 'Frame rate (fps)', 'معدّل الإطارات (fps)'),
  'rs.keep': ('Değiştirme', 'Keep as is', 'دون تغيير'),
  'rs.video_note': (
    'Video her durumda yeniden kodlanır (kalite ya da ses değişse de): '
        'istediğin ölçüye birebir dönüştürülür (FFmpeg). Öncelik cihazın '
        'donanım kodlayıcısında; o kullanılamazsa yazılım kodlayıcıya düşülür '
        've işlem belirgin biçimde yavaşlar. Hangi motorun çalıştığı, yüzde ve '
        'kalan süre işlem satırında yazar. Uzun bir videoda bu dakikalar '
        'sürebilir; işlem arka planda koşar. Cihaz bu videoyu hiç çeviremezse '
        'yedek motora düşülür: orada kare sayısı seçimi uygulanamaz ve '
        '“Değiştirme” dışındaki çözünürlükler en yakın kademeye yuvarlanır.',
    'Video is always re-encoded (even if only the quality or audio changes): '
        'it is converted exactly to the size you asked for (FFmpeg). The '
        'device’s hardware encoder is preferred; if it is unavailable the '
        'software encoder is used and the job gets noticeably slower. Which '
        'engine is running, the percentage and the remaining time are shown on '
        'the job row. On a long video this can take minutes; the job runs in '
        'the background. If the device cannot convert the video at all, a '
        'fallback engine is used: there the frame-rate choice cannot be '
        'applied and resolutions other than “Keep as is” are rounded to the '
        'nearest step.',
    'يُعاد ترميز الفيديو دائمًا (حتى لو تغيّرت الجودة أو الصوت فقط): يُحوَّل '
        'تمامًا إلى المقاس المطلوب (FFmpeg). تُفضَّل وحدة الترميز العتادية في '
        'الجهاز؛ وإن لم تتوفر يُستخدم المرمّز البرمجي وتصبح العملية أبطأ بوضوح. '
        'يظهر المحرّك العامل والنسبة والوقت المتبقي في سطر العملية. قد يستغرق '
        'ذلك دقائق في فيديو طويل؛ وتعمل العملية في الخلفية. وإن تعذّر على '
        'الجهاز تحويل الفيديو إطلاقًا يُستخدم محرّك احتياطي: هناك لا يمكن تطبيق '
        'اختيار معدّل الإطارات وتُقرَّب الدقات غير «دون تغيير» إلى أقرب درجة.',
  ),
  'rs.strip_audio': ('Sesi çıkar', 'Remove the audio', 'إزالة الصوت'),
  'rs.strip_audio_sub': (
    'Ses kaydı olmayan videolarda belirgin yer kazandırır.',
    'Saves noticeable space on videos where the audio is not needed.',
    'يوفّر مساحة ملحوظة في الفيديوهات التي لا يُحتاج فيها الصوت.',
  ),
  'rs.trash_original': (
    'Özgün dosyayı çöp kutusuna at',
    'Move the original to the trash',
    'نقل الملف الأصلي إلى سلة المهملات',
  ),
  'rs.trash_original_sub': (
    'Kapalıyken küçültülmüş kopya aynı klasöre yeni bir dosya olarak yazılır, '
        'aslına dokunulmaz.',
    'When off, the smaller copy is written to the same folder as a new file '
        'and the original is untouched.',
    'عند الإيقاف تُكتب النسخة المصغّرة في المجلد نفسه كملف جديد ولا يُمس الأصل.',
  ),
  'rs.queue_note': (
    'İşlem arka planda kuyrukta çalışır; başka ekranlara geçebilirsin. '
        'Uygulamayı tamamen kapatırsan durur. Küçültülen dosya özgün dosyanın '
        'yanına kaydedilir; sonucu ve oluşan dosyaları ana ekrandaki '
        '“İşlemler” kutusundan açabilirsin.',
    'The job runs in a background queue; you can move to other screens. It '
        'stops if you close the app completely. The smaller file is saved next '
        'to the original; you can open the result and the created files from '
        'the “Jobs” box on the home screen.',
    'تعمل العملية في طابور بالخلفية؛ يمكنك الانتقال إلى شاشات أخرى. وتتوقف إن '
        'أغلقت التطبيق تمامًا. يُحفظ الملف المصغّر بجوار الأصل؛ ويمكنك فتح '
        'النتيجة والملفات الناتجة من صندوق «العمليات» في الشاشة الرئيسية.',
  ),
  'rs.start': ('Başlat', 'Start', 'ابدأ'),

  // ── PDF'i AI ile düzenle ──────────────────────────────────────────────────
  'pa.preset_grammar': (
    'Yazım/dil bilgisi düzelt',
    'Fix spelling/grammar',
    'صحّح الإملاء/النحو',
  ),
  'pa.preset_grammar_prompt': (
    'Metindeki yazım ve dil bilgisi hatalarını düzelt. Anlamı ve üslubu '
        'değiştirme, cümleleri yeniden kurma.',
    'Fix the spelling and grammar mistakes in the text. Do not change the '
        'meaning or the style, and do not rewrite the sentences.',
    'صحّح الأخطاء الإملائية والنحوية في النص. لا تغيّر المعنى أو الأسلوب ولا '
        'تُعِد صياغة الجمل.',
  ),
  'pa.preset_simplify': ('Sadeleştir', 'Simplify', 'بسّط'),
  'pa.preset_simplify_prompt': (
    'Metni daha kısa ve anlaşılır hâle getir. Bilgi kaybetme, gereksiz '
        'tekrarları ve dolgu ifadeleri at.',
    'Make the text shorter and clearer. Do not lose information; drop needless '
        'repetition and filler.',
    'اجعل النص أقصر وأوضح. لا تفقد أي معلومة؛ واحذف التكرار الزائد والحشو.',
  ),
  'pa.preset_summary': ('Özetle', 'Summarise', 'لخّص'),
  'pa.preset_summary_prompt': (
    'Metni ana başlıklar ve maddeler hâlinde özetle.',
    'Summarise the text as headings and bullet points.',
    'لخّص النص على شكل عناوين ونقاط.',
  ),
  'pa.preset_formal': ('Resmî dile çevir', 'Make it formal', 'حوّله إلى لغة رسمية'),
  'pa.preset_formal_prompt': (
    'Metni resmî yazışma diline uygun hâle getir.',
    'Rewrite the text in formal correspondence style.',
    'أعِد كتابة النص بأسلوب المراسلات الرسمية.',
  ),
  'pa.need_key': (
    'Önce Ayarlar > Gemini API anahtarı bölümünden anahtarınızı girin.',
    'First enter your key under Settings > Gemini API key.',
    'أدخل مفتاحك أولًا من الإعدادات > مفتاح Gemini API.',
  ),
  'pa.need_task': (
    'Ne yapılmasını istediğinizi yazın ya da seçin.',
    'Type or pick what you want done.',
    'اكتب أو اختر ما تريد إنجازه.',
  ),
  'pa.prompt': (
    'Aşağıdaki belgenin metnini şu yönergeye göre yeniden yaz:\n"{task}"\n\n'
        'ÇOK ÖNEMLİ: yalnızca düzenlenmiş metni döndür. Açıklama, giriş '
        'cümlesi, "işte metin" gibi ifadeler ve kod bloğu işaretleri EKLEME.',
    'Rewrite the text of the document below according to this instruction:\n'
        '"{task}"\n\nVERY IMPORTANT: return only the edited text. Do NOT add '
        'explanations, an introductory sentence, phrases like "here is the '
        'text", or code-block markers.',
    'أعِد كتابة نص المستند أدناه وفق هذه التعليمات:\n"{task}"\n\n'
        'مهم جدًا: أعِد النص المحرَّر فقط. لا تُضِف شروحًا أو جملة تمهيدية أو '
        'عبارات مثل «إليك النص» أو علامات كتل الشيفرة.',
  ),
  'pa.save_note': (
    'Yeni PDF düz metinden üretilir: özgün belgenin sayfa düzeni '
        '(sütun, tablo, logo, imza) KORUNMAZ.',
    'The new PDF is produced from plain text: the original document’s layout '
        '(columns, tables, logos, signatures) is NOT preserved.',
    'يُنتَج ملف PDF الجديد من نص عادي: لا يُحافَظ على تخطيط المستند الأصلي '
        '(الأعمدة والجداول والشعارات والتواقيع).',
  ),
  'pa.save_pdf': ('PDF olarak kaydet', 'Save as PDF', 'حفظ بصيغة PDF'),
  'pa.no_text': (
    'Bu belgede okunabilir metin yok (taranmış olabilir).\n'
        'Önce ⋮ menüsünden “Metni tanı (OCR)” çalıştırın.',
    'This document has no readable text (it may be scanned).\n'
        'Run “Recognize text (OCR)” from the ⋮ menu first.',
    'لا يحتوي هذا المستند على نص قابل للقراءة (قد يكون ممسوحًا ضوئيًا).\n'
        'شغّل «التعرّف على النص (OCR)» من قائمة ⋮ أولًا.',
  ),
  'pa.what': ('Ne yapılsın?', 'What should be done?', 'ما الذي تريد فعله؟'),
  'pa.hint': (
    'Örn. “Başlıkları numaralandır ve maddeleri kısalt”',
    'E.g. “Number the headings and shorten the bullet points”',
    'مثال: «رقّم العناوين واختصر النقاط»',
  ),
  'pa.working': ('Çalışıyor…', 'Working…', 'جارٍ العمل…'),
  'pa.result': ('Sonuç', 'Result', 'النتيجة'),
  'pa.editable': ('elle düzenlenebilir', 'you can edit it by hand', 'يمكنك تحريره يدويًا'),
  'pa.result_hint': (
    'AI çıktısı burada görünecek…',
    'The AI output will appear here…',
    'سيظهر ناتج الذكاء الاصطناعي هنا…',
  ),
  'pa.footer': (
    'Kaydederken üretilen PDF düz metindir: özgün sayfa düzeni '
        '(sütun, tablo, logo) korunmaz. Özgün belgeyi bozmamak için '
        '“Kopyasını kaydet”i seçin.',
    'The PDF produced on save is plain text: the original layout (columns, '
        'tables, logos) is not preserved. Choose “Save a copy” to keep the '
        'original document intact.',
    'ملف PDF المنتَج عند الحفظ نص عادي: لا يُحافَظ على التخطيط الأصلي (الأعمدة '
        'والجداول والشعارات). اختر «حفظ نسخة» للإبقاء على المستند الأصلي كما هو.',
  ),

  // ── PDF kaydetme penceresi ────────────────────────────────────────────────
  'ps.open': ('AÇ', 'OPEN', 'فتح'),
  'ps.saved_as': ('Kaydedildi: {name}', 'Saved: {name}', 'تم الحفظ: {name}'),
  'ps.title': ('Nasıl kaydedilsin?', 'How should we save it?', 'كيف نحفظه؟'),
  'ps.overwrite': ('Üzerine yaz', 'Overwrite', 'الكتابة فوقه'),
  'ps.overwrite_sub': (
    '{name} değişir — geri alınamaz',
    '{name} changes — this cannot be undone',
    'سيتغيّر {name} — لا يمكن التراجع',
  ),
  'ps.copy': ('Kopyasını kaydet', 'Save a copy', 'حفظ نسخة'),
  'ps.copy_sub': (
    'Aynı klasöre “… (kopya).pdf” olarak',
    'Into the same folder as “… (copy).pdf”',
    'في المجلد نفسه باسم «… (نسخة).pdf»',
  ),
  'ps.pick_folder': ('Klasör seçerek kaydet…', 'Save to a chosen folder…', 'حفظ في مجلد مختار…'),
  'ps.pick_folder_sub': (
    'Nereye gideceğine siz karar verin',
    'You decide where it goes',
    'أنت تقرّر أين يذهب',
  ),

  // ── PDF yerinde metin düzenleme akışı ─────────────────────────────────────
  'pf.replaced_reflow': (
    'Değiştirildi — satırın kalanı yeniden hizalandı.',
    'Replaced — the rest of the line was re-aligned.',
    'تم الاستبدال — أُعيدت محاذاة بقية السطر.',
  ),
  'pf.replaced': ('Değiştirildi.', 'Replaced.', 'تم الاستبدال.'),

  // ── Benzer görüntüler ─────────────────────────────────────────────────────
  'sim.title': ('Benzer görüntüler', 'Similar images', 'صور متشابهة'),
  'sim.scanning_title': (
    'Benzer görüntüler aranıyor ({level})',
    'Searching for similar images ({level})',
    'جارٍ البحث عن صور متشابهة ({level})',
  ),
  'sim.scanning_name': (
    'Benzer görüntü araması ({level})',
    'Similar image search ({level})',
    'البحث عن صور متشابهة ({level})',
  ),
  'sim.preparing_list': (
    'Dosya listesi hazırlanıyor…',
    'Preparing the file list…',
    'جارٍ تحضير قائمة الملفات…',
  ),
  'sim.need_key': (
    'Gemini için Ayarlar > API anahtarı gerekiyor. Cihaz-içi benzerlik '
        'taraması anahtarsız çalışır.',
    'Gemini needs an API key under Settings. The on-device similarity scan '
        'works without a key.',
    'يحتاج Gemini إلى مفتاح API من الإعدادات. أما فحص التشابه على الجهاز فيعمل '
        'دون مفتاح.',
  ),
  'sim.sending': (
    'Görseller küçültülüp Gemini’ye gönderiliyor…',
    'Shrinking the images and sending them to Gemini…',
    'جارٍ تصغير الصور وإرسالها إلى Gemini…',
  ),
  'sim.too_few_previews': (
    'Karşılaştırma için en az iki önizleme üretilemedi '
        '(dosyalar okunamıyor olabilir).',
    'Could not produce at least two previews to compare (the files may be '
        'unreadable).',
    'تعذّر إنتاج معاينتين على الأقل للمقارنة (قد تكون الملفات غير قابلة للقراءة).',
  ),
  'sim.gemini_opinion': ('Gemini’nin görüşü', 'Gemini’s opinion', 'رأي Gemini'),
  'sim.recoverable': ('{size} kazanılabilir', '{size} can be freed', 'يمكن تحرير {size}'),
  'sim.groups_summary': (
    '{n} benzer grup · {size} kazanılabilir',
    '{n} similar groups · {size} can be freed',
    '{n} مجموعة متشابهة · يمكن تحرير {size}',
  ),
  'sim.group_summary': (
    '{n} benzer · {size} kazanılabilir',
    '{n} similar · {size} can be freed',
    '{n} متشابهة · يمكن تحرير {size}',
  ),
  'sim.select_extras': ('Fazlaları seç', 'Select the extras', 'حدّد الزائدة'),
  'sim.scan_failed': (
    'Tarama başarısız: {error}',
    'Scan failed: {error}',
    'فشل الفحص: {error}',
  ),
  'sim.none': (
    'Benzer görüntü bulunamadı 🎉',
    'No similar images found 🎉',
    'لم يُعثر على صور متشابهة 🎉',
  ),
  'sim.n_files': ('{n} dosyayı', '{n} files', '{n} ملف'),
  'sim.scanning': ('Taranıyor…', 'Scanning…', 'جارٍ الفحص…'),
  'sim.background_note': (
    'Ekranı kapatabilirsin — tarama arka planda sürer, geri döndüğünde sonuç '
        'hazır olur.',
    'You can close this screen — the scan continues in the background and the '
        'result is ready when you come back.',
    'يمكنك إغلاق الشاشة — يستمر الفحص في الخلفية وتكون النتيجة جاهزة عند عودتك.',
  ),

  // ── Süzgeç sayfası ────────────────────────────────────────────────────────
  'flt.pick_range': ('Tarih aralığı seç', 'Pick a date range', 'اختر نطاقًا زمنيًا'),
  'flt.title': ('Filtrele ve sırala', 'Filter and sort', 'التصفية والترتيب'),
  'flt.sort': ('Sıralama', 'Sorting', 'الترتيب'),
  'flt.source': (
    'Kaynak (birden çok seçilebilir)',
    'Source (you can pick several)',
    'المصدر (يمكن اختيار أكثر من واحد)',
  ),
  'flt.all': ('Tümü', 'All', 'الكل'),
  'flt.chat_kind': (
    'Mesajlaşma dosyası türü',
    'Messaging file type',
    'نوع ملف المراسلة',
  ),
  'flt.direction': ('Gelen / gönderilen', 'Received / sent', 'واردة / مرسلة'),
  'flt.direction_note': (
    'Gönderdiklerin WhatsApp’ın “Sent” klasöründen okunur. Telegram bu ayrımı '
        'yapmadığı için oradaki dosyalar “gelen” sayılır.',
    'Your sent files are read from WhatsApp’s “Sent” folder. Telegram does not '
        'make this distinction, so its files count as “received”.',
    'تُقرأ ملفاتك المرسلة من مجلد «Sent» في WhatsApp. أما Telegram فلا يميّز '
        'بينهما، لذا تُعدّ ملفاته «واردة».',
  ),
  'flt.tag': ('Etiket (kişi / grup)', 'Tag (person / group)', 'وسم (شخص / مجموعة)'),
  'flt.file_type': ('Dosya türü', 'File type', 'نوع الملف'),
  'flt.hide_dupes': (
    'Yinelenen kopyaları gizle',
    'Hide duplicate copies',
    'إخفاء النسخ المكررة',
  ),
  'flt.hide_dupes_sub': (
    'Aynı ad ve boyuttaki dosya bir kez görünür '
        '(WhatsApp aynı görseli birkaç klasöre yazar).',
    'A file with the same name and size is shown once (WhatsApp writes the '
        'same image into several folders).',
    'يظهر الملف ذو الاسم والحجم نفسيهما مرة واحدة (يكتب WhatsApp الصورة نفسها '
        'في عدة مجلدات).',
  ),
  'flt.desc': ('Azalan', 'Descending', 'تنازلي'),
  'flt.asc': ('Artan', 'Ascending', 'تصاعدي'),
  'flt.date': ('Tarih', 'Date', 'التاريخ'),
  'flt.size': ('Boyut', 'Size', 'الحجم'),
  'flt.active_count': ('{n} filtre etkin', '{n} filters active', '{n} عامل تصفية نشط'),

  // ── Tarama önizleme ───────────────────────────────────────────────────────
  'sr.rotate_failed': (
    'Döndürülemedi: {error}',
    'Could not rotate: {error}',
    'تعذّر التدوير: {error}',
  ),
  'sr.last_page': (
    'Son sayfa silinemez — taramayı iptal edin.',
    'You cannot delete the last page — cancel the scan instead.',
    'لا يمكن حذف الصفحة الأخيرة — ألغِ المسح بدلًا من ذلك.',
  ),
  'sr.rotate_page': ('Sayfayı çevir (90°)', 'Rotate the page (90°)', 'تدوير الصفحة (90°)'),
  'sr.delete_page': ('Bu sayfayı sil', 'Delete this page', 'حذف هذه الصفحة'),
  'sr.page_failed': ('Sayfa görüntülenemedi', 'Could not show the page', 'تعذّر عرض الصفحة'),
  'sr.crop_hint': (
    'Sayfa yamuk ya da fazla yer kaptıysa köşeleri düzeltin.',
    'If the page is skewed or takes too much room, adjust the corners.',
    'إن كانت الصفحة مائلة أو تشغل مساحة زائدة فاضبط الزوايا.',
  ),
  'sr.adjust_corners': ('Köşeleri ayarla', 'Adjust the corners', 'ضبط الزوايا'),
  // Elle düzleştirme: açılıştaki otomatik geçiş emin olmadığı sayfaya
  // dokunmuyor; eğik kaldığını gören kullanıcının düğmesi.
  'sr.straighten': ('Düzleştir', 'Straighten', 'تقويم'),
  'sr.straightened': (
    'Sayfa düzleştirildi.',
    'The page was straightened.',
    'تم تقويم الصفحة.',
  ),
  'sr.straighten_noop': (
    'Sayfa zaten düz görünüyor — değiştirilmedi.',
    'The page already looks straight — nothing changed.',
    'تبدو الصفحة مستقيمة بالفعل — لم يتغيّر شيء.',
  ),
  // Sayfaları düzenle ekranı (2026-10-17: tarama doğrudan kaydediliyor,
  // düzenleme sonuç ekranından açılıyor).
  'sr.title': ('Sayfa {n} / {total}', 'Page {n} / {total}', 'الصفحة {n} / {total}'),
  'sr.move_earlier': ('Sayfayı öne al', 'Move the page earlier', 'نقل الصفحة إلى الأمام'),
  'sr.move_later': ('Sayfayı arkaya al', 'Move the page later', 'نقل الصفحة إلى الخلف'),
  'sr.order_hint': (
    'Sırayı değiştirmek için oklara dokunun',
    'Tap the arrows to change the order',
    'اضغط على الأسهم لتغيير الترتيب',
  ),

  // ── Açılma geçmişi ────────────────────────────────────────────────────────
  'oh.title': ('Son açılanlar', 'Recently opened', 'المفتوحة مؤخرًا'),
  'oh.search': ('Son açılanlarda ara…', 'Search recently opened…', 'ابحث في المفتوحة مؤخرًا…'),
  'oh.clear': ('Geçmişi temizle', 'Clear the history', 'مسح السجل'),
  'oh.clear_title': ('Geçmiş temizlensin mi?', 'Clear the history?', 'هل تريد مسح السجل؟'),
  'oh.clear_body': (
    'Yalnız “ne zaman açıldı” kaydı silinir; dosyaların kendisi silinmez.',
    'Only the “when it was opened” record is deleted; the files themselves are not.',
    'يُحذف سجل «متى فُتح» فقط؛ أما الملفات نفسها فلا تُحذف.',
  ),
  'oh.empty': (
    'Henüz açılmış bir dosya yok.\nBir dosyayı açtığında burada görünür.',
    'No file has been opened yet.\nWhen you open one, it shows up here.',
    'لم يُفتح أي ملف بعد.\nعندما تفتح ملفًا سيظهر هنا.',
  ),
  'oh.no_match': ('“{query}” için sonuç yok.', 'No results for “{query}”.', 'لا نتائج لـ «{query}».'),
  'oh.last_opened': ('Son açılma: ', 'Last opened: ', 'آخر فتح: '),

  // ── Arama ekranı ──────────────────────────────────────────────────────────
  'srch.in_hint': ('{name} içinde ara…', 'Search in {name}…', 'ابحث في {name}…'),
  'srch.options': ('Arama seçenekleri', 'Search options', 'خيارات البحث'),
  'srch.smart_off': ('Akıllı aramayı kapat', 'Turn off smart search', 'إيقاف البحث الذكي'),
  'srch.smart_on': ('Akıllı aramayı aç', 'Turn on smart search', 'تشغيل البحث الذكي'),
  'srch.index_building': (
    'Arama dizini kuruluyor — bu ilk sefere özel, sonraki aramalar anında olacak.',
    'Building the search index — this is a one-off; later searches are instant.',
    'جارٍ إنشاء فهرس البحث — لمرة واحدة فقط؛ وستكون عمليات البحث اللاحقة فورية.',
  ),
  'srch.index_stale': (
    'Dosyalar değişti — dizin arka planda tazeleniyor.',
    'The files changed — the index is refreshing in the background.',
    'تغيّرت الملفات — يجري تحديث الفهرس في الخلفية.',
  ),
  'srch.understood': ('Anladım:', 'Understood:', 'فهمت:'),
  'srch.need_key': (
    'Önce Ayarlar > Gemini API anahtarını girin.',
    'First enter the Gemini API key under Settings.',
    'أدخل مفتاح Gemini API من الإعدادات أولًا.',
  ),
  'srch.ai_fallback': (
    'AI bu sorguyu yorumlayamadı; yerel çözümleme kullanılıyor.',
    'The AI could not interpret this query; the local parser is used instead.',
    'تعذّر على الذكاء الاصطناعي تفسير هذا الاستعلام؛ يُستخدم المحلّل المحلي.',
  ),
  'srch.ai_error': ('AI hatası: {error}', 'AI error: {error}', 'خطأ في الذكاء الاصطناعي: {error}'),
  'srch.summary': (
    '{n} sonuç · {sort} ({dir}){capped}',
    '{n} results · {sort} ({dir}){capped}',
    '{n} نتيجة · {sort} ({dir}){capped}',
  ),
  'srch.capped': (' · ilk 1000 sonuç', ' · first 1000 results', ' · أول 1000 نتيجة'),
  'srch.empty_hint': (
    'Dosya veya klasör adının bir bölümünü yazın.\n\n'
        'İpucu: “geçen ay whatsapp videoları”, “bu hafta pdf”, '
        '“2024 fotoğrafları” gibi cümleler de yazabilirsiniz.',
    'Type part of a file or folder name.\n\n'
        'Tip: you can also type sentences such as “whatsapp videos last month”, '
        '“pdf this week” or “photos from 2024”.',
    'اكتب جزءًا من اسم ملف أو مجلد.\n\n'
        'نصيحة: يمكنك أيضًا كتابة جمل مثل «فيديوهات واتساب الشهر الماضي» أو '
        '«pdf هذا الأسبوع» أو «صور 2024».',
  ),
  'srch.ai_interpret': (
    'AI ile yorumla (Gemini)',
    'Interpret with AI (Gemini)',
    'فسّر بالذكاء الاصطناعي (Gemini)',
  ),
  'srch.rebuild_index': ('Dizini yeniden kur', 'Rebuild the index', 'إعادة بناء الفهرس'),
  'srch.searching': ('Aranıyor…', 'Searching…', 'جارٍ البحث…'),
  'srch.no_result': ('Sonuç bulunamadı.', 'No results found.', 'لم يُعثر على نتائج.'),

  // ── Toplu yeniden adlandırma ──────────────────────────────────────────────
  'br.title': ('Toplu yeniden adlandır', 'Batch rename', 'إعادة تسمية جماعية'),
  'br.done': (
    '{n} dosya yeniden adlandırıldı.',
    '{n} files renamed.',
    'تمت إعادة تسمية {n} ملف.',
  ),
  'br.partial': (
    '{n} dosya adlandırıldı, {fail} hata: {first}',
    '{n} files renamed, {fail} errors: {first}',
    'أُعيدت تسمية {n} ملف، {fail} أخطاء: {first}',
  ),
  'br.preset_prefix': ('Tatil-1, Tatil-2…', 'Tatil-1, Tatil-2…', 'Tatil-1، Tatil-2…'),
  'br.preset_date_seq': ('Tarih + sıra', 'Date + number', 'التاريخ + الرقم'),
  'br.preset_name_seq': ('Eski ad + sıra', 'Old name + number', 'الاسم القديم + الرقم'),
  'br.preset_date_name': ('Tarih + eski ad', 'Date + old name', 'التاريخ + الاسم القديم'),
  'br.file_count': ('{n} dosya', '{n} files', '{n} ملف'),
  'br.find': ('Bul (eski adda)', 'Find (in the old name)', 'ابحث (في الاسم القديم)'),
  'br.more_files': (
    '… ve {n} dosya daha',
    '… and {n} more files',
    '… و{n} ملف آخر',
  ),
  'br.pattern': ('Ad kalıbı', 'Name pattern', 'نمط الاسم'),
  'br.replace': ('Değiştir', 'Replace', 'استبدال'),
  'br.start': ('Başlangıç', 'Start', 'البداية'),
  'br.preview': ('Önizleme', 'Preview', 'معاينة'),
  'br.will_change': ('{n} dosya değişecek', '{n} files will change', 'سيتغيّر {n} ملف'),
  'br.will_change_problems': (
    '{n} dosya değişecek · {problems} sorunlu ad atlanacak',
    '{n} files will change · {problems} problematic names will be skipped',
    'سيتغيّر {n} ملف · وسيُتخطّى {problems} اسم به مشكلة',
  ),

  // ── İşlem geçmişi ─────────────────────────────────────────────────────────
  'oph.title': ('Son işlemler', 'Recent operations', 'العمليات الأخيرة'),
  'oph.undone': (
    '{n} öğe eski yerine döndü.',
    '{n} items were moved back.',
    'أُعيد {n} عنصر إلى مكانه.',
  ),
  'oph.undo_partial': (
    '{n}/{total} öğe geri alındı; kalanı taşınamadı. '
        'Kayıt duruyor, yeniden deneyebilirsin.',
    '{n}/{total} items were undone; the rest could not be moved. The record is '
        'kept, so you can try again.',
    'تم التراجع عن {n}/{total} عنصر؛ وتعذّر نقل الباقي. السجل محفوظ فيمكنك '
        'المحاولة مجددًا.',
  ),
  'oph.clear': ('Geçmişi temizle', 'Clear the history', 'مسح السجل'),
  'oph.clear_title': ('Geçmiş temizlensin mi?', 'Clear the history?', 'هل تريد مسح السجل؟'),
  'oph.clear_body': (
    'Yalnızca işlem kayıtları silinir; dosyalarınıza hiçbir şey olmaz. '
        'Geri alma imkânı kaybolur.',
    'Only the operation records are deleted; nothing happens to your files. '
        'You lose the ability to undo them.',
    'تُحذف سجلات العمليات فقط؛ ولا يحدث شيء لملفاتك. لكنك تفقد إمكانية التراجع.',
  ),
  'oph.empty': (
    'Henüz kayıtlı işlem yok.\n'
        'Taşıma ve otomatik düzenleme işlemleri burada birikir ve buradan '
        'geri alınabilir.',
    'No operations recorded yet.\n'
        'Moves and auto-organize runs collect here and can be undone from here.',
    'لا توجد عمليات مسجّلة بعد.\n'
        'تتجمّع عمليات النقل والتنظيم التلقائي هنا ويمكن التراجع عنها من هنا.',
  ),

  // ── Yinelenen dosyalar ────────────────────────────────────────────────────
  'dup.scanning_title': (
    'Yinelenen dosyalar aranıyor',
    'Searching for duplicate files',
    'جارٍ البحث عن ملفات مكررة',
  ),
  'dup.scanning_name': (
    'Yinelenen dosya araması',
    'Duplicate file search',
    'البحث عن ملفات مكررة',
  ),
  'dup.comparing': (
    'Dosyalar bayt bayt karşılaştırılıyor…',
    'Comparing the files byte by byte…',
    'جارٍ مقارنة الملفات بايتًا ببايت…',
  ),
  'dup.comparing_short': (
    'Dosyalar karşılaştırılıyor…',
    'Comparing the files…',
    'جارٍ مقارنة الملفات…',
  ),
  'dup.none': (
    'Yinelenen dosya bulunamadı 🎉',
    'No duplicate files found 🎉',
    'لم يُعثر على ملفات مكررة 🎉',
  ),
  'dup.summary': (
    '{n} grup · {size} boşa gidiyor',
    '{n} groups · {size} wasted',
    '{n} مجموعة · {size} مهدرة',
  ),
  'dup.n_copies': ('{n} kopyayı', '{n} copies', '{n} نسخة'),
  'dup.none_short': ('Yinelenen dosya yok', 'No duplicate files', 'لا توجد ملفات مكررة'),
  'dup.job_summary': (
    '{n} grup · {size} kazanılabilir',
    '{n} groups · {size} can be freed',
    '{n} مجموعة · يمكن تحرير {size}',
  ),
  'dup.visible_summary': (
    '{shown} / {total} grup · {size} boşa gidiyor',
    '{shown} / {total} groups · {size} wasted',
    '{shown} / {total} مجموعة · {size} مهدرة',
  ),
  'dup.no_match': ('“{query}” için sonuç yok.', 'No results for “{query}”.', 'لا نتائج لـ «{query}».'),
  'dup.tile_summary': (
    '{n} kopya · {size} · {waste} kazanılabilir',
    '{n} copies · {size} · {waste} can be freed',
    '{n} نسخة · {size} · يمكن تحرير {waste}',
  ),
  'dup.group_summary': (
    '· {size} kazanılabilir',
    '· {size} can be freed',
    '· يمكن تحرير {size}',
  ),

  // ── Ses / video oynatıcı ──────────────────────────────────────────────────
  'mp.audio_failed': (
    'Bu ses dosyası çalınamadı: {error}',
    'This audio file could not be played: {error}',
    'تعذّر تشغيل هذا الملف الصوتي: {error}',
  ),
  // ── Arka planda çalma (2026-09-02) ───────────────────────────────────
  'mp.channel_name': ('Müzik çalar', 'Music player', 'مشغل الموسيقى'),
  'mp.channel_desc': (
    'Arka planda çalan ses dosyası bildirimi',
    'Notification for audio playing in the background',
    'إشعار الصوت الذي يعمل في الخلفية',
  ),
  'mp.play': ('Çal', 'Play', 'تشغيل'),
  'mp.pause': ('Duraklat', 'Pause', 'إيقاف مؤقت'),
  'mp.next': ('Sonraki', 'Next', 'التالي'),
  'mp.previous': ('Önceki', 'Previous', 'السابق'),
  'mp.background_on': (
    'Arka planda çalmaya devam eder',
    'Keeps playing in the background',
    'يستمر التشغيل في الخلفية',
  ),
  'mp.now_playing': ('Çalıyor', 'Now playing', 'قيد التشغيل'),
  'mp.speed': ('Hız', 'Speed', 'السرعة'),
  'mp.back10': ('10 sn geri', 'Back 10s', 'إرجاع 10 ثوانٍ'),
  'mp.forward10': ('10 sn ileri', 'Forward 10s', 'تقديم 10 ثوانٍ'),
  'mp.portrait': ('Dikey', 'Portrait', 'عمودي'),
  'mp.fullscreen': (
    'Tam ekran (yatay)',
    'Full screen (landscape)',
    'ملء الشاشة (أفقي)',
  ),
  'mp.next_page': ('Sonraki sayfa', 'Next page', 'الصفحة التالية'),
  'mp.play_speed': ('Oynatma hızı', 'Playback speed', 'سرعة التشغيل'),
  'mp.subtitles': ('Altyazı', 'Subtitles', 'الترجمة'),
  'mp.sub_off': ('Altyazı kapalı', 'Subtitles off', 'إيقاف الترجمة'),
  'mp.sub_pick': (
    'Dosyadan altyazı seç…',
    'Choose subtitle file…',
    'اختيار ملف ترجمة…',
  ),
  'mp.sub_earlier': (
    'Altyazıyı 0,5 sn öne al',
    'Shift subtitles 0.5 s earlier',
    'تقديم الترجمة 0.5 ثانية',
  ),
  'mp.sub_later': (
    'Altyazıyı 0,5 sn geciktir',
    'Shift subtitles 0.5 s later',
    'تأخير الترجمة 0.5 ثانية',
  ),
};
