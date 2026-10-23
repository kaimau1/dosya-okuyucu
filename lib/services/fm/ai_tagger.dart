import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import '../gemini_service.dart';
import 'ai_buckets.dart';
import 'ai_index.dart';
import 'ai_scope.dart';

/// **AI ile etiketleme** — seçili (ya da listedeki) dosyalara kısa etiket
/// önerir; kullanıcı onaylayınca [FileTags]'a yazılır.
///
/// Kullanıcı isteği (2026-10-23): *"kategorilendirme, toplu etiketleme, AI ile
/// etiketleme, manuel etiketleme yapılabilmeli"*.
///
/// ## İki kaynak, önce ücretsiz olan
/// 1. **AI dizini** ([AiIndex]) — toplu analizden geçmiş dosyanın etiketleri ve
///    türü zaten diskte; bunlar için ağa hiç gidilmez.
/// 2. Kalanlar için **Gemini**, yalnız **meta** ile: dosya adı, uzantı, üst
///    klasörün ADI (tam yol değil), boyut ve ay. İçerik gitmez. [AiScope]
///    dışlamaları (kamera klasörü, kilitli klasörler) hiç gönderilmez.
///
/// Öneri **önerdir**: hiçbir etiket kendiliğinden yazılmaz, levhada işaretli
/// gelir, kullanıcı kaldırabilir.
abstract final class AiTagger {
  /// Tek istekte sorulan dosya sayısı (ücretsiz kotada istek sayısı sınırı
  /// var; satır başına ~15 belirteç).
  static const batchSize = 120;

  /// Bir oturumda en çok bu kadar dosya buluta sorulur.
  static const maxCloud = 600;

  /// Etiket → dosya yolları. Etiket adları katlanmış anahtarla tekilleşir
  /// ("Fatura" ve "fatura" tek etiket), ilk görülen yazım korunur.
  static Map<String, Set<String>> fromIndex(Iterable<FsEntry> entries) {
    final out = _TagBag();
    for (final e in entries) {
      final r = AiIndex.of(e.path);
      if (r == null) continue;
      for (final t in r.tags.take(3)) {
        out.add(t, e.path);
      }
      if (r.docType.isNotEmpty) {
        out.add(AiBuckets.label(AiBuckets.canonicalDocType(r.docType)), e.path);
      }
    }
    return out.map;
  }

  /// Buluta sorulacak satırlar — kapsam dışı dosyalar elenir.
  static List<FsEntry> cloudCandidates(
    Iterable<FsEntry> entries, {
    required AiScope scope,
    Set<String> skip = const {},
  }) =>
      [
        for (final e in entries)
          if (!e.isDir && !skip.contains(e.path) && scope.allowsFile(e)) e,
      ].take(maxCloud).toList();

  static String _month(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  /// İstem gövdesi (test edilebilsin diye ayrı).
  static String promptFor(List<FsEntry> items, {Set<String> existing = const {}}) {
    final b = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      final e = items[i];
      b.writeln('$i|${e.name}|${p.basename(p.dirname(e.path))}|'
          '${(e.sizeBytes / 1024).round()} KB|${_month(e.modifiedMs)}');
    }
    final known = existing.isEmpty
        ? ''
        : '\nKullanıcının mevcut etiketleri (uygunsa AYNEN bunları kullan): '
            '${existing.take(40).join(', ')}\n';
    return 'Aşağıda telefondaki dosyaların satırları var: '
        '"numara|ad|klasör adı|boyut|ay". Her dosyaya 1-3 KISA etiket öner '
        '(1-2 sözcük; ör. Fatura, Sözleşme, Sağlık, Okul, İş, Kimlik, Banka, '
        'Sunum, Rapor, Ekran görüntüsü, Seyahat). Etiket bir KONU ya da TÜR '
        'olsun; dosya adını, tarihi ya da kişi adını etiket yapma. Emin '
        'olmadığın dosyaya boş liste ver. Etiket dili arayüz dilidir.$known\n'
        '$b';
  }

  static const schema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'i': {'type': 'integer'},
            'tags': {
              'type': 'array',
              'items': {'type': 'string'}
            },
          },
          'required': ['i', 'tags'],
        },
      },
    },
    'required': ['items'],
  };

  /// Yanıtı etiket → yollar haritasına çevirir; bozuk satırlar atlanır.
  static Map<String, Set<String>> parse(String raw, List<FsEntry> items) {
    final out = _TagBag();
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['items'] : null;
      if (list is! List) return out.map;
      for (final row in list) {
        if (row is! Map) continue;
        final i = (row['i'] as num?)?.toInt();
        if (i == null || i < 0 || i >= items.length) continue;
        final tags = row['tags'];
        if (tags is! List) continue;
        for (final t in tags.take(3)) {
          out.add('$t', items[i].path);
        }
      }
    } catch (_) {
      // Bilinçli: şema dışı yanıt — aşağıdaki yedek yol kullanılır.
    }
    return out.map;
  }

  /// İki haritayı birleştirir (etiket adları katlanarak eşlenir).
  static Map<String, Set<String>> merge(
      Map<String, Set<String>> a, Map<String, Set<String>> b) {
    final out = _TagBag();
    for (final m in [a, b]) {
      for (final e in m.entries) {
        for (final path in e.value) {
          out.add(e.key, path);
        }
      }
    }
    return out.map;
  }

  /// Önerileri getirir: önce dizin, kalanlar için bulut ([onProgress] grup
  /// başına `(bitti, toplam)`).
  static Future<Map<String, Set<String>>> suggest({
    required List<FsEntry> entries,
    required GeminiService gemini,
    required AiScope scope,
    Set<String> existing = const {},
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await AiIndex.ensureLoaded();
    var result = fromIndex(entries);
    final known = {for (final s in result.values) ...s};
    final cloud = cloudCandidates(entries, scope: scope, skip: known);
    for (var start = 0; start < cloud.length; start += batchSize) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call(start, cloud.length);
      final part = cloud.sublist(
          start, (start + batchSize).clamp(0, cloud.length).toInt());
      final raw = await gemini.generateJson(
        prompt: promptFor(part, existing: existing),
        schema: schema,
      );
      result = merge(result, parse(raw, part));
    }
    onProgress?.call(cloud.length, cloud.length);
    return result;
  }
}

/// Katlanmış anahtarla tekilleşen etiket torbası.
class _TagBag {
  final Map<String, String> _display = {};
  final Map<String, Set<String>> _paths = {};

  void add(String tag, String path) {
    final clean = tag.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > 32) return;
    final key = turkishFold(clean);
    final shown = _display.putIfAbsent(key, () => _capitalize(clean));
    (_paths[shown] ??= {}).add(path);
  }

  Map<String, Set<String>> get map => _paths;

  /// İlk harf büyük — Türkçe i/ı doğru ("izin" → "İzin").
  static String _capitalize(String s) {
    final first = switch (s[0]) {
      'i' => 'İ',
      'ı' => 'I',
      final c => c.toUpperCase(),
    };
    return first + s.substring(1);
  }
}
