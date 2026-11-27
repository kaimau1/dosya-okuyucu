part of '../app_strings.dart';

/// Çeviri tablosunun 55. bölümü (2026-11-27, B18): Yer aç yeni görünüm ve
/// derin taramaların (benzer kareler, sohbet medyası) listeye katılması.
const Map<String, (String, String, String)> _t55 = {
  'clean.safe_main': (
    'Güvenle açılabilir',
    'Safe to free',
    'يمكن تحريرها بأمان',
  ),
  'clean.review_line': (
    'İncelemeye değer: {size}',
    'Worth reviewing: {size}',
    'تستحق المراجعة: {size}',
  ),
  'clean.free_after': (
    'Seçilenler temizlenince boş alan: {before} → {after} (+{delta})',
    'Free space after cleaning the selection: {before} → {after} (+{delta})',
    'المساحة الفارغة بعد تنظيف المحدد: {before} ← {after} (+{delta})',
  ),
  'clean.groups_n': ('{n} grup', '{n} groups', '{n} مجموعة'),
  'clean.files_n': ('{n} dosya', '{n} files', '{n} ملف'),
  'clean.similar_detail': (
    '{n} grupta birbirine çok benzeyen kareler. Her grubun en iyi karesi korunur, yalnız fazlası önerilir.',
    'Near-identical shots in {n} groups. The best shot of each group is kept; only the extras are suggested.',
    'لقطات متشابهة جدًا في {n} مجموعة. تُحفَظ أفضل لقطة في كل مجموعة ويُقترح الباقي فقط.',
  ),
  'clean.chat_media': ('Sohbet medyası', 'Chat media', 'وسائط المحادثات'),
  'clean.chat_media_detail': (
    'WhatsApp ve Telegram klasörlerinde {n} gereksiz olabilecek dosya: çıkartma, GIF, eski ve kopya medya.',
    '{n} likely unneeded files in WhatsApp and Telegram folders: stickers, GIFs, old and duplicate media.',
    '{n} ملف قد لا تحتاجه في مجلدات واتساب وتيليجرام: ملصقات وصور GIF ووسائط قديمة ومكررة.',
  ),
  'clean.why_similar': (
    'Hiçbiri kendiliğinden seçilmez; dokunup grup grup bakın. En iyi kare asla silinmez.',
    'Nothing is pre-selected; tap to review group by group. The best shot is never deleted.',
    'لا يُحدَّد شيء تلقائيًا؛ اضغط للمراجعة مجموعةً مجموعة. لا تُحذف أفضل لقطة أبدًا.',
  ),
  'clean.why_chat_media': (
    'Hiçbiri kendiliğinden seçilmez; dokunup türüne göre bakın. Çöp kutusuna gider, geri alınabilir.',
    'Nothing is pre-selected; tap to review by type. Moves to trash, restorable.',
    'لا يُحدَّد شيء تلقائيًا؛ اضغط للمراجعة حسب النوع. يُنقَل للمهملات ويمكن استعادته.',
  ),
};
