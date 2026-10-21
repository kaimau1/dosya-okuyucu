part of '../app_strings.dart';

/// Çeviri tablosunun 3. bölümü (çoğunlukla `excel`, `drive` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t3 = {
  // ── Uzak/USB gezgini: seçim, kopyalama, sıralama (2026-09-02) ────────
  'nas.copy_to_phone': (
    'Telefona kopyala',
    'Copy to phone',
    'نسخ إلى الهاتف',
  ),
  'nas.copied_to_phone': (
    'İndirilenler/Dosya Okuyucu klasörüne kopyalandı',
    'Copied to Download/Dosya Okuyucu',
    'تم النسخ إلى مجلد التنزيلات',
  ),
  'nas.copy_only_files': (
    'Yalnız dosyalar kopyalanabiliyor (klasör seçilmiş).',
    'Only files can be copied (a folder is selected).',
    'يمكن نسخ الملفات فقط.',
  ),
  'nas.copy_skipped_dirs': ('klasör atlandı', 'folders skipped', 'مجلدات متخطاة'),
  'nas.copying': ('Kopyalanıyor', 'Copying', 'جارٍ النسخ'),
  'nas.filter_hint': ('Bu klasörde süz', 'Filter this folder', 'تصفية هذا المجلد'),
  'nas.no_match': ('Süzgece uyan dosya yok.', 'No matching files.', 'لا ملفات مطابقة.'),
  'nas.delete_many': ('{n} öğe silinsin mi?', 'Delete {n} items?', 'حذف {n} عنصرًا؟'),
  'nas.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'nas.sort_size': ('Boyuta göre', 'By size', 'حسب الحجم'),
  'nas.sort_date': ('Tarihe göre', 'By date', 'حسب التاريخ'),
  'nas.sort_ascending': ('Artan sıra', 'Ascending', 'تصاعدي'),
  'nas.rename': ('Yeniden adlandır', 'Rename', 'إعادة تسمية'),
  'nas.new_name': ('Yeni ad', 'New name', 'الاسم الجديد'),
  'nas.empty_folder': ('Bu klasör boş.', 'This folder is empty.', 'هذا المجلد فارغ.'),
  'nas.smb_share_root': (
    'Paylaşımlar — bir paylaşıma girerek dosyaları görün.',
    'Shares — open a share to see its files.',
    'المشاركات — افتح مشاركة لعرض ملفاتها.',
  ),
  'nas.error_unreachable': (
    'Sunucuya ulaşılamadı. Adres, port ve aynı ağda olup olmadığınızı kontrol edin.',
    'Could not reach the server. Check the address, the port, and that you are '
        'on the same network.',
    'تعذّر الوصول إلى الخادم. تحقق من العنوان والمنفذ ومن أنك على نفس الشبكة.',
  ),
  'nas.error_auth': (
    'Kullanıcı adı ya da parola kabul edilmedi.',
    'The username or password was rejected.',
    'تم رفض اسم المستخدم أو كلمة المرور.',
  ),
  'nas.error_not_found': ('Klasör ya da dosya yok.', 'Folder or file not found.', 'المجلد أو الملف غير موجود.'),
  'nas.error_denied': ('Sunucu izin vermedi.', 'The server denied access.', 'رفض الخادم الوصول.'),
  'nas.error_unsupported': (
    'Sunucu bu protokol sürümünü desteklemiyor. SFTP ya da FTP deneyin.',
    'The server does not support this protocol version. Try SFTP or FTP.',
    'لا يدعم الخادم إصدار البروتوكول هذا. جرّب SFTP أو FTP.',
  ),
  'nas.error_unknown': ('Bağlantı hatası.', 'Connection error.', 'خطأ في الاتصال.'),
  'nas.smb_warning': (
    'SMB, Samba/Windows paylaşımlarıyla (SMB2) sınandı ve çalışıyor. Yalnız '
        'SMB3 zorunlu kılan sunucular bağlanmayabilir; öyleyse aynı sunucuda '
        'SFTP ya da FTP deneyin. Port her zaman 445\'tir, değiştirilemez.',
    'SMB was tested against Samba/Windows shares (SMB2) and works. Servers that '
        'require SMB3 only may not connect; in that case try SFTP or FTP on the '
        'same server. The port is always 445 and cannot be changed.',
    'تم اختبار SMB مع مشاركات Samba/Windows (SMB2) وهو يعمل. قد لا تتصل الخوادم '
        'التي تفرض SMB3 فقط؛ في هذه الحالة جرّب SFTP أو FTP على الخادم نفسه. '
        'المنفذ دائمًا 445 ولا يمكن تغييره.',
  ),

  'nas.writeback_title': (
    'Değişiklikler sunucuya yüklensin mi?',
    'Upload the changes to the server?',
    'هل تريد رفع التغييرات إلى الخادم؟',
  ),
  'nas.writeback_body': (
    '“{name}” düzenlendi. Değişiklik şu an yalnız telefondaki geçici kopyada; '
        'sunucudaki dosya hâlâ eski. Yüklersen sunucudaki sürümün ÜZERİNE yazılır.',
    '“{name}” was edited. The change is currently only in the temporary copy on '
        'the phone; the file on the server is still the old one. Uploading '
        'OVERWRITES the version on the server.',
    'تم تعديل «{name}». التغيير موجود حاليًا فقط في النسخة المؤقتة على الهاتف؛ '
        'الملف على الخادم لا يزال قديمًا. سيؤدي الرفع إلى الكتابة فوق النسخة '
        'الموجودة على الخادم.',
  ),
  'nas.writeback_upload': ('Yükle', 'Upload', 'رفع'),
  'nas.writeback_keep_local': (
    'Şimdilik yükleme',
    'Don’t upload for now',
    'لا ترفع الآن',
  ),
  'nas.writeback_done': (
    'Sunucuya yüklendi.',
    'Uploaded to the server.',
    'تم الرفع إلى الخادم.',
  ),

  // ── Ağdan erişim (telefon = FTP sunucusu) ─────────────────────────────────
  //
  // Ad 2026-08-29'da "PC'den eriş (FTP)"ten "Ağdan erişim"e çevrildi: kullanıcı
  // panoda aradığı şeyi "FTP" diye aramıyor. Protokol adı ekranın içinde,
  // adresin kendisinde (ftp://…) zaten yazılı.
  'ftpd.title': ('Ağdan erişim', 'Network access', 'الوصول عبر الشبكة'),
  'ftpd.description': (
    'Telefondaki dosyalara ağdaki bilgisayardan ulaşın. Başlatın, aşağıdaki '
        'adresi PC\'de bir dosya gezginine yazın. Telefon ve PC AYNI Wi-Fi '
        'ağında olmalı.',
    'Reach the files on this phone from a computer on the network. Start it, '
        'then type the address below into a file explorer on the PC. The phone '
        'and the PC must be on the SAME Wi-Fi network.',
    'الوصول إلى ملفات الهاتف من حاسوب على الشبكة. ابدأ الخدمة ثم اكتب العنوان '
        'أدناه في مستكشف الملفات على الحاسوب. يجب أن يكون الهاتف والحاسوب على '
        'نفس شبكة Wi-Fi.',
  ),
  'ftpd.intro': (
    'Ağdan dosyalara erişmek için hizmeti başlatın.',
    'Start the service to reach the files over the network.',
    'ابدأ الخدمة للوصول إلى الملفات عبر الشبكة.',
  ),
  'ftpd.hint': (
    'Yukarıdaki adresi PC\'de bir dosya gezginine yazın.',
    'Type the address above into a file explorer on your PC.',
    'اكتب العنوان أعلاه في مستكشف الملفات على حاسوبك.',
  ),
  // İki kapı, tek paylaşım: tarayıcı (her cihaz, dosyayı AÇAR) ve FTP
  // (Gezgin, sürükle-bırak yazma). Bkz. HttpShareServer — kullanıcı hatası
  // 2026-08-29: "Edge açılıyor ama dosya açılmıyor".
  'ftpd.web_label': ('Tarayıcıda aç', 'Open in a browser', 'افتح في المتصفح'),
  'ftpd.web_hint': (
    'Bu adresi PC\'de tarayıcıya yazın: dosyalara tıklayınca açılır ya da iner.',
    'Type this address into a browser on your PC: click a file to open or '
        'download it.',
    'اكتب هذا العنوان في متصفح حاسوبك: اضغط على ملف ليُفتح أو يُنزَّل.',
  ),
  'ftpd.ftp_label': (
    'Dosya gezgini (FTP)',
    'File explorer (FTP)',
    'مستكشف الملفات (FTP)',
  ),
  'ftpd.ftp_hint': (
    'Gezgin\'e yazın: sürükleyip bırakarak kopyalayın. Tarayıcılar FTP\'yi '
        'artık desteklemiyor — dosyayı açmak için üstteki adresi kullanın.',
    'Type it into Explorer to copy by drag and drop. Browsers no longer '
        'support FTP — use the address above to open a file.',
    'اكتبه في المستكشف للنسخ بالسحب والإفلات. المتصفحات لم تعد تدعم FTP — '
        'استخدم العنوان أعلاه لفتح ملف.',
  ),
  'ftpd.random_password': (
    'Rastgele şifre',
    'Random password',
    'كلمة مرور عشوائية',
  ),
  'ftpd.show_hidden': (
    'Gizli dosyaları göster',
    'Show hidden files',
    'إظهار الملفات المخفية',
  ),
  'ftpd.clients': (
    '{n} bilgisayar bağlı',
    '{n} computer(s) connected',
    '{n} حاسوب متصل',
  ),
  'ftpd.folders_hint': (
    'PC\'de telefondaki kutuları görürsünüz: Belgeler, Resimler, Videolar, '
        'Ses, Arsivler, Uygulamalar, Indirilenler, Kamera — ve tüm dosyalar '
        'için "Telefon". Hangilerinin paylaşılacağını yukarıdan seçebilir, '
        'yalnız "Paylaşılan" klasörünü de paylaşabilirsiniz.',
    'On the PC you will see the same boxes as on the phone: Belgeler, '
        'Resimler, Videolar, Ses, Arsivler, Uygulamalar, Indirilenler, Kamera '
        '— plus "Telefon" for everything. You can pick which ones are shared '
        'above, or share only the "Paylasilan" folder.',
    'على الحاسوب سترى نفس الصناديق الموجودة على الهاتف: المستندات والصور '
        'والفيديو والصوت والأرشيف والتطبيقات والتنزيلات والكاميرا — بالإضافة '
        'إلى "Telefon" لكل الملفات. يمكنك اختيار ما يُشارك من الأعلى، أو '
        'مشاركة مجلد "Paylasilan" فقط.',
  ),
  'ftpd.notification_hint': (
    'Açık kaldığı sürece bildirim panelinde görünür; uygulamayı kapatınca '
        'kendiliğinden durur.',
    'It stays visible in the notification panel while on, and stops by itself '
        'when you close the app.',
    'تبقى ظاهرة في لوحة الإشعارات أثناء التشغيل، وتتوقف تلقائيًا عند إغلاق '
        'التطبيق.',
  ),
  'ftpd.open_action': ('Ağdan erişim açık', 'Network access is on', 'الوصول عبر الشبكة مفعّل'),
  'ftpd.advanced': ('Gelişmiş', 'Advanced', 'إعدادات متقدمة'),
  'ftpd.start': ('BAŞLAT', 'START', 'ابدأ'),
  'ftpd.stop': ('HİZMETİ DURDUR', 'STOP THE SERVICE', 'أوقف الخدمة'),
  'ftpd.running': ('Çalışıyor', 'Running', 'قيد التشغيل'),
  'ftpd.stopped': ('Durdu', 'Stopped', 'متوقف'),
  'ftpd.address': ('Adres', 'Address', 'العنوان'),
  'ftpd.no_address': (
    'Wi-Fi bağlantısı bulunamadı. Telefonu bir Wi-Fi ağına bağlayın.',
    'No Wi-Fi connection found. Connect the phone to a Wi-Fi network.',
    'لم يُعثر على اتصال Wi-Fi. صل الهاتف بشبكة Wi-Fi.',
  ),
  'ftpd.allow_write': ('Yazmaya izin ver', 'Allow writing', 'السماح بالكتابة'),
  'ftpd.allow_write_note': (
    'Kapalıyken PC yalnız okuyabilir. Açarsanız PC telefondaki dosyaları '
        'değiştirebilir ve SİLEBİLİR.',
    'While off, the PC can only read. If you turn it on, the PC can modify and '
        'DELETE files on the phone.',
    'عند الإيقاف، يمكن للحاسوب القراءة فقط. عند التفعيل، يمكنه تعديل وحذف ملفات '
        'الهاتف.',
  ),
  'ftpd.anonymous_warning': (
    'Kullanıcı adı boş: AYNI AĞDAKİ HERKES parolasız bağlanabilir.',
    'Username is empty: ANYONE ON THE SAME NETWORK can connect without a password.',
    'اسم المستخدم فارغ: يمكن لأي شخص على نفس الشبكة الاتصال بدون كلمة مرور.',
  ),

  // ── Paylaşılacak klasör seçimi (kullanıcı isteği 2026-08-31) ─────────────
  //
  // *"ağ paylaşımında hangi klasörlerin paylaşılacağını seçelim, bir de ayrı
  // olarak paylaşılan klasörü olsun, kişi göndermek istediği şeyi oraya
  // atsın ve sadece o klasör paylaşılır."* Gerekçe: paylaşım o güne dek hep
  // ya hep yoktu — iki dosya göndermek için telefonun tamamı ağa açılıyordu.
  'ftpd.folders_title': (
    'Paylaşılacak klasörler',
    'Folders to share',
    'المجلدات المشتركة',
  ),
  'ftpd.folders_all': ('Tümü paylaşılıyor', 'Everything is shared', 'كل شيء مشترك'),
  'ftpd.folders_count': (
    '{n} klasör paylaşılıyor',
    '{n} folder(s) shared',
    'مشاركة {n} مجلد',
  ),
  'ftpd.folders_none': (
    'Hiçbir klasör seçilmedi',
    'No folder selected',
    'لم يتم اختيار أي مجلد',
  ),
  'ftpd.folders_none_warning': (
    'Hiçbir klasör seçili değil: paylaşım açılsa da bilgisayarda boş görünür.',
    'No folder is selected: even when the share is on, the PC will see nothing.',
    'لم يتم اختيار أي مجلد: حتى عند تشغيل المشاركة، لن يرى الحاسوب شيئًا.',
  ),
  'ftpd.mode_boxes': (
    'Seçtiğim klasörler',
    'The folders I choose',
    'المجلدات التي أختارها',
  ),
  'ftpd.mode_boxes_desc': (
    'Aşağıdan işaretlediğiniz klasörler paylaşılır; kalanlar ağda görünmez.',
    'Only the folders you tick below are shared; the rest stay invisible.',
    'تتم مشاركة المجلدات المحددة أدناه فقط؛ ويبقى الباقي غير مرئي.',
  ),
  'ftpd.mode_shared': (
    'Yalnız Paylaşılan klasörü',
    'Only the Shared folder',
    'مجلد "المشترك" فقط',
  ),
  'ftpd.mode_shared_desc': (
    'Göndermek istediğinizi "Paylaşılan" klasörüne atın; telefonun geri kalanı '
        'ağda hiç görünmez.',
    'Drop what you want to send into the "Shared" folder; the rest of the phone '
        'is not visible on the network at all.',
    'ضع ما تريد إرساله في مجلد "المشترك"؛ ولن يظهر باقي الهاتف على الشبكة.',
  ),
  'ftpd.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'ftpd.clear_all': ('Seçimi kaldır', 'Clear selection', 'إلغاء التحديد'),
  'ftpd.box_on_pc': (
    'Bilgisayarda: {name}',
    'On the PC: {name}',
    'على الحاسوب: {name}',
  ),
  'ftpd.box_shared': ('Paylaşılan', 'Shared', 'المشترك'),
  'ftpd.box_storage': ('Telefonun tamamı', 'The whole phone', 'كل الهاتف'),
  'ftpd.box_downloads': ('İndirilenler', 'Downloads', 'التنزيلات'),
  'ftpd.box_camera': ('Kamera', 'Camera', 'الكاميرا'),
  'ftpd.box_screenshots': ('Ekran görüntüleri', 'Screenshots', 'لقطات الشاشة'),
  'ftpd.box_images': ('Resimler', 'Images', 'الصور'),
  'ftpd.box_videos': ('Videolar', 'Videos', 'الفيديو'),
  'ftpd.box_audio': ('Ses', 'Audio', 'الصوت'),
  'ftpd.box_documents': ('Belgeler', 'Documents', 'المستندات'),
  'ftpd.box_archives': ('Arşivler', 'Archives', 'الأرشيف'),
  'ftpd.box_apps': ('Uygulamalar', 'Apps', 'التطبيقات'),
  'ftpd.shared_folder_hint': (
    'Telefonda "Paylaşılan" klasörü. Bir dosyanın ⋮ menüsünden '
        '"Paylaşılan\'a kopyala" ile buraya atabilirsiniz.',
    'The "Paylaşılan" folder on the phone. Use "Copy to Shared" in a file\'s '
        '⋮ menu to put something here.',
    'مجلد "Paylaşılan" على الهاتف. استخدم "نسخ إلى المشترك" من قائمة ⋮ للملف '
        'لوضع شيء هنا.',
  ),
  'ftpd.copied': ('Adres kopyalandı.', 'Address copied.', 'تم نسخ العنوان.'),
  'ftpd.start_failed': (
    'Sunucu başlatılamadı: {error}',
    'Could not start the server: {error}',
    'تعذّر بدء الخادم: {error}',
  ),

  // ── Google Drive ──────────────────────────────────────────────────────────
  'drive.title': ('Google Drive', 'Google Drive', 'Google Drive'),
  'drive.upload_action': ('Drive\'a yükle', 'Upload to Drive', 'رفع إلى Drive'),
  'drive.sign_in': ('Google ile bağlan', 'Connect with Google', 'الاتصال عبر Google'),
  'drive.sign_out': ('Bağlantıyı kes', 'Disconnect', 'قطع الاتصال'),
  'drive.sign_in_prompt': (
    'Drive\'ınızı buradan gezmek, dosya açmak, yüklemek ve klasör düzenlemek '
        'için Google hesabınıza bağlanın.',
    'Connect your Google account to browse your Drive here, open and upload '
        'files, and organise folders.',
    'اتصل بحساب Google لتصفح Drive من هنا وفتح الملفات ورفعها وتنظيم المجلدات.',
  ),
  'drive.root': ('Drive\'ım', 'My Drive', 'ملفاتي'),
  'drive.new_folder': ('Yeni klasör', 'New folder', 'مجلد جديد'),
  'drive.new_folder_default': ('Yeni klasör', 'New folder', 'مجلد جديد'),
  'drive.new_folder_failed': (
    'Klasör oluşturulamadı.',
    'Could not create the folder.',
    'تعذّر إنشاء المجلد.',
  ),
  'drive.rename': ('Yeniden adlandır', 'Rename', 'إعادة تسمية'),
  'drive.rename_failed': (
    'Yeniden adlandırılamadı.',
    'Could not rename.',
    'تعذّرت إعادة التسمية.',
  ),
  // Tam erişimden sonra "henüz yüklemediniz" yanlış: klasör gerçekten boş
  // olabilir, kullanıcının bir şey yüklememesiyle ilgisi yok.
  'drive.empty': (
    'Bu klasör boş.',
    'This folder is empty.',
    'هذا المجلد فارغ.',
  ),
  'drive.empty_search': (
    'Eşleşen dosya bulunamadı.',
    'No matching files found.',
    'لم يُعثر على ملفات مطابقة.',
  ),
  'drive.search_hint': ('Drive\'da ara…', 'Search Drive…', 'ابحث في Drive…'),
  'drive.exports_as': (
    '{format} olarak iner',
    'downloads as {format}',
    'يُنزَّل بصيغة {format}',
  ),
  'drive.uploading': ('Drive\'a yükleniyor…', 'Uploading to Drive…', 'جارٍ الرفع إلى Drive…'),
  'drive.upload_name': ("Drive'a yükleme", 'Upload to Drive', 'الرفع إلى Drive'),
  'drive.upload_done': ('Drive\'a yüklendi:', 'Uploaded to Drive:', 'تم الرفع إلى Drive:'),
  'drive.upload_failed': ('Drive\'a yüklenemedi.', 'Upload to Drive failed.', 'فشل الرفع إلى Drive.'),
  'drive.download_failed': ('Dosya indirilemedi.', 'Could not download the file.', 'تعذّر تنزيل الملف.'),
  'drive.downloading': ('Drive\'dan indiriliyor…', 'Downloading from Drive…', 'جارٍ التنزيل من Drive…'),
  'drive.ready_offscreen': (
    'İndirildi, açmak için dokunun:',
    'Downloaded — tap it to open:',
    'تم التنزيل — انقر لفتحه:'
  ),
  'drive.download_stopped': (
    'İndirme durduruldu.',
    'Download stopped.',
    'تم إيقاف التنزيل.'
  ),
  // Kalıcı silme DEĞİL (2026-08-06): dosya Drive'ın çöp kutusuna gider ve
  // 30 gün geri alınabilir — metin de bunu söylemeli.
  'drive.delete_confirm': (
    '“{name}” Drive\'ın çöp kutusuna taşınsın mı?',
    'Move “{name}” to the Drive trash?',
    'هل تريد نقل «{name}» إلى سلة محذوفات Drive؟',
  ),
  'drive.delete_failed': ('Silinemedi.', 'Could not delete.', 'تعذّر الحذف.'),
  'drive.download': ('Telefona indir…', 'Download to phone…', 'تنزيل إلى الهاتف…'),
  'drive.download_here': ('Buraya indir', 'Download here', 'التنزيل هنا'),
  'drive.downloaded': (
    'İndirildi: {folder}',
    'Downloaded to: {folder}',
    'تم التنزيل إلى: {folder}',
  ),
  'drive.star': ('Yıldız ekle', 'Add star', 'إضافة نجمة'),
  'drive.unstar': ('Yıldızı kaldır', 'Remove star', 'إزالة النجمة'),
  'drive.star_failed': (
    'Yıldız değiştirilemedi.',
    'Could not change the star.',
    'تعذّر تغيير النجمة.',
  ),
  'drive.info': ('Bilgi', 'Details', 'التفاصيل'),
  'drive.info_kind': ('Tür', 'Kind', 'النوع'),
  'drive.info_size': ('Boyut', 'Size', 'الحجم'),
  'drive.info_modified': ('Değiştirilme', 'Modified', 'آخر تعديل'),
  'drive.info_created': ('Oluşturulma', 'Created', 'تاريخ الإنشاء'),
  'drive.info_owner': ('Sahibi', 'Owner', 'المالك'),
  'drive.info_shared': ('Paylaşım', 'Sharing', 'المشاركة'),
  'drive.info_starred': ('Yıldızlı', 'Starred', 'المميزة بنجمة'),
  'drive.shared_yes': (
    'Paylaşılmış',
    'Shared with others',
    'مُشارَك مع آخرين',
  ),
  'drive.shared_no': ('Yalnız siz', 'Only you', 'أنت فقط'),
  'drive.sort': ('Sıralama', 'Sort', 'الترتيب'),
  'drive.folder': ('Klasör', 'Folder', 'مجلد'),
  'drive.share_link': ('Bağlantıyı paylaş', 'Share link', 'مشاركة الرابط'),
  'drive.share_file': ('Dosyayı paylaş', 'Share file', 'مشاركة الملف'),
  'drive.share_failed': (
    'Paylaşım bağlantısı oluşturulamadı.',
    'Could not create the share link.',
    'تعذّر إنشاء رابط المشاركة.',
  ),
  'drive.paste_failed': ('Yapıştırılamadı.', 'Could not paste.', 'تعذّر اللصق.'),
  // Aynı klasöre kopyalanan dosyanın adına eklenir: "Rapor (kopya).pdf".
  'drive.copy_tag': ('kopya', 'copy', 'نسخة'),
  'drive.error_not_signed_in': (
    'Google hesabına bağlı değilsiniz.',
    'You are not connected to a Google account.',
    'أنت غير متصل بحساب Google.',
  ),
  // Giriş neden olmadı? Kullanıcı hatası 2026-07-30 ("drive olmadı"): tek ve
  // aynı "bağlı değilsiniz" metni her nedene veriliyordu. Aşağıdakiler ayrı
  // ayrı NE YAPILACAĞINI söylüyor.
  'drive.error_not_configured': (
    'Google girişi bu APK için etkinleştirilmemiş. Uygulamanın imzası '
        'Google Cloud\'a "Android OAuth istemcisi" olarak kaydedilmeden '
        'hesap bağlanamıyor (Google\'ın kuralı; kod tarafında çözülemez). '
        'Aşağıdaki sistem seçicisi yolu bu kayıt olmadan da çalışır.',
    'Google sign-in is not enabled for this APK. An account cannot be '
        'connected until the app signature is registered in Google Cloud as '
        'an "Android OAuth client" (Google\'s rule; not fixable in code). '
        'The system picker below works without that registration.',
    'لم يُفعَّل تسجيل الدخول بحساب Google لهذه النسخة. لا يمكن ربط حساب قبل '
        'تسجيل توقيع التطبيق في Google Cloud كـ«عميل OAuth لأندرويد» (قاعدة من '
        'Google ولا تُحل برمجيًا). أما منتقي النظام أدناه فيعمل بدون ذلك.',
  ),
  // Kurulum kartı: notConfigured hatasında paket adı + SHA-1'i telefondan
  // kopyalatır. Değerleri belgeye gömmek yetmiyordu — kullanıcının elinde
  // kayıt için gereken iki değer de yoktu ("google drive girmiyorum",
  // 2026-08-05). SHA-1 çalışan APK'nın KENDİ imzasından okunur.
  'drive.setup_title': (
    'Tek seferlik kurulum bilgileri',
    'One-time setup values',
    'قيم الإعداد لمرة واحدة',
  ),
  'drive.setup_steps': (
    'console.cloud.google.com → API\'ler ve Hizmetler → Kimlik bilgileri → '
        'OAuth istemci kimliği (Android) sayfasında aşağıdaki iki değeri girin. '
        'OAuth izin ekranı "Test" modundaysa hesabınızı test kullanıcılarına '
        'ekleyin. Ayrıntı: docs/GOOGLE-DRIVE-KURULUM.md',
    'Enter the two values below at console.cloud.google.com → APIs & '
        'Services → Credentials → OAuth client ID (Android). If the OAuth '
        'consent screen is in "Testing" mode, add your account as a test '
        'user. Details: docs/GOOGLE-DRIVE-KURULUM.md',
    'أدخل القيمتين أدناه في console.cloud.google.com ← واجهات برمجة التطبيقات '
        'والخدمات ← بيانات الاعتماد ← معرّف عميل OAuth (أندرويد). إذا كانت شاشة '
        'موافقة OAuth في وضع «الاختبار» فأضف حسابك كمستخدم اختبار. التفاصيل: '
        'docs/GOOGLE-DRIVE-KURULUM.md',
  ),
  'drive.setup_package': ('Paket adı', 'Package name', 'اسم الحزمة'),
  'drive.setup_sha1': ('İmza SHA-1', 'Signing SHA-1', 'بصمة SHA-1'),
  'drive.setup_copied': ('Kopyalandı.', 'Copied.', 'تم النسخ.'),
  'drive.error_no_play_services': (
    'Bu cihazda Google Play Hizmetleri yok ya da güncel değil; Google girişi '
        'çalışmıyor. Aşağıdaki sistem seçicisi yolunu kullanabilirsiniz.',
    'Google Play Services is missing or outdated on this device, so Google '
        'sign-in cannot run. You can use the system picker below.',
    'خدمات Google Play غير متوفرة أو قديمة على هذا الجهاز، لذا لا يعمل تسجيل '
        'الدخول. يمكنك استخدام منتقي النظام أدناه.',
  ),
  'drive.error_sign_in_failed': (
    'Google girişi tamamlanamadı.',
    'Google sign-in could not be completed.',
    'تعذّر إتمام تسجيل الدخول بحساب Google.',
  ),
  'drive.system_picker_hint': (
    'Giriş çalışmasa da Drive\'ınızın TAMAMINA ulaşabilirsiniz: Android\'in '
        'sistem seçicisi Drive\'ı dosya kaynağı olarak listeler ve hiçbir '
        'yetki istemez.',
    'Even if sign-in does not work you can still reach ALL of your Drive: '
        'Android\'s system picker lists Drive as a file source and asks for '
        'no permissions.',
    'حتى لو لم يعمل تسجيل الدخول يمكنك الوصول إلى كامل Drive: يعرض منتقي نظام '
        'أندرويد خدمة Drive كمصدر للملفات ولا يطلب أي أذونات.',
  ),
  'drive.open_via_system': (
    'Sistem seçicisiyle Drive dosyası aç',
    'Open a Drive file with the system picker',
    'فتح ملف من Drive عبر منتقي النظام',
  ),
  'drive.error_forbidden': (
    'Drive bu işleme izin vermedi. Bu dosya uygulamamızla yüklenmemiş olabilir.',
    'Drive denied this operation. The file may not have been uploaded with this app.',
    'رفض Drive هذه العملية. قد لا يكون الملف مرفوعًا بواسطة هذا التطبيق.',
  ),
  // 403'ün İKİ ayrı nedeni (kullanıcı ekran görüntüsü 2026-08-05): giriş
  // çalışıyor ama liste 403. "İzin vermedi" demek kullanıcıyı dosya
  // sahipliğine baktırıyordu; asıl neden çoğu kez API'nin hiç açılmamış olması.
  'drive.error_api_not_enabled': (
    'Google Drive API bu projede etkin değil. Google Cloud Console → '
        'API\'ler ve Hizmetler → Kitaplık → "Google Drive API" → Etkinleştir '
        'adımını uygulayın; birkaç dakika sonra tekrar deneyin.',
    'The Google Drive API is not enabled for this project. Go to Google Cloud '
        'Console → APIs & Services → Library → "Google Drive API" → Enable, '
        'then try again in a few minutes.',
    'واجهة Google Drive API غير مفعّلة في هذا المشروع. انتقل إلى Google Cloud '
        'Console ← واجهات برمجة التطبيقات والخدمات ← المكتبة ← «Google Drive '
        'API» ← تفعيل، ثم أعد المحاولة بعد دقائق.',
  ),
  'drive.error_insufficient_scope': (
    'Hesap bağlandı ama Drive izni verilmemiş. Bağlantıyı kesip yeniden '
        'bağlanın ve izin penceresinde Drive erişimini onaylayın.',
    'The account is connected but Drive permission was not granted. '
        'Disconnect, connect again and approve Drive access in the consent '
        'dialog.',
    'تم ربط الحساب لكن لم يُمنح إذن Drive. اقطع الاتصال ثم أعد الربط ووافق على '
        'الوصول إلى Drive في نافذة الأذونات.',
  ),
  'drive.error_not_found': ('Dosya Drive\'da bulunamadı.', 'File not found on Drive.', 'لم يُعثر على الملف في Drive.'),
  'drive.error_temporary': (
    'Drive şu an yanıt vermiyor, biraz sonra deneyin.',
    'Drive is not responding right now, try again shortly.',
    'لا يستجيب Drive حاليًا، حاول بعد قليل.',
  ),
  'drive.error_unknown': ('Drive bağlantısında hata.', 'Drive connection error.', 'خطأ في الاتصال بـ Drive.'),

  // ── Word ──────────────────────────────────────────────────────────────────
  'word.page_view': ('Sayfa görünümü', 'Page view', 'عرض الصفحة'),
  'word.text_editor': ('Metin düzenleyici', 'Text editor', 'محرر النص'),
  'word.bullet_list': ('Madde işareti', 'Bulleted list', 'قائمة نقطية'),
  'word.numbered_list': ('Numaralı liste', 'Numbered list', 'قائمة مرقّمة'),
  'word.add_paragraph_below': (
    'Altına paragraf ekle',
    'Add paragraph below',
    'إضافة فقرة بالأسفل',
  ),
  'word.delete_paragraph': ('Paragrafı sil', 'Delete paragraph', 'حذف الفقرة'),
  'word.live_edit_unsafe': (
    'Bu belgede canlı düzenleme güvenli değil (paragraf eşleşmedi: '
        '{web}/{ours}). ⋮ > Metin düzenleyici kullanın.',
    'Live editing is not safe in this document (paragraph mismatch: '
        '{web}/{ours}). Use ⋮ > Text editor.',
    'التحرير المباشر غير آمن في هذا المستند (عدم تطابق الفقرات: '
        '{web}/{ours}). استخدم ⋮ > محرر النص.',
  ),
  'word.done': ('Bitti', 'Done', 'تم'),
  'word.text_color': ('Yazı rengi', 'Text color', 'لون النص'),
  'word.highlight': ('Vurgu rengi', 'Highlight', 'لون التمييز'),
  'word.bullets': ('Madde işareti', 'Bullets', 'تعداد نقطي'),
  'word.numbering': ('Numaralandırma', 'Numbering', 'تعداد رقمي'),
  'word.rewrite_selection': (
    'Seçimi AI ile düzelt',
    'Rewrite selection with AI',
    'أعد صياغة التحديد بالذكاء الاصطناعي',
  ),
  'word.translate_selection': (
    'Seçimi çevir',
    'Translate selection',
    'ترجم التحديد',
  ),
  'word.select_text_first': (
    'Önce belgede metin seçin',
    'Select some text in the document first',
    'حدد نصًا في المستند أولًا',
  ),
  'word.replace_needs_edit': (
    'Değiştirmek için önce düzenlemeye geçin',
    'Switch to editing to replace',
    'انتقل إلى التحرير للاستبدال',
  ),
  'word.page_of': ('Sayfa {n} / {total}', 'Page {n} / {total}', 'الصفحة {n} / {total}'),
  'word.goto_page': ('Sayfaya git', 'Go to page', 'الانتقال إلى صفحة'),
  'word.goto_page_hint': (
    '1 – {total} arası',
    'Between 1 and {total}',
    'بين 1 و {total}',
  ),
  'word.font_family': ('Yazı tipi', 'Font', 'نوع الخط'),
  'word.font_size': ('Punto', 'Size', 'حجم الخط'),
  'word.add_paragraph': ('Paragraf ekle', 'Add paragraph', 'إضافة فقرة'),
  'word.page_layout': ('Sayfa', 'Page', 'صفحة'),
  'word.mobile_flow': ('Mobil', 'Mobile', 'الجوال'),
  'word.save_failed': (
    'Kaydedilemedi: {error}',
    'Could not save: {error}',
    'تعذّر الحفظ: {error}',
  ),
  'word.rtl_document': (
    'Sağdan sola belge',
    'Right-to-left document',
    'مستند من اليمين إلى اليسار',
  ),

  // ── Excel ─────────────────────────────────────────────────────────────────
  'excel.row': ('Satır', 'Row', 'صف'),
  'excel.column': ('Sütun', 'Column', 'عمود'),
  'excel.insert_row_above': ('Üste satır ekle', 'Insert row above', 'إدراج صف بالأعلى'),
  'excel.insert_row_below': ('Alta satır ekle', 'Insert row below', 'إدراج صف بالأسفل'),
  'excel.delete_row': ('Satırı sil', 'Delete row', 'حذف الصف'),
  'excel.insert_col_left': ('Sola sütun ekle', 'Insert column left', 'إدراج عمود لليسار'),
  'excel.insert_col_right': ('Sağa sütun ekle', 'Insert column right', 'إدراج عمود لليمين'),
  'excel.delete_col': ('Sütunu sil', 'Delete column', 'حذف العمود'),
  'excel.goto_cell': ('Hücreye git', 'Go to cell', 'الانتقال إلى خلية'),
  'excel.goto_cell_menu': ('Hücreye git…', 'Go to cell…', 'الانتقال إلى خلية…'),
  'excel.cell_reference': ('Hücre başvurusu', 'Cell reference', 'مرجع الخلية'),
  'excel.cell_reference_hint': ('ör. C15', 'e.g. C15', 'مثال: C15'),
  'excel.cell_content': ('Hücre içeriği', 'Cell content', 'محتوى الخلية'),
  'excel.cell_label': ('Hücre {ref}', 'Cell {ref}', 'الخلية {ref}'),
  'excel.sheet_pos': (
    'Sayfa {n} / {total}',
    'Sheet {n} / {total}',
    'الورقة {n} / {total}',
  ),
  'excel.column_width': ('Sütun genişliği…', 'Column width…', 'عرض العمود…'),
  'excel.row_height': ('Satır yüksekliği…', 'Row height…', 'ارتفاع الصف…'),
  'excel.column_width_of': (
    '{col} sütun genişliği',
    'Width of column {col}',
    'عرض العمود {col}',
  ),
  'excel.row_height_of': (
    '{row}. satır yüksekliği',
    'Height of row {row}',
    'ارتفاع الصف {row}',
  ),
  'excel.default_value': (
    'Varsayılan ({value})',
    'Default ({value})',
    'الافتراضي ({value})',
  ),
  'excel.freeze_panes': (
    'Bölmeleri dondur (dosyadaki gibi)',
    'Freeze panes (as in the file)',
    'تجميد الأجزاء (كما في الملف)',
  ),
  'excel.unfreeze_panes': (
    'Bölmeleri çöz (sabit satır/sütun)',
    'Unfreeze panes (fixed rows/columns)',
    'إلغاء تجميد الأجزاء (صفوف/أعمدة ثابتة)',
  ),
  'excel.panes_trimmed': (
    'Dosyadaki sabit bölme ekrana sığmadı; o sütunlar kaydırılabilir yapıldı. '
        '⋮ > Bölmeleri çöz ile tamamen kapatabilirsiniz.',
    'The frozen pane in the file did not fit the screen, so those columns were '
        'made scrollable. You can turn it off entirely with ⋮ > Unfreeze panes.',
    'لم يتّسع الجزء المجمّد في الملف للشاشة، لذا أصبحت تلك الأعمدة قابلة للتمرير. '
        'يمكنك إيقافه تمامًا عبر ⋮ > إلغاء تجميد الأجزاء.',
  ),
  'excel.sheet_rtl': (
    'Sayfa sağdan sola',
    'Right-to-left sheet',
    'الورقة من اليمين إلى اليسار',
  ),
  'excel.sheet_rtl_on': (
    'Sayfa sağdan sola çizilecek (A sütunu sağda).',
    'The sheet will be laid out right-to-left (column A on the right).',
    'سيتم عرض الورقة من اليمين إلى اليسار (العمود A على اليمين).',
  ),
  'excel.sheet_rtl_off': (
    'Sayfa soldan sağa çizilecek (A sütunu solda).',
    'The sheet will be laid out left-to-right (column A on the left).',
    'سيتم عرض الورقة من اليسار إلى اليمين (العمود A على اليسار).',
  ),
  'excel.selection_cells': (
    'Seçili: {n} hücre',
    'Selected: {n} cells',
    'المحدد: {n} خلية',
  ),
  'excel.selection_filled': (
    'Seçili: {n} hücre  ·  Dolu: {filled}',
    'Selected: {n} cells  ·  Filled: {filled}',
    'المحدد: {n} خلية  ·  المملوءة: {filled}',
  ),
  'excel.selection_stats': (
    'Ortalama: {avg}  ·  Sayı: {count}  ·  Toplam: {sum}',
    'Average: {avg}  ·  Count: {count}  ·  Sum: {sum}',
    'المتوسط: {avg}  ·  العدد: {count}  ·  المجموع: {sum}',
  ),
  'excel.csv_encoding': ('CSV kodlaması', 'CSV encoding', 'ترميز CSV'),
  'excel.csv_utf8': ('UTF-8 (önerilir)', 'UTF-8 (recommended)', 'UTF-8 (مستحسن)'),
  'excel.csv_utf8_sub': (
    'Modern Excel / Google E-Tablolar',
    'Modern Excel / Google Sheets',
    'Excel الحديث / جداول بيانات Google',
  ),
  'excel.csv_legacy': (
    'Eski Türkçe Excel / Not Defteri',
    'Legacy Turkish Excel / Notepad',
    'Excel/المفكرة التركية القديمة',
  ),
  'excel.csv_failed': (
    'CSV dışa aktarılamadı: {error}',
    'CSV export failed: {error}',
    'فشل تصدير CSV: {error}',
  ),
  'excel.pick_from_list': ('Listeden seç', 'Pick from list', 'اختر من القائمة'),
  'excel.no_sheet': ('Sayfa yok.', 'No sheet.', 'لا توجد ورقة.'),
  'excel.go': ('Git', 'Go', 'انتقال'),
  'excel.find_in_sheet': ('Bu sayfada ara', 'Search this sheet', 'ابحث في هذه الورقة'),
  'excel.hidden': ('Gizli', 'Hidden', 'مخفي'),
  'excel.unit_chars': ('karakter', 'characters', 'حرفًا'),
  'excel.unit_points': ('punto', 'points', 'نقطة'),

  // ── Düzenleme: geri al, pano, doldurma, Σ, değiştir ───────────────────────
  'excel.undo': ('Geri al', 'Undo', 'تراجع'),
  'excel.redo': ('Yinele', 'Redo', 'إعادة'),
  'excel.undone': ('Geri alındı: {what}', 'Undone: {what}', 'تم التراجع: {what}'),
  'excel.redone': ('Yinelendi: {what}', 'Redone: {what}', 'تمت الإعادة: {what}'),
  'excel.undo_typing': ('yazma', 'typing', 'الكتابة'),
  'excel.undo_paste': ('yapıştırma', 'paste', 'اللصق'),
  'excel.undo_clear': ('temizleme', 'clear', 'المسح'),
  'excel.undo_fill': ('doldurma', 'fill', 'التعبئة'),
  'excel.undo_autosum': ('otomatik toplam', 'AutoSum', 'الجمع التلقائي'),
  'excel.undo_format': ('biçimlendirme', 'formatting', 'التنسيق'),
  'excel.undo_replace': ('değiştirme', 'replace', 'الاستبدال'),
  'excel.undo_insert_row': ('satır ekleme', 'insert row', 'إدراج صف'),
  'excel.undo_delete_row': ('satır silme', 'delete row', 'حذف صف'),
  'excel.undo_insert_col': ('sütun ekleme', 'insert column', 'إدراج عمود'),
  'excel.undo_delete_col': ('sütun silme', 'delete column', 'حذف عمود'),
  'excel.cut': ('Kes', 'Cut', 'قص'),
  'excel.paste': ('Yapıştır', 'Paste', 'لصق'),
  'excel.clear_contents': ('İçeriği temizle', 'Clear contents', 'مسح المحتويات'),
  'excel.autosum': ('Otomatik toplam', 'AutoSum', 'الجمع التلقائي'),
  'excel.autosum_empty': (
    'Toplanacak bitişik sayı bulunamadı — aralığı kendiniz yazın.',
    'No adjacent numbers to sum — type the range yourself.',
    'لا توجد أرقام متجاورة للجمع — اكتب النطاق بنفسك.',
  ),
  'excel.copy_done': ('{n} hücre kopyalandı', '{n} cells copied', 'تم نسخ {n} خلية'),
  'excel.cut_done': ('{n} hücre kesildi', '{n} cells cut', 'تم قص {n} خلية'),
  'excel.clipboard_empty': ('Pano boş.', 'Clipboard is empty.', 'الحافظة فارغة.'),
  'excel.replace': ('Değiştir', 'Replace', 'استبدال'),
  'excel.replace_all': ('Tümünü değiştir', 'Replace all', 'استبدال الكل'),
  'excel.replace_with': ('Şununla değiştir', 'Replace with', 'استبدال بـ'),
  'excel.replace_none': (
    'Değiştirilecek eşleşme yok.',
    'No matches to replace.',
    'لا توجد تطابقات للاستبدال.',
  ),
  'word.undo': ('Geri al', 'Undo', 'تراجع'),
  'word.redo': ('Yinele', 'Redo', 'إعادة'),
  'word.undone': ('Geri alındı: {what}', 'Undone: {what}', 'تم التراجع: {what}'),
  'word.redone': ('Yinelendi: {what}', 'Redone: {what}', 'تمت الإعادة: {what}'),
  'word.undo_add_paragraph': ('paragraf ekleme', 'add paragraph', 'إضافة فقرة'),
  'word.undo_delete_paragraph': ('paragraf silme', 'delete paragraph', 'حذف فقرة'),
  'excel.alignment': ('Hizalama', 'Alignment', 'المحاذاة'),
  'excel.group_clipboard': ('Pano', 'Clipboard', 'الحافظة'),
  'excel.group_number': ('Sayı', 'Number', 'رقم'),
  'excel.number_format': ('Sayı biçimi', 'Number format', 'تنسيق الأرقام'),
  'excel.fmt_general': ('Genel', 'General', 'عام'),
  'excel.fmt_number': ('Sayı (1.234,50)', 'Number (1,234.50)', 'رقم (1,234.50)'),
  'excel.fmt_thousands': ('Binlik (1.234)', 'Thousands (1,234)', 'آلاف (1,234)'),
  'excel.fmt_currency': ('Para (₺)', 'Currency (₺)', 'عملة (₺)'),
  'excel.fmt_percent': ('Yüzde (%15)', 'Percent (15%)', 'نسبة (15%)'),
  'excel.fmt_date': ('Tarih', 'Date', 'تاريخ'),
  'excel.fmt_time': ('Saat', 'Time', 'وقت'),
  'excel.fmt_text': ('Metin', 'Text', 'نص'),
  'excel.decimal_more': ('Ondalık artır', 'Increase decimals', 'زيادة المنازل العشرية'),
  'excel.decimal_less': ('Ondalık azalt', 'Decrease decimals', 'إنقاص المنازل العشرية'),
  'excel.undo_number_format': ('sayı biçimi', 'number format', 'تنسيق الأرقام'),
  'excel.group_format': ('Biçim', 'Format', 'تنسيق'),
  'ana.cache_total': (
    'Bunun {v} kadarı önbellek — silinmesi güvenli',
    '{v} of this is cache — safe to clear',
    '{v} من هذا ذاكرة مؤقتة — آمن حذفها',
  ),
  'clean.app_backup': (
    'Uygulama yedekleri',
    'App backups',
    'نسخ التطبيقات الاحتياطية',
  ),
  'clean.app_backup_detail': (
    '{n} yedek dosyası (.bak). Bunlar uygulamaların ÇALIŞMASI için gerekli '
        'değil — bir yedekleme aracının aldığı kopyalar. Silince yüklü '
        'uygulamalar bozulmaz; yalnız bu yedekten geri yükleme imkânı gider.',
    '{n} backup files (.bak). Apps do NOT need these to run — they are copies '
        'made by a backup tool. Deleting them will not break installed apps; '
        'you only lose the ability to restore from this backup.',
    '{n} ملف نسخ احتياطي (.bak). التطبيقات لا تحتاجها للعمل — إنها نسخ أنشأتها '
        'أداة نسخ احتياطي. حذفها لا يعطّل التطبيقات المثبتة؛ تفقد فقط إمكانية '
        'الاستعادة من هذه النسخة.',
  ),
  'fm.apps': ('Uygulamalar', 'Apps', 'التطبيقات'),
  'fm.files': ('Dosyalar', 'Files', 'الملفات'),
  'fm.calc_size': ('Boyutu hesapla', 'Calculate size', 'حساب الحجم'),
  'fm.copy_path': ('Yolu kopyala', 'Copy path', 'نسخ المسار'),
  'fm.new_xlsx': (
    'Excel tablosu (.xlsx)',
    'Excel spreadsheet (.xlsx)',
    'جدول Excel (.xlsx)',
  ),
  'fm.to_background': ('Arka plana al', 'Run in background', 'تشغيل في الخلفية'),
  // Depolama birimi adları: yalnız TANINAN birimler çevrilir. Takılabilir bir
  // diskin kendi adı (ör. "SAMSUNG") çevrilmez — o kullanıcının verisidir.
  'fm.vol_internal': ('Ana bellek', 'Internal storage', 'الذاكرة الداخلية'),
  'fm.vol_sdcard': ('SD kart', 'SD card', 'بطاقة SD'),
  'fm.vol_usb': ('USB bellek', 'USB drive', 'محرك USB'),
  'fm.external_storage': (
    'Harici Bellek',
    'External drive',
    'محرك خارجي',
  ),
  'fm.external_count': ('{n} birim', '{n} drives', '{n} محركات'),
  'fm.external_none_short': ('Takılı değil', 'Not attached', 'غير متصل'),
  'saf.title': (
    'Harici belleğe klasör izniyle eriş',
    'Access the drive with folder permission',
    'الوصول إلى المحرك بإذن المجلد',
  ),
  'saf.body': (
    'Bu cihazda Android, takılan belleği dosya yolu olarak vermiyor; bu yüzden '
    'listede görünmüyor. Android\'in klasör seçicisinden belleği (ya da içindeki '
    'bir klasörü) seçerseniz uygulama ona kalıcı olarak erişebilir: gezme, açma, '
    'kopyalama, silme ve yeniden adlandırma çalışır.\n\n'
    'Seçicide belleği göremiyorsanız Android onu hiç bağlamamış demektir; o '
    'durumda bildirim panelindeki USB bildirimini kontrol edin.',
    'On this device Android does not expose the attached drive as a file path, '
    'so it does not show up in the list. If you pick the drive (or a folder in '
    'it) from Android\'s folder picker, the app gets lasting access: browsing, '
    'opening, copying, deleting and renaming all work.\n\n'
    'If the drive is not in the picker either, Android has not mounted it — '
    'check the USB notification in the shade.',
    'على هذا الجهاز لا يوفّر أندرويد المحرك المتصل كمسار ملف، لذلك لا يظهر في '
    'القائمة. اختر المحرك (أو مجلدًا فيه) من منتقي المجلدات ليحصل التطبيق على '
    'وصول دائم.\n\nإن لم يظهر المحرك في المنتقي فلم يوصّله أندرويد.',
  ),
  'saf.pick': ('Klasör seç', 'Pick folder', 'اختر مجلدًا'),
  'saf.granted': ('Klasör izniyle', 'Via folder permission', 'بإذن المجلد'),
  // ── USB teşhis ekranı ────────────────────────────────────────────────
  // Kararlar tek cümlelik: kullanıcı ekranı okuyup NE YAPACAĞINI bilsin.
  'usb.eject_mounted_hint': (
    'Android\'in bağladığı bir belleği uygulama söküp çıkaramaz (herkese '
    'açık bir yol yok). Bildirim panelindeki USB/SD bildiriminde "Çıkar" '
    'düğmesi vardır; uygulamanın kendi sürdüğü bellekte ise gezgin '
    'ekranındaki ⋮ menüsünde "Güvenle çıkar" çalışır.',
    'The app cannot unmount a drive that Android mounted (there is no public '
    'API). Use the "Eject" button in the USB/SD notification; for a drive the '
    'app drives itself, use "Safely remove" in the browser\'s ⋮ menu.',
    'لا يمكن للتطبيق فصل محرك وصّله أندرويد. استخدم زر "إخراج" في إشعار USB.',
  ),
  'usb.eject': ('Güvenle çıkar', 'Safely remove', 'إزالة آمنة'),
  'usb.eject_done': (
    'Bellek bırakıldı — şimdi çıkarabilirsiniz.',
    'The drive was released — you can unplug it now.',
    'تم تحرير المحرك — يمكنك فصله الآن.',
  ),
  'usb.diag_title': ('USB teşhisi', 'USB diagnostics', 'تشخيص USB'),
  'usb.diag_sub': (
    'Takılı belleği hangi kanalın gördüğünü ölçer ve ne yapılacağını söyler.',
    'Measures which channel sees the attached drive and says what to do.',
    'يقيس أي قناة ترى المحرك المتصل ويخبرك بما ينبغي فعله.',
  ),
  'usb.open_raw': ('Belleği doğrudan aç', 'Open the drive directly', 'افتح المحرك مباشرة'),
  'usb.open_raw_hint': (
    'Android bağlamasa da uygulama belleği kendi sürer. FAT16/FAT32 ve exFAT '
    'belleklerde okuma da yazma da açık; NTFS salt okunur.',
    'The app drives the device itself even if Android did not mount it. '
    'FAT16/FAT32 and exFAT can be read and written; NTFS is read-only.',
    'يشغّل التطبيق الجهاز بنفسه حتى لو لم يوصّله أندرويد. القراءة والكتابة '
    'متاحتان على FAT16/FAT32 و exFAT؛ أما NTFS فللقراءة فقط.',
  ),
  'fmset.folder_sizes': (
    'Listede klasör boyutu',
    'Folder sizes in the list',
    'أحجام المجلدات في القائمة',
  ),
  'fmset.folder_sizes_sub': (
    'Görünen klasörler arka planda ölçülür; büyük ağaçlarda gecikebilir.',
    'Visible folders are measured in the background; large trees take longer.',
    'تُقاس المجلدات الظاهرة في الخلفية؛ قد تستغرق الأشجار الكبيرة وقتًا.',
  ),
  'fmset.resume': (
    'Kaldığın yerden devam',
    'Resume where you left off',
    'المتابعة من حيث توقفت',
  ),
  'fmset.resume_sub': (
    'Video/ses konumu ve belge sayfası hatırlansın.',
    'Remember playback position and document page.',
    'تذكّر موضع التشغيل وصفحة المستند.',
  ),
  'srch.recent': ('Son aramalar', 'Recent searches', 'عمليات البحث الأخيرة'),
  'srch.clear_history': ('Geçmişi temizle', 'Clear history', 'مسح السجل'),
  'vw.resumed_page': (
    '{n}. sayfadan devam ediliyor',
    'Resuming from page {n}',
    'المتابعة من الصفحة {n}',
  ),
  'vw.restart_doc': ('Baştan başla', 'Start over', 'ابدأ من جديد'),
  'pt.move_to': ('Sayfayı taşı…', 'Move page to…', 'نقل الصفحة إلى…'),
  'pt.move_to_hint': (
    'Hedef sayfa numarası (1-{n})',
    'Target page number (1-{n})',
    'رقم الصفحة الهدف (1-{n})',
  ),
  'pt.op_duplicate': ('Sayfayı çoğalt', 'Duplicate page', 'تكرار الصفحة'),
  'pt.op_insert_blank': ('Boş sayfa ekle', 'Insert blank page', 'إدراج صفحة فارغة'),
  'pt.op_reverse': ('Sırayı ters çevir', 'Reverse page order', 'عكس ترتيب الصفحات'),
  'pt.op_split': ('Bölme', 'Splitting', 'تقسيم'),
  'pt.split_every': ('Parçalara böl…', 'Split into parts…', 'تقسيم إلى أجزاء…'),
  'pt.split_size': (
    '{n} sayfalık parçalar',
    'Parts of {n} pages',
    'أجزاء من {n} صفحة',
  ),
  'pt.split_done': (
    '{n} dosya yazıldı (belgenin yanına).',
    '{n} files written next to the document.',
    'تمت كتابة {n} ملفات بجانب المستند.',
  ),
  'pt.split_too_short': (
    'Bölmek için en az iki sayfa gerekir.',
    'Splitting needs at least two pages.',
    'يتطلب التقسيم صفحتين على الأقل.',
  ),
  'pt.select_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'pt.invert_selection': ('Seçimi ters çevir', 'Invert selection', 'عكس التحديد'),
  'mp.loop_mark_a': ('A-B tekrar: A işaretle', 'A-B repeat: mark A', 'تكرار A-B: علّم A'),
  'mp.loop_mark_b': ('A-B tekrar: B işaretle', 'A-B repeat: mark B', 'تكرار A-B: علّم B'),
  'mp.loop_off': ('A-B tekrarı kaldır', 'Clear A-B repeat', 'إلغاء تكرار A-B'),
  'mp.loop_a_set': (
    'Başlangıç (A) işaretlendi',
    'Start point (A) marked',
    'تم تعليم نقطة البداية (A)',
  ),
  'mp.loop_on': (
    'A-B tekrar açık — aralık sürekli dönüyor.',
    'A-B repeat on — the range keeps looping.',
    'تكرار A-B مفعّل — يتكرر المقطع باستمرار.',
  ),
  'mp.loop_cleared': ('A-B tekrar kapatıldı', 'A-B repeat cleared', 'أُلغي تكرار A-B'),
  'mp.float_window': (
    'Ekran üstünde oynat',
    'Play in a floating window',
    'تشغيل في نافذة عائمة',
  ),
  'mp.float_permission': (
    'Video başka uygulamaların üstünde küçük bir pencerede oynayabilir. '
    'Bunun için Android\'in "Diğer uygulamaların üzerinde göster" iznini '
    'vermeniz gerekiyor; ayar ekranını şimdi açalım mı?',
    'The video can keep playing in a small window on top of other apps. '
    'Android needs the "Display over other apps" permission for that — '
    'shall we open the settings screen?',
    'يمكن تشغيل الفيديو في نافذة صغيرة فوق التطبيقات الأخرى. يتطلب ذلك إذن '
    '"العرض فوق التطبيقات الأخرى". هل نفتح الإعدادات؟',
  ),
  'mp.float_failed': (
    'Yüzen pencere açılamadı.',
    'The floating window could not be opened.',
    'تعذّر فتح النافذة العائمة.',
  ),
  'mp.zoom_fill': ('Ekranı doldur', 'Fill the screen', 'ملء الشاشة'),
  'mp.zoom_fit': ('Ekrana sığdır', 'Fit to screen', 'ملاءمة الشاشة'),
  'mp.resumed_at': (
    '{time} konumundan devam ediliyor',
    'Resuming from {time}',
    'المتابعة من {time}',
  ),
  'mp.restart': ('Baştan başlat', 'Start over', 'ابدأ من جديد'),
  'mp.sleep_timer': ('Uyku zamanlayıcısı', 'Sleep timer', 'مؤقّت النوم'),
  'mp.sleep_off': ('Kapalı', 'Off', 'مغلق'),
  'mp.sleep_minutes': ('{n} dakika', '{n} minutes', '{n} دقيقة'),
  'mp.sleep_active': (
    '{time} sonra duracak',
    'Stopping in {time}',
    'سيتوقف بعد {time}',
  ),
  'usb.multi_volume': (
    'Bu bellekte {n} bölüm var; ilki açıldı.',
    'This drive has {n} volumes; the first one was opened.',
    'يحتوي هذا المحرك على {n} أقسام؛ تم فتح الأول.',
  ),
  'usb.pick_volume': ('Bölüm seç', 'Choose a volume', 'اختر قسمًا'),
  'usb.diag_uas_only': (
    'Bu bellek yalnız UAS (USB 3) taşıması bildiriyor — uygulamanın '
    'sürücüsü Bulk-Only konuşur. Klasör izniyle (Klasör seç) erişilebilir.',
    'This drive only reports the UAS (USB 3) transport — the app driver '
    'speaks Bulk-Only. Folder permission (Pick folder) still works.',
    'يعلن هذا المحرك عن نقل UAS فقط؛ استخدم إذن المجلد.',
  ),
  'usb.diag_cbi_only': (
    'Bu bellek çok eski bir taşıma (CBI) bildiriyor — uygulamanın sürücüsü '
    'Bulk-Only konuşur.',
    'This drive reports a legacy transport (CBI) — the app driver speaks '
    'Bulk-Only.',
    'يعلن هذا المحرك عن نقل قديم (CBI).',
  ),
  'usb.write_protected': (
    'Bellek yazma korumalı (donanım anahtarı) — yalnız okunabilir.',
    'The drive is write-protected in hardware — read-only.',
    'المحرك محمي ضد الكتابة (مفتاح الجهاز) — للقراءة فقط.',
  ),
  'usb.open_raw_failed_title': (
    'Bellek açılamadı',
    'Could not open the drive',
    'تعذّر فتح المحرك',
  ),
  'usb.open_raw_failed': (
    'Bellek doğrudan açılamadı: izin verilmedi ya da biçimi tanınmadı '
    '(FAT16/FAT32/exFAT/NTFS destekleniyor).',
    'Could not open the drive directly: permission denied or unknown format '
    '(FAT16/FAT32/exFAT/NTFS are supported).',
    'تعذّر فتح المحرك مباشرة: رُفض الإذن أو تنسيق غير معروف.',
  ),
  'usb.diag_copied': ('Rapor panoya kopyalandı', 'Report copied', 'تم نسخ التقرير'),
  'usb.diag_devices': ('Takılı aygıtlar', 'Attached devices', 'الأجهزة المتصلة'),
  'usb.diag_host': ('USB ana makine (OTG)', 'USB host (OTG)', 'مضيف USB'),
  'usb.diag_no_device': ('Takılı aygıt yok', 'No device attached', 'لا يوجد جهاز'),
  'usb.diag_mass': ('yığın depolama', 'mass storage', 'تخزين'),
  'usb.diag_drivable': ('sürülebilir', 'drivable', 'قابل للتشغيل'),
  'usb.diag_permission': ('izin', 'permission', 'إذن'),
  'usb.diag_readable': ('okunabilir', 'readable', 'قابل للقراءة'),
  'usb.diag_saf': ('Klasör izinleri', 'Folder permissions', 'أذونات المجلدات'),
  'usb.diag_usable': ('Gezilebilen birimler', 'Browsable volumes', 'وحدات قابلة للتصفح'),
  'usb.verdict_usable': ('Her şey yolunda', 'All good', 'كل شيء جيد'),
  'usb.verdict_usable_hint': (
    'Harici bellek görülüyor ve geziliyor.',
    'The external drive is visible and browsable.',
    'المحرك الخارجي مرئي وقابل للتصفح.',
  ),
  'usb.verdict_mountedNoPath': (
    'Bellek bağlı, ama dosya yolu verilmiyor',
    'Drive is mounted, but no file path is exposed',
    'المحرك موصّل لكن لا يوفَّر مسار ملف',
  ),
  'usb.verdict_mountedNoPath_hint': (
    'Android belleği bağlamış; erişim için klasör izni (Klasör seç) yeterli. '
    'Ham USB sürücüsüne gerek yok.',
    'Android has mounted the drive; folder permission (Pick folder) is enough. '
    'A raw USB driver is not needed.',
    'وصّل أندرويد المحرك؛ إذن المجلد كافٍ ولا حاجة لمشغّل USB خام.',
  ),
  'usb.verdict_attachedNotMounted': (
    'Bellek takılı ama Android onu HİÇ bağlamamış',
    'Drive attached but Android never mounted it',
    'المحرك متصل لكن أندرويد لم يوصّله إطلاقًا',
  ),
  'usb.verdict_attachedNotMounted_hint': (
    'Ne yol var, ne birim, ne de klasör seçicide görünür. Bu durumda tek '
    'çözüm uygulamanın belleği doğrudan sürmesi (ham USB yığın depolama).',
    'No path, no volume, and it will not appear in the folder picker either. '
    'The only fix is driving the device directly (raw USB mass storage).',
    'لا مسار ولا وحدة ولا ظهور في المنتقي. الحل الوحيد تشغيل الجهاز مباشرة.',
  ),
};
