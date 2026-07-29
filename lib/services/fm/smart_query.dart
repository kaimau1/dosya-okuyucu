import 'dart:convert';

import '../../core/text_search.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';

/// **Akıllı arama** — "geçen ay whatsapp'tan gelen büyük videolar" gibi doğal
/// bir cümleyi süzgece çevirir.
///
/// ## Niye önce YEREL çözümleyici
/// Bu iş için AI'ya gitmek cazip ama yanlış: kullanıcının çoğu sorgusu birkaç
/// kalıptan ibaret ("bu hafta", "pdf", "whatsapp"), bunlar için ağ gecikmesi,
/// API anahtarı zorunluluğu ve maliyet ödemek anlamsız. Yerel çözümleyici
/// **anında, çevrimdışı ve ücretsiz** çalışır; anlaşılmayan kalan metin zaten
/// ad araması olarak kullanılır. AI yalnızca kullanıcı isterse devreye girer
/// ([smartQueryFromJson] ile) ve sonucu aynı yapıya döner.
///
/// ## Tasarım kararı — anlaşılanı GÖSTER
/// Sorgunun hangi kısmının nasıl yorumlandığı ([understood]) arayüzde çip
/// olarak yazılır. Sessizce süzülen bir arama "neden bu sonuç çıktı?"
/// sorusunu doğurur; kullanıcı yanlış anlaşılan çipi kaldırabilmeli.
class SmartQuery {
  /// Cümleden çıkarılan süzgeç (tarih, boyut, kaynak, uzantı).
  final FmFilter filter;

  /// Cümleden çıkarılan kategori (video/görsel/belge…); null = hepsi.
  final FmCategory? category;

  /// Anlaşılamayan kalan metin — ad araması olarak kullanılır.
  final String text;

  /// "Son 30 gün", "Video", "WhatsApp" gibi insan okur etiketler.
  final List<String> understood;

  const SmartQuery({
    required this.filter,
    this.category,
    this.text = '',
    this.understood = const [],
  });

  bool get isEmpty =>
      category == null && !filter.isActive && text.trim().isEmpty;

  /// Sorgunun bir kısmı gerçekten anlaşıldı mı? (Çipleri göstermeye değer mi?)
  bool get hasStructure => category != null || filter.isActive;
}

