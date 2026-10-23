part of '../app_strings.dart';

/// Çeviri tablosunun 14. bölümü (2026-10-23): düzenleme turu (Faz 20–26) —
/// ortak düzenleme çekirdeği (kaydetme durumu, taslak, çıkış sorusu, klavye
/// üstü çubuk, biçim paneli), Word canlı düzenleme, Excel veri girişi.
const Map<String, (String, String, String)> _t14 = {
  // ── Ortak çekirdek (Faz 20) ──────────────────────────────────────────────
  'edit.unsaved_title': (
    'Değişiklikler kaydedilsin mi?',
    'Save your changes?',
    'هل تريد حفظ التغييرات؟',
  ),
  'edit.unsaved_body': (
    'Bu belgede kaydedilmemiş değişiklikler var. Kaydetmeden çıkarsanız kaybolur.',
    'This document has unsaved changes. They will be lost if you leave without saving.',
    'يحتوي هذا المستند على تغييرات غير محفوظة. ستفقد إذا خرجت دون حفظ.',
  ),
  'edit.dont_save': ('Kaydetme', "Don't save", 'عدم الحفظ'),
  'edit.saving': ('Kaydediliyor…', 'Saving…', 'جارٍ الحفظ…'),
  'edit.saved_at': ('Kaydedildi {time}', 'Saved {time}', 'تم الحفظ {time}'),
  'edit.save_failed_short': ('Kaydedilemedi', 'Not saved', 'تعذر الحفظ'),
  'edit.changed_elsewhere': (
    'Dosya başka yerde değişti',
    'File changed elsewhere',
    'تغيّر الملف في مكان آخر',
  ),
  'edit.draft_found': (
    'Kaydedilmemiş değişiklikler bulundu ({time})',
    'Unsaved changes found ({time})',
    'تم العثور على تغييرات غير محفوظة ({time})',
  ),
  'edit.draft_restore': ('Geri yükle', 'Restore', 'استعادة'),
  'edit.draft_discard': ('Sil', 'Discard', 'حذف'),
  'edit.draft_restored': (
    'Kaydedilmemiş değişiklikler geri yüklendi',
    'Unsaved changes restored',
    'تمت استعادة التغييرات غير المحفوظة',
  ),
  'edit.autosave': ('Otomatik kaydet', 'AutoSave', 'حفظ تلقائي'),
  'edit.autosave_sub': (
    'Değişiklikler birkaç saniye içinde dosyaya yazılır. Taslak her zaman tutulur.',
    'Changes are written to the file within seconds. A draft is always kept.',
    'تُكتب التغييرات في الملف خلال ثوانٍ. تُحفظ مسودة دائماً.',
  ),
  'edit.autosave_doc': (
    'Bu belgede otomatik kaydet',
    'AutoSave this document',
    'حفظ هذا المستند تلقائياً',
  ),
  'edit.typing': ('Yazma', 'Typing', 'كتابة'),
  'edit.format_panel': ('Biçim', 'Format', 'تنسيق'),
  'edit.show_keyboard': ('Klavye', 'Keyboard', 'لوحة المفاتيح'),
  'edit.hide_keyboard': ('Klavyeyi gizle', 'Hide keyboard', 'إخفاء لوحة المفاتيح'),
  'edit.tab_text': ('Yazı', 'Text', 'النص'),
  'edit.tab_paragraph': ('Paragraf', 'Paragraph', 'الفقرة'),
  'edit.tab_styles': ('Stiller', 'Styles', 'الأنماط'),
  'edit.perf_overlay': (
    'Düzenleme gecikme sayacı',
    'Editing latency counter',
    'عداد تأخر التحرير',
  ),
  'edit.perf_overlay_sub': (
    'Tuştan ekrana süreyi köşede gösterir (geliştirici)',
    'Shows key-to-screen time in the corner (developer)',
    'يعرض زمن المفتاح إلى الشاشة في الزاوية (للمطور)',
  ),
  'set.sec_documents': ('Belgeler', 'Documents', 'المستندات'),
  'common.strike': ('Üstü çizili', 'Strikethrough', 'يتوسطه خط'),
  'common.redo_short': ('Yinele', 'Redo', 'إعادة'),
  // ── Word (Faz 21) ─────────────────────────────────────────────────────────
  'word.spellcheck': (
    'Word: yazım denetimi ve otomatik düzeltme',
    'Word: spell check and autocorrect',
    'Word: التدقيق الإملائي والتصحيح التلقائي',
  ),
  'word.spellcheck_sub': (
    'Kırmızı dalgalı çizgi, klavye önerileri, cümle başı büyük harf',
    'Red squiggles, keyboard suggestions, sentence capitalisation',
    'خط متعرج أحمر واقتراحات لوحة المفاتيح وأحرف كبيرة في بداية الجملة',
  ),
  'word.align_cycle': ('Hizalama', 'Alignment', 'المحاذاة'),
  'common.paste': ('Yapıştır', 'Paste', 'لصق'),
  // ── Deneme: yeni Word editörü (Faz 21b / K18) ────────────────────────────
  'lab.word_flag': (
    'Yeni Word editörü (deneme)',
    'New Word editor (experiment)',
    'محرر Word الجديد (تجريبي)',
  ),
  'lab.word_flag_sub': (
    'Word ⋮ menüsünde ince çekirdekli yazma denemesi — kaydetmez',
    'Thin-core typing trial in the Word ⋮ menu — does not save',
    'تجربة كتابة بنواة خفيفة في قائمة Word ⋮ — لا تحفظ',
  ),
  'lab.word_open': (
    'Yeni editörde dene',
    'Try in new editor',
    'جرّب في المحرر الجديد',
  ),
  'lab.word_banner': (
    'Deneme — değişiklikler kaydedilmez',
    'Experiment — changes are not saved',
    'تجربة — لا تُحفظ التغييرات',
  ),
};
