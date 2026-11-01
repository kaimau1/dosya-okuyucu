part of '../app_strings.dart';

/// Çeviri tablosunun 15. bölümü (2026-10-28 turu): tek satır süzgeç başlığı,
/// okuma kipi, Görüntüler (foto + video), QR ile al, alma onayı.
const Map<String, (String, String, String)> _t15 = {
  // ── Tür seçici (tek satır süzgeç başlığı) ────────────────────────────────
  'typ.title': ('Dosya türü', 'File type', 'نوع الملف'),
  'typ.all_types': ('Tüm türler', 'All types', 'كل الأنواع'),
  'typ.hint': (
    'Birden çok tür seçebilirsin; liste hemen süzülür.',
    'You can pick several types; the list filters right away.',
    'يمكنك اختيار عدة أنواع؛ تُصفّى القائمة فورًا.',
  ),
  'typ.show_n': ('{n} dosyayı göster', 'Show {n} files', 'عرض {n} ملف'),
  'typ.more_n': ('{name} +{n}', '{name} +{n}', '{name} +{n}'),

  // ── Görüntüler (fotoğraf + video) ────────────────────────────────────────
  'fm.photos': ('Fotoğraflar', 'Photos', 'الصور'),
  'fm.media_all': ('Görüntüler', 'Photos & videos', 'الصور والفيديو'),

  // ── QR ile al ────────────────────────────────────────────────────────────
  'qrr.confirm_title': ('Dosyalar alınsın mı?', 'Receive these files?', 'هل تريد استلام هذه الملفات؟'),
  'qrr.confirm_body': (
    '{n} dosya · {size}\nKaydedileceği yer: {dir}',
    '{n} files · {size}\nSaved to: {dir}',
    '{n} ملف · {size}\nسيُحفظ في: {dir}',
  ),
  'qrr.accept': ('Al', 'Receive', 'استلام'),
  'qrr.declined': ('Alma iptal edildi', 'Receiving cancelled', 'أُلغي الاستلام'),
  'qrr.receiving': ('Alınıyor', 'Receiving', 'جارٍ الاستلام'),
  'qrr.done_title': ('{n} dosya alındı', '{n} files received', 'تم استلام {n} ملف'),
  'qrr.open_folder': ('Klasörü aç', 'Open folder', 'فتح المجلد'),

  // ── Yakındaki cihazdan gelen dosya onayı ─────────────────────────────────
  'peer.ask_title': ('Gelen dosya', 'Incoming file', 'ملف وارد'),
  'peer.ask_body': (
    '{from} sana {n} dosya göndermek istiyor ({size}).',
    '{from} wants to send you {n} files ({size}).',
    'يريد {from} إرسال {n} ملف إليك ({size}).',
  ),
  'peer.ask_body_one': (
    '{from} sana “{name}” göndermek istiyor ({size}).',
    '{from} wants to send you “{name}” ({size}).',
    'يريد {from} إرسال «{name}» إليك ({size}).',
  ),
  'peer.ask_accept': ('Kabul et', 'Accept', 'قبول'),
  'peer.ask_decline': ('Reddet', 'Decline', 'رفض'),
  'peer.declined_by_peer': (
    'Karşı taraf dosyayı kabul etmedi',
    'The other device declined the file',
    'رفض الجهاز الآخر الملف',
  ),
  'peer.ask_switch': ('Gelen dosyayı onayla', 'Confirm incoming files', 'تأكيد الملفات الواردة'),

  // ── Kitaplık (2026-11-01) ────────────────────────────────────────────────
  'lib.title': ('Kitaplık', 'Library', 'المكتبة'),
  'lib.count': ('{n} kitap', '{n} books', '{n} كتاب'),
  'lib.add': ('Kitap ekle', 'Add books', 'إضافة كتب'),
  'lib.added': ('{n} kitap eklendi', '{n} books added', 'تمت إضافة {n} كتاب'),
  'lib.already': ('Seçilenler zaten kitaplıkta', 'Already in your library', 'موجودة بالفعل في المكتبة'),
  'lib.add_one': ('Kitaplığa ekle', 'Add to library', 'إضافة إلى المكتبة'),
  'lib.remove': ('Kitaplıktan çıkar', 'Remove from library', 'إزالة من المكتبة'),
  'lib.removed': ('Kitaplıktan çıkarıldı', 'Removed from library', 'أزيل من المكتبة'),
  'lib.missing': ('Dosya bulunamadı (taşınmış ya da silinmiş)', 'File not found (moved or deleted)', 'الملف غير موجود'),
  'lib.search': ('Kitaplıkta ara', 'Search library', 'ابحث في المكتبة'),
  'lib.continue': ('Okumaya devam et', 'Continue reading', 'متابعة القراءة'),
  'lib.shelf': ('Raflar', 'Shelves', 'الرفوف'),
  'lib.no_match': ('Eşleşen kitap yok', 'No matching books', 'لا توجد كتب مطابقة'),
  'lib.sort_added': ('Son eklenen', 'Recently added', 'المضاف حديثًا'),
  'lib.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'lib.sort_progress': ('Okuma ilerlemesine göre', 'By reading progress', 'حسب التقدم'),
  'lib.pin_home': ('Ana ekrana ekle', 'Add to home screen', 'إضافة إلى الشاشة الرئيسية'),
  'lib.empty_title': ('Kitaplığın boş', 'Your library is empty', 'مكتبتك فارغة'),
  'lib.empty_body': (
    'PDF, EPUB, MOBI, FB2, DJVU ve çizgi roman (CBZ) dosyalarını ekle. '
    'Dosya menüsünden "Kitaplığa ekle" de diyebilirsin; dosyalar yerinden oynamaz.',
    'Add PDF, EPUB, MOBI, FB2, DJVU and comic (CBZ) files. You can also use '
    '"Add to library" in a file’s menu; files stay where they are.',
    'أضف ملفات PDF وEPUB وMOBI وFB2 وDJVU وCBZ. الملفات تبقى في مكانها.',
  ),
  'lib.tile_empty': ('Kitap ekle', 'Add books', 'إضافة كتب'),
};
