part of '../app_strings.dart';

/// Çeviri tablosunun 8. bölümü (çoğunlukla `enum`, `aih` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t8 = {
  'skin.paper': ('Kağıt', 'Paper', 'ورقي'),
  'skin.paper_sub': (
    'Kağıt zemin, mürekkep metin, cetvel çizgileri',
    'Paper ground, ink text, ruled lines',
    'خلفية ورقية ونص حبري وخطوط مسطرة',
  ),
  'skin.light': ('Açık', 'Light', 'فاتح'),
  'skin.light_sub': (
    'Nötr beyaz — kağıdın sıcaklığı olmadan',
    'Neutral white, without the paper warmth',
    'أبيض محايد بدون دفء الورق',
  ),
  'skin.modern': ('Modern', 'Modern', 'عصري'),
  'skin.modern_sub': (
    'Canlı mor vurgu, yuvarlak köşeler, büyük simgeler',
    'Vivid purple accent, round corners, large icons',
    'لون بنفسجي زاهٍ وزوايا دائرية وأيقونات كبيرة',
  ),
  'skin.night': ('Gece (OLED)', 'Night (OLED)', 'ليلي (OLED)'),
  'skin.night_sub': (
    'Saf siyah zemin — pil dostu, gece okunur',
    'Pure black ground: battery friendly, easy at night',
    'خلفية سوداء نقية موفرة للبطارية ومريحة ليلاً',
  ),
  'skin.forces_dark': (
    'Bu tema her zaman koyu çalışır',
    'This theme always stays dark',
    'تبقى هذه السمة داكنة دائماً',
  ),

  // ── arka plan rengi ─────────────────────────────────────────────────────
  'bgc.title': ('Arka plan rengi', 'Background colour', 'لون الخلفية'),
  'bgc.default': ('Temanın kendi', 'Theme default', 'افتراضي السمة'),
  'bgc.white': ('Beyaz', 'White', 'أبيض'),
  'bgc.paper': ('Kağıt', 'Paper', 'ورقي'),
  'bgc.sand': ('Kum', 'Sand', 'رملي'),
  'bgc.rose': ('Gül', 'Rose', 'وردي'),
  'bgc.mint': ('Nane', 'Mint', 'نعناعي'),
  'bgc.ice': ('Buz mavisi', 'Ice blue', 'أزرق ثلجي'),
  'bgc.lilac': ('Leylak', 'Lilac', 'ليلكي'),
  'bgc.grey': ('Gri', 'Grey', 'رمادي'),
  'bgc.olive': ('Zeytin', 'Olive', 'زيتوني'),
  'bgc.navy': ('Gece mavisi', 'Navy', 'كحلي'),
  'bgc.black': ('Siyah', 'Black', 'أسود'),
  'set.sec_text': ('Yazı', 'Text', 'النص'),
  'set.sec_language': ('Dil', 'Language', 'اللغة'),
  'set.sec_lists': ('Listeler', 'Lists', 'القوائم'),
  'set.sec_photos': ('Fotoğraflar', 'Photos', 'الصور'),
  'set.sec_opening': ('Açma', 'Opening', 'الفتح'),
  'set.sec_key': ('Erişim', 'Access', 'الوصول'),
  'set.sec_lock': ('Klasör kilidi', 'Folder lock', 'قفل المجلد'),
  'set.sec_speed': ('Hız ve pil', 'Speed & battery', 'السرعة والبطارية'),

  'enum.doc_pdf': ('PDF', 'PDF', 'PDF'),
  'enum.doc_text': ('Metin', 'Text', 'نص'),
  'enum.doc_spreadsheet': ('Excel', 'Excel', 'Excel'),
  'enum.doc_word': ('Word', 'Word', 'Word'),
  'enum.doc_slides': ('Slayt', 'Slides', 'شرائح'),
  'enum.doc_image': ('Görsel', 'Image', 'صورة'),
  'enum.doc_unknown': ('Bilinmeyen', 'Unknown', 'غير معروف'),

  'enum.bucket_camera': ('Kamera', 'Camera', 'الكاميرا'),
  'enum.bucket_screenshot': ('Ekran görüntüsü', 'Screenshot', 'لقطة شاشة'),
  'enum.bucket_whatsapp': ('WhatsApp', 'WhatsApp', 'WhatsApp'),
  'enum.bucket_telegram': ('Telegram', 'Telegram', 'Telegram'),
  'enum.bucket_instagram': ('Instagram', 'Instagram', 'Instagram'),
  'enum.bucket_download': ('İndirilenler', 'Downloads', 'التنزيلات'),
  'enum.bucket_bluetooth': ('Bluetooth', 'Bluetooth', 'بلوتوث'),
  'enum.bucket_other': ('Diğer', 'Other', 'أخرى'),

  'enum.dl_queued': ('Sırada', 'Queued', 'في الانتظار'),
  'enum.dl_running': ('İndiriliyor', 'Downloading', 'جارٍ التنزيل'),
  'enum.dl_paused': ('Duraklatıldı', 'Paused', 'متوقف مؤقتًا'),
  'enum.dl_completed': ('Tamamlandı', 'Completed', 'اكتمل'),
  'enum.dl_failed': ('Başarısız', 'Failed', 'فشل'),
  'enum.dl_canceled': ('İptal edildi', 'Canceled', 'أُلغي'),

  'enum.age_fresh': ('yeni', 'new', 'جديد'),
  'enum.age_recent': ('bu ay', 'this month', 'هذا الشهر'),
  'enum.age_old': ('eski', 'old', 'قديم'),
  'enum.age_ancient': ('çok eski', 'very old', 'قديم جدًا'),
  'enum.age_unknown': ('bilinmiyor', 'unknown', 'غير معروف'),

  'enum.date_any': ('Her zaman', 'Any time', 'أي وقت'),
  'enum.date_today': ('Bugün', 'Today', 'اليوم'),
  'enum.date_week': ('Son 7 gün', 'Last 7 days', 'آخر 7 أيام'),
  'enum.date_month': ('Son 30 gün', 'Last 30 days', 'آخر 30 يومًا'),
  'enum.date_year': ('Son 1 yıl', 'Last year', 'آخر سنة'),
  'enum.date_custom': ('Özel aralık', 'Custom range', 'نطاق مخصص'),

  'enum.size_any': ('Tümü', 'All', 'الكل'),
  'enum.size_tiny': ('1 MB altı', 'Under 1 MB', 'أقل من 1 ميغابايت'),
  'enum.size_small': ('1 – 10 MB', '1 – 10 MB', '1 – 10 ميغابايت'),
  'enum.size_medium': ('10 – 100 MB', '10 – 100 MB', '10 – 100 ميغابايت'),
  'enum.size_large': ('100 MB üzeri', 'Over 100 MB', 'أكثر من 100 ميغابايت'),

  'enum.chat_image': ('Görüntü', 'Image', 'صورة'),
  'enum.chat_video': ('Video', 'Video', 'فيديو'),
  'enum.chat_document': ('Belge', 'Document', 'مستند'),
  'enum.chat_audio': ('Ses', 'Audio', 'صوت'),
  'enum.chat_voice': ('Sesli not', 'Voice note', 'رسالة صوتية'),
  'enum.chat_sticker': ('Çıkartma', 'Sticker', 'ملصق'),
  'enum.chat_gif': ('Animasyon (GIF)', 'Animation (GIF)', 'صورة متحركة (GIF)'),
  'enum.chat_other': ('Diğer', 'Other', 'أخرى'),
  'enum.chat_dir_any': ('Hepsi', 'All', 'الكل'),
  'enum.chat_dir_received': ('Bana gelenler', 'Received', 'الواردة'),
  'enum.chat_dir_sent': ('Gönderdiklerim', 'Sent', 'المرسلة'),

  'enum.res_keep': ('Değiştirme', 'Keep as is', 'دون تغيير'),
  'enum.res_480': ('480p', '480p', '480p'),
  'enum.res_540': ('540p', '540p', '540p'),
  'enum.res_720': ('720p (HD)', '720p (HD)', '720p (HD)'),
  'enum.res_1080': ('1080p (Full HD)', '1080p (Full HD)', '1080p (Full HD)'),
  'enum.res_percent': ('Yüzde', 'Percent', 'نسبة مئوية'),
  'enum.res_custom': ('Piksel (en × boy)', 'Pixels (width × height)', 'بكسل (عرض × ارتفاع)'),

  'enum.imgfmt_keep': ('Aynı kalsın', 'Keep the same', 'إبقاء كما هو'),
  'enum.imgfmt_jpeg': ('JPEG (küçük)', 'JPEG (small)', 'JPEG (صغير)'),
  'enum.imgfmt_png': ('PNG (kayıpsız)', 'PNG (lossless)', 'PNG (بلا فقد)'),

  'enum.vq_very_low': ('En küçük dosya', 'Smallest file', 'أصغر ملف'),
  'enum.vq_low': ('Küçük', 'Small', 'صغير'),
  'enum.vq_medium': ('Dengeli', 'Balanced', 'متوازن'),
  'enum.vq_high': ('Yüksek kalite', 'High quality', 'جودة عالية'),

  'enum.doc_invoice': ('Fatura', 'Invoice', 'فاتورة'),
  'enum.doc_receipt': ('Makbuz / fiş', 'Receipt', 'إيصال'),
  'enum.doc_id': ('Kimlik / resmî belge', 'ID / official document', 'هوية / مستند رسمي'),
  'enum.doc_health': ('Sağlık belgesi', 'Health document', 'مستند صحي'),
  'enum.doc_bank': ('Banka / finans', 'Bank / finance', 'بنك / مالية'),
  'enum.doc_contract': ('Sözleşme', 'Contract', 'عقد'),
  'enum.doc_education': ('Eğitim / not', 'Education / notes', 'تعليم / ملاحظات'),
  'enum.doc_screenshot': ('Ekran görüntüsü', 'Screenshot', 'لقطة شاشة'),
  'enum.doc_ticket': ('Bilet / rezervasyon', 'Ticket / booking', 'تذكرة / حجز'),
  'enum.doc_other': ('Diğer', 'Other', 'أخرى'),

  'enum.org_type': ('Türüne göre', 'By type', 'حسب النوع'),
  'enum.org_date': ('Tarihine göre', 'By date', 'حسب التاريخ'),
  'enum.org_source': ('Kaynağına göre', 'By source', 'حسب المصدر'),
  'enum.org_type_desc': (
    'Görüntüler, Videolar, Belgeler…',
    'Images, Videos, Documents…',
    'صور، فيديوهات، مستندات…',
  ),
  'enum.org_date_desc': ('2026-07, 2026-06…', '2026-07, 2026-06…', '2026-07، 2026-06…'),
  'enum.org_source_desc': (
    'Kamera, WhatsApp, İndirilenler…',
    'Camera, WhatsApp, Downloads…',
    'الكاميرا، WhatsApp، التنزيلات…',
  ),

  'enum.job_queued': ('Sırada', 'Queued', 'في الانتظار'),
  'enum.job_running': ('Sürüyor', 'Running', 'قيد التنفيذ'),
  'enum.job_done': ('Tamamlandı', 'Completed', 'اكتمل'),
  'enum.job_failed': ('Başarısız', 'Failed', 'فشل'),
  'enum.job_cancelled': ('İptal edildi', 'Cancelled', 'أُلغي'),
  'enum.job_interrupted': ('Yarıda kaldı', 'Interrupted', 'توقفت في المنتصف'),

  'enum.sim_strict': ('Çok sıkı', 'Very strict', 'صارم جدًا'),
  'enum.sim_normal': ('Normal', 'Normal', 'عادي'),
  'enum.sim_loose': ('Gevşek', 'Loose', 'متساهل'),
  'enum.sim_strict_desc': (
    'Neredeyse birebir aynı görüntüler (yeniden sıkıştırılmış kopyalar).',
    'Almost identical images (re-compressed copies).',
    'صور متطابقة تقريبًا (نسخ أُعيد ضغطها).',
  ),
  'enum.sim_normal_desc': (
    'Aynı görüntünün boyutu/kalitesi değişmiş ya da hafif kırpılmış hâlleri.',
    'The same image resized, re-encoded or lightly cropped.',
    'الصورة نفسها بعد تغيير الحجم أو الجودة أو قصّ بسيط.',
  ),
  'enum.sim_loose_desc': (
    'Aynı sahnenin arka arkaya çekilmiş kareleri de eşleşir; yanlış eşleşme olabilir.',
    'Also matches consecutive shots of the same scene; false matches are possible.',
    'يطابق أيضًا لقطات متتالية للمشهد نفسه؛ قد تحدث مطابقات خاطئة.',
  ),

  // ── Kesintisiz AI havuzu (5 anahtar × 6 model) ────────────────────────────
  'aipool.backup_keys': ('Yedek API anahtarları', 'Backup API keys', 'مفاتيح API احتياطية'),
  'aipool.backup_keys_sub': (
    'Birinci anahtarın TÜM modellerinin kotası dolunca sıradaki anahtara '
        'geçilir. En çok 5 anahtar.',
    'When every model of the first key is out of quota, the next key is used. '
        'Up to 5 keys.',
    'عند نفاد حصة كل نماذج المفتاح الأول يُستخدم المفتاح التالي. حتى 5 مفاتيح.',
  ),
  'aipool.key_n': ('Anahtar {n}', 'Key {n}', 'المفتاح {n}'),
  'aipool.add_key': ('Anahtar ekle', 'Add key', 'إضافة مفتاح'),
  'aipool.show_keys': ('Anahtarı göster/gizle', 'Show/hide key', 'إظهار/إخفاء المفتاح'),
  'aipool.model_chain': ('Model sırası', 'Model order', 'ترتيب النماذج'),
  'aipool.model_chain_sub': (
    'Gemini kotayı model başına sayar. Bir modelin kotası dolunca istek '
        'sıradaki modele geçer. En çok 6 model.',
    'Gemini counts quota per model. When one runs out the request moves to the '
        'next model. Up to 6 models.',
    'يحسب Gemini الحصة لكل نموذج. عند نفادها ينتقل الطلب إلى النموذج التالي. '
        'حتى 6 نماذج.',
  ),
  'aipool.add_model': ('Model ekle', 'Add model', 'إضافة نموذج'),
  'aipool.move_up': ('Yukarı taşı', 'Move up', 'نقل لأعلى'),
  'aipool.model_gone': (
    'Bu model artık kullanılamıyor — kaldırılmış ya da anahtarınıza kapalı.',
    'This model is no longer available — retired or not enabled for your key.',
    'لم يعد هذا النموذج متاحًا — أُوقف أو غير مفعّل لمفتاحك.',
  ),
  'aipool.status': ('Kota durumu', 'Quota status', 'حالة الحصة'),
  'aipool.status_sub': (
    '{total} kota havuzu (anahtar × model) · {cooling} tanesi şu an dolu.',
    '{total} quota pools (key × model) · {cooling} currently exhausted.',
    '{total} مجمّع حصص (مفتاح × نموذج) · {cooling} منها ممتلئة الآن.',
  ),
  'aipool.reset': ('Sıfırla', 'Reset', 'إعادة تعيين'),

  // ── Seçici kipi (başka uygulama bizden dosya istedi) ──────────────────────
  'pick.title': ('Dosya seç', 'Pick a file', 'اختر ملفًا'),
  'fm.categories': ('Kategoriler', 'Categories', 'الفئات'),
  'pick.search_hint': (
    'Tüm dosyalarda ara…',
    'Search all files…',
    'ابحث في كل الملفات…',
  ),
  'pick.select_n': ('Seç ({n})', 'Select ({n})', 'اختيار ({n})'),
  'pick.empty': (
    'Bu klasörde uygun dosya yok.',
    'No matching file in this folder.',
    'لا يوجد ملف مطابق في هذا المجلد.',
  ),
  'pick.unreadable': (
    'Bu klasör okunamadı.',
    'This folder could not be read.',
    'تعذّرت قراءة هذا المجلد.',
  ),
  'pick.need_permission': (
    'Dosyaları listelemek için depolama izni gerekiyor.',
    'Storage permission is needed to list files.',
    'مطلوب إذن التخزين لعرض الملفات.',
  ),
  'pick.failed': (
    'Dosya çağıran uygulamaya verilemedi.',
    'The file could not be handed to the requesting app.',
    'تعذّر تسليم الملف إلى التطبيق الطالب.',
  ),
  // Belirli tür istendiğinde açılan eşleşme listesi (2026-10-17).
  'pick.for_caller': ('{app} için', 'For {app}', 'لـ {app}'),
  'pick.filter_hint': (
    '{kind} dosyalarında ara…',
    'Search {kind} files…',
    'ابحث في ملفات {kind}…',
  ),
  'pick.matches_count': ('{n} dosya', '{n} files', '{n} ملف'),
  'pick.all': ('Tümü', 'All', 'الكل'),
  'pick.sort_newest': ('En yeni', 'Newest', 'الأحدث'),
  'pick.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'pick.browse_folders': ('Klasörlerde gez', 'Browse folders', 'تصفّح المجلدات'),
  'pick.other_sources': ('Diğer', 'Other', 'أخرى'),
  'pick.no_matches': (
    'Bu türde dosya bulunamadı. Klasörlerde gezebilir ya da "Diğer" ile Drive/Galeri\'den seçebilirsin.',
    'No files of this type were found. Browse folders or use "Other" for Drive/Gallery.',
    'لم يُعثر على ملفات من هذا النوع. تصفّح المجلدات أو استخدم "أخرى" لـ Drive/المعرض.',
  ),
  'pick.no_filter_matches': (
    'Aramaya uyan dosya yok.',
    'No file matches the search.',
    'لا يوجد ملف يطابق البحث.',
  ),

  // ── AI analiz kuyruğu (arka planda, bağlamsız — AppStrings.current) ───────
  'aiq.job_title': ('AI dosya analizi', 'AI file analysis', 'تحليل الملفات بالذكاء الاصطناعي'),
  'aiq.collecting': ('Dosyalar toplanıyor…', 'Collecting files…', 'جارٍ جمع الملفات…'),
  'aiq.all_fresh': (
    'Kapsamdaki her dosya zaten analiz edilmiş.',
    'Every file in scope is already analyzed.',
    'كل ملف ضمن النطاق مُحلَّل بالفعل.',
  ),
  'aiq.budget_done': (
    'Bugünlük dosya bütçesi doldu. Yarın devam edilebilir.',
    'Today\'s file budget is used up. You can continue tomorrow.',
    'انتهت حصة اليوم من الملفات. يمكنك المتابعة غدًا.',
  ),
  'aiq.budget_split': (
    'Günlük bütçe: bugün {n} dosya işlenecek, {rest} dosya yarına kaldı.',
    'Daily budget: {n} files today, {rest} left for tomorrow.',
    'الحصة اليومية: {n} ملف اليوم و{rest} متبقٍ للغد.',
  ),
  'aiq.waiting': (
    'Kota sınırı — {sec} sn bekleniyor…',
    'Quota limit — waiting {sec} s…',
    'حد الحصة — الانتظار {sec} ثانية…',
  ),
  'aiq.quota_stuck': ('Kota açılmadı: {error}', 'Quota did not recover: {error}', 'لم تُستعد الحصة: {error}'),
  'aiq.finished': ('{n} dosya analiz edildi.', '{n} files analyzed.', 'تم تحليل {n} ملف.'),
  'aiq.stopped': (
    'Durduruldu — {n} dosya işlendi, sonuçlar kaydedildi.',
    'Stopped — {n} files processed, results saved.',
    'أُوقف — تمت معالجة {n} ملف وحُفظت النتائج.',
  ),

  // ── AI Merkezi (toplu dosya analizi) ──────────────────────────────────────
  'aih.title': ('AI Merkezi', 'AI Hub', 'مركز الذكاء الاصطناعي'),
  'aih.tab_analysis': ('Analiz', 'Analysis', 'التحليل'),
  'aih.tab_chat': ('Sohbet', 'Chat', 'محادثة'),
  'aih.analysis_what': (
    'Dosya analizi ne yapar?',
    'What does file analysis do?',
    'ماذا يفعل تحليل الملفات؟',
  ),
  'aih.analysis_body': (
    'Telefondaki belge, fotoğraf ve indirmeleri okuyup her birine tür '
        've önem verir. Sonra "geçen ay indirdiğim faturalar nerede" diye '
        'sorabilir, resmî evrakı tek listede görebilir, anlamsız adları ve '
        'yanlış klasörleri toplu düzeltebilirsin.',
    'It reads the documents, photos and downloads on your phone and gives '
        'each one a type and an importance. After that you can ask "where '
        'are the invoices I downloaded last month", see all official '
        'paperwork in one list, and fix meaningless names and wrong folders '
        'in bulk.',
    'يقرأ المستندات والصور والتنزيلات على هاتفك ويمنح كلاً منها نوعاً '
        'وأهمية. بعدها يمكنك السؤال عن ملفاتك، ورؤية الأوراق الرسمية في '
        'قائمة واحدة، وإصلاح الأسماء والمجلدات الخاطئة دفعة واحدة.',
  ),
  'aih.analysis_manual': (
    'Analiz kendiliğinden başlamaz — sen başlatana kadar hiçbir dosya '
        'okunmaz, hiç token harcanmaz.',
    'Analysis never starts on its own: no file is read and no token is '
        'spent until you start it.',
    'لا يبدأ التحليل تلقائياً: لا يُقرأ أي ملف ولا يُستهلك أي رمز حتى تبدأه.',
  ),
  'aih.analysis_scope': ('Kapsamı ayarla', 'Set the scope', 'اضبط النطاق'),
  'aih.analysis_running': (
    'Analiz sürüyor',
    'Analysis is running',
    'التحليل قيد التشغيل',
  ),
  'aih.tab_tags': ('Etiketler', 'Tags', 'الوسوم'),
  'aih.tab_suggestions': ('Öneriler', 'Suggestions', 'اقتراحات'),
  'aih.tab_report': ('Rapor', 'Report', 'تقرير'),
  'aih.scope_settings': ('Kapsam ayarları', 'Scope settings', 'إعدادات النطاق'),
  'aih.start': ('Analizi başlat', 'Start analysis', 'ابدأ التحليل'),
  'aih.continue': ('Devam et', 'Continue', 'متابعة'),
  'aih.reanalyze': ('Hepsini yeniden analiz et', 'Re-analyze everything', 'أعد تحليل كل شيء'),
  'aih.pause': ('Duraklat', 'Pause', 'إيقاف مؤقت'),
  'aih.resume': ('Sürdür', 'Resume', 'استئناف'),
  'aih.stop': ('Durdur', 'Stop', 'إيقاف'),
  'aih.analyzed': (
    '{n} dosya analiz edildi',
    '{n} files analyzed',
    'تم تحليل {n} ملف',
  ),
  'aih.scope_summary': (
    '{n} klasör kapsam dışı · kapsamı ayarlardan değiştir',
    '{n} folders excluded · change the scope in settings',
    '{n} مجلد خارج النطاق · غيّر النطاق من الإعدادات',
  ),
  'aih.no_key_note': (
    'API anahtarı yok — yerel kip: tür ve önem tahmini yapılır, özet üretilmez.',
    'No API key — local mode: type and importance are guessed, no summaries.',
    'لا يوجد مفتاح API — الوضع المحلي: يُخمَّن النوع والأهمية دون ملخصات.',
  ),
  'aih.need_key': (
    'Sohbet için Ayarlar > Gemini API anahtarı gerekir.',
    'Chat needs a Gemini API key (Settings).',
    'تحتاج المحادثة إلى مفتاح Gemini API من الإعدادات.',
  ),
  'aih.chat_empty': (
    'Dosyalarına soru sor',
    'Ask your files',
    'اسأل ملفاتك',
  ),
  'aih.chat_empty_sub': (
    'Örnek: "geçen ay indirdiğim faturalar", "kira sözleşmem nerede", '
        '"bu yıl taradığım kimlik belgeleri".',
    'For example: "invoices I downloaded last month", "where is my lease", '
        '"ID documents I scanned this year".',
    'مثال: «الفواتير التي نزّلتها الشهر الماضي»، «أين عقد الإيجار»، '
        '«وثائق الهوية التي مسحتها هذا العام».',
  ),
  'aih.chat_hint': ('Bir soru yaz…', 'Type a question…', 'اكتب سؤالًا…'),
  'aih.sources': ('Kaynak dosyalar', 'Source files', 'الملفات المصدر'),
  'aih.no_match': (
    'Analiz edilen dosyalarda eşleşme yok.',
    'No match among the analyzed files.',
    'لا تطابق ضمن الملفات المُحلَّلة.',
  ),
  'aih.tags_empty': (
    'Henüz analiz yok',
    'No analysis yet',
    'لا يوجد تحليل بعد',
  ),
  'aih.tags_empty_sub': (
    'Yukarıdaki "Analizi başlat" düğmesi dosyaları okuyup etiketler.',
    'The "Start analysis" button above reads and tags your files.',
    'زر «ابدأ التحليل» أعلاه يقرأ ملفاتك ويضع لها وسومًا.',
  ),
  'aih.filter_important': ('Yalnız önemli', 'Important only', 'المهم فقط'),
  'aih.sug_empty': (
    'Bekleyen öneri yok',
    'No pending suggestions',
    'لا اقتراحات معلّقة',
  ),
  'aih.sug_empty_sub': (
    'Analiz, anlamsız adlandırılmış ya da yanlış klasördeki dosyalar için '
        'öneri üretir.',
    'Analysis suggests fixes for badly named or misplaced files.',
    'يقترح التحليل إصلاحات للملفات ذات الأسماء غير المفيدة أو في مجلد خاطئ.',
  ),
  'aih.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'aih.apply_selected': ('Uygula ({n})', 'Apply ({n})', 'تطبيق ({n})'),
  'aih.apply_one': ('Yalnız bunu uygula', 'Apply only this', 'طبّق هذا فقط'),
  'aih.ignore_one': ('Öneriyi yok say', 'Dismiss suggestion', 'تجاهل الاقتراح'),
  'fm.actions': ('Dosya işlemleri', 'File actions', 'إجراءات الملف'),
  'aih.applied': (
    '{ok} dosya düzenlendi, {fail} atlandı',
    '{ok} files updated, {fail} skipped',
    'تم تحديث {ok} ملف وتخطّي {fail}',
  ),
  'aih.report_empty': ('Rapor için önce analiz gerekir', 'Analyze first to see a report', 'حلّل أولًا لعرض التقرير'),
  'aih.report_empty_sub': (
    'Analiz bittiğinde burada tür dağılımı, önemli evrak ve çöp adayları çıkar.',
    'After analysis you get type breakdown, important documents and junk candidates.',
    'بعد التحليل يظهر توزيع الأنواع والمستندات المهمة والمرشّحة للحذف.',
  ),
  'aih.report_analyzed': ('Analiz edilen dosya', 'Files analyzed', 'ملفات محلَّلة'),
  'aih.report_important': ('Önemli evrak', 'Important documents', 'مستندات مهمة'),
  'aih.report_junk': ('Silinebilir aday', 'Deletion candidates', 'مرشّحة للحذف'),
  'aih.report_suggestions': ('Bekleyen öneri', 'Pending suggestions', 'اقتراحات معلّقة'),
  'aih.report_types': ('Türlere göre', 'By type', 'حسب النوع'),
  'aih.card_title': ('AI Asistan', 'AI assistant', 'مساعد الذكاء الاصطناعي'),
  'aih.card_idle': (
    'Dosyalarını analiz et, sonra onlara soru sor',
    'Analyze your files, then ask them questions',
    'حلّل ملفاتك ثم اسألها',
  ),
  'aih.card_ready': (
    '{n} dosya analiz edildi · {s} öneri bekliyor',
    '{n} files analyzed · {s} suggestions pending',
    'تم تحليل {n} ملف · {s} اقتراح معلّق',
  ),

  // ── AI kovaları, toplu işlem ve öneri uygulama ────────────────────────────
  'aif.empty': (
    'Bu listede dosya yok.',
    'No files in this list.',
    'لا ملفات في هذه القائمة.',
  ),
  'aif.selected_n': ('{n} seçili · {size}', '{n} selected · {size}', '{n} محدد · {size}'),
  'aif.apply': ('Öneriyi uygula', 'Apply suggestion', 'طبّق الاقتراح'),
  'aif.share': ('Paylaş', 'Share', 'مشاركة'),
  'aif.move': ('Taşı', 'Move', 'نقل'),
  'aih.report_low': (
    'Düşük önemli (gözden geçir)',
    'Low value (review)',
    'أهمية منخفضة (راجعها)',
  ),
  'aih.apply_all': ('Tümünü uygula ({n})', 'Apply all ({n})', 'طبّق الكل ({n})'),
  'aih.sug_hint': (
    'Taşınanlar “Önemli Dosyalar” altındaki klasöre gider. İşlem arka planda '
        'sürer; bildirimden izleyebilir, durdurabilirsiniz.',
    'Moved files go under “Important Files”. The job runs in the background; '
        'watch or stop it from the notification.',
    'تنتقل الملفات إلى «الملفات المهمة». تجري العملية في الخلفية؛ يمكنك '
        'متابعتها أو إيقافها من الإشعار.',
  ),
  'aih.card_sug_title': (
    '{n} dosya için ad/klasör önerisi hazır',
    'Name/folder suggestions ready for {n} files',
    'اقتراحات الاسم/المجلد جاهزة لـ {n} ملف',
  ),
  'aih.card_sug_body': (
    'Anlamsız adlandırılmış ya da yanlış klasördeki dosyalar. Seçtiklerin '
        'düzenlenir, gerisi olduğu gibi kalır.',
    'Badly named or misplaced files. Only what you pick is changed.',
    'ملفات بأسماء غير مفيدة أو في مجلد خاطئ. لا يتغيّر إلا ما تختاره.',
  ),
  'aih.card_sug_action': ('Önerileri aç', 'Open suggestions', 'افتح الاقتراحات'),
  'aih.card_junk_title': (
    '{n} harcanabilir dosya · {size}',
    '{n} disposable files · {size}',
    '{n} ملف قابل للحذف · {size}',
  ),
  'aih.card_junk_body': (
    'Ekran görüntüsü, geçici dosya ve önbellek gibi güvenle silinebilecekler. '
        'Fotoğraf ve videolar bu listeye ALINMAZ.',
    'Screenshots, temporary files and caches. Photos and videos are never '
        'included.',
    'لقطات الشاشة والملفات المؤقتة والذاكرة المؤقتة. لا تُدرج الصور والفيديو.',
  ),
  'aih.card_junk_action': ('Listeyi aç', 'Open list', 'افتح القائمة'),
  'aiap.job_title': ('AI önerileri uygulanıyor', 'Applying AI suggestions', 'تطبيق اقتراحات الذكاء الاصطناعي'),
  'aiap.job_name': ('AI önerilerinin uygulanması', 'Applying AI suggestions', 'تطبيق اقتراحات الذكاء الاصطناعي'),
  'aiap.started': (
    '{n} dosya arka planda düzenleniyor',
    'Updating {n} files in the background',
    'يجري تحديث {n} ملف في الخلفية',
  ),
  'aiap.result': (
    'Son uygulama: {ok} dosya düzenlendi, {fail} atlandı',
    'Last run: {ok} files updated, {fail} skipped',
    'آخر تشغيل: تم تحديث {ok} ملف وتخطّي {fail}',
  ),

  // ── AI kapsam ayarları ────────────────────────────────────────────────────
  'aiset.excluded': ('Kapsam dışı klasörler', 'Excluded folders', 'مجلدات مستثناة'),
  'aiset.excluded_sub': (
    'Buradaki klasörler analiz edilmez, içerikleri AI\'ya hiç gönderilmez. '
        'Kamera klasörü varsayılan olarak kapalıdır.',
    'These folders are never analyzed and their contents never leave the device. '
        'The camera folder is excluded by default.',
    'لا تُحلَّل هذه المجلدات ولا تغادر محتوياتها الجهاز. '
        'مجلد الكاميرا مستثنى افتراضيًا.',
  ),
  'aiset.exclude_add': ('Klasör dışla', 'Exclude a folder', 'استثنِ مجلدًا'),
  'aiset.exclude_pick': ('Bu klasörü dışla', 'Exclude this folder', 'استثنِ هذا المجلد'),
  'aiset.include_again': ('Kapsama geri al', 'Include again', 'أعده إلى النطاق'),
  'aiset.types': ('Analiz edilen türler', 'Analyzed types', 'الأنواع المُحلَّلة'),
  'aiset.types_sub': (
    'Kapalı tür hiç okunmaz.',
    'Types left off are never read.',
    'الأنواع المغلقة لا تُقرأ إطلاقًا.',
  ),
  'aiset.send_text': ('Metin özünü gönder', 'Send text excerpt', 'أرسل مقتطف النص'),
  'aiset.send_text_sub': (
    'Belgenin ilk {kb} KB metni Gemini\'ye gider. Kapalıyken yalnız dosya adı '
        've boyutu gönderilir.',
    'The first {kb} KB of text goes to Gemini. When off, only name and size are sent.',
    'تُرسل أول {kb} كيلوبايت من النص إلى Gemini. عند الإيقاف يُرسل الاسم والحجم فقط.',
  ),
  'aiset.send_images': ('Görselleri gönder', 'Send images', 'أرسل الصور'),
  'aiset.send_images_sub': (
    'Kapalıyken görselin kendisi asla yüklenmez; yalnız cihazda okunan metin '
        '(OCR) kullanılır.',
    'When off the image itself is never uploaded; only on-device OCR text is used.',
    'عند الإيقاف لا تُرفع الصورة أبدًا؛ يُستخدم نص OCR المستخرج على الجهاز فقط.',
  ),
  'aiset.hidden': ('Gizli dosyalar', 'Hidden files', 'الملفات المخفية'),
  'aiset.hidden_sub': (
    'Nokta ile başlayan dosya ve klasörler de analiz edilsin mi?',
    'Also analyze dot-files and dot-folders?',
    'هل تُحلَّل أيضًا الملفات والمجلدات التي تبدأ بنقطة؟',
  ),
  'aiset.excerpt': ('Gönderilen metin', 'Text sent', 'النص المُرسل'),
  'aiset.excerpt_sub': (
    'Dosya başına buluta giden en fazla metin.',
    'Maximum text sent to the cloud per file.',
    'أقصى نص يُرسل إلى السحابة لكل ملف.',
  ),
  'aiset.budget': ('Günlük dosya bütçesi', 'Daily file budget', 'حصة الملفات اليومية'),
  'aiset.budget_sub': (
    'Analiz kendi kendine durmasın diye varsayılan sınırsız. Kota gerçekten '
        'dolunca havuz sıradaki modele/anahtara geçer.',
    'Unlimited by default so analysis never stops itself. When quota really '
        'runs out the pool moves to the next model/key.',
    'غير محدود افتراضيًا كي لا يتوقف التحليل من تلقاء نفسه. وعند نفاد الحصة '
        'فعليًا ينتقل المجمّع إلى النموذج/المفتاح التالي.',
  ),
  'aiset.budget_unlimited': ('Sınırsız', 'Unlimited', 'بلا حد'),
  'aiset.forget': ('AI belleğini temizle', 'Clear AI memory', 'امسح ذاكرة الذكاء الاصطناعي'),
  'aiset.forget_sub': (
    'Tüm analiz kayıtlarını siler. Dosyalara dokunulmaz.',
    'Deletes all analysis records. Your files are untouched.',
    'يحذف كل سجلات التحليل. لا تُمسّ ملفاتك.',
  ),
  'aiset.forget_confirm': (
    'Analiz sonuçları (etiket, özet, öneri) silinsin mi? Dosyalarınız silinmez.',
    'Delete analysis results (tags, summaries, suggestions)? Your files stay.',
    'هل تُحذف نتائج التحليل (الوسوم والملخصات والاقتراحات)؟ تبقى ملفاتك.',
  ),
  'set.sec_ai_scope': ('Analiz kapsamı', 'Analysis scope', 'نطاق التحليل'),
  'set.sec_ai_privacy': ('Buluta ne gidiyor', 'What leaves the device', 'ما يغادر الجهاز'),
  'set.sec_ai_budget': ('Bütçe ve bellek', 'Budget and memory', 'الحصة والذاكرة'),

  'enum.op_move': ('Taşıma', 'Move', 'نقل'),
  'enum.op_copy': ('Kopyalama', 'Copy', 'نسخ'),
  'enum.op_delete': ('Silme', 'Delete', 'حذف'),
  'enum.op_rename': ('Yeniden adlandırma', 'Rename', 'إعادة تسمية'),
  'enum.op_organize': ('Otomatik düzenleme', 'Auto-organize', 'تنظيم تلقائي'),

  // ── 2026-09-24: bellek analizi / uygulamalar / AI / ayarlar turu ─────────
  'apps.sort_menu': ('Sırala ve göster', 'Sort and show', 'الترتيب والعرض'),
  'apps.filter_unused': (
    '{n}+ gün kullanılmayan',
    'Unused {n}+ days',
    'غير مستخدم منذ {n}+ يومًا',
  ),
  'apps.count': ('{n} uygulama', '{n} apps', '{n} تطبيق'),
  'apps.no_unused': (
    'Uzun süredir kullanılmayan uygulama yok.',
    'No apps have gone unused for long.',
    'لا توجد تطبيقات غير مستخدمة منذ مدة طويلة.',
  ),
  'apps.stat_cache': ('Önbellek', 'Cache', 'ذاكرة التخزين المؤقت'),
  'apps.stat_unused': (
    '{n}+ gün açılmadı',
    'Not opened {n}+ days',
    'لم يُفتح منذ {n}+ يومًا',
  ),
  'apps.stat_unused_size': (
    'kullanılmayan · {size}',
    'unused · {size}',
    'غير مستخدم · {size}',
  ),
  'apps.size_app': ('Uygulama', 'App', 'التطبيق'),
  'apps.size_data': ('Veri', 'Data', 'البيانات'),
  'apps.installed_on': ('Kuruldu', 'Installed', 'تاريخ التثبيت'),
  'apps.copy_package': ('Paket adını kopyala', 'Copy package name', 'نسخ اسم الحزمة'),
  'apps.package_copied': ('Paket adı kopyalandı', 'Package name copied', 'تم نسخ اسم الحزمة'),
  'aih.mode_cloud': (
    'Gemini ile: tür, önem ve kısa özet çıkarılır.',
    'With Gemini: type, importance and a short summary.',
    'مع Gemini: النوع والأهمية وملخص قصير.',
  ),
  'aih.mode_local': (
    'Yerel kip (anahtar yok): yalnız tür ve önem tahmini, özet yok.',
    'Local mode (no key): type and importance only, no summaries.',
    'الوضع المحلي (بلا مفتاح): النوع والأهمية فقط، دون ملخصات.',
  ),
  'aih.chat_clear': ('Konuşmayı temizle', 'Clear conversation', 'مسح المحادثة'),
  'aih.chat_need_analysis': (
    'Sohbet analiz edilmiş dosyalarda arar. Önce analizi başlat.',
    'Chat searches analysed files. Start the analysis first.',
    'تبحث المحادثة في الملفات المحلَّلة. ابدأ التحليل أولًا.',
  ),
  'aih.chat_try': (
    'Şunlardan birini dene ya da kendi sorunu yaz:',
    'Try one of these or type your own question:',
    'جرّب أحد هذه الأسئلة أو اكتب سؤالك:',
  ),
  'aih.ex1': (
    'Geçen ay indirdiğim faturalar',
    'Invoices I downloaded last month',
    'الفواتير التي نزّلتها الشهر الماضي',
  ),
  'aih.ex2': ('Kimlik belgelerim nerede?', 'Where are my ID documents?', 'أين وثائق هويتي؟'),
  'aih.ex3': (
    'Silebileceğim gereksiz dosyalar',
    'Unneeded files I can delete',
    'ملفات غير ضرورية يمكنني حذفها',
  ),
  'aih.ex4': ('Sözleşmelerim', 'My contracts', 'عقودي'),
  'aih.thinking': ('Dosyalarına bakıyorum…', 'Looking through your files…', 'أبحث في ملفاتك…'),
  'aih.ask_files': ('Dosyalara sor', 'Ask your files', 'اسأل ملفاتك'),
  'set.theme_auto': ('Otomatik', 'Auto', 'تلقائي'),
  'vw.saving_wait': (
    'Kaydediliyor, bir saniye…',
    'Saving, one moment…',
    'جارٍ الحفظ، لحظة…',
  ),
  'vw.ask_ai_selection': (
    'AI\'ya sor',
    'Ask AI',
    'اسأل الذكاء الاصطناعي',
  ),
  'vw.find_selection': (
    'Belgede ara',
    'Find in document',
    'ابحث في المستند',
  ),
  'vw.highlight_color': (
    'Vurgu rengi',
    'Highlight colour',
    'لون التمييز',
  ),
  'common.done': (
    'Bitti',
    'Done',
    'تم',
  ),
  'tf.auto_short': (
    'otomatik',
    'auto',
    'تلقائي',
  ),
  'tf.auto_detect': (
    'Otomatik algıla',
    'Detect language',
    'اكتشاف اللغة',
  ),
  'tf.detected': (
    'Algılanan: {lang}',
    'Detected: {lang}',
    'اللغة المكتشفة: {lang}',
  ),
  'ai.answer_language': (
    'Türkçe',
    'English',
    'العربية',
  ),
  'ai.reply_in': (
    'Yanıtı {lang} ver.',
    'Reply in {lang}.',
    'أجب باللغة {lang}.',
  ),
  'ai.thinking': (
    'Düşünüyor…',
    'Thinking…',
    'يفكر…',
  ),
  'ai.ask_about_hint': (
    'Bu kısım hakkında sor…',
    'Ask about this part…',
    'اسأل عن هذا الجزء…',
  ),
  'ai.q_explain': (
    'Açıkla',
    'Explain',
    'اشرح',
  ),
  'ai.q_explain_prompt': (
    'Aşağıdaki bölümü açıkla: ne anlatıyor, bağlamı ne, neden önemli? Kısa ve anlaşılır ol.',
    'Explain the passage below: what it says, its context and why it matters. Be brief and clear.',
    'اشرح المقطع التالي: ماذا يقول، وما سياقه، ولماذا هو مهم؟ كن موجزًا وواضحًا.',
  ),
  'ai.q_simplify': (
    'Basitçe anlat',
    'Simplify',
    'بسّط',
  ),
  'ai.q_simplify_prompt': (
    'Aşağıdaki bölümü, konuyu bilmeyen birine anlatır gibi sade bir dille yeniden anlat.',
    'Rewrite the passage below in plain language, as if explaining to someone new to the topic.',
    'أعد صياغة المقطع التالي بلغة بسيطة كأنك تشرحه لشخص جديد على الموضوع.',
  ),
  'ai.q_summary': (
    'Özetle',
    'Summarize',
    'لخّص',
  ),
  'ai.q_summary_prompt': (
    'Aşağıdaki bölümü 2-3 maddede özetle.',
    'Summarize the passage below in 2-3 bullet points.',
    'لخّص المقطع التالي في 2-3 نقاط.',
  ),
  'ai.q_terms': (
    'Terimler',
    'Key terms',
    'المصطلحات',
  ),
  'ai.q_terms_prompt': (
    'Aşağıdaki bölümdeki önemli terimleri, eski/yabancı kelimeleri ve özel adları kısa anlamlarıyla listele.',
    'List the important terms, archaic/foreign words and proper names in the passage below with short meanings.',
    'اذكر المصطلحات المهمة والكلمات القديمة أو الأجنبية وأسماء الأعلام في المقطع التالي مع معانٍ مختصرة.',
  ),
  'vw.pdf_error_title': (
    'Bu PDF açılamadı',
    'This PDF could not be opened',
    'تعذّر فتح ملف PDF هذا',
  ),
  'vw.pdf_error_empty': (
    'Dosya boş (0 bayt). Büyük olasılıkla bir indirme ya da kaydetme yarıda kalmış.',
    'The file is empty (0 bytes). A download or save was most likely interrupted.',
    'الملف فارغ (0 بايت). على الأرجح انقطع تنزيل أو حفظ.',
  ),
  'vw.pdf_error_broken': (
    'Dosya bozuk ya da tam inmemiş olabilir.',
    'The file may be damaged or incompletely downloaded.',
    'قد يكون الملف تالفًا أو لم يُنزَّل بالكامل.',
  ),
  'vw.pdf_error_restore': (
    'Özgün hâlini geri yükle',
    'Restore original',
    'استعادة النسخة الأصلية',
  ),
  'pn.title': (
    'Sayfaya git',
    'Go to page',
    'انتقل إلى الصفحة',
  ),
  'pn.position': (
    '{n}. sayfa · toplam {total} · %{p}',
    'Page {n} of {total} · {p}%',
    'الصفحة {n} من {total} · {p}٪',
  ),
  'pn.chip_label': (
    '{n}. sayfa, toplam {total}. Sayfaya gitmek için dokunun, yıldızlamak için basılı tutun.',
    'Page {n} of {total}. Tap to go to a page, long-press to bookmark.',
    'الصفحة {n} من {total}. انقر للانتقال، واضغط مطولًا لإضافة علامة.',
  ),
  'pn.star': (
    'Bu sayfayı yıldızla',
    'Bookmark this page',
    'أضف علامة لهذه الصفحة',
  ),
  'pn.unstar': (
    'Yıldızı kaldır',
    'Remove bookmark',
    'إزالة العلامة',
  ),
  'pn.starred': (
    '{n}. sayfa yıldızlandı',
    'Page {n} bookmarked',
    'تمت إضافة علامة للصفحة {n}',
  ),
  'pn.unstarred': (
    '{n}. sayfanın yıldızı kaldırıldı',
    'Bookmark removed from page {n}',
    'أُزيلت علامة الصفحة {n}',
  ),
  'pn.prev': (
    'Önceki sayfa (basılı tut: hızlı)',
    'Previous page (hold: faster)',
    'الصفحة السابقة (اضغط مطولًا: أسرع)',
  ),
  'pn.next': (
    'Sonraki sayfa (basılı tut: hızlı)',
    'Next page (hold: faster)',
    'الصفحة التالية (اضغط مطولًا: أسرع)',
  ),
  'pn.field_hint': (
    'Sayfa (1–{total})',
    'Page (1–{total})',
    'الصفحة (1–{total})',
  ),
  'pn.first': (
    'İlk sayfa',
    'First page',
    'الصفحة الأولى',
  ),
  'pn.last': (
    'Son sayfa',
    'Last page',
    'الصفحة الأخيرة',
  ),
  'pn.back_to': (
    '{n}. sayfaya dön',
    'Back to page {n}',
    'العودة إلى الصفحة {n}',
  ),
  'pn.bookmarks': (
    'Yıldızlı sayfalar ({n})',
    'Bookmarked pages ({n})',
    'الصفحات المعلَّمة ({n})',
  ),
  'pn.bookmarks_empty': (
    'Henüz yıldızlı sayfa yok. Okurken sayfa rozetine basılı tutarak ya da buradaki düğmeyle yıldızlayabilirsiniz.',
    'No bookmarks yet. While reading, long-press the page badge or use the button here.',
    'لا توجد علامات بعد. أثناء القراءة اضغط مطولًا على شارة الصفحة أو استخدم الزر هنا.',
  ),
  'ea.shortcut': (
    'Ana ekrana ekle',
    'Add to home screen',
    'إضافة إلى الشاشة الرئيسية',
  ),
  'ea.shortcut_hint': (
    'telefon ana ekranına kısayol',
    'shortcut on your phone\'s home screen',
    'اختصار على الشاشة الرئيسية',
  ),
  'ea.shortcut_unsupported': (
    'Bu telefonun ana ekranı kısayol eklemeyi desteklemiyor.',
    'This phone\'s launcher does not support adding shortcuts.',
    'مشغّل هذا الهاتف لا يدعم إضافة الاختصارات.',
  ),
  'ea.shortcut_requested': (
    '“{name}” için kısayol istendi — ana ekranın onay penceresinden ekleyin.',
    'Shortcut requested for “{name}” — confirm it in your home screen\'s prompt.',
    'طُلب اختصار لـ «{name}» — أكّده من نافذة الشاشة الرئيسية.',
  ),
  'ea.shortcut_failed': (
    'Kısayol eklenemedi.',
    'Could not add the shortcut.',
    'تعذّرت إضافة الاختصار.',
  ),
  'ea.shortcut_missing': (
    'Kısayolun gösterdiği öğe bulunamadı (taşınmış ya da silinmiş olabilir).',
    'The item this shortcut points to was not found (it may have been moved or deleted).',
    'تعذّر العثور على العنصر الذي يشير إليه الاختصار (ربما نُقل أو حُذف).',
  ),
  'ea.hide': (
    'Gizle',
    'Hide',
    'إخفاء',
  ),
  'ea.hide_hint': (
    'galeride ve listelerde görünmez',
    'hidden from gallery and lists',
    'لا يظهر في المعرض والقوائم',
  ),
  'hv.title': (
    'Gizli dosyalar',
    'Hidden files',
    'الملفات المخفية',
  ),
  'hv.hidden_n': (
    '{n} öğe gizlendi',
    '{n} item(s) hidden',
    'تم إخفاء {n} عنصر',
  ),
  'hv.restored_n': (
    '{n} öğe geri yüklendi',
    '{n} item(s) restored',
    'تمت استعادة {n} عنصر',
  ),
  'hv.empty': (
    'Gizli dosya yok. Bir dosyaya basılı tutup “Gizle” deyin.',
    'No hidden files. Long-press a file and choose “Hide”.',
    'لا توجد ملفات مخفية. اضغط مطولًا على ملف واختر «إخفاء».',
  ),
  'hv.restore': (
    'Geri yükle',
    'Restore',
    'استعادة',
  ),
  'hv.note': (
    'Gizlenen dosyalar gizli bir klasöre taşınır; galeride ve bu uygulamanın listelerinde görünmez. Şifreleme değildir.',
    'Hidden files are moved to a hidden folder; they don\'t appear in the gallery or in this app\'s lists. This is not encryption.',
    'تُنقل الملفات المخفية إلى مجلد مخفي؛ لا تظهر في المعرض أو في قوائم هذا التطبيق. هذا ليس تشفيرًا.',
  ),
  'hv.from': (
    'Geldiği yer: {path}',
    'From: {path}',
    'المصدر: {path}',
  ),
  'hv.hiding': ('Gizleniyor', 'Hiding', 'جارٍ الإخفاء'),
  'hv.hide_name': ('Gizleme', 'Hiding', 'الإخفاء'),
  'hv.restoring': ('Geri getiriliyor', 'Restoring', 'جارٍ الاستعادة'),
  'hv.restore_name': ('Gizlenenleri geri getirme', 'Restoring hidden files', 'استعادة الملفات المخفية'),
  'hv.confirm_title': (
    '{n} öğe gizlensin mi?',
    'Hide {n} item(s)?',
    'إخفاء {n} عنصر؟',
  ),
  'hv.confirm_body': (
    'Öğeler şifrelenip Kasa\'ya taşınacak; telefon bilgisayara bağlansa da okunamazlar. Kasa\'dan geri çıkarabilirsiniz.',
    'The items will be encrypted and moved into the Vault; they stay unreadable even when the phone is connected to a computer. Take them out from the Vault.',
    'ستُشفَّر العناصر وتُنقل إلى الخزنة، فلا تُقرأ حتى عند توصيل الهاتف بحاسوب. يمكنك إخراجها من الخزنة.',
  ),
  'dash.reset': (
    'Varsayılan',
    'Reset',
    'افتراضي',
  ),
  'dash.tiles': (
    'Kutular',
    'Tiles',
    'المربعات',
  ),
  'dash.sections': (
    'Bölümler',
    'Sections',
    'الأقسام',
  ),
  'dash.hint': (
    'Sürükleyerek sıralayın, anahtarla gösterin/gizleyin. Değişiklik hemen uygulanır.',
    'Drag to reorder, use the switch to show/hide. Changes apply immediately.',
    'اسحب لإعادة الترتيب واستخدم المفتاح للإظهار/الإخفاء. تُطبّق التغييرات فورًا.',
  ),
  'dash.sec_storage': (
    'Bellek kartları',
    'Storage cards',
    'بطاقات التخزين',
  ),
  'dash.sec_recent': (
    'Son açılanlar',
    'Recently opened',
    'المفتوحة مؤخرًا',
  ),
  'dash.recent_all': (
    'Tümü →',
    'All →',
    'الكل ←',
  ),
  'dash.sec_categories': (
    'Kategori kutuları',
    'Category tiles',
    'مربعات الفئات',
  ),
  'dash.sec_favorites': (
    'Favoriler',
    'Favourites',
    'المفضلة',
  ),
  'dash.title': (
    'Ana ekranı düzenle',
    'Customize home',
    'تخصيص الشاشة الرئيسية',
  ),
  'chat.page_label': (
    'Sayfa {n}',
    'Page {n}',
    'الصفحة {n}',
  ),
  'chat.quick_page_summary': (
    'Bu sayfayı özetle',
    'Summarize this page',
    'لخّص هذه الصفحة',
  ),
  'chat.quick_page_summary_prompt': (
    'Şu an okuduğum sayfayı ({page}) kısa maddelerle özetle.',
    'Summarize the page I\'m reading now ({page}) in short bullet points.',
    'لخّص الصفحة التي أقرؤها الآن ({page}) في نقاط قصيرة.',
  ),
  'chat.quick_page_explain': (
    'Bu sayfayı açıkla',
    'Explain this page',
    'اشرح هذه الصفحة',
  ),
  'chat.quick_page_explain_prompt': (
    'Şu an okuduğum sayfayı ({page}) sade bir dille açıkla; zor kavramları ve eski/yabancı kelimeleri anlamlarıyla ver.',
    'Explain the page I\'m reading now ({page}) in plain language; give the meaning of difficult concepts and archaic/foreign words.',
    'اشرح الصفحة التي أقرؤها الآن ({page}) بلغة بسيطة، مع معاني المفاهيم الصعبة والكلمات القديمة أو الأجنبية.',
  ),
};
