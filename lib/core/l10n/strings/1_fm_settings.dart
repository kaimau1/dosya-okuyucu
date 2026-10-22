part of '../app_strings.dart';

/// Çeviri tablosunun 1. bölümü (çoğunlukla `fm`, `settings` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t1 = {
  // ── Ortak eylemler ────────────────────────────────────────────────────────
  'common.ok': ('Tamam', 'OK', 'موافق'),
  'common.cancel': ('Vazgeç', 'Cancel', 'إلغاء'),
  'common.yes': ('Evet', 'Yes', 'نعم'),
  'common.no': ('Hayır', 'No', 'لا'),
  'common.details': ('Ayrıntı', 'Details', 'التفاصيل'),
  'common.close': ('Kapat', 'Close', 'إغلاق'),
  'common.save': ('Kaydet', 'Save', 'حفظ'),
  'common.delete': ('Sil', 'Delete', 'حذف'),
  'common.share': ('Paylaş', 'Share', 'مشاركة'),
  'common.download': ('İndir', 'Download', 'تنزيل'),
  'ink.title': ('Kalemle düzenle', 'Draw & annotate', 'الرسم والتعليق'),
  'ink.pen': ('Kalem', 'Pen', 'قلم'),
  'ink.highlighter': ('Fosforlu', 'Highlighter', 'قلم تمييز'),
  'ink.text': ('Yazı', 'Text', 'نص'),
  'ink.eraser': ('Silgi', 'Eraser', 'ممحاة'),
  'ink.hand': ('Kaydır', 'Move', 'تحريك'),
  'ink.redo': ('Yinele', 'Redo', 'إعادة'),
  'ink.eraser_hint': ('Silmek için üstünden geç', 'Swipe over a mark to erase', 'مرّر فوق العلامة لمسحها'),
  'ink.hand_hint': (
    'Sürükle: kaydır · yukarı/aşağı: sayfa çevir. Kalemdeyken iki parmak da kaydırır.',
    'Drag to move · swipe up/down to turn pages. With the pen, use two fingers.',
    'اسحب للتحريك · اسحب لأعلى/لأسفل لتقليب الصفحات. مع القلم استخدم إصبعين.',
  ),
  'ink.text_title': ('Yazı ekle', 'Add text', 'إضافة نص'),
  'ink.text_hint': ('Yazılacak metin', 'Text to place', 'النص المراد إضافته'),
  'ink.size_s': ('Küçük', 'Small', 'صغير'),
  'ink.size_m': ('Orta', 'Medium', 'متوسط'),
  'ink.size_l': ('Büyük', 'Large', 'كبير'),
  'ink.unsaved_title': ('Çizimler kaydedilmedi', 'Unsaved marks', 'علامات غير محفوظة'),
  'ink.unsaved_body': ('Yaptığın çizim ve yazılar kaydedilsin mi?', 'Save your drawings and text?', 'هل تريد حفظ الرسومات والنصوص؟'),
  'ink.save_note': ('Çizimler ve yazılar sayfaya kalıcı olarak işlenir.', 'Drawings and text are permanently added to the pages.', 'تُضاف الرسومات والنصوص إلى الصفحات بشكل دائم.'),
  'ink.failed': ('Kaydedilemedi: {error}', 'Could not save: {error}', 'تعذّر الحفظ: {error}'),
  'dl.saved': ("İndirilenler'e kaydedildi: {name}", 'Saved to Downloads: {name}', 'تم الحفظ في التنزيلات: {name}'),
  'dl.already_saved': ("Zaten İndirilenler'de: {name}", 'Already in Downloads: {name}', 'موجود بالفعل في التنزيلات: {name}'),
  'dl.save_failed': ("İndirilenler'e kaydedilemedi: {error}", 'Could not save to Downloads: {error}', 'تعذّر الحفظ في التنزيلات: {error}'),
  'dl.show': ('Göster', 'Show', 'عرض'),
  'dl.from_browser': ("Tarayıcıdan açılan dosya İndirilenler'e kaydedildi: {name}", 'File opened from the browser was saved to Downloads: {name}', 'تم حفظ الملف المفتوح من المتصفح في التنزيلات: {name}'),
  'common.open': ('Aç', 'Open', 'فتح'),
  'common.edit': ('Düzenle', 'Edit', 'تحرير'),
  'common.apply': ('Uygula', 'Apply', 'تطبيق'),
  'common.search': ('Ara', 'Search', 'بحث'),
  'common.refresh': ('Yenile', 'Refresh', 'تحديث'),
  'common.settings': ('Ayarlar', 'Settings', 'الإعدادات'),
  'common.previous': ('Önceki', 'Previous', 'السابق'),
  'common.next': ('Sonraki', 'Next', 'التالي'),
  'common.copy': ('Kopyala', 'Copy', 'نسخ'),
  'common.more': ('Daha fazla', 'More', 'المزيد'),
  // 2026-09-23 tasarım turu — belge kabuğu, "Daha fazla" sayfası, okuma ayarları
  'shell.unsaved': ('Kaydedilmedi', 'Unsaved', 'غير محفوظ'),
  'shell.pages': ('{n} sayfa', '{n} pages', '{n} صفحة'),
  'shell.slides': ('{n} slayt', '{n} slides', '{n} شريحة'),
  'shell.sheets': ('{n} sayfa', '{n} sheets', '{n} أوراق'),
  'dm.view': ('Görünüm', 'View', 'العرض'),
  'dm.page': ('Sayfa', 'Page', 'الصفحة'),
  'dm.text': ('Metin', 'Text', 'النص'),
  'dm.convert': ('Dönüştür ve dinle', 'Convert & listen', 'التحويل والاستماع'),
  'dm.file': ('Dosya', 'File', 'الملف'),
  'vw.reading_settings': ('Okuma ayarları', 'Reading settings', 'إعدادات القراءة'),
  'vw.text_size': ('Yazı boyutu', 'Text size', 'حجم الخط'),
  'vw.font_default': ('Varsayılan', 'Default', 'الافتراضي'),
  'vw.layout': ('Düzen', 'Layout', 'التخطيط'),
  'vw.speak_part': ('Bölüm {n} / {total}', 'Part {n} of {total}', 'الجزء {n} من {total}'),
  'find.none': ('Sonuç yok', 'No results', 'لا نتائج'),
  'gal.info': ('Bilgi', 'Info', 'معلومات'),
  'gal.tools': ('Araçlar', 'Tools', 'الأدوات'),
  'common.stop': ('Durdur', 'Stop', 'إيقاف'),
  'common.add': ('Ekle', 'Add', 'إضافة'),
  'common.pause': ('Duraklat', 'Pause', 'إيقاف مؤقت'),
  'common.resume': ('Devam et', 'Resume', 'متابعة'),
  'common.location': ('Konum', 'Location', 'الموقع'),
  // Dili belirtilmemiş kod bloğunun rozeti (```…```).
  'md.code': ('kod', 'code', 'شيفرة'),
  'common.password': ('Parola', 'Password', 'كلمة المرور'),
  'common.ignore': ('Yoksay', 'Ignore', 'تجاهل'),
  'fm.search_apps': ('Uygulama ara…', 'Search apps…', 'ابحث في التطبيقات…'),
  'common.go': ('Git', 'Go', 'انتقال'),
  'common.saved': ('Kaydedildi', 'Saved', 'تم الحفظ'),
  'common.save_failed': (
    'Kaydedilemedi: {error}',
    'Could not save: {error}',
    'تعذّر الحفظ: {error}',
  ),
  'common.translate': ('Çevir', 'Translate', 'ترجمة'),
  'common.ai': ('AI ile çalış', 'Work with AI', 'العمل بالذكاء الاصطناعي'),
  'common.bold': ('Kalın', 'Bold', 'عريض'),
  'common.italic': ('İtalik', 'Italic', 'مائل'),
  'common.underline': ('Altı çizili', 'Underline', 'تسطير'),
  'common.align_left': ('Sola yasla', 'Align left', 'محاذاة لليسار'),
  'common.align_center': ('Ortala', 'Center', 'توسيط'),
  'common.align_right': ('Sağa yasla', 'Align right', 'محاذاة لليمين'),
  'common.align_justify': ('İki yana yasla', 'Justify', 'ضبط'),
  // 2026-08-08: son kalan sabit Türkçe metinler buraya taşındı — uygulamada
  // artık kullanıcıya görünen çevrilmemiş dize YOK (`l10n_literals_test`
  // yenisini eklemeyi derleme değil TEST hatası yapar).
  'common.undo': ('Geri al', 'Undo', 'تراجع'),
  'common.retry': ('Yeniden dene', 'Retry', 'إعادة المحاولة'),
  'common.rescan': ('Yeniden tara', 'Rescan', 'إعادة الفحص'),
  'common.clear': ('Temizle', 'Clear', 'مسح'),
  'common.clear_selection': ('Seçimi kaldır', 'Clear selection', 'إلغاء التحديد'),
  'common.send': ('Gönder', 'Send', 'إرسال'),
  'common.remove_bookmark': (
    'Yer imini kaldır',
    'Remove bookmark',
    'إزالة الإشارة المرجعية',
  ),
  'common.new': ('Yeni', 'New', 'جديد'),
  'common.oldest': ('en eski', 'oldest', 'الأقدم'),
  'common.best': ('en iyi', 'best', 'الأفضل'),
  'common.deleting': ('Siliniyor', 'Deleting', 'جارٍ الحذف'),
  'common.saved_hint': (
    'Kaydedildi. Kalıcı yer için ⋮ > Paylaş/Dışa aktar.',
    'Saved. Use ⋮ > Share/Export for a permanent location.',
    'تم الحفظ. استخدم ⋮ > مشاركة/تصدير لموقع دائم.',
  ),
  'common.open_failed': (
    'Açılamadı: {error}',
    'Could not open: {error}',
    'تعذّر الفتح: {error}',
  ),

  // ── Ana ekran / gezinme ───────────────────────────────────────────────────
  'home.tab_files': ('Dosyalar', 'Files', 'الملفات'),
  'home.tab_recent': ('Son belgeler', 'Recent', 'المستندات الأخيرة'),
  'home.tab_ai': ('AI', 'AI', 'الذكاء الاصطناعي'),
  'home.pdf_tools': ('PDF araçları', 'PDF tools', 'أدوات PDF'),
  'home.new_document': ('Yeni belge', 'New document', 'مستند جديد'),
  'home.new_document_title': (
    'Yeni belge oluştur',
    'Create a new document',
    'إنشاء مستند جديد',
  ),
  'home.new_word': ('Word belgesi', 'Word document', 'مستند Word'),
  'home.new_excel': ('Excel tablosu', 'Excel spreadsheet', 'جدول Excel'),
  'home.new_text': ('Metin dosyası', 'Text file', 'ملف نصي'),
  'home.theme_system': ('Tema: Sistem', 'Theme: System', 'السمة: النظام'),
  'home.theme_light': ('Tema: Açık', 'Theme: Light', 'السمة: فاتح'),
  'home.theme_dark': ('Tema: Koyu', 'Theme: Dark', 'السمة: داكن'),
  'home.scan': ('Belge Tara', 'Scan document', 'مسح مستند'),
  'home.open_file': ('Dosya Aç', 'Open file', 'فتح ملف'),
  'home.search_recent': (
    'Son dosyalarda ara…',
    'Search recent files…',
    'ابحث في الملفات الأخيرة…',
  ),
  'home.no_match': ('Eşleşen dosya yok', 'No matching file', 'لا يوجد ملف مطابق'),
  'home.empty_title': (
    'Henüz belge açmadınız',
    'You haven’t opened a document yet',
    'لم تفتح أي مستند بعد',
  ),
  'home.empty_body': (
    'PDF, Word, Excel, Slayt, görsel ve metin dosyalarını açıp inceleyebilir, '
        'düzenleyebilir ve yapay zeka ile üzerinde çalışabilirsiniz. '
        'Telefonundaki tüm dosyalar için alttaki “Dosyalar” sekmesini kullanın.',
    'Open, view and edit PDF, Word, Excel, slide, image and text files, and '
        'work on them with AI. Use the “Files” tab below for everything on '
        'your phone.',
    'افتح واعرض وحرّر ملفات PDF وWord وExcel والشرائح والصور والنصوص، واعمل '
        'عليها بالذكاء الاصطناعي. استخدم تبويب «الملفات» بالأسفل لكل ما على هاتفك.',
  ),
  'home.empty_cta': ('İlk dosyanı aç', 'Open your first file', 'افتح أول ملف لك'),
  'home.empty_ai_hint': (
    'AI özellikleri için Ayarlar’dan Gemini API anahtarı ekleyin.',
    'Add a Gemini API key in Settings to enable AI features.',
    'أضف مفتاح Gemini API من الإعدادات لتفعيل ميزات الذكاء الاصطناعي.',
  ),
  'home.open_error': (
    'Dosya açılamadı: {error}',
    'Could not open file: {error}',
    'تعذّر فتح الملف: {error}',
  ),
  'home.open_error_moved': (
    'Dosya açılamadı (taşınmış olabilir): {name}',
    'Could not open file (it may have been moved): {name}',
    'تعذّر فتح الملف (ربما تم نقله): {name}',
  ),
  'home.create_error': (
    'Yeni belge oluşturulamadı: {error}',
    'Could not create the document: {error}',
    'تعذّر إنشاء المستند: {error}',
  ),
  'home.time_now': ('az önce', 'just now', 'الآن'),
  'home.time_minutes': ('{n} dk önce', '{n} min ago', 'قبل {n} دقيقة'),
  'home.time_hours': ('{n} saat önce', '{n} h ago', 'قبل {n} ساعة'),
  'home.time_days': ('{n} gün önce', '{n} d ago', 'قبل {n} يوم'),
  'home.time_weeks': ('{n} hafta önce', '{n} w ago', 'قبل {n} أسبوع'),
  'home.time_months': ('{n} ay önce', '{n} mo ago', 'قبل {n} شهر'),
  'home.time_years': ('{n} yıl önce', '{n} y ago', 'قبل {n} سنة'),

  // ── Ayarlar ───────────────────────────────────────────────────────────────
  'settings.title': ('Ayarlar', 'Settings', 'الإعدادات'),
  'settings.language': ('Dil', 'Language', 'اللغة'),
  'settings.language_note': (
    'Uygulama dili. “Sistem” cihazın dilini kullanır; desteklenmeyen bir dilde '
        'Türkçe’ye düşer. Arapça seçilince arayüz sağdan sola akar.',
    'App language. “System” follows your device; unsupported languages fall '
        'back to Turkish. Arabic switches the interface to right-to-left.',
    'لغة التطبيق. يتبع خيار «النظام» لغة جهازك؛ وتُستخدم التركية عند عدم دعم '
        'اللغة. يؤدي اختيار العربية إلى عرض الواجهة من اليمين إلى اليسار.',
  ),
  'settings.language_system': ('Sistem', 'System', 'النظام'),
  'settings.ai_section': (
    'Yapay Zeka (Gemini)',
    'Artificial intelligence (Gemini)',
    'الذكاء الاصطناعي (Gemini)',
  ),
  'settings.api_key': ('Gemini API anahtarı', 'Gemini API key', 'مفتاح Gemini API'),
  'settings.api_key_note': (
    'Anahtar cihazınızda saklanır. aistudio.google.com adresinden ücretsiz '
        'alabilirsiniz.',
    'The key is stored on your device. You can get one for free at '
        'aistudio.google.com.',
    'يُحفظ المفتاح على جهازك. يمكنك الحصول عليه مجانًا من aistudio.google.com.',
  ),
  'settings.model_fetched': (
    'Model (hesabınızdan alındı)',
    'Model (from your account)',
    'النموذج (من حسابك)',
  ),
  'settings.model_default': (
    'Model (varsayılan liste)',
    'Model (default list)',
    'النموذج (القائمة الافتراضية)',
  ),
  'settings.model_refresh': (
    'Model listesini yenile',
    'Refresh model list',
    'تحديث قائمة النماذج',
  ),
  'settings.model_none': (
    'Bu anahtarla model bulunamadı.',
    'No model found for this key.',
    'لم يُعثر على نموذج لهذا المفتاح.',
  ),
  'settings.model_error': (
    '{error} Varsayılan liste gösteriliyor.',
    '{error} Showing the default list.',
    '{error} يتم عرض القائمة الافتراضية.',
  ),
  'settings.model_found': (
    '{n} model bulundu.',
    '{n} models found.',
    'تم العثور على {n} نموذج.',
  ),
  'settings.appearance': ('Görünüm ve dil', 'Appearance & language', 'المظهر واللغة'),
  'settings.appearance_sub': (
    'Tema ve arayüz dili',
    'Theme and interface language',
    'السمة ولغة الواجهة',
  ),
  'settings.theme': ('Tema', 'Theme', 'السمة'),
  'settings.ui_font': ('Yazı tipi', 'Font', 'نوع الخط'),
  'settings.ui_text_size': ('Yazı boyutu', 'Text size', 'حجم النص'),
  'settings.size_small': ('Küçük', 'Small', 'صغير'),
  'settings.size_medium': ('Orta', 'Medium', 'متوسط'),
  'settings.size_large': ('Büyük', 'Large', 'كبير'),
  'settings.size_xlarge': ('Çok büyük', 'Extra large', 'كبير جدًا'),
  'settings.font_sample': (
    'Örnek: Dosya Okuyucu — 0123456789',
    'Sample: File Reader — 0123456789',
    'مثال: قارئ الملفات — 0123456789',
  ),
  'settings.ui_text_size_note': (
    'Yazı tipi ve boyutu tüm telefonlarda aynıdır; sistemin yazı boyutu ayarı '
    'uygulamayı etkilemez, yalnız buradan değişir.',
    'Font and size are identical on every phone; the system font-size setting '
    'does not affect the app — change it only here.',
    'الخط والحجم متطابقان على كل الهواتف؛ إعداد حجم خط النظام لا يؤثر على '
    'التطبيق — يُغيَّر من هنا فقط.',
  ),
  'settings.ai_sub': (
    'Gemini anahtarı ve model seçimi',
    'Gemini key and model choice',
    'مفتاح Gemini واختيار النموذج',
  ),
  'settings.memory_sub': (
    'Yapay zekânın hatırlamasını istediğiniz notlar',
    'Notes you want the AI to remember',
    'ملاحظات تريد أن يتذكرها الذكاء الاصطناعي',
  ),
  'settings.perf_section': (
    'Pil ve başarım',
    'Battery & performance',
    'البطارية والأداء',
  ),
  'settings.perf_sub': (
    'Tazeleme hızı ve arka plan taraması',
    'Refresh rate and background scanning',
    'معدل التحديث والفحص في الخلفية',
  ),
  'settings.perf_high_refresh': (
    'Yüksek tazeleme hızı',
    'High refresh rate',
    'معدل تحديث مرتفع',
  ),
  'settings.perf_high_refresh_sub': (
    '120 Hz ekranlarda kaydırma daha akıcı. Kapatınca ekran 60 Hz\'de kalır '
        've pil daha az harcanır.',
    'Smoother scrolling on 120 Hz screens. Turn off to stay at 60 Hz and use '
        'less battery.',
    'تمرير أكثر سلاسة على شاشات 120 هرتز. أوقفه للبقاء عند 60 هرتز وتوفير '
        'البطارية.',
  ),
  'settings.perf_auto_rescan': (
    'Otomatik yeniden tarama',
    'Automatic re-scan',
    'إعادة الفحص التلقائي',
  ),
  'settings.perf_auto_rescan_sub': (
    'Uygulama dışında eklenen dosyalar görünsün diye pano 12 saatte bir tüm '
        'depolamayı tarar. Kapatınca listeleri aşağı çekerek siz tazelersiniz.',
    'The dashboard re-scans all storage every 12 hours so files added outside '
        'the app show up. Turn off and refresh lists yourself by pulling down.',
    'تعيد اللوحة فحص وحدة التخزين كل 12 ساعة لتظهر الملفات المضافة خارج '
        'التطبيق. أوقفه وحدّث القوائم بالسحب للأسفل.',
  ),
  'settings.fm_section': ('Dosya yöneticisi', 'File manager', 'مدير الملفات'),
  'settings.fm_sub': (
    'Küçük resimler, gizli dosyalar, çöp kutusu',
    'Thumbnails, hidden files, trash',
    'الصور المصغّرة والملفات المخفية وسلة المهملات',
  ),
  'settings.fm_open': (
    'Dosya yöneticisi ayarlarını aç',
    'Open file manager settings',
    'فتح إعدادات مدير الملفات',
  ),
  'settings.about_sub': (
    'Sürüm bilgisi ve lisanslar',
    'Version info and licenses',
    'معلومات الإصدار والتراخيص',
  ),
  'settings.theme_system': ('Sistem', 'System', 'النظام'),
  'settings.theme_light': ('Açık', 'Light', 'فاتح'),
  'settings.theme_dark': ('Koyu', 'Dark', 'داكن'),
  'settings.memory': ('AI Kalıcı Hafıza', 'AI long-term memory', 'ذاكرة الذكاء الاصطناعي'),
  'settings.memory_count': ('{n} not', '{n} notes', '{n} ملاحظة'),
  'settings.memory_empty': (
    'Henüz kayıtlı not yok. AI sohbetinde bir yanıtı “Hafızaya kaydet” ile '
        'ekleyebilirsiniz.',
    'No saved notes yet. In the AI chat you can add an answer with “Save to '
        'memory”.',
    'لا توجد ملاحظات محفوظة بعد. يمكنك إضافة إجابة من محادثة الذكاء الاصطناعي '
        'عبر «حفظ في الذاكرة».',
  ),
  'settings.about': ('Hakkında', 'About', 'حول'),
  'settings.about_body': (
    'Dosya Okuyucu • sürüm {version}\n'
        'Çok formatlı, hızlı ve sade dosya okuyucu/düzenleyici.',
    'Dosya Okuyucu • version {version}\n'
        'A fast, simple multi-format file reader/editor.',
    'Dosya Okuyucu • الإصدار {version}\n'
        'قارئ/محرر ملفات سريع وبسيط يدعم صيغًا متعددة.',
  ),
  // ── Gizlilik politikası ve hata kayıtları (2026-08-28) ──────────────────
  'settings.privacy_policy': (
    'Gizlilik politikası',
    'Privacy policy',
    'سياسة الخصوصية',
  ),
  'settings.privacy_policy_sub': (
    'Hangi veri nerede kalır, ne zaman cihazdan çıkar',
    'What stays on the device and when anything leaves it',
    'ما الذي يبقى على الجهاز ومتى يغادره',
  ),
  'settings.crash_log': ('Hata kayıtları', 'Crash reports', 'سجلّات الأعطال'),
  'settings.crash_log_sub': (
    'Cihazda tutulur, kendiliğinden gönderilmez',
    'Kept on the device, never sent automatically',
    'تُحفظ على الجهاز ولا تُرسل تلقائيًا',
  ),
  'settings.crash_log_count': ('{n} kayıt', '{n} reports', '{n} سجل'),
  'settings.crash_log_empty': (
    'Kayıt yok — uygulama bu cihazda hiç hata vermedi.',
    'No reports — the app has not failed on this device.',
    'لا توجد سجلّات — لم يُخفق التطبيق على هذا الجهاز.',
  ),
  'settings.crash_log_note': (
    'Bu metin YALNIZ cihazınızda durur. Paylaş dediğinizde ne gönderdiğinizi '
        'görebilmeniz için tamamı burada gösterilir; hata mesajı dosya adı '
        'içerebilir.',
    'This text stays on your device only. It is shown in full so you can see '
        'what you would send; an error message may contain a file name.',
    'يبقى هذا النص على جهازك فقط. ويُعرض كاملًا لترى ما سترسله؛ فقد تتضمّن '
        'رسالة الخطأ اسم ملف.',
  ),
  'settings.crash_log_cleared': (
    'Hata kayıtları silindi',
    'Crash reports deleted',
    'تم حذف سجلّات الأعطال',
  ),
  'settings.oss': ('Açık kaynak bileşenler', 'Open-source components', 'المكوّنات مفتوحة المصدر'),
  'settings.oss_sub': (
    'Media3, Syncfusion ve diğer lisanslar',
    'Media3, Syncfusion and other licenses',
    'Media3 وSyncfusion وتراخيص أخرى',
  ),

  // ── Dosya yöneticisi: pano ────────────────────────────────────────────────
  'fm.all_files': ('Tüm dosyalar', 'All files', 'كل الملفات'),
  'fm.quick_folders': ('Hızlı klasörler', 'Quick folders', 'مجلدات سريعة'),
  'fm.tools': ('Araçlar', 'Tools', 'الأدوات'),
  'fm.all_tools': ('Tümü ({n})', 'All ({n})', 'الكل ({n})'),
  'fm.recent_opened': ('Son açılanlar', 'Recently opened', 'المفتوحة مؤخرًا'),
  'fm.recent_opened_note': (
    'Her tür dosya',
    'Files of every type',
    'ملفات من كل نوع',
  ),
  'fm.recent_ops': ('Son işlemler', 'Recent operations', 'العمليات الأخيرة'),
  'hist.title': ('Geçmiş', 'History', 'السجل'),
  'hist.tile_sub': ('Açılanlar · üretilenler · işlemler', 'Opened · made · tasks', 'المفتوحة · المُنشأة · العمليات'),
  'hist.opened': ('Açılanlar', 'Opened', 'المفتوحة'),
  'hist.produced': ('Üretilenler', 'Made', 'المُنشأة'),
  'hist.jobs': ('İşlemler', 'Tasks', 'العمليات'),
  'hist.incoming': ('Yeni gelenler', 'Incoming', 'الواردة'),
  'fm.jobs': ('İşlemler', 'Jobs', 'المهام'),
  'fm.jobs_running': ('{n} sürüyor', '{n} running', '{n} قيد التنفيذ'),
  'fm.jobs_finished': ('{n} biten', '{n} finished', '{n} منتهية'),
  'fm.download': ('İndir', 'Download', 'تنزيل'),
  'fm.downloads': ('İndirilenler', 'Downloads', 'التنزيلات'),
  'fm.downloads_missing': (
    'İndirilenler klasörü bulunamadı.',
    'Downloads folder not found.',
    'لم يُعثر على مجلد التنزيلات.',
  ),
  'fm.hero_percent': ('%{n}', '{n}%', '{n}%'),
  'fm.hero_used': (
    '{used} / {total} kullanılıyor',
    '{used} of {total} used',
    'مستخدم {used} من {total}',
  ),
  'fm.hero_browse': ('Göz at', 'Browse', 'تصفح'),
  'fm.hero_analysis': ('Analiz', 'Analysis', 'تحليل'),
  'fm.free_space': ('Yer aç', 'Free up space', 'تحرير مساحة'),
  'fm.similar_images': ('Benzer görsel', 'Similar images', 'صور متشابهة'),
  'ana.similar_note': ('Seri çekimler, neredeyse aynı kareler', 'Bursts and near-identical shots', 'اللقطات المتتالية والصور شبه المتطابقة'),
  'ana.chat_note': ('WhatsApp ve Telegram medyası', 'WhatsApp and Telegram media', 'وسائط واتساب وتيليجرام'),
  'fm.apk_files': ('APK dosyaları', 'APK files', 'ملفات APK'),
  'fm.network_storage': ('Ağ depolama', 'Network storage', 'التخزين الشبكي'),
  'xfer.title': ('Aktar', 'Transfer', 'نقل'),
  'xfer.computer': ('Bilgisayarla', 'With a computer', 'مع حاسوب'),
  'xfer.computer_note': ('Tarayıcıdan ya da FTP ile, QR kodla bağlan', 'From a browser or FTP, connect with a QR code', 'من المتصفح أو FTP، اتصل برمز QR'),
  'xfer.phone': ('Telefonla', 'With a phone', 'مع هاتف'),
  'xfer.phone_note': ('Aynı ağdaki başka bir telefona gönder', 'Send to another phone on the same network', 'أرسل إلى هاتف آخر على نفس الشبكة'),
  'xfer.nas_note': ('FTP, SFTP, SMB, WebDAV bağlantıları', 'FTP, SFTP, SMB, WebDAV connections', 'اتصالات FTP وSFTP وSMB وWebDAV'),
  'xfer.downloads': ('İndirmeler', 'Downloads', 'التنزيلات'),
  'xfer.downloads_note': ('Bağlantıdan dosya indir', 'Download a file from a link', 'نزّل ملفًا من رابط'),
  // "Çöp" yerine "Çöp kutusu": büyük kutuya taşınınca (2026-07-31) tek
  // heceli "Çöp" neyi kastettiğini anlatmıyordu.
  'fm.trash': ('Çöp kutusu', 'Trash', 'المهملات'),
  'fm.trash_count': ('{n} öğe', '{n} items', '{n} عنصر'),
  'fm.trash_empty': ('Boş', 'Empty', 'فارغة'),
  'fm.fm_settings': (
    'Dosya yöneticisi ayarları',
    'File manager settings',
    'إعدادات مدير الملفات',
  ),
  'fm.scanning': ('Taranıyor…', 'Scanning…', 'جارٍ الفحص…'),
  'fm.scanning_storage': (
    'Depolama taranıyor…',
    'Scanning storage…',
    'جارٍ فحص وحدة التخزين…',
  ),
  'fm.no_standard_folders': (
    'Standart klasörler bulunamadı.',
    'Standard folders not found.',
    'لم يُعثر على المجلدات القياسية.',
  ),
  'fm.new_folder': ('Yeni klasör', 'New folder', 'مجلد جديد'),
  'fm.folder_name': ('Klasör adı', 'Folder name', 'اسم المجلد'),
  'fm.create': ('Oluştur', 'Create', 'إنشاء'),
  'fm.folder_create_failed': (
    'Klasör oluşturulamadı: {error}',
    'Could not create folder: {error}',
    'تعذّر إنشاء المجلد: {error}',
  ),
  'fm.permission_title': (
    'Tüm dosyalara erişim gerekli',
    'All-files access is required',
    'مطلوب الوصول إلى كل الملفات',
  ),
  'fm.permission_body': (
    'Telefonundaki tüm klasörleri görebilmek, kopyalayıp taşıyabilmek için '
        'Android’in “Tüm dosyalara erişim” iznini vermen gerekiyor. İzin '
        'yalnızca cihazda kullanılır; hiçbir veri gönderilmez.',
    'To see, copy and move every folder on your phone, Android’s “All files '
        'access” permission is required. The permission is used only on the '
        'device; no data is sent anywhere.',
    'لرؤية جميع المجلدات على هاتفك ونسخها ونقلها، يلزم إذن «الوصول إلى كل '
        'الملفات» من Android. يُستخدم الإذن على الجهاز فقط ولا تُرسل أي بيانات.',
  ),
  'fm.permission_denied': (
    'Tüm dosyalara erişim verilmedi — yalnızca izin verilen klasörler görünür.',
    'All-files access was not granted — only permitted folders are shown.',
    'لم يُمنح الوصول إلى كل الملفات — تظهر المجلدات المسموح بها فقط.',
  ),
  'fm.permission_grant': ('İzin ver', 'Grant permission', 'منح الإذن'),

  'fm.internal_storage': ('Ana bellek', 'Internal storage', 'الذاكرة الداخلية'),
  'fm.none': ('Yok', 'None', 'لا شيء'),
  'fm.organize': ('Düzenle', 'Organize', 'تنظيم'),

  // ── Dosya yöneticisi: gezgin ──────────────────────────────────────────────
  'fm.root': ('Kök', 'Root', 'الجذر'),
  'fm.other': ('Diğer', 'Other', 'أخرى'),
  'fm.empty_folder': ('Bu klasör boş', 'This folder is empty', 'هذا المجلد فارغ'),
  'fm.search_here': ('Bu klasörde ara', 'Search in this folder', 'ابحث في هذا المجلد'),
  'fm.unreadable': (
    'Bu klasör okunamadı.\nAndroid’in koruduğu bir konum olabilir '
        '(Android/data gibi) ya da “tüm dosyalara erişim” izni verilmemiş olabilir.',
    'This folder could not be read.\nIt may be a location Android protects '
        '(such as Android/data), or “all files access” may not be granted.',
    'تعذّرت قراءة هذا المجلد.\nقد يكون موقعًا يحميه Android (مثل Android/data) '
        'أو أن إذن «الوصول إلى كل الملفات» غير ممنوح.',
  ),
  'fm.locked_folder': ('Kilitli klasör', 'Locked folder', 'مجلد مقفل'),
  'fm.locked_prompt': (
    'Bu klasör kilitli.\nGörmek için PIN girin.',
    'This folder is locked.\nEnter the PIN to view it.',
    'هذا المجلد مقفل.\nأدخل رمز PIN لعرضه.',
  ),
  'fm.lock_folder': ('Klasörü kilitle (PIN)', 'Lock folder (PIN)', 'قفل المجلد (PIN)'),
  'fm.unlock_folder': ('Klasör kilidini kaldır', 'Unlock folder', 'إلغاء قفل المجلد'),
  'fm.unfavorite': ('Favorilerden çıkar', 'Remove from favourites', 'إزالة من المفضلة'),
  'fm.favorite': ('Favorilere ekle', 'Add to favourites', 'إضافة إلى المفضلة'),
  'fm.show_hidden': ('Gizli dosyaları göster', 'Show hidden files', 'إظهار الملفات المخفية'),
  'fm.hide_hidden': ('Gizli dosyaları gizle', 'Hide hidden files', 'إخفاء الملفات المخفية'),
  'fm.layout': ('Görünüm: {name}', 'Layout: {name}', 'العرض: {name}'),
  'fm.sort_name': ('Ada göre sırala', 'Sort by name', 'ترتيب حسب الاسم'),
  'fm.sort_date': ('Tarihe göre sırala', 'Sort by date', 'ترتيب حسب التاريخ'),
  'fm.sort_size': ('Boyuta göre sırala', 'Sort by size', 'ترتيب حسب الحجم'),
  'fm.sort_type': ('Türe göre sırala', 'Sort by type', 'ترتيب حسب النوع'),
  'fm.sort_asc': ('Artan sırala', 'Ascending', 'تصاعدي'),
  'fm.sort_desc': ('Azalan sırala', 'Descending', 'تنازلي'),
  'fm.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'fm.select_none': ('Seçimi kaldır', 'Clear selection', 'إلغاء التحديد'),
  'fm.select_invert': ('Seçimi tersine çevir', 'Invert selection', 'عكس التحديد'),
  'fm.select_above': ('Üstündekileri de seç', 'Also select above', 'حدّد ما فوقه أيضًا'),
  'fm.select_below': ('Altındakileri de seç', 'Also select below', 'حدّد ما تحته أيضًا'),
  'fm.selected_count': ('{n} / {total} seçildi', '{n} / {total} selected', 'تم تحديد {n} / {total}'),
  'fm.new_name': ('Yeni ad', 'New name', 'الاسم الجديد'),
  'fm.irreversible': (
    'Bu işlem geri alınamaz.',
    'This cannot be undone.',
    'لا يمكن التراجع عن هذا.',
  ),
  'fm.new_folder_or_file': ('Yeni klasör / dosya', 'New folder / file', 'مجلد / ملف جديد'),
  'fm.new_text_file': ('Metin dosyası (.txt)', 'Text file (.txt)', 'ملف نصي (.txt)'),
  'fm.file_name': ('Dosya adı', 'File name', 'اسم الملف'),
  'fm.file_create_failed': (
    'Dosya oluşturulamadı: {error}',
    'Could not create file: {error}',
    'تعذّر إنشاء الملف: {error}',
  ),
  'fm.auto_organize': ('Otomatik düzenle…', 'Auto-organize…', 'تنظيم تلقائي…'),
  'fm.paste': ('Yapıştır', 'Paste', 'لصق'),
  'paste.conflict_title': (
    'Hedefte {n} dosya zaten var',
    '{n} files already exist here',
    'يوجد {n} ملف بالفعل هنا',
  ),
  'paste.conflict_more': (
    '{names} ve {n} dosya daha',
    '{names} and {n} more',
    '{names} و{n} ملفات أخرى',
  ),
  'paste.keep_both': ('İkisini de tut', 'Keep both', 'الاحتفاظ بالاثنين'),
  'paste.keep_both_sub': (
    'Yenisine “(1)” eklenir, hiçbir şey silinmez',
    'The new one gets “(1)”; nothing is deleted',
    'يُضاف “(1)” إلى الجديد ولا يُحذف شيء',
  ),
  'paste.skip': ('Bu dosyaları atla', 'Skip these files', 'تخطي هذه الملفات'),
  'paste.skip_sub': (
    'Hedefteki dosyalar olduğu gibi kalır',
    'The files already here stay as they are',
    'تبقى الملفات الموجودة كما هي',
  ),
  'paste.overwrite': ('Üzerine yaz', 'Overwrite', 'استبدال'),
  'paste.overwrite_sub': (
    'Hedefteki dosyalar silinir — geri alınamaz',
    'The files already here are replaced — cannot be undone',
    'تُستبدل الملفات الموجودة — لا يمكن التراجع',
  ),
  'fm.clipboard_ready': (
    '{n} öğe {verb} hazır',
    '{n} items ready to {verb}',
    '{n} عنصر جاهز لـ{verb}',
  ),
  'fm.verb_move': ('taşınmaya', 'move', 'النقل'),
  'fm.verb_copy': ('kopyalanmaya', 'copy', 'النسخ'),
  'fm.copying': ('Kopyalanıyor', 'Copying', 'جارٍ النسخ'),
  'fm.moving': ('Taşınıyor', 'Moving', 'جارٍ النقل'),
  'fm.transfer_partial': (
    'Bazı öğeler aktarılamadı: {error}',
    'Some items could not be transferred: {error}',
    'تعذّر نقل بعض العناصر: {error}',
  ),
  'fm.transfer_cancelled': (
    'İşlem iptal edildi (aktarılanlar yerinde kaldı).',
    'The operation was cancelled (transferred items stayed in place).',
    'تم إلغاء العملية (بقيت العناصر المنقولة في مكانها).',
  ),

  // ── Denetim turu 2026-09-06: özet, EXIF, bölme, boş klasör, yedek ─────────
  'peer.speed': ('{done} / {total} · {speed}/sn', '{done} / {total} · {speed}/s', '{done} / {total} · {speed}/ث'),

  'fm.ext_changed_title': ('Uzantı değişiyor', 'Extension is changing', 'الامتداد يتغير'),
  'fm.ext_changed_body': (
    '"{old}" → "{new}". Uzantı dosyanın türünü belirler; değiştirirsen dosya '
    'yanlış uygulamada açılabilir ya da hiç açılmayabilir.',
    '"{old}" → "{new}". The extension decides the file type; changing it may '
    'open the file in the wrong app, or not at all.',
    '"{old}" ← "{new}". يحدد الامتداد نوع الملف؛ قد يفتح الملف في تطبيق خاطئ '
    'أو لا يفتح إطلاقًا.',
  ),
  'fm.ext_changed_keep': ('Uzantıyı koru', 'Keep the extension', 'الاحتفاظ بالامتداد'),
  'fm.ext_changed_go': ('Yine de değiştir', 'Change anyway', 'التغيير على أي حال'),

  'clean.free_amount': ('{size} yer aç', 'Free up {size}', 'توفير {size}'),
  'prop.contents': ('İçerik', 'Contents', 'المحتويات'),
  'prop.contents_value': (
    '{files} dosya, {dirs} klasör',
    '{files} files, {dirs} folders',
    '{files} ملف، {dirs} مجلد',
  ),
  'fm.compare_digest': ('İki dosya aynı mı?', 'Are the two files identical?', 'هل الملفان متطابقان؟'),
  'fm.compare_running': ('Karşılaştırılıyor', 'Comparing', 'جارٍ المقارنة'),
  'fm.compare_same': (
    'Dosyalar AYNI (SHA-256 eşleşti)',
    'The files are IDENTICAL (SHA-256 matched)',
    'الملفان متطابقان (تطابقت SHA-256)',
  ),
  'fm.compare_diff': (
    'Dosyalar FARKLI',
    'The files are DIFFERENT',
    'الملفان مختلفان',
  ),
  'lock.app_wait': (
    'Çok fazla deneme — {n} saniye bekleyin',
    'Too many attempts — wait {n} seconds',
    'محاولات كثيرة — انتظر {n} ثانية',
  ),

  'dl.verify': ('Özeti doğrula (SHA-256)', 'Verify checksum (SHA-256)', 'التحقق من البصمة (SHA-256)'),
  'dl.verify_paste': (
    'Yayıncının verdiği SHA-256 özetini yapıştırın',
    'Paste the SHA-256 checksum published by the source',
    'الصق بصمة SHA-256 التي نشرها المصدر',
  ),
  'dl.verify_running': ('Dosya okunuyor…', 'Reading the file…', 'جارٍ قراءة الملف…'),
  'dl.verify_ok': (
    'Özet TUTUYOR — dosya bozulmamış',
    'Checksum MATCHES — the file is intact',
    'البصمة مطابقة — الملف سليم',
  ),
  'dl.verify_bad': (
    'Özet TUTMUYOR — dosya eksik ya da değiştirilmiş',
    'Checksum does NOT match — the file is incomplete or altered',
    'البصمة غير مطابقة — الملف ناقص أو مُعدّل',
  ),

  'prop.encoding': ('Kodlama', 'Encoding', 'الترميز'),

  'vw.prettify': ('Biçimlendir (JSON/XML)', 'Format (JSON/XML)', 'تنسيق (JSON/XML)'),
  'vw.prettify_done': ('Biçimlendirildi', 'Formatted', 'تم التنسيق'),
  'vw.prettify_failed': (
    'Bu dosya çözümlenemedi — metin değiştirilmedi',
    'Could not parse this file — the text was left as is',
    'تعذّر تحليل هذا الملف — لم يتم تغيير النص',
  ),
  'vw.wrap_on': ('Satırları kaydır', 'Wrap lines', 'التفاف الأسطر'),
  'vw.wrap_off': ('Satırları kaydırma', "Don't wrap lines", 'عدم التفاف الأسطر'),

  'srch.in_content': ('Dosya içinde ara', 'Search inside files', 'البحث داخل الملفات'),
  'srch.content_running': ('Dosyaların içine bakılıyor…', 'Looking inside files…', 'جارٍ البحث داخل الملفات…'),
  'srch.content_hits': ('{n} eşleşme · {line}. satır', '{n} matches · line {line}', '{n} تطابق · السطر {line}'),
  'srch.content_none': (
    'İçinde bu metin geçen dosya bulunamadı (yalnız metin biçimlerine bakılır).',
    'No file contains that text (only text formats are searched).',
    'لا يوجد ملف يحتوي على هذا النص (يتم البحث في الصيغ النصية فقط).',
  ),
  'srch.content_hint': (
    'Yalnız metin biçimleri (.txt .csv .log .json .md …), dosya başına 2 MB',
    'Text formats only (.txt .csv .log .json .md …), 2 MB per file',
    'الصيغ النصية فقط (.txt .csv .log .json .md …)، 2 ميغابايت لكل ملف',
  ),

  'report.folder': ('Klasör', 'Folder', 'مجلد'),
  'report.header': (
    'Ad;Tür;Boyut (bayt);Değiştirilme',
    'Name;Type;Size (bytes);Modified',
    'الاسم;النوع;الحجم (بايت);التعديل',
  ),
  'report.summary': (
    '{dirs} klasör, {files} dosya',
    '{dirs} folders, {files} files',
    '{dirs} مجلد، {files} ملف',
  ),

  'mp.playlist_save': ('Çalma listesini kaydet', 'Save playlist', 'حفظ قائمة التشغيل'),
  'mp.playlist_open': ('Çalma listesi aç', 'Open playlist', 'فتح قائمة تشغيل'),
  'mp.playlist_saved': ('{name} kaydedildi', 'Saved {name}', 'تم حفظ {name}'),
  'mp.playlist_loaded': (
    '{n} parça yüklendi ({missing} bulunamadı)',
    '{n} tracks loaded ({missing} missing)',
    'تم تحميل {n} مقطع ({missing} غير موجود)',
  ),
  'mp.playlist_empty': (
    'Listede çalınabilir dosya yok',
    'No playable files in the list',
    'لا توجد ملفات قابلة للتشغيل في القائمة',
  ),
  'mp.playlist_name': ('Liste adı', 'Playlist name', 'اسم القائمة'),
  'mp.sub_delay_saved': (
    'Altyazı gecikmesi bu dosya için hatırlanacak',
    'Subtitle delay will be remembered for this file',
    'سيتم تذكّر تأخير الترجمة لهذا الملف',
  ),

  'peer.code_label': ('Eşleştirme kodu', 'Pairing code', 'رمز الاقتران'),
  'peer.code_ask': (
    'Karşı cihazda yazan 4 haneli kodu girin',
    'Enter the 4-digit code shown on the other device',
    'أدخل الرمز المكوّن من 4 أرقام الظاهر على الجهاز الآخر',
  ),
  'peer.code_wrong': (
    'Kod yanlış — dosya gönderilmedi',
    'Wrong code — nothing was sent',
    'الرمز غير صحيح — لم يتم الإرسال',
  ),
  'peer.code_on': (
    'Kod istensin (aynı ağdaki herkes gönderemesin)',
    'Require a code (so not everyone on the network can send)',
    'اطلب رمزًا (حتى لا يتمكن الجميع على الشبكة من الإرسال)',
  ),
  'peer.folder_zipping': (
    'Klasör sıkıştırılıyor',
    'Compressing folder',
    'جارٍ ضغط المجلد',
  ),
  'peer.folders_zipped': (
    '{n} klasör ZIP olarak gönderiliyor',
    'Sending {n} folder(s) as ZIP',
    'يتم إرسال {n} مجلد كملف ZIP',
  ),
  'peer.notify_title': ('Dosya alındı', 'File received', 'تم استلام ملف'),
  'peer.channel_name': ('Yakındaki cihaz', 'Nearby device', 'جهاز قريب'),
  'peer.channel_desc': (
    'Yakındaki bir cihazdan dosya alındığında.',
    'When a file is received from a nearby device.',
    'عند استلام ملف من جهاز قريب.',
  ),
  'peer.recent_devices': ('Son cihazlar', 'Recent devices', 'الأجهزة الأخيرة'),

  'backup.title': ('Ayarları yedekle', 'Back up settings', 'نسخ الإعدادات احتياطيًا'),
  'backup.sub': (
    'Tema, dil, yer imleri ve tercihler tek dosyaya. API anahtarları ve '
    'PIN\'ler yedeğe GİRMEZ.',
    'Theme, language, bookmarks and preferences in one file. API keys and '
    'PINs are NOT included.',
    'السمة واللغة والإشارات المرجعية والتفضيلات في ملف واحد. مفاتيح API '
    'ورموز PIN غير مضمّنة.',
  ),
  'backup.saved': ('Yedek kaydedildi: {name}', 'Backup saved: {name}', 'تم حفظ النسخة: {name}'),
  'backup.failed': ('Yedeklenemedi: {error}', 'Backup failed: {error}', 'فشل النسخ: {error}'),
  'backup.restore': ('Yedekten geri yükle', 'Restore from backup', 'استعادة من نسخة'),
  'backup.restore_sub': (
    'Yedekteki ayarlar geri gelir; yedekte olmayanlar olduğu gibi kalır.',
    'Settings from the backup are restored; anything not in it stays as is.',
    'تُستعاد الإعدادات من النسخة؛ ما ليس فيها يبقى كما هو.',
  ),
  'backup.restored': (
    '{n} ayar geri yüklendi. Bazıları uygulama yeniden açılınca geçerli olur.',
    '{n} settings restored. Some take effect after restarting the app.',
    'تمت استعادة {n} إعداد. يسري بعضها بعد إعادة تشغيل التطبيق.',
  ),
  'backup.restore_failed': (
    'Geri yüklenemedi: {error}',
    'Restore failed: {error}',
    'فشلت الاستعادة: {error}',
  ),
  'lock.app_title': ('Uygulama kilidi', 'App lock', 'قفل التطبيق'),
  'lock.app_sub_on': (
    'Uygulama açılırken PIN sorulur.',
    'A PIN is asked when the app opens.',
    'يُطلب رمز PIN عند فتح التطبيق.',
  ),
  'lock.app_sub_off': (
    'Kapalı — uygulama doğrudan açılıyor.',
    'Off — the app opens directly.',
    'مغلق — يفتح التطبيق مباشرة.',
  ),
  'lock.app_prompt': ('PIN girin', 'Enter PIN', 'أدخل رمز PIN'),
  'lock.app_wrong': ('PIN yanlış', 'Wrong PIN', 'رمز PIN غير صحيح'),
  'lock.app_needs_pin': (
    'Önce bir PIN belirleyin (Gizlilik > Klasör kilidi PIN\'i).',
    'Set a PIN first (Privacy > Folder lock PIN).',
    'عيّن رمز PIN أولاً (الخصوصية > رمز قفل المجلد).',
  ),

  'vw.replace_with': ('Şununla değiştir', 'Replace with', 'استبدال بـ'),
  'vw.replace_one': ('Değiştir', 'Replace', 'استبدال'),
  'vw.replace_all': ('Tümünü değiştir', 'Replace all', 'استبدال الكل'),
  'vw.replaced': ('{n} değişiklik yapıldı', '{n} replacements made', 'تم إجراء {n} استبدال'),
  'vw.replace_none': ('Değiştirilecek bir şey bulunamadı', 'Nothing to replace', 'لا يوجد ما يُستبدل'),
  'vw.show_replace': ('Değiştirmeyi aç/kapat', 'Toggle replace', 'إظهار/إخفاء الاستبدال'),
  'vw.goto_line': ('Satıra git', 'Go to line', 'الانتقال إلى سطر'),
  'vw.line_number': ('Satır numarası (1-{max})', 'Line number (1-{max})', 'رقم السطر (1-{max})'),
  'vw.line_numbers': ('Satır numaraları', 'Line numbers', 'أرقام الأسطر'),
  'vw.line_ending': ('Satır sonu', 'Line ending', 'نهاية السطر'),

  'ea.rotate': ('Döndür', 'Rotate', 'تدوير'),
  'ea.rotate_hint': ('90° sağa · yeni dosya', '90° right · new file', '90° يمينًا · ملف جديد'),
  'ea.split': ('Parçalara böl', 'Split into parts', 'تقسيم إلى أجزاء'),
  'ea.split_hint': ('FAT32 / e-posta sınırı', 'FAT32 / email limit', 'حد FAT32 / البريد'),
  'ea.join': ('Parçaları birleştir', 'Join parts', 'دمج الأجزاء'),
  'ea.join_hint': ('.001 .002 …', '.001 .002 …', '.001 .002 …'),
  'split.title': ('Parçalara böl', 'Split into parts', 'تقسيم إلى أجزاء'),
  'split.pick_size': ('Parça boyutu', 'Part size', 'حجم الجزء'),
  'split.working': ('Bölünüyor', 'Splitting', 'جارٍ التقسيم'),
  'split.done': ('{n} parça oluştu', '{n} parts created', 'تم إنشاء {n} جزء'),
  'split.cancelled': ('Bölme durduruldu', 'Splitting stopped', 'تم إيقاف التقسيم'),
  'split.too_small': (
    'Dosya seçilen parça boyutundan küçük — bölmeye gerek yok.',
    'The file is smaller than the chosen part size — no need to split.',
    'الملف أصغر من حجم الجزء المختار — لا حاجة للتقسيم.',
  ),
  'join.working': ('Birleştiriliyor', 'Joining', 'جارٍ الدمج'),
  'join.done': ('{name} oluştu', '{name} created', 'تم إنشاء {name}'),
  'join.failed': ('Birleştirilemedi: {error}', 'Could not join: {error}', 'تعذر الدمج: {error}'),
  'rotate.working': ('Döndürülüyor…', 'Rotating…', 'جارٍ التدوير…'),
  'rotate.done': ('{name} kaydedildi', 'Saved {name}', 'تم حفظ {name}'),
  'rotate.failed': ('Döndürülemedi: {error}', 'Could not rotate: {error}', 'تعذر التدوير: {error}'),
  'fm.empty_folders': ('Boş klasörleri temizle', 'Clean empty folders', 'تنظيف المجلدات الفارغة'),
  'fm.empty_scanning': ('Boş klasörler aranıyor…', 'Looking for empty folders…', 'جارٍ البحث عن المجلدات الفارغة…'),
  'fm.empty_none': ('Boş klasör yok.', 'No empty folders.', 'لا توجد مجلدات فارغة.'),
  'fm.empty_found': (
    '{n} boş klasör bulundu. Silinsin mi?',
    '{n} empty folders found. Delete them?',
    'تم العثور على {n} مجلد فارغ. هل تريد حذفها؟',
  ),
  'fm.empty_deleted': ('{n} boş klasör silindi', '{n} empty folders deleted', 'تم حذف {n} مجلد فارغ'),
  'fm.export_list': ('Listeyi dışa aktar', 'Export listing', 'تصدير القائمة'),
  'fm.export_text': ('Metin (.txt)', 'Text (.txt)', 'نص (.txt)'),
  'fm.export_csv': ('Tablo (.csv)', 'Spreadsheet (.csv)', 'جدول (.csv)'),
  'fm.export_done': ('{name} kaydedildi', 'Saved {name}', 'تم حفظ {name}'),

  'prop.name': ('Ad', 'Name', 'الاسم'),
  'prop.size': ('Boyut', 'Size', 'الحجم'),
  'prop.location': ('Konum', 'Location', 'الموقع'),
  'prop.digest': ('Özet (SHA-256)', 'Checksum (SHA-256)', 'البصمة (SHA-256)'),
  'prop.digest_md5': ('Özet (MD5)', 'Checksum (MD5)', 'البصمة (MD5)'),
  'prop.compute_digest': ('Özeti hesapla', 'Compute checksum', 'حساب البصمة'),
  'prop.computing_digest': ('Hesaplanıyor…', 'Computing…', 'جارٍ الحساب…'),
  'prop.digest_copied': ('Özet panoya kopyalandı', 'Checksum copied', 'تم نسخ البصمة'),
  'prop.photo_info': ('Fotoğraf bilgileri', 'Photo details', 'تفاصيل الصورة'),
  'prop.taken_at': ('Çekim tarihi', 'Taken', 'تاريخ الالتقاط'),
  'prop.camera': ('Kamera', 'Camera', 'الكاميرا'),
  'prop.lens': ('Objektif', 'Lens', 'العدسة'),
  'prop.resolution': ('Çözünürlük', 'Resolution', 'الدقة'),
  'prop.iso': ('ISO', 'ISO', 'ISO'),
  'prop.exposure': ('Poz', 'Exposure', 'التعريض'),
  'prop.aperture': ('Diyafram', 'Aperture', 'فتحة العدسة'),
  'prop.focal': ('Odak uzaklığı', 'Focal length', 'البعد البؤري'),
  'prop.flash': ('Flaş', 'Flash', 'الفلاش'),
  'prop.flash_on': ('Kullanıldı', 'Fired', 'تم استخدامه'),
  'prop.flash_off': ('Kullanılmadı', 'Did not fire', 'لم يُستخدم'),
  'prop.software': ('Yazılım', 'Software', 'البرنامج'),
  'prop.copy_name': ('Adı kopyala', 'Copy name', 'نسخ الاسم'),

  // ── Çizim hatası kurtarma ekranı (bkz. widgets/app_error_screen.dart) ─────
  'err.render_failed': (
    'Bu ekran çizilemedi',
    'This screen could not be drawn',
    'تعذر رسم هذه الشاشة',
  ),
  'err.render_logged': (
    'Hata kaydedildi (Ayarlar > Hata kayıtları).\nÖnceki ekrana dönebilirsiniz.',
    'The error was logged (Settings > Error logs).\nYou can go back to the '
        'previous screen.',
    'تم تسجيل الخطأ (الإعدادات > سجلات الأخطاء).\nيمكنك العودة إلى الشاشة '
        'السابقة.',
  ),
  'err.go_back': ('Geri dön', 'Go back', 'رجوع'),
  'err.go_home': ('Ana ekran', 'Home', 'الشاشة الرئيسية'),

  // ── Yakındaki cihaza gönder (iki Dosya Okuyucu arası) ─────────────────────
  'peer.title': ('Yakındaki cihaz', 'Nearby device', 'جهاز قريب'),
  'peer.send_action': (
    'Yakındaki cihaza gönder',
    'Send to nearby device',
    'إرسال إلى جهاز قريب',
  ),
  'peer.send_hint': (
    'Aynı Wi-Fi\'deki Dosya Okuyucu\'ya doğrudan',
    'Straight to Dosya Okuyucu on the same Wi-Fi',
    'مباشرة إلى Dosya Okuyucu على نفس شبكة Wi-Fi',
  ),
  'peer.tab_send': ('Gönder', 'Send', 'إرسال'),
  'peer.tab_receive': ('Al', 'Receive', 'استقبال'),
  'peer.searching': ('Cihazlar aranıyor…', 'Looking for devices…', 'جارٍ البحث عن الأجهزة…'),
  'peer.search_again': ('Yeniden ara', 'Search again', 'إعادة البحث'),
  'peer.none_found': (
    'Cihaz bulunamadı. Karşı telefonda Dosya Okuyucu > Yakındaki cihaz > Al '
    'ekranı açık olmalı ve iki cihaz aynı Wi-Fi ağında olmalı.',
    'No device found. On the other phone open Dosya Okuyucu > Nearby device > '
    'Receive, and make sure both are on the same Wi-Fi network.',
    'لم يتم العثور على جهاز. افتح في الهاتف الآخر Dosya Okuyucu > جهاز قريب > '
    'استقبال، وتأكد من أن الجهازين على نفس شبكة Wi-Fi.',
  ),
  'peer.files_to_send': (
    '{n} dosya gönderilecek',
    '{n} file(s) to send',
    'سيتم إرسال {n} ملف',
  ),
  'peer.sending': ('Gönderiliyor', 'Sending', 'جارٍ الإرسال'),
  'peer.sent': (
    '{n} dosya {name} cihazına gönderildi',
    'Sent {n} file(s) to {name}',
    'تم إرسال {n} ملف إلى {name}',
  ),
  'peer.send_failed': (
    'Gönderilemedi: {error}',
    'Could not send: {error}',
    'تعذر الإرسال: {error}',
  ),
  'peer.send_stopped': (
    'Durduruldu ({n} dosya gitti)',
    'Stopped ({n} file(s) sent)',
    'تم الإيقاف (تم إرسال {n} ملف)',
  ),
  'peer.receiving_on': (
    'Alınmaya hazır',
    'Ready to receive',
    'جاهز للاستقبال',
  ),
  'peer.receiving_off': ('Kapalı', 'Off', 'مغلق'),
  'peer.receive_explain': (
    'Bu ekran açıkken aynı Wi-Fi ağındaki Dosya Okuyucu\'lar bu cihaza dosya '
    'gönderebilir. Ekranı kapatınca kapanır.',
    'While this screen is open, Dosya Okuyucu apps on the same Wi-Fi can send '
    'files here. It closes when you leave the screen.',
    'أثناء فتح هذه الشاشة، يمكن لتطبيقات Dosya Okuyucu على نفس شبكة Wi-Fi '
    'إرسال ملفات إلى هنا. يتوقف عند مغادرة الشاشة.',
  ),
  'peer.receive_warning': (
    'Aktarım şifrelenmez — halka açık ağlarda kullanmayın.',
    'Transfers are not encrypted — avoid public networks.',
    'النقل غير مشفر — تجنب الشبكات العامة.',
  ),
  'peer.save_to': ('Kayıt yeri: {path}', 'Saved to: {path}', 'مكان الحفظ: {path}'),
  'peer.change_folder': ('Klasörü değiştir', 'Change folder', 'تغيير المجلد'),
  'peer.device_name': ('Bu cihazın adı', 'This device\'s name', 'اسم هذا الجهاز'),
  'peer.received': ('{name} alındı', 'Received {name}', 'تم استلام {name}'),
  'peer.received_from': ('{name} · {from} cihazından', '{name} · from {from}', '{name} · من {from}'),
  'peer.nothing_received': (
    'Henüz dosya gelmedi.',
    'No files yet.',
    'لا توجد ملفات بعد.',
  ),
  'peer.address_hint': (
    'Cihaz görünmüyorsa karşı taraftaki adresi elle yazın',
    'If the device does not appear, type its address manually',
    'إذا لم يظهر الجهاز، اكتب عنوانه يدويًا',
  ),
  'peer.address': ('Adres (192.168.1.42)', 'Address (192.168.1.42)', 'العنوان (192.168.1.42)'),
  'peer.connect': ('Bağlan', 'Connect', 'اتصال'),
  'peer.not_found_at': (
    'Bu adreste Dosya Okuyucu bulunamadı',
    'No Dosya Okuyucu found at that address',
    'لم يتم العثور على Dosya Okuyucu على هذا العنوان',
  ),
  'peer.this_device': ('Bu cihaz: {name}', 'This device: {name}', 'هذا الجهاز: {name}'),
  'peer.other_apps': (
    'WhatsApp, Bluetooth, e-posta…',
    'WhatsApp, Bluetooth, email…',
    'واتساب، بلوتوث، بريد…',
  ),

  // ── Dosya yöneticisi: seçim çubuğu ────────────────────────────────────────
  'fm.copy': ('Kopyala', 'Copy', 'نسخ'),
  'fm.clip_copy': ('Panoya kopyala', 'Copy to clipboard', 'نسخ إلى الحافظة'),
  'fm.clip_cut': ('Panoya kes', 'Cut to clipboard', 'قص إلى الحافظة'),
  'fm.move': ('Taşı', 'Move', 'نقل'),
  'fm.rename': ('Yeniden adlandır', 'Rename', 'إعادة تسمية'),
  'fm.batch_rename': (
    'Toplu yeniden adlandır',
    'Batch rename',
    'إعادة تسمية جماعية',
  ),
  'fm.compress': ('Sıkıştır (ZIP/7z)', 'Compress (ZIP/7z)', 'ضغط (ZIP/7z)'),
  'fm.resize': (
    'Boyut düşür (çözünürlük/kare sayısı)',
    'Reduce size (resolution / frame rate)',
    'تصغير الحجم (الدقة/معدل الإطارات)',
  ),
  'fm.tag': ('Etiketle (kişi/grup)', 'Tag (person/group)', 'وسم (شخص/مجموعة)'),
  'fm.copy_to_important': (
    'Önemli dosyalara kopyala',
    'Copy to important files',
    'نسخ إلى الملفات المهمة',
  ),
  // "Paylaşılan"a kopyala — ağ paylaşımının dar kapsamlı kutusu (kullanıcı
  // isteği 2026-08-31: *"dosyaların 3 nokta ayarında paylaşılan'a kopyala
  // seçeneği olsun"*). Taşımak DEĞİL kopyalamak: dosya kullanıcının bildiği
  // yerde (DCIM, Belgeler) kalmalı — "Önemli dosyalar"daki karar ile aynı.
  'fm.copy_to_shared': (
    'Paylaşılan\'a kopyala',
    'Copy to Shared',
    'نسخ إلى المشترك',
  ),
  'fm.properties': ('Özellikler', 'Properties', 'الخصائص'),
  'fm.more_actions': ('Diğer işlemler', 'More actions', 'إجراءات أخرى'),
  'fm.more': ('Daha fazla', 'More', 'المزيد'),
  'fm.clipboard_copied': (
    'Panoya kopyalandı. Hedef klasörde “Yapıştır”a dokunun.',
    'Copied to clipboard. Tap “Paste” in the destination folder.',
    'تم النسخ إلى الحافظة. اضغط «لصق» في المجلد الوجهة.',
  ),
  'fm.clipboard_cut': (
    'Panoya kesildi. Hedef klasörde “Yapıştır”a dokunun.',
    'Cut to clipboard. Tap “Paste” in the destination folder.',
    'تم القص إلى الحافظة. اضغط «لصق» في المجلد الوجهة.',
  ),

  // ── Dosya yöneticisi: girdi işlemleri (uzun basış) ────────────────────────
  // İşlem sayfasının bölüm başlıkları ve KISA etiketleri (iki sütunlu
  // ızgarada uzun etiket ikinci satıra taşıp kutuyu şişiriyordu; parantezli
  // açıklama artık etiketin altında soluk ipucu satırı).
  'ea.sec_open': ('Aç ve paylaş', 'Open & share', 'فتح ومشاركة'),
};
