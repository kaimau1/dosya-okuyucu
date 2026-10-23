part of '../app_strings.dart';

/// Çeviri tablosunun 4. bölümü (çoğunlukla `fmset`, `excel` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t4 = {
  'usb.verdict_notMassStorage': (
    'Takılı aygıt bir bellek değil',
    'The attached device is not storage',
    'الجهاز المتصل ليس وحدة تخزين',
  ),
  'usb.verdict_notMassStorage_hint': (
    'Klavye, ses kartı, şarj gibi bir aygıt görünüyor.',
    'A keyboard, audio card or charger-like device is attached.',
    'يظهر جهاز مثل لوحة مفاتيح أو بطاقة صوت.',
  ),
  'usb.verdict_noDevice': (
    'Takılı bellek yok',
    'No drive attached',
    'لا يوجد محرك متصل',
  ),
  'usb.verdict_noDevice_hint': (
    'Hiçbir kanal bir aygıt görmüyor. Belleği takıp yeniden ölçün.',
    'No channel sees a device. Attach the drive and measure again.',
    'لا ترى أي قناة جهازًا. أعد التوصيل وقس مجددًا.',
  ),
  'usb.verdict_noHostSupport': (
    'Cihaz USB ana makine (OTG) desteklemiyor',
    'This device has no USB host (OTG) support',
    'لا يدعم الجهاز مضيف USB',
  ),
  'usb.verdict_noHostSupport_hint': (
    'Bu telefon USB belleği hiç okuyamaz; yazılımla çözülebilecek bir şey '
    'değil.',
    'This phone cannot read USB drives at all; software cannot fix that.',
    'لا يمكن لهذا الهاتف قراءة محركات USB إطلاقًا.',
  ),
  // Mesaj bir ÇIKIŞ YOLU söylüyor (kullanıcı 2026-09-02: bellek takılıyken
  // "Android açmadı" demek elinde yapacak bir şey bırakmıyordu). Şeridin
  // "Klasör seç" düğmesi seçiciyi doğrudan o birimin üstünde açar.
  'fm.external_unusable_short': (
    '{name} takılı ama Android dosya yolu vermiyor.',
    '{name} is attached but Android exposes no file path.',
    '{name} متصل لكن أندرويد لا يوفّر مسارًا.',
  ),
  'fm.external_unusable_title': (
    '{name} açılamıyor',
    'Cannot open {name}',
    'تعذّر فتح {name}',
  ),
  'fm.external_unusable': (
    '{name} takılı ama Android onu dosya yolu olarak vermiyor. "Klasör seç" '
    'ile belleği seçerseniz uygulama ona kalıcı olarak erişir; seçicide de '
    'yoksa bildirim panelindeki USB bildiriminden "Dosya aktarımı" seçin.',
    '{name} is attached but Android does not expose it as a file path. Tap '
    '"Pick folder" and choose the drive for lasting access; if it is not in '
    'the picker either, choose "File transfer" in the USB notification.',
    '{name} متصل لكن أندرويد لا يوفّره كمسار ملف. اضغط "اختر مجلدًا" وحدد '
    'المحرك للوصول الدائم؛ وإن لم يظهر في المنتقي فاختر "نقل الملفات" من '
    'إشعار USB.',
  ),
  'fm.external_usb_count': ('{n} USB', '{n} USB', '{n} USB'),
  'fm.external_card_count': ('{n} SD kart', '{n} SD card', '{n} بطاقة SD'),
  'fm.copy_to_external': (
    'Harici belleğe kopyala',
    'Copy to external drive',
    'نسخ إلى محرك خارجي',
  ),
  'fm.external_pick_hint': ('USB / SD kart', 'USB / SD card', 'USB / بطاقة SD'),
  'fm.external_none': (
    'Takılı harici bellek yok. USB belleği ya da SD kartı takıp yeniden '
    'deneyin.',
    'No external drive is attached. Plug in a USB drive or SD card and try '
    'again.',
    'لا يوجد محرك خارجي متصل. أدخل محرك USB أو بطاقة SD وحاول مرة أخرى.',
  ),
  'fm.copying_external': (
    '{volume} birimine kopyalanıyor…',
    'Copying to {volume}…',
    'جارٍ النسخ إلى {volume}…',
  ),
  'fm.external_copied': (
    '{n} öğe {volume} birimine kopyalandı (Dosya Okuyucu klasörü).',
    '{n} item(s) copied to {volume} (Dosya Okuyucu folder).',
    'تم نسخ {n} عنصر إلى {volume} (مجلد Dosya Okuyucu).',
  ),
  'fm.usb_attached': (
    '{volume} takıldı — açmak için dokunun.',
    '{volume} attached — tap to open.',
    'تم توصيل {volume} — اضغط للفتح.',
  ),
  'fm.usb_detached': (
    'Harici bellek çıkarıldı.',
    'External drive removed.',
    'تمت إزالة المحرك الخارجي.',
  ),
  'fm.usb_open': ('Aç', 'Open', 'فتح'),
  'fm.quick_untouched': (
    '{n} aydır açılmamış',
    'Not opened in {n} months',
    'لم يُفتح منذ {n} أشهر',
  ),
  'fm.quick_opened_within': (
    'Son {n} ayda açılanlar',
    'Opened in the last {n} months',
    'فُتح خلال آخر {n} أشهر',
  ),
  'fm.storage_analysis': ('Bellek Analizi', 'Storage analysis', 'تحليل التخزين'),
  'fm.used_percent': ('Kullanılan %{n}', '{n}% used', 'مستخدَم %{n}'),
  'fm.used': ('Kullanılan', 'Used', 'مستخدَم'),
  'apps.sort_size': ('Boyuta göre', 'By size', 'حسب الحجم'),
  'apps.storage_settings': (
    'Depolama ve önbellek',
    'Storage & cache',
    'التخزين والذاكرة المؤقتة',
  ),
  'excel.add_sheet': ('Sayfa ekle', 'Add sheet', 'إضافة ورقة'),
  'excel.cond_format': (
    'Koşullu biçimlendirme',
    'Conditional formatting',
    'تنسيق شرطي',
  ),
  'excel.cond_greater': ('Şundan büyükse', 'Greater than', 'أكبر من'),
  'excel.cond_less': ('Şundan küçükse', 'Less than', 'أصغر من'),
  'excel.cond_equal': ('Şuna eşitse', 'Equal to', 'يساوي'),
  'excel.cond_contains': ('Şunu içeriyorsa', 'Text contains', 'يحتوي على'),
  'excel.cond_value': ('Değer', 'Value', 'القيمة'),
  'excel.cond_text': ('Aranan metin', 'Text', 'النص'),
  'excel.undo_cond_format': (
    'koşullu biçimlendirme',
    'conditional formatting',
    'التنسيق الشرطي',
  ),
  'excel.fill_no_neighbour': (
    'Komşu sütun boş — nereye kadar doldurulacağı belirlenemedi',
    'Neighbouring column is empty — nothing to fill down to',
    'العمود المجاور فارغ — لا يمكن تحديد نطاق التعبئة',
  ),
  'excel.filter_column': (
    '{col} sütununu süz',
    'Filter column {col}',
    'تصفية العمود {col}',
  ),
  'excel.sort_asc': ('A → Z sırala', 'Sort A → Z', 'ترتيب أ → ي'),
  'excel.sort_desc': ('Z → A sırala', 'Sort Z → A', 'ترتيب ي → أ'),
  // Şerit sekmeleri (Excel'in kendi adları).
  'excel.tab_home': ('Giriş', 'Home', 'الصفحة الرئيسية'),
  'excel.tab_insert': ('Ekle', 'Insert', 'إدراج'),
  'excel.tab_data': ('Veri', 'Data', 'بيانات'),
  'excel.tab_view': ('Görünüm', 'View', 'عرض'),
  'excel.filter': ('Süz', 'Filter', 'تصفية'),
  'excel.zoom_in': ('Yakınlaştır', 'Zoom in', 'تكبير'),
  'excel.zoom_out': ('Uzaklaştır', 'Zoom out', 'تصغير'),
  'excel.zoom_reset': ('Yakınlaştırmayı sıfırla (%100)', 'Reset zoom (100%)',
      'إعادة ضبط التكبير (100%)'),
  'excel.ribbon_hide': ('Şeridi gizle', 'Hide ribbon', 'إخفاء الشريط'),
  'excel.ribbon_show': ('Şeridi göster', 'Show ribbon', 'إظهار الشريط'),
  'excel.font_default': ('Yazı tipi', 'Font', 'الخط'),
  'excel.undo_font': ('yazı tipi', 'font', 'الخط'),
  'excel.sort_needs_range': (
    'Sıralamak için önce satırları seçin (basılı tutup kaydırın) ya da tabloya süzgeç ekleyin.',
    'To sort, first select the rows (press and drag) or add a filter to the table.',
    'للترتيب، حدد الصفوف أولاً (اضغط واسحب) أو أضف تصفية إلى الجدول.',
  ),
  'excel.filter_needs_table': (
    'Bu sütunda süzgeç yok. Süzgeç, dosyada tanımlı tablo aralığında çalışır.',
    'No filter on this column. Filtering works on the table range defined in the file.',
    'لا توجد تصفية على هذا العمود. تعمل التصفية على نطاق الجدول المحدد في الملف.',
  ),
  'excel.saved_as_xlsx': (
    '{name} olarak kaydedildi (eski .xls dosyanız olduğu gibi duruyor)',
    'Saved as {name} (your original .xls file is untouched)',
    'تم الحفظ باسم {name} (ملف .xls الأصلي كما هو)',
  ),
  'excel.filter_all': ('Tümünü seç', 'Select all', 'تحديد الكل'),
  'excel.filter_blank': ('(Boş)', '(Blank)', '(فارغ)'),
  'excel.filter_clear': ('Süzgeci kaldır', 'Clear filter', 'مسح التصفية'),
  'excel.undo_filter': ('süzme', 'filter', 'التصفية'),
  'excel.undo_sort': ('sıralama', 'sort', 'الترتيب'),
  'excel.rename_sheet': ('Sayfayı yeniden adlandır', 'Rename sheet', 'إعادة تسمية الورقة'),
  'excel.delete_sheet': ('Sayfayı sil', 'Delete sheet', 'حذف الورقة'),
  'excel.delete_sheet_confirm': (
    '“{name}” sayfası ve içindeki her şey silinsin mi?',
    'Delete sheet “{name}” and everything in it?',
    'حذف الورقة «{name}» وكل ما فيها؟',
  ),
  'excel.sheet_name': ('Sayfa{n}', 'Sheet{n}', 'ورقة{n}'),
  'excel.sheet_name_label': ('Sayfa adı', 'Sheet name', 'اسم الورقة'),
  'excel.sheet_name_taken': (
    'Bu ad zaten kullanılıyor',
    'That name is already used',
    'هذا الاسم مستخدم بالفعل',
  ),
  'excel.last_sheet': (
    'Son sayfa silinemez',
    'The last sheet cannot be deleted',
    'لا يمكن حذف الورقة الأخيرة',
  ),
  'excel.fill_color': ('Dolgu rengi', 'Fill color', 'لون التعبئة'),
  'excel.font_color': ('Yazı rengi', 'Font color', 'لون الخط'),
  'excel.color_none': ('Renk yok', 'No color', 'بلا لون'),
  'excel.borders': ('Kenarlıklar', 'Borders', 'الحدود'),
  'excel.border_all': ('Tüm kenarlıklar', 'All borders', 'كل الحدود'),
  'excel.border_outline': ('Dış kenarlık', 'Outline', 'حد خارجي'),
  'excel.border_top': ('Üst kenarlık', 'Top border', 'حد علوي'),
  'excel.border_bottom': ('Alt kenarlık', 'Bottom border', 'حد سفلي'),
  'excel.border_none': ('Kenarlığı kaldır', 'No border', 'إزالة الحدود'),
  'excel.wrap_text': ('Metni kaydır', 'Wrap text', 'التفاف النص'),
  'excel.merge': ('Hücreleri birleştir', 'Merge cells', 'دمج الخلايا'),
  'excel.unmerge': ('Birleştirmeyi çöz', 'Unmerge cells', 'إلغاء دمج الخلايا'),
  'excel.merge_needs_range': (
    'Birleştirmek için en az iki hücre seçin',
    'Select at least two cells to merge',
    'حدد خليتين على الأقل للدمج',
  ),
  'excel.undo_fill_color': ('dolgu rengi', 'fill color', 'لون التعبئة'),
  'excel.undo_font_color': ('yazı rengi', 'font color', 'لون الخط'),
  'excel.undo_border': ('kenarlık', 'border', 'الحدود'),
  'excel.undo_wrap': ('metin kaydırma', 'text wrap', 'التفاف النص'),
  'excel.undo_merge': ('hücre birleştirme', 'merge cells', 'دمج الخلايا'),
  'excel.undo_unmerge': (
    'birleştirmeyi çözme',
    'unmerge cells',
    'إلغاء دمج الخلايا',
  ),
  'excel.replaced_count': (
    '{n} hücre değiştirildi',
    '{n} cells replaced',
    'تم استبدال {n} خلية',
  ),

  // ── Dosya yöneticisi ayarları ─────────────────────────────────────────────
  'fmset.title': (
    'Dosya yöneticisi ayarları',
    'File manager settings',
    'إعدادات مدير الملفات',
  ),
  'fmset.sec_view': ('Görünüm', 'Appearance', 'المظهر'),
  'fmset.sec_open': ('Açma', 'Opening', 'الفتح'),
  'fmset.start_folder': (
    'Açılış klasörü',
    'Start folder',
    'مجلد البداية',
  ),
  'fmset.start_folder_none': (
    'Uygulama panoyla açılır',
    'The app opens on the dashboard',
    'يفتح التطبيق على اللوحة',
  ),
  'fmset.start_folder_pick': (
    'Açılışta burayı aç',
    'Open this at startup',
    'افتح هذا عند البدء',
  ),
  'fmset.start_folder_clear': (
    'Açılış klasörünü kaldır',
    'Clear the start folder',
    'إزالة مجلد البداية',
  ),
  'fmset.sec_search': ('Arama', 'Search', 'البحث'),
  'fmset.sec_privacy': ('Gizlilik', 'Privacy', 'الخصوصية'),
  'fmset.sec_delete': ('Silme', 'Deleting', 'الحذف'),
  'fmset.sec_permissions': ('İzinler', 'Permissions', 'الأذونات'),
  'fmset.sec_maintenance': ('Bakım', 'Maintenance', 'الصيانة'),
  'fmset.sec_app': ('Uygulama', 'App', 'التطبيق'),
  'fmset.list_layout': (
    'Dosya listesi görünümü',
    'File list layout',
    'تخطيط قائمة الملفات',
  ),
  'fmset.photo_grid': ('Fotoğraflar ızgarası', 'Photo grid', 'شبكة الصور'),
  'fmset.grid_density': ('Izgara yoğunluğu', 'Grid density', 'كثافة الشبكة'),
  'fmset.grouping': ('gruplama', 'grouping', 'التجميع'),
  'fmset.show_hidden': (
    'Gizli dosyaları göster',
    'Show hidden files',
    'إظهار الملفات المخفية',
  ),
  'fmset.show_hidden_sub': (
    'Adı nokta ile başlayanlar (.thumbnails gibi)',
    'Names starting with a dot (such as .thumbnails)',
    'الأسماء التي تبدأ بنقطة (مثل ‎.thumbnails)',
  ),
  'fmset.thumbnails': ('Küçük resimler', 'Thumbnails', 'الصور المصغّرة'),
  'fmset.thumbnails_sub': (
    'Görsel ve video önizlemeleri (yavaş cihazda kapatın)',
    'Image and video previews (turn off on slow devices)',
    'معاينات الصور والفيديو (أوقفها على الأجهزة البطيئة)',
  ),
  'fmset.default_sort': ('Varsayılan sıralama', 'Default sorting', 'الترتيب الافتراضي'),
  'fmset.desc': ('azalan', 'descending', 'تنازلي'),
  'fmset.asc': ('artan', 'ascending', 'تصاعدي'),
  'fmset.reverse_dir': ('Yönü ters çevir', 'Reverse direction', 'عكس الاتجاه'),
  'fmset.group_photos': ('Fotoğrafları grupla', 'Group photos', 'تجميع الصور'),
  'fmset.group_photos_sub': (
    '{unit} göre ayrılır',
    'Grouped by {unit}',
    'مجمَّعة حسب {unit}',
  ),
  'fmset.media_open_with': (
    'Video, ses ve görselleri neyle aç',
    'Open videos, audio and images with',
    'فتح الفيديو والصوت والصور بواسطة',
  ),
  'fmset.index': ('Arama dizini', 'Search index', 'فهرس البحث'),
  'fmset.index_building': ('Kuruluyor…', 'Building…', 'جارٍ الإنشاء…'),
  'fmset.index_none': (
    'Henüz kurulmadı — ilk aramada ya da tarama sonrası kurulur',
    'Not built yet — it is built on the first search or after a scan',
    'لم يُنشأ بعد — يُنشأ عند أول بحث أو بعد الفحص',
  ),
  'fmset.index_stale': (
    ' · dosyalar değişti, tazelenmeli',
    ' · files changed, needs refreshing',
    ' · تغيّرت الملفات، يحتاج تحديثًا',
  ),
  'fmset.index_ready': (
    '{n} kayıt · {date}{stale}',
    '{n} records · {date}{stale}',
    '{n} سجل · {date}{stale}',
  ),
  'fmset.index_failed': (
    'Dizin kurulamadı (depolama izni verilmemiş olabilir).',
    'Could not build the index (storage permission may be missing).',
    'تعذّر إنشاء الفهرس (قد يكون إذن التخزين مفقودًا).',
  ),
  'fmset.index_built': (
    'Arama dizini kuruldu · {n} kayıt.',
    'Search index built · {n} records.',
    'تم إنشاء فهرس البحث · {n} سجل.',
  ),
  'fmset.pin_change': (
    'Klasör kilidi PIN’i değiştir',
    'Change the folder lock PIN',
    'تغيير رمز قفل المجلد',
  ),
  'fmset.pin_set': (
    'Klasör kilidi PIN’i belirle',
    'Set a folder lock PIN',
    'تعيين رمز قفل المجلد',
  ),
  'fmset.pin_sub_locked': (
    '{n} klasör kilitli · kilitlemek için klasörde ⋮ > “Klasörü kilitle”',
    '{n} folders locked · to lock one, use ⋮ > “Lock folder” in the folder',
    '{n} مجلد مقفل · للقفل استخدم ⋮ > «قفل المجلد» داخل المجلد',
  ),
  'fmset.pin_sub_unset': (
    'Kilitli klasörler listelerde ve galeride görünmez. '
        'Dosyalar ŞİFRELENMEZ — yalnız bu uygulamada gizlenir.',
    'Locked folders are hidden from lists and the gallery. Files are NOT '
        'encrypted — they are only hidden inside this app.',
    'المجلدات المقفلة مخفية من القوائم والمعرض. الملفات غير مشفّرة — إنما '
        'تُخفى داخل هذا التطبيق فقط.',
  ),
  'fmset.pin_remove': (
    'Kilidi tamamen kaldır',
    'Remove the lock completely',
    'إزالة القفل تمامًا',
  ),
  'fmset.pin_remove_sub': (
    'PIN silinir ve tüm klasörlerin kilidi açılır.',
    'The PIN is deleted and all folders are unlocked.',
    'يُحذف الرمز وتُفتح جميع المجلدات.',
  ),
  'fmset.unlock': ('Kilidi kaldır', 'Unlock', 'إلغاء القفل'),
  'fmset.use_trash': ('Çöp kutusunu kullan', 'Use the trash', 'استخدام سلة المهملات'),
  'fmset.use_trash_sub': (
    'Kapalıysa dosyalar doğrudan kalıcı silinir (geri alınamaz)',
    'When off, files are deleted permanently right away (cannot be undone)',
    'عند الإيقاف تُحذف الملفات نهائيًا مباشرةً (لا يمكن التراجع)',
  ),
  'fmset.confirm_delete': (
    'Silmeden önce sor',
    'Ask before deleting',
    'اسأل قبل الحذف',
  ),
  'fmset.trash_auto': (
    'Çöp kutusunu otomatik temizle',
    'Empty the trash automatically',
    'تفريغ سلة المهملات تلقائيًا',
  ),
  'fmset.trash_auto_off': (
    'Kapalı — çöp elle boşaltılır',
    'Off — the trash is emptied by hand',
    'مُعطّل — تُفرَّغ السلة يدويًا',
  ),
  'fmset.trash_auto_on': (
    '{n} günden eski öğeler silinir',
    'Items older than {n} days are deleted',
    'تُحذف العناصر الأقدم من {n} يومًا',
  ),
  'fmset.off': ('Kapalı', 'Off', 'مُعطّل'),
  'fmset.days': ('{n} gün', '{n} days', '{n} يومًا'),
  'fmset.empty_trash_now': (
    'Çöp kutusunu şimdi boşalt',
    'Empty the trash now',
    'تفريغ سلة المهملات الآن',
  ),
  'fmset.trash_empty': ('Çöp kutusu boş', 'The trash is empty', 'سلة المهملات فارغة'),
  'fmset.trash_summary': (
    '{n} öğe · {size}',
    '{n} items · {size}',
    '{n} عنصر · {size}',
  ),
  'fmset.empty_confirm_title': (
    'Çöp kutusu boşaltılsın mı?',
    'Empty the trash?',
    'هل تريد تفريغ سلة المهملات؟',
  ),
  'fmset.empty_confirm_body': (
    '{n} öğe ({size}) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    '{n} items ({size}) will be deleted permanently. This cannot be undone.',
    'سيتم حذف {n} عنصر ({size}) نهائيًا. لا يمكن التراجع عن ذلك.',
  ),
  'fmset.empty': ('Boşalt', 'Empty', 'تفريغ'),
  'fmset.emptying': (
    'Çöp kutusu boşaltılıyor',
    'Emptying the trash',
    'جارٍ تفريغ سلة المهملات',
  ),
  'fmset.empty_partial': (
    '{ok} öğe silindi, {fail} öğe silinemedi.',
    '{ok} items deleted, {fail} could not be deleted.',
    'تم حذف {ok} عنصر، وتعذّر حذف {fail}.',
  ),
  'fmset.empty_cancelled': (
    'Durduruldu — {ok} öğe silindi.',
    'Stopped — {ok} items deleted.',
    'تم الإيقاف — حُذف {ok} عنصر.',
  ),
  'fmset.empty_done': (
    'Çöp kutusu boşaltıldı · {ok} öğe · {size} yer açıldı.',
    'Trash emptied · {ok} items · {size} freed.',
    'تم تفريغ سلة المهملات · {ok} عنصر · تم تحرير {size}.',
  ),
  'fmset.full_access': (
    'Tüm dosyalara erişim',
    'All-files access',
    'الوصول إلى كل الملفات',
  ),
  'fmset.full_access_on': (
    'Verildi — tüm klasörler görünüyor',
    'Granted — all folders are visible',
    'مُمنوح — تظهر جميع المجلدات',
  ),
  'fmset.full_access_off': (
    'Verilmedi — yalnız medya klasörleri görünür',
    'Not granted — only media folders are visible',
    'غير ممنوح — تظهر مجلدات الوسائط فقط',
  ),
  'fmset.usage_access': ('Kullanım erişimi', 'Usage access', 'الوصول إلى الاستخدام'),
  'fmset.usage_access_on': (
    'Verildi — uygulamaların son açılma tarihi görünüyor',
    'Granted — apps’ last-opened dates are visible',
    'مُمنوح — يظهر تاريخ آخر فتح للتطبيقات',
  ),
  'fmset.usage_access_off': (
    'Verilmedi — “Uygulamalar” ekranında tarih gösterilemez',
    'Not granted — dates cannot be shown on the “Apps” screen',
    'غير ممنوح — لا يمكن عرض التواريخ في شاشة «التطبيقات»',
  ),
  'fmset.grant': ('İzin ver', 'Grant', 'منح الإذن'),
  'fmset.clear_thumbs': (
    'Küçük resim önbelleğini temizle',
    'Clear the thumbnail cache',
    'مسح ذاكرة الصور المصغّرة',
  ),
  // ── Uygulamanın kapladığı alan (2026-09-26) ─────────────────────────────
  'foot.section': ('Uygulamanın alanı', 'App storage', 'مساحة التطبيق'),
  'foot.title': (
    'Uygulamanın kapladığı alan',
    'Storage used by the app',
    'المساحة التي يشغلها التطبيق',
  ),
  'foot.tile_sub': (
    'Neyin ne kadar yer tuttuğunu gör; önbelleği ve kopyaları temizle',
    'See what takes how much space; clear the cache and copies',
    'اعرف ما يشغل المساحة؛ امسح ذاكرة التخزين المؤقت والنسخ',
  ),
  'foot.kw_cache': ('önbellek boyut yer', 'cache size space', 'ذاكرة مؤقتة حجم مساحة'),
  'foot.total_sub': (
    'Uygulamanın kendi klasörlerinde (veri + önbellek). Uygulamanın kendisi (APK) bunun dışında.',
    'In the app’s own folders (data + cache). The app itself (APK) is not included.',
    'في مجلدات التطبيق نفسه (بيانات + ذاكرة مؤقتة). التطبيق نفسه (APK) غير مشمول.',
  ),
  'foot.system': (
    'Android’e göre: uygulama {app} · veri {data}',
    'According to Android: app {app} · data {data}',
    'حسب أندرويد: التطبيق {app} · البيانات {data}',
  ),
  'foot.empty': ('Ölçülecek bir şey yok.', 'Nothing to measure.', 'لا شيء لقياسه.'),
  'foot.shared': ('Paylaşım kopyaları', 'Share copies', 'نسخ المشاركة'),
  'foot.shared_sub': (
    '“Birlikte aç” ile gelen ve paylaşım için hazırlanan dosyaların kopyası; 7 günde kendiliğinden silinir',
    'Copies of files opened with “Open with” or prepared for sharing; removed automatically after 7 days',
    'نسخ الملفات المفتوحة عبر «فتح باستخدام» أو المُعدّة للمشاركة؛ تُحذف تلقائيًا بعد 7 أيام',
  ),
  'foot.picker': ('Dosya seçici kopyaları', 'File picker copies', 'نسخ منتقي الملفات'),
  'foot.picker_sub': (
    'Seçici ile seçilen dosyaların kopyası; 7 günde kendiliğinden silinir',
    'Copies of files chosen with the picker; removed automatically after 7 days',
    'نسخ الملفات المختارة بالمنتقي؛ تُحذف تلقائيًا بعد 7 أيام',
  ),
  'foot.thumbs': ('Küçük resimler', 'Thumbnails', 'الصور المصغّرة'),
  'foot.thumbs_sub': (
    'Video, PDF ve APK önizlemeleri — gerektikçe yeniden üretilir',
    'Video, PDF and APK previews — regenerated when needed',
    'معاينات الفيديو وPDF وAPK — يُعاد إنشاؤها عند الحاجة',
  ),
  'foot.temp': ('Geçici dosyalar', 'Temporary files', 'الملفات المؤقتة'),
  'foot.temp_sub': (
    'Tarama ara kareleri, arşiv önizlemeleri, WebView önbelleği',
    'Scan intermediates, archive previews, WebView cache',
    'ملفات المسح الوسيطة ومعاينات الأرشيف وذاكرة WebView المؤقتة',
  ),
  'foot.drive': ('Google Drive önbelleği', 'Google Drive cache', 'ذاكرة Google Drive المؤقتة'),
  'foot.drive_sub': (
    'Drive’dan açılan dosyaların yerel kopyası — yeniden açınca tekrar iner',
    'Local copies of files opened from Drive — downloaded again when reopened',
    'نسخ محلية لملفات فُتحت من Drive — تُنزَّل مجددًا عند فتحها',
  ),
  'foot.models': ('Çeviri dil modelleri', 'Translation language models', 'نماذج لغات الترجمة'),
  'foot.models_sub': (
    'Cihaz içi çeviri için indirilen modeller (dil başına ~30 MB)',
    'Models downloaded for on-device translation (~30 MB per language)',
    'نماذج نُزّلت للترجمة على الجهاز (~30 ميغابايت لكل لغة)',
  ),
  'foot.docs': ('Uygulama içindeki belgeler', 'Documents inside the app', 'مستندات داخل التطبيق'),
  'foot.docs_sub': (
    'Eski taramalar ve yeni belgeler — SİZİN dosyalarınız, temizlenmez. Uygulama kaldırılınca silinirler; dokunup Belgeler klasörüne taşıyın',
    'Older scans and new documents — YOUR files, never cleared. They are deleted if the app is uninstalled; tap and move them to Documents',
    'مسوحات قديمة ومستندات جديدة — ملفاتك، لا تُمسح. تُحذف عند إلغاء تثبيت التطبيق؛ اضغط وانقلها إلى المستندات',
  ),
  'foot.other': ('Ayarlar ve dizinler', 'Settings and indexes', 'الإعدادات والفهارس'),
  'foot.other_sub': (
    'Arama dizini, geçmiş, ayarlar, WebView verisi',
    'Search index, history, settings, WebView data',
    'فهرس البحث والسجل والإعدادات وبيانات WebView',
  ),
  'foot.clean': ('Önbelleği temizle ({size})', 'Clear cache ({size})', 'مسح الذاكرة المؤقتة ({size})'),
  'foot.clean_note': (
    'Kopyalar, küçük resimler, geçici dosyalar ve Drive önbelleği silinir. Belgelerinize dokunulmaz; son 10 dakikada açılanlar atlanır.',
    'Copies, thumbnails, temporary files and the Drive cache are deleted. Your documents are untouched; items opened in the last 10 minutes are skipped.',
    'تُحذف النسخ والصور المصغّرة والملفات المؤقتة وذاكرة Drive. لا تُمسّ مستنداتك؛ ويُتخطّى ما فُتح في آخر 10 دقائق.',
  ),
  'foot.freed': ('{size} boşaltıldı.', '{size} freed.', 'تم تحرير {size}.'),
  'foot.nothing_freed': (
    'Boşaltılacak bir şey kalmadı.',
    'Nothing left to free.',
    'لم يتبقَّ شيء لتحريره.',
  ),
  'foot.delete_models': ('Dil modellerini sil', 'Delete language models', 'حذف نماذج اللغات'),
  'foot.models_deleted': (
    '{n} dil modeli silindi; gerektiğinde yeniden iner.',
    '{n} language models deleted; they download again when needed.',
    'تم حذف {n} من نماذج اللغات؛ تُنزَّل مجددًا عند الحاجة.',
  ),
  'foot.apk_note': (
    'Uygulamanın kendisi (~95 MB) çoğunlukla cihaz içinde çalışan motorlardan oluşur: metin tanıma (OCR), çeviri, video, PDF. Bunlar internet gerektirmeden çalışsın diye pakette gelir.',
    'The app itself (~95 MB) is mostly on-device engines: text recognition (OCR), translation, video, PDF. They ship in the package so they work without internet.',
    'التطبيق نفسه (~95 ميغابايت) معظمه محركات تعمل على الجهاز: التعرّف على النص (OCR) والترجمة والفيديو وPDF. تأتي ضمن الحزمة لتعمل دون إنترنت.',
  ),
  'foot.system_settings': (
    'Android uygulama ayarlarını aç',
    'Open Android app settings',
    'فتح إعدادات التطبيق في أندرويد',
  ),
  'ocr.model_downloading': (
    'Metin tanıma modeli Google Play Hizmetleri tarafından indiriliyor. İnternete bağlı olun ve birkaç dakika sonra yeniden deneyin.',
    'The text recognition model is being downloaded by Google Play services. Stay online and try again in a few minutes.',
    'تقوم خدمات Google Play بتنزيل نموذج التعرّف على النص. ابقَ متصلًا بالإنترنت وأعد المحاولة بعد بضع دقائق.',
  ),
  'fmset.volumes': ('Birimler', 'Volumes', 'وحدات التخزين'),
  'fmset.volumes_none': ('Bulunamadı', 'None found', 'لم يُعثر على شيء'),
  'fmset.general': ('Genel ayarlar', 'General settings', 'الإعدادات العامة'),
  'fmset.general_sub': (
    'Gemini anahtarı, tema, hesap',
    'Gemini key, theme, account',
    'مفتاح Gemini، السمة، الحساب',
  ),

  // ── İndirmeler ────────────────────────────────────────────────────────────
  'dl.title': ('İndirmeler', 'Downloads', 'التنزيلات'),
  'dl.clipboard_download': (
    'Panodaki bağlantıyı indir',
    'Download the link in the clipboard',
    'تنزيل الرابط الموجود في الحافظة',
  ),
  'dl.how_to': (
    'Tarayıcıdan nasıl indiririm?',
    'How do I download from the browser?',
    'كيف أُنزّل من المتصفح؟',
  ),
  'dl.clear_finished': (
    'Biten kayıtları temizle',
    'Clear finished entries',
    'مسح السجلات المنتهية',
  ),
  'dl.link': ('Bağlantı', 'Link', 'رابط'),
  'dl.clipboard_link': ('Panodaki bağlantı', 'Link in the clipboard', 'الرابط في الحافظة'),
  'dl.download': ('İndir', 'Download', 'تنزيل'),
  'dl.no_link': (
    'Panoda bir bağlantı yok. Tarayıcıda bağlantıyı kopyalayıp buraya dönün.',
    'There is no link in the clipboard. Copy a link in the browser and come back.',
    'لا يوجد رابط في الحافظة. انسخ الرابط في المتصفح ثم عُد إلى هنا.',
  ),
  'dl.from_link': ('Bağlantıdan indir', 'Download from a link', 'التنزيل من رابط'),
  'dl.link_label': ('Bağlantı (https://…)', 'Link (https://…)', 'الرابط (‎https://…)'),
  'dl.continue': ('Devam', 'Continue', 'متابعة'),
  'dl.empty': ('Henüz indirme yok', 'No downloads yet', 'لا توجد تنزيلات بعد'),
  'dl.remaining': ('{time} kaldı', '{time} left', 'بقي {time}'),
  'dl.link_copied': (
    'Bağlantı panoya kopyalandı.',
    'Link copied to the clipboard.',
    'تم نسخ الرابط إلى الحافظة.',
  ),
  'dl.pause': ('Duraklat', 'Pause', 'إيقاف مؤقت'),
  'dl.resume': ('Devam et', 'Resume', 'استئناف'),
  'dl.cancel_task': ('İptal et', 'Cancel', 'إلغاء'),
  'dl.open_folder': ('Klasörünü aç', 'Open its folder', 'فتح مجلده'),
  'dl.copy_link': ('Bağlantıyı kopyala', 'Copy link', 'نسخ الرابط'),
  'dl.remove': ('Listeden kaldır', 'Remove from list', 'إزالة من القائمة'),
  'dl.download_here': ('Buraya indir', 'Download here', 'نزّل هنا'),
  'dl.started': (
    'İndirme başladı: {name}',
    'Download started: {name}',
    'بدأ التنزيل: {name}',
  ),
  'dl.fetching_release': (
    'Sürüm dosyaları alınıyor…',
    'Fetching release files…',
    'جارٍ جلب ملفات الإصدار…',
  ),
  'dl.asset_count': ('{n} dosya · {tag}', '{n} files · {tag}', '{n} ملف · {tag}'),
  'dl.size_unknown': ('Boyut bilinmiyor', 'Size unknown', 'الحجم غير معروف'),
  'dl.step1_title': ('1) Paylaş (en kolayı)', '1) Share (easiest)', '1) المشاركة (الأسهل)'),
  'dl.step1_body': (
    'Bağlantıya uzun basın → “Bağlantıyı paylaş” → Dosya Okuyucu. '
        'Sayfadaki paylaş düğmesi de olur.',
    'Long-press the link → “Share link” → Dosya Okuyucu. The page’s own share '
        'button works too.',
    'اضغط مطوّلًا على الرابط ← «مشاركة الرابط» ← Dosya Okuyucu. زر المشاركة في '
        'الصفحة يعمل أيضًا.',
  ),
  'dl.step2_title': ('2) Kopyala-yapıştır', '2) Copy and paste', '2) نسخ ولصق'),
  'dl.step2_body': (
    'Bağlantıya uzun basın → “Bağlantı adresini kopyala”, sonra bu ekranı '
        'açın: bağlantı üstte çıkar, “İndir”e dokunun.',
    'Long-press the link → “Copy link address”, then open this screen: the '
        'link appears at the top, tap “Download”.',
    'اضغط مطوّلًا على الرابط ← «نسخ عنوان الرابط»، ثم افتح هذه الشاشة: يظهر '
        'الرابط في الأعلى، اضغط «تنزيل».',
  ),
  'dl.step3_title': (
    '3) Bağlantıya dokununca çıkmamız için',
    '3) To make us appear when you tap a link',
    '3) لكي نظهر عند الضغط على رابط',
  ),
  'dl.step3_body': (
    'Android 12’den beri bir uygulama, sahibi olmadığı bir sitenin '
        'bağlantılarını izinsiz açamıyor. Elle izin verebilirsiniz: aşağıdaki '
        'düğmeyle uygulama bilgisi ekranını açın, sonra:\n'
        '• Saf Android / Pixel: “Varsayılan olarak aç” → '
        '“Desteklenen bağlantıları aç”\n'
        '• Samsung: “Varsayılan olarak ayarla” → “Desteklenen web adresleri”\n'
        '• Xiaomi / Redmi: “Varsayılan olarak aç” → “Desteklenen bağlantılar”\n'
        'Açılan listede github.com gibi adresleri işaretleyin.',
    'Since Android 12, an app cannot open links for a site it does not own '
        'without permission. You can grant it by hand: use the button below to '
        'open the app info screen, then:\n'
        '• Stock Android / Pixel: “Open by default” → “Open supported links”\n'
        '• Samsung: “Set as default” → “Supported web addresses”\n'
        '• Xiaomi / Redmi: “Open by default” → “Supported links”\n'
        'Tick addresses such as github.com in the list that appears.',
    'منذ Android 12 لا يمكن لتطبيق أن يفتح روابط موقع لا يملكه دون إذن. يمكنك '
        'منح الإذن يدويًا: افتح شاشة معلومات التطبيق بالزر أدناه، ثم:\n'
        '• Android الأصلي / Pixel: «الفتح افتراضيًا» ← «فتح الروابط المدعومة»\n'
        '• Samsung: «التعيين كافتراضي» ← «عناوين الويب المدعومة»\n'
        '• Xiaomi / Redmi: «الفتح افتراضيًا» ← «الروابط المدعومة»\n'
        'علّم العناوين مثل github.com في القائمة التي تظهر.',
  ),
  'dl.how_to_note': (
    'Bu menü yalnız Android 12 ve üstünde var. Bulamıyorsanız 1. yolu '
        'kullanın — hiçbir ayar gerektirmiyor ve her cihazda çalışıyor.',
    'This menu only exists on Android 12 and above. If you cannot find it, use '
        'method 1 — it needs no settings and works on every device.',
    'هذه القائمة موجودة فقط في Android 12 وما فوق. إن لم تجدها فاستخدم الطريقة '
        'الأولى — لا تحتاج أي إعداد وتعمل على كل جهاز.',
  ),
  'dl.open_app_info': (
    'Uygulama bilgisini aç',
    'Open app info',
    'فتح معلومات التطبيق',
  ),

  // ── PDF düzenleyici ───────────────────────────────────────────────────────
  'pe.prepare_failed': (
    'Belge hazırlanamadı: {error}',
    'Could not prepare the document: {error}',
    'تعذّر تحضير المستند: {error}',
  ),
  'pe.outline_failed': (
    'Sayfa çözümlenemedi: {error}',
    'Could not analyse the page: {error}',
    'تعذّر تحليل الصفحة: {error}',
  ),
  'pe.background_failed': (
    'Arka plan öğeleri taranamadı: {error}',
    'Could not scan background items: {error}',
    'تعذّر فحص عناصر الخلفية: {error}',
  ),
  'pe.undone': ('Geri alındı', 'Undone', 'تم التراجع'),
  'pe.paragraph_updated': ('Paragraf güncellendi', 'Paragraph updated', 'تم تحديث الفقرة'),
  'pe.delete_image': ('Görseli sil', 'Delete image', 'حذف الصورة'),
  'pe.delete_image_body': (
    'Bu görsel sayfadan kaldırılacak. Geri al ile döndürebilirsiniz.',
    'This image will be removed from the page. You can bring it back with Undo.',
    'ستُزال هذه الصورة من الصفحة. يمكنك إرجاعها عبر التراجع.',
  ),
  'pe.image_deleted': ('Görsel silindi', 'Image deleted', 'تم حذف الصورة'),
  'pe.image_moved': ('Görsel taşındı', 'Image moved', 'تم نقل الصورة'),
  'pe.image_turned': ('Görsel döndürüldü', 'Image rotated', 'تم تدوير الصورة'),
  'pe.image_mirrored': (
    'Görsel aynalandı',
    'Image mirrored',
    'تم عكس الصورة'
  ),
  'pe.mirror_h': (
    'Yatay ayna (sağ-sol)',
    'Mirror horizontally',
    'عكس أفقي'
  ),
  'pe.mirror_v': ('Dikey ayna (alt-üst)', 'Mirror vertically', 'عكس رأسي'),
  'pe.pick_to_remove': (
    'Kaldırılacak öğe seçin',
    'Select the items to remove',
    'اختر العناصر المراد إزالتها',
  ),
  'pe.items_removed': (
    'Seçilen öğeler kaldırıldı',
    'Selected items removed',
    'تمت إزالة العناصر المحددة',
  ),
  'pe.page_rotated': ('Sayfa döndürüldü', 'Page rotated', 'تم تدوير الصفحة'),
  'pe.op_failed': (
    'İşlem yapılamadı: {error}',
    'The operation failed: {error}',
    'فشلت العملية: {error}',
  ),
  'pe.protected_title': ('Belge korumalı', 'The document is protected', 'المستند محمي'),
  'pe.protected_body': (
    'Bu belge düzenlemeye karşı kilitli ama parola sormadan açılıyor '
        '(izin kilidi). Korumayı kaldırıp düzenleyelim mi?\n\n'
        'Özgün dosyanız değişmez; koruma yalnız düzenlenen kopyada kalkar.',
    'This document is locked against editing but opens without asking for a '
        'password (a permissions lock). Shall we remove the protection and '
        'edit it?\n\nYour original file is untouched; the protection is only '
        'removed on the edited copy.',
    'هذا المستند مقفل ضد التحرير لكنه يُفتح دون طلب كلمة مرور (قفل أذونات). '
        'هل نزيل الحماية ونحرّره؟\n\nملفك الأصلي لا يتغيّر؛ تُزال الحماية من '
        'النسخة المحرَّرة فقط.',
  ),
  'pe.remove_protection': ('Korumayı kaldır', 'Remove protection', 'إزالة الحماية'),
  'pe.protection_removed': ('Koruma kaldırıldı', 'Protection removed', 'تمت إزالة الحماية'),
  'pe.unlock_failed': (
    'Belgenin şifre koruması kaldırılamadı: {error}\n\n'
        'Gerçek bir parola varsa PDF araçlarından kaldırıp yeniden deneyin.',
    'Could not remove the document’s password protection: {error}\n\n'
        'If there is a real password, remove it from PDF tools and try again.',
    'تعذّرت إزالة حماية كلمة المرور من المستند: {error}\n\n'
        'إن كانت هناك كلمة مرور حقيقية فأزلها من أدوات PDF ثم أعد المحاولة.',
  ),
  'pe.save_note': (
    'Düzenlenmiş belgeyi nereye kaydedelim?',
    'Where should we save the edited document?',
    'أين نحفظ المستند المحرَّر؟',
  ),
  'pe.unsaved_title': (
    'Kaydedilmemiş değişiklikler',
    'Unsaved changes',
    'تغييرات غير محفوظة',
  ),
  'pe.unsaved_body': (
    'Yaptığınız düzenlemeler henüz kaydedilmedi. Ne yapalım?',
    'Your edits have not been saved yet. What should we do?',
    'لم تُحفظ تعديلاتك بعد. ماذا نفعل؟',
  ),
  'pe.discard_leave': ('Kaydetme, çık', 'Don’t save, leave', 'اخرج دون حفظ'),
  'pe.hint_text_none': (
    'Bu sayfada düzenlenebilir metin bulunamadı. Yeni yazı için “Yazı ekle”ye dokunun.',
    'No editable text on this page. Tap “Add text” to write on it.',
    'لا يوجد نص قابل للتحرير في هذه الصفحة. اضغط «إضافة نص» للكتابة عليها.',
  ),
  'pe.hint_text_scanned': (
    'Taranmış sayfa: dokunduğunuz satırın üstüne yazılır (satır tanınıyor…).',
    'Scanned page: tap a line to type over it (recognizing lines…).',
    'صفحة ممسوحة: المس سطرًا للكتابة فوقه (جارٍ التعرف على الأسطر…).',
  ),
  'pe.scanned_updated': (
    'Satır güncellendi.',
    'Line updated.',
    'تم تحديث السطر.',
  ),
  // ── Sesli okuma ayarları ──────────────────────────────────────────────────
  'tts.settings': ('Sesli okuma', 'Read aloud', 'القراءة الصوتية'),
  'tts.default_voice': (
    'Cihaz varsayılanı',
    'Device default',
    'إعداد الجهاز الافتراضي',
  ),
  'tts.no_voices': (
    'Cihaz ses listesi vermedi; hız ve perde yine ayarlanabilir. Daha iyi '
        'sesler için cihaz ayarlarından konuşma motoru sesi indirilebilir.',
    'The device did not report a voice list; speed and pitch still apply. '
        'Better voices can be downloaded from the system speech settings.',
    'لم يوفّر الجهاز قائمة أصوات؛ تظل السرعة والنبرة قابلتين للضبط.',
  ),
  'tts.neural_sub': ('Yapay zekâ sesi · cihazda, internetsiz', 'AI voice · on device, offline', 'صوت ذكاء اصطناعي · على الجهاز، دون إنترنت'),
  'tts.neural_get': ('İndirmek için dokunun', 'Tap to download', 'المس للتنزيل'),
  'tts.rate': ('Hız', 'Speed', 'السرعة'),
  'tts.pitch': ('Perde', 'Pitch', 'النبرة'),
  'tts.try': ('Dene', 'Try', 'جرّب'),
  'tts.sample': (
    'Bu ses böyle okuyor. Beğendiniz mi?',
    'This is how this voice reads. Do you like it?',
    'هكذا يقرأ هذا الصوت. هل أعجبك؟',
  ),
  'tts.voice_settings': ('Ses ayarları', 'Voice settings', 'إعدادات الصوت'),
  'tts.ai_read': ('AI ile oku', 'Read with AI', 'اقرأ بالذكاء'),
  'tts.ai_read_on': (
    'AI ile oku açık: sayfa okunmadan önce metin toparlanır.',
    'Read with AI is on: the text is tidied before each page is read.',
    'القراءة بالذكاء مفعّلة: يُنظَّف النص قبل قراءة كل صفحة.',
  ),
  'tts.ai_read_off': (
    'AI ile oku kapalı.',
    'Read with AI is off.',
    'القراءة بالذكاء متوقفة.',
  ),
  'tts.ai_needs_key': (
    'AI ile oku için Ayarlar > Gemini API anahtarı gerekiyor.',
    'Read with AI needs a Gemini API key (Settings).',
    'تتطلب القراءة بالذكاء مفتاح Gemini من الإعدادات.',
  ),
  // "Düzelt" adı kullanıcıyı yanıltıyordu (2026-08-06): sayfanın EĞİKLİĞİNİ
  // düzelteceğini sanıp bu düğmeleri aradı. İkisi de METNİ onarır (OCR'ın
  // Türkçe hataları); eğiklik/kavis düzeltme tarama önizlemesinde
  // ("Düzleştir", `sr.straighten`). Ad artık ne yaptığını söylüyor.
  'pe.fix_page': ('Metni düzelt', 'Fix text', 'إصلاح النص'),
  'pe.fix_page_ai': ('Metni AI ile düzelt', 'Fix text with AI', 'إصلاح النص بالذكاء'),
  'pe.fix_done': (
    '{n} satır düzeltildi.',
    '{n} lines corrected.',
    'تم تصحيح {n} سطرًا.',
  ),
  'pe.fix_nothing': (
    'Düzeltilecek bir şey bulunamadı — sayfa zaten temiz görünüyor.',
    'Nothing to correct — the page already looks clean.',
    'لا شيء لتصحيحه — تبدو الصفحة نظيفة بالفعل.',
  ),
  'pe.fix_needs_key': (
    'AI ile düzeltme için Ayarlar > Gemini API anahtarı gerekiyor. '
        'Anahtarsız "Düzelt" düğmesi cihaz içinde çalışmaya devam eder.',
    'Fixing with AI needs a Gemini API key (Settings). The plain “Fix” '
        'button keeps working on-device without a key.',
    'يتطلب الإصلاح بالذكاء مفتاح Gemini من الإعدادات. يظل زر «إصلاح» '
        'يعمل على الجهاز بدون مفتاح.',
  ),
  'pe.hint_text': (
    'Değiştirmek istediğiniz paragrafa dokunun.',
    'Tap the paragraph you want to change.',
    'اضغط على الفقرة التي تريد تغييرها.',
  ),
  // Görsel VAR ama hiçbiri düzenlenemiyor (paylaşılan çizim bloğu ya da
  // satır içi görsel). Eskiden bu durumda da "görsel yok" yazıyordu ve
  // kullanıcı gözüyle gördüğü şeyin yokmuş gibi anlatılmasına haklı olarak
  // güvenmiyordu (2026-09-04).
  'pe.hint_image_locked': (
    'Bu sayfadaki görseller yerinde sabit: gösteriliyor ama düzenlenemiyor '
        '(belgede paylaşılan çizim bloğu ya da satır içi görsel).',
    'The images on this page are fixed in place: shown but not editable '
        '(a shared drawing block or an inline image).',
    'الصور في هذه الصفحة ثابتة: تُعرض لكن لا يمكن تحريرها (كتلة رسم مشتركة '
        'أو صورة مضمّنة في المحتوى).',
  ),
  'pe.object_locked': (
    'Bu görsel düzenlenemiyor; yalnız yeri gösteriliyor.',
    'This image cannot be edited; only its position is shown.',
    'لا يمكن تحرير هذه الصورة؛ يُعرض موضعها فقط.',
  ),
  // Sayfa çözümlemesi reddedildiğinde şerit KALICI olarak bunu yazar.
  // Eskiden yalnız bir anlık uyarı çıkıyor, sonra "bu sayfada metin/görsel
  // yok" yazısı kalıyordu — yani hata, boş sayfa gibi görünüyordu.
  'pe.hint_failed': (
    'Bu sayfa çözümlenemedi: {error}',
    'This page could not be analyzed: {error}',
    'تعذّر تحليل هذه الصفحة: {error}',
  ),
  'pe.hint_image_none': (
    'Bu sayfada gömülü görsel yok.',
    'There are no embedded images on this page.',
    'لا توجد صور مضمّنة في هذه الصفحة.',
  ),
  'pe.hint_image': (
    'Görsele dokunup seçin; sürükleyerek taşıyın, köşeden boyutlandırın, '
        'alttaki çubuktan döndürün ya da aynalayın.',
    'Tap an image to select it; drag to move, resize from a corner, or use '
        'the bar below to rotate and mirror it.',
    'اضغط على صورة لتحديدها؛ اسحب للنقل، وغيّر الحجم من الزاوية، أو استخدم '
        'الشريط أدناه للتدوير والعكس.',
  ),
  'pe.hint_background': (
    'Her sayfada yinelenen öğeler aşağıda. Kaldırmak istediklerinizi seçin.',
    'Items repeated on every page are listed below. Select the ones to remove.',
    'العناصر المتكررة في كل صفحة مدرجة أدناه. اختر ما تريد إزالته.',
  ),
  'pe.hint_page': ('Açık sayfayı döndürün.', 'Rotate the open page.', 'دوّر الصفحة المفتوحة.'),
  'pe.mode_text': ('Metin', 'Text', 'نص'),
  'pe.mode_image': ('Görsel', 'Image', 'صورة'),
  'pe.mode_watermark': ('Filigran', 'Watermark', 'علامة مائية'),
  'pe.mode_page': ('Sayfa', 'Page', 'صفحة'),
  'pe.clear_selection': ('Seçimi bırak', 'Clear selection', 'إلغاء التحديد'),
  'pe.rot_left': ('90° sola', '90° left', '90° لليسار'),
  'pe.rot_right': ('90° sağa', '90° right', '90° لليمين'),
  'pe.no_background': (
    'Yinelenen arka plan öğesi bulunamadı.',
    'No repeating background items found.',
    'لم يُعثر على عناصر خلفية متكررة.',
  ),
  'pe.remove_picked': (
    'Seçilenleri kaldır ({n})',
    'Remove selected ({n})',
    'إزالة المحدد ({n})',
  ),
  'pe.edit_paragraph': ('Paragrafı düzenle', 'Edit paragraph', 'تحرير الفقرة'),
  'pe.current_text': ('Şu anki metin', 'Current text', 'النص الحالي'),
  'pe.new_text': ('Yeni metin', 'New text', 'النص الجديد'),
  'pe.new_text_help': (
    'Yazı tipi, punto ve sayfa düzeni korunur.',
    'The font, size and page layout are preserved.',
    'يُحافظ على الخط والحجم وتخطيط الصفحة.',
  ),
  'pe.font_size': ('Punto', 'Font size', 'حجم الخط'),
  'pe.font_size_help': (
    'Belgedeki ölçülen punto. Değiştirirseniz paragrafın tamamı ölçeklenir.',
    'The measured size from the document. Changing it scales the whole '
        'paragraph.',
    'الحجم المقاس من المستند. تغييره يقيس الفقرة بأكملها.',
  ),
  'pe.font_smaller': ('Küçült', 'Smaller', 'أصغر'),
  'pe.font_bigger': ('Büyüt', 'Bigger', 'أكبر'),

  // ── Slayt düzenleyici ─────────────────────────────────────────────────────
  'sl.play': ('Oynat', 'Play', 'تشغيل'),
  'sl.to_pdf': ('PDF', 'PDF', 'PDF'),
  'sl.pdf_progress': (
    'Slayt {n}/{total} basılıyor…',
    'Rendering slide {n}/{total}…',
    'يجري تصيير الشريحة {n}/{total}…',
  ),
  'sl.pdf_failed': (
    'PDF üretilemedi: {error}',
    'Could not create the PDF: {error}',
    'تعذّر إنشاء ملف PDF: {error}',
  ),
  'sl.pdf_share': ('Sunum (PDF)', 'Presentation (PDF)', 'عرض تقديمي (PDF)'),
  'sl.none': ('Slayt bulunamadı.', 'No slides found.', 'لم يُعثر على شرائح.'),
  'sl.notes_title': ('Slayt {n} · notlar', 'Slide {n} · notes', 'الشريحة {n} · الملاحظات'),
  'sl.notes_prev': ('Önceki notlu slayt', 'Previous slide with notes', 'الشريحة السابقة ذات الملاحظات'),
  'sl.notes_next': ('Sonraki notlu slayt', 'Next slide with notes', 'الشريحة التالية ذات الملاحظات'),
  'sl.notes_toggle': ('Konuşmacı notları', 'Speaker notes', 'ملاحظات المتحدث'),
  'sl.actions': ('Slayt işlemleri', 'Slide actions', 'إجراءات الشريحة'),
  'sl.duplicate': ('Slaytı çoğalt', 'Duplicate slide', 'تكرار الشريحة'),
  'sl.move_up': ('Yukarı taşı', 'Move up', 'تحريك لأعلى'),
  'sl.move_down': ('Aşağı taşı', 'Move down', 'تحريك لأسفل'),
  'sl.delete': ('Slaytı sil', 'Delete slide', 'حذف الشريحة'),
  'sl.no_structure': (
    'Bu dosyada slayt yapısı düzenlenemiyor (eksik sunum bilgisi).',
    'The slide structure cannot be edited in this file (missing presentation data).',
    'لا يمكن تحرير بنية الشرائح في هذا الملف (بيانات العرض ناقصة).',
  ),
  'sl.duplicated': ('Slayt çoğaltıldı.', 'Slide duplicated.', 'تم تكرار الشريحة.'),
  'sl.delete_body': (
    'Slayt {n} silinsin mi? Bu işlem geri alınamaz '
        '(kaydedene kadar dosya değişmez).',
    'Delete slide {n}? This cannot be undone (the file is unchanged until you save).',
    'هل تريد حذف الشريحة {n}؟ لا يمكن التراجع عن ذلك (لا يتغيّر الملف حتى تحفظ).',
  ),
  'sl.nothing_to_play': (
    'Bu dosyada gösterilecek slayt yok.',
    'There are no slides to show in this file.',
    'لا توجد شرائح للعرض في هذا الملف.',
  ),
  'sl.open_failed': ('Açılamadı: {error}', 'Could not open: {error}', 'تعذّر الفتح: {error}'),
  'sl.slide_of': ('Slayt {n} / {total}', 'Slide {n} / {total}', 'الشريحة {n} / {total}'),
  'sl.goto': ('Slayta git', 'Go to slide', 'الانتقال إلى شريحة'),
  'sl.goto_hint': (
    '1 – {total} arası',
    'Between 1 and {total}',
    'بين 1 و {total}',
  ),
  'sl.search_hint': (
    'Slaytlarda ara',
    'Search in slides',
    'ابحث في الشرائح',
  ),
  'sl.no_match': ('Eşleşme yok', 'No matches', 'لا توجد نتائج'),
  'sl.match_pos': ('{n} / {total}', '{n} / {total}', '{n} / {total}'),
  'sl.fullscreen': ('Tam ekran sunum', 'Full-screen slideshow', 'عرض ملء الشاشة'),
  'sl.done': ('Bitti', 'Done', 'تم'),

  // ── PDF araçları ──────────────────────────────────────────────────────────
  'pt.locked_title': ('Belge parolalı', 'The document has a password', 'المستند محمي بكلمة مرور'),
  'pt.enter_password': ('Parolayı girin', 'Enter the password', 'أدخل كلمة المرور'),
  'pt.job_name': ('PDF işlemi ({label})', 'PDF operation ({label})', 'عملية PDF ({label})'),
  'pt.op_failed': (
    '{label} başarısız: {error}',
    '{label} failed: {error}',
    'فشل {label}: {error}',
  ),
  'pt.op_rotate': ('Döndürme', 'Rotating', 'التدوير'),
  'pt.op_delete': ('Silme', 'Deleting', 'الحذف'),
  'pt.op_move': ('Taşıma', 'Moving', 'النقل'),
  'pt.op_move_page': ('Sayfa taşıma', 'Moving a page', 'نقل صفحة'),
  'pt.op_merge': ('Birleştirme', 'Merging', 'الدمج'),
  'pt.op_scan_append': ('Tarama ekleme', 'Adding a scan', 'إضافة مسح ضوئي'),
  'pt.op_compress': ('Sıkıştırılıyor', 'Compressing', 'جارٍ الضغط'),
  'pt.op_set_password': ('Parola koyma', 'Setting a password', 'تعيين كلمة مرور'),
  'pt.op_remove_password': ('Parola kaldırma', 'Removing the password', 'إزالة كلمة المرور'),
  'pt.cannot_delete_all': (
    'Tüm sayfalar silinemez',
    'You cannot delete every page',
    'لا يمكن حذف كل الصفحات',
  ),
  'pt.annot_title': ('Vurgular kaybolacak', 'Highlights will be lost', 'ستفقد التمييزات'),
  'pt.annot_body': (
    'Bu belgede {n} vurgu/not var. “{action}” işlemi sayfaları yeniden '
        'oluşturduğu için bunlar silinir.\n\n'
        'Sayfa silmek isterseniz “Sil” düğmesi vurguları korur.',
    'This document has {n} highlights/notes. The “{action}” operation rebuilds '
        'the pages, so they will be deleted.\n\n'
        'If you want to delete pages, the “Delete” button keeps highlights.',
    'يحتوي هذا المستند على {n} تمييز/ملاحظة. عملية «{action}» تعيد بناء '
        'الصفحات، لذا ستُحذف.\n\n'
        'إن أردت حذف صفحات، فإن زر «حذف» يحافظ على التمييزات.',
  ),
};
