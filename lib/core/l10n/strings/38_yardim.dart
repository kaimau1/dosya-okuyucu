part of '../app_strings.dart';

/// Çeviri tablosunun 38. bölümü (2026-11-14): Ara ve Yardım, özellik
/// isteği ve aynı turdaki kullanıcı istekleri.
const Map<String, (String, String, String)> _t38 = {
  // Albümler (kullanıcı 2026-11-15): oluştur / ekle / çıkar / gizle / sil.
  'pa.new': ('Yeni albüm', 'New album', 'ألبوم جديد'),
  'pa.name': ('Albüm adı', 'Album name', 'اسم الألبوم'),
  'pa.create': ('Oluştur', 'Create', 'إنشاء'),
  'pa.add_to': ('Albüme ekle', 'Add to album', 'إضافة إلى ألبوم'),
  'pa.added': ('{n} dosya “{name}” albümüne eklendi', '{n} files added to “{name}”', 'أُضيف {n} ملف إلى «{name}»'),
  'pa.already': ('Seçilenler zaten “{name}” albümünde', 'Already in “{name}”', 'المحدد موجود بالفعل في «{name}»'),
  'pa.remove_from': ('Albümden çıkar', 'Remove from album', 'إزالة من الألبوم'),
  'pa.removed': ('{n} dosya albümden çıkarıldı (dosyalar silinmedi)', '{n} files removed from album (not deleted)', 'أُزيل {n} ملف من الألبوم (لم تُحذف)'),
  'pa.hide': ('Albümü gizle', 'Hide album', 'إخفاء الألبوم'),
  'pa.unhide': ('Albümü göster', 'Unhide album', 'إظهار الألبوم'),
  'pa.hidden_done': ('“{name}” gizlendi', '“{name}” hidden', 'تم إخفاء «{name}»'),
  'pa.rename': ('Yeniden adlandır', 'Rename', 'إعادة التسمية'),
  'pa.delete': ('Albümü sil', 'Delete album', 'حذف الألبوم'),
  'pa.delete_hint': ('Dosyalar silinmez, yerinde kalır', 'Files are kept', 'تبقى الملفات'),
  'pa.delete_msg': ('“{name}” albümü silinsin mi? İçindeki dosyalar silinmez.', 'Delete album “{name}”? Its files are kept.', 'حذف الألبوم «{name}»؟ تبقى ملفاته.'),
  'pa.delete_dir': ('Albümü içindekilerle sil', 'Delete album with its files', 'حذف الألبوم مع ملفاته'),
  'pa.delete_dir_hint': ('Bu klasördeki {n} dosya silinir', '{n} files in this folder are deleted', 'تُحذف {n} ملفات في هذا المجلد'),
  'pa.show_hidden': ('Gizli albümler ({n})', 'Hidden albums ({n})', 'الألبومات المخفية ({n})'),
  'pa.hide_hidden': ('Gizlileri sakla', 'Conceal hidden', 'إخفاء المخفية'),
  'pa.area_hidden': ('Albüm alanı gizlendi. Geri açmak için: Analiz ve diğer › Görünüm', 'Albums area hidden. To bring it back: Analysis and more › View', 'أُخفيت منطقة الألبومات. لإعادتها: التحليل والمزيد › العرض'),
  'pa.mine': ('Albümüm', 'My album', 'ألبومي'),
  'fm.search_help': ('Ara ve Yardım', 'Search & Help', 'البحث والمساعدة'),
  'help.ftitle': ('Özellikler ve yardım', 'Features & help', 'الميزات والمساعدة'),
  'help.hint': (
    'Bir özellik ara: kes, şifre, birleştir…',
    'Search a feature: trim, password, merge…',
    'ابحث عن ميزة: قص، كلمة مرور، دمج…',
  ),
  'help.none': (
    '"{q}" için bir özellik bulunamadı. Aşağıdan istekte bulunabilirsin.',
    'No feature found for "{q}". You can request it below.',
    'لم يتم العثور على ميزة لـ "{q}". يمكنك طلبها أدناه.',
  ),
  'help.where': ('Nerede', 'Where', 'أين'),
  'help.how': ('Nasıl yapılır', 'How to', 'كيف'),
  'help.more': ('{n} özellik daha', '{n} more features', '{n} ميزات أخرى'),
  'help.open': ('Yardım: tüm özellikler', 'Help: all features', 'المساعدة: كل الميزات'),
  'help.request': ('Özellik iste', 'Request a feature', 'طلب ميزة'),
  'help.req_hint': (
    'Uygulamada olmasını istediğin şeyi yaz. İsteğin bu cihazda saklanır ve geliştiriciye iletilmek üzere tarayıcıda açılır.',
    'Describe what you would like the app to do. Your request is saved on this device and opened in the browser to send to the developer.',
    'اكتب ما تريد أن يفعله التطبيق. يُحفظ طلبك على هذا الجهاز ويُفتح في المتصفح لإرساله إلى المطور.',
  ),
  'help.req_field': ('İsteğin…', 'Your request…', 'طلبك…'),
  'help.req_send': ('Gönder', 'Send', 'إرسال'),
  'help.req_mine': ('İsteklerim', 'My requests', 'طلباتي'),
  'help.req_sent': ('İstek kaydedildi ve açıldı', 'Request saved and opened', 'تم حفظ الطلب وفتحه'),
  'help.req_saved': (
    'İstek bu cihaza kaydedildi (tarayıcı açılamadı)',
    'Request saved on this device (browser could not open)',
    'تم حفظ الطلب على هذا الجهاز (تعذر فتح المتصفح)',
  ),
  // ── Sesi kes ──────────────────────────────────────────────────────────
  'atr.title': ('Sesi kes', 'Trim audio', 'قص الصوت'),
  'atr.action_hint': (
    'Baştan ve sondan kırp, yeni dosya olarak kaydet',
    'Trim start and end, save as a new file',
    'قص البداية والنهاية واحفظ كملف جديد',
  ),
  'atr.hint': (
    'Tutamaçları sürükle; sürüklerken o andan kısa bir parça çalınır.',
    'Drag the handles; a short part plays from that point while dragging.',
    'اسحب المقابض؛ يُشغَّل جزء قصير من تلك النقطة أثناء السحب.',
  ),
  'atr.result': ('Sonuç {t}', 'Result {t}', 'النتيجة {t}'),
  'atr.failed': ('Bu ses dosyası açılamadı.', 'This audio file could not be opened.', 'تعذر فتح ملف الصوت هذا.'),
  'atr.job': ('Ses kesiliyor: {name}', 'Trimming audio: {name}', 'جارٍ قص الصوت: {name}'),
  'aif.check_hint': (
    'Kutuları işaretle, alttan toplu uygula',
    'Tick the boxes, apply together below',
    'حدد المربعات وطبّق معًا بالأسفل',
  ),
};
