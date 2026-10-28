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
  'qrr.fab': ('QR ile al', 'Receive by QR', 'استلام عبر QR'),
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
};
