part of '../app_strings.dart';

/// Çeviri tablosunun 29. bölümü (2026-11-08): Play yorum çalışması aşama 2–3 —
/// gizlilik sayfası, çevrimdışı kip, AI onayı, klasör ekle, ilk açılış.
const Map<String, (String, String, String)> _t29 = {
  'set.sec_network': ('Ağ ve yapay zekâ', 'Network & AI', 'الشبكة والذكاء الاصطناعي'),
  'set.kw_offline': ('çevrimdışı internet ağ uçak offline', 'offline internet network airplane', 'دون اتصال إنترنت شبكة'),
  'offline.title': ('Çevrimdışı kip', 'Offline mode', 'وضع عدم الاتصال'),
  'offline.sub': (
    'Açıkken uygulama internete hiç çıkmaz: yapay zekâ, Google Drive, altyazı ve indirmeler durur. Yerel ağ (NAS, yakındaki cihaz) çalışır. Tanılama zaten hiçbir şey göndermez.',
    'When on, the app never goes online: AI, Google Drive, subtitles and downloads stop. Local network (NAS, nearby devices) still works. Diagnostics never send anything anyway.',
    'عند التشغيل لا يتصل التطبيق بالإنترنت إطلاقًا: يتوقف الذكاء الاصطناعي وGoogle Drive والترجمات والتنزيلات. تعمل الشبكة المحلية. التشخيص لا يرسل شيئًا أصلًا.',
  ),
  'offline.on': (
    'AÇIK — internete hiçbir şey gitmiyor. Yapay zekâ, Drive, altyazı ve indirmeler kapalı; yerel ağ çalışıyor.',
    'ON — nothing goes to the internet. AI, Drive, subtitles and downloads are off; local network works.',
    'مفعّل — لا يُرسل شيء إلى الإنترنت. الذكاء الاصطناعي وDrive والترجمات والتنزيلات متوقفة؛ الشبكة المحلية تعمل.',
  ),
  'offline.blocked': (
    'Çevrimdışı kip açık — internete bağlanılmadı. Ayarlar › Gizlilik ve izinler’den kapatabilirsin.',
    'Offline mode is on — no internet connection was made. Turn it off in Settings › Privacy & permissions.',
    'وضع عدم الاتصال مفعّل — لم يتم الاتصال بالإنترنت. أوقفه من الإعدادات › الخصوصية والأذونات.',
  ),
  'perm.revoke': ('Geri al', 'Revoke', 'إلغاء'),
  'aisend.setting': ('Yapay zekâya göndermeden önce sor', 'Ask before sending to AI', 'اسأل قبل الإرسال إلى الذكاء الاصطناعي'),
  'aisend.setting_sub': (
    'Dosya metni Google Gemini’ye gitmeden önce onay ister. Kapalıysa onay bir kez verilmiştir.',
    'Asks before file text goes to Google Gemini. Off means you already agreed once.',
    'يطلب الموافقة قبل إرسال نص الملف إلى Google Gemini. إيقافه يعني أنك وافقت مرة.',
  ),
  'aisend.title': ('Dosya Google’a gönderilsin mi?', 'Send the file to Google?', 'إرسال الملف إلى Google؟'),
  'aisend.body': (
    'Bu iş için dosyanın metni (görselse görüntüsü) Google Gemini’ye gönderilir ve senin API anahtarınla işlenir. Başka hiçbir şey telefondan çıkmaz. Bu oturumda bir daha sorulmaz.',
    'For this, the file’s text (or image) is sent to Google Gemini and processed with your API key. Nothing else leaves the phone. You won’t be asked again this session.',
    'لهذه المهمة يُرسل نص الملف (أو صورته) إلى Google Gemini ويُعالج بمفتاحك. لا يغادر الهاتف أي شيء آخر. لن يُطرح السؤال مجددًا في هذه الجلسة.',
  ),
  'aisend.remember': ('Bir daha sorma', 'Don’t ask again', 'لا تسأل مجددًا'),
  'aisend.send': ('Gönder', 'Send', 'إرسال'),
  'aisend.cancelled': ('Yapay zekâya gönderilmedi.', 'Not sent to AI.', 'لم يُرسل إلى الذكاء الاصطناعي.'),
};