/// Karşılaştırma biçimi: küçük harf **ve aksansız**.
///
/// Kullanıcı "geçen ay" da yazar "gecen ay" da (telefon klavyesinde Türkçe
/// harfleri atlamak çok yaygın). Her iki yazım da aynı sonuca varsın diye
/// hem sorgu hem anahtar sözcükler bu biçime indirgenir.
String _plain(String input) {
  const map = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final folded = turkishFold(input);
  final sb = StringBuffer();
  for (final ch in folded.split('')) {
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

/// Doğal dil sorgusunu çözümler (Türkçe, büyük/küçük harf ve aksan duyarsız).
///
/// Eşleşen sözcükler cümleden **çıkarılır**; kalanlar ad araması olur.
/// Örnek: "geçen ay kamera videoları tatil" → kategori=video, tarih=son 30 gün,
/// kaynak=Kamera, metin="tatil".
SmartQuery parseSmartQuery(String input, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final words = _plain(input).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.trim().isEmpty);
  if (words.isEmpty) return const SmartQuery(filter: FmFilter.none);

  var filter = FmFilter.none;
  FmCategory? category;
  final understood = <String>[];
  final leftovers = <String>[];
  final used = List<bool>.filled(words.length, false);

  /// [phrase] (boşluklu olabilir) sözcük dizisinde geçiyorsa true döner ve
  /// kullanılan sözcükleri işaretler.
  bool take(String phrase) {
    final parts = phrase.split(' ');
    for (var i = 0; i + parts.length <= words.length; i++) {
      if (used[i]) continue;
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (used[i + j] || words[i + j] != parts[j]) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (var j = 0; j < parts.length; j++) {
        used[i + j] = true;
      }
      return true;
    }
    return false;
  }

  bool takeAny(List<String> phrases) {
    var hit = false;
    for (final phrase in phrases) {
      // Hepsini dene: "video" ve "videolar" aynı cümlede geçebilir.
      while (take(phrase)) {
        hit = true;
      }
    }
    return hit;
  }

  // ── kategori ──────────────────────────────────────────────────────────────
  if (takeAny(['video', 'videolar', 'videolari', 'film', 'filmler', 'klip'])) {
    category = FmCategory.video;
    understood.add('Videolar');
  } else if (takeAny([
    'foto',
    'fotograf',
    'fotograflar',
    'fotograflari',
    'resim',
    'resimler',
    'resimleri',
    'gorsel',
    'gorseller',
    'goruntu',
    'goruntuler',
  ])) {
    category = FmCategory.image;
    understood.add('Görüntüler');
  } else if (takeAny(
      ['ses', 'sesler', 'muzik', 'muzikler', 'sarki', 'sarkilar', 'kayit'])) {
    category = FmCategory.audio;
    understood.add('Ses');
  } else if (takeAny(['belge', 'belgeler', 'dokuman', 'dokumanlar'])) {
    category = FmCategory.document;
    understood.add('Belgeler');
  } else if (takeAny(['uygulama', 'uygulamalar', 'apk'])) {
    category = FmCategory.apk;
    understood.add('Uygulamalar');
  } else if (takeAny(['arsiv', 'arsivler'])) {
    category = FmCategory.archive;
    understood.add('Arşivler');
  }

  // ── uzantı (belge türleri de kategoriyi belgeye çeker) ────────────────────
  const extWords = {
    'pdf': ['pdf'],
    'word': ['doc', 'docx'],
    'excel': ['xls', 'xlsx'],
    'sunum': ['ppt', 'pptx'],
    'slayt': ['ppt', 'pptx'],
    'metin': ['txt'],
    'zip': ['zip'],
    'rar': ['rar'],
    'mp4': ['mp4'],
    'mp3': ['mp3'],
    'jpg': ['jpg', 'jpeg'],
    'png': ['png'],
  };
  for (final entry in extWords.entries) {
    if (!takeAny([entry.key, '${entry.key}ler', '${entry.key}lar'])) continue;
    filter = filter.withExtensions({...filter.extensions, ...entry.value});
    understood.add('.${entry.value.first}');
    category ??= FsEntry.categoryForExtension(entry.value.first);
  }

  // ── tarih ─────────────────────────────────────────────────────────────────
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  if (takeAny(['bugun'])) {
    filter = filter.withDateRange(FmDateRange.today);
    understood.add('Bugün');
  } else if (takeAny(['dun'])) {
    final yesterday = startOfDay(today).subtract(const Duration(days: 1));
    filter = filter.withDateRange(
      FmDateRange.custom,
      fromMs: yesterday.millisecondsSinceEpoch,
      toMs: yesterday.millisecondsSinceEpoch,
    );
    understood.add('Dün');
  } else if (takeAny(['bu hafta', 'son hafta', 'gecen hafta', 'son 7 gun'])) {
    filter = filter.withDateRange(FmDateRange.week);
    understood.add('Son 7 gün');
  } else if (takeAny(
      ['bu ay', 'gecen ay', 'son ay', 'son 30 gun', 'son bir ay'])) {
    filter = filter.withDateRange(FmDateRange.month);
    understood.add('Son 30 gün');
  } else if (takeAny(['bu yil', 'gecen yil', 'son yil', 'son bir yil'])) {
    filter = filter.withDateRange(FmDateRange.year);
    understood.add('Son 1 yıl');
  } else {
    // Yalın yıl: "2024 fotoğrafları" → 2024'ün tamamı.
    for (var i = 0; i < words.length; i++) {
      if (used[i]) continue;
      final year = int.tryParse(words[i]);
      if (year == null || year < 1990 || year > today.year + 1) continue;
      used[i] = true;
      filter = filter.withDateRange(
        FmDateRange.custom,
        fromMs: DateTime(year).millisecondsSinceEpoch,
        toMs: DateTime(year, 12, 31).millisecondsSinceEpoch,
      );
      understood.add('$year');
      break;
    }
  }

  // ── boyut ─────────────────────────────────────────────────────────────────
  if (takeAny(['buyuk', 'buyukler', 'devasa', 'kocaman'])) {
    filter = filter.withSizeRange(FmSizeRange.large);
    understood.add('100 MB üzeri');
  } else if (takeAny(['kucuk', 'kucukler', 'ufak'])) {
    filter = filter.withSizeRange(FmSizeRange.tiny);
    understood.add('1 MB altı');
  }

  // ── kaynak ────────────────────────────────────────────────────────────────
  const bucketWords = <MediaBucket, List<String>>{
    MediaBucket.whatsapp: ['whatsapp', 'wp'],
    MediaBucket.camera: ['kamera', 'cektigim', 'dcim'],
    MediaBucket.screenshot: ['ekran goruntusu', 'ekran', 'screenshot'],
    MediaBucket.telegram: ['telegram'],
    MediaBucket.instagram: ['instagram'],
    MediaBucket.download: ['indirilen', 'indirilenler', 'indirdigim'],
    MediaBucket.bluetooth: ['bluetooth'],
  };
  for (final entry in bucketWords.entries) {
    if (!takeAny(entry.value)) continue;
    filter = filter.toggleBucket(entry.key);
    understood.add(entry.key.label);
  }

  // ── kalan metin ───────────────────────────────────────────────────────────
  for (var i = 0; i < words.length; i++) {
    if (used[i]) continue;
    // Bağlaç/edat gürültüsü ad aramasını bozmasın.
    const stop = {
      've',
      'ile',
      'icin',
      'dan',
      'den',
      'daki',
      'deki',
      'olan',
      'gelen',
      'butun',
      'tum',
      'hepsi',
      'bana',
      'bul',
      'goster',
      'ara',
      'dosya',
      'dosyalar',
      'dosyalari',
      'gun',
    };
    if (stop.contains(words[i])) continue;
    leftovers.add(words[i]);
  }

  return SmartQuery(
    filter: filter,
    category: category,
    text: leftovers.join(' '),
    understood: understood,
  );
}

/// AI'nın döndürdüğü JSON'u aynı yapıya çevirir.
///
/// Model bazen fazladan metin, kod bloğu ya da bilinmeyen alan döndürür; bu
/// yüzden **hoşgörülü** ayrıştırılır: ilk `{`…son `}` arası alınır, tanınmayan
/// değerler yok sayılır. Çözümleme başarısızsa null → çağıran yerel sonucu
/// kullanmaya devam eder (AI hiçbir zaman aramayı BOZMAZ).
SmartQuery? smartQueryFromJson(String raw, {DateTime? now}) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) return null;
    map = decoded.cast<String, dynamic>();
  } catch (_) {
    return null;
  }

  var filter = FmFilter.none;
  final understood = <String>[];

  FmCategory? category;
  final categoryName = (map['category'] as String?)?.trim();
  for (final c in FmCategory.values) {
    if (c.name == categoryName) {
      category = c;
      understood.add(c.label);
    }
  }

  final dateName = (map['dateRange'] as String?)?.trim();
  for (final r in FmDateRange.values) {
    if (r.name != dateName || r == FmDateRange.any) continue;
    if (r == FmDateRange.custom) {
      final from = (map['fromMs'] as num?)?.toInt();
      final to = (map['toMs'] as num?)?.toInt();
      if (from == null || to == null) break;
      filter = filter.withDateRange(r, fromMs: from, toMs: to);
    } else {
      filter = filter.withDateRange(r);
    }
    understood.add(r.label);
  }

  final sizeName = (map['sizeRange'] as String?)?.trim();
  for (final s in FmSizeRange.values) {
    if (s.name == sizeName && s != FmSizeRange.any) {
      filter = filter.withSizeRange(s);
      understood.add(s.label);
    }
  }

  final buckets = map['buckets'];
  if (buckets is List) {
    for (final raw in buckets) {
      for (final b in MediaBucket.values) {
        if (b.name == raw) {
          filter = filter.toggleBucket(b);
          understood.add(b.label);
        }
      }
    }
  }

  final extensions = map['extensions'];
  if (extensions is List) {
    final set = <String>{
      for (final e in extensions)
        if (e is String && e.trim().isNotEmpty)
          e.trim().toLowerCase().replaceAll('.', ''),
    };
    if (set.isNotEmpty) {
      filter = filter.withExtensions(set);
      understood.addAll(set.map((e) => '.$e'));
    }
  }

  final text = (map['text'] as String?)?.trim() ?? '';
  final result = SmartQuery(
    filter: filter,
    category: category,
    text: text,
    understood: understood,
  );
  return result.isEmpty ? null : result;
}

/// AI'ya verilecek yönerge — çıktının **yalnız JSON** olmasını zorlar.
String smartQueryPrompt(String question, DateTime now) => '''
Bir dosya yöneticisinin arama süzgecini kuruyorsun. Kullanıcının Türkçe
isteğini AŞAĞIDAKİ JSON şemasına çevir. Yalnız JSON döndür, açıklama yazma.

{
  "category": "image|video|audio|document|archive|apk|other" ya da null,
  "dateRange": "any|today|week|month|year|custom",
  "fromMs": <custom ise başlangıç, epoch ms>,
  "toMs": <custom ise bitiş, epoch ms>,
  "sizeRange": "any|tiny|small|medium|large",
  "buckets": ["camera","screenshot","whatsapp","telegram","instagram","download","bluetooth"],
  "extensions": ["pdf","mp4"],
  "text": "dosya adında aranacak kalan metin"
}

Bugünün tarihi: ${now.toIso8601String()}.
week = son 7 gün, month = son 30 gün, year = son 1 yıl.
tiny = 1 MB altı, small = 1-10 MB, medium = 10-100 MB, large = 100 MB üzeri.
Emin olmadığın alanı null ya da "any" bırak.

Kullanıcının isteği: "$question"
''';
