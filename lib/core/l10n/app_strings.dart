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
  'common.more': ('Daha fazla', 'More', 'المزيد'),
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
  'vw.goto_page_short': ('sayfaya git', 'go to page', 'انتقل إلى صفحة'),
  'vw.find_in_doc': ('Belgede ara…', 'Search in document…', 'ابحث في المستند…'),
  'vw.find_in_doc_short': ('Belgede ara', 'Search in document', 'ابحث في المستند'),
  'vw.dont_save': ('Kaydetme', 'Don’t save', 'عدم الحفظ'),
  'vw.image_only': ('Sadece resim', 'Image only', 'الصورة فقط'),
  'vw.doc_info': ('Belge bilgisi', 'Document info', 'معلومات المستند'),
  'vw.highlight': ('Vurgula', 'Highlight', 'تمييز'),
  'fm.drive_subtitle': ('Buluttaki dosyalar', 'Files in the cloud', 'الملفات في السحابة'),
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
  'drive.upload_done': ('Drive\'a yüklendi:', 'Uploaded to Drive:', 'تم الرفع إلى Drive:'),
  'drive.upload_failed': ('Drive\'a yüklenemedi.', 'Upload to Drive failed.', 'فشل الرفع إلى Drive.'),
  'drive.download_failed': ('Dosya indirilemedi.', 'Could not download the file.', 'تعذّر تنزيل الملف.'),
  'drive.downloading': ('Drive\'dan indiriliyor…', 'Downloading from Drive…', 'جارٍ التنزيل من Drive…'),
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
  'fm.quick_untouched': (
    '{n} aydır açılmamış',
    'Not opened in {n} months',
    'لم يُفتح منذ {n} أشهر',
  ),
  'fm.storage_analysis': ('Bellek Analizi', 'Storage analysis', 'تحليل التخزين'),
  'fm.used_percent': ('Kullanılan %{n}', '{n}% used', 'مستخدَم %{n}'),
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
    'Bu sayfada düzenlenebilir metin bulunamadı (taranmış sayfa olabilir).',
    'No editable text found on this page (it may be a scanned page).',
    'لم يُعثر على نص قابل للتحرير في هذه الصفحة (قد تكون صفحة ممسوحة ضوئيًا).',
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
  'pe.hint_image_none': (
    'Bu sayfada gömülü görsel yok.',
    'There are no embedded images on this page.',
    'لا توجد صور مضمّنة في هذه الصفحة.',
  ),
  'pe.hint_image': (
    'Görsele dokunup seçin; sürükleyerek taşıyın, köşeden boyutlandırın.',
    'Tap an image to select it; drag to move, resize from a corner.',
    'اضغط على صورة لتحديدها؛ اسحب للنقل، وغيّر الحجم من الزاوية.',
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

  // ── Slayt düzenleyici ─────────────────────────────────────────────────────
  'sl.play': ('Oynat', 'Play', 'تشغيل'),
  'sl.none': ('Slayt bulunamadı.', 'No slides found.', 'لم يُعثر على شرائح.'),
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
  'ph.clean': ('Temizle', 'Clean up', 'تنظيف'),
  'ph.similar_title': ('Benzer: {title}', 'Similar: {title}', 'مشابه: {title}'),

  // ── AI sohbeti ────────────────────────────────────────────────────────────
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

  // ── Boyut düşürme ─────────────────────────────────────────────────────────
  'rs.title': (
    'Boyut düşür ({n} dosya)',
    'Reduce size ({n} files)',
    'تصغير الحجم ({n} ملف)',
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
  'pf.unlock_failed': (
    'Belgenin şifre koruması kaldırılamadı: {error}\n\n'
        'Parolayı biliyorsanız PDF araçlarından kaldırıp yeniden deneyin.',
    'Could not remove the document’s password protection: {error}\n\n'
        'If you know the password, remove it from PDF tools and try again.',
    'تعذّرت إزالة حماية كلمة المرور من المستند: {error}\n\n'
        'إن كنت تعرف كلمة المرور فأزلها من أدوات PDF ثم أعد المحاولة.',
  ),
  'pf.replaced_reflow': (
    'Değiştirildi — satırın kalanı yeniden hizalandı.',
    'Replaced — the rest of the line was re-aligned.',
    'تم الاستبدال — أُعيدت محاذاة بقية السطر.',
  ),
  'pf.replaced': ('Değiştirildi.', 'Replaced.', 'تم الاستبدال.'),
  'pf.overflow': (
    '⚠ Yeni metin satıra sığmadı, satır sayfanın metin alanının dışına taşıyor.',
    '⚠ The new text did not fit the line; it overflows the page’s text area.',
    '⚠ لم يتّسع النص الجديد للسطر، وهو يتجاوز منطقة النص في الصفحة.',
  ),
  'pf.unlocked_note': (
    'Belgenin şifre koruması kaldırıldı.',
    'The document’s password protection was removed.',
    'أُزيلت حماية كلمة المرور من المستند.',
  ),
  'pf.stamped': (
    'Metin ÜSTE yazıldı (yerinde düzenleme yapılamadı).',
    'The text was stamped ON TOP (in-place editing was not possible).',
    'كُتب النص فوق القديم (تعذّر التحرير في المكان).',
  ),
  'pf.locked_title': (
    'Belge şifre korumalı',
    'The document is password-protected',
    'المستند محمي بكلمة مرور',
  ),
  'pf.locked_body': (
    'Bu belgede şifre koruması var; açılırken parola sorulmadığına göre bu bir '
        'izin kilidi (yazdırma/kopyalama kısıtı).\n\n'
        'Koruma kaldırılırsa metin, belgenin KENDİ yazı tipi ve puntosuyla '
        'yerinde düzenlenebilir — görüntü hiç bozulmaz.\n\n'
        '• Özgün dosyanız değişmez: koruma yalnız düzenlenen kopyada kalkar, '
        'kaydetme biçimini çıkarken siz seçersiniz.\n'
        '• Belge bu sırada yeniden yazılır (artımlı güncelleme değil).\n\n'
        'Kaldırılmasın derseniz eski yazının üstüne yazma yolu önerilir; orada '
        'yazı tipi belgenin fontu OLMAZ.',
    'This document has password protection; since no password is asked when '
        'opening it, this is a permissions lock (printing/copying restriction).'
        '\n\nIf the protection is removed, the text can be edited in place '
        'using the document’s OWN font and size — the appearance is not '
        'affected at all.\n\n'
        '• Your original file is untouched: the protection is only removed on '
        'the edited copy, and you choose how to save when you leave.\n'
        '• The document is rewritten in the process (not an incremental '
        'update).\n\nIf you decline, stamping over the old text is offered '
        'instead; there the font will NOT be the document’s own.',
    'يحتوي هذا المستند على حماية بكلمة مرور؛ وبما أنه لا يطلب كلمة مرور عند '
        'الفتح فهذا قفل أذونات (تقييد الطباعة/النسخ).\n\n'
        'إذا أُزيلت الحماية فيمكن تحرير النص في مكانه بخط المستند وحجمه '
        'نفسيهما — دون أي تأثير على المظهر.\n\n'
        '• ملفك الأصلي لا يتغيّر: تُزال الحماية من النسخة المحرَّرة فقط، وأنت '
        'تختار طريقة الحفظ عند الخروج.\n'
        '• يُعاد كتابة المستند أثناء ذلك (وليس تحديثًا تزايديًا).\n\n'
        'إن رفضت فسيُقترح الكتابة فوق النص القديم؛ وهناك لن يكون الخط هو خط '
        'المستند.',
  ),
  'pf.dont_remove': ('Kaldırma', 'Don’t remove', 'لا تُزلها'),
  'pf.inplace_failed_title': (
    'Yerinde düzenleme yapılamadı',
    'In-place editing was not possible',
    'تعذّر التحرير في المكان',
  ),
  'pf.stamp_body': (
    'Bunun yerine eski yazının ÜSTÜ kapatılıp yenisi çizilebilir. '
        'Bu durumda:\n'
        '• yazı tipi belgenin kendi fontu olmaz,\n'
        '• iki yana yaslı metinde satır hizası bozulur,\n'
        '• arka plan düz renk varsayılır (desenli zeminde kutu görünür),\n'
        '• eski metin belgenin içinde aranabilir hâlde KALIR.\n\n'
        'Kısacası görüntü bozulabilir. Belgeyi korumak istiyorsanız “Vazgeç” '
        'deyip kaydederken “Kopyasını kaydet”i seçin.',
    'Instead, the old text can be covered and the new one drawn over it. '
        'In that case:\n'
        '• the font will not be the document’s own,\n'
        '• line alignment breaks in justified text,\n'
        '• the background is assumed to be a flat colour (a box shows on a '
        'patterned background),\n'
        '• the old text REMAINS searchable inside the document.\n\n'
        'In short, the appearance may suffer. To keep the document intact, tap '
        '“Cancel” and choose “Save a copy” when saving.',
    'بدلًا من ذلك يمكن تغطية النص القديم ورسم الجديد فوقه. لكن:\n'
        '• لن يكون الخط هو خط المستند،\n'
        '• تختلّ محاذاة الأسطر في النص المضبوط،\n'
        '• تُفترض الخلفية لونًا مسطحًا (يظهر مربع فوق خلفية منقوشة)،\n'
        '• يبقى النص القديم قابلًا للبحث داخل المستند.\n\n'
        'باختصار قد يتضرّر المظهر. للحفاظ على المستند اضغط «إلغاء» واختر «حفظ '
        'نسخة» عند الحفظ.',
  ),
  'pf.stamp_over': ('Üste yaz', 'Stamp over', 'اكتب فوقه'),

  // ── Benzer görüntüler ─────────────────────────────────────────────────────
  'sim.title': ('Benzer görüntüler', 'Similar images', 'صور متشابهة'),
  'sim.scanning_title': (
    'Benzer görüntüler aranıyor ({level})',
    'Searching for similar images ({level})',
    'جارٍ البحث عن صور متشابهة ({level})',
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
  'mp.now_playing': ('Çalıyor', 'Now playing', 'قيد التشغيل'),
  'mp.speed': ('Hız', 'Speed', 'السرعة'),
  'mp.play_speed': ('Oynatma hızı', 'Playback speed', 'سرعة التشغيل'),
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
    'Mavi dikdörtgenin köşelerini sayfanın köşelerine sürükleyin. '
        'Sayfa eğik çekildiyse de düzleştirilir.',
    'Drag the corners of the blue rectangle onto the corners of the page. A '
        'skewed shot is straightened too.',
    'اسحب زوايا المستطيل الأزرق إلى زوايا الصفحة. وتُقوَّم أيضًا اللقطة المائلة.',
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

  // ── Tarama akışı ──────────────────────────────────────────────────────────
  'sf.scanner_failed': (
    'Tarayıcı açılamadı: {error}\nKamera izni verilmemiş olabilir.',
    'Could not open the scanner: {error}\nCamera permission may be missing.',
    'تعذّر فتح الماسح: {error}\nقد يكون إذن الكاميرا مفقودًا.',
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
  'simf.none': ('Benzer dosya bulunamadı', 'No similar files found', 'لم يُعثر على ملفات متشابهة'),
  'simf.found': (
    '{n} grup · {size} kazanılabilir',
    '{n} groups · {size} can be freed',
    '{n} مجموعة · يمكن تحرير {size}',
  ),

  // ── AI eylemleri (dosyaya uzun basış) ─────────────────────────────────────
  'aia.need_key': (
    'Önce Ayarlar > Gemini API anahtarı bölümünden anahtarınızı girin.',
    'First enter your key under Settings > Gemini API key.',
    'أدخل مفتاحك أولًا من الإعدادات > مفتاح Gemini API.',
  ),
  'aia.read_failed': (
    'Belge okunamadı: {error}',
    'Could not read the document: {error}',
    'تعذّرت قراءة المستند: {error}',
  ),
  'aia.no_text': (
    'Bu dosyadan özetlenecek metin çıkarılamadı.',
    'No text could be extracted from this file to summarise.',
    'تعذّر استخراج نص من هذا الملف لتلخيصه.',
  ),
  'aia.summary_prompt': (
    'Bu belgeyi Türkçe özetle. Biçim:\n'
        '1) Tek cümlelik "bu ne belgesi" tanımı\n'
        '2) En fazla 5 madde hâlinde önemli bilgiler (tarih, tutar, taraflar, '
        'son tarih varsa mutlaka yaz)\n'
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English. Format:\n'
        '1) A one-sentence "what kind of document is this"\n'
        '2) At most 5 bullet points with the important facts (always include '
        'dates, amounts, parties and any deadline)\n'
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية. الصيغة:\n'
        '1) جملة واحدة تصف «ما نوع هذا المستند»\n'
        '2) خمس نقاط كحد أقصى بالمعلومات المهمة (اذكر دائمًا التواريخ والمبالغ '
        'والأطراف وأي موعد نهائي)\n'
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'aia.summary_failed': (
    'AI özeti alınamadı: {error}',
    'Could not get the AI summary: {error}',
    'تعذّر الحصول على ملخّص الذكاء الاصطناعي: {error}',
  ),
  'aia.summary_title': ('AI özeti', 'AI summary', 'ملخّص الذكاء الاصطناعي'),

  // AI özet akışı (AiSummaryFlow) — kısa / detaylı.
  'ai.summarize': ('AI özet', 'AI summary', 'ملخّص ذكي'),
  'ai.sum_working': ('Özet hazırlanıyor…', 'Preparing the summary…', 'جارٍ إعداد الملخّص…'),
  'ai.sum_no_text': (
    'Özetlenecek metin bulunamadı.',
    'No text found to summarise.',
    'لم يُعثر على نص لتلخيصه.',
  ),
  'ai.sum_short': ('Kısa özet', 'Short summary', 'ملخّص قصير'),
  'ai.sum_short_hint': (
    'Birkaç cümle — "bu ne anlatıyor"',
    'A few sentences — the gist',
    'بضع جمل — الفكرة العامة',
  ),
  'ai.sum_detailed': ('Detaylı özet', 'Detailed summary', 'ملخّص مفصّل'),
  'ai.sum_detailed_hint': (
    'Bölüm bölüm, önemli sayı ve isimlerle',
    'Section by section, with key figures and names',
    'قسمًا بقسم، مع الأرقام والأسماء المهمة',
  ),
  'ai.sum_truncated': (
    'Belge uzun olduğu için yalnız ilk {n} karakter özetlendi.',
    'The document is long; only the first {n} characters were summarised.',
    'المستند طويل؛ لم يُلخَّص سوى أول {n} حرف.',
  ),
  'ai.sum_prompt_short': (
    'Bu belgeyi Türkçe, KISA özetle: en fazla 4-5 cümle. '
        'Ne anlattığını ve en önemli 2-3 bilgiyi ver. '
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English, SHORT: at most 4-5 sentences. '
        'Say what it is about and give the 2-3 most important facts. '
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية بإيجاز: 4-5 جمل كحد أقصى. '
        'اذكر موضوعه وأهم 2-3 معلومات. '
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'ai.sum_prompt_detailed': (
    'Bu belgeyi Türkçe, DETAYLI özetle. Biçim:\n'
        '1) Tek cümlelik "bu ne belgesi" tanımı\n'
        '2) Bölüm bölüm (slayt/başlık sırasıyla) madde madde özet — metinde '
        'slayt numarası varsa koru\n'
        '3) Önemli sayı, tarih, isim ve kararları ayrı bir başlıkta topla\n'
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English, in DETAIL. Format:\n'
        '1) A one-sentence "what kind of document is this"\n'
        '2) A section-by-section (slide/heading order) bullet summary — keep '
        'slide numbers if the text has them\n'
        '3) A separate heading collecting key figures, dates, names and decisions\n'
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية بالتفصيل. الصيغة:\n'
        '1) جملة واحدة تصف «ما نوع هذا المستند»\n'
        '2) ملخّص بالنقاط قسمًا بقسم (بترتيب الشرائح/العناوين) — واحتفظ بأرقام '
        'الشرائح إن وُجدت في النص\n'
        '3) عنوان منفصل يجمع الأرقام والتواريخ والأسماء والقرارات المهمة\n'
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'aia.reading_doc': ('Belge okunuyor…', 'Reading the document…', 'جارٍ قراءة المستند…'),
  'aia.reading_image': (
    'Görseldeki metin okunuyor…',
    'Reading the text in the image…',
    'جارٍ قراءة النص في الصورة…',
  ),
  'aia.ocr_failed': (
    'Metin tanınamadı: {error}',
    'Text recognition failed: {error}',
    'فشل التعرّف على النص: {error}',
  ),
  'aia.looks_like': (
    'Bu bir {type} gibi görünüyor',
    'This looks like a {type}',
    'يبدو أن هذا {type}',
  ),
  'aia.image_text': ('Görseldeki metin', 'Text in the image', 'النص في الصورة'),
  'aia.image_no_text': (
    'Bu görselde okunabilir metin bulunamadı.',
    'No readable text was found in this image.',
    'لم يُعثر على نص قابل للقراءة في هذه الصورة.',
  ),
  'aia.move_failed': ('Taşınamadı: {error}', 'Could not move it: {error}', 'تعذّر النقل: {error}'),
  'aia.moved': (
    '“{name}” → Önemli Dosyalar/{folder}',
    '“{name}” → Önemli Dosyalar/{folder}',
    '«{name}» ← Önemli Dosyalar/{folder}',
  ),
  'aia.hints': ('İpuçları: {list}', 'Hints: {list}', 'مؤشرات: {list}'),
  'aia.target_folder': (
    'Önemli Dosyalar/{folder}',
    'Önemli Dosyalar/{folder}',
    'Önemli Dosyalar/{folder}',
  ),

  // ── İndirilenler ekranı ───────────────────────────────────────────────────
  'dls.selected': ('{n} dosya seçildi · ', '{n} files selected · ', 'تم تحديد {n} ملف · '),
  'dls.count_size': ('{n} dosya · {size}', '{n} files · {size}', '{n} ملف · {size}'),
  'dls.untouched': (
    '{n} dosya 6 aydır dokunulmamış · ',
    '{n} files untouched for 6 months · ',
    '{n} ملف لم يُلمس منذ 6 أشهر · ',
  ),
  'dls.last_opened': ('son açılma: {when}', 'last opened: {when}', 'آخر فتح: {when}'),

  // ── Klasör seçici ─────────────────────────────────────────────────────────
  'fp.create_failed': (
    'Klasör oluşturulamadı: {error}',
    'Could not create the folder: {error}',
    'تعذّر إنشاء المجلد: {error}',
  ),
  'fp.no_subfolders': (
    'Bu klasörde alt klasör yok.\n'
        'Aşağıdaki düğmeyle buraya koyabilir ya da üstteki “yeni klasör” ile '
        'bir tane açabilirsiniz.',
    'This folder has no subfolders.\n'
        'Use the button below to put it here, or create one with “new folder” '
        'at the top.',
    'لا توجد مجلدات فرعية داخل هذا المجلد.\n'
        'استخدم الزر بالأسفل لوضعه هنا، أو أنشئ مجلدًا عبر «مجلد جديد» بالأعلى.',
  ),
  'fp.new_folder_default': ('Yeni klasör', 'New folder', 'مجلد جديد'),

  // ── Etiket seçici ─────────────────────────────────────────────────────────
  'tp.new_tag': (
    'Yeni etiket (kişi / grup adı)',
    'New tag (person / group name)',
    'وسم جديد (اسم شخص / مجموعة)',
  ),
  'tp.new_tag_hint': ('Ayşe, İş grubu, Fatura…', 'Alex, Work group, Invoice…', 'أحمد، مجموعة العمل، فاتورة…'),
  'tp.partial': ('{tag} (bazısında)', '{tag} (on some)', '{tag} (على بعضها)'),
  'tp.note': (
    'Etiket dosyanın içine yazılmaz, uygulamanın kendi kaydında durur. Bu '
        'uygulamayla taşıdığında, adını değiştirdiğinde ve çöpten geri '
        'aldığında etiket dosyayla birlikte gider; başka bir uygulamayla '
        'taşırsan gitmez.',
    'The tag is not written inside the file; it lives in this app’s own record. '
        'It follows the file when you move, rename or restore it with this app; '
        'it does not follow if you move it with another app.',
    'لا يُكتب الوسم داخل الملف، بل يبقى في سجل التطبيق نفسه. وهو يتبع الملف عند '
        'نقله أو إعادة تسميته أو استعادته بهذا التطبيق؛ ولا يتبعه إن نقلته '
        'بتطبيق آخر.',
  ),

  // ── Video dönüştürme ──────────────────────────────────────────────────────
  'vt.hw_encoder': ('donanım kodlayıcı', 'hardware encoder', 'مرمّز عتادي'),
  'vt.sw_encoder': ('yazılım kodlayıcı', 'software encoder', 'مرمّز برمجي'),
  'vt.sw_encoder_slow': (
    'yazılım kodlayıcı (yavaş)',
    'software encoder (slow)',
    'مرمّز برمجي (بطيء)',
  ),
  'vt.fallback_engine': (
    'yedek motor (kademeli ölçü)',
    'fallback engine (stepped size)',
    'محرّك احتياطي (مقاس متدرّج)',
  ),
  'vt.fallback_preparing': (
    'yedek motor hazırlanıyor…',
    'preparing the fallback engine…',
    'جارٍ تحضير المحرّك الاحتياطي…',
  ),
  'vt.engine_preparing': ('{engine} hazırlanıyor…', 'preparing the {engine}…', 'جارٍ تحضير {engine}…'),
  'vt.failed': (
    'Video dönüştürülemedi: {error}',
    'Could not convert the video: {error}',
    'تعذّر تحويل الفيديو: {error}',
  ),
  'vt.unreadable_output': (
    'Dönüştürülen video okunamadı (bozuk çıktı) — özgün dosyaya dokunulmadı.',
    'The converted video could not be read (corrupt output) — the original file '
        'was left untouched.',
    'تعذّرت قراءة الفيديو المحوَّل (ناتج تالف) — لم يُمس الملف الأصلي.',
  ),
  'vt.truncated': (
    'Dönüştürme yarıda kalmış: çıktı {out} sn, kaynak {src} sn. Özgün dosyaya '
        'dokunulmadı.',
    'The conversion was cut short: the output is {out} s, the source {src} s. '
        'The original file was left untouched.',
    'انقطع التحويل: الناتج {out} ثانية والمصدر {src} ثانية. لم يُمس الملف الأصلي.',
  ),
  'vt.unsupported': (
    'Video sıkıştırılamadı (biçim desteklenmiyor olabilir).',
    'The video could not be compressed (the format may be unsupported).',
    'تعذّر ضغط الفيديو (قد تكون الصيغة غير مدعومة).',
  ),

  // ── Çöp kutusu ────────────────────────────────────────────────────────────
  'tr.restored': (
    '“{name}” geri yüklendi → {folder}',
    '“{name}” restored → {folder}',
    'تمت استعادة «{name}» ← {folder}',
  ),
  'tr.delete_body': (
    '{n} öğe ({size}) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    '{n} items ({size}) will be deleted permanently. This cannot be undone.',
    'سيتم حذف {n} عنصر ({size}) نهائيًا. لا يمكن التراجع عن ذلك.',
  ),
  'tr.partial': (
    '{n} öğe silindi, {fail} öğe silinemedi: {first}',
    '{n} items deleted, {fail} could not be deleted: {first}',
    'تم حذف {n} عنصر، وتعذّر حذف {fail}: {first}',
  ),
  'tr.cancelled': (
    'Durduruldu — {n} öğe silindi.',
    'Stopped — {n} items deleted.',
    'تم الإيقاف — حُذف {n} عنصر.',
  ),
  'tr.emptied': (
    'Çöp kutusu boşaltıldı · {n} öğe · {size} yer açıldı.',
    'Trash emptied · {n} items · {size} freed.',
    'تم تفريغ سلة المهملات · {n} عنصر · تم تحرير {size}.',
  ),
  'tr.count_size': ('{n} öğe · {size}', '{n} items · {size}', '{n} عنصر · {size}'),

  // ── Ortak sayaçlar ────────────────────────────────────────────────────────
  'count.files': ('{n} dosya', '{n} files', '{n} ملف'),
  'count.files_size': ('{n} dosya · {size}', '{n} files · {size}', '{n} ملف · {size}'),
  'count.of_files': ('{shown} / {total} dosya', '{shown} / {total} files', '{shown} / {total} ملف'),
  'count.more_files': ('… ve {n} dosya daha', '… and {n} more files', '… و{n} ملف آخر'),

  // ── Yer açma (onay ve düğme) ──────────────────────────────────────────────
  'clean.confirm_lead': (
    '{n} öneri · {size} yer açılacak.\n\n',
    '{n} suggestions · {size} will be freed.\n\n',
    '{n} اقتراح · سيتم تحرير {size}.\n\n',
  ),

  // ── Bellek analizi ────────────────────────────────────────────────────────
  'an.trend_days': ('Son {n} günde ', 'In the last {n} days ', 'خلال آخر {n} يومًا '),
  'an.top_growing': (
    'En çok büyüyen: {category} ',
    'Growing fastest: {category} ',
    'الأسرع نموًا: {category} ',
  ),
  'an.volume_usage': (
    '{used} / {total} kullanıldı (%{percent}) · {free} boş',
    '{used} / {total} used ({percent}%) · {free} free',
    '{used} / {total} مستخدَم (%{percent}) · {free} حر',
  ),

  // ── İmza kutusu ───────────────────────────────────────────────────────────
  'sp.draw': ('İmzanızı çizin', 'Draw your signature', 'ارسم توقيعك'),

  // ── Word sayfa görünümü ───────────────────────────────────────────────────
  'dv.too_big': (
    'belge çok büyük ({mb} MB)',
    'the document is too large ({mb} MB)',
    'المستند كبير جدًا ({mb} ميغابايت)',
  ),
  'dv.fallback': (
    'Sayfa görünümü açılamadı: {error}\n\nMetin düzenleyiciye geçiliyor.',
    'Could not open the page view: {error}\n\nSwitching to the text editor.',
    'تعذّر فتح عرض الصفحة: {error}\n\nيجري التحويل إلى محرّر النصوص.',
  ),

  // ── Arşiv parolası ────────────────────────────────────────────────────────
  'ap.title': ('Arşiv parolası', 'Archive password', 'كلمة مرور الأرشيف'),
  'ap.wrong': (
    'Parola yanlış. Tekrar deneyin.',
    'Wrong password. Try again.',
    'كلمة المرور خاطئة. حاول مجددًا.',
  ),
  'ap.body': (
    'Bu arşiv parola korumalı.',
    'This archive is password-protected.',
    'هذا الأرشيف محمي بكلمة مرور.',
  ),

  // ── İş şeridi ─────────────────────────────────────────────────────────────
  'jp.cancel': ('İptal', 'Cancel', 'إلغاء'),
  'jp.show': ('Göster', 'Show', 'عرض'),

  // ── Firebase / giriş ──────────────────────────────────────────────────────
  'fb.sign_in_cancelled': (
    'Google girişi iptal edildi.',
    'Google sign-in was cancelled.',
    'أُلغي تسجيل الدخول عبر Google.',
  ),
  'fb.not_configured': (
    'Firebase yapılandırılmamış. Ayarlar’daki kurulum adımlarını izleyin.',
    'Firebase is not configured. Follow the setup steps in Settings.',
    'لم يُهيّأ Firebase. اتبع خطوات الإعداد في الإعدادات.',
  ),

  // ── İndirme bildirimi ─────────────────────────────────────────────────────
  'dsv.downloading': ('İndiriliyor…', 'Downloading…', 'جارٍ التنزيل…'),
  'dsv.downloaded': ('İndirildi', 'Downloaded', 'تم التنزيل'),
  'dsv.paused': ('Duraklatıldı', 'Paused', 'متوقف مؤقتًا'),
  'dsv.failed': ('İndirilemedi', 'Download failed', 'فشل التنزيل'),
  'dsv.start_failed': (
    'İndirme başlatılamadı',
    'Could not start the download',
    'تعذّر بدء التنزيل',
  ),

  // ── Sunum ─────────────────────────────────────────────────────────────────
  'ss.exit': ('Çık', 'Exit', 'خروج'),
  'ss.step': (
    '{n} / {total}  ·  adım {step}/{max}',
    '{n} / {total}  ·  step {step}/{max}',
    '{n} / {total}  ·  الخطوة {step}/{max}',
  ),
  'ss.no_text': ('(Metin yok)', '(No text)', '(لا يوجد نص)'),

  // ── Kurulu uygulamalar ────────────────────────────────────────────────────
  'ia.permission_hint': (
    'Açılan ayar sayfasından “Dosya Okuyucu”ya izin verip geri dönün, '
        'sonra yenileyin.',
    'Grant permission to “Dosya Okuyucu” on the settings page that opens, come '
        'back, then refresh.',
    'امنح الإذن لـ «Dosya Okuyucu» في صفحة الإعدادات التي تُفتح، ثم عُد وحدّث.',
  ),

  // ── Boyut düşürme işi ─────────────────────────────────────────────────────
  'ra.media_only': (
    'Boyut düşürme yalnız fotoğraf ve videolarda yapılabilir.',
    'Reducing size only works on photos and videos.',
    'تصغير الحجم متاح للصور والفيديوهات فقط.',
  ),
  'ra.job_one': (
    'Boyut düşürülüyor: {name}',
    'Reducing the size of: {name}',
    'جارٍ تصغير حجم: {name}',
  ),
  'ra.job_many': (
    '{n} dosyanın boyutu düşürülüyor',
    'Reducing the size of {n} files',
    'جارٍ تصغير حجم {n} ملف',
  ),
  'ra.already_running': (
    'Bu işlem zaten sürüyor. Durumu alttaki şeritten ya da “İşlemler” '
        'ekranından izleyebilirsin.',
    'This job is already running. You can follow it from the bar below or the '
        '“Jobs” screen.',
    'هذه العملية جارية بالفعل. يمكنك متابعتها من الشريط بالأسفل أو من شاشة '
        '«العمليات».',
  ),
  'ra.queued': (
    'İşlem kuyruğa alındı; süren iş bitince başlayacak. Durumu “İşlemler” '
        'ekranından izleyebilirsin.',
    'The job is queued; it starts when the running one finishes. You can follow '
        'it from the “Jobs” screen.',
    'أُضيفت العملية إلى الطابور؛ وستبدأ عند انتهاء العملية الجارية. يمكنك '
        'متابعتها من شاشة «العمليات».',
  ),
  'ra.started': (
    'İşlem arka planda başladı. Durumu ve oluşan dosyaları alttaki şeritten ya '
        'da “İşlemler” ekranından görebilirsin.',
    'The job started in the background. You can see its status and the files it '
        'creates from the bar below or the “Jobs” screen.',
    'بدأت العملية في الخلفية. يمكنك رؤية حالتها والملفات الناتجة من الشريط '
        'بالأسفل أو من شاشة «العمليات».',
  ),
  'ra.saved_bytes': ('{size} kazanıldı', '{size} saved', 'تم توفير {size}'),
  'ra.no_gain': ('Kazanç olmadı', 'No gain', 'لا مكسب'),
  'ra.saved_into': ('Kaydedildi: {name}', 'Saved to: {name}', 'حُفظ في: {name}'),
  'ra.stopped_at': (
    'durduruldu ({n}/{total})',
    'stopped ({n}/{total})',
    'تم الإيقاف ({n}/{total})',
  ),
  'ra.saved_to': (
    '{n} klasöre kaydedildi',
    'Saved into {n} folders',
    'حُفظت في {n} مجلد',
  ),
  'ra.failed_count': (
    '{n} dosya küçültülemedi',
    '{n} files could not be shrunk',
    'تعذّر تصغير {n} ملف',
  ),
  'ra.originals_trashed': (
    '{n} özgün çöp kutusunda',
    '{n} originals in the trash',
    '{n} ملف أصلي في سلة المهملات',
  ),
  'ra.frame_losing_kept': (
    '{n} hareketli/çok sayfalı dosyanın aslı korundu',
    'the originals of {n} animated/multi-page files were kept',
    'تم الإبقاء على أصول {n} ملف متحرك/متعدد الصفحات',
  ),

  // ── İlerleme penceresi ────────────────────────────────────────────────────
  'pd.preparing': ('Hazırlanıyor…', 'Preparing…', 'جارٍ التحضير…'),
  'pd.cancel': ('İptal', 'Cancel', 'إلغاء'),

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
  // "Uygulamalar" DEĞİL: bu, depolamada bulunan .apk/.bak KURULUM
  // DOSYALARI; yüklü uygulamalar ayrı bir kart. İkisi aynı adı
  // taşıyınca kullanıcı "49 GB mı 85 MB mı" diye takıldı (2026-08-05).
  'enum.cat_apk': (
    'Kurulum dosyaları',
    'Installer files',
    'ملفات التثبيت',
  ),
  'enum.cat_other': ('Diğer', 'Other', 'أخرى'),

  'enum.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'enum.sort_date': ('Tarihe göre', 'By date', 'حسب التاريخ'),
  'enum.sort_size': ('Boyuta göre', 'By size', 'حسب الحجم'),
  'enum.sort_type': ('Türe göre', 'By type', 'حسب النوع'),

  // ── Kağıt teması turu (2026-08-04 tasarım devir notu) ────────────────────
  'fm.search_all': (
    'Tüm dosyalarda ara',
    'Search all files',
    'ابحث في كل الملفات',
  ),
  'fm.free_bytes': ('{v} boş', '{v} free', '{v} متاح'),
  'fm.storage_free': ('Boş', 'Free', 'متاح'),
  'recent.group_today': ('Bugün', 'Today', 'اليوم'),
  'recent.group_week': ('Bu hafta', 'This week', 'هذا الأسبوع'),
  'recent.group_older': ('Daha önce', 'Earlier', 'قبل ذلك'),
  'recent.show_path': ('Yolu göster', 'Show path', 'إظهار المسار'),
  'recent.remove': ('Listeden kaldır', 'Remove from list', 'إزالة من القائمة'),
  'chat.context_badge': ('Bağlam: {f}', 'Context: {f}', 'السياق: {f}'),
  'chat.pick_context': (
    'Bağlam dosyası seç',
    'Choose a context file',
    'اختر ملف السياق',
  ),
  'chat.quick_slides': (
    'Slayt planı çıkar',
    'Draft a slide plan',
    'أعدّ خطة شرائح',
  ),
  'chat.quick_slides_prompt': (
    'Bu içerikten bir sunum planı çıkar: her slayt için kısa bir başlık ve '
        'en fazla üç madde yaz.',
    'Draft a slide plan from this content: a short title and at most three '
        'bullets per slide.',
    'أعدّ خطة عرض تقديمي من هذا المحتوى: عنوان قصير وثلاث نقاط كحد أقصى لكل شريحة.',
  ),
  'cat.summary': (
    '{n} / {total} dosya · {sort}',
    '{n} / {total} files · {sort}',
    '{n} / {total} ملف · {sort}',
  ),
  'trash.auto_days': (
    '{n} gün sonra kendiliğinden silinir',
    'Deleted automatically after {n} days',
    'يُحذف تلقائيًا بعد {n} يومًا',
  ),
  'trash.auto_off': (
    'Otomatik temizleme kapalı',
    'Auto-cleanup is off',
    'التنظيف التلقائي متوقف',
  ),
  'trash.restore_all': ('Tümünü geri yükle', 'Restore all', 'استعادة الكل'),
  'trash.restore_all_done': (
    '{n} öğe geri yüklendi',
    '{n} items restored',
    'تمت استعادة {n} عنصرًا',
  ),
  'jobs.files_progress': (
    '{done}/{total} dosya',
    '{done}/{total} files',
    '{done}/{total} ملف',
  ),
  'jobs.outputs': (
    'Oluşan dosyalar ({n})',
    'Files created ({n})',
    'الملفات الناتجة ({n})',
  ),
  'set.key_valid': (
    'Anahtar geçerli · {n} model bulundu',
    'Key is valid · {n} models found',
    'المفتاح صالح · تم العثور على {n} نموذجًا',
  ),
  'set.key_invalid': (
    'Anahtar doğrulanamadı',
    'Key could not be verified',
    'تعذّر التحقق من المفتاح',
  ),
  'set.search_hint': ('Ayarlarda ara', 'Search settings', 'ابحث في الإعدادات'),
  'set.no_match': (
    'Eşleşen ayar yok',
    'No matching setting',
    'لا توجد إعدادات مطابقة',
  ),

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

  'enum.op_move': ('Taşıma', 'Move', 'نقل'),
  'enum.op_copy': ('Kopyalama', 'Copy', 'نسخ'),
  'enum.op_delete': ('Silme', 'Delete', 'حذف'),
  'enum.op_rename': ('Yeniden adlandırma', 'Rename', 'إعادة تسمية'),
  'enum.op_organize': ('Otomatik düzenleme', 'Auto-organize', 'تنظيم تلقائي'),
};
