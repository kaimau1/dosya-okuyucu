part of '../app_strings.dart';

/// 2026-11-21 — PDF kayıt/düzenleme & Excel performans/doğrulama düzeltmeleri.
const Map<String, (String, String, String)> _t49 = {
  // ── PDF etkinlik özetleri ("Üretilenler") ──
  'ps.act_edited': ('Düzenlendi', 'Edited', 'تم التعديل'),
  'ps.act_form': ('Form dolduruldu', 'Form filled', 'تم ملء النموذج'),
  'ps.act_signed': ('İmzalandı', 'Signed', 'تم التوقيع'),
  'ps.act_ink': ('Çizim eklendi', 'Drawing added', 'تمت إضافة رسم'),
  'ps.act_translated': ('Çevrildi', 'Translated', 'تمت الترجمة'),

  // ── PDF çıkış onayı (Form / Sayfa Stüdyosu) ──
  'pdf.discard_title': ('Değişikliklerden çıkılsın mı?', 'Discard changes?', 'هل تريد تجاهل التغييرات؟'),
  'pdf.discard_body': ('Kaydedilmemiş değişiklikleriniz kaybolacak.', 'Your unsaved changes will be lost.', 'ستفقد التغييرات غير المحفوظة.'),
  'pdf.discard_confirm': ('Çık', 'Leave', 'مغادرة'),

  // ── Excel Veri Doğrulama giriş iletisi & sınır denetimi ──
  'excel.val_prompt_title': ('Giriş iletisi başlığı (isteğe bağlı)', 'Input message title (optional)', 'عنوان رسالة الإدخال (اختياري)'),
  'excel.val_prompt': ('Giriş iletisi (isteğe bağlı)', 'Input message (optional)', 'رسالة الإدخال (اختياري)'),
  'excel.val_bad_bound': ('Geçerli bir sınır değeri girin', 'Enter a valid bound value', 'أدخل قيمة حد صالحة'),
  'excel.act_saved': ('Düzenlendi', 'Edited', 'تم التعديل'),
};
