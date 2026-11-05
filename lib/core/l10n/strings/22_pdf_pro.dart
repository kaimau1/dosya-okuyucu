part of '../app_strings.dart';

/// 2026-11-05 — Faz 39: PDF pro araçları (dijital imza, karartma, dışa
/// aktarım, karşılaştırma, izinler, yer imleri, okuma, sıkıştırma, formlar…).
const Map<String, (String, String, String)> _t22 = {
  'pp.menu': ('Pro araçlar…', 'Pro tools…', 'أدوات احترافية…'),
  'pp.title': ('PDF pro araçları', 'PDF pro tools', 'أدوات PDF الاحترافية'),
  // ── Dijital imza ──
  'pp.dsign': ('Dijital imza (sertifikalı)', 'Digital signature (certificate)', 'توقيع رقمي (شهادة)'),
  'pp.dsign_sub': (
    'PKCS#7 imza; Adobe/Chrome doğrular',
    'PKCS#7 signature; verified by Adobe/Chrome',
    'توقيع PKCS#7؛ يتحقق منه Adobe/Chrome',
  ),
  'pp.dsign_source': ('Sertifika', 'Certificate', 'الشهادة'),
  'pp.dsign_self': ('Uygulama kimliği (öz-imzalı)', 'App identity (self-signed)', 'هوية التطبيق (موقعة ذاتيًا)'),
  'pp.dsign_pfx': ('Sertifika dosyası (.pfx/.p12)', 'Certificate file (.pfx/.p12)', 'ملف شهادة (.pfx/.p12)'),
  'pp.dsign_name': ('İmzalayan adı', 'Signer name', 'اسم الموقّع'),
  'pp.dsign_reason': ('Neden (isteğe bağlı)', 'Reason (optional)', 'السبب (اختياري)'),
  'pp.dsign_location': ('Yer (isteğe bağlı)', 'Location (optional)', 'المكان (اختياري)'),
  'pp.dsign_visible': ('Görünür imza kutusu', 'Visible signature box', 'مربع توقيع مرئي'),
  'pp.dsign_last_page': ('Son sayfaya koy', 'Place on last page', 'ضع في الصفحة الأخيرة'),
  'pp.dsign_go': ('İmzala', 'Sign', 'وقّع'),
  'pp.dsign_working': ('Dijital imza', 'Digital signature', 'توقيع رقمي'),
  'pp.dsign_creating': ('İmza anahtarı üretiliyor', 'Creating signing key', 'جارٍ إنشاء مفتاح التوقيع'),
  'pp.dsign_pfx_password': ('Sertifika parolası', 'Certificate password', 'كلمة مرور الشهادة'),
  'pp.dsign_done': (
    'İmzalandı. Kaydetmeden başka değişiklik yapma — imzayı geçersiz kılar.',
    'Signed. Make no other change before saving — it would invalidate the signature.',
    'تم التوقيع. لا تُجرِ أي تعديل قبل الحفظ — فذلك يُبطل التوقيع.',
  ),
  'pp.dsign_list': ('İmzalar', 'Signatures', 'التوقيعات'),
  'pp.dsign_none': ('Belgede imza yok', 'The document has no signatures', 'لا توجد توقيعات في المستند'),
  'pp.dsign_signed': ('İmzalı', 'Signed', 'موقّع'),
  'pp.dsign_empty_field': ('Boş imza alanı', 'Empty signature field', 'حقل توقيع فارغ'),
  'pp.dsign_export_cert': ('Sertifikamı paylaş (.cer)', 'Share my certificate (.cer)', 'شارك شهادتي (.cer)'),
  'pp.dsign_name_needed': ('İmzalayan adı gerekli', 'Signer name is required', 'اسم الموقّع مطلوب'),
  // ── Bölge işaretleme ──
  'pp.region_title': ('Bölge seç', 'Select area', 'اختر منطقة'),
  'pp.region_hint': (
    'Sürükleyerek kutu çiz; kutuya dokun → sil',
    'Drag to draw a box; tap a box to remove it',
    'اسحب لرسم مربع؛ انقر على مربع لحذفه',
  ),
  'pp.region_hint_crop': (
    'Kalacak alanı sürükleyerek çiz',
    'Drag to draw the area to keep',
    'اسحب لرسم المنطقة التي ستبقى',
  ),
  'pp.region_status': ('Sayfa {page}/{count} · {n} kutu', 'Page {page}/{count} · {n} boxes', 'الصفحة {page}/{count} · {n} مربع'),
  'pp.prev_page': ('Önceki sayfa', 'Previous page', 'الصفحة السابقة'),
  'pp.next_page': ('Sonraki sayfa', 'Next page', 'الصفحة التالية'),
  // ── Karartma ──
  'pp.redact': ('Kalıcı karartma', 'Permanent redaction', 'تنقيح دائم'),
  'pp.redact_sub': (
    'Metni ve görüntüyü gerçekten siler',
    'Really removes the text and image',
    'يحذف النص والصورة فعليًا',
  ),
  'pp.redact_terms_hint': (
    'Aranacak ifadeler (virgülle) — boş: elle işaretle',
    'Terms to find (comma separated) — empty: mark by hand',
    'عبارات للبحث (مفصولة بفواصل) — فارغ: حدّد يدويًا',
  ),
  'pp.redact_find': ('Bul', 'Find', 'بحث'),
  'pp.redact_searching': ('Aranıyor', 'Searching', 'جارٍ البحث'),
  'pp.redact_no_match': ('Eşleşme yok — elle işaretleyebilirsin', 'No matches — you can mark by hand', 'لا تطابق — يمكنك التحديد يدويًا'),
  'pp.redact_confirm': (
    '{pages} sayfada {n} alan kalıcı olarak silinecek. Bu sayfalar görüntüye dönüşür (kutu dışı metin aranabilir kalır); açıklamalar, formlar ve parola kaldırılır. Geri alma yalnız kaydetmeden önce.',
    '{n} areas on {pages} pages will be removed permanently. These pages become images (text outside boxes stays searchable); annotations, forms and the password are removed. Undo works only before saving.',
    'سيُحذف {n} منطقة في {pages} صفحة نهائيًا. تتحول هذه الصفحات إلى صور (يبقى النص خارج المربعات قابلاً للبحث)؛ تُزال التعليقات والنماذج وكلمة المرور. التراجع ممكن قبل الحفظ فقط.',
  ),
  'pp.redact_apply': ('Karart', 'Redact', 'نقّح'),
  'pp.redact_done': (
    'Karartıldı ve doğrulandı: kutularda metin kalmadı.',
    'Redacted and verified: no text left inside the boxes.',
    'تم التنقيح والتحقق: لم يبقَ نص داخل المربعات.',
  ),
  // ── Dışa aktarım ──
  'pp.saved_as': ('Kaydedildi: {name}', 'Saved: {name}', 'حُفظ: {name}'),
  'pp.sheet_prefix': ('Sayfa', 'Page', 'صفحة'),
  'pp.to_xlsx': ('Tabloları Excel\'e aktar', 'Export tables to Excel', 'تصدير الجداول إلى Excel'),
  'pp.to_xlsx_sub': (
    'Satır/sütun algılanır; seçili sayfalar ya da tümü',
    'Rows/columns detected; selected pages or all',
    'تُكتشف الصفوف/الأعمدة؛ الصفحات المحددة أو الكل',
  ),
  'pp.to_docx': ('Word\'e aktar (düzen korunur)', 'Export to Word (keep layout)', 'تصدير إلى Word (مع الحفاظ على التخطيط)'),
  'pp.to_docx_sub': (
    'Satırlar, girinti, punto ve sayfa sonları',
    'Lines, indents, font sizes and page breaks',
    'الأسطر والمسافات البادئة والأحجام وفواصل الصفحات',
  ),
  'pp.pdfa': ('PDF/A olarak kaydet', 'Save as PDF/A', 'حفظ كـ PDF/A'),
  'pp.pdfa_sub': ('Uzun süreli arşiv (PDF/A-2b)', 'Long-term archive (PDF/A-2b)', 'أرشيف طويل الأمد (PDF/A-2b)'),
  'pp.pdfa_vector': ('Metin ve çizimler korunsun', 'Keep text and vectors', 'الحفاظ على النص والرسوم'),
  'pp.pdfa_vector_sub': (
    'Küçük dosya; kaynakta gömülmemiş yazı tipi varsa tam uyum garanti değil',
    'Small file; full compliance not guaranteed if the source has non-embedded fonts',
    'ملف صغير؛ لا يُضمن التوافق الكامل إن وُجدت خطوط غير مضمّنة',
  ),
  'pp.pdfa_image': ('Görüntü + aranabilir metin', 'Image + searchable text', 'صورة + نص قابل للبحث'),
  'pp.pdfa_image_sub': (
    'Her sayfa görüntü olur; uyum en güvenli, dosya büyür',
    'Each page becomes an image; safest compliance, larger file',
    'تصبح كل صفحة صورة؛ أكثر توافقًا وأكبر حجمًا',
  ),
  'pp.too_many_pages': (
    'En çok {n} sayfa — önce sayfa seç ya da böl',
    'At most {n} pages — select pages or split first',
    'بحد أقصى {n} صفحة — حدّد صفحات أو قسّم أولًا',
  ),
};
