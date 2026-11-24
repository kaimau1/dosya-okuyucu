part of '../app_strings.dart';

/// 2026-11-22 — PDF, Word ve Excel düzenleme deneyimi ve görsel tasarım yenilemesi.
const Map<String, (String, String, String)> _t51 = {
  // ── PDF Pro UX ve yeni araç levhaları ──
  'pse.edit_text': ('Metni düzenle', 'Edit text', 'تحرير النص'),
  'pse.style': ('Biçim', 'Style', 'التنسيق'),
  'pse.add_text': ('Metin ekle', 'Add text', 'إضافة نص'),
  'pse.textbox_guide': (
    'Metin eklemek istediğiniz yere dokunun',
    'Tap where you want to add text',
    'اضغط حيث تريد إضافة النص',
  ),
  'pse.lasso_guide': (
    'Seçmek istediğiniz nesnelerin etrafını çizin',
    'Draw around the items to select',
    'ارسم حول العناصر لتحديدها',
  ),
  'pse.draw_guide': (
    '{tool} etkin · 2 parmakla yakınlaştırın',
    '{tool} active · Pinch with 2 fingers to zoom',
    '{tool} نشط · قرّب بإصبعين',
  ),
  'pse.shapes': ('Şekiller', 'Shapes', 'الأشكال'),
  'pse.text_lines': ('Metin çizgisi', 'Text lines', 'خطوط النص'),
  'pse.stroke_title': ('Renk ve kalınlık', 'Color & thickness', 'اللون والسُمك'),
  'pse.stroke_width': ('Çizgi kalınlığı', 'Line thickness', 'سُمك الخط'),
  'pse.stroke_thin': ('İnce', 'Thin', 'رفيع'),
  'pse.stroke_medium': ('Orta', 'Medium', 'متوسط'),
  'pse.stroke_thick': ('Kalın', 'Thick', 'سميك'),
  'pse.stroke_bold': ('Çok kalın', 'Extra thick', 'سميك جدًا'),
  'pse.align_group': (
    'Hizala ve dağıt',
    'Align & distribute',
    'المحاذاة والتوزيع',
  ),
  'pse.order': ('Sıra', 'Order', 'الترتيب'),
  'pse.block_more': ('Blok işlemleri', 'Block actions', 'إجراءات الكتلة'),
  'pse.mode_label_para': ('Kip: Paragraf', 'Mode: Paragraph', 'الوضع: فقرة'),
  'pse.mode_label_line': ('Kip: Satır', 'Mode: Line', 'الوضع: سطر'),
  'pse.style_sheet_title': ('Metin biçimi', 'Text formatting', 'تنسيق النص'),
  'pse.font_size_pt': ('{n} pt', '{n} pt', '{n} ن'),

  // ── Word UX ve kısa etiketler ──
  'word.tbl_row_up_short': ('Satır +↑', 'Row +↑', 'صف +↑'),
  'word.tbl_row_down_short': ('Satır +↓', 'Row +↓', 'صف +↓'),
  'word.tbl_col_left_short': ('Sütun +←', 'Col +←', 'عمود +←'),
  'word.tbl_col_right_short': ('Sütun +→', 'Col +→', 'عمود +→'),
  'word.tbl_del_row_short': ('Satır sil', 'Del row', 'حذف صف'),
  'word.tbl_del_col_short': ('Sütun sil', 'Del col', 'حذف عمود'),
  'word.tbl_del_short': ('Tabloyu sil', 'Del table', 'حذف الجدول'),
  'word.tbl_header_short': ('Başlık', 'Header', 'رأس'),
  'word.tbl_banded_short': ('Şeritli', 'Banded', 'مخطط'),
  'word.color_pick': ('Yazı rengi', 'Text color', 'لون النص'),
  'word.highlight_pick': ('Vurgu rengi', 'Highlight color', 'لون التمييز'),
  'word.search_short': ('Bul', 'Find', 'بحث'),
  'word.words_n': ('{n} sözcük', '{n} words', '{n} كلمة'),

  // ── Excel UX ve kısa etiketler ──
  'word.edit_on_page': ('Sayfada düzenle', 'Edit on page', 'تحرير في الصفحة'),
  'word.review_page': ('Sayfa görünümü', 'Page view', 'عرض الصفحة'),
  'excel.cell_menu': ('Hücre menüsü', 'Cell menu', 'قائمة الخلية'),
  'excel.quick_actions': ('Hızlı işlemler', 'Quick actions', 'إجراءات سريعة'),
  'excel.paste_special_group': ('Özel yapıştır', 'Paste special', 'لصق خاص'),
  'excel.fill_sort_group': ('Doldur ve sırala', 'Fill & sort', 'تعبئة وفرز'),
  'excel.rows_cols_group': ('Satır ve sütun', 'Rows & columns', 'الصفوف والأعمدة'),
  'excel.copied_stat': ('Panoya kopyalandı: {v}', 'Copied: {v}', 'تم النسخ: {v}'),
  'excel.stat_sum_short': ('Toplam: {v}', 'Sum: {v}', 'المجموع: {v}'),
  'excel.stat_avg_short': ('Ortalama: {v}', 'Average: {v}', 'المتوسط: {v}'),
  'excel.stat_count_short': ('Sayı: {v}', 'Count: {v}', 'العدد: {v}'),
  'excel.stat_min_short': ('En küçük: {v}', 'Min: {v}', 'الأدنى: {v}'),
  'excel.stat_max_short': ('En büyük: {v}', 'Max: {v}', 'الأقصى: {v}'),
  'excel.fn_sum_short': ('Toplam', 'Sum', 'مجموع'),
  'excel.sort_asc_short': ('A→Z', 'A→Z', 'أ→ي'),
  'excel.sort_desc_short': ('Z→A', 'Z→A', 'ي→أ'),
  'excel.row_above_short': ('Satır +↑', 'Row +↑', 'صف +↑'),
  'excel.row_below_short': ('Satır +↓', 'Row +↓', 'صف +↓'),
  'excel.col_left_short': ('Sütun +←', 'Col +←', 'عمود +←'),
  'excel.col_right_short': ('Sütun +→', 'Col +→', 'عمود +→'),

  // ── Evrensel menü içi arama (2026-11-24) ──
  'menu.search_hint': (
    'Menüde veya işlevle ara…',
    'Search menu or by action…',
    'ابحث في القائمة أو بالوظيفة…',
  ),
  'menu.search_empty': (
    'Eşleşen işlem bulunamadı',
    'No matching actions found',
    'لم يتم العثور على إجراءات مطابقة',
  ),
  'menu.search_intent': (
    'İşlev eşleşmesi',
    'By function',
    'تطابق وظيفي',
  ),

  // ── Aktar ekranı yenilemesi ──
  'near.clear_sel': ('Temizle', 'Clear', 'مسح'),
  'near.sec_local': (
    'Yerel ağ ve indirilenler',
    'Local network & downloads',
    'الشبكة المحلية والتنزيلات',
  ),
  'near.sec_prefs': (
    'Aktarım ayarları',
    'Transfer preferences',
    'إعدادات النقل',
  ),
  'near.empty_hint': (
    'Karşı cihazda da Aktar ekranını açın (aynı Wi-Fi ya da Bluetooth).',
    'Open Transfer on the other device too (same Wi-Fi or Bluetooth).',
    'افتح شاشة النقل على الجهاز الآخر أيضًا (نفس Wi-Fi أو البلوتوث).',
  ),
  'near.pick_to_link': (
    'Dosya seç ve bağlantı oluştur',
    'Pick files & create link',
    'اختر ملفات وأنشئ رابطًا',
  ),

  // ── PDF / Word / Excel / Slayt düzeni ──
  'pdf.sec_look': ('Görünüm ve düzen', 'Appearance & layout', 'المظهر والتخطيط'),
  'pdf.sec_comfort': ('Okuma konforu', 'Reading comfort', 'راحة القراءة'),
  'pdf.sec_screen': ('Ekran ve kayıt', 'Screen & session', 'الشاشة والجلسة'),
  'pdf.exit_edit': ('Düzenlemeden çık', 'Exit editing', 'إنهاء التحرير'),
  'sl.quick_style': ('Stil', 'Style', 'النمط'),
  'sl.quick_arrange': ('Düzenle', 'Arrange', 'ترتيب'),
  'sl.add_slide_short': ('Slayt', 'Slide', 'شريحة'),
};
