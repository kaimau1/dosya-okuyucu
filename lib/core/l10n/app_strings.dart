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

  /// **Bağlamsız** yerler için son yüklenen dil (bildirimler, arka plandaki
  /// iş kuyruğu, `dart:io` katmanı). Delegate her `load`ta günceller.
  ///
  /// Arayüzde bunu KULLANMA: `context.t(...)` ekranın kendi `Localizations`ına
  /// bakar ve önizleme/test içinde ayrı bir dil kurulabilir; bu statik ise
  /// uygulama genelinde tektir.
  static AppStrings current = const AppStrings(AppLanguage.tr);

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
  Future<AppStrings> load(Locale locale) {
    final strings = AppStrings(AppLanguageInfo.byCode(locale.languageCode));
    AppStrings.current = strings;
    return SynchronousFuture(strings);
  }

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
  'common.copy': ('Kopyala', 'Copy', 'نسخ'),
  'common.stop': ('Durdur', 'Stop', 'إيقاف'),
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

  // ── Dosya yöneticisi: girdi işlemleri (uzun basış) ────────────────────────
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
  'vw.editor': ('Düzenleyici', 'Editor', 'المحرر'),
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
  'vw.page_of': ('{n}. sayfa (toplam {total})', 'Page {n} (of {total})', 'الصفحة {n} (من {total})'),
  'vw.page_jump_failed_total': (
    '{target}. sayfaya gidilemedi; {landed}. sayfada kalındı (toplam {total}).',
    'Could not jump to page {target}; stayed on page {landed} (of {total}).',
    'تعذّر الانتقال إلى الصفحة {target}؛ بقيت على {landed} (من {total}).',
  ),
  'vw.goto_page': ('Sayfaya git…', 'Go to page…', 'الانتقال إلى صفحة…'),
  'vw.goto_page_short': ('Sayfaya git', 'Go to page', 'الانتقال إلى صفحة'),
  'vw.find_in_doc': ('Belgede ara…', 'Search in document…', 'ابحث في المستند…'),
  'vw.find_in_doc_short': ('Belgede ara', 'Search in document', 'ابحث في المستند'),
  'vw.dont_save': ('Kaydetme', 'Don’t save', 'عدم الحفظ'),
  'vw.image_only': ('Sadece resim', 'Image only', 'الصورة فقط'),
  'vw.doc_info': ('Belge bilgisi', 'Document info', 'معلومات المستند'),
  'vw.highlight': ('Vurgula', 'Highlight', 'تمييز'),
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
  'vw.sign': ('İmzala', 'Sign', 'توقيع'),
  'vw.print': ('Yazdır', 'Print', 'طباعة'),
  'vw.ai_edit': ('AI ile düzenle', 'Edit with AI', 'تحرير بالذكاء الاصطناعي'),
  'vw.translate_doc': ('Belgeyi çevir', 'Translate document', 'ترجمة المستند'),
  'vw.to_pdf': ('PDF’e dönüştür', 'Convert to PDF', 'تحويل إلى PDF'),
  'vw.to_slides': ('Slayta dönüştür', 'Convert to slides', 'تحويل إلى شرائح'),
  'vw.file_ops': ('Dosya işlemleri (taşı, kopyala…)', 'File operations (move, copy…)', 'عمليات الملفات (نقل، نسخ…)'),
  'vw.ocr': ('Metni tanı (OCR)', 'Recognize text (OCR)', 'التعرّف على النص (OCR)'),
  'vw.ocr_short': ('Metni tanı', 'Recognize text', 'التعرّف على النص'),
  'vw.ocr_running': ('Metin tanınıyor…', 'Recognizing text…', 'جارٍ التعرّف على النص…'),
  'vw.ocr_page': ('Sayfa {n} / {total} taranıyor…', 'Scanning page {n} / {total}…', 'جارٍ فحص الصفحة {n} / {total}…'),
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
  'vw.change_failed': ('Değiştirilemedi: {error}', 'Could not change: {error}', 'تعذّر التغيير: {error}'),
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
  'apps.app_info': ('Uygulama bilgisi (sistem ayarı)', 'App info (system settings)', 'معلومات التطبيق (إعدادات النظام)'),
  'apps.color_legend': ('Renk = kullanılmama süresi', 'Colour = time unused', 'اللون = مدة عدم الاستخدام'),
  'apps.never_opened': ('hiç açılmadı', 'never opened', 'لم يُفتح قط'),
  'apps.today': ('bugün', 'today', 'اليوم'),
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
  'clean.title': ('Yer aç', 'Free up space', 'تحرير مساحة'),
  'clean.analyzing': ('Yer aç: depolama çözümleniyor', 'Free up space: analysing storage', 'تحرير مساحة: جارٍ تحليل التخزين'),
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
  'clean.cleaned': ('Temizlendi. Yeniden çözümleniyor…', 'Cleaned. Re-analysing…', 'تم التنظيف. جارٍ إعادة التحليل…'),
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
  'drive.upload_action': ('Drive\'a yükle', 'Upload to Drive', 'رفع إلى Drive'),
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

  // ── Dosya yöneticisi ayarları ─────────────────────────────────────────────
  'fmset.title': (
    'Dosya yöneticisi ayarları',
    'File manager settings',
    'إعدادات مدير الملفات',
  ),
  'fmset.sec_view': ('Görünüm', 'Appearance', 'المظهر'),
  'fmset.sec_open': ('Açma', 'Opening', 'الفتح'),
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
  'fmset.clear_thumbs_sub': (
    'Video önizlemeleri yeniden üretilir',
    'Video previews are regenerated',
    'يُعاد إنشاء معاينات الفيديو',
  ),
  'fmset.thumbs_none': (
    'Temizlenecek küçük resim bulunamadı.',
    'No thumbnails to clear.',
    'لا توجد صور مصغّرة لمسحها.',
  ),
  'fmset.thumbs_cleared': (
    '{n} küçük resim silindi.',
    '{n} thumbnails deleted.',
    'تم حذف {n} صورة مصغّرة.',
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

  // ── Arka plandaki iş kuyruğu / bildirimler ────────────────────────────────
  'job.error_generic': ('Bir hata oluştu.', 'Something went wrong.', 'حدث خطأ.'),
  'job.finished': ('Tamamlandı.', 'Completed.', 'اكتمل.'),
  'job.stopped_detail': (
    'Durduruldu · {detail}',
    'Stopped · {detail}',
    'تم الإيقاف · {detail}',
  ),

  // ── Sayılabilir değerlerin etiketleri (models/… `labelKey`) ───────────────
  // Buradaki her anahtar bir enum'un `labelKey` getter'ından gelir; saf Dart
  // modeller `AppStrings`'i tanımadığı için etiket metni tek yerde, burada.
  'enum.layout_list': ('Liste', 'List', 'قائمة'),
  'enum.layout_detail': ('Büyük liste', 'Large list', 'قائمة كبيرة'),
  'enum.layout_grid2': ('2 sütun', '2 columns', 'عمودان'),
  'enum.layout_grid3': ('3 sütun', '3 columns', '3 أعمدة'),
  'enum.layout_grid4': ('4 sütun', '4 columns', '4 أعمدة'),
  'enum.layout_grid5': ('5 sütun', '5 columns', '5 أعمدة'),
  'enum.layout_list_desc': (
    'Tek sıra · ad, boyut ve tarih',
    'Single row · name, size and date',
    'صف واحد · الاسم والحجم والتاريخ',
  ),
  'enum.layout_detail_desc': (
    'Tek sıra · büyük önizleme',
    'Single row · large preview',
    'صف واحد · معاينة كبيرة',
  ),
  'enum.layout_grid2_desc': ('En büyük kareler', 'Largest tiles', 'أكبر المربعات'),
  'enum.layout_grid3_desc': (
    'Dengeli — varsayılan',
    'Balanced — default',
    'متوازن — الافتراضي',
  ),
  'enum.layout_grid4_desc': ('Daha çok dosya sığar', 'Fits more files', 'يتّسع لملفات أكثر'),
  'enum.layout_grid5_desc': ('En yoğun görünüm', 'Densest view', 'أكثف عرض'),

  'enum.photo_group_day': ('Gün', 'Day', 'يوم'),
  'enum.photo_group_month': ('Ay', 'Month', 'شهر'),
  'enum.photo_group_year': ('Yıl', 'Year', 'سنة'),

  'enum.open_with_ask': ('Her seferinde sor', 'Ask every time', 'اسأل في كل مرة'),
  'enum.open_with_in_app': (
    'Uygulama içi oynatıcı',
    'In-app player',
    'المشغّل داخل التطبيق',
  ),
  'enum.open_with_external': ('Başka uygulama', 'Another app', 'تطبيق آخر'),
  'enum.open_with_ask_desc': (
    'Video/ses/görsel açarken hangisini kullanacağın sorulur',
    'You are asked which one to use when opening video/audio/images',
    'يُسألك أيّهما تستخدم عند فتح فيديو/صوت/صورة',
  ),
  'enum.open_with_in_app_desc': (
    'Dosyalar bu uygulamanın oynatıcısında açılır',
    'Files open in this app’s player',
    'تُفتح الملفات في مشغّل هذا التطبيق',
  ),
  'enum.open_with_external_desc': (
    'Telefonundaki varsayılan oynatıcı/galeri açılır',
    'Your phone’s default player/gallery opens',
    'يُفتح المشغّل/المعرض الافتراضي في هاتفك',
  ),

  'enum.cat_folder': ('Klasör', 'Folder', 'مجلد'),
  'enum.cat_image': ('Görüntüler', 'Images', 'الصور'),
  'enum.cat_video': ('Videolar', 'Videos', 'الفيديوهات'),
  'enum.cat_audio': ('Ses', 'Audio', 'الصوت'),
  'enum.cat_document': ('Belgeler', 'Documents', 'المستندات'),
  'enum.cat_archive': ('Arşivler', 'Archives', 'الأرشيفات'),
  'enum.cat_apk': ('Uygulamalar', 'Apps', 'التطبيقات'),
  'enum.cat_other': ('Diğer', 'Other', 'أخرى'),

  'enum.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'enum.sort_date': ('Tarihe göre', 'By date', 'حسب التاريخ'),
  'enum.sort_size': ('Boyuta göre', 'By size', 'حسب الحجم'),
  'enum.sort_type': ('Türe göre', 'By type', 'حسب النوع'),

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
  'enum.res_percent': ('Yüzdeyle küçült', 'Scale by percent', 'تصغير بنسبة مئوية'),
  'enum.res_custom': ('Serbest en × boy', 'Custom width × height', 'عرض × ارتفاع مخصص'),

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

  'enum.op_move': ('Taşıma', 'Move', 'نقل'),
  'enum.op_copy': ('Kopyalama', 'Copy', 'نسخ'),
  'enum.op_delete': ('Silme', 'Delete', 'حذف'),
  'enum.op_rename': ('Yeniden adlandırma', 'Rename', 'إعادة تسمية'),
  'enum.op_organize': ('Otomatik düzenleme', 'Auto-organize', 'تنظيم تلقائي'),
};
