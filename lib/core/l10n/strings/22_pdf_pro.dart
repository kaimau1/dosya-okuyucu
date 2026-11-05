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
};
