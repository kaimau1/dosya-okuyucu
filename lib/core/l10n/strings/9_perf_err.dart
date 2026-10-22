part of '../app_strings.dart';

/// Çeviri tablosunun 9. bölümü: başarım profili (Faz 4) ve kullanıcı
/// iletişimi altyapısı — hata dili, izin, çevrimdışı, yardım (Faz 5).
const Map<String, (String, String, String)> _t9 = {
  // ── Başarım profili (Faz 4) ───────────────────────────────────────────────
  'perf.mode': ('Başarım', 'Performance', 'الأداء'),
  'perf.mode_sub': (
    'Hafif: eski/düşük RAM\'li telefonda daha az bellek ve pil — küçük resimler tek tek, süsler kapalı, 60 Hz.',
    'Light: less memory and battery on older/low-RAM phones — one thumbnail at a time, effects off, 60 Hz.',
    'خفيف: ذاكرة وبطارية أقل في الهواتف القديمة أو قليلة الذاكرة — صورة مصغرة واحدة في كل مرة، المؤثرات متوقفة، 60 هرتز.',
  ),
  'perf.auto': ('Otomatik', 'Automatic', 'تلقائي'),
  'perf.light': ('Hafif', 'Light', 'خفيف'),
  'perf.full': ('Tam', 'Full', 'كامل'),
  'perf.auto_is': (
    'Otomatik — bu telefon: {tier}',
    'Automatic — this phone: {tier}',
    'تلقائي — هذا الهاتف: {tier}',
  ),
  'perf.tier_low': ('hafif', 'light', 'خفيف'),
  'perf.tier_mid': ('orta', 'medium', 'متوسط'),
  'perf.tier_high': ('güçlü', 'powerful', 'قوي'),
  // ── Kullanıcı dili hatalar (Faz 5) ────────────────────────────────────────
  'uerr.permission': (
    'İzin yok — bu klasöre yazma/okuma izni verilmemiş.',
    'No permission — access to this folder hasn\'t been granted.',
    'لا يوجد إذن — لم يُمنح الوصول إلى هذا المجلد.',
  ),
  'uerr.no_space': (
    'Yer kalmadı — telefonda yeterli boş alan yok.',
    'Out of space — there isn\'t enough free storage.',
    'لا توجد مساحة — لا تتوفر مساحة تخزين كافية.',
  ),
  'uerr.not_found': (
    'Dosya bulunamadı — taşınmış ya da silinmiş olabilir.',
    'File not found — it may have been moved or deleted.',
    'لم يُعثر على الملف — ربما نُقل أو حُذف.',
  ),
  'uerr.read_only': (
    'Bu bellek salt okunur — buraya yazılamıyor.',
    'This storage is read-only — it can\'t be written to.',
    'هذه الذاكرة للقراءة فقط — لا يمكن الكتابة عليها.',
  ),
  'uerr.exists': (
    'Aynı adda bir dosya zaten var.',
    'A file with the same name already exists.',
    'يوجد ملف بالاسم نفسه بالفعل.',
  ),
  'uerr.offline': (
    'Bağlantı yok — internet ya da ağ bağlantısını denetleyin.',
    'No connection — check your internet or network.',
    'لا يوجد اتصال — تحقق من الإنترنت أو الشبكة.',
  ),
  'uerr.pdf_damaged': (
    'PDF okunamadı — dosya bozuk olabilir.',
    'Couldn\'t read the PDF — the file may be damaged.',
    'تعذّرت قراءة ملف PDF — قد يكون الملف تالفًا.',
  ),
  'uerr.pdf_locked': (
    'PDF parolalı — önce parolayı girin.',
    'The PDF is password-protected — enter the password first.',
    'ملف PDF محمي بكلمة مرور — أدخل كلمة المرور أولًا.',
  ),
  'uerr.ai_key': (
    'AI anahtarı geçersiz ya da yetkisiz — Ayarlar > AI\'dan denetleyin.',
    'The AI key is invalid or not authorized — check Settings > AI.',
    'مفتاح الذكاء الاصطناعي غير صالح أو غير مخوّل — تحقق من الإعدادات > الذكاء الاصطناعي.',
  ),
  'uerr.ai_quota': (
    'AI kotası doldu — biraz sonra yeniden deneyin.',
    'AI quota reached — try again a little later.',
    'نفدت حصة الذكاء الاصطناعي — حاول مجددًا بعد قليل.',
  ),
  'uerr.cancelled': ('İşlem iptal edildi.', 'The operation was cancelled.', 'أُلغيت العملية.'),
  'uerr.unknown': (
    'Beklenmeyen bir hata oldu. Ayrıntı hata kaydına yazıldı.',
    'Something unexpected went wrong. The details were saved to the error log.',
    'حدث خطأ غير متوقع. حُفظت التفاصيل في سجل الأخطاء.',
  ),
  'uerr.details': ('Ayrıntı', 'Details', 'التفاصيل'),
  'uerr.retry': ('Yeniden dene', 'Try again', 'أعد المحاولة'),
  'uerr.notif_off': (
    'Bildirimler kapalı: işin ilerlemesi yalnız uygulama içinde görünecek. Ayarlar\'dan açabilirsiniz.',
    'Notifications are off: progress will only show inside the app. You can turn them on in Settings.',
    'الإشعارات متوقفة: سيظهر التقدم داخل التطبيق فقط. يمكنك تشغيلها من الإعدادات.',
  ),
  // ── İzinler (Faz 5) ───────────────────────────────────────────────────────
  'perm.allow': ('İzin ver', 'Allow', 'السماح'),
  'perm.open_settings': ('Ayarlara git', 'Open settings', 'فتح الإعدادات'),
  'perm.granted': ('İzin verildi', 'Allowed', 'مسموح'),
  'perm.all_files_title': ('Tüm dosyalara erişim', 'Access to all files', 'الوصول إلى كل الملفات'),
  'perm.all_files_why': (
    'Dosya yöneticisi olarak telefondaki klasörleri gezmek, kopyalamak ve taşımak için gerekli.',
    'Needed to browse, copy and move folders on your phone as a file manager.',
    'مطلوب لتصفح المجلدات ونسخها ونقلها على هاتفك كمدير ملفات.',
  ),
  'perm.all_files_without': (
    'İzin olmadan yalnız fotoğraf/video/müzik ve uygulamanın kendi klasörü görünür.',
    'Without it, only photos/videos/music and the app\'s own folder are visible.',
    'بدونه تظهر فقط الصور ومقاطع الفيديو والموسيقى ومجلد التطبيق نفسه.',
  ),
  'perm.notifications_title': ('Bildirimler', 'Notifications', 'الإشعارات'),
  'perm.notifications_why': (
    'Uzun işlerin (kopyalama, temizlik, indirme) ilerlemesini ve bitişini haber vermek için.',
    'To show progress and completion of long tasks (copying, cleanup, downloads).',
    'لعرض تقدم المهام الطويلة (النسخ والتنظيف والتنزيل) واكتمالها.',
  ),
  'perm.notifications_without': (
    'İşler yine çalışır; yalnız ilerlemeyi uygulama içinde görürsünüz.',
    'Tasks still run; you\'ll only see progress inside the app.',
    'تستمر المهام في العمل؛ سترى التقدم داخل التطبيق فقط.',
  ),
  'perm.camera_title': ('Kamera', 'Camera', 'الكاميرا'),
  'perm.camera_why': (
    'Belge tarama ve QR ile bağlanma için.',
    'For document scanning and connecting via QR.',
    'لمسح المستندات والاتصال عبر رمز QR.',
  ),
  'perm.camera_without': (
    'Tarama yerine galeriden görsel seçebilirsiniz.',
    'You can pick images from the gallery instead of scanning.',
    'يمكنك اختيار الصور من المعرض بدلًا من المسح.',
  ),
  'perm.location_title': ('Konum', 'Location', 'الموقع'),
  'perm.location_why': (
    'Fotoğrafların çekildiği yerlerin adını göstermek için (Anılar > Yerler).',
    'To show where photos were taken (Memories > Places).',
    'لعرض أماكن التقاط الصور (الذكريات > الأماكن).',
  ),
  'perm.location_without': (
    'Yerler bölümü boş kalır; başka hiçbir şey etkilenmez.',
    'The Places section stays empty; nothing else is affected.',
    'يبقى قسم الأماكن فارغًا؛ ولا يتأثر أي شيء آخر.',
  ),
  'perm.overlay_title': ('Diğer uygulamaların üstünde gösterme', 'Display over other apps', 'العرض فوق التطبيقات الأخرى'),
  'perm.overlay_why': (
    'Videoyu yüzen pencerede oynatmak için.',
    'To play video in a floating window.',
    'لتشغيل الفيديو في نافذة عائمة.',
  ),
  'perm.overlay_without': (
    'Video yalnız uygulama içinde oynar.',
    'Video plays only inside the app.',
    'يُشغَّل الفيديو داخل التطبيق فقط.',
  ),
  // ── Anahtarsız AI (Faz 5) ─────────────────────────────────────────────────
  'aikey.title': ('AI\'yı etkinleştir', 'Turn on AI', 'تفعيل الذكاء الاصطناعي'),
  'aikey.body': (
    'Özet, sohbet, çeviri ve akıllı düzenleme Google Gemini ile çalışır. Ücretsiz bir anahtar alıp Ayarlar > AI\'ya yapıştırmanız yeterli; gerisi kendiliğinden.',
    'Summaries, chat, translation and smart editing run on Google Gemini. Get a free key and paste it in Settings > AI; that\'s all.',
    'تعمل الملخصات والدردشة والترجمة والتحرير الذكي عبر Google Gemini. احصل على مفتاح مجاني والصقه في الإعدادات > الذكاء الاصطناعي؛ هذا كل شيء.',
  ),
  'aikey.privacy': (
    'Yalnız sizin seçtiğiniz metin/dosya, yalnız siz istediğinizde gönderilir.',
    'Only the text/file you choose is sent, and only when you ask.',
    'يُرسَل فقط النص أو الملف الذي تختاره، وفقط عندما تطلب ذلك.',
  ),
  'aikey.add': ('Anahtar ekle', 'Add key', 'إضافة مفتاح'),
  'aikey.button_off': ('AI (kapalı)', 'AI (off)', 'الذكاء الاصطناعي (متوقف)'),
  // ── Yardım / SSS (Faz 5 iskeleti) ─────────────────────────────────────────
  // ── İlk açılış rehberi (Faz 11a) ─────────────────────────────────────────
  'onb.skip': ('Atla', 'Skip', 'تخطٍّ'),
  'onb.next': ('İleri', 'Next', 'التالي'),
  'onb.start': ('Başla', 'Get started', 'ابدأ'),
  'onb.p1_title': ('Tüm dosyaların tek yerde', 'All your files in one place', 'كل ملفاتك في مكان واحد'),
  'onb.p1_body': (
    'PDF, Word, Excel, slayt, fotoğraf, video ve arşivleri açar, düzenler ve dönüştürür. Telefondaki dosyaları gezer, temizler, taşır — internet gerekmez.',
    'Opens, edits and converts PDF, Word, Excel, slides, photos, videos and archives. Browses, cleans up and moves the files on your phone — no internet needed.',
    'يفتح ملفات PDF وWord وExcel والعروض والصور والفيديو والأرشيفات ويحررها ويحوّلها. يتصفح ملفات هاتفك وينظّفها وينقلها — دون الحاجة إلى الإنترنت.',
  ),
  'onb.p2_title': ('İzinler — neden ve ne zaman', 'Permissions — why and when', 'الأذونات — لماذا ومتى'),
  'onb.p2_body': (
    'Her izin tek bir iş için, o işi ilk kullandığınızda istenir. Dosyalara erişim gezgin ve temizlik için; bildirim uzun işlerin ilerlemesi için; kamera belge tarama için. Vermezseniz yalnız o özellik kısıtlanır.',
    'Each permission serves one feature and is asked the first time you use it. File access is for browsing and cleanup; notifications show progress of long tasks; the camera is for scanning documents. If you decline, only that feature is limited.',
    'كل إذن يخدم ميزة واحدة ويُطلب عند أول استخدام لها. الوصول إلى الملفات للتصفح والتنظيف؛ والإشعارات لعرض تقدم المهام الطويلة؛ والكاميرا لمسح المستندات. إذا رفضت تُقيَّد تلك الميزة فقط.',
  ),
  'onb.p3_title': ('Gizlilik ve AI', 'Privacy and AI', 'الخصوصية والذكاء الاصطناعي'),
  'onb.p3_body': (
    'Dosyalarınız telefonda kalır; reklam ve takip yok. AI özellikleri isteğe bağlıdır: yalnız siz bir AI işi başlattığınızda, seçtiğiniz içerik kendi Gemini anahtarınızla Google\'a gönderilir. Anahtarınız bu telefonda şifreli saklanır.',
    'Your files stay on the phone; no ads and no tracking. AI features are optional: only when you start an AI task is the content you chose sent to Google with your own Gemini key. Your key is stored encrypted on this phone.',
    'تبقى ملفاتك على الهاتف؛ لا إعلانات ولا تتبّع. ميزات الذكاء الاصطناعي اختيارية: فقط عندما تبدأ مهمة ذكاء اصطناعي يُرسَل المحتوى الذي اخترته إلى Google بمفتاح Gemini الخاص بك. ويُحفظ مفتاحك مشفّرًا على هذا الهاتف.',
  ),
  'help.report': ('Sorun bildir', 'Report a problem', 'الإبلاغ عن مشكلة'),
  'help.report_body': (
    'Sorunu kısaca anlatın (ne yaptınız, ne bekliyordunuz, ne oldu):',
    'Briefly describe the problem (what you did, what you expected, what happened):',
    'صِف المشكلة باختصار (ماذا فعلت، وماذا توقعت، وماذا حدث):',
  ),
  'help.open_with_q': ('Dosyalar neden başka uygulamada açılıyor / açılmıyor?', 'Why do files open (or not) in another app?', 'لماذا تُفتح الملفات (أو لا تُفتح) في تطبيق آخر؟'),
  'help.open_with_a': (
    'Uygulama PDF, Office, metin, fotoğraf, video, ses ve arşivleri kendisi açar. Başka biçimler için dosyanın ⋮ menüsünde "Başka uygulamayla aç" vardır. Fotoğraf ve videonun nerede açılacağını Ayarlar > Gezinme\'den seçebilirsiniz.',
    'The app opens PDF, Office, text, photos, video, audio and archives itself. For other formats use "Open with another app" in the file\'s ⋮ menu. Choose where photos and videos open in Settings > Browsing.',
    'يفتح التطبيق ملفات PDF وOffice والنصوص والصور والفيديو والصوت والأرشيفات بنفسه. للصيغ الأخرى استخدم "فتح بتطبيق آخر" من قائمة ⋮ للملف. اختر مكان فتح الصور والفيديو من الإعدادات > التصفح.',
  ),
  'help.reading_q': ('Okurken çubuklar neden kayboluyor?', 'Why do the bars disappear while reading?', 'لماذا تختفي الأشرطة أثناء القراءة؟'),
  'help.reading_a': (
    'Okuma kipi: belgeyi aşağı kaydırınca üst ve alt çubuk çekilir, yukarı kaydırınca ya da ekrana bir kez dokununca geri gelir. "Aa" düğmesindeki "Tam ekran" sistem çubuklarını da gizler.',
    'Reading mode: scrolling down hides the top and bottom bars; scrolling up or a single tap brings them back. "Full screen" under the "Aa" button also hides the system bars.',
    'وضع القراءة: التمرير لأسفل يخفي الشريطين العلوي والسفلي، والتمرير لأعلى أو نقرة واحدة يعيدهما. و"ملء الشاشة" في زر "Aa" يخفي أشرطة النظام أيضًا.',
  ),
  'help.resize_q': ('Fotoğrafı istediğim boyuta nasıl küçültürüm?', 'How do I resize a photo exactly?', 'كيف أغيّر حجم صورة بدقة؟'),
  'help.resize_a': (
    'Galeride "Boyut"a ya da dosyanın ⋮ menüsünde "Boyutlandır"a dokunun: yüzde, piksel (oran kilitli), uzun kenar, en-boy oranı ya da hedef dosya boyutu ("en çok 200 KB") seçilebilir. Özgün dosya korunur.',
    'Tap "Resize" in the gallery or "Resize" in the file\'s ⋮ menu: choose a percentage, pixels (aspect locked), long edge, aspect ratio or a target file size ("at most 200 KB"). The original is kept.',
    'اضغط "الحجم" في المعرض أو "تغيير الحجم" من قائمة ⋮ للملف: اختر نسبة مئوية أو بكسلات (مع قفل النسبة) أو الضلع الأطول أو نسبة العرض إلى الارتفاع أو حجم ملف مستهدفًا ("200 ك.ب كحد أقصى"). يُحتفَظ بالأصل.',
  ),
  'help.trash_q': ('Sildiğim dosyayı geri alabilir miyim?', 'Can I get a deleted file back?', 'هل يمكنني استعادة ملف محذوف؟'),
  'help.trash_a': (
    'Evet: silinen dosyalar önce Çöp kutusuna gider; silme bildirimindeki "Geri al" ya da Çöp kutusu > Geri yükle ile geri gelir. Çöp kutusu ayarladığınız günden sonra kendini boşaltır.',
    'Yes: deleted files go to the Trash first; "Undo" on the delete notice or Trash > Restore brings them back. The Trash empties itself after the number of days you set.',
    'نعم: تذهب الملفات المحذوفة أولًا إلى سلة المهملات؛ ويعيدها "تراجع" في إشعار الحذف أو سلة المهملات > استعادة. وتُفرَّغ السلة تلقائيًا بعد عدد الأيام الذي تحدده.',
  ),
  'help.usb_q': ('USB belleği güvenle nasıl çıkarırım?', 'How do I safely remove a USB drive?', 'كيف أُخرج ذاكرة USB بأمان؟'),
  'help.usb_a': (
    'Yazma bitmeden belleği çekmeyin; USB ekranının ⋮ menüsünden "Güvenle çıkar"ı kullanın. Yazma yarıda kesilirse uygulama bir sonraki takışta belleği kendiliğinden onarır (kayıp alanı geri verir).',
    'Do not unplug before writing finishes; use "Safely remove" in the USB screen\'s ⋮ menu. If a write is interrupted, the app repairs the drive automatically the next time it is plugged in (lost space is recovered).',
    'لا تنزع الذاكرة قبل انتهاء الكتابة؛ استخدم "إزالة آمنة" من قائمة ⋮ في شاشة USB. وإذا انقطعت الكتابة يُصلح التطبيق الذاكرة تلقائيًا عند توصيلها مرة أخرى (تُستعاد المساحة المفقودة).',
  ),
  'help.video_q': ('Video oynatıcıda hangi jestler var?', 'Which gestures does the video player have?', 'ما الإيماءات المتاحة في مشغّل الفيديو؟'),
  'help.video_a': (
    'Sağ yarıda yukarı/aşağı kaydırma ses, sol yarıda parlaklık; yavaş yatay kaydırma sarar; çift dokunuş 10 sn ileri/geri; basılı tutmak 2× hız. Soldaki kilit düğmesi yanlış dokunuşları engeller.',
    'Swipe up/down on the right half for volume, on the left half for brightness; a slow horizontal drag seeks; double-tap skips 10 s; press and hold for 2× speed. The lock button on the left blocks accidental touches.',
    'اسحب لأعلى/لأسفل في النصف الأيمن للصوت وفي الأيسر للسطوع؛ والسحب الأفقي البطيء للتقديم؛ والنقر المزدوج للتقديم أو الإرجاع 10 ث؛ والضغط المطوّل لسرعة 2×. وزر القفل على اليسار يمنع اللمسات الخاطئة.',
  ),
  'help.title': ('Yardım ve sık sorulanlar', 'Help & FAQ', 'المساعدة والأسئلة الشائعة'),
  'help.tile_sub': (
    'İzinler, kasa PIN\'i, ağ paylaşımı, AI anahtarı',
    'Permissions, vault PIN, network sharing, AI key',
    'الأذونات، رمز الخزنة، المشاركة عبر الشبكة، مفتاح الذكاء الاصطناعي',
  ),
  'help.permissions_q': ('Uygulama hangi izinleri neden istiyor?', 'Which permissions does the app need, and why?', 'ما الأذونات التي يحتاجها التطبيق ولماذا؟'),
  'help.permissions_a': (
    'Her izin tek bir iş için istenir; vermezseniz yalnız o iş kısıtlanır. Durumları aşağıda görüp buradan açabilirsiniz.',
    'Each permission serves a single feature; if you decline, only that feature is limited. See their status below and turn them on here.',
    'كل إذن يخدم ميزة واحدة؛ إذا رفضته تُقيَّد تلك الميزة فقط. اطّلع على حالتها أدناه وفعّلها من هنا.',
  ),
  'help.vault_pin_q': ('Kasa PIN\'imi unutursam ne olur?', 'What if I forget my vault PIN?', 'ماذا لو نسيت رمز الخزنة؟'),
  'help.vault_pin_a': (
    'Kasadaki dosyalar PIN\'inizden türetilen anahtarla şifrelidir; PIN olmadan kimse — biz de — açamaz. Parmak izi ayarlıysa onunla açıp Ayarlar > Gizlilik\'ten yeni PIN koyabilirsiniz.',
    'Vault files are encrypted with a key derived from your PIN; without it nobody — including us — can open them. If fingerprint is set up, unlock with it and set a new PIN in Settings > Privacy.',
    'ملفات الخزنة مشفرة بمفتاح مشتق من رمزك؛ بدونه لا يمكن لأحد — ولا لنا — فتحها. إذا كانت البصمة مفعّلة فافتح بها وعيّن رمزًا جديدًا من الإعدادات > الخصوصية.',
  ),
  'help.network_share_q': ('Bilgisayarla dosya nasıl paylaşırım?', 'How do I share files with a computer?', 'كيف أشارك الملفات مع حاسوب؟'),
  'help.network_share_a': (
    'Aktar > Bilgisayarla\'yı açın; telefon ve bilgisayar aynı Wi-Fi\'de olmalı. Gösterilen adresi tarayıcıya yazın ya da QR\'ı okutun. Paylaşım siz kapatınca biter.',
    'Open Transfer > With a computer; the phone and computer must be on the same Wi-Fi. Type the shown address into a browser or scan the QR. Sharing ends when you stop it.',
    'افتح النقل > مع حاسوب؛ يجب أن يكون الهاتف والحاسوب على شبكة Wi-Fi نفسها. اكتب العنوان المعروض في المتصفح أو امسح رمز QR. تنتهي المشاركة عند إيقافها.',
  ),
  'help.ai_key_q': ('AI neden anahtar istiyor, ücretli mi?', 'Why does AI need a key — does it cost money?', 'لماذا يحتاج الذكاء الاصطناعي إلى مفتاح، وهل هو مدفوع؟'),
  'help.ai_key_a': (
    'AI özellikleri Google Gemini\'yi sizin anahtarınızla çağırır. Ücretsiz katman günlük kullanım için yeter; anahtar yalnız bu telefonda saklanır.',
    'AI features call Google Gemini with your own key. The free tier is enough for daily use; the key is stored only on this phone.',
    'تستدعي ميزات الذكاء الاصطناعي Google Gemini بمفتاحك. الطبقة المجانية تكفي للاستخدام اليومي؛ ويُحفظ المفتاح على هذا الهاتف فقط.',
  ),
  'help.light_mode_q': ('Telefonum eski, uygulama yavaşsa?', 'My phone is old — what if the app is slow?', 'هاتفي قديم — ماذا لو كان التطبيق بطيئًا؟'),
  'help.light_mode_a': (
    'Ayarlar > Depolama ve hız > Başarım\'ı "Hafif" yapın: daha az bellek, tek tek küçük resim, süs animasyonları kapalı, 60 Hz. "Otomatik" bunu düşük RAM\'li telefonda zaten seçer.',
    'Set Settings > Storage & speed > Performance to "Light": less memory, one thumbnail at a time, no decorative animations, 60 Hz. "Automatic" already picks this on low-RAM phones.',
    'اضبط الإعدادات > التخزين والسرعة > الأداء على "خفيف": ذاكرة أقل، صورة مصغرة واحدة في كل مرة، بلا رسوم متحركة تزيينية، 60 هرتز. ويختاره "تلقائي" تلقائيًا في الهواتف قليلة الذاكرة.',
  ),
  'help.errors_q': ('Bir hata gördüm, ne yapmalıyım?', 'I saw an error — what should I do?', 'رأيت خطأ — ماذا أفعل؟'),
  'help.errors_a': (
    'Hata bildirimindeki "Ayrıntı" teknik metni gösterir ve kopyalar. Beklenmeyen hatalar Ayarlar > Hakkında > Hata kayıtları\'na yazılır; oradan paylaşabilirsiniz.',
    '"Details" on the error notice shows and copies the technical text. Unexpected errors are saved under Settings > About > Error log; you can share them from there.',
    'يعرض زر "التفاصيل" في إشعار الخطأ النص التقني وينسخه. تُحفظ الأخطاء غير المتوقعة في الإعدادات > حول > سجل الأخطاء؛ ويمكنك مشاركتها من هناك.',
  ),
  // ── Sabit metinlerin çevirisi (Faz 5, I2-I4) ────────────────────────────
  'uix.view': ('Görünüm', 'View', 'العرض'),
  'uix.item_n': ('Öğe {n}', 'Item {n}', 'عنصر {n}'),
  'uix.video': ('Video', 'Video', 'فيديو'),
  'uix.no_text': ('Okunacak metin yok', 'Nothing to read', 'لا يوجد نص للقراءة'),
  // ── Açık kaynak lisansları penceresi (Faz 5, I3) ──────────────────────────
  'oss.body': (
    'Video küçültme ve oynatma Android Media3 (Apache 2.0) ile yapılır; '
        'H.264 için cihazın donanım kodlayıcısı kullanılır.\n\n'
        'Syncfusion Flutter PDF — Syncfusion Community License (açık kaynak '
        'DEĞİL; ücretsiz kullanım şartlara bağlıdır).\n\n'
        'Diğer bileşenler (Flutter, PDFium/pdfrx, Google ML Kit, archive, image, '
        'video_player, flutter_local_notifications …) BSD/MIT/Apache 2.0 '
        'lisanslıdır. Tam liste: "Tüm lisanslar".',
    'Video downsizing and playback use Android Media3 (Apache 2.0); H.264 '
        'uses the device\'s hardware encoder.\n\n'
        'Syncfusion Flutter PDF — Syncfusion Community License (NOT open '
        'source; free use is subject to conditions).\n\n'
        'Other components (Flutter, PDFium/pdfrx, Google ML Kit, archive, '
        'image, video_player, flutter_local_notifications …) are BSD/MIT/'
        'Apache 2.0 licensed. Full list: "All licenses".',
    'يتم تصغير الفيديو وتشغيله باستخدام Android Media3 (Apache 2.0)؛ ويُستخدم '
        'مرمّز العتاد في الجهاز لـ H.264.\n\n'
        'Syncfusion Flutter PDF — رخصة Syncfusion المجتمعية (ليست مفتوحة '
        'المصدر؛ الاستخدام المجاني مشروط).\n\n'
        'المكونات الأخرى (Flutter وPDFium/pdfrx وGoogle ML Kit وarchive وimage '
        'وvideo_player وflutter_local_notifications …) مرخّصة بـ BSD/MIT/'
        'Apache 2.0. القائمة الكاملة: "كل التراخيص".',
  ),
  'oss.all': ('Tüm lisanslar', 'All licenses', 'كل التراخيص'),
};
