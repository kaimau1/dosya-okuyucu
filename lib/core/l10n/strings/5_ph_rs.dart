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
  'ph.albums_hide': ('Albüm alanını gizle', 'Hide albums area', 'إخفاء منطقة الألبومات'),
  'ph.albums_show': ('Albüm alanını göster', 'Show albums area', 'إظهار منطقة الألبومات'),
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

  // ── PDF formu doldurma ────────────────────────────────────────────────────
  'pf.title': ('Formu doldur — {name}', 'Fill form — {name}', 'تعبئة النموذج — {name}'),
  'pf.save': ('Doldur ve kaydet', 'Fill and save', 'تعبئة وحفظ'),
  'pf.page': ('Sayfa {n}', 'Page {n}', 'الصفحة {n}'),
  'pf.other_fields': ('Diğer alanlar', 'Other fields', 'حقول أخرى'),
  'pf.read_only': ('salt okunur', 'read-only', 'للقراءة فقط'),
  'pf.sign_tap': ('İmzalamak için dokunun', 'Tap to sign', 'انقر للتوقيع'),
  'pf.signed': (
    'İmzalandı — kaydedince alana basılır',
    'Signed — stamped into the field on save',
    'تم التوقيع — يُختم في الحقل عند الحفظ',
  ),
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
    'Boyutlandır ({n} dosya)',
    'Resize ({n} files)',
    'تغيير الحجم ({n} ملف)',
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
  'rs.jpeg_quality': ('JPEG kalitesi (fotoğraf)', 'JPEG quality (photos)', 'جودة JPEG (الصور)'),
  'rs.format': ('Biçim (fotoğraf)', 'Format (photos)', 'الصيغة (الصور)'),
  'rs.video_quality': ('Video sıkıştırma', 'Video compression', 'ضغط الفيديو'),
  'rs.fps': ('Kare sayısı (fps)', 'Frame rate (fps)', 'معدّل الإطارات (fps)'),
  'rs.keep': ('Değiştirme', 'Keep as is', 'دون تغيير'),
  'rs.video_note': (
    'Video her durumda yeniden kodlanır (kalite ya da ses değişse de): '
        'istediğin ölçüye birebir dönüştürülür, cihazın donanım kodlayıcısıyla '
        '(Android Media3). Yüzde ve kalan süre işlem satırında yazar. Uzun bir '
        'videoda bu dakikalar sürebilir; işlem arka planda koşar.',
    'Video is always re-encoded (even if only the quality or audio changes): '
        'it is converted exactly to the size you asked for, using the '
        'device’s hardware encoder (Android Media3). The percentage and '
        'remaining time are shown on the job row. On a long video this can '
        'take minutes; the job runs in the background.',
    'يُعاد ترميز الفيديو دائمًا (حتى لو تغيّرت الجودة أو الصوت فقط): يُحوَّل '
        'تمامًا إلى المقاس المطلوب باستخدام المرمّز العتادي في الجهاز '
        '(Android Media3). تظهر النسبة والوقت المتبقي في سطر العملية. قد يستغرق '
        'ذلك دقائق في فيديو طويل؛ وتعمل العملية في الخلفية.',
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
    'Tarama tamamlanamadı',
    'The scan could not finish',
    'تعذّر إكمال الفحص',
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
  'sr.last_page': (
    'Son sayfa silinemez — taramayı iptal edin.',
    'You cannot delete the last page — cancel the scan instead.',
    'لا يمكن حذف الصفحة الأخيرة — ألغِ المسح بدلًا من ذلك.',
  ),
  'sr.page_failed': ('Sayfa görüntülenemedi', 'Could not show the page', 'تعذّر عرض الصفحة'),
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

  // ── Açılma geçmişi ────────────────────────────────────────────────────────
  'oh.title': ('Geçmiş', 'History', 'السجل'),
  'oh.search': ('Geçmişte ara…', 'Search history…', 'ابحث في السجل…'),
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
  'srch.ai_error': (
    'Akıllı işlem yapılamadı: {error}',
    'The smart action failed: {error}',
    'تعذّر تنفيذ الإجراء الذكي: {error}',
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
  'mp.speed_reset': ('1× yap', 'Reset to 1×', 'إعادة إلى 1×'),
  'mp.subtitles': ('Altyazı', 'Subtitles', 'الترجمة'),
  'mp.sub_off': ('Altyazı kapalı', 'Subtitles off', 'إيقاف الترجمة'),
  'mp.engine_mpv': (
    'Gelişmiş motorla aç (mpv — her kodek)',
    'Open with advanced engine (mpv — all codecs)',
    'فتح بالمحرك المتقدم (mpv — كل الترميزات)',
  ),
  'mp.engine_exo': (
    'Standart motora dön (ExoPlayer)',
    'Back to standard engine (ExoPlayer)',
    'العودة إلى المحرك القياسي (ExoPlayer)',
  ),
  'mp.audio_track_n': ('Ses {n}', 'Audio {n}', 'الصوت {n}'),
  'mp.sub_online': (
    'İnternette ara (OpenSubtitles)…',
    'Search online (OpenSubtitles)…',
    'البحث عبر الإنترنت (OpenSubtitles)…',
  ),
  'mp.sub_online_none': (
    'Bu video için altyazı bulunamadı.',
    'No subtitles found for this video.',
    'لم يتم العثور على ترجمة لهذا الفيديو.',
  ),
  'mp.sub_online_failed': (
    'Altyazı alınamadı: {error}',
    'Could not get subtitles: {error}',
    'تعذر جلب الترجمة: {error}',
  ),
  'mp.sub_exact': ('Bu sürümle birebir', 'Exact match for this file', 'مطابقة تامة لهذا الملف'),
  'mp.sub_bigger': ('Altyazıyı büyüt', 'Larger subtitles', 'تكبير الترجمة'),
  'mp.sub_smaller': ('Altyazıyı küçült', 'Smaller subtitles', 'تصغير الترجمة'),
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
