part of '../app_strings.dart';

/// Çeviri tablosunun 41. bölümü (2026-11-18): ana ekran araçları, Kitaplık'ta
/// sesli kitaplar, "Görselde ne var?" (AI kısa özeti), akıllı klasör düzeni
/// (ad · sıra · sütun) ve Akıllı düzenin öğrenmesi ("Ne olmalıydı?").
const Map<String, (String, String, String)> _t41 = {
  // Ana ekran araçları.
  'tools.dupes': ('Kopyalar', 'Duplicates', 'المكررات'),

  // Kitaplık.
  'lib.audiobooks_sub': (
    'Belgelerden yapılan sesli kitapları dinle',
    'Listen to audiobooks made from your documents',
    'استمع إلى الكتب الصوتية المصنوعة من مستنداتك',
  ),

  // Görselde ne var?
  'iin.ai_title': ('AI kısa özeti', 'AI summary', 'ملخص الذكاء الاصطناعي'),
  'iin.ai_working': (
    'AI görsele bakıyor…',
    'AI is looking at the image…',
    'الذكاء الاصطناعي يفحص الصورة…',
  ),
  'iin.ai_offer': (
    'Görselde ne olduğunu iki cümleyle anlatsın mı?',
    'Get a two-sentence description of the image?',
    'هل تريد وصفًا للصورة في جملتين؟',
  ),
  'iin.ai_run': ('AI ile özetle', 'Summarize with AI', 'لخّص بالذكاء الاصطناعي'),
  'iin.ai_blocked': (
    'Bu klasör AI kapsamı dışında; görsel gönderilmedi.',
    'This folder is outside the AI scope; the image was not sent.',
    'هذا المجلد خارج نطاق الذكاء الاصطناعي؛ لم تُرسل الصورة.',
  ),
  'iin.ai_offline': (
    'Çevrimdışı kip açık; AI özeti yapılmadı.',
    'Offline mode is on; no AI summary.',
    'وضع عدم الاتصال مفعّل؛ لا يوجد ملخص.',
  ),
  'iin.ai_empty': (
    'AI bir açıklama veremedi.',
    'AI could not describe this image.',
    'تعذّر على الذكاء الاصطناعي وصف الصورة.',
  ),
  'iin.lines': ('{n} satır yazı', '{n} lines of text', '{n} سطر نص'),
  'iin.text_title': ('Görseldeki yazı', 'Text in the image', 'النص في الصورة'),
  'iin.copied': ('Kopyalandı', 'Copied', 'تم النسخ'),

  // Akıllı klasör düzeni.
  'smo.hint': (
    'Basılı tut: ad ve sıra · İki parmakla sıkıştır: sütun sayısı',
    'Long-press: name and order · Pinch: number of columns',
    'اضغط مطولًا: الاسم والترتيب · قرّب بإصبعين: عدد الأعمدة',
  ),
  'smo.layout': ('Düzen', 'Layout', 'التخطيط'),
  'smo.cols': ('{n} sütun', '{n} columns', '{n} أعمدة'),
  'smo.arrange': ('Sırala ve adlandır', 'Reorder and rename', 'الترتيب وإعادة التسمية'),
  'smo.arrange_sub': (
    'Tutamaçtan sürükle, kalemle adını değiştir',
    'Drag by the handle, tap the pencil to rename',
    'اسحب من المقبض، واضغط القلم لإعادة التسمية',
  ),
  'smo.reset': ('Adları ve sırayı sıfırla', 'Reset names and order', 'إعادة تعيين الأسماء والترتيب'),
  'smo.rename': ('Yeniden adlandır', 'Rename', 'إعادة التسمية'),
  'smo.rename_title': ('Klasörün adı', 'Folder name', 'اسم المجلد'),
  'smo.rename_label': (
    'Asıl adı: {name}',
    'Original name: {name}',
    'الاسم الأصلي: {name}',
  ),
  'smo.move_first': ('En başa al', 'Move to the top', 'انقل إلى البداية'),
  'smo.default_name': ('Adı "{name}" yap', 'Rename to "{name}"', 'أعد الاسم إلى "{name}"'),
  'smo.learn_title': ('Öğrenme', 'Learning', 'التعلّم'),
  'smo.learn_none': (
    'Yanlış düzenlenen dosyada ⋮ → "Kategori yanlış mı?" de; benzer dosyalarda aynı hatayı yapmaz.',
    'On a wrongly sorted file tap ⋮ → "Wrong category?"; similar files will not get the same mistake.',
    'في ملف مصنّف خطأً اضغط ⋮ ← "تصنيف خاطئ؟"؛ لن يتكرر الخطأ في الملفات المشابهة.',
  ),
  'smo.learn_n': (
    '{n} düzeltmeden öğrendi',
    'Learned from {n} corrections',
    'تعلّم من {n} تصحيح',
  ),
  'smo.learn_reset': ('Sıfırla', 'Reset', 'إعادة تعيين'),
  'smo.learn_reset_title': ('Öğrenilenler silinsin mi?', 'Forget what was learned?', 'نسيان ما تم تعلّمه؟'),
  'smo.learn_reset_body': (
    'Düzelttiğin dosyalar düzeltilmiş kalır; yalnız yeni dosyalara uygulanan öğrenme silinir.',
    'Files you corrected stay corrected; only the learning applied to new files is removed.',
    'تبقى الملفات التي صححتها كما هي؛ يُحذف فقط التعلّم المطبّق على الملفات الجديدة.',
  ),

  // Ne olmalıydı?
  'smf.action': ('Kategori yanlış mı?', 'Wrong category?', 'تصنيف خاطئ؟'),
  'smf.action_hint': ('şimdi: {cat}', 'now: {cat}', 'الآن: {cat}'),
  'smf.title': ('Ne olmalıydı?', 'What should it be?', 'ماذا يجب أن يكون؟'),
  'smf.now': (
    'Akıllı düzen "{cat}" dedi',
    'Smart sort said "{cat}"',
    'قال الترتيب الذكي "{cat}"',
  ),
  'smf.body': (
    'Doğrusunu seç: dosya oraya geçer ve Akıllı düzen bunu öğrenir — benzer dosyalarda aynı hatayı yapmaz.',
    'Pick the right one: the file moves there and Smart sort learns it, so similar files will not get the same mistake.',
    'اختر الصحيح: ينتقل الملف إليه ويتعلّم الترتيب الذكي ذلك فلا يتكرر الخطأ في الملفات المشابهة.',
  ),
  'smf.docs': ('Belge', 'Document', 'مستند'),
  'smf.images': ('Görsel', 'Image', 'صورة'),
  'smf.was_right': ('Aslında doğruymuş', 'It was right', 'كان صحيحًا'),
  'smf.kept': (
    'Tamam, doğru kabul edildi',
    'OK, marked as correct',
    'حسنًا، اعتُبر صحيحًا',
  ),
  'smf.learned': (
    'Öğrendim: "{cat}" olarak düzeltildi',
    'Learned: corrected to "{cat}"',
    'تعلّمت: صُحّح إلى "{cat}"',
  ),
  'smf.learned_n': (
    'Öğrendim: bu dosya ve benzer {n} dosya "{cat}" oldu',
    'Learned: this file and {n} similar files are now "{cat}"',
    'تعلّمت: هذا الملف و{n} ملفات مشابهة أصبحت "{cat}"',
  ),
  'smf.similar_title': ('Benzerleri de düzeltilsin mi?', 'Fix similar files too?', 'تصحيح الملفات المشابهة أيضًا؟'),
  'smf.similar_body': (
    'Buna benzeyen {n} dosya da "{from}" olarak düzenlenmiş. Onlar da "{to}" olsun mu?',
    '{n} similar files were also sorted as "{from}". Make them "{to}" too?',
    '{n} ملفات مشابهة صُنّفت أيضًا "{from}". هل تجعلها "{to}" أيضًا؟',
  ),
  'smf.similar_go': ('Evet, düzelt', 'Yes, fix them', 'نعم، صحّحها'),
  'smf.list_hint': (
    'Yanlış duran dosya mı var? ⋮ menüsü → "Kategori yanlış mı?" — Akıllı düzen öğrenir.',
    'A file in the wrong place? ⋮ menu → "Wrong category?" — Smart sort learns.',
    'ملف في غير مكانه؟ القائمة ⋮ ← "تصنيف خاطئ؟" — يتعلّم الترتيب الذكي.',
  ),
};
