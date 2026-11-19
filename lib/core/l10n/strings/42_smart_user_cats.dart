part of '../app_strings.dart';

/// Çeviri tablosunun 42. bölümü (2026-11-18): Akıllı düzen **kullanıcı
/// kategorileri** — ad + "neyi kapsar" cümlesi, "Dene", geriye dönük uygula.
const Map<String, (String, String, String)> _t42 = {
  'suc.section': ('Kategorilerim', 'My categories', 'فئاتي'),
  'suc.sub': (
    'Kendi kategorini tarif et; AI her dosyaya ayrıca sorar. Bir dosya birden çok kategoride olabilir.',
    'Describe your own category; AI asks about each file separately. A file can be in several categories.',
    'صِف فئتك الخاصة؛ يسأل الذكاء الاصطناعي عن كل ملف على حدة. قد يكون الملف في عدة فئات.',
  ),
  'suc.empty': (
    'Henüz kategorin yok. Örnek: "Kira" — kira sözleşmesi, kira dekontları ve aidat makbuzları.',
    'No categories yet. Example: "Rent" — rental contract, rent receipts and maintenance fees.',
    'لا فئات بعد. مثال: "الإيجار" — عقد الإيجار وإيصالات الإيجار ورسوم الصيانة.',
  ),
  'suc.add': ('Kategori ekle', 'Add category', 'إضافة فئة'),
  'suc.full': (
    'En çok {n} kategori eklenebilir',
    'You can add at most {n} categories',
    'يمكنك إضافة {n} فئة على الأكثر',
  ),
  'suc.new_title': ('Yeni kategori', 'New category', 'فئة جديدة'),
  'suc.edit_title': ('Kategoriyi düzenle', 'Edit category', 'تعديل الفئة'),
  'suc.name': ('Ad', 'Name', 'الاسم'),
  'suc.name_hint': ('ör. Kira', 'e.g. Rent', 'مثلاً: الإيجار'),
  'suc.about': (
    'Neyi kapsar? (tek cümle)',
    'What does it cover? (one sentence)',
    'ماذا تشمل؟ (جملة واحدة)',
  ),
  'suc.about_hint': (
    'ör. Kira sözleşmesi, kira dekontları ve aidat makbuzları',
    'e.g. Rental contract, rent receipts and maintenance fee slips',
    'مثلاً: عقد الإيجار وإيصالات الإيجار وإيصالات رسوم الصيانة',
  ),
  'suc.icon': ('Simge', 'Icon', 'الأيقونة'),
  'suc.color': ('Renk', 'Color', 'اللون'),
  'suc.try': ('Dene', 'Try it', 'جرّب'),
  'suc.try_sub': (
    'Kaydetmeden önce son {n} dosyada denenir; eşleşenleri görürsün.',
    'Before saving, it is tried on your last {n} files; you will see the matches.',
    'قبل الحفظ تُجرَّب على آخر {n} ملفات؛ وسترى الملفات المطابقة.',
  ),
  'suc.trying': ('Deneniyor… {done}/{total}', 'Trying… {done}/{total}', 'جارٍ التجربة… {done}/{total}'),
  'suc.try_none': (
    'Son {n} dosyada eşleşme yok. Cümleyi düzeltip yeniden dene.',
    'No match in the last {n} files. Adjust the sentence and try again.',
    'لا تطابق في آخر {n} ملفات. عدّل الجملة وجرّب مرة أخرى.',
  ),
  'suc.try_hits': ('{m} / {n} dosya eşleşti', '{m} of {n} files matched', 'تطابق {m} من {n} ملفات'),
  'suc.try_stale': (
    'Ad ya da cümle değişti — yeniden dene.',
    'The name or sentence changed — try again.',
    'تغيّر الاسم أو الجملة — جرّب مرة أخرى.',
  ),
  'suc.no_files': (
    'Denenecek dosya bulunamadı',
    'No files to try on',
    'لم يُعثر على ملفات للتجربة',
  ),
  'suc.matched': ('Eşleşti', 'Matched', 'مطابق'),
  'suc.not_matched': ('Eşleşmedi', 'Not matched', 'غير مطابق'),
  'suc.confirm': ('Sonuçlar doğru', 'The results are right', 'النتائج صحيحة'),
  'suc.confirm_sub': (
    'Eşleşenler bu kategoriye gerçekten giriyor mu? Değilse cümleyi düzelt.',
    'Do the matches really belong here? If not, adjust the sentence.',
    'هل تنتمي الملفات المطابقة فعلاً إلى هذه الفئة؟ إن لم تكن كذلك فعدّل الجملة.',
  ),
  'suc.save': ('Kaydet', 'Save', 'حفظ'),
  'suc.save_need': (
    'Kaydetmek için önce dene, en az bir eşleşme gör ve sonuçları onayla.',
    'To save, try it first, see at least one match and confirm the results.',
    'للحفظ، جرّب أولاً وشاهد تطابقاً واحداً على الأقل ثم أكّد النتائج.',
  ),
  'suc.apply': ('Eski dosyalara uygula ({n})', 'Apply to earlier files ({n})', 'تطبيق على الملفات السابقة ({n})'),
  'suc.applying': ('Uygulanıyor… {done}/{total}', 'Applying… {done}/{total}', 'جارٍ التطبيق… {done}/{total}'),
  'suc.applied': (
    '{n} dosyaya bakıldı, {m} eşleşti',
    '{n} files checked, {m} matched',
    'تم فحص {n} ملفات، وتطابق {m}',
  ),
  'suc.stopped': ('Durdu: {reason}', 'Stopped: {reason}', 'توقف: {reason}'),
  'suc.stop': ('Durdur', 'Stop', 'إيقاف'),
  'suc.count': ('{n} dosya', '{n} files', '{n} ملفات'),
  'suc.pending': (
    '{n} dosya · {p} dosyaya henüz sorulmadı',
    '{n} files · {p} not checked yet',
    '{n} ملفات · {p} لم تُفحص بعد',
  ),
  'suc.menu': ('Kategori seçenekleri', 'Category options', 'خيارات الفئة'),
  'suc.edit': ('Düzenle', 'Edit', 'تعديل'),
  'suc.delete_q': (
    '"{name}" kategorisi silinsin mi? Dosyalar yerinde kalır.',
    'Delete the category "{name}"? Files stay where they are.',
    'حذف الفئة "{name}"؟ تبقى الملفات في مكانها.',
  ),
};
