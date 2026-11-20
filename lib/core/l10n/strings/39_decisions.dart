part of '../app_strings.dart';

/// Çeviri tablosunun 39. bölümü (2026-11-18): AI ile hızlı kontrol (Gemini
/// Decisions API), Aktar'da yeni dosyalar şeridi ve uygulamalarla paylaş.
const Map<String, (String, String, String)> _t39 = {
  'qc.too_large': (
    'Dosya akıllı işlem için çok büyük (en çok 14 MB).',
    'The file is too large for a smart action (max 14 MB).',
    'الملف كبير جدًا للإجراء الذكي (الحد 14 ميغابايت).',
  ),
  'qc.unsupported': (
    'Akıllı işlemler PDF, görsel, ses, video ve yazı içeren belgelerde çalışır.',
    'Smart actions work on PDFs, images, audio, video and documents with text.',
    'تعمل الإجراءات الذكية على PDF والصور والصوت والفيديو والمستندات النصية.',
  ),
  'qc.scope_off': (
    'Bu dosya akıllı özelliklerin kapsamı dışında (Ayarlar → Yapay zekâ).',
    'This file is outside the scope of smart features (Settings → Artificial intelligence).',
    'هذا الملف خارج نطاق الميزات الذكية (الإعدادات ← الذكاء الاصطناعي).',
  ),
  'fresh.new': ('Yeniler', 'New', 'الجديدة'),
  'near.share_apps': ('Uygulamalarla paylaş', 'Share with apps', 'مشاركة مع التطبيقات'),
  'near.share_no_folder': (
    'Klasörler uygulamalarla paylaşılamaz; içindeki dosyaları seç.',
    'Folders cannot be shared with apps; pick the files inside.',
    'لا يمكن مشاركة المجلدات مع التطبيقات؛ اختر الملفات داخلها.',
  ),
  'ocr.script': ('Metin tanıma dili', 'Text recognition script', 'لغة التعرّف على النص'),
  'ocr.script_auto': ('Otomatik', 'Automatic', 'تلقائي'),
  'ocr.script_auto_sub': (
    'Cihazda tanır; Arapça vb. yazı görürse akıllı okumayla yeniden okur',
    'Recognises on the device; re-reads with smart reading when it sees Arabic etc.',
    'يتعرّف على الجهاز؛ ويعيد القراءة بالقراءة الذكية إذا رأى العربية ونحوها',
  ),
  'ocr.script_latin': ('Yalnız Latin (cihazda)', 'Latin only (on device)', 'اللاتينية فقط (على الجهاز)'),
  'ocr.script_latin_sub': (
    'İnternetsiz, hiçbir şey gönderilmez',
    'Offline, nothing is sent',
    'دون إنترنت، لا يُرسل شيء',
  ),
  'ocr.script_arabic': (
    'Arapça ve diğer alfabeler · akıllı okuma',
    'Arabic and other scripts · smart reading',
    'العربية والأبجديات الأخرى · قراءة ذكية',
  ),
  'ocr.script_arabic_sub': (
    'Görsel Gemini ile okunur; internet ve API anahtarı gerekir',
    'The image is read by Gemini; needs internet and an API key',
    'تُقرأ الصورة بواسطة Gemini؛ يتطلب إنترنت ومفتاح API',
  ),
  'ocr.cloud_need_key': (
    'Arapça metin tanıma akıllı okumayla yapılır: Ayarlar → Yapay zekâ bölümünden Gemini API anahtarı ekle.',
    'Arabic text recognition uses smart reading: add a Gemini API key in Settings → Artificial intelligence.',
    'التعرّف على النص العربي يتم بالقراءة الذكية: أضف مفتاح Gemini API من الإعدادات ← الذكاء الاصطناعي.',
  ),
  'qrimg.title': ('Görseldeki QR', 'QR in the image', 'رمز QR في الصورة'),
  'qrimg.chip': ('QR ({n})', 'QR ({n})', 'QR ({n})'),
  'qrimg.open': ('Bağlantıyı aç', 'Open link', 'افتح الرابط'),
  'qrimg.open_failed': ('Bağlantı açılamadı', 'Could not open the link', 'تعذّر فتح الرابط'),
  'shield.setting': ('Paylaşmadan önce kişisel veri denetimi', 'Check for personal data before sharing', 'فحص البيانات الشخصية قبل المشاركة'),
  'shield.setting_sub': (
    'Paylaşılan görsel ve PDF\'lerde kimlik, TC no, IBAN, sağlık bilgisi varsa uyarır (AI; dosyalar Gemini\'ye gider)',
    'Warns if shared images and PDFs show an ID, ID number, IBAN or health data (AI; files go to Gemini)',
    'ينبّه إذا ظهرت في الصور وملفات PDF المشتركة هوية أو رقم وطني أو IBAN أو بيانات صحية (ذكاء اصطناعي؛ تُرسل الملفات إلى Gemini)',
  ),
  'shield.checking': ('Kişisel veri denetleniyor…', 'Checking for personal data…', 'جارٍ فحص البيانات الشخصية…'),
  'shield.title': ('Kişisel veri olabilir', 'May contain personal data', 'قد يحتوي على بيانات شخصية'),
  'shield.body': (
    'Şu dosyalarda kimlik, iletişim, banka ya da sağlık bilgisi görünüyor:\n{files}\n\nYine de paylaşılsın mı?',
    'These files seem to show identity, contact, bank or health data:\n{files}\n\nShare anyway?',
    'يبدو أن هذه الملفات تُظهر بيانات هوية أو اتصال أو بنك أو صحة:\n{files}\n\nهل تريد المشاركة على أي حال؟',
  ),
  'shield.share_anyway': ('Yine de paylaş', 'Share anyway', 'شارك على أي حال'),
};
