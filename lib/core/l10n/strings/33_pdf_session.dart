part of '../app_strings.dart';

/// Çeviri tablosunun 33. bölümü (2026-11-11): PDF Pro Faz 54 — düzenleme
/// oturumu (tek yüzey), artımlı kayıt, sürüm geçmişi, çökme kurtarma,
/// şifreli belge.
const Map<String, (String, String, String)> _t33 = {
  'pse.editing': ('Düzenleme kipi', 'Editing', 'وضع التحرير'),
  'pse.unsaved_n': (
    'Kaydedilmedi · {n} değişiklik',
    'Not saved · {n} changes',
    'لم يُحفظ · {n} تغييرات',
  ),
  'pse.saved': ('Kaydedildi', 'Saved', 'تم الحفظ'),
  'pse.undo_named': ('Geri al: {name}', 'Undo: {name}', 'تراجع: {name}'),
  'pse.redo_named': ('Yinele: {name}', 'Redo: {name}', 'إعادة: {name}'),
  'pse.step_paragraph': ('Paragraf düzenlendi', 'Paragraph edited', 'تم تحرير الفقرة'),
  'pse.step_detail': ('{name}: “{detail}”', '{name}: “{detail}”', '{name}: «{detail}»'),
  'pse.hint_tap': (
    'Bir paragrafa dokunup seçin; yeniden dokununca olduğu yerde yazarsınız.',
    'Tap a paragraph to select it; tap again to type right on the page.',
    'اضغط على فقرة لتحديدها، ثم اضغط مرة أخرى للكتابة في مكانها.',
  ),
  'pse.edit_title': ('Paragrafı düzenle', 'Edit paragraph', 'تحرير الفقرة'),
  'pse.edit_hint': ('Paragraf metni', 'Paragraph text', 'نص الفقرة'),
  'pse.refused_glyph': (
    'Belgenin yazı tipinde bu harflerin bazıları yok; paragraf değiştirilmedi.',
    "The document's font lacks some of these letters; the paragraph was not changed.",
    'خط المستند لا يحتوي على بعض هذه الأحرف؛ لم تتغير الفقرة.',
  ),
  'pse.refused': (
    'Bu paragraf bu sürümde düzenlenemiyor; belge değiştirilmedi.',
    "This paragraph can't be edited in this version; the document was not changed.",
    'لا يمكن تحرير هذه الفقرة في هذا الإصدار؛ لم يتغير المستند.',
  ),
  'pse.undo_failed': (
    'Geri alınamadı; belge olduğu gibi duruyor.',
    "Couldn't undo; the document is unchanged.",
    'تعذّر التراجع؛ المستند كما هو.',
  ),
  'pse.save_as': ('Farklı kaydet', 'Save as', 'حفظ باسم'),
  'pse.save_as_same': ('Aynı klasöre kopya', 'Copy in the same folder', 'نسخة في المجلد نفسه'),
  'pse.save_as_docs': ("Belgeler'e kopya", 'Copy in Documents', 'نسخة في المستندات'),
  'pse.saved_copy': ('Kopya kaydedildi: {name}', 'Copy saved: {name}', 'تم حفظ النسخة: {name}'),
  'pse.readonly_fallback': (
    "Bu konuma yazılamıyor. Kopya Belgeler'e kaydedildi: {name}",
    "This location can't be written to. A copy was saved in Documents: {name}",
    'لا يمكن الكتابة في هذا الموقع. تم حفظ نسخة في المستندات: {name}',
  ),
  'pse.save_failed': ('Kaydedilemedi: {error}', "Couldn't save: {error}", 'تعذّر الحفظ: {error}'),
  'pse.finish': ('Düzenlemeyi bitir', 'Finish editing', 'إنهاء التحرير'),
  'pse.versions': ('Sürüm geçmişi', 'Version history', 'سجل الإصدارات'),
  'pse.versions_empty': (
    'Henüz saklanan sürüm yok. Kaydettikçe önceki sürümler 14 gün burada tutulur.',
    'No stored versions yet. Each time you save, the previous version is kept here for 14 days.',
    'لا توجد إصدارات محفوظة بعد. عند كل حفظ يُحتفظ بالإصدار السابق هنا لمدة 14 يومًا.',
  ),
  'pse.versions_note': (
    'Önceki sürümler 14 gün saklanır.',
    'Previous versions are kept for 14 days.',
    'يُحتفظ بالإصدارات السابقة لمدة 14 يومًا.',
  ),
  'pse.version_restore': ('Bu sürüme dön', 'Restore this version', 'استعادة هذا الإصدار'),
  'pse.version_restore_q': (
    '{when} tarihli sürüme dönülsün mü? Şimdiki hâl de geçmişe eklenir.',
    'Restore the version from {when}? The current state is added to the history too.',
    'هل تريد استعادة إصدار {when}؟ ستُضاف الحالة الحالية إلى السجل أيضًا.',
  ),
  'pse.version_restore_unsaved': (
    'Kaydedilmemiş değişiklikler bırakılır.',
    'Unsaved changes will be discarded.',
    'سيتم تجاهل التغييرات غير المحفوظة.',
  ),
  'pse.version_restored': ('Önceki sürüme dönüldü', 'Previous version restored', 'تمت استعادة الإصدار السابق'),
  'pse.version_failed': (
    'Sürüme dönülemedi: {error}',
    "Couldn't restore the version: {error}",
    'تعذّرت استعادة الإصدار: {error}',
  ),
  'pse.recover_title': (
    'Kaydedilmemiş düzenlemeler bulundu',
    'Unsaved edits found',
    'تم العثور على تعديلات غير محفوظة',
  ),
  'pse.recover_body': (
    'Uygulama kapanmadan önce bu belgede {n} kaydedilmemiş değişiklik vardı.',
    'This document had {n} unsaved changes when the app closed.',
    'كان في هذا المستند {n} تغييرات غير محفوظة عند إغلاق التطبيق.',
  ),
  'pse.recover_body_copy': (
    'Uygulama kapanmadan önce bu belgede kaydedilmemiş değişiklikler vardı. Belge o zamandan beri değişmiş; düzenlenmiş hâli kopya olarak kurtarılabilir.',
    'This document had unsaved changes when the app closed. The file has changed since, so the edited state can be recovered as a copy.',
    'كان في هذا المستند تغييرات غير محفوظة عند إغلاق التطبيق. تغيّر الملف منذ ذلك الحين، ويمكن استرداد الحالة المعدَّلة كنسخة.',
  ),
  'pse.recover_restore': (
    'Kaydedilmemiş düzenlemeleri geri yükle',
    'Restore unsaved edits',
    'استعادة التعديلات غير المحفوظة',
  ),
  'pse.recover_copy': ('Kurtarılan kopyayı kaydet', 'Save the recovered copy', 'حفظ النسخة المستردة'),
  'pse.recover_discard': ('Sil', 'Discard', 'تجاهل'),
  'pse.recover_done': (
    '{n} değişiklik geri yüklendi (henüz kaydedilmedi)',
    '{n} changes restored (not saved yet)',
    'تمت استعادة {n} تغييرات (لم تُحفظ بعد)',
  ),
  'pse.recover_partial': (
    '{n} / {total} değişiklik geri yüklendi',
    '{n} of {total} changes restored',
    'تمت استعادة {n} من {total} تغييرات',
  ),
  'pse.recover_none': (
    'Düzenlemeler bu belgeye yeniden uygulanamadı.',
    "The edits couldn't be reapplied to this document.",
    'تعذّر إعادة تطبيق التعديلات على هذا المستند.',
  ),
  'pse.locked_title': (
    'Bu belge düzenlemeye karşı korunuyor',
    'This document is protected against editing',
    'هذا المستند محمي من التحرير',
  ),
  'pse.locked_body': (
    'Belgenin sahibi içeriğin değiştirilmesini kısıtlamış. Düzenlemek için sahip parolası gerekir.',
    "The document's owner has restricted changes to its content. Editing requires the owner password.",
    'قيّد مالك المستند تغيير محتواه. يتطلب التحرير كلمة مرور المالك.',
  ),
  'pse.locked_open': ('Sahip parolasıyla aç', 'Unlock with owner password', 'فتح بكلمة مرور المالك'),
  'pse.owner_title': ('Sahip parolası', 'Owner password', 'كلمة مرور المالك'),
  'pse.owner_body': (
    'Düzenleme kısıtlamasını kaldıran parolayı girin.',
    'Enter the password that lifts the editing restriction.',
    'أدخل كلمة المرور التي تزيل قيد التحرير.',
  ),
  'pse.owner_wrong': (
    'Bu parola belgenin sahip parolası değil.',
    "That isn't this document's owner password.",
    'هذه ليست كلمة مرور مالك المستند.',
  ),
};
