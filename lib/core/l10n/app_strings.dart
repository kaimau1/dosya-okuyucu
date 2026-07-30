import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// Uygulama metinleri — Türkçe / İngilizce / Arapça.
///
/// **Neden kod tablosu, neden `.arb` + `gen_l10n` değil:** üretilen kod CI'da
/// ek bir adım (`flutter gen-l10n`) ister ve çıktısı depoya girmezse derleme
/// kırılır. Burada tablo düz Dart; `flutter analyze`/`test` dışında araç yok.
///
/// **Kayıp çeviri İMKÂNSIZ:** her anahtarın karşılığı üç alanlı bir kayıt
/// (`tr`, `en`, `ar`). Bir dili unutmak yazım hatası değil, **derleme hatası**
/// olur — üç ayrı `Map` tutulsaydı eksik anahtar ancak çalışma anında
/// (kullanıcının ekranında) fark edilirdi.
///
/// Değişken yerleştirme: metinde `{ad}`, çağrıda `{'ad': değer}`.
class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  /// En yakın [Localizations]tan okur. Yoksa (test kısayolları, `Localizations`
  /// kurulmadan çizilen ekranlar) Türkçe'ye düşer — metinsiz ekran çizmektense
  /// uygulamanın ana dilini göstermek doğru.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(AppLanguage.tr);

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// Anahtarın bu dildeki karşılığı. Anahtar tabloda yoksa anahtarın kendisi
  /// döner (ekranda gözle görülür bir iz bırakır; sessizce boş kalmaz).
  String t(String key, [Map<String, Object?>? vars]) {
    final entry = _table[key];
    if (entry == null) {
      assert(false, 'çevrilmemiş anahtar: $key');
      return key;
    }
    var text = switch (language) {
      AppLanguage.en => entry.$2,
      AppLanguage.ar => entry.$3,
      _ => entry.$1,
    };
    if (vars != null) {
      vars.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    }
    return text;
  }

  /// Tablodaki tüm anahtarlar (test ve denetim için).
  static Iterable<String> get keys => _table.keys;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'tr', 'en', 'ar'}.contains(locale.languageCode);

  /// **`SynchronousFuture` şart:** tablo koddadır, yüklenecek bir şey yok.
  /// `async` bir gövde `Localizations`ı bir kare bekletir ve o karede ekran
  /// BOŞ çizilir — dil değiştirmede gözle görülür bir çakma olurdu.
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(AppLanguageInfo.byCode(locale.languageCode)));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

/// Kısayol: `context.t('common.save')`.
extension AppStringsX on BuildContext {
  String t(String key, [Map<String, Object?>? vars]) =>
      AppStrings.of(this).t(key, vars);

  /// Seçili dil (ekranın kendi yönünü ayarlaması gerekenler için).
  AppLanguage get language => AppStrings.of(this).language;
}

