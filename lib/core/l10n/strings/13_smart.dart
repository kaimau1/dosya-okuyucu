part of '../app_strings.dart';

/// Çeviri tablosunun 13. bölümü (2026-10-23): akıllı bildirim alanı, kategori
/// "Analiz ve düzenle" levhası, liste denetim şeridi, eylem levhası, AI ile
/// etiketleme, anlamla arama.
const Map<String, (String, String, String)> _t13 = {
  // ── Akıllı bildirim alanı (pano) ─────────────────────────────────────────
  'inbox.running': ('Sürüyor…', 'Running…', 'قيد التشغيل…'),
  'inbox.just_now': ('şimdi', 'just now', 'الآن'),
  'inbox.min_ago': ('{n} dk önce', '{n} min ago', 'قبل {n} د'),
  'inbox.hour_ago': ('{n} sa önce', '{n} h ago', 'قبل {n} س'),
  'inbox.clear_done': ('Bitenleri temizle', 'Clear finished', 'مسح المنتهية'),
  'inbox.more': ('+{n} daha · Tümü', '+{n} more · All', '+{n} أخرى · الكل'),
  'inbox.all': ('Tüm işlemler', 'All jobs', 'كل العمليات'),
  'inbox.open': ('Aç', 'Open', 'فتح'),
  'inbox.storage_full': ('Bellek %{n} dolu', 'Storage {n}% full', 'التخزين ممتلئ {n}%'),
  'inbox.trash_full': ('Çöp kutusunda {n} öğe', '{n} items in the bin', '{n} عنصر في السلة'),
  'inbox.trash_hint': (
    'Yer kaplıyor — göz atıp boşaltabilirsin',
    'Taking up space — review and empty it',
    'تشغل مساحة — راجعها وأفرغها',
  ),

  // ── Liste denetim şeridi ─────────────────────────────────────────────────
  'lc.count': ('{n} öğe', '{n} items', '{n} عنصر'),
  'lc.count_of': ('{n} / {total} öğe', '{n} / {total} items', '{n} / {total} عنصر'),
  'lc.filter': ('Süzgeç', 'Filter', 'تصفية'),
  'lc.filter_n': ('Süzgeç · {n}', 'Filter · {n}', 'تصفية · {n}'),
  'lc.tools': ('Analiz', 'Insights', 'تحليل'),
  'lc.clear_all': ('Temizle', 'Clear', 'مسح'),
  'lc.no_dupes': ('Kopyalar gizli', 'Duplicates hidden', 'النسخ مخفية'),

  // ── Analiz ve düzenle (kategori / hızlı klasör) ──────────────────────────
  'ct.title': ('Analiz ve düzenle', 'Analyse & organise', 'تحليل وتنظيم'),
  'ct.subtitle': ('{title} · görünen {n} dosya', '{title} · {n} files shown', '{title} · {n} ملف ظاهر'),
  'ct.menu_hint': (
    'Özet, genel analiz, akıllı analiz, etiketleme',
    'Summary, analysis, smart insights, tagging',
    'ملخص، تحليل، تحليل ذكي، وسوم',
  ),
  'ct.group_analysis': ('Analiz', 'Analysis', 'تحليل'),
  'ct.group_tags': ('Kategoriler ve etiketler', 'Categories & tags', 'الفئات والوسوم'),
  'ct.summary': ('Özet', 'Summary', 'ملخص'),
  'ct.summary_hint': ('Sayı, boyut, türler, kaynaklar', 'Count, size, types, sources', 'العدد والحجم والأنواع والمصادر'),
  'ct.analysis': ('Genel analiz', 'Full analysis', 'تحليل شامل'),
  'ct.analysis_hint': (
    'Aylara göre, en büyükler, temizlenebilirler',
    'By month, largest, what can be cleaned',
    'حسب الشهر، الأكبر، ما يمكن تنظيفه',
  ),
  'ct.ai_analysis': (
    'Akıllı analiz',
    'Smart insights',
    'تحليل ذكي',
  ),
  'ct.ai_analysis_hint': (
    'Ne var, nasıl düzenlenir — yalnız sayılar ve dosya adları gider',
    'What is here and how to organise it — only counts and names are sent',
    'ما الموجود وكيف تنظمه — تُرسل الأعداد والأسماء فقط',
  ),
  'ct.bulk_tag': ('Toplu etiketle', 'Tag all', 'وسم الكل'),
  'ct.bulk_tag_hint': ('Görünen {n} dosyaya elle etiket ekle', 'Add a tag to the {n} files shown', 'أضف وسمًا لـ {n} ملفًا ظاهرًا'),
  'ct.manage_tags': ('Etiketleri yönet', 'Manage tags', 'إدارة الوسوم'),
  'ct.manage_tags_hint': ('Yeniden adlandır ya da sil', 'Rename or delete', 'إعادة تسمية أو حذف'),
  'ct.empty': ('Bu listede dosya yok.', 'No files in this list.', 'لا توجد ملفات في هذه القائمة.'),
  'ct.stat_files': ('dosya', 'files', 'ملف'),
  'ct.stat_size': ('toplam', 'total', 'المجموع'),
  'ct.stat_month': ('bu ay', 'this month', 'هذا الشهر'),
  'ct.by_type': ('Türler', 'Types', 'الأنواع'),
  'ct.by_source': ('Nereden geldi', 'Where from', 'المصدر'),
  'ct.by_month': ('Son 12 ay', 'Last 12 months', 'آخر 12 شهرًا'),
  'ct.cleanable': ('Temizlenebilir', 'Can be cleaned', 'قابل للتنظيف'),
  'ct.stale': ('{days} günden uzun süredir açılmamış', 'Not opened for over {days} days', 'لم تُفتح منذ أكثر من {days} يومًا'),
  'ct.stale_title': ('{title} · uzun süredir açılmamış', '{title} · not opened for long', '{title} · لم تُفتح منذ مدة'),
  'ct.copies': ('Kopya adlı dosyalar ("(1)", "kopya")', 'Copy-named files ("(1)", "copy")', 'ملفات بأسماء نسخ ("(1)"، "نسخة")'),
  'ct.copies_title': ('{title} · kopyalar', '{title} · copies', '{title} · نسخ'),
  'ct.largest': ('En büyük dosyalar', 'Largest files', 'أكبر الملفات'),
  'ct.tags_heading': ('Etiketler', 'Tags', 'الوسوم'),
  'ct.no_tags': (
    'Henüz etiket yok — "Akıllı ikinci ad" ya da "Toplu etiketle".',
    'No tags yet — try "Smart second name" or "Tag all".',
    'لا توجد وسوم بعد — جرّب "اسم ثانٍ ذكي" أو "وسم الكل".',
  ),
  'ct.no_tags_yet': ('Henüz hiç etiket yok.', 'No tags yet.', 'لا توجد وسوم بعد.'),
  'ct.ai_busy': (
    'Akıllı analiz listeyi inceliyor…',
    'Smart insights are reviewing the list…',
    'التحليل الذكي يراجع القائمة…',
  ),
  'ct.ai_done': (
    'Akıllı analiz hazır',
    'Smart insights ready',
    'التحليل الذكي جاهز',
  ),
  'ct.ai_findings': ('Dikkat çekenler', 'Findings', 'ملاحظات'),
  'ct.ai_tips': ('Öneriler', 'Suggestions', 'اقتراحات'),
  'ct.ai_categories': ('Önerilen kategoriler', 'Suggested categories', 'فئات مقترحة'),
  'ct.ai_privacy': (
    'AI\'ya dosyaların içeriği gitmedi: yalnız sayılar ve en çok 150 dosya adı (kapsam dışı klasörler hariç).',
    'No file contents were sent: only counts and up to 150 file names (excluded folders skipped).',
    'لم يُرسل محتوى الملفات: الأعداد وما يصل إلى 150 اسم ملف فقط (دون المجلدات المستثناة).',
  ),
  'ct.tag_rename': ('Etiketi yeniden adlandır', 'Rename tag', 'إعادة تسمية الوسم'),
  'ct.tag_delete': ('Etiketi sil', 'Delete tag', 'حذف الوسم'),
  'ct.tag_delete_body': (
    '"{tag}" etiketi {n} dosyadan kaldırılacak. Dosyalar silinmez.',
    'The tag "{tag}" will be removed from {n} files. Files are not deleted.',
    'سيُزال الوسم "{tag}" من {n} ملف. لن تُحذف الملفات.',
  ),

  // ── Eylem levhası (seçim › Daha fazla) ───────────────────────────────────
  'sel.sheet_title': ('{n} öğe seçildi', '{n} selected', 'تم تحديد {n}'),
  'sel.group_organize': ('Düzenle', 'Organise', 'تنظيم'),
  'sel.group_copy': ('Kopyala ve gönder', 'Copy & send', 'نسخ وإرسال'),
  'sel.group_more': ('Diğer', 'More', 'المزيد'),
  'sel.hide_hint': ('Şifreli kasaya taşır', 'Moves into the encrypted vault', 'ينقل إلى الخزنة المشفرة'),

  // ── AI ile etiketleme ────────────────────────────────────────────────────
  'tagai.error': (
    'Akıllı işlem yapılamadı: {error}',
    'The smart action failed: {error}',
    'تعذّر تنفيذ الإجراء الذكي: {error}',
  ),
  'tp.title': ('Etiketle', 'Tag', 'وسم'),
  'tp.title_n': ('Etiketle ({n} dosya)', 'Tag ({n} files)', 'وسم ({n} ملف)'),

  // ── Anlamla ara (AI) ─────────────────────────────────────────────────────
  'srch.meaning': (
    'Akıllı arama',
    'Smart search',
    'بحث ذكي',
  ),
  'srch.meaning_off': ('Anlamla aramayı kapat', 'Turn off meaning search', 'إيقاف البحث بالمعنى'),
  'srch.meaning_short': ('Anlamla', 'Meaning', 'بالمعنى'),
  'srch.meaning_hint': ('Ne arıyorsun? Kendi cümlenle yaz', 'What are you looking for? Describe it', 'ما الذي تبحث عنه؟ صِفه'),
  'srch.meaning_intro': (
    'Örn. "geçen kışki elektrik faturası". Ara\'ya bas: akıllı arama eş anlamlı ve ilgili sözcükleri bulur, arama telefonunda yapılır. Yalnız sorgun gider.',
    'E.g. "last winter\'s electricity bill". Press search: smart search finds synonyms and related words, the search runs on your phone. Only your query is sent.',
    'مثال: "فاتورة الكهرباء الشتاء الماضي". اضغط بحث: يجد البحث الذكي المرادفات والكلمات ذات الصلة، ويجري البحث على هاتفك. يُرسل استعلامك فقط.',
  ),
  'srch.meaning_terms': ('Aranan:', 'Searched for:', 'تم البحث عن:'),
};
