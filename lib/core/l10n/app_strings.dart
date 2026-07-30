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
