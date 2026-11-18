part of '../app_strings.dart';

/// Çeviri tablosunun 43. bölümü (2026-11-18): Akıllı düzen **doğruluk ölçüm
/// tezgâhı** (Geliştirici ayarlarında gizli).
const Map<String, (String, String, String)> _t43 = {
  'sb.title': ('Doğruluk ölçümü', 'Accuracy bench', 'قياس الدقة'),
  'sb.sub': (
    'Akıllı düzenin doğruluğunu kendi dosyalarınla ölç',
    'Measure smart sort accuracy with your own files',
    'قِس دقة الترتيب الذكي بملفاتك',
  ),
  'sb.intro': (
    'En çok {n} dosyayı doğru kategorisiyle etiketle; AI yanıtıyla karşılaştırılır. Etiketler yalnız bu telefonda kalır, rapora dosya adı girmez.',
    'Label up to {n} files with their correct category; they are compared with the AI answer. Labels stay on this phone and the report contains no file names.',
    'صنّف حتى {n} ملف بفئتها الصحيحة؛ تُقارَن بإجابة الذكاء الاصطناعي. تبقى التصنيفات على هذا الهاتف ولا يحتوي التقرير على أسماء الملفات.',
  ),
  'sb.category': ('Kategori', 'Category', 'الفئة'),
  'sb.subtype': ('Alt tür', 'Subtype', 'النوع الفرعي'),
  'sb.date': ('Tarih (ay + yıl)', 'Date (month + year)', 'التاريخ (الشهر + السنة)'),
  'sb.gate': ('kapı {g}', 'gate {g}', 'الحد {g}'),
  'sb.no_data': ('veri yok', 'no data', 'لا بيانات'),
  'sb.measured': (
    '{m} / {n} dosyada AI yanıtı var',
    '{m} of {n} files have an AI answer',
    '{m} من {n} ملف لها إجابة من الذكاء الاصطناعي',
  ),
  'sb.threshold': (
    'Önerilen güven eşiği: {t}',
    'Suggested confidence threshold: {t}',
    'حد الثقة المقترح: {t}',
  ),
  'sb.threshold_none': (
    'Güven eşiği için yeterli doğru yanıt yok',
    'Not enough correct answers to suggest a threshold',
    'لا توجد إجابات صحيحة كافية لاقتراح حد',
  ),
  'sb.ask_missing': ('Eksiklere sor ({n})', 'Ask missing ({n})', 'اسأل عن الناقص ({n})'),
  'sb.ask_all': ('Hepsini yeniden sor', 'Ask all again', 'اسأل عن الكل مجددًا'),
  'sb.asking': ('Soruluyor {done}/{total}', 'Asking {done}/{total}', 'جارٍ السؤال {done}/{total}'),
  'sb.stop': ('Durdur', 'Stop', 'إيقاف'),
  'sb.asked': (
    '{ok} yanıt alındı, {failed} düştü',
    '{ok} answers received, {failed} failed',
    'تم استلام {ok} إجابة، وفشل {failed}',
  ),
  'sb.stopped': ('Durdu: {reason}', 'Stopped: {reason}', 'توقف: {reason}'),
  'sb.add': ('Dosya etiketle', 'Label a file', 'صنّف ملفًا'),
  'sb.full': (
    'En çok {n} dosya etiketlenebilir',
    'You can label at most {n} files',
    'يمكن تصنيف {n} ملف على الأكثر',
  ),
  'sb.labelled': ('Etiketlenenler', 'Labelled', 'المصنّفة'),
  'sb.empty': (
    'Henüz etiket yok. "Dosya etiketle" ile başla.',
    'No labels yet. Start with "Label a file".',
    'لا تصنيفات بعد. ابدأ بـ "صنّف ملفًا".',
  ),
  'sb.pick_title': ('Etiketlenecek dosya', 'File to label', 'الملف المراد تصنيفه'),
  'sb.pick_empty': (
    'Akıllı düzen kapsamında dosya bulunamadı',
    'No files found in the smart sort scope',
    'لم يُعثر على ملفات ضمن نطاق الترتيب الذكي',
  ),
  'sb.row': (
    'Doğru: {truth} · AI: {model}',
    'Correct: {truth} · AI: {model}',
    'الصحيح: {truth} · الذكاء الاصطناعي: {model}',
  ),
  'sb.row_none': ('yanıt yok', 'no answer', 'لا إجابة'),
  'sb.label_title': ('Doğru etiket', 'Correct label', 'التصنيف الصحيح'),
  'sb.sub_skip': ('Puanlama', 'Do not score', 'لا تحتسب'),
  'sb.sub_other': ('Hiçbiri / diğer', 'None / other', 'لا شيء / أخرى'),
  'sb.date_label': ('Belgedeki tarihi puanla', 'Score the document date', 'احتسب تاريخ المستند'),
  'sb.month': ('Ay', 'Month', 'الشهر'),
  'sb.year': ('Yıl', 'Year', 'السنة'),
  'sb.no_date': ('Yok', 'None', 'لا يوجد'),
  'sb.year_none': ('Yok / daha eski', 'None / older', 'لا يوجد / أقدم'),
  'sb.save': ('Kaydet', 'Save', 'حفظ'),
  'sb.remove': ('Etiketi sil', 'Remove label', 'حذف التصنيف'),
  'sb.copy': ('Raporu kopyala', 'Copy report', 'نسخ التقرير'),
  'sb.copied': (
    'Rapor kopyalandı (dosya adı yok)',
    'Report copied (no file names)',
    'تم نسخ التقرير (بلا أسماء ملفات)',
  ),
  'sb.clear': ('Bütün etiketleri sil', 'Delete all labels', 'حذف كل التصنيفات'),
  'sb.clear_ask': (
    'Bütün etiketler silinsin mi? Dosyalara dokunulmaz.',
    'Delete all labels? Your files are not touched.',
    'حذف كل التصنيفات؟ لن تُمَس ملفاتك.',
  ),
};
