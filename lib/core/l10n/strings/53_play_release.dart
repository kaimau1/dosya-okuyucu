part of '../app_strings.dart';

/// Çeviri tablosunun 53. bölümü: Play çıkışı, PC metin aktarımı, USB/SAF
/// güvenliği, OCR stüdyosu ve sesli kitap motor/konuşma iyileştirmeleri.
const Map<String, (String, String, String)> _t53 = {

  // OCR Stüdyosu (Paket 6)
  'ocr_studio.title': (
    'Metin Tanıma Stüdyosu',
    'Text Recognition Studio',
    'استوديو التعرف على النص',
  ),
  'ocr_studio.quality': (
    'Tanıma Kalitesi',
    'Recognition Quality',
    'جودة التعرف',
  ),
  'ocr_studio.mode_fast': ('Hızlı', 'Fast', 'سريع'),
  'ocr_studio.mode_fast_sub': (
    'Ham görüntü · cihazda hızlı tarama',
    'Raw image · fast on-device scan',
    'صورة خام · مسح سريع على الجهاز',
  ),
  'ocr_studio.mode_enhanced': (
    'Gelişmiş (Taranmış)',
    'Enhanced (Scanned)',
    'محسّن (ممسوح ضوئيًا)',
  ),
  'ocr_studio.mode_enhanced_sub': (
    '2400 px kayıpsız iyileştirme · ışık/gölge düzeltme + paragraf sırası',
    '2400 px lossless enhance · shadow cleanup + paragraph order',
    'تحسين ٢٤٠٠ بكسل دون فقد · إزالة الظلال وترتيب الفقرات',
  ),
  'ocr_studio.mode_ai': (
    'AI Görüş (Gemini)',
    'AI Vision (Gemini)',
    'رؤية الذكاء الاصطناعي (Gemini)',
  ),
  'ocr_studio.mode_ai_sub': (
    'El yazısı, tablo ve karışık sayfalar · kendi Gemini anahtarınızla',
    'Handwriting, tables & complex pages · with your Gemini key',
    'خط اليد والجداول والصفحات المعقدة · بمفتاح Gemini الخاص بك',
  ),
  'ocr_studio.pages': ('Sayfa Kapsamı', 'Page Range', 'نطاق الصفحات'),
  'ocr_studio.pages_current': (
    'Bu sayfa ({n})',
    'Current page ({n})',
    'هذه الصفحة ({n})',
  ),
  'ocr_studio.pages_batch': (
    'İlk {n} sayfa',
    'First {n} pages',
    'أول {n} صفحة',
  ),
  'ocr_studio.pages_custom': (
    'Özel aralık',
    'Custom range',
    'نطاق مخصص',
  ),
  'ocr_studio.range_hint': (
    'Örn: 1-5, 8 (toplam {total} sayfa)',
    'e.g. 1-5, 8 ({total} pages total)',
    'مثال: 1-5, 8 (إجمالي {total} صفحة)',
  ),
  'ocr_studio.range_empty': (
    'Geçerli bir sayfa aralığı girin.',
    'Enter a valid page range.',
    'أدخل نطاق صفحات صالحًا.',
  ),
  'ocr_studio.start': ('Metni Tanı', 'Recognize Text', 'التعرف على النص'),
  'ocr_studio.rescan': ('Yeniden Tara', 'Rescan', 'إعادة المسح'),
  'ocr_studio.progress_page': (
    'Sayfa {done} / {total} taranıyor…',
    'Scanning page {done} / {total}…',
    'جارٍ مسح الصفحة {done} / {total}…',
  ),
  'ocr_studio.all_pages': ('Tümü ({n})', 'All ({n})', 'الكل ({n})'),
  'ocr_studio.page_chip': ('Sayfa {n}', 'Page {n}', 'صفحة {n}'),
  'ocr_studio.preview': (
    'Kaynak önizlemesini göster / gizle',
    'Show / hide source preview',
    'إظهار / إخفاء معاينة المصدر',
  ),
  'ocr_studio.stats': (
    '{words} kelime · {chars} karakter',
    '{words} words · {chars} chars',
    '{words} كلمة · {chars} حرفًا',
  ),
  'ocr_studio.clean': ('Temizle', 'Clean Up', 'تنظيف'),
  'ocr_studio.clean_done': (
    'Türkçe harf, tire ve noktalama düzeltildi.',
    'Letters, hyphens & punctuation fixed.',
    'تم إصلاح الأحرف والواصلات وعلامات الترقيم.',
  ),
  'ocr_studio.ai_fix': ('AI Düzelt', 'AI Fix', 'إصلاح AI'),
  'ocr_studio.ai_done': (
    'Metin kendi Gemini anahtarınızla toparlandı.',
    'Text refined with your Gemini key.',
    'تم تحسين النص بمفتاح Gemini الخاص بك.',
  ),
  'ocr_studio.save_txt': ('TXT Kaydet', 'Save TXT', 'حفظ TXT'),
  'ocr_studio.saved_txt': (
    'Metin kaydedildi: {name}',
    'Saved text: {name}',
    'تم حفظ النص: {name}',
  ),
  'ocr_studio.read': ('Dinle', 'Listen', 'استماع'),
  'ocr_studio.stop_read': ('Durdur', 'Stop', 'إيقاف'),
  'ocr_studio.select_on_image': (
    'Görselde seç',
    'Select on image',
    'تحديد على الصورة',
  ),
  'ocr_studio.empty_result': (
    'Bu sayfalarda okunabilir metin bulunamadı. Gelişmiş veya AI Görüş kipini deneyin.',
    'No readable text found on these pages. Try Enhanced or AI Vision mode.',
    'لم يُعثر على نص مقروء. جرّب الوضع المحسّن أو رؤية AI.',
  ),
  'ocr_studio.editor_hint': (
    'Tanınan metni burada düzenleyebilirsiniz…',
    'Edit recognized text here…',
    'يمكنك تعديل النص هنا…',
  ),

  // Sesli Kitap ve Konuşma Motoru (Paket 7)
  'tts.engine': ('Konuşma Motoru', 'Speech Engine', 'محرك النطق'),
  'tts.engine_default': (
    'Sistem varsayılanı',
    'System default',
    'الافتراضي للنظام',
  ),
  'ab.pro_locked_title': (
    'Sesli Kitap Stüdyosu Pro Özelliğidir',
    'Audiobook Studio is a Pro Feature',
    'استوديو الكتب الصوتية ميزة Pro',
  ),
  'ab.pro_locked_sub': (
    'Belgelerinizi doğal cümle duraklamalı sesli kitaplara (M4A/WAV) dönüştürmek için Pro sürüme geçin.',
    'Upgrade to Pro to convert documents into audiobooks (M4A/WAV) with natural pauses.',
    'قم بالترقية إلى Pro لتحويل مستنداتك إلى كتب صوتية بوقفات طبيعية.',
  ),
  'ab.pro_unlock': (
    'Pro Özellikleri Gör',
    'View Pro Features',
    'عرض ميزات Pro',
  ),
  'ab.engine_section': (
    'Konuşma Motoru ve Sistem Sesi',
    'Speech Engine & System Voice',
    'محرك النطق وصوت النظام',
  ),
  'ab.engine_label': ('TTS Motoru', 'TTS Engine', 'محرك TTS'),
  'ab.system_voice_label': ('Sistem Sesi', 'System Voice', 'صوت النظام'),
  'ab.system_voice_default': (
    'Varsayılan sistem sesi',
    'Default system voice',
    'صوت النظام الافتراضي',
  ),
  'ab.preview': ('Sesi Önizle', 'Preview Voice', 'معاينة الصوت'),
  'ab.preview_sample': (
    'Merhaba. Bu cümle, seçilen ses motoru ve doğal duraklamalarla test edilmektedir.',
    'Hello. This sentence tests the selected voice engine and natural pauses.',
    'مرحبًا. تختبر هذه الجملة محرك الصوت المختار والوقفات الطبيعية.',
  ),
  'ab.clean_section': (
    'Doğal Okuma Temizliği',
    'Natural Speech Cleanup',
    'تنظيف القراءة الطبيعية',
  ),
  'ab.clean_pages': (
    'Sayfa numaralarını ve tekrarlayan üst/alt bilgileri atla',
    'Skip page numbers and repeated headers/footers',
    'تخطي أرقام الصفحات والرؤوس والتذييلات المتكررة',
  ),
  'ab.clean_symbols': (
    'Noktalama, parantez ve bağlantıları doğal okumaya göre sadeleştir',
    'Clean extra symbols, brackets, and URLs for natural speech',
    'تبسيط الرموز والأقواس والروابط للنطق الطبيعي',
  ),
  'ab.clean_abbr': (
    'Kısaltmaları aç (vb., Dr., bkz.)',
    'Expand abbreviations (e.g., Dr., etc.)',
    'توسيع الاختصارات الشائعة',
  ),
  'ab.ai_tidy': (
    'AI ile akıcılaştır (BYOK)',
    'Smooth text with AI (BYOK)',
    'تحسين السلاسة بالذكاء الاصطناعي (BYOK)',
  ),
  'ab.ai_tidy_sub': (
    'Bölüm metnini kendi Gemini anahtarınızla sesli okumaya göre düzenler',
    'Refines chapters for natural speech using your own Gemini key',
    'ينقّح الفصول للقراءة الصوتية بمفتاح Gemini الخاص بك',
  ),
  'set.rate_app': (
    'Uygulamayı değerlendir',
    'Rate the app',
    'قيّم التطبيق',
  ),
  'set.rate_app_sub': (
    'Görüşünüz küçük bir geliştirici ekibine çok yardımcı olur',
    'Your rating helps a small developer team grow',
    'تقييمك يساعد فريق التطوير الصغير كثيرًا',
  ),
  'err.report': (
    'Sorunu bildir',
    'Report issue',
    'الإبلاغ عن مشكلة',
  ),
  'fb.copy': (
    'Metni kopyala',
    'Copy text',
    'نسخ النص',
  ),
  'fb.copied': (
    'Metin panoya kopyalandı',
    'Text copied to clipboard',
    'تم نسخ النص إلى الحافظة',
  ),
  'sm.local_ready_title': (
    'Yerel akıllı düzen hazır (API anahtarı gerekmez)',
    'Local smart sort is ready (no API key needed)',
    'التصنيف الذكي المحلي جاهز (لا يحتاج مفتاح API)',
  ),
  'sm.local_ready_sub': (
    'Fatura, dekont, resmi evrak, sağlık, ekran görüntüsü ve APK dosyaları cihazda ücretsiz ve internetsiz sınıflandırılır. İsteğe bağlı Gemini anahtarıyla belirsiz dosyalar da tanınır.',
    'Invoices, bank receipts, official docs, health records, screenshots and APKs are sorted offline for free. Optional Gemini key classifies ambiguous files too.',
    'تُصنَّف الفواتير والإيصالات والمستندات الرسمية والصحية ولقطات الشاشة وملفات APK محليًا دون إنترنت. يمكن إضافة مفتاح Gemini اختياريًا للملفات غير الواضحة.',
  ),
};
