part of '../app_strings.dart';

/// Çeviri tablosunun 6. bölümü (çoğunlukla `sdu`, `cj` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t6 = {
  'mp.sub_offset': ('Kayma: {v} sn', 'Offset: {v} s', 'الإزاحة: {v} ثانية'),
  'mp.sub_unreadable': (
    'Altyazı dosyası okunamadı.',
    'Could not read the subtitle file.',
    'تعذّرت قراءة ملف الترجمة.',
  ),
  'mp.open_with': ('Başka uygulamayla aç', 'Open with another app', 'فتح بتطبيق آخر'),
  'mp.file_ops': (
    'Dosya işlemleri (taşı, kopyala, paylaş…)',
    'File operations (move, copy, share…)',
    'عمليات الملفات (نقل، نسخ، مشاركة…)',
  ),
  'mp.shuffle': ('Karışık', 'Shuffle', 'عشوائي'),
  'mp.repeat_off': ('Tekrar: kapalı', 'Repeat: off', 'التكرار: مُعطّل'),
  'mp.repeat_one': ('Tekrar: bu parça', 'Repeat: this track', 'التكرار: هذا المقطع'),
  'mp.repeat_all': ('Tekrar: tümü', 'Repeat: all', 'التكرار: الكل'),
  'mp.video_failed': (
    'Bu dosya oynatılamadı. Cihaz bu codec’i desteklemiyor olabilir — '
        '“Başka uygulamayla aç”ı deneyin.\n\n{error}',
    'This file could not be played. Your device may not support this codec — '
        'try “Open with another app”.\n\n{error}',
    'تعذّر تشغيل هذا الملف. قد لا يدعم جهازك هذا الترميز — جرّب «فتح بتطبيق '
        'آخر».\n\n{error}',
  ),

  // ── İşlemler ekranı ───────────────────────────────────────────────────────
  'jb.title': ('İşlemler', 'Jobs', 'العمليات'),
  'jb.background_note': (
    'İşler uygulama arka plandayken de sürer ve ilerleme bildirimde görünür. '
        'Uygulamayı görev listesinden tamamen kapatırsan iş durur.',
    'Jobs keep running while the app is in the background and the progress '
        'shows in a notification. If you close the app from the task list, the '
        'job stops.',
    'تستمر العمليات أثناء عمل التطبيق في الخلفية ويظهر التقدّم في إشعار. وإن '
        'أغلقت التطبيق تمامًا من قائمة المهام فستتوقف العملية.',
  ),
  'jb.empty': (
    'Henüz bir işlem yok.\n'
        'Boyut düşürme, yer açma, kopya arama gibi işlemler burada görünür.',
    'No jobs yet.\n'
        'Jobs such as resizing, freeing space and duplicate scans show up here.',
    'لا توجد عمليات بعد.\n'
        'تظهر هنا عمليات مثل تصغير الحجم وتحرير المساحة والبحث عن النسخ المكررة.',
  ),
  'jb.cancelled': ('İptal edildi.', 'Cancelled.', 'أُلغيت.'),
  'jb.cancelled_detail': (
    'İptal edildi · {detail}',
    'Cancelled · {detail}',
    'أُلغيت · {detail}',
  ),
  'act.title': ('Yaptıklarım', 'My activity', 'ما قمت به'),
  'act.subtitle': (
    'Ürettiğiniz dosyalar',
    'Files you produced',
    'الملفات التي أنتجتها',
  ),
  'act.empty': (
    'Henüz kayıt yok.\nBir videoyu küçültünce, bir PDF düzenleyince ya da belge '
    'tarayınca ürettiğiniz dosyalar burada türlerine göre listelenir.',
    'Nothing yet.\nShrink a video, edit a PDF or scan a document and the files '
    'you produce will be listed here by type.',
    'لا يوجد شيء بعد.\nصغّر فيديو أو حرّر ملف PDF أو امسح مستندًا وستظهر الملفات '
    'التي تنتجها هنا مصنّفة حسب النوع.',
  ),
  'act.all': ('Hepsi ({n})', 'All ({n})', 'الكل ({n})'),
  'act.clear': ('Geçmişi temizle', 'Clear history', 'مسح السجل'),
  'act.clear_confirm': (
    'Bu liste temizlensin mi? Dosyalarınız SİLİNMEZ, yalnız buradaki kayıt '
    'listesi boşalır.',
    'Clear this list? Your files are NOT deleted — only the log is emptied.',
    'هل تريد مسح هذه القائمة؟ لن تُحذف ملفاتك — يُفرَّغ السجل فقط.',
  ),
  'act.kind_video': ('Küçültülen videolar', 'Shrunk videos', 'فيديوهات مصغّرة'),
  'act.kind_image': (
    'Küçültülen fotoğraflar',
    'Shrunk photos',
    'صور مصغّرة',
  ),
  'act.kind_pdf': ('Düzenlenen PDF\'ler', 'Edited PDFs', 'ملفات PDF محرَّرة'),
  'act.kind_doc': (
    'Düzenlenen belgeler',
    'Edited documents',
    'مستندات محرَّرة',
  ),
  'act.kind_convert': (
    'Dönüştürülen dosyalar',
    'Converted files',
    'ملفات محوَّلة',
  ),
  'act.kind_scan': ('Taranan belgeler', 'Scanned documents', 'مستندات ممسوحة'),
  'act.kind_other': ('Diğer', 'Other', 'أخرى'),
  'jb.resume': ('Devam et', 'Resume', 'متابعة'),
  'jb.resume_started': (
    'Kaldığı yerden devam ediyor.',
    'Resuming where it left off.',
    'تُستأنف من حيث توقفت.',
  ),
  'jb.resume_failed': (
    'Bu işlem devam ettirilemiyor; yeniden başlatın.',
    'This job cannot be resumed; start it again.',
    'لا يمكن استئناف هذه المهمة؛ ابدأها من جديد.',
  ),
  'jb.interrupted': (
    'Uygulama kapandığı için yarıda kaldı. Dokunun: kaldığı yerden yeniden '
        'başlatabilirsiniz.',
    'It was interrupted because the app closed. Tap to start it again.',
    'توقفت لأن التطبيق أُغلق. اضغط لبدئها من جديد.',
  ),
  'jb.interrupted_detail': (
    'Yarıda kaldı · {detail} · dokunup yeniden başlatın',
    'Interrupted · {detail} · tap to start it again',
    'توقفت في المنتصف · {detail} · اضغط لإعادة البدء',
  ),
  'jb.running_for': ('{time} sürüyor', 'Running for {time}', 'مستمرة منذ {time}'),
  'jb.took': ('{status} · {time} sürdü', '{status} · took {time}', '{status} · استغرقت {time}'),
  'jb.outputs': (
    'Oluşan dosyalar ({n})',
    'Files created ({n})',
    'الملفات الناتجة ({n})',
  ),
  'jb.open_folder': ('Klasörü aç', 'Open the folder', 'فتح المجلد'),
  'jb.file_missing': (
    'Dosya bulunamadı · {folder}',
    'File not found · {folder}',
    'الملف غير موجود · {folder}',
  ),

  // ── İmzalama ──────────────────────────────────────────────────────────────
  'sg.note': (
    'İmza belgeye kalıcı olarak basılacak.',
    'The signature is stamped onto the document permanently.',
    'يُطبع التوقيع على المستند بشكل دائم.',
  ),
  'sg.failed': ('İmzalanamadı: {error}', 'Signing failed: {error}', 'فشل التوقيع: {error}'),
  'sg.title': ('İmzala — {name}', 'Sign — {name}', 'وقّع — {name}'),
  'sg.redraw': ('İmzayı yeniden çiz', 'Redraw the signature', 'أعِد رسم التوقيع'),
  'sg.stamp': ('Bas', 'Stamp', 'اختم'),
  'sg.prev_page': ('Önceki sayfa', 'Previous page', 'الصفحة السابقة'),

  // ── Köşe düzeltme ─────────────────────────────────────────────────────────
  'se.failed': ('Düzeltilemedi: {error}', 'Could not correct it: {error}', 'تعذّر التصحيح: {error}'),
  'se.title': ('Köşeleri ayarla', 'Adjust the corners', 'ضبط الزوايا'),
  'se.reset': ('Sıfırla', 'Reset', 'إعادة تعيين'),
  'se.open_failed': (
    'Görsel açılamadı: {error}',
    'Could not open the image: {error}',
    'تعذّر فتح الصورة: {error}',
  ),
  'se.working': ('Düzeltiliyor…', 'Correcting…', 'جارٍ التصحيح…'),
  'se.hint': (
    'Mavi çerçeve sayfanın tamamı — dokunmazsanız hiçbir yer kesilmez. '
        'Kırpmak için köşeleri sürükleyin; eğik çekilen sayfa da düzleşir.',
    'The blue frame is the whole page — nothing is cut unless you move it. '
        'Drag the corners to crop; a skewed shot is straightened too.',
    'الإطار الأزرق هو الصفحة كاملة — لن يُقصّ شيء ما لم تحرّكه. اسحب الزوايا '
        'للقصّ؛ وتُقوَّم اللقطة المائلة أيضًا.',
  ),
  'se.use_found': (
    'Bulunan kenarlara oturt',
    'Snap to the detected edges',
    'المطابقة مع الحواف المكتشفة',
  ),
  // ── Otomatik kenar bulma + belge filtreleri (istek 2026-07-30) ────────────
  'se.auto_detect': (
    'Kenarları otomatik bul',
    'Detect the edges automatically',
    'اكتشاف الحواف تلقائيًا',
  ),
  'se.detecting': (
    'Kâğıdın kenarları aranıyor…',
    'Looking for the edges of the sheet…',
    'جارٍ البحث عن حواف الورقة…',
  ),
  'se.auto_found': (
    'Kenarlar otomatik bulundu. Yanlışsa köşeleri sürükleyerek düzeltin.',
    'The edges were found automatically. If they are off, drag the corners.',
    'عُثر على الحواف تلقائيًا. إن كانت خاطئة فاسحب الزوايا لتصحيحها.',
  ),
  'scan.filter_original': ('Özgün', 'Original', 'الأصل'),
  'scan.filter_auto': ('Netleştir (renkli)', 'Sharpen (color)', 'توضيح (ملوّن)'),
  'scan.filter_gray': ('Gri', 'Gray', 'رمادي'),
  'scan.filter_bw': ('Siyah-beyaz', 'Black & white', 'أبيض وأسود'),
  'scan.apply_to_all': (
    'Tüm sayfalara uygula',
    'Apply to all pages',
    'تطبيق على كل الصفحات',
  ),
  'scan.filter_failed': (
    'Sayfa netleştirilemedi: {error}',
    'The page could not be enhanced: {error}',
    'تعذّر تحسين الصفحة: {error}',
  ),

  // ── Galeri ────────────────────────────────────────────────────────────────
  'gal.open_in_viewer': (
    'Görüntüleyicide aç (OCR, çeviri, PDF)',
    'Open in the viewer (OCR, translation, PDF)',
    'افتح في العارض (OCR، ترجمة، PDF)',
  ),
  'gal.slideshow': ('Slayt gösterisi', 'Slideshow', 'عرض الشرائح'),
  'gal.slideshow_every': ('{n} saniyede bir', 'Every {n} seconds', 'كل {n} ثوانٍ'),
  'gal.use_as': ('Farklı kullan…', 'Use as…', 'استخدام كـ…'),
  'gal.use_as_failed': ('Bu fotoğraf için uygulama bulunamadı.', 'No app can use this photo.', 'لا يوجد تطبيق يمكنه استخدام هذه الصورة.'),
  'gal.other_actions': ('Diğer işlemler', 'Other actions', 'إجراءات أخرى'),

  // ── Sıkıştırma ────────────────────────────────────────────────────────────
  'cmp.title': ('Sıkıştır', 'Compress', 'ضغط'),
  'cmp.zip_note': (
    'Her yerde açılır. Parola verilirse AES-256 ile şifrelenir '
        '(dosya adları görünür kalır).',
    'Opens everywhere. With a password it is encrypted with AES-256 (file '
        'names stay visible).',
    'يُفتح في كل مكان. وبكلمة مرور يُشفَّر بـ AES-256 (تبقى أسماء الملفات ظاهرة).',
  ),
  'cmp.7z_note': (
    'Daha küçük dosya. Parola verilirse AES-256; istenirse dosya adları da '
        'gizlenir.',
    'A smaller file. With a password, AES-256; file names can be hidden too.',
    'ملف أصغر. وبكلمة مرور، AES-256؛ ويمكن إخفاء أسماء الملفات أيضًا.',
  ),
  'cmp.set_password': ('Parola koy', 'Set a password', 'تعيين كلمة مرور'),
  'cmp.hide_names': (
    'Dosya adlarını da gizle',
    'Hide the file names too',
    'إخفاء أسماء الملفات أيضًا',
  ),
  'cmp.hide_names_sub': (
    'Arşiv parolasız açılamaz',
    'The archive cannot be opened without the password',
    'لا يمكن فتح الأرشيف بدون كلمة المرور',
  ),
  'cmp.password_warning': (
    'Parolayı unutursanız arşiv AÇILAMAZ — kurtarma yolu yoktur.',
    'If you forget the password the archive CANNOT be opened — there is no '
        'recovery.',
    'إن نسيت كلمة المرور فلن يمكن فتح الأرشيف — لا توجد طريقة للاستعادة.',
  ),

  // ── SD kartla birleşik depolama (2026-10-17) ─────────────────────────────
  'sdu.title': ('SD kartla birleşik depolama', 'Combined storage with SD card', 'تخزين موحّد مع بطاقة SD'),
  'sdu.section': ('SD kart', 'SD card', 'بطاقة SD'),
  'sdu.tile_sub': (
    'Şarj olurken eski fotoğraf ve videoları SD karta taşıyıp ana belleği boşaltır',
    'While charging, moves old photos and videos to the SD card to free up internal storage',
    'أثناء الشحن، ينقل الصور ومقاطع الفيديو القديمة إلى بطاقة SD لتحرير الذاكرة الداخلية',
  ),
  'sdu.kw': (
    'hafıza kartı microsd taşı yedekle şarj ana bellek doldu yer aç',
    'memory card microsd move backup charging internal storage full free space',
    'بطاقة ذاكرة microsd نقل نسخ احتياطي شحن الذاكرة ممتلئة تحرير مساحة',
  ),
  'sdu.hero_title': ('İki bellek, tek depolama', 'Two memories, one storage', 'ذاكرتان، تخزين واحد'),
  'sdu.hero_body': (
    'Telefon şarja takılınca seçtiğiniz klasörlerin eski dosyaları SD karta, aynı '
        'klasör yapısıyla taşınır. Listelerde ve galeride yine birlikte görünürler; '
        'ana bellek boşalır. Şarjdan çıkınca iş durur, yarım dosya kalmaz.',
    'When the phone is charging, old files from the folders you choose are moved '
        'to the SD card with the same folder layout. They still show up together in '
        'lists and the gallery, and internal storage is freed. Unplugging stops the '
        'job without leaving half-copied files.',
    'عند شحن الهاتف تُنقل الملفات القديمة من المجلدات التي تختارها إلى بطاقة SD '
        'بنفس بنية المجلدات. وتظل تظهر معًا في القوائم والمعرض، وتتحرّر الذاكرة '
        'الداخلية. يتوقف العمل عند فصل الشاحن دون ترك ملفات منسوخة جزئيًا.',
  ),
  'sdu.android_only': (
    'Bu özellik yalnız Android\'de çalışır.',
    'This feature works only on Android.',
    'تعمل هذه الميزة على Android فقط.',
  ),
  'sdu.no_card': ('SD kart takılı değil', 'No SD card inserted', 'لا توجد بطاقة SD'),
  'sdu.no_card_hint': (
    'Telefonunuza bir microSD kart takın; kart burada kendiliğinden görünür.',
    'Insert a microSD card into your phone; it will show up here automatically.',
    'أدخل بطاقة microSD في هاتفك وستظهر هنا تلقائيًا.',
  ),
  'sdu.card_missing': (
    'Seçili SD kart şu an takılı değil. Kart takılınca iş kaldığı yerden sürer.',
    'The selected SD card is not inserted right now. The job continues once it is back.',
    'بطاقة SD المحددة غير موجودة حاليًا. سيستأنف العمل عند إعادتها.',
  ),
  'sdu.err_readonly': (
    'Bu telefon SD karta doğrudan yazmaya izin vermiyor (Android 10 ve öncesi ya '
        'da "Tüm dosyalara erişim" izni kapalı). Ayarlar\'dan izni açın.',
    'This phone does not allow writing to the SD card directly (Android 10 or '
        'older, or "All files access" is off). Turn the permission on in Settings.',
    'لا يسمح هذا الهاتف بالكتابة على بطاقة SD مباشرة (Android 10 أو أقدم، أو '
        'إذن "الوصول إلى كل الملفات" مغلق). فعّل الإذن من الإعدادات.',
  ),
  'sdu.enable': ('Şarj olurken otomatik çalıştır', 'Run automatically while charging', 'التشغيل تلقائيًا أثناء الشحن'),
  'sdu.enable_sub': (
    'Uygulama kapalıyken de çalışır; pil harcamaz, şarjdan çıkınca durur.',
    'Works even when the app is closed; it does not drain the battery and stops when unplugged.',
    'يعمل حتى والتطبيق مغلق؛ لا يستهلك البطارية ويتوقف عند فصل الشاحن.',
  ),
  'sdu.sec_status': ('Durum', 'Status', 'الحالة'),
  'sdu.sec_target': ('Hedef ve kip', 'Target and mode', 'الوجهة والوضع'),
  'sdu.sec_what': ('Neler taşınsın', 'What to move', 'ما الذي يُنقل'),
  'sdu.card_free': ('{free} boş · {total}', '{free} free · {total}', '{free} متاحة · {total}'),
  'sdu.mode_move': ('Taşı', 'Move', 'نقل'),
  'sdu.mode_copy': ('Yedekle', 'Back up', 'نسخ احتياطي'),
  'sdu.mode_move_sub': (
    'Dosya SD karta geçer, ana bellekte yer açılır.',
    'Files move to the SD card and free up internal storage.',
    'تنتقل الملفات إلى بطاقة SD وتتحرّر مساحة في الذاكرة الداخلية.',
  ),
  'sdu.mode_copy_sub': (
    'Dosya ana bellekte kalır, SD karta bir kopyası alınır (değişirse tazelenir).',
    'Files stay in internal storage and a copy is kept on the SD card (refreshed when changed).',
    'تبقى الملفات في الذاكرة الداخلية وتُحفظ نسخة على بطاقة SD (تُحدَّث عند التغيير).',
  ),
  'sdu.folders': ('Klasörler', 'Folders', 'المجلدات'),
  'sdu.f_camera': ('Kamera (DCIM)', 'Camera (DCIM)', 'الكاميرا (DCIM)'),
  'sdu.f_pictures': ('Resimler', 'Pictures', 'الصور'),
  'sdu.f_movies': ('Videolar', 'Movies', 'الفيديوهات'),
  'sdu.f_music': ('Müzik', 'Music', 'الموسيقى'),
  'sdu.f_download': ('İndirilenler', 'Downloads', 'التنزيلات'),
  'sdu.f_documents': ('Belgeler', 'Documents', 'المستندات'),
  'sdu.f_recordings': ('Kayıtlar', 'Recordings', 'التسجيلات'),
  'sdu.age': ('Şu kadar eski dosyalar', 'Files older than', 'الملفات الأقدم من'),
  'sdu.age_all': ('Hepsi', 'All', 'الكل'),
  'sdu.age_days': ('{n} gün', '{n} days', '{n} يوم'),
  'sdu.preview_wait': ('Hesaplanıyor…', 'Calculating…', 'جارٍ الحساب…'),
  'sdu.preview_move': (
    'Şu an {n} dosya · {size} taşınır',
    '{n} files · {size} would move now',
    'سيُنقل الآن {n} ملف · {size}',
  ),
  'sdu.preview_copy': (
    'Şu an {n} dosya · {size} yedeklenir',
    '{n} files · {size} would be backed up now',
    'سيُنسخ الآن {n} ملف · {size}',
  ),
  'sdu.preview_sub': (
    'Kartta zaten aynısı olanlar atlanır.',
    'Files that already exist on the card are skipped.',
    'تُتخطّى الملفات الموجودة بالفعل على البطاقة.',
  ),
  'sdu.notify': ('Bitince bildirim göster', 'Notify when done', 'إظهار إشعار عند الانتهاء'),
  'sdu.rules': (
    'Dokunulmayanlar: gizli klasörler (.thumbnails), son 10 dakikada değişen '
        'dosyalar ve WhatsApp/Telegram gibi sohbet uygulamalarının medyası — '
        'sohbetler dosyayı yoluyla tuttuğu için taşınınca açılmaz olurdu. Kartta '
        'en az 1 GB boş yer bırakılır. Aynı adlı farklı bir dosya varsa yeni ad '
        'verilir, hiçbir şeyin üzerine yazılmaz.',
    'Left alone: hidden folders (.thumbnails), files changed in the last 10 '
        'minutes and media of chat apps like WhatsApp/Telegram — chats keep the '
        'file by its path, so moving it would break them. At least 1 GB is kept '
        'free on the card. If a different file with the same name exists, a new '
        'name is used; nothing is overwritten.',
    'ما لا يُمسّ: المجلدات المخفية (.thumbnails) والملفات المعدّلة في آخر 10 '
        'دقائق ووسائط تطبيقات الدردشة مثل WhatsApp/Telegram — إذ تحفظ المحادثات '
        'الملف بمساره فيتعطّل عند نقله. يُترك 1 غيغابايت على الأقل فارغًا على '
        'البطاقة. إن وُجد ملف مختلف بالاسم نفسه يُستخدم اسم جديد ولا يُستبدل شيء.',
  ),
  'sdu.charging': ('Şarjda', 'Charging', 'قيد الشحن'),
  'sdu.not_charging': ('Şarjda değil', 'Not charging', 'غير موصول بالشاحن'),
  'sdu.will_run_now': ('kısa süre içinde çalışır', 'will run shortly', 'سيعمل قريبًا'),
  'sdu.will_run_charging': ('şarja takılınca çalışır', 'runs when you plug in', 'يعمل عند توصيل الشاحن'),
  'sdu.never': ('Henüz çalışmadı.', 'Has not run yet.', 'لم يعمل بعد.'),
  'sdu.running': (
    'Taşınıyor… şimdiye dek {n} dosya · {size}',
    'Moving… {n} files · {size} so far',
    'جارٍ النقل… {n} ملف · {size} حتى الآن',
  ),
  'sdu.last_run': (
    'Son çalışma {when}: {n} dosya · {size}',
    'Last run {when}: {n} files · {size}',
    'آخر تشغيل {when}: {n} ملف · {size}',
  ),
  'sdu.total': (
    'Toplam: {n} dosya · {size}',
    'In total: {n} files · {size}',
    'الإجمالي: {n} ملف · {size}',
  ),
  'sdu.failed_n': (
    '{n} dosya taşınamadı (bir sonraki çalışmada yeniden denenir).',
    '{n} files could not be moved (retried next time).',
    'تعذّر نقل {n} ملف (سيُعاد المحاولة في المرة القادمة).',
  ),
  'sdu.err_sd_missing': (
    'SD kart bulunamadı — iş atlandı.',
    'SD card not found — the job was skipped.',
    'لم يُعثر على بطاقة SD — تم تخطي العمل.',
  ),
  'sdu.err_sd_full': (
    'SD kart doldu (1 GB pay bırakılıyor) — iş durdu.',
    'The SD card is full (1 GB is kept free) — the job stopped.',
    'امتلأت بطاقة SD (يُترك 1 غيغابايت فارغًا) — توقف العمل.',
  ),
  'sdu.err_stopped': (
    'Şarj kesildiği ya da durdurulduğu için yarıda bırakıldı; kalanı sonra taşınır.',
    'Paused because charging stopped or it was stopped; the rest moves later.',
    'توقّف مؤقتًا لانقطاع الشحن أو لإيقافه؛ يُنقل الباقي لاحقًا.',
  ),
  'sdu.run_now_move': ('Şimdi taşı', 'Move now', 'انقل الآن'),
  'sdu.run_now_copy': ('Şimdi yedekle', 'Back up now', 'انسخ الآن'),
  'sdu.run_started': (
    'Başladı — uygulamayı kapatabilirsiniz.',
    'Started — you can close the app.',
    'بدأ — يمكنك إغلاق التطبيق.',
  ),
  'sdu.run_failed': (
    'Başlatılamadı. SD kart takılı mı?',
    'Could not start. Is the SD card inserted?',
    'تعذّر البدء. هل بطاقة SD موجودة؟',
  ),
  'sdu.notify_title_move': ('SD karta taşındı', 'Moved to SD card', 'نُقل إلى بطاقة SD'),
  'sdu.notify_title_copy': ('SD karta yedeklendi', 'Backed up to SD card', 'نُسخ إلى بطاقة SD'),
  'sdu.notify_body': ('{n} dosya · {size}', '{n} files · {size}', '{n} ملف · {size}'),
  'sdu.job_title': ('SD karta taşınıyor', 'Moving to the SD card', 'جارٍ النقل إلى بطاقة SD'),
  'sdu.job_title_copy': ('SD karta yedekleniyor', 'Backing up to the SD card', 'جارٍ النسخ الاحتياطي إلى بطاقة SD'),
  'sdu.job_name': ('SD karta aktarma', 'Transfer to the SD card', 'النقل إلى بطاقة SD'),

  // ── Tarama akışı ──────────────────────────────────────────────────────────
  'sf.scanner_failed': (
    'Tarayıcı açılamadı: {error}\nKamera izni verilmemiş olabilir.',
    'Could not open the scanner: {error}\nCamera permission may be missing.',
    'تعذّر فتح الماسح: {error}\nقد يكون إذن الكاميرا مفقودًا.',
  ),
  'sf.preparing': (
    'Sayfalar hazırlanıyor… ({n} / {total})',
    'Preparing the pages… ({n} / {total})',
    'جارٍ تجهيز الصفحات… ({n} / {total})',
  ),
  'sf.ocr_progress': (
    'Yazılar taranıyor… ({n} / {total} sayfa)',
    'Scanning text… ({n} / {total} pages)',
    'جارٍ فحص النص… ({n} / {total} صفحة)',
  ),
  'sf.building_pdf': (
    'PDF hazırlanıyor…',
    'Preparing the PDF…',
    'جارٍ تجهيز ملف PDF…',
  ),
  'sf.save_failed': (
    'Tarama kaydedilemedi: {error}',
    'Could not save the scan: {error}',
    'تعذّر حفظ المسح: {error}',
  ),
  'sf.saved_n': (
    '{n} sayfa PDF olarak kaydedildi',
    '{n} pages saved as a PDF',
    'تم حفظ {n} صفحة كملف PDF',
  ),

  // ── Sohbet medyası temizliği (WhatsApp/Telegram yığını) ───────────────────
  'cj.title': (
    'Sohbet medyası temizliği',
    'Chat media cleanup',
    'تنظيف وسائط المحادثات',
  ),
  'cj.job_title': (
    'Sohbet medyası taranıyor',
    'Scanning chat media',
    'جارٍ فحص وسائط المحادثات',
  ),
  'cj.job_name': (
    'Sohbet medyası taraması',
    'Chat media scan',
    'فحص وسائط المحادثات',
  ),
  'cj.rescan': ('Yeniden tara', 'Scan again', 'إعادة الفحص'),
  'cj.step_listing': (
    'Dosyalar listeleniyor…',
    'Listing the files…',
    'جارٍ سرد الملفات…',
  ),
  'cj.step_found': (
    '{n} sohbet dosyası bulundu',
    'Found {n} chat files',
    'تم العثور على {n} ملف محادثة',
  ),
  'cj.step_duplicates': (
    'Birebir kopyalar aranıyor…',
    'Looking for identical copies…',
    'جارٍ البحث عن النسخ المتطابقة…',
  ),
  'cj.step_sorting': ('Ayrıştırılıyor…', 'Sorting…', 'جارٍ التصنيف…'),
  'cj.step_none': (
    'Sohbet medyası bulunamadı',
    'No chat media found',
    'لم يُعثر على وسائط محادثات',
  ),
  'cj.step_clean': (
    'Gereksiz görünen bir şey çıkmadı',
    'Nothing looks unnecessary',
    'لا يبدو أن هناك ما هو غير ضروري',
  ),
  'cj.step_summary': (
    '{n} dosya · {size} geri kazanılabilir',
    '{n} files · {size} can be reclaimed',
    '{n} ملف · يمكن استرجاع {size}',
  ),
  'cj.scanned': (
    '{n} sohbet dosyası · {size}',
    '{n} chat files · {size}',
    '{n} ملف محادثة · {size}',
  ),
  'cj.summary': (
    'Bunların {n} tanesi (%{percent}) gereksiz görünüyor · {size}',
    '{n} of them ({percent}%) look unnecessary · {size}',
    'يبدو أن {n} منها ({percent}%) غير ضرورية · {size}',
  ),
  'cj.summary_none': (
    'Gereksiz görünen bir yığın çıkmadı.',
    'No unnecessary pile came up.',
    'لم تظهر أي كومة غير ضرورية.',
  ),
  'cj.disclaimer': (
    '“Gereksiz” bir tahmindir: kimin gönderdiği ya da fotoğrafın sizin için '
        'değeri dosyadan okunamaz. Hiçbir şey kendiliğinden silinmez; kararı '
        'siz verirsiniz.',
    '“Unnecessary” is a guess: who sent a file, or what it means to you, '
        'cannot be read from the file. Nothing is deleted on its own — you '
        'decide.',
    '«غير ضروري» تخمين: لا يمكن معرفة المُرسِل أو قيمة الصورة لك من الملف '
        'نفسه. لا يُحذف شيء تلقائيًا — القرار لك.',
  ),
  'cj.tiny_threshold': (
    'Küçük görüntü sınırı (bunun altı “iletilmiş” sayılır)',
    'Small image limit (below this counts as “forwarded”)',
    'حد الصورة الصغيرة (ما دونه يُعدّ «مُعاد توجيهه»)',
  ),
  'cj.empty_no_media': (
    'Bu telefonda WhatsApp/Telegram klasörü bulunamadı.',
    'No WhatsApp/Telegram folder was found on this phone.',
    'لم يُعثر على مجلد واتساب/تيليجرام على هذا الهاتف.',
  ),
  'cj.empty_clean': (
    'Sohbet medyanızda gereksiz görünen bir yığın yok 🎉',
    'There is no unnecessary pile in your chat media 🎉',
    'لا توجد كومة غير ضرورية في وسائط محادثاتك 🎉',
  ),
  'cj.kind_duplicate': (
    'Birebir kopyalar',
    'Identical copies',
    'نسخ متطابقة',
  ),
  'cj.kind_sticker': ('Çıkartmalar', 'Stickers', 'ملصقات'),
  'cj.kind_gif': ('Animasyonlar (GIF)', 'Animations (GIF)', 'صور متحركة (GIF)'),
  'cj.kind_profile': (
    'Profil fotoğrafları',
    'Profile photos',
    'صور الملف الشخصي',
  ),
  'cj.kind_tiny': (
    'Küçük görüntüler',
    'Small images',
    'صور صغيرة',
  ),
  'cj.kind_sent': (
    'Gönderdiklerim',
    'Files I sent',
    'الملفات التي أرسلتها',
  ),
  'cj.kind_stale': (
    'Uzun süredir açılmamışlar',
    'Not opened for a long time',
    'لم تُفتح منذ وقت طويل',
  ),
  'cj.why_duplicate': (
    'Aynı dosyanın fazladan kopyaları. Her kümeden en eski kopya KALIR.',
    'Extra copies of the same file. The oldest copy in each set is KEPT.',
    'نسخ إضافية من الملف نفسه. تبقى أقدم نسخة في كل مجموعة.',
  ),
  'cj.why_sticker': (
    'Sohbet süsü; saklanacak bir anı değil.',
    'Chat decoration, not a memory worth keeping.',
    'زينة محادثة، وليست ذكرى تستحق الحفظ.',
  ),
  'cj.why_gif': (
    'Genelde iletilmiş espri/animasyon.',
    'Usually a forwarded joke or animation.',
    'عادةً نكتة أو صورة متحركة مُعاد توجيهها.',
  ),
  'cj.why_profile': (
    'Uygulamanın indirdiği profil resmi önbelleği.',
    'Profile picture cache downloaded by the app.',
    'ذاكرة مؤقتة لصور الملفات الشخصية نزّلها التطبيق.',
  ),
  'cj.why_tiny': (
    'Bu kadar küçük görüntüler çoğunlukla iletilen afiş, mem ya da '
        '“günaydın” görselleridir; telefonla çekilen kare daha büyük olur.',
    'Images this small are mostly forwarded posters, memes or “good morning” '
        'pictures; a photo taken with the phone is larger.',
    'الصور بهذا الصغر غالبًا ملصقات أو «ميمز» أو صور «صباح الخير» مُعاد '
        'توجيهها؛ الصورة الملتقطة بالهاتف تكون أكبر.',
  ),
  'cj.why_sent': (
    'Sizin gönderdiğiniz dosyaların ikinci kopyası; aslı galeride ya da '
        'indirilenlerde duruyor olabilir.',
    'A second copy of files you sent; the original may still be in your '
        'gallery or downloads.',
    'نسخة ثانية من ملفات أرسلتها؛ قد يكون الأصل في المعرض أو التنزيلات.',
  ),
  'cj.why_stale': (
    'Aylardır ne açılmış ne dokunulmuş.',
    'Neither opened nor touched for months.',
    'لم تُفتح ولم تُمس منذ أشهر.',
  ),
  'cj.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'cj.select_none': ('Seçimi kaldır', 'Clear selection', 'إلغاء التحديد'),
  'cj.nothing_selected': (
    'Silinecek dosya seçin',
    'Select the files to delete',
    'اختر الملفات المراد حذفها',
  ),
  'cj.selected_summary': (
    '{n} dosya seçildi · {size}',
    '{n} files selected · {size}',
    'تم تحديد {n} ملف · {size}',
  ),
  'cj.bucket_empty': (
    'Bu kovada dosya kalmadı.',
    'No files left in this bucket.',
    'لم تبقَ ملفات في هذه المجموعة.',
  ),
  'cj.similar_title': (
    'Benzer kareler (WhatsApp)',
    'Similar shots (WhatsApp)',
    'لقطات متشابهة (واتساب)',
  ),
  'cj.similar_body': (
    'Kovaların bulamadığı yığın: aynı anın 5 karesi, yeniden sıkıştırılmış '
        'kopyalar. Görüntüleri çözerek arar, uzun sürer.',
    'The pile the buckets cannot find: five shots of the same moment, '
        'recompressed copies. It decodes the images, so it takes a while.',
    'الكومة التي لا تجدها المجموعات: خمس لقطات للحظة نفسها، ونسخ أُعيد '
        'ضغطها. يفكّ ترميز الصور، لذا يستغرق وقتًا.',
  ),

  // ── Tarama stüdyosu + kırpma (2026-10-18: akış baştan) ───────────────────
  'ss.pages_tab': ('Sayfalar ({n})', 'Pages ({n})', 'الصفحات ({n})'),
  'ss.saved': ('Kaydedildi · {folder}', 'Saved · {folder}', 'تم الحفظ · {folder}'),
  'ss.saving': ('Kaydediliyor…', 'Saving…', 'جارٍ الحفظ…'),
  'ss.save_failed': (
    'Kaydedilemedi — yeniden denemek için dokunun',
    'Not saved — tap to try again',
    'لم يُحفظ — اضغط لإعادة المحاولة',
  ),
  'ss.finishing': (
    'Son değişiklikler kaydediliyor…',
    'Saving the last changes…',
    'جارٍ حفظ آخر التغييرات…',
  ),
  'ss.tool_crop': ('Kırp', 'Crop', 'قصّ'),
  'ss.tool_rotate': ('Döndür', 'Rotate', 'تدوير'),
  'ss.tool_filter': ('Filtre', 'Filter', 'تصفية'),
  'ss.tool_retake': ('Yeniden çek', 'Retake', 'إعادة الالتقاط'),
  'ss.tool_delete': ('Sil', 'Delete', 'حذف'),
  'ss.page_deleted': ('Sayfa silindi', 'Page deleted', 'حُذفت الصفحة'),
  'ss.working_crop': ('Kırpılıyor…', 'Cropping…', 'جارٍ القصّ…'),
  'ss.working_rotate': ('Döndürülüyor…', 'Rotating…', 'جارٍ التدوير…'),
  'ss.working_filter': ('Uygulanıyor…', 'Applying…', 'جارٍ التطبيق…'),
  'ss.working_straighten': ('Düzleştiriliyor…', 'Straightening…', 'جارٍ التقويم…'),
  'ss.moving': ('Taşınıyor…', 'Moving…', 'جارٍ النقل…'),
  'ss.add_camera': ('Kamerayla tara', 'Scan with the camera', 'المسح بالكاميرا'),
  'ss.add_camera_sub': (
    'Sayfa kenarları otomatik bulunur',
    'The page edges are found automatically',
    'تُكتشف حواف الصفحة تلقائيًا',
  ),
  'ss.add_gallery': ('Fotoğraftan ekle', 'Add from a photo', 'إضافة من صورة'),
  'ss.add_gallery_sub': (
    'Galeriden seçin, kırpmayı siz ayarlayın',
    'Pick from the gallery and set the crop yourself',
    'اختر من المعرض واضبط القصّ بنفسك',
  ),
  'ss.filter_title': ('Sayfanın görünümü', 'Page look', 'مظهر الصفحة'),
  'ss.filter_note': (
    'Özgün: tarayıcıdan geldiği gibi. Netleştirme gölgeyi alır ve yazıyı '
        'belirginleştirir; fotoğraflara dokunmaz.',
    'Original: as it came from the scanner. Sharpen removes shadows and '
        'darkens the text; photos are left untouched.',
    'الأصل: كما جاء من الماسح. التوضيح يزيل الظلال ويُبرز النص؛ ولا يمسّ '
        'الصور.',
  ),
  'ss.straighten_sub': (
    'Eğik ya da kavisli satırları yazıya bakarak düzeltir',
    'Fixes tilted or curved lines by looking at the text',
    'يصحّح الأسطر المائلة أو المنحنية بالنظر إلى النص',
  ),
  'scan.short_original': ('Özgün', 'Original', 'الأصل'),
  'scan.short_auto': ('Netleştir', 'Sharpen', 'توضيح'),
  'scan.short_gray': ('Gri', 'Gray', 'رمادي'),
  'scan.short_bw': ('S/B', 'B/W', 'أ/أ'),
  'se.crop_title': ('Sayfayı kırp', 'Crop the page', 'قصّ الصفحة'),
  'se.crop_hint': (
    'Köşeleri ya da kenarları sürükleyin',
    'Drag the corners or the edges',
    'اسحب الزوايا أو الحواف',
  ),
  'se.full_page': ('Tam sayfa', 'Whole page', 'الصفحة كاملة'),
  'se.find_edges': ('Kenarları bul', 'Find edges', 'اكتشاف الحواف'),
  'se.not_found': (
    'Kâğıt kenarı bulunamadı — kenarları elle sürükleyin.',
    'No paper edge was found — drag the edges by hand.',
    'لم يُعثر على حافة الورقة — اسحب الحواف يدويًا.',
  ),
  'se.apply_crop': ('Kırp', 'Crop', 'قصّ'),
  'sf.tips_title': ('Nasıl taranır?', 'How to scan', 'كيفية المسح'),
  'sf.tips_sub': (
    'Birazdan açılacak tarama ekranında üç düğme önemli:',
    'Three buttons matter on the scanner screen that opens next:',
    'ثلاثة أزرار مهمة في شاشة المسح التي ستفتح الآن:',
  ),
  'sf.tip1_title': ('1 · Sayfayı çek', '1 · Capture the page', '١ · التقط الصفحة'),
  'sf.tip1_body': (
    'Belgeyi düz bir zemine koy; kenarlar kendiliğinden bulunur.',
    'Lay the document flat; edges are found automatically.',
    'ضع المستند على سطح مستوٍ؛ تُكتشف الحواف تلقائياً.',
  ),
  'sf.tip2_title': (
    '2 · Yeni sayfa için ➕ sayfa düğmesi',
    '2 · Use the ➕ page button for more pages',
    '٢ · استخدم زر ➕ الصفحة لصفحات أخرى',
  ),
  'sf.tip2_body': (
    'Sağ alttaki mavi, artılı sayfa simgesine bas: kamera yeniden açılır ve sonraki sayfayı çekersin. Her sayfa için tekrarla.',
    'Tap the blue page-with-plus icon at the bottom right: the camera reopens for the next page. Repeat for each page.',
    'اضغط أيقونة الصفحة الزرقاء ذات علامة الزائد أسفل اليمين: تُفتح الكاميرا للصفحة التالية. كرر لكل صفحة.',
  ),
  'sf.tip_next_label': ('Sonraki', 'Next', 'التالي'),
  'sf.tip3_title': (
    '3 · "Sonraki" taramayı BİTİRİR',
    '3 · "Next" FINISHES the scan',
    '٣ · "التالي" يُنهي المسح',
  ),
  'sf.tip3_body': (
    'Tüm sayfaları çektikten sonra bas. Yine de unuttuğun sayfa olursa belge stüdyosundaki "Sayfa ekle" ile eklersin.',
    'Tap it once all pages are captured. Forgot one? Add it later with "Add pages" in the document studio.',
    'اضغطه بعد التقاط كل الصفحات. نسيت صفحة؟ أضفها لاحقاً عبر "إضافة صفحات" في الاستوديو.',
  ),
  'sf.tips_start': ('Taramaya başla', 'Start scanning', 'ابدأ المسح'),
  'sf.tips_never': ('Anladım, bir daha gösterme', 'Got it, don\'t show again', 'فهمت، لا تعرض مجدداً'),
  'scr.class_hint': (
    '{type} gibi görünüyor — "Önemli Dosyalar/{folder}" klasörüne taşınsın mı?',
    'Looks like {type} — move to "Önemli Dosyalar/{folder}"?',
    'يبدو أنه {type} — نقله إلى "Önemli Dosyalar/{folder}"؟',
  ),
  'scr.class_move': ('Taşı', 'Move', 'نقل'),
  'scr.add_pages_hint': (
    'Kamera ya da galeri',
    'Camera or gallery',
    'الكاميرا أو المعرض',
  ),
  'sf.title': ('Belge hazırlanıyor', 'Preparing the document', 'جارٍ تجهيز المستند'),
  'sf.job_name': ('Belge tarama', 'Document scan', 'مسح المستند'),

  // ── Tarama sonucu ekranı ──────────────────────────────────────────────────
  'scr.title': ('Tarama sonucu', 'Scan result', 'نتيجة المسح'),
  'scr.tab_document': ('Belge', 'Document', 'المستند'),
  'scr.tab_text': ('Metin', 'Text', 'النص'),
  'scr.saved_to': (
    'PDF kaydedildi · {folder}',
    'PDF saved · {folder}',
    'حُفظ الـ PDF · {folder}',
  ),
  'scr.change_location': ('Konumu değiştir', 'Change location', 'تغيير الموقع'),
  'scr.save_here': ('Buraya kaydet', 'Save here', 'احفظ هنا'),
  'scr.moved': (
    'Taşındı · {folder}',
    'Moved · {folder}',
    'تم النقل · {folder}',
  ),
  'scr.move_failed': (
    'Taşınamadı: {error}',
    'Could not move: {error}',
    'تعذّر النقل: {error}',
  ),
  'scr.open_pdf': ('PDF\'i aç', 'Open the PDF', 'فتح الـ PDF'),
  'scr.no_text_yet': (
    'Bu tarama metin tanımadan yapıldı. Sayfalardaki yazıları şimdi '
        'tanıyabilirsiniz.',
    'This scan was made without text recognition. You can recognize the text '
        'on the pages now.',
    'تم هذا المسح دون التعرّف على النص. يمكنك التعرّف على النص الآن.',
  ),
  // ('Aranabilir olsun mu?' penceresi 2026-08-05'te kaldırıldı: OCR artık her
  // taramada kendiliğinden koşar — soru anahtarları da tabloyla birlikte gitti.)
  'scr.rename': ('Yeniden adlandır', 'Rename', 'إعادة التسمية'),
  'scr.rename_failed': (
    'Ad değiştirilemedi: {error}',
    'Could not rename: {error}',
    'تعذّرت إعادة التسمية: {error}',
  ),
  'scr.add_pages': ('Sayfa ekle', 'Add pages', 'إضافة صفحات'),
  'scr.crop_page': ('Kenarları kırp', 'Crop edges', 'قصّ الحواف'),
  'scr.edit_pages': ('Sayfaları düzenle', 'Edit pages', 'تحرير الصفحات'),
  'scr.updated': ('Belge güncellendi.', 'The document was updated.', 'تم تحديث المستند.'),
  'scr.cropped': ('Sayfa düzeltildi.', 'Page adjusted.', 'تم تعديل الصفحة.'),
  'reader.open': ('Okuma görünümü', 'Reading view', 'وضع القراءة'),
  'reader.theme': ('Zemin', 'Background', 'الخلفية'),
  'reader.theme_light': ('Açık', 'Light', 'فاتح'),
  'reader.theme_sepia': ('Sepya', 'Sepia', 'بني داكن'),
  'reader.theme_dark': ('Koyu', 'Dark', 'داكن'),
  'reader.page_empty': (
    'Bu sayfada okunabilir metin bulunamadı.',
    'No readable text found on this page.',
    'لم يُعثر على نص مقروء في هذه الصفحة.'
  ),
  'scr.pages_added': (
    '{n} sayfa eklendi',
    '{n} pages added',
    'تمت إضافة {n} صفحة',
  ),
  'scr.add_failed': (
    'Sayfalar eklenemedi: {error}',
    'Could not add the pages: {error}',
    'تعذّرت إضافة الصفحات: {error}',
  ),

  // ── Çeviri akışı ──────────────────────────────────────────────────────────
  'tf.title': ('Çeviri', 'Translation', 'الترجمة'),
  'tf.job_title': ('Belge çevriliyor', 'Translating the document', 'جارٍ ترجمة المستند'),
  'tf.job_done': ('{n} sayfa çevrildi', '{n} pages translated', 'تُرجمت {n} صفحة'),
  'tf.no_text': ('Çevrilecek metin yok.', 'There is no text to translate.', 'لا يوجد نص للترجمة.'),
  'tf.preparing': ('Hazırlanıyor…', 'Preparing…', 'جارٍ التحضير…'),
  'tf.first_use': (
    'Bu yalnızca ilk kullanımda gerekir.',
    'This is only needed the first time.',
    'هذا مطلوب في المرة الأولى فقط.',
  ),
  'tf.progress': (
    'Çevriliyor… ({n} / {total} satır)',
    'Translating… ({n} / {total} lines)',
    'جارٍ الترجمة… ({n} / {total} سطر)',
  ),
  'tf.working': ('Çevriliyor…', 'Translating…', 'جارٍ الترجمة…'),
  'tf.failed': (
    'Çeviri başarısız: {error}\n'
        'Dil modeli inmediyse internet bağlantısını kontrol edin.',
    'Translation failed: {error}\n'
        'If the language model has not downloaded, check your internet connection.',
    'فشلت الترجمة: {error}\n'
        'إن لم يُنزَّل نموذج اللغة فتحقّق من اتصالك بالإنترنت.',
  ),
  'tf.empty_result': (
    'Çeviri sonucu boş döndü.',
    'The translation came back empty.',
    'عادت الترجمة فارغة.',
  ),
  'tf.lang_title': ('Çeviri dili', 'Translation language', 'لغة الترجمة'),
  'tf.swap': ('Dilleri değiştir', 'Swap the languages', 'تبديل اللغتين'),
  'tf.source_lang': ('Kaynak dil', 'Source language', 'لغة المصدر'),
  'tf.target_lang': ('Hedef dil', 'Target language', 'اللغة الهدف'),
  'tf.downloading': (
    '{lang} dil modeli indiriliyor…',
    'Downloading the {lang} language model…',
    'جارٍ تنزيل نموذج اللغة {lang}…',
  ),
  'tf.copied': ('Çeviri kopyalandı', 'Translation copied', 'تم نسخ الترجمة'),
  // Belge çevirisi: metin toplama (katman/OCR) → sayfa sayfa çeviri.
  'tf.page_reading': (
    'Sayfa {n} / {total} okunuyor…',
    'Reading page {n} / {total}…',
    'جارٍ قراءة الصفحة {n} / {total}…',
  ),
  'tf.page_ocr': (
    'Sayfa {n} / {total} taranıyor (metin tanıma)…',
    'Scanning page {n} / {total} (text recognition)…',
    'جارٍ فحص الصفحة {n} / {total} (التعرّف على النص)…',
  ),
  'tf.page_translating': (
    'Sayfa {n} / {total} çevriliyor…',
    'Translating page {n} / {total}…',
    'جارٍ ترجمة الصفحة {n} / {total}…',
  ),
  'tf.page_header': ('— Sayfa {n} —', '— Page {n} —', '— صفحة {n} —'),
  'tf.stopping': ('Durduruluyor…', 'Stopping…', 'جارٍ الإيقاف…'),
  'tf.stopped': (
    'Çeviri durduruldu.',
    'Translation stopped.',
    'تم إيقاف الترجمة.',
  ),
  'tf.partial': (
    'Durduruldu — {total} sayfanın {n} tanesi çevrildi.',
    'Stopped — {n} of {total} pages were translated.',
    'تم الإيقاف — تُرجمت {n} من {total} صفحة.',
  ),
  'tf.mode_title': (
    'Çeviri nasıl olsun?',
    'How should the translation come out?',
    'كيف تريد نتيجة الترجمة؟'
  ),
  'tf.mode_inplace': (
    'Belgenin kendisi (düzeni koruyarak)',
    'The document itself (same layout)',
    'المستند نفسه (بالتنسيق ذاته)'
  ),
  'tf.mode_inplace_hint': (
    'Yazı tipi, punto ve sayfa düzeni aynı kalır; yalnız yazılar hedef '
    'dilde olur. Sonuç yeni bir PDF olarak kaydedilir.',
    'Font, size and page layout stay the same; only the words change. '
    'The result is saved as a new PDF.',
    'يبقى الخط والحجم وتنسيق الصفحة كما هو؛ تتغيّر الكلمات فقط. '
    'تُحفظ النتيجة كملف PDF جديد.'
  ),
  'tf.mode_text': (
    'Metin olarak (okumak / kopyalamak için)',
    'As plain text (to read or copy)',
    'كنص عادي (للقراءة أو النسخ)'
  ),
  'tf.mode_text_hint': (
    'Taranmış sayfalar da (OCR ile) çevrilir, ama sonuç düz metindir.',
    'Scanned pages are included (via OCR), but the result is plain text.',
    'تشمل الصفحات الممسوحة ضوئيًا (عبر OCR)، لكن النتيجة نص عادي.'
  ),
  'tf.inplace_done': (
    '{n} paragraf çevrildi ({pages} sayfa).',
    'Translated {n} paragraphs across {pages} pages.',
    'تُرجمت {n} فقرة في {pages} صفحة.'
  ),
  'tf.inplace_partial': (
    '{n} paragraf çevrildi; {skipped} tanesi belgeye yazılamadı '
    '(yazı tipi hedef dilin harflerini taşımıyor ya da metin sayfaya '
    'sığmıyor) ve olduğu gibi kaldı.',
    'Translated {n} paragraphs; {skipped} could not be written back '
    '(the embedded font lacks the target letters, or the text no longer '
    'fits) and were left unchanged.',
    'تُرجمت {n} فقرة؛ تعذّرت كتابة {skipped} منها (الخط المضمّن لا يحتوي '
    'حروف اللغة الهدف أو أن النص لم يعد يتّسع) وبقيت كما هي.'
  ),
  'tf.inplace_none': (
    'Hiçbir paragraf belgeye yazılamadı ({n} denendi): belgeye gömülü yazı '
    'tipi hedef dilin harflerini taşımıyor olabilir. "Metin olarak çevir" '
    'bu belgede çalışır.',
    'No paragraph could be written back ({n} tried): the fonts embedded in '
    'this document may not carry the target language\'s letters. '
    '"Translate as text" works for this document.',
    'تعذّرت إعادة كتابة أي فقرة ({n} محاولة): قد لا تحتوي الخطوط المضمّنة '
    'حروف اللغة الهدف. خيار «الترجمة كنص» يعمل مع هذا المستند.'
  ),

  // ── Otomatik düzenleme ekranı ─────────────────────────────────────────────
  'org.all_placed_full': (
    'Her şey zaten yerinde görünüyor',
    'Everything already looks in place',
    'يبدو أن كل شيء في مكانه',
  ),
  'org.already_placed': (
    '{n} dosya zaten doğru klasörde.',
    '{n} files are already in the right folder.',
    '{n} ملف موجود بالفعل في المجلد الصحيح.',
  ),

  // ── AI ile yeniden yaz (metin şeridi) ─────────────────────────────────────
  'aw.preset_fix': ('Yazımı düzelt', 'Fix the writing', 'صحّح الكتابة'),
  'aw.preset_fix_prompt': (
    'Bu metindeki yazım ve dil bilgisi hatalarını düzelt. Anlamı ve üslubu '
        'koru, uzunluğu mümkün olduğunca aynı tut.',
    'Fix the spelling and grammar mistakes in this text. Keep the meaning and '
        'the style, and keep the length as close as possible.',
    'صحّح الأخطاء الإملائية والنحوية في هذا النص. حافظ على المعنى والأسلوب، '
        'وأبقِ الطول كما هو قدر الإمكان.',
  ),
  'aw.preset_shorten': ('Kısalt', 'Shorten', 'اختصر'),
  'aw.preset_shorten_prompt': (
    'Bu metni anlamını kaybetmeden belirgin biçimde kısalt.',
    'Shorten this text noticeably without losing its meaning.',
    'اختصر هذا النص بوضوح دون فقدان معناه.',
  ),
  'aw.preset_simplify': ('Sadeleştir', 'Simplify', 'بسّط'),
  'aw.preset_simplify_prompt': (
    'Bu metni daha anlaşılır ve sade bir dille yeniden yaz.',
    'Rewrite this text in clearer, plainer language.',
    'أعِد كتابة هذا النص بلغة أوضح وأبسط.',
  ),
  'aw.preset_formal': ('Resmîleştir', 'Make it formal', 'اجعله رسميًا'),
  'aw.preset_formal_prompt': (
    'Bu metni resmî yazışma diline uygun hâle getir.',
    'Rewrite this text in formal correspondence style.',
    'أعِد كتابة هذا النص بأسلوب المراسلات الرسمية.',
  ),
  'aw.prompt': (
    'Aşağıdaki metni şu yönergeye göre yeniden yaz: "{task}"\n\n{text}\n\n'
        'ÇOK ÖNEMLİ: yalnızca yeni metni döndür. Açıklama, tırnak, giriş '
        'cümlesi ya da kod bloğu işareti EKLEME. Metin bir PDF sayfasındaki '
        'dar bir satıra sığacak; gereksiz uzatma.',
    'Rewrite the text below according to this instruction: "{task}"\n\n{text}'
        '\n\nVERY IMPORTANT: return only the new text. Do NOT add explanations, '
        'quotes, an introductory sentence or code-block markers. The text has '
        'to fit a narrow line on a PDF page; do not pad it.',
    'أعِد كتابة النص أدناه وفق هذه التعليمات: "{task}"\n\n{text}\n\n'
        'مهم جدًا: أعِد النص الجديد فقط. لا تُضِف شروحًا أو علامات اقتباس أو '
        'جملة تمهيدية أو علامات كتل الشيفرة. سيوضع النص في سطر ضيق داخل صفحة '
        'PDF؛ فلا تُطِله بلا داعٍ.',
  ),
  'aw.hint': (
    'Örn. “daha kibar bir dille yaz”',
    'E.g. “write it more politely”',
    'مثال: «اكتبه بلغة ألطف»',
  ),
  'aw.working': ('Çalışıyor…', 'Working…', 'جارٍ العمل…'),
  'aw.title': ('AI ile düzelt', 'Fix with AI', 'تصحيح بالذكاء الاصطناعي'),

  // ── Klasör kilidi PIN ─────────────────────────────────────────────────────
  'pin.too_short': (
    'PIN en az 4 haneli olmalı.',
    'The PIN must be at least 4 digits.',
    'يجب أن يتكوّن الرمز من 4 أرقام على الأقل.',
  ),
  'pin.mismatch': ('İki PIN aynı değil.', 'The two PINs do not match.', 'الرمزان غير متطابقين.'),
  'pin.repeat_empty': (
    'Aynı PIN\'i alttaki "PIN (tekrar)" kutusuna da yazın.',
    'Type the same PIN again in the "PIN (repeat)" box below.',
    'أعد كتابة الرمز نفسه في خانة «الرمز (تكرار)» بالأسفل.',
  ),
  'pin.wrong': ('PIN yanlış.', 'Wrong PIN.', 'الرمز غير صحيح.'),
  'pin.not_encrypted': (
    'Bu kilit dosyaları ŞİFRELEMEZ: yalnız bu uygulamadaki listelerden gizler. '
        'Telefon bilgisayara takılırsa ya da başka bir dosya yöneticisi '
        'kullanılırsa dosyalar görülebilir.',
    'This lock does NOT encrypt the files: it only hides them from the lists in '
        'this app. If the phone is plugged into a computer, or another file '
        'manager is used, the files are visible.',
    'هذا القفل لا يشفّر الملفات: إنما يخفيها من القوائم داخل هذا التطبيق فقط. '
        'وإذا وُصل الهاتف بحاسوب أو استُخدم مدير ملفات آخر فستكون الملفات ظاهرة.',
  ),

  // ── Benzerlik taraması (arka plan) ────────────────────────────────────────
  'simf.preparing': ('Hazırlanıyor…', 'Preparing…', 'جارٍ التحضير…'),
  'simf.inspected': (
    '{n} / {total} dosya incelendi',
    '{n} / {total} files inspected',
    'تم فحص {n} / {total} ملف',
  ),
  'simf.matching': ('Eşleşmeler çıkarılıyor…', 'Extracting matches…', 'جارٍ استخراج المطابقات…'),
};
