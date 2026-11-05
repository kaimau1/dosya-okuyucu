part of '../app_strings.dart';

/// 2026-11-05 — Faz 36: Excel pro (özet tablo, koşullu biçim yazma, mini
/// grafik, formül yardımı, tablo nesnesi, yazdırma/koruma, görünüm…).
const Map<String, (String, String, String)> _t23 = {
  // ── Özet tablo ──
  'xp.pivot': ('Özet tablo', 'PivotTable', 'جدول محوري'),
  'xp.pivot_sheet': ('Özet {n}', 'Pivot {n}', 'محوري {n}'),
  'xp.pivot_create': ('Oluştur', 'Create', 'إنشاء'),
  'xp.pivot_refresh': ('Özeti yenile', 'Refresh pivot', 'تحديث الجدول المحوري'),
  'xp.pivot_refreshed': ('Özet tablo yenilendi', 'Pivot refreshed', 'حُدّث الجدول المحوري'),
  'xp.pivot_source_gone': ('Kaynak sayfa yok — yenilenemedi', 'Source sheet is gone — cannot refresh', 'الورقة المصدر غير موجودة — تعذّر التحديث'),
  'xp.grand_total': ('Genel Toplam', 'Grand Total', 'المجموع الكلي'),
  'xp.blank': ('(boş)', '(blank)', '(فارغ)'),
  'xp.none': ('— yok —', '— none —', '— لا شيء —'),
  'xp.rows': ('Satırlar', 'Rows', 'الصفوف'),
  'xp.cols': ('Sütunlar (isteğe bağlı)', 'Columns (optional)', 'الأعمدة (اختياري)'),
  'xp.values': ('Değer', 'Value', 'القيمة'),
  'xp.agg': ('İşlev', 'Function', 'الدالة'),
  'xp.filter': ('Süzgeç (isteğe bağlı)', 'Filter (optional)', 'عامل التصفية (اختياري)'),
  'xp.agg_header': ('{agg}: {field}', '{agg} of {field}', '{agg}: {field}'),
  'xp.agg_sum': ('Topla', 'Sum', 'المجموع'),
  'xp.agg_count': ('Say', 'Count', 'العدد'),
  'xp.agg_average': ('Ortalama', 'Average', 'المتوسط'),
  'xp.agg_min': ('En küçük', 'Min', 'الأدنى'),
  'xp.agg_max': ('En büyük', 'Max', 'الأقصى'),
  // ── Koşullu biçim ──
  'xp.cond_visual': ('Ölçek, çubuk, simge', 'Scales, bars, icons', 'مقاييس وأشرطة ورموز'),
  'xp.scale_rg': ('Renk ölçeği: kırmızı → yeşil', 'Colour scale: red → green', 'مقياس لوني: أحمر ← أخضر'),
  'xp.scale_ryg': ('Renk ölçeği: kırmızı → sarı → yeşil', 'Colour scale: red → yellow → green', 'مقياس لوني: أحمر ← أصفر ← أخضر'),
  'xp.scale_wb': ('Renk ölçeği: beyaz → mavi', 'Colour scale: white → blue', 'مقياس لوني: أبيض ← أزرق'),
  'xp.data_bar': ('Veri çubuğu (mavi)', 'Data bar (blue)', 'شريط بيانات (أزرق)'),
  'xp.data_bar_green': ('Veri çubuğu (yeşil)', 'Data bar (green)', 'شريط بيانات (أخضر)'),
  'xp.icon_set': ('Simge kümesi: trafik ışığı', 'Icon set: traffic lights', 'مجموعة رموز: إشارات المرور'),
  'xp.cond_formula': ('Formülle kural…', 'Rule by formula…', 'قاعدة بصيغة…'),
  'xp.cond_formula_hint': ('{cell} hücresine göre koşul (ör. ={cell}>100)', 'Condition relative to {cell} (e.g. ={cell}>100)', 'شرط نسبةً إلى {cell} (مثل ={cell}>100)'),
  // ── Mini grafik ──
  'xp.sparkline': ('Mini grafik', 'Sparkline', 'خط مؤشر'),
  'xp.sparkline_needs_range': ('Önce bir veri aralığı seç', 'Select a data range first', 'حدّد نطاق بيانات أولًا'),
  'xp.spark_line': ('Çizgi', 'Line', 'خطي'),
  'xp.spark_column': ('Sütun', 'Column', 'عمودي'),
  'xp.spark_stacked': ('Kazanç/kayıp', 'Win/loss', 'ربح/خسارة'),
  'xp.undo_sparkline': ('Mini grafik ekleme', 'Insert sparkline', 'إدراج خط مؤشر'),
};
