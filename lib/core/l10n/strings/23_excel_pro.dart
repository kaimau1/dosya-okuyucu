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
};
