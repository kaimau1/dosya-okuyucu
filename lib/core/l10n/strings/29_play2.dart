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
  'aisend.private': ('Kasadaki dosyalar yapay zekâya gönderilmez.', 'Files in the vault are never sent to AI.', 'لا تُرسل ملفات الخزنة إلى الذكاء الاصطناعي أبدًا.'),
  'aisend.cancelled': ('Yapay zekâya gönderilmedi.', 'Not sent to AI.', 'لم يُرسل إلى الذكاء الاصطناعي.'),
  'fm.add_folder': ('Klasör ekle', 'Add folder', 'إضافة مجلد'),
  'fm.open_one': ('Şimdilik tek dosya aç', 'Just open a file', 'افتح ملفًا واحدًا الآن'),
  'saf.folders_title': ('Eklenen klasörler', 'Added folders', 'المجلدات المضافة'),
  'saf.folders_sub': (
    'Yalnız bu klasörlere izin verdin; panoda kart olarak görünürler. "Geri al" izni bırakır, dosyalara dokunmaz.',
    'You allowed only these folders; they show as cards on the home screen. "Revoke" drops the access, files stay.',
    'سمحت بهذه المجلدات فقط؛ تظهر كبطاقات في الشاشة الرئيسية. «إلغاء» يسحب الإذن ولا يمس الملفات.',
  ),
  'saf.folders_none': (
    'Henüz yok. Tüm dosyalara izin vermek istemezsen panodan "Klasör ekle" ile yalnız seçtiğin klasörleri ekleyebilirsin.',
    'None yet. If you’d rather not allow all files, use "Add folder" on the home screen to add only the folders you pick.',
    'لا شيء بعد. إن لم ترغب في السماح بكل الملفات، استخدم «إضافة مجلد» في الشاشة الرئيسية لإضافة ما تختاره فقط.',
  ),
  'onb.choice_open': ('Bir dosya aç', 'Open a file', 'افتح ملفًا'),
  'onb.choice_open_sub': (
    'İzin gerekmez: Android’in seçicisinden dosyayı seç, hemen açılsın.',
    'No permission needed: pick the file in Android’s picker and it opens right away.',
    'لا حاجة لأي إذن: اختر الملف من منتقي Android ليُفتح فورًا.',
  ),
  'onb.choice_manage': ('Telefonumdaki tüm dosyaları yönet', 'Manage all files on my phone', 'إدارة كل الملفات على هاتفي'),
  'whatsnew.title': ('Neler yeni — {v}', 'What’s new — {v}', 'ما الجديد — {v}'),
  'whatsnew.privacy': ('Ayarlar › Gizlilik ve izinler: her izin neden istenir, durumu ne, tek dokunuşla geri al.', 'Settings › Privacy & permissions: why each permission is asked, its status, revoke in one tap.', 'الإعدادات › الخصوصية والأذونات: سبب كل إذن وحالته وإلغاؤه بلمسة.'),
  'whatsnew.offline': ('Çevrimdışı kip: açınca uygulama internete hiç çıkmaz.', 'Offline mode: when on, the app never goes online.', 'وضع عدم الاتصال: عند تشغيله لا يتصل التطبيق بالإنترنت أبدًا.'),
  'whatsnew.ai_ask': ('Yapay zekâya dosya gitmeden önce sorulur.', 'You’re asked before a file goes to AI.', 'يُطلب إذنك قبل إرسال أي ملف إلى الذكاء الاصطناعي.'),
  'whatsnew.add_folder': ('Tüm dosyalara izin vermeden "Klasör ekle" ile yalnız seçtiğin klasörleri kullan.', 'Use "Add folder" to work with just the folders you choose, without all-files access.', 'استخدم «إضافة مجلد» للعمل بالمجلدات التي تختارها فقط دون إذن كل الملفات.'),
  'whatsnew.reading': ('PDF’te okuma yardımcıları; Word/Slayt kaldığı yerden, Excel kaydedildiği sayfada açılır.', 'Reading helpers in PDF; Word/Slides reopen where you left off, Excel on its saved sheet.', 'أدوات قراءة في PDF؛ Word والشرائح تُفتح من حيث توقفت، وExcel على الورقة المحفوظة.'),
  'whatsnew.faster': ('Yeni Flutter ve paketler: daha akıcı PDF kaydırma, daha hızlı SFTP.', 'New Flutter and packages: smoother PDF scrolling, faster SFTP.', 'Flutter وحزم جديدة: تمرير PDF أنعم وSFTP أسرع.'),
  'ia.reader_off': ('Bu sürüm uygulama listesine erişmez. Tam sürümde yüklü uygulamaları görebilirsin.', 'This edition can’t list installed apps. The full edition shows them.', 'هذا الإصدار لا يصل إلى قائمة التطبيقات. يعرضها الإصدار الكامل.'),
};
