part of '../app_strings.dart';

/// Çeviri tablosunun 7. bölümü (çoğunlukla `set`, `vault` alanları).
/// Yinelenen anahtar `_table`ın sabit birleşiminde DERLEME hatası verir.
const Map<String, (String, String, String)> _t7 = {
  'simf.none': ('Benzer dosya bulunamadı', 'No similar files found', 'لم يُعثر على ملفات متشابهة'),
  'simf.found': (
    '{n} grup · {size} kazanılabilir',
    '{n} groups · {size} can be freed',
    '{n} مجموعة · يمكن تحرير {size}',
  ),

  // ── AI eylemleri (dosyaya uzun basış) ─────────────────────────────────────
  'aia.need_key': (
    'Önce Ayarlar > Gemini API anahtarı bölümünden anahtarınızı girin.',
    'First enter your key under Settings > Gemini API key.',
    'أدخل مفتاحك أولًا من الإعدادات > مفتاح Gemini API.',
  ),
  'aia.read_failed': (
    'Belge okunamadı: {error}',
    'Could not read the document: {error}',
    'تعذّرت قراءة المستند: {error}',
  ),
  'aia.no_text': (
    'Bu dosyadan özetlenecek metin çıkarılamadı.',
    'No text could be extracted from this file to summarise.',
    'تعذّر استخراج نص من هذا الملف لتلخيصه.',
  ),
  'aia.summary_prompt': (
    'Bu belgeyi Türkçe özetle. Biçim:\n'
        '1) Tek cümlelik "bu ne belgesi" tanımı\n'
        '2) En fazla 5 madde hâlinde önemli bilgiler (tarih, tutar, taraflar, '
        'son tarih varsa mutlaka yaz)\n'
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English. Format:\n'
        '1) A one-sentence "what kind of document is this"\n'
        '2) At most 5 bullet points with the important facts (always include '
        'dates, amounts, parties and any deadline)\n'
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية. الصيغة:\n'
        '1) جملة واحدة تصف «ما نوع هذا المستند»\n'
        '2) خمس نقاط كحد أقصى بالمعلومات المهمة (اذكر دائمًا التواريخ والمبالغ '
        'والأطراف وأي موعد نهائي)\n'
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'aia.summary_failed': (
    'AI özeti alınamadı: {error}',
    'Could not get the AI summary: {error}',
    'تعذّر الحصول على ملخّص الذكاء الاصطناعي: {error}',
  ),
  'aia.summary_title': ('AI özeti', 'AI summary', 'ملخّص الذكاء الاصطناعي'),
  'aia.regenerate': ('Yeniden oluştur', 'Regenerate', 'إعادة الإنشاء'),

  // AI özet akışı (AiSummaryFlow) — kısa / detaylı.
  'ai.summarize': ('AI özet', 'AI summary', 'ملخّص ذكي'),
  'ai.sum_working': ('Özet hazırlanıyor…', 'Preparing the summary…', 'جارٍ إعداد الملخّص…'),
  'ai.sum_no_text': (
    'Özetlenecek metin bulunamadı.',
    'No text found to summarise.',
    'لم يُعثر على نص لتلخيصه.',
  ),
  'ai.sum_short': ('Kısa özet', 'Short summary', 'ملخّص قصير'),
  'ai.sum_short_hint': (
    'Birkaç cümle — "bu ne anlatıyor"',
    'A few sentences — the gist',
    'بضع جمل — الفكرة العامة',
  ),
  'ai.sum_detailed': ('Detaylı özet', 'Detailed summary', 'ملخّص مفصّل'),
  'ai.sum_detailed_hint': (
    'Bölüm bölüm, önemli sayı ve isimlerle',
    'Section by section, with key figures and names',
    'قسمًا بقسم، مع الأرقام والأسماء المهمة',
  ),
  'ai.sum_truncated': (
    'Belge uzun olduğu için yalnız ilk {n} karakter özetlendi.',
    'The document is long; only the first {n} characters were summarised.',
    'المستند طويل؛ لم يُلخَّص سوى أول {n} حرف.',
  ),
  'ai.sum_prompt_short': (
    'Bu belgeyi Türkçe, KISA özetle: en fazla 4-5 cümle. '
        'Ne anlattığını ve en önemli 2-3 bilgiyi ver. '
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English, SHORT: at most 4-5 sentences. '
        'Say what it is about and give the 2-3 most important facts. '
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية بإيجاز: 4-5 جمل كحد أقصى. '
        'اذكر موضوعه وأهم 2-3 معلومات. '
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'ai.sum_prompt_detailed': (
    'Bu belgeyi Türkçe, DETAYLI özetle. Biçim:\n'
        '1) Tek cümlelik "bu ne belgesi" tanımı\n'
        '2) Bölüm bölüm (slayt/başlık sırasıyla) madde madde özet — metinde '
        'slayt numarası varsa koru\n'
        '3) Önemli sayı, tarih, isim ve kararları ayrı bir başlıkta topla\n'
        'Uydurma bilgi ekleme; belgede yoksa yazma.',
    'Summarise this document in English, in DETAIL. Format:\n'
        '1) A one-sentence "what kind of document is this"\n'
        '2) A section-by-section (slide/heading order) bullet summary — keep '
        'slide numbers if the text has them\n'
        '3) A separate heading collecting key figures, dates, names and decisions\n'
        'Do not invent anything; if it is not in the document, leave it out.',
    'لخّص هذا المستند بالعربية بالتفصيل. الصيغة:\n'
        '1) جملة واحدة تصف «ما نوع هذا المستند»\n'
        '2) ملخّص بالنقاط قسمًا بقسم (بترتيب الشرائح/العناوين) — واحتفظ بأرقام '
        'الشرائح إن وُجدت في النص\n'
        '3) عنوان منفصل يجمع الأرقام والتواريخ والأسماء والقرارات المهمة\n'
        'لا تختلق أي معلومة؛ وما ليس في المستند لا تكتبه.',
  ),
  'aia.reading_doc': ('Belge okunuyor…', 'Reading the document…', 'جارٍ قراءة المستند…'),
  'aia.reading_image': (
    'Görseldeki metin okunuyor…',
    'Reading the text in the image…',
    'جارٍ قراءة النص في الصورة…',
  ),
  'aia.ocr_failed': (
    'Metin tanınamadı: {error}',
    'Text recognition failed: {error}',
    'فشل التعرّف على النص: {error}',
  ),
  'aia.looks_like': (
    'Bu bir {type} gibi görünüyor',
    'This looks like a {type}',
    'يبدو أن هذا {type}',
  ),
  'aia.image_text': ('Görseldeki metin', 'Text in the image', 'النص في الصورة'),
  'aia.image_no_text': (
    'Bu görselde okunabilir metin bulunamadı.',
    'No readable text was found in this image.',
    'لم يُعثر على نص قابل للقراءة في هذه الصورة.',
  ),
  'aia.move_failed': ('Taşınamadı: {error}', 'Could not move it: {error}', 'تعذّر النقل: {error}'),
  'aia.moved': (
    '“{name}” → Önemli Dosyalar/{folder}',
    '“{name}” → Önemli Dosyalar/{folder}',
    '«{name}» ← Önemli Dosyalar/{folder}',
  ),
  'aia.hints': ('İpuçları: {list}', 'Hints: {list}', 'مؤشرات: {list}'),
  'aia.target_folder': (
    'Önemli Dosyalar/{folder}',
    'Önemli Dosyalar/{folder}',
    'Önemli Dosyalar/{folder}',
  ),

  // ── İndirilenler ekranı ───────────────────────────────────────────────────
  'dls.selected': ('{n} dosya seçildi · ', '{n} files selected · ', 'تم تحديد {n} ملف · '),
  'dls.count_size': ('{n} dosya · {size}', '{n} files · {size}', '{n} ملف · {size}'),
  'dls.untouched': (
    '{n} dosya 6 aydır dokunulmamış · ',
    '{n} files untouched for 6 months · ',
    '{n} ملف لم يُلمس منذ 6 أشهر · ',
  ),
  'dls.last_opened': ('son açılma: {when}', 'last opened: {when}', 'آخر فتح: {when}'),

  // ── Klasör seçici ─────────────────────────────────────────────────────────
  'fp.create_failed': (
    'Klasör oluşturulamadı: {error}',
    'Could not create the folder: {error}',
    'تعذّر إنشاء المجلد: {error}',
  ),
  'fp.no_subfolders': (
    'Bu klasörde alt klasör yok.\n'
        'Aşağıdaki düğmeyle buraya koyabilir ya da üstteki “yeni klasör” ile '
        'bir tane açabilirsiniz.',
    'This folder has no subfolders.\n'
        'Use the button below to put it here, or create one with “new folder” '
        'at the top.',
    'لا توجد مجلدات فرعية داخل هذا المجلد.\n'
        'استخدم الزر بالأسفل لوضعه هنا، أو أنشئ مجلدًا عبر «مجلد جديد» بالأعلى.',
  ),
  'fp.new_folder_default': ('Yeni klasör', 'New folder', 'مجلد جديد'),

  // ── Etiket seçici ─────────────────────────────────────────────────────────
  'tp.new_tag': (
    'Yeni etiket (kişi / grup adı)',
    'New tag (person / group name)',
    'وسم جديد (اسم شخص / مجموعة)',
  ),
  'tp.new_tag_hint': ('Ayşe, İş grubu, Fatura…', 'Alex, Work group, Invoice…', 'أحمد، مجموعة العمل، فاتورة…'),
  'tp.partial': ('{tag} (bazısında)', '{tag} (on some)', '{tag} (على بعضها)'),
  'tp.note': (
    'Etiket dosyanın içine yazılmaz, uygulamanın kendi kaydında durur. Bu '
        'uygulamayla taşıdığında, adını değiştirdiğinde ve çöpten geri '
        'aldığında etiket dosyayla birlikte gider; başka bir uygulamayla '
        'taşırsan gitmez.',
    'The tag is not written inside the file; it lives in this app’s own record. '
        'It follows the file when you move, rename or restore it with this app; '
        'it does not follow if you move it with another app.',
    'لا يُكتب الوسم داخل الملف، بل يبقى في سجل التطبيق نفسه. وهو يتبع الملف عند '
        'نقله أو إعادة تسميته أو استعادته بهذا التطبيق؛ ولا يتبعه إن نقلته '
        'بتطبيق آخر.',
  ),

  // ── Video dönüştürme ──────────────────────────────────────────────────────
  'vt.hw_encoder': ('donanım kodlayıcı', 'hardware encoder', 'مرمّز عتادي'),
  'vt.engine_preparing': ('{engine} hazırlanıyor…', 'preparing the {engine}…', 'جارٍ تحضير {engine}…'),
  'vt.failed': (
    'Video dönüştürülemedi: {error}',
    'Could not convert the video: {error}',
    'تعذّر تحويل الفيديو: {error}',
  ),
  'vt.unreadable_output': (
    'Dönüştürülen video okunamadı (bozuk çıktı) — özgün dosyaya dokunulmadı.',
    'The converted video could not be read (corrupt output) — the original file '
        'was left untouched.',
    'تعذّرت قراءة الفيديو المحوَّل (ناتج تالف) — لم يُمس الملف الأصلي.',
  ),
  'vt.truncated': (
    'Dönüştürme yarıda kalmış: çıktı {out} sn, kaynak {src} sn. Özgün dosyaya '
        'dokunulmadı.',
    'The conversion was cut short: the output is {out} s, the source {src} s. '
        'The original file was left untouched.',
    'انقطع التحويل: الناتج {out} ثانية والمصدر {src} ثانية. لم يُمس الملف الأصلي.',
  ),
  'vt.unsupported': (
    'Video sıkıştırılamadı (biçim desteklenmiyor olabilir).',
    'The video could not be compressed (the format may be unsupported).',
    'تعذّر ضغط الفيديو (قد تكون الصيغة غير مدعومة).',
  ),

  // ── Çöp kutusu ────────────────────────────────────────────────────────────
  'tr.restored': (
    '“{name}” geri yüklendi → {folder}',
    '“{name}” restored → {folder}',
    'تمت استعادة «{name}» ← {folder}',
  ),
  'tr.delete_body': (
    '{n} öğe ({size}) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
    '{n} items ({size}) will be deleted permanently. This cannot be undone.',
    'سيتم حذف {n} عنصر ({size}) نهائيًا. لا يمكن التراجع عن ذلك.',
  ),
  'tr.partial': (
    '{n} öğe silindi, {fail} öğe silinemedi: {first}',
    '{n} items deleted, {fail} could not be deleted: {first}',
    'تم حذف {n} عنصر، وتعذّر حذف {fail}: {first}',
  ),
  'tr.cancelled': (
    'Durduruldu — {n} öğe silindi.',
    'Stopped — {n} items deleted.',
    'تم الإيقاف — حُذف {n} عنصر.',
  ),
  'tr.emptied': (
    'Çöp kutusu boşaltıldı · {n} öğe · {size} yer açıldı.',
    'Trash emptied · {n} items · {size} freed.',
    'تم تفريغ سلة المهملات · {n} عنصر · تم تحرير {size}.',
  ),
  'tr.count_size': ('{n} öğe · {size}', '{n} items · {size}', '{n} عنصر · {size}'),

  // ── Ortak sayaçlar ────────────────────────────────────────────────────────
  'count.files': ('{n} dosya', '{n} files', '{n} ملف'),
  'count.files_size': ('{n} dosya · {size}', '{n} files · {size}', '{n} ملف · {size}'),
  'count.of_files': ('{shown} / {total} dosya', '{shown} / {total} files', '{shown} / {total} ملف'),
  'count.more_files': ('… ve {n} dosya daha', '… and {n} more files', '… و{n} ملف آخر'),

  // ── Yer açma (onay ve düğme) ──────────────────────────────────────────────
  'clean.confirm_lead': (
    '{n} öneri · {size} yer açılacak.\n\n',
    '{n} suggestions · {size} will be freed.\n\n',
    '{n} اقتراح · سيتم تحرير {size}.\n\n',
  ),
  'clean.confirm_tail': (
    'Dosyalar çöp kutusuna taşınır; oradan geri alabilirsiniz.',
    'The files are moved to the trash; you can restore them from there.',
    'تُنقل الملفات إلى المهملات؛ ويمكنك استعادتها من هناك.',
  ),

  // ── Bellek analizi ────────────────────────────────────────────────────────
  'an.trend_days': ('Son {n} günde ', 'In the last {n} days ', 'خلال آخر {n} يومًا '),
  'an.top_growing': (
    'En çok büyüyen: {category} ',
    'Growing fastest: {category} ',
    'الأسرع نموًا: {category} ',
  ),
  'an.free_headline': ('{size} boş', '{size} free', '{size} حر'),
  'an.used_of': (
    '{used} / {total} kullanıldı',
    '{used} / {total} used',
    '{used} / {total} مستخدَم',
  ),
  'an.other_used': ('Sistem ve diğer', 'System & other', 'النظام وغيره'),
  'an.tools': ('Araçlar', 'Tools', 'الأدوات'),
  'an.volume_usage': (
    '{used} / {total} kullanıldı (%{percent}) · {free} boş',
    '{used} / {total} used ({percent}%) · {free} free',
    '{used} / {total} مستخدَم (%{percent}) · {free} حر',
  ),

  // ── İmza kutusu ───────────────────────────────────────────────────────────
  'sp.draw': ('İmzanızı çizin', 'Draw your signature', 'ارسم توقيعك'),

  // ── Word sayfa görünümü ───────────────────────────────────────────────────
  'dv.too_big': (
    'belge çok büyük ({mb} MB)',
    'the document is too large ({mb} MB)',
    'المستند كبير جدًا ({mb} ميغابايت)',
  ),
  'dv.fallback': (
    'Sayfa görünümü açılamadı: {error}\n\nMetin düzenleyiciye geçiliyor.',
    'Could not open the page view: {error}\n\nSwitching to the text editor.',
    'تعذّر فتح عرض الصفحة: {error}\n\nيجري التحويل إلى محرّر النصوص.',
  ),

  // ── Arşiv parolası ────────────────────────────────────────────────────────
  'ap.title': ('Arşiv parolası', 'Archive password', 'كلمة مرور الأرشيف'),
  'ap.wrong': (
    'Parola yanlış. Tekrar deneyin.',
    'Wrong password. Try again.',
    'كلمة المرور خاطئة. حاول مجددًا.',
  ),
  'ap.body': (
    'Bu arşiv parola korumalı.',
    'This archive is password-protected.',
    'هذا الأرشيف محمي بكلمة مرور.',
  ),

  // ── İş şeridi ─────────────────────────────────────────────────────────────
  'jp.title_queued': ('{title} (+{n} işlem daha)', '{title} (+{n} more)', '{title} (+{n} عملية أخرى)'),
  'jp.cancel': ('İptal', 'Cancel', 'إلغاء'),
  'rc.title': ('Eski ↔ yeni karşılaştır', 'Compare old ↔ new', 'مقارنة القديم ↔ الجديد'),
  'rc.old': ('Eski', 'Old', 'القديم'),
  'rc.new': ('Yeni', 'New', 'الجديد'),
  'rc.trash_old': ('Eskiyi sil', 'Delete old', 'حذف القديم'),
  'rc.trash_new': ('Yeniyi sil', 'Delete new', 'حذف الجديد'),
  'rc.keep_both': ('İkisini de tut', 'Keep both', 'الاحتفاظ بكليهما'),
  'rc.keep_all': ('Hepsini tut', 'Keep all', 'الاحتفاظ بالكل'),
  'rc.trash_all_old': ('Hepsinde eskiyi sil', 'Delete all old', 'حذف كل القديم'),
  'rc.confirm_all': (
      '{n} eski dosya çöp kutusuna taşınacak. Yeni küçültülmüş dosyalar kalır.',
      '{n} old files will be moved to the trash. The resized files stay.',
      'سيتم نقل {n} ملفات قديمة إلى المهملات. تبقى الملفات المصغّرة.'),
  'rc.done_snack': ('{n} eski dosya çöp kutusuna taşındı', '{n} old files moved to trash', 'تم نقل {n} ملفات قديمة إلى المهملات'),
  'rc.old_trashed': ('Eski dosya çöp kutusunda', 'The old file is in the trash', 'الملف القديم في المهملات'),
  'rc.new_trashed': ('Yeni dosya silindi', 'The new file was deleted', 'تم حذف الملف الجديد'),
  'rc.open_old': ('Eskiyi aç', 'Open old', 'فتح القديم'),
  'rc.open_new': ('Yeniyi aç', 'Open new', 'فتح الجديد'),
  'rc.empty': ('Karşılaştırılacak dosya yok', 'Nothing to compare', 'لا يوجد ما يمكن مقارنته'),
  'jp.cancelling': ('Durduruluyor…', 'Stopping…', 'جارٍ الإيقاف…'),
  'jp.show': ('Göster', 'Show', 'عرض'),


  // ── İndirme bildirimi ─────────────────────────────────────────────────────
  'dsv.downloading': ('İndiriliyor…', 'Downloading…', 'جارٍ التنزيل…'),
  'dsv.job_name': ('İndirme', 'Download', 'التنزيل'),
  'dsv.speed': ('{speed}/sn', '{speed}/s', '{speed}/ث'),
  // Eklentinin canlı bildirimi: {progress} {networkSpeed} {timeRemaining}
  // eklentinin kendi yer tutucuları (bizim `t()` dokunmaz).
  'dsv.downloading_live': (
    'İndiriliyor · {progress} · {networkSpeed} · kalan {timeRemaining}',
    'Downloading · {progress} · {networkSpeed} · {timeRemaining} left',
    'جارٍ التنزيل · {progress} · {networkSpeed} · متبقٍ {timeRemaining}',
  ),
  'dsv.downloaded': ('İndirildi', 'Downloaded', 'تم التنزيل'),
  'dsv.paused': ('Duraklatıldı', 'Paused', 'متوقف مؤقتًا'),
  'dsv.failed': ('İndirilemedi', 'Download failed', 'فشل التنزيل'),
  'dsv.start_failed': (
    'İndirme başlatılamadı',
    'Could not start the download',
    'تعذّر بدء التنزيل',
  ),

  // ── Sunum ─────────────────────────────────────────────────────────────────
  'ss.exit': ('Çık', 'Exit', 'خروج'),
  'ss.step': (
    '{n} / {total}  ·  adım {step}/{max}',
    '{n} / {total}  ·  step {step}/{max}',
    '{n} / {total}  ·  الخطوة {step}/{max}',
  ),
  'ss.no_text': ('(Metin yok)', '(No text)', '(لا يوجد نص)'),

  // ── Kurulu uygulamalar ────────────────────────────────────────────────────
  'ia.permission_hint': (
    'Açılan ayar sayfasından “Dosya Okuyucu”ya izin verip geri dönün, '
        'sonra yenileyin.',
    'Grant permission to “Dosya Okuyucu” on the settings page that opens, come '
        'back, then refresh.',
    'امنح الإذن لـ «Dosya Okuyucu» في صفحة الإعدادات التي تُفتح، ثم عُد وحدّث.',
  ),

  // ── Boyut düşürme işi ─────────────────────────────────────────────────────
  'ra.media_only': (
    'Boyut düşürme yalnız fotoğraf ve videolarda yapılabilir.',
    'Reducing size only works on photos and videos.',
    'تصغير الحجم متاح للصور والفيديوهات فقط.',
  ),
  'ra.job_one': (
    'Boyut düşürülüyor: {name}',
    'Reducing the size of: {name}',
    'جارٍ تصغير حجم: {name}',
  ),
  'ra.job_many': (
    '{n} dosyanın boyutu düşürülüyor',
    'Reducing the size of {n} files',
    'جارٍ تصغير حجم {n} ملف',
  ),
  'ra.job_one_name': (
    'Boyut düşürme: {name}',
    'Size reduction: {name}',
    'تقليل الحجم: {name}',
  ),
  'ra.job_many_name': (
    '{n} dosyada boyut düşürme',
    'Size reduction of {n} files',
    'تقليل حجم {n} ملفات',
  ),
  'ra.already_running': (
    'Bu işlem zaten sürüyor. Durumu alttaki şeritten ya da “İşlemler” '
        'ekranından izleyebilirsin.',
    'This job is already running. You can follow it from the bar below or the '
        '“Jobs” screen.',
    'هذه العملية جارية بالفعل. يمكنك متابعتها من الشريط بالأسفل أو من شاشة '
        '«العمليات».',
  ),
  'ra.queued': (
    'İşlem kuyruğa alındı; süren iş bitince başlayacak. Durumu “İşlemler” '
        'ekranından izleyebilirsin.',
    'The job is queued; it starts when the running one finishes. You can follow '
        'it from the “Jobs” screen.',
    'أُضيفت العملية إلى الطابور؛ وستبدأ عند انتهاء العملية الجارية. يمكنك '
        'متابعتها من شاشة «العمليات».',
  ),
  'ra.started': (
    'İşlem arka planda başladı. Durumu ve oluşan dosyaları alttaki şeritten ya '
        'da “İşlemler” ekranından görebilirsin.',
    'The job started in the background. You can see its status and the files it '
        'creates from the bar below or the “Jobs” screen.',
    'بدأت العملية في الخلفية. يمكنك رؤية حالتها والملفات الناتجة من الشريط '
        'بالأسفل أو من شاشة «العمليات».',
  ),
  'ra.saved_bytes': ('{size} kazanıldı', '{size} saved', 'تم توفير {size}'),
  'ra.no_gain': ('Kazanç olmadı', 'No gain', 'لا مكسب'),
  'ra.saved_into': ('Kaydedildi: {name}', 'Saved to: {name}', 'حُفظ في: {name}'),
  'ra.stopped_at': (
    'durduruldu ({n}/{total})',
    'stopped ({n}/{total})',
    'تم الإيقاف ({n}/{total})',
  ),
  'ra.saved_to': (
    '{n} klasöre kaydedildi',
    'Saved into {n} folders',
    'حُفظت في {n} مجلد',
  ),
  'ra.failed_count': (
    '{n} dosya küçültülemedi',
    '{n} files could not be shrunk',
    'تعذّر تصغير {n} ملف',
  ),
  'ra.originals_trashed': (
    '{n} özgün çöp kutusunda',
    '{n} originals in the trash',
    '{n} ملف أصلي في سلة المهملات',
  ),
  'ra.frame_losing_kept': (
    '{n} hareketli/çok sayfalı dosyanın aslı korundu',
    'the originals of {n} animated/multi-page files were kept',
    'تم الإبقاء على أصول {n} ملف متحرك/متعدد الصفحات',
  ),

  // ── İlerleme penceresi ────────────────────────────────────────────────────
  'pd.preparing': ('Hazırlanıyor…', 'Preparing…', 'جارٍ التحضير…'),
  'pd.cancel': ('İptal', 'Cancel', 'إلغاء'),

  // ── Arka plandaki iş kuyruğu / bildirimler ────────────────────────────────
  'job.error_generic': ('Bir hata oluştu.', 'Something went wrong.', 'حدث خطأ.'),
  'job.finished': ('Tamamlandı.', 'Completed.', 'اكتمل.'),
  'job.step': ('Adım {n}/{total} · {text}', 'Step {n}/{total} · {text}', 'الخطوة {n}/{total} · {text}'),
  // ── Dosya işlemlerinin ad hâli ve sonuç özeti (2026-10-18, iş sistemi) ──
  'drive.downloading_name': ("Drive'dan indirme", "Download from Drive", "التنزيل من Drive"),
  'trash.emptying_name': ('Çöp kutusunu boşaltma', 'Emptying the trash', 'تفريغ المهملات'),
  'trash.restore_all_name': ('Çöpten geri yükleme', 'Restoring from trash', 'الاستعادة من المهملات'),
  'fm.extracting_name': ('Arşivden çıkarma', 'Extraction', 'الاستخراج'),
  'arc.opening_name': ('Arşivi açma', 'Opening the archive', 'فتح الأرشيف'),
  'apk.extracting_name': ('APK hazırlama', 'APK preparation', 'تحضير APK'),
  'dl.verify_name': ('Dosya özeti denetimi', 'Checksum check', 'فحص المجموع الاختباري'),
  'fm.compare_name': ('Karşılaştırma', 'Comparison', 'المقارنة'),
  'split.name': ('Parçalara bölme', 'Splitting', 'التقسيم'),
  'join.name': ('Parçaları birleştirme', 'Joining', 'الدمج'),
  'fm.deleting_name': ('Silme', 'Deletion', 'الحذف'),
  'fm.trashing_name': ('Çöp kutusuna taşıma', 'Moving to trash', 'النقل إلى المهملات'),
  'fm.copying_important_name': ('Önemli dosyalara kopyalama', 'Copy to important files', 'النسخ إلى الملفات المهمة'),
  'fm.copying_shared_name': ("Paylaşılan'a kopyalama", "Copy to Shared", "النسخ إلى المشترك"),
  'peer.sending_name': ('Yakındaki cihaza gönderme', 'Sending to a nearby device', 'الإرسال إلى جهاز قريب'),
  'fm.empty_scanning_name': ('Boş klasör araması', 'Empty folder search', 'البحث عن المجلدات الفارغة'),
  'org.working_name': ('Otomatik düzenleme', 'Auto-organizing', 'التنظيم التلقائي'),
  'fm.copying_name': ('Kopyalama', 'Copy', 'النسخ'),
  'fm.moving_name': ('Taşıma', 'Move', 'النقل'),
  'fm.copying_external_name': ('{volume} birimine kopyalama', 'Copy to {volume}', 'النسخ إلى {volume}'),
  'fm.zipping_name': ('Sıkıştırma', 'Compression', 'الضغط'),
  'job.op_done_n': ('{n} öğe tamam', '{n} items done', 'اكتمل {n} عنصر'),
  'job.op_skipped': ('{n} atlandı', '{n} skipped', 'تُخطّي {n}'),
  'job.op_errors': ('{n} hata', '{n} errors', '{n} أخطاء'),
  'job.op_created': ('Hazır: {name}', 'Ready: {name}', 'جاهز: {name}'),
  'job.op_items': ('{n} öğe', '{n} items', '{n} عنصر'),
  // Süre birimleri ve kalan süre (bkz. `humanDuration`, `etaText`).
  'dur.sec': ('{n} sn', '{n} s', '{n} ث'),
  'dur.min': ('{n} dk', '{n} min', '{n} د'),
  'dur.hour': ('{n} sa', '{n} h', '{n} س'),
  'job.eta': ('~{time} kaldı', '~{time} left', 'بقي ~{time}'),
  'job.took': ('{time} sürdü', 'took {time}', 'استغرق {time}'),
  'job.more_running': (
    '+{n} işlem daha',
    '+{n} more',
    '+{n} عملية أخرى',
  ),
  'job.channel_name': ('Dosya işlemleri', 'File operations', 'عمليات الملفات'),
  'job.channel_desc': (
    'Yer açma, kopya arama, kopyalama, boyut düşürme gibi süren işlerin ilerlemesi.',
    'Progress of running tasks such as freeing space, finding duplicates, copying and resizing.',
    'تقدّم المهام الجارية مثل تحرير المساحة والبحث عن النسخ والنسخ وتقليل الحجم.',
  ),
  // Biten işin başlığı (bkz. `FmJob.shownTitle`): süren işin "-iyor"
  // başlığı bitince "tamamlandı" kipine döner.
  'job.title_done': ('{name} tamamlandı', '{name} complete', 'اكتمل: {name}'),
  'job.title_failed': ('{name} başarısız oldu', '{name} failed', 'فشل: {name}'),
  'job.title_cancelled': ('{name} durduruldu', '{name} stopped', 'أُوقف: {name}'),
  'job.title_interrupted': (
    '{name} yarıda kaldı',
    '{name} interrupted',
    'انقطع: {name}',
  ),
  'job.stopped_detail': (
    'Durduruldu · {detail}',
    'Stopped · {detail}',
    'تم الإيقاف · {detail}',
  ),

  // ── Sayılabilir değerlerin etiketleri (models/… `labelKey`) ───────────────
  // Buradaki her anahtar bir enum'un `labelKey` getter'ından gelir; saf Dart
  // modeller `AppStrings`'i tanımadığı için etiket metni tek yerde, burada.
  'enum.layout_list': ('Liste', 'List', 'قائمة'),
  'enum.layout_detail': ('Büyük liste', 'Large list', 'قائمة كبيرة'),
  'enum.layout_grid2': ('2 sütun', '2 columns', 'عمودان'),
  'enum.layout_grid3': ('3 sütun', '3 columns', '3 أعمدة'),
  'enum.layout_grid4': ('4 sütun', '4 columns', '4 أعمدة'),
  'enum.layout_grid5': ('5 sütun', '5 columns', '5 أعمدة'),
  'enum.layout_list_desc': (
    'Tek sıra · ad, boyut ve tarih',
    'Single row · name, size and date',
    'صف واحد · الاسم والحجم والتاريخ',
  ),
  'enum.layout_detail_desc': (
    'Tek sıra · büyük önizleme',
    'Single row · large preview',
    'صف واحد · معاينة كبيرة',
  ),
  'enum.layout_grid2_desc': ('En büyük kareler', 'Largest tiles', 'أكبر المربعات'),
  'enum.layout_grid3_desc': (
    'Dengeli — varsayılan',
    'Balanced — default',
    'متوازن — الافتراضي',
  ),
  'enum.layout_grid4_desc': ('Daha çok dosya sığar', 'Fits more files', 'يتّسع لملفات أكثر'),
  'enum.layout_grid5_desc': ('En yoğun görünüm', 'Densest view', 'أكثف عرض'),

  'enum.photo_group_day': ('Gün', 'Day', 'يوم'),
  'enum.photo_group_month': ('Ay', 'Month', 'شهر'),
  'enum.photo_group_year': ('Yıl', 'Year', 'سنة'),

  'enum.open_with_ask': ('Her seferinde sor', 'Ask every time', 'اسأل في كل مرة'),
  'enum.open_with_in_app': (
    'Uygulama içi oynatıcı',
    'In-app player',
    'المشغّل داخل التطبيق',
  ),
  'enum.open_with_external': ('Başka uygulama', 'Another app', 'تطبيق آخر'),
  'enum.open_with_ask_desc': (
    'Video/ses/görsel açarken hangisini kullanacağın sorulur',
    'You are asked which one to use when opening video/audio/images',
    'يُسألك أيّهما تستخدم عند فتح فيديو/صوت/صورة',
  ),
  'enum.open_with_in_app_desc': (
    'Dosyalar bu uygulamanın oynatıcısında açılır',
    'Files open in this app’s player',
    'تُفتح الملفات في مشغّل هذا التطبيق',
  ),
  'enum.open_with_external_desc': (
    'Telefonundaki varsayılan oynatıcı/galeri açılır',
    'Your phone’s default player/gallery opens',
    'يُفتح المشغّل/المعرض الافتراضي في هاتفك',
  ),

  'enum.cat_folder': ('Klasör', 'Folder', 'مجلد'),
  'enum.cat_image': ('Görüntüler', 'Images', 'الصور'),
  'enum.cat_video': ('Videolar', 'Videos', 'الفيديوهات'),
  'enum.cat_audio': ('Ses', 'Audio', 'الصوت'),
  'enum.cat_document': ('Belgeler', 'Documents', 'المستندات'),
  'enum.cat_archive': ('Arşivler', 'Archives', 'الأرشيفات'),
  // "Uygulamalar" DEĞİL: bu, depolamada bulunan .apk/.bak KURULUM
  // DOSYALARI; yüklü uygulamalar ayrı bir kart. İkisi aynı adı
  // taşıyınca kullanıcı "49 GB mı 85 MB mı" diye takıldı (2026-08-05).
  'enum.cat_apk': (
    'Kurulum dosyaları',
    'Installer files',
    'ملفات التثبيت',
  ),
  'enum.cat_other': ('Diğer', 'Other', 'أخرى'),

  'enum.sort_name': ('Ada göre', 'By name', 'حسب الاسم'),
  'enum.sort_date': ('Tarihe göre', 'By date', 'حسب التاريخ'),
  'enum.sort_size': ('Boyuta göre', 'By size', 'حسب الحجم'),
  'enum.sort_type': ('Türe göre', 'By type', 'حسب النوع'),

  // ── Kağıt teması turu (2026-08-04 tasarım devir notu) ────────────────────
  'fm.search_all': (
    'Tüm dosyalarda ara',
    'Search all files',
    'ابحث في كل الملفات',
  ),
  'fm.free_bytes': ('{v} boş', '{v} free', '{v} متاح'),
  'fm.storage_free': ('Boş', 'Free', 'متاح'),
  'recent.group_today': ('Bugün', 'Today', 'اليوم'),
  'recent.group_week': ('Bu hafta', 'This week', 'هذا الأسبوع'),
  'recent.group_older': ('Daha önce', 'Earlier', 'قبل ذلك'),
  'recent.show_path': ('Yolu göster', 'Show path', 'إظهار المسار'),
  'recent.remove': ('Listeden kaldır', 'Remove from list', 'إزالة من القائمة'),
  'chat.context_badge': ('Bağlam: {f}', 'Context: {f}', 'السياق: {f}'),
  'chat.pick_context': (
    'Bağlam dosyası seç',
    'Choose a context file',
    'اختر ملف السياق',
  ),
  'chat.quick_slides': (
    'Slayt planı çıkar',
    'Draft a slide plan',
    'أعدّ خطة شرائح',
  ),
  'chat.quick_slides_prompt': (
    'Bu içerikten bir sunum planı çıkar: her slayt için kısa bir başlık ve '
        'en fazla üç madde yaz.',
    'Draft a slide plan from this content: a short title and at most three '
        'bullets per slide.',
    'أعدّ خطة عرض تقديمي من هذا المحتوى: عنوان قصير وثلاث نقاط كحد أقصى لكل شريحة.',
  ),
  'cat.summary': (
    '{n} / {total} dosya · {sort}',
    '{n} / {total} files · {sort}',
    '{n} / {total} ملف · {sort}',
  ),
  'trash.auto_days': (
    '{n} gün sonra kendiliğinden silinir',
    'Deleted automatically after {n} days',
    'يُحذف تلقائيًا بعد {n} يومًا',
  ),
  'trash.auto_off': (
    'Otomatik temizleme kapalı',
    'Auto-cleanup is off',
    'التنظيف التلقائي متوقف',
  ),
  'trash.restore_all': ('Tümünü geri yükle', 'Restore all', 'استعادة الكل'),
  'trash.restore_all_done': (
    '{n} öğe geri yüklendi',
    '{n} items restored',
    'تمت استعادة {n} عنصرًا',
  ),
  'jobs.files_progress': (
    '{done}/{total} dosya',
    '{done}/{total} files',
    '{done}/{total} ملف',
  ),
  'jobs.outputs': (
    'Oluşan dosyalar ({n})',
    'Files created ({n})',
    'الملفات الناتجة ({n})',
  ),
  'set.key_valid': (
    'Anahtar geçerli · {n} model bulundu',
    'Key is valid · {n} models found',
    'المفتاح صالح · تم العثور على {n} نموذجًا',
  ),
  'set.key_invalid': (
    'Anahtar doğrulanamadı',
    'Key could not be verified',
    'تعذّر التحقق من المفتاح',
  ),
  'set.search_hint': ('Ayarlarda ara', 'Search settings', 'ابحث في الإعدادات'),
  'set.no_match': (
    'Eşleşen ayar yok',
    'No matching setting',
    'لا توجد إعدادات مطابقة',
  ),

  // ── Ayarlar: sekiz kategori (2026-08-09 yeniden tasarım) ────────────────
  // Kullanıcı: "ayarlar kısmımız çok karıştı her yer her yerde tamamen 0 dan
  // tasarlanmalı". Ayarlar iki ekrandan tek ekrana, sekiz kategoriye indi;
  // aşağıdaki anahtarlar o yerleşimin adlarıdır.
  'set.search_all': (
    'Tüm ayarlarda ara',
    'Search all settings',
    'ابحث في كل الإعدادات',
  ),
  'set.key_missing': (
    'Anahtar girilmedi',
    'No key entered',
    'لم يتم إدخال مفتاح',
  ),
  'set.cat_appearance': ('Görünüm ve dil', 'Appearance & language', 'المظهر واللغة'),
  'set.cat_appearance_sub': (
    'Tema, yazı tipi, yazı boyutu ve arayüz dili',
    'Theme, font, text size and interface language',
    'السمة والخط وحجم النص ولغة الواجهة',
  ),
  'set.cat_browsing': ('Dosya listeleri', 'File lists', 'قوائم الملفات'),
  'set.cat_browsing_sub': (
    'Yerleşim, sıralama, küçük resimler, açılış klasörü',
    'Layout, sorting, thumbnails, start folder',
    'التخطيط والترتيب والصور المصغّرة ومجلد البدء',
  ),
  'set.cat_ai': ('Yapay zekâ', 'Artificial intelligence', 'الذكاء الاصطناعي'),
  'set.cat_ai_sub': (
    'Gemini anahtarı, model ve kalıcı hafıza',
    'Gemini key, model and long-term memory',
    'مفتاح Gemini والنموذج والذاكرة الدائمة',
  ),
  'set.cat_privacy': ('Gizlilik ve izinler', 'Privacy & permissions', 'الخصوصية والأذونات'),
  'set.cat_privacy_sub': (
    'Klasör kilidi ve uygulamanın aldığı izinler',
    'Folder lock and the permissions the app holds',
    'قفل المجلدات وأذونات التطبيق',
  ),
  'set.cat_trash': ('Silme ve çöp kutusu', 'Deleting & trash', 'الحذف وسلة المهملات'),
  'set.cat_trash_sub': (
    'Silinen dosyaya ne olacağı ve çöp kutusu bakımı',
    'What happens to deleted files, and trash upkeep',
    'ما يحدث للملفات المحذوفة وصيانة السلة',
  ),
  'set.cat_perf': ('Pil, hız ve bakım', 'Battery, speed & upkeep', 'البطارية والسرعة والصيانة'),
  'set.cat_perf_sub': (
    'Tazeleme hızı, otomatik tarama, arama dizini, önbellek',
    'Refresh rate, auto scan, search index, cache',
    'معدل التحديث والفحص التلقائي وفهرس البحث والذاكرة المؤقتة',
  ),
  // ── Ayarların 2026-08-29 yeniden tasarımı ───────────────────────────────
  'set.cat_reading': ('Okuma ve sesli okuma', 'Reading & speech', 'القراءة والنطق'),
  'set.cat_reading_sub': (
    'Sesli okuma sesi, hızı ve AI yanıtlarının okunması',
    'Speech voice, speed and reading AI answers aloud',
    'صوت النطق وسرعته وقراءة إجابات الذكاء الاصطناعي',
  ),
  'set.cat_storage': ('Depolama ve başarım', 'Storage & performance', 'التخزين والأداء'),
  'set.cat_storage_sub': (
    'Çöp kutusu, silme onayı, hız ve bakım',
    'Trash, delete confirmation, speed and upkeep',
    'سلة المهملات وتأكيد الحذف والسرعة والصيانة',
  ),
  'set.sec_tts': ('Sesli okuma', 'Speech', 'النطق'),
  'set.tts_voice': ('Ses ve hız', 'Voice and speed', 'الصوت والسرعة'),
  'set.tts_voice_sub': (
    'Cihazdaki sesler arasından seç, hız ve perdeyi ayarla (dinleyerek)',
    'Pick from the voices on your device, set speed and pitch (with preview)',
    'اختر من أصوات جهازك واضبط السرعة والطبقة (مع معاينة)',
  ),
  'set.tts_default_voice': ('Cihaz varsayılanı', 'Device default', 'افتراضي الجهاز'),
  'set.tts_summary': ('Sesli okuma {x}x', 'Speech {x}x', 'النطق {x}x'),
  'set.tts_ai_read': (
    'AI yanıtlarını sesli oku',
    'Read AI answers aloud',
    'اقرأ إجابات الذكاء الاصطناعي بصوت',
  ),
  'set.tts_ai_read_sub': (
    'Yanıt gelir gelmez okunmaya başlar',
    'Starts speaking as soon as the answer arrives',
    'يبدأ النطق فور وصول الإجابة',
  ),
  'set.sec_advanced': ('Gelişmiş', 'Advanced', 'إعدادات متقدمة'),
  'set.sec_experimental': ('Deneysel', 'Experimental', 'تجريبي'),
  'dev.title': ('Geliştirici', 'Developer', 'المطوّر'),
  'dev.sub': ('Teşhis araçları', 'Diagnostic tools', 'أدوات التشخيص'),
  'dev.on': ('Açık', 'On', 'مفعّل'),
  'dev.enabled': ('Geliştirici menüsü açıldı — Ayarlar\'ın en altında', 'Developer menu enabled — at the bottom of Settings', 'تم تفعيل قائمة المطوّر — أسفل الإعدادات'),
  'dev.turn_off': ('Geliştirici menüsünü kapat', 'Turn off developer menu', 'إيقاف قائمة المطوّر'),
  'set.advanced_hint': (
    'Nadiren gerekir — bir kez ayarlanır',
    'Rarely needed — set once',
    'نادرًا ما تحتاجها — تُضبط مرة واحدة',
  ),
  'set.trash_off': ('Kalıcı silme', 'Delete permanently', 'حذف نهائي'),
  'set.refresh_60': ('60 Hz', '60 Hz', '60 هرتز'),
  'set.ai_no_key': ('Anahtar yok', 'No key', 'لا يوجد مفتاح'),
  'set.ai_key_count': ('{n} anahtar', '{n} keys', '{n} مفتاح'),
  'set.api_key_sub': (
    'Gemini API anahtarınız — cihazda saklanır',
    'Your Gemini API key — stored on the device',
    'مفتاح Gemini الخاص بك — يُحفظ على الجهاز',
  ),
  'set.results_count': ('{n} sonuç', '{n} results', '{n} نتيجة'),
  // Aramanın yakaladığı eşanlamlar (ekranda GÖRÜNMEZ, yalnız arama içindir).
  'set.kw_dark': ('karanlık gece dark night', 'dark night mode', 'وضع داكن ليلي'),
  'set.kw_font': ('yazı tipi punto büyüklük font size', 'font typeface size', 'الخط الحجم'),
  'set.kw_speak': ('sesli oku konuş seslendir tts speech', 'speak voice tts read aloud', 'نطق صوت قراءة'),
  'set.kw_gemini': ('gemini api anahtar token', 'gemini api key token', 'مفتاح gemini'),
  'set.kw_days': ('gün süre otomatik days', 'days auto period', 'أيام تلقائي'),
  'set.sec_theme': ('Tema', 'Theme', 'السمة'),

  'ftpd.qr_hint': (
    'Bilgisayarın ya da başka bir telefonun kamerasıyla okut — tarayıcıda dosyaların açılır.',
    'Scan with a computer or another phone\'s camera — your files open in the browser.',
    'امسح بكاميرا الحاسوب أو هاتف آخر — تُفتح ملفاتك في المتصفح.',
  ),
  'ftpd.upload_hint': (
    'Bilgisayardan telefona: sayfadaki "Telefona gönder" ile seçilen dosyalar İndirilenler/Bilgisayardan klasörüne gelir.',
    'Computer to phone: files sent with "Telefona gönder" on the page arrive in Download/Bilgisayardan.',
    'من الحاسوب إلى الهاتف: تصل الملفات المرسلة عبر "Telefona gönder" إلى Download/Bilgisayardan.',
  ),
  // ── anılar (2026-10-18) ─────────────────────────────────────────────────
  'mem.title': ('Anılar', 'Memories', 'الذكريات'),
  'mem.tab_day': ('Bu gün', 'On this day', 'في مثل هذا اليوم'),
  'mem.tab_places': ('Yerler', 'Places', 'الأماكن'),
  'mem.scanning': ('Fotoğraflar okunuyor… {n}/{total}', 'Reading photos… {n}/{total}', 'جارٍ قراءة الصور… {n}/{total}'),
  'mem.loading': ('Fotoğraflar inceleniyor…', 'Looking through photos…', 'جارٍ فحص الصور…'),
  'mem.day_empty': (
    'Geçmiş yıllarda bugün çekilmiş fotoğraf yok. Yarın yeniden bak!',
    'No photos from this day in past years. Check again tomorrow!',
    'لا صور من هذا اليوم في السنوات الماضية. عد غداً!',
  ),
  'mem.years_ago': ('{n} yıl önce bugün · {year} · {count} fotoğraf', '{n} years ago today · {year} · {count} photos', 'قبل {n} سنوات اليوم · {year} · {count} صورة'),
  'mem.places_empty': (
    'Konum bilgisi taşıyan fotoğraf bulunamadı (kameranın konum etiketi kapalı olabilir).',
    'No photos with location found (the camera\'s location tag may be off).',
    'لم يُعثر على صور بموقع (قد يكون وسم الموقع في الكاميرا معطلاً).',
  ),
  'mem.place_unknown': ('Yer {n}', 'Place {n}', 'مكان {n}'),
  'mem.n_photos': ('{n} fotoğraf', '{n} photos', '{n} صورة'),
  // ── şifreli kasa (2026-10-18) ───────────────────────────────────────────
  'vault.title': ('Şifreli kasa', 'Encrypted vault', 'الخزنة المشفرة'),
  'vault.pin_use_lock': ('Klasör kilidinin PIN\'ini girin — kasa aynı PIN\'i kullanır', 'Enter your folder lock PIN — the vault uses the same PIN', 'أدخل رمز قفل المجلدات — الخزنة تستخدم الرمز نفسه'),
  'vault.pin_same_existing': ('Kasa, klasör ve uygulama kilidiyle aynı PIN\'i kullanır: mevcut PIN\'inizi girin.', 'The vault uses the same PIN as folder and app lock: enter your current PIN.', 'تستخدم الخزنة رمز قفل المجلدات والتطبيق نفسه: أدخل رمزك الحالي.'),
  'vault.pin_same_new': ('Bu PIN klasör ve uygulama kilidi için de kullanılır.', 'This PIN is also used for folder and app lock.', 'يُستخدم هذا الرمز أيضًا لقفل المجلدات والتطبيق.'),
  'vault.legacy_title': ('{n} gizli öğe şifresiz duruyor', '{n} hidden items are not encrypted', '{n} عنصرًا مخفيًا غير مشفّر'),
  'vault.legacy_body': ('Eski "Gizli dosyalar" yalnız saklıyordu; telefon bilgisayara bağlanınca görünürler. Kasaya taşıyınca şifrelenirler — her dosya önce şifrelenip doğrulanır, sonra aslı silinir.', 'Old "Hidden files" were only tucked away; they show up when the phone is connected to a computer. Moving them into the vault encrypts them — each file is encrypted and verified before the original is deleted.', 'كانت "الملفات المخفية" القديمة مخفية فقط وتظهر عند توصيل الهاتف بحاسوب. نقلها إلى الخزنة يشفّرها — يُشفَّر كل ملف ويُتحقق منه قبل حذف الأصل.'),
  'vault.legacy_move': ('Kasaya taşı', 'Move into vault', 'انقل إلى الخزنة'),
  'vault.legacy_show': ('Listeyi gör', 'See the list', 'اعرض القائمة'),
  'vault.move': ('Şifreli kasaya taşı', 'Move to encrypted vault', 'انقل إلى الخزنة المشفرة'),
  'vault.move_hint': (
    'İçerik şifrelenir; PIN ya da parmak izi olmadan açılmaz',
    'Content is encrypted; opens only with PIN or fingerprint',
    'يُشفَّر المحتوى؛ لا يُفتح إلا برمز PIN أو البصمة',
  ),
  'vault.move_n': ('{n} dosyayı kasaya taşı', 'Move {n} files to vault', 'انقل {n} ملفات إلى الخزنة'),
  'vault.pick_title': ('Kasaya eklenecekler', 'Choose files for the vault', 'اختر ملفات للخزنة'),
  'vault.setup_title': ('Şifreli kasa kur', 'Set up the encrypted vault', 'إعداد الخزنة المشفرة'),
  'vault.setup_body': (
    'Kimlik, tapu, sözleşme gibi belgeler AES-256 ile şifrelenerek saklanır. Telefon bilgisayara bağlansa ya da başka bir uygulamayla bakılsa da okunamaz.',
    'Documents like IDs, deeds and contracts are stored encrypted with AES-256. They stay unreadable even if the phone is connected to a computer.',
    'تُحفظ المستندات مثل الهوية والعقود مشفرة بـ AES-256، ولا يمكن قراءتها حتى عند توصيل الهاتف بالحاسوب.',
  ),
  'vault.pin': ('Kasa PIN\'i', 'Vault PIN', 'رمز الخزنة'),
  'vault.pin_again': ('PIN\'i tekrar yaz', 'Repeat PIN', 'أعد إدخال الرمز'),
  'vault.pin_short': ('PIN en az 4 haneli olmalı', 'PIN must be at least 4 digits', 'يجب أن يتكون الرمز من 4 أرقام على الأقل'),
  'vault.pin_mismatch': ('İki PIN aynı değil', 'The PINs do not match', 'الرمزان غير متطابقين'),
  'vault.pin_warning': (
    'Önemli: PIN unutulursa kasadaki dosyalar KURTARILAMAZ — şifre çözülemez, bunu biz de yapamayız. Parmak izi yalnız bu telefonda kısayoldur; PIN\'i bir yere not et.',
    'Important: if the PIN is forgotten the files CANNOT be recovered — nobody, including us, can decrypt them. Fingerprint is a shortcut on this phone only; note your PIN somewhere safe.',
    'مهم: إذا نُسي الرمز فلا يمكن استعادة الملفات — لا أحد يستطيع فك التشفير. البصمة اختصار على هذا الهاتف فقط؛ احفظ الرمز.',
  ),
  'vault.create': ('Kasayı kur', 'Create vault', 'إنشاء الخزنة'),
  'vault.locked_title': ('Kasa kilitli', 'Vault is locked', 'الخزنة مقفلة'),
  'vault.locked_body': (
    'Açmak için PIN\'ini gir ya da parmak izini kullan.',
    'Enter your PIN or use your fingerprint to open.',
    'أدخل الرمز أو استخدم البصمة للفتح.',
  ),
  'vault.unlock': ('Kilidi aç', 'Unlock', 'افتح القفل'),
  'vault.unlock_bio': ('Parmak iziyle aç', 'Unlock with fingerprint', 'افتح بالبصمة'),
  'vault.bio_prompt': ('Kasayı açmak için doğrula', 'Verify to open the vault', 'تحقق لفتح الخزنة'),
  'vault.use_pin': ('PIN kullan', 'Use PIN', 'استخدم الرمز'),
  'vault.bio_failed': ('Parmak iziyle açılamadı — PIN\'i kullan', 'Could not open with fingerprint — use your PIN', 'تعذر الفتح بالبصمة — استخدم الرمز'),
  'vault.bio_toggle': ('Parmak iziyle aç', 'Unlock with fingerprint', 'الفتح بالبصمة'),
  'vault.wrong_pin': ('PIN yanlış', 'Wrong PIN', 'رمز خاطئ'),
  'vault.lock': ('Kilitle', 'Lock', 'قفل'),
  'vault.add': ('Kasaya ekle', 'Add to vault', 'أضف إلى الخزنة'),
  'vault.adding': ('Şifreleniyor…', 'Encrypting…', 'جارٍ التشفير…'),
  'vault.added_n': ('{n} dosya şifrelenip kasaya taşındı', '{n} files encrypted into the vault', 'تم تشفير {n} ملفات ونقلها إلى الخزنة'),
  'vault.summary': ('{n} şifreli dosya', '{n} encrypted files', '{n} ملفات مشفرة'),
  'vault.encrypted_note': (
    'AES-256 · ekrandan çıkınca ve uygulama arka plana geçince kilitlenir',
    'AES-256 · locks when you leave or the app goes to background',
    'AES-256 · تُقفل عند المغادرة أو انتقال التطبيق للخلفية',
  ),
  'vault.empty': (
    'Kasa boş. Aşağıdaki düğmeyle ya da gezginde bir dosyaya basılı tutup "Şifreli kasaya taşı" ile ekle.',
    'The vault is empty. Add files with the button below, or long-press a file in the browser and choose "Move to encrypted vault".',
    'الخزنة فارغة. أضف ملفات بالزر أدناه أو اضغط مطولاً على ملف واختر "انقل إلى الخزنة المشفرة".',
  ),
  'vault.restore': ('Kasadan çıkar', 'Take out of vault', 'أخرج من الخزنة'),
  'vault.restore_sub': ('Şifresi çözülüp eski klasörüne döner', 'Decrypted back to its original folder', 'يُفك تشفيره ويعود إلى مجلده'),
  'vault.restored': ('Kasadan çıkarıldı: {path}', 'Taken out: {path}', 'أُخرج: {path}'),
  'vault.delete': ('Kalıcı olarak sil', 'Delete permanently', 'حذف نهائي'),
  'vault.delete_body': ('"{name}" kasadan kalıcı olarak silinsin mi? Geri alınamaz.', 'Permanently delete "{name}" from the vault? This cannot be undone.', 'حذف "{name}" نهائياً؟ لا يمكن التراجع.'),
  'vault.open_failed': ('Açılamadı: {error}', 'Could not open: {error}', 'تعذر الفتح: {error}'),
  // ── faturalar ve giderler (2026-10-18) ────────────────────────────────
  'bills.month_1': ('Ocak', 'January', 'يناير'),
  'bills.month_2': ('Şubat', 'February', 'فبراير'),
  'bills.month_3': ('Mart', 'March', 'مارس'),
  'bills.month_4': ('Nisan', 'April', 'أبريل'),
  'bills.month_5': ('Mayıs', 'May', 'مايو'),
  'bills.month_6': ('Haziran', 'June', 'يونيو'),
  'bills.month_7': ('Temmuz', 'July', 'يوليو'),
  'bills.month_8': ('Ağustos', 'August', 'أغسطس'),
  'bills.month_9': ('Eylül', 'September', 'سبتمبر'),
  'bills.month_10': ('Ekim', 'October', 'أكتوبر'),
  'bills.month_11': ('Kasım', 'November', 'نوفمبر'),
  'bills.month_12': ('Aralık', 'December', 'ديسمبر'),
  'bills.title': ('Faturalar ve giderler', 'Bills and expenses', 'الفواتير والمصاريف'),
  'bills.tile_sub': ('Aylık özet, son ödeme', 'Monthly summary, due dates', 'ملخص شهري ومواعيد'),
  'bills.refresh': ('Faturaları yeniden oku', 'Re-read bills', 'أعد قراءة الفواتير'),
  'bills.reading': ('Faturalar okunuyor… {n}/{total}', 'Reading bills… {n}/{total}', 'جارٍ قراءة الفواتير… {n}/{total}'),
  'bills.read_n': ('{n} fatura okundu', '{n} bills read', 'تمت قراءة {n} فاتورة'),
  'bills.read_pending': ('{n} yeni faturayı oku', 'Read {n} new bills', 'اقرأ {n} فاتورة جديدة'),
  'bills.this_month': ('Bu ayın giderleri', 'This month\'s expenses', 'مصاريف هذا الشهر'),
  'bills.count_month': ('{n} fatura/makbuz', '{n} bills/receipts', '{n} فاتورة/إيصال'),
  'bills.no_key': (
    'Gemini API anahtarı olmadan tutar ve tarihler cihazda metinden tahmin ediliyor; anahtar girersen daha isabetli okunur.',
    'Without a Gemini API key, amounts and dates are guessed on the device; add a key for more accurate reading.',
    'بدون مفتاح Gemini تُقدَّر المبالغ والتواريخ على الجهاز؛ أضف مفتاحاً لقراءة أدق.',
  ),
  'bills.upcoming': ('Son ödemesi yaklaşanlar', 'Due soon', 'مستحقة قريباً'),
  'bills.empty': (
    'Henüz fatura bulunamadı. AI analizi faturaları ve makbuzları tanıdıkça burada aylık özetleri görünecek.',
    'No bills found yet. As AI analysis recognises bills and receipts, monthly summaries appear here.',
    'لم يُعثر على فواتير بعد. ستظهر الملخصات الشهرية مع تحليل الفواتير.',
  ),
  'bills.due': ('son ödeme {date}', 'due {date}', 'الاستحقاق {date}'),
  'bills.overdue': ('son ödeme GEÇTİ ({date})', 'OVERDUE ({date})', 'متأخرة ({date})'),
  'bills.unknown': ('Kurum bilinmiyor', 'Unknown issuer', 'جهة غير معروفة'),
  'bills.no_amount': ('tutar okunamadı', 'amount not found', 'لم يُقرأ المبلغ'),
  'bills.paid': ('Ödendi', 'Paid', 'مدفوعة'),
  // ── yerel ekler: bildirim ve widget metinleri ───────────────────────────
  'nx.channel': ('Hatırlatmalar ve öneriler', 'Reminders and suggestions', 'التذكيرات والاقتراحات'),
  'nx.bill_title': ('Fatura son ödeme: {title}', 'Bill due: {title}', 'استحقاق فاتورة: {title}'),
  'nx.bill_body': ('{amount} · {days} gün kaldı', '{amount} · {days} days left', '{amount} · بقي {days} أيام'),
  'nx.bill_today': ('{amount} · son gün BUGÜN', '{amount} · due TODAY', '{amount} · الاستحقاق اليوم'),
  'nx.bill_overdue': ('{amount} · son ödeme tarihi geçti', '{amount} · past due', '{amount} · فات الموعد'),
  'nx.clean_title': ('Haftalık temizlik zamanı', 'Weekly clean-up time', 'وقت التنظيف الأسبوعي'),
  'nx.clean_body': ('Depolama %{pct} dolu — gereksiz dosyalara göz atmak için dokun', 'Storage {pct}% full — tap to review unneeded files', 'التخزين ممتلئ {pct}% — اضغط لمراجعة الملفات غير الضرورية'),
  'nx.clean_body_found': ('Depolama %{pct} dolu · son taramada {size} gereksiz dosya bulundu', 'Storage {pct}% full · {size} of unneeded files found last time', 'التخزين ممتلئ {pct}% · وُجد {size} ملفات غير ضرورية'),
  'nx.w_free': ('{v} boş', '{v} free', '{v} متاح'),
  'nx.w_scan': ('Tara', 'Scan', 'مسح'),
  'nx.w_empty': ('Henüz açılan dosya yok', 'No opened files yet', 'لا ملفات مفتوحة بعد'),
  'nx.weekly': ('Haftalık temizlik önerisi', 'Weekly clean-up suggestion', 'اقتراح التنظيف الأسبوعي'),
  'nx.weekly_sub': (
    'Depolama dolmaya başlayınca haftada bir bildirim (uygulama kapalıyken de)',
    'A weekly notification when storage fills up (even when the app is closed)',
    'إشعار أسبوعي عند امتلاء التخزين (حتى عند إغلاق التطبيق)',
  ),
  // ── akıllı klasörler (2026-10-18) ──────────────────────────────────────
  'smart.title': ('Akıllı klasörler', 'Smart folders', 'المجلدات الذكية'),
  'smart.create': ('Yeni akıllı klasör', 'New smart folder', 'مجلد ذكي جديد'),
  'smart.query_hint': (
    'Ne aransın? (örn. fatura, kimlik, sözleşme)',
    'What to look for? (e.g. invoice, ID, contract)',
    'ماذا تبحث؟ (مثلاً فاتورة، هوية، عقد)',
  ),
  'smart.save': ('Akıllı klasör olarak kaydet', 'Save as smart folder', 'احفظ كمجلد ذكي'),
  'smart.saved': (
    '"{name}" akıllı klasörü oluşturuldu — yeni dosyalar kendiliğinden eklenecek',
    'Smart folder "{name}" created — new files will be added automatically',
    'تم إنشاء المجلد الذكي "{name}" — ستُضاف الملفات الجديدة تلقائياً',
  ),
  'smart.empty': ('Henüz akıllı klasör yok', 'No smart folders yet', 'لا توجد مجلدات ذكية بعد'),
  'smart.empty_sub': (
    'AI sohbetinde bir şey sor ve cevabın altındaki "Akıllı klasör olarak kaydet"e bas — ya da aşağıdan yeni bir tane oluştur. Analiz edilen yeni dosyalar kendiliğinden içeri girer.',
    'Ask something in AI chat and tap "Save as smart folder" under the answer, or create one below. Newly analysed files join automatically.',
    'اسأل شيئاً في محادثة الذكاء الاصطناعي واضغط "احفظ كمجلد ذكي"، أو أنشئ واحداً أدناه. تنضم الملفات الجديدة تلقائياً.',
  ),
  'smart.count_folders': ('{n} klasör', '{n} folders', '{n} مجلد'),
  'smart.count': ('{n} dosya', '{n} files', '{n} ملف'),
  'smart.new_n': ('{n} yeni', '{n} new', '{n} جديد'),
  'smart.new_badge': ('Yeni', 'New', 'جديد'),
  'smart.header': (
    '"{query}" araması · {n} dosya · {size} — AI analizindeki eşleşmeler, kendiliğinden güncellenir.',
    'Search "{query}" · {n} files · {size} — matches from AI analysis, kept up to date automatically.',
    'بحث "{query}" · {n} ملف · {size} — تتحدث تلقائياً.',
  ),
  'smart.no_items': (
    'Şu an eşleşen dosya yok. AI analizi yeni dosyaları taradıkça burada görünecek.',
    'No matching files yet. They will appear as AI analysis covers new files.',
    'لا توجد ملفات مطابقة بعد. ستظهر مع تحليل ملفات جديدة.',
  ),
  'smart.rename': ('Yeniden adlandır', 'Rename', 'إعادة التسمية'),
  'smart.delete': ('Akıllı klasörü sil', 'Delete smart folder', 'حذف المجلد الذكي'),
  'smart.delete_body': (
    'Yalnız kayıtlı arama silinir; dosyaların kendisine dokunulmaz.',
    'Only the saved search is removed; your files are untouched.',
    'يُحذف البحث المحفوظ فقط؛ لا تُمس ملفاتك.',
  ),
  // ── alt çubuk kısayolları (2026-10-18) ─────────────────────────────────
  'nav.edit_title': ('Alt çubuk kısayolları', 'Bottom bar shortcuts', 'اختصارات الشريط السفلي'),
  'nav.edit_sub': (
    '{n}/{max} kısayol · basılı tutup sürükleyerek sırala. Çubuğa basılı tutarak da bu sayfayı açabilirsin.',
    '{n}/{max} shortcuts · press and drag to reorder. You can also open this page by long-pressing the bar.',
    '{n}/{max} اختصارات · اضغط مطولاً واسحب لإعادة الترتيب. يمكنك أيضاً فتح هذه الصفحة بالضغط المطول على الشريط.',
  ),
  'nav.home_locked': (
    'Dosyalar her zaman ilk sırada kalır',
    'Files always stays first',
    'تبقى الملفات دائماً في المقدمة',
  ),
  'nav.section': ('Gezinme', 'Navigation', 'التنقل'),
  'nav.addable': ('Eklenebilecekler', 'Available', 'المتاح للإضافة'),
  'nav.full': (
    'Çubuk dolu (en fazla {max}) — eklemek için önce birini çıkar',
    'Bar is full (max {max}) — remove one to add another',
    'الشريط ممتلئ (الحد {max}) — أزل واحداً لإضافة آخر',
  ),
  'nav.add': ('Çubuğa ekle', 'Add to bar', 'أضف إلى الشريط'),
  'nav.remove': ('Çubuktan çıkar', 'Remove from bar', 'أزل من الشريط'),
  'nav.reset': ('Varsayılana dön', 'Reset to default', 'استعادة الافتراضي'),
  'nav.important': ('Önemli', 'Important', 'مهم'),
  'nav.ai': ('AI', 'AI', 'الذكاء'),
  'nav.bills': ('Faturalar', 'Bills', 'الفواتير'),
  'nav.vault': ('Kasa', 'Vault', 'الخزنة'),
  'nav.settings_sub': (
    'Alttaki hızlı erişim düğmelerini seç ve sırala (en fazla 6)',
    'Choose and order the bottom shortcuts (up to 6)',
    'اختر ورتب الاختصارات السفلية (حتى 6)',
  ),

  // ── tema aileleri (2026-08-25) ──────────────────────────────────────────
  'skin.title': ('Tema ailesi', 'Theme style', 'نمط السمة'),
};
