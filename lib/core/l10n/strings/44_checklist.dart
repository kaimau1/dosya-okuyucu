part of '../app_strings.dart';

/// Çeviri tablosunun 44. bölümü (2026-11-19, B2 dilim 3): AI kontrol
/// listeleri (evrak listesi → ✓/✗ + güven, eksik evrak, PDF rapor).
const Map<String, (String, String, String)> _t44 = {
  'ckl.action': ('Kontrol listesi', 'Checklist', 'قائمة التحقق'),
  'ckl.action_hint': (
    'Vize, kira, iş başvurusu… eksik evrak var mı?',
    'Visa, rental, job application… anything missing?',
    'تأشيرة، إيجار، طلب عمل… هل هناك مستند ناقص؟',
  ),
  'ckl.title': ('Kontrol listesi ({n} dosya)', 'Checklist ({n} files)', 'قائمة التحقق ({n} ملفات)'),
  'ckl.intro': (
    'Bir liste seçin; her madde dosyalarda aranır.',
    'Pick a list; each item is looked for in the files.',
    'اختر قائمة؛ يُبحث عن كل بند في الملفات.',
  ),
  'ckl.new': ('Yeni liste', 'New list', 'قائمة جديدة'),
  'ckl.new_name': ('Liste adı', 'List name', 'اسم القائمة'),
  'ckl.new_items': (
    'Evraklar (her satıra bir tane)',
    'Documents (one per line)',
    'المستندات (واحد في كل سطر)',
  ),
  'ckl.delete': ('Listeyi sil', 'Delete list', 'حذف القائمة'),
  'ckl.run': ('Kontrol et', 'Check', 'تحقّق'),
  'ckl.progress': ('{done}/{total} dosya', '{done}/{total} files', '{done}/{total} ملفات'),
  'ckl.summary': ('{ok}/{total} madde tamam', '{ok}/{total} items present', '{ok}/{total} بنود موجودة'),
  'ckl.missing': ('Eksik evrak ({n})', 'Missing documents ({n})', 'مستندات ناقصة ({n})'),
  'ckl.all_ok': ('Eksik evrak yok', 'Nothing missing', 'لا يوجد نقص'),
  'ckl.found': ('VAR', 'FOUND', 'موجود'),
  'ckl.absent': ('EKSİK', 'MISSING', 'ناقص'),
  'ckl.share_pdf': ('PDF rapor paylaş', 'Share PDF report', 'مشاركة تقرير PDF'),
  'ckl.report_meta': (
    '{n} dosya incelendi · {date}',
    '{n} files checked · {date}',
    'تم فحص {n} ملفات · {date}',
  ),
  'ckl.no_files': ('Kontrol edilecek dosya yok', 'No files to check', 'لا توجد ملفات للتحقق'),
  // Ayıkla 2: WhatsApp'ta aynı görselin iletilen kopyaları.
  'sm.r_wa_copy': ('WhatsApp kopyası', 'WhatsApp copy', 'نسخة واتساب'),
  'ckl.p_visa': ('Vize dosyası', 'Visa application', 'ملف التأشيرة'),
  'ckl.p_visa_items': (
    'Pasaport|Biyometrik fotoğraf|Banka hesap dökümü|Seyahat sağlık sigortası|Otel ya da konaklama rezervasyonu|Uçak bileti rezervasyonu|İşveren ya da okul yazısı',
    'Passport|Biometric photo|Bank statement|Travel health insurance|Hotel or accommodation booking|Flight reservation|Employer or school letter',
    'جواز السفر|صورة بيومترية|كشف حساب بنكي|تأمين صحي للسفر|حجز فندق أو إقامة|حجز تذكرة طيران|خطاب من جهة العمل أو المدرسة',
  ),
  'ckl.p_rent': ('Kira sözleşmesi', 'Rental agreement', 'عقد الإيجار'),
  'ckl.p_rent_items': (
    'Kira sözleşmesi|Kimlik kartı|Kefil belgesi|Depozito ödeme dekontu|Tapu ya da mülk sahibi belgesi|Demirbaş listesi',
    'Rental contract|ID card|Guarantor document|Deposit payment receipt|Title deed or proof of ownership|Inventory list',
    'عقد الإيجار|بطاقة الهوية|وثيقة الكفيل|إيصال دفع التأمين|سند الملكية أو إثبات المالك|قائمة المحتويات',
  ),
  'ckl.p_rx': ('Reçete', 'Prescription', 'الوصفة الطبية'),
  'ckl.p_rx_items': (
    'Reçete|Doktor imzası ya da kaşesi|İlaç adı ve dozu|Reçete tarihi',
    'Prescription|Doctor signature or stamp|Medicine name and dose|Prescription date',
    'الوصفة الطبية|توقيع الطبيب أو ختمه|اسم الدواء والجرعة|تاريخ الوصفة',
  ),
  'ckl.p_discharge': ('Epikriz', 'Discharge summary', 'ملخص الخروج'),
  'ckl.p_discharge_items': (
    'Epikriz raporu|Tahlil sonuçları|Görüntüleme raporu|Taburcu ilaç listesi|Kontrol randevusu',
    'Discharge summary|Lab results|Imaging report|Discharge medication list|Follow-up appointment',
    'تقرير الخروج|نتائج التحاليل|تقرير الأشعة|قائمة أدوية الخروج|موعد المتابعة',
  ),
  'ckl.p_job': ('İş başvurusu', 'Job application', 'طلب عمل'),
  'ckl.p_job_items': (
    'Özgeçmiş|Ön yazı|Diploma|Referans mektubu|Sertifikalar|Kimlik kartı',
    'CV|Cover letter|Diploma|Reference letter|Certificates|ID card',
    'السيرة الذاتية|خطاب التقديم|الشهادة الجامعية|خطاب توصية|الشهادات|بطاقة الهوية',
  ),
};