/// Anahtar → (Türkçe, English, العربية).
const Map<String, (String, String, String)> _table = {
  // ── Ortak eylemler ────────────────────────────────────────────────────────
  'common.ok': ('Tamam', 'OK', 'موافق'),
  'common.cancel': ('Vazgeç', 'Cancel', 'إلغاء'),
  'common.close': ('Kapat', 'Close', 'إغلاق'),
  'common.save': ('Kaydet', 'Save', 'حفظ'),
  'common.delete': ('Sil', 'Delete', 'حذف'),
  'common.share': ('Paylaş', 'Share', 'مشاركة'),
  'common.open': ('Aç', 'Open', 'فتح'),
  'common.edit': ('Düzenle', 'Edit', 'تحرير'),
  'common.apply': ('Uygula', 'Apply', 'تطبيق'),
  'common.search': ('Ara', 'Search', 'بحث'),
  'common.refresh': ('Yenile', 'Refresh', 'تحديث'),
  'common.settings': ('Ayarlar', 'Settings', 'الإعدادات'),
  'common.previous': ('Önceki', 'Previous', 'السابق'),
  'common.next': ('Sonraki', 'Next', 'التالي'),
  'common.translate': ('Çevir', 'Translate', 'ترجمة'),
  'common.ai': ('AI ile çalış', 'Work with AI', 'العمل بالذكاء الاصطناعي'),
  'common.bold': ('Kalın', 'Bold', 'عريض'),
  'common.italic': ('İtalik', 'Italic', 'مائل'),
  'common.underline': ('Altı çizili', 'Underline', 'تسطير'),
  'common.align_left': ('Sola yasla', 'Align left', 'محاذاة لليسار'),
  'common.align_center': ('Ortala', 'Center', 'توسيط'),
  'common.align_right': ('Sağa yasla', 'Align right', 'محاذاة لليمين'),
  'common.align_justify': ('İki yana yasla', 'Justify', 'ضبط'),
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
  'settings.appearance': ('Görünüm', 'Appearance', 'المظهر'),
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
  'settings.account': ('Hesap & Senkron', 'Account & sync', 'الحساب والمزامنة'),
  'settings.account_local': (
    'Bulut senkron için Firebase henüz yapılandırılmamış. Uygulama şu an yerel '
        'modda çalışıyor.',
    'Firebase is not configured yet, so cloud sync is off. The app is running '
        'in local mode.',
    'لم يتم إعداد Firebase بعد، لذا المزامنة السحابية متوقفة. يعمل التطبيق '
        'حاليًا في الوضع المحلي.',
  ),
  'settings.account_local_note': (
    'Etkinleştirmek için depo kökündeki FIREBASE_SETUP.md adımlarını izleyin '
        '(flutterfire configure).',
    'To enable it, follow FIREBASE_SETUP.md in the repository root '
        '(flutterfire configure).',
    'لتفعيلها، اتبع خطوات FIREBASE_SETUP.md في جذر المستودع '
        '(flutterfire configure).',
  ),
  'settings.signed_in': ('Giriş yapıldı', 'Signed in', 'تم تسجيل الدخول'),
  'settings.sync_active': ('Bulut senkron aktif', 'Cloud sync is on', 'المزامنة السحابية مفعّلة'),
  'settings.sign_out': ('Çıkış', 'Sign out', 'تسجيل الخروج'),
  'settings.email': ('E-posta', 'Email', 'البريد الإلكتروني'),
  'settings.password': ('Parola', 'Password', 'كلمة المرور'),
  'settings.sign_in': ('Giriş', 'Sign in', 'تسجيل الدخول'),
  'settings.register': ('Kayıt ol', 'Register', 'إنشاء حساب'),
  'settings.google_sign_in': ('Google ile giriş', 'Sign in with Google', 'الدخول عبر Google'),
  'settings.about': ('Hakkında', 'About', 'حول'),
  'settings.about_body': (
    'Dosya Okuyucu • sürüm 0.1.0\n'
        'Çok formatlı, hızlı ve sade dosya okuyucu/düzenleyici.',
    'Dosya Okuyucu • version 0.1.0\n'
        'A fast, simple multi-format file reader/editor.',
    'Dosya Okuyucu • الإصدار 0.1.0\n'
        'قارئ/محرر ملفات سريع وبسيط يدعم صيغًا متعددة.',
  ),
  'settings.oss': ('Açık kaynak bileşenler', 'Open-source components', 'المكوّنات مفتوحة المصدر'),
  'settings.oss_sub': (
    'FFmpeg (LGPL v3) ve diğer lisanslar',
    'FFmpeg (LGPL v3) and other licenses',
    'FFmpeg (LGPL v3) وتراخيص أخرى',
  ),

  // ── Dosya yöneticisi: pano ────────────────────────────────────────────────
  'fm.all_files': ('Tüm dosyalar', 'All files', 'كل الملفات'),
  'fm.quick_folders': ('Hızlı klasörler', 'Quick folders', 'مجلدات سريعة'),
  'fm.tools': ('Araçlar', 'Tools', 'الأدوات'),
  'fm.recent_opened': ('Son açılanlar', 'Recently opened', 'المفتوحة مؤخرًا'),
  'fm.recent_ops': ('Son işlemler', 'Recent operations', 'العمليات الأخيرة'),
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
  'fm.free_space': ('Yer aç', 'Free up space', 'تحرير مساحة'),
  'fm.similar_images': ('Benzer görsel', 'Similar images', 'صور متشابهة'),
  'fm.apk_files': ('APK dosyaları', 'APK files', 'ملفات APK'),
  'fm.network_storage': ('Ağ depolama', 'Network storage', 'التخزين الشبكي'),
  'fm.trash': ('Çöp', 'Trash', 'المهملات'),
  'fm.trash_count': ('{n} öğe', '{n} items', '{n} عنصر'),
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

  // ── Dosya açma ────────────────────────────────────────────────────────────
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

  // ── PC'den telefona FTP sunucusu ──────────────────────────────────────────
  'ftpd.title': ('PC\'den eriş (FTP)', 'Access from PC (FTP)', 'الوصول من الحاسوب (FTP)'),
  'ftpd.description': (
    'Telefonu FTP sunucusuna çevirir: PC\'nizin dosya gezgininden ya da '
        'tarayıcısından aşağıdaki adresi açarak telefondaki dosyalara '
        'ulaşabilirsiniz. Telefon ve PC AYNI Wi-Fi ağında olmalı.',
    'Turns the phone into an FTP server: open the address below in your PC\'s '
        'file explorer or browser to reach the files on the phone. The phone '
        'and the PC must be on the SAME Wi-Fi network.',
    'يحوّل الهاتف إلى خادم FTP: افتح العنوان أدناه في مستكشف الملفات أو المتصفح '
        'على حاسوبك للوصول إلى ملفات الهاتف. يجب أن يكون الهاتف والحاسوب على '
        'نفس شبكة Wi-Fi.',
  ),
  'ftpd.start': ('Başlat', 'Start', 'ابدأ'),
  'ftpd.stop': ('Durdur', 'Stop', 'أوقف'),
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
  'ftpd.shared_folder': ('Paylaşılan klasör', 'Shared folder', 'المجلد المشترك'),
  'ftpd.copied': ('Adres kopyalandı.', 'Address copied.', 'تم نسخ العنوان.'),
  'ftpd.start_failed': (
    'Sunucu başlatılamadı: {error}',
    'Could not start the server: {error}',
    'تعذّر بدء الخادم: {error}',
  ),

  // ── Google Drive ──────────────────────────────────────────────────────────
  'drive.title': ('Google Drive', 'Google Drive', 'Google Drive'),
  'drive.sign_in': ('Google ile bağlan', 'Connect with Google', 'الاتصال عبر Google'),
  'drive.sign_out': ('Bağlantıyı kes', 'Disconnect', 'قطع الاتصال'),
  'drive.sign_in_prompt': (
    'Drive\'a dosya yüklemek ve yüklediklerinizi buradan açmak için Google '
        'hesabınıza bağlanın.',
    'Connect your Google account to upload files to Drive and open what you '
        'uploaded from here.',
    'اتصل بحساب Google لرفع الملفات إلى Drive وفتح ما رفعته من هنا.',
  ),
  // Kapsam dürüstlüğü: bu metin OLMADAN boş liste "bozuk" sanılır.
  'drive.scope_notice': (
    'Burada yalnız **bu uygulamayla yüklediğiniz** dosyalar görünür; '
        'Drive\'ınızdaki diğer dosyalara erişim istemiyoruz. Başka bir Drive '
        'dosyasını açmak için: Dosya Aç → sistem seçicisinde Drive.',
    'Only files **you uploaded with this app** appear here; we do not request '
        'access to the rest of your Drive. To open another Drive file: Open '
        'file → pick Drive in the system picker.',
    'تظهر هنا الملفات **التي رفعتها بهذا التطبيق** فقط؛ لا نطلب الوصول إلى بقية '
        'ملفات Drive. لفتح ملف آخر من Drive: فتح ملف ← اختر Drive من منتقي النظام.',
  ),
  'drive.empty': (
    'Henüz bu uygulamayla Drive\'a dosya yüklemediniz.',
    'You haven\'t uploaded any file to Drive with this app yet.',
    'لم ترفع أي ملف إلى Drive بهذا التطبيق بعد.',
  ),
  'drive.search_hint': ('Drive\'da ara…', 'Search Drive…', 'ابحث في Drive…'),
  'drive.exports_as': (
    '{format} olarak iner',
    'downloads as {format}',
    'يُنزَّل بصيغة {format}',
  ),
  'drive.uploading': ('Drive\'a yükleniyor…', 'Uploading to Drive…', 'جارٍ الرفع إلى Drive…'),
  'drive.upload_done': ('Drive\'a yüklendi:', 'Uploaded to Drive:', 'تم الرفع إلى Drive:'),
  'drive.upload_failed': ('Drive\'a yüklenemedi.', 'Upload to Drive failed.', 'فشل الرفع إلى Drive.'),
  'drive.download_failed': ('Dosya indirilemedi.', 'Could not download the file.', 'تعذّر تنزيل الملف.'),
  'drive.delete_confirm': (
    '“{name}” Drive\'dan silinsin mi?',
    'Delete “{name}” from Drive?',
    'هل تريد حذف «{name}» من Drive؟',
  ),
  'drive.delete_failed': ('Silinemedi.', 'Could not delete.', 'تعذّر الحذف.'),
  'drive.error_not_signed_in': (
    'Google hesabına bağlı değilsiniz.',
    'You are not connected to a Google account.',
    'أنت غير متصل بحساب Google.',
  ),
  'drive.error_forbidden': (
    'Drive bu işleme izin vermedi. Bu dosya uygulamamızla yüklenmemiş olabilir.',
    'Drive denied this operation. The file may not have been uploaded with this app.',
    'رفض Drive هذه العملية. قد لا يكون الملف مرفوعًا بواسطة هذا التطبيق.',
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
};
