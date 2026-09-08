import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../text_decode.dart';

/// Bir dosyanın içindeki eşleşme.
class ContentHit {
  final String path;

  /// Eşleşmenin geçtiği satır numarası (1 tabanlı).
  final int line;

  /// Listede gösterilecek kısa bağlam (eşleşme ortada).
  final String snippet;

  /// Bu dosyada toplam kaç eşleşme var.
  final int total;

  const ContentHit({
    required this.path,
    required this.line,
    required this.snippet,
    required this.total,
  });
}

/// **Dosya İÇİNDE arama** — "adını bilmiyorum ama içinde şu yazıyordu".
///
/// ## Niye (2026-09-06 denetim turu)
/// Arama yalnız **dosya adına** bakıyordu. Kullanıcının en sık kaybettiği şey
/// ise adını hatırlamadığı bir not: bir `.txt`, indirilen bir `.csv`, bir
/// kayıt dosyası, bir `.json` yedeği. "İçinde 'fatura no' geçen dosyayı bul"
/// sorusunun uygulamada hiçbir cevabı yoktu.
///
/// ## Sınırlar — bilinçli ve dar
/// * **Yalnız metin biçimleri** ([textExtensions]). PDF/Word/Excel'in içi
///   ayrı bir iş: onlar için ayrıştırıcı çalıştırmak gerekir ve tarama
///   dakikalar sürerdi. (Uygulamanın AI dizini o belgeleri ayrıca indeksliyor.)
/// * **Dosya başına 2 MB**: daha büyük bir metin dosyası (çoğunlukla kayıt
///   dosyası) taramayı kilitler; sınır aşılınca dosya atlanır.
/// * **Sonuç sınırı**: ilk [limit] dosyada durulur — kullanıcı 3000 sonucu
///   zaten okumaz, ama beklemesi gerekir.
/// * Her dosyadan sonra olay döngüsüne dönülüyor: tarama sürerken arayüz
///   donmuyor ve "Durdur" düğmesi çalışıyor.
abstract final class ContentSearch {
  /// İçine bakılan uzantılar. Liste dar tutuluyor: bir `.mp4`i metin diye
  /// okumak hem yavaş hem anlamsız.
  static const textExtensions = {
    'txt', 'md', 'markdown', 'csv', 'tsv', 'log', 'json', 'xml', 'yaml', 'yml',
    'ini', 'conf', 'cfg', 'properties', 'srt', 'vtt', 'sql', 'html', 'htm',
    'css', 'js', 'ts', 'dart', 'py', 'java', 'kt', 'c', 'h', 'cpp', 'sh',
    'bat', 'gradle', 'gitignore', 'env', 'toml',
  };

  /// Bu boyutun üstündeki dosyaların içine bakılmaz.
  static const maxFileBytes = 2 * 1024 * 1024;

  static bool isSearchable(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    // Uzantısız `.gitignore` gibi dosyalarda `extension` boş döner; adın
    // kendisine bakılıyor.
    if (ext.isEmpty) {
      return textExtensions.contains(p.basename(path).replaceFirst('.', ''));
    }
    return textExtensions.contains(ext);
  }

  /// [root] altında içinde [query] geçen dosyaları arar.
  static Future<List<ContentHit>> search(
    String root,
    String query, {
    int limit = 200,
    void Function(String path)? onScan,
    bool Function()? isCancelled,
  }) async {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    final hits = <ContentHit>[];
    var scanned = 0;

    Future<void> walk(Directory dir, int depth) async {
      if (depth > 16 || hits.length >= limit) return;
      if (isCancelled?.call() ?? false) return;
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        return;
      }
      for (final child in children) {
        if (hits.length >= limit) return;
        if (isCancelled?.call() ?? false) return;
        if (child is Directory) {
          // Gizli/sistem klasörleri atlanıyor: `.thumbnails`, `Android/data`
          // gibi yerlerde kullanıcının aradığı not bulunmaz.
          if (p.basename(child.path).startsWith('.')) continue;
          await walk(child, depth + 1);
          continue;
        }
        if (child is! File || !isSearchable(child.path)) continue;
        try {
          if (child.lengthSync() > maxFileBytes) continue;
        } catch (_) {
          continue;
        }
        onScan?.call(child.path);
        // Her dosyadan sonra nefes: tarama sürerken arayüz yanıt versin.
        if (++scanned % 8 == 0) await Future<void>.delayed(Duration.zero);
        final hit = await _searchFile(child, needle);
        if (hit != null) hits.add(hit);
      }
    }

    await walk(Directory(root), 0);
    return hits;
  }

  static Future<ContentHit?> _searchFile(File file, String needle) async {
    String text;
    try {
      text = TextDecode.decode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
    // Türkçe-duyarlı, büyük/küçük harf duyarsız (İ/I/ı/i doğru eşleşir).
    final starts = findAll(text, needle, limit: 500);
    if (starts.isEmpty) return null;
    final at = starts.first;
    // Satır numarası: eşleşmeye kadar olan satır sonlarını say.
    var line = 1;
    for (var i = 0; i < at; i++) {
      if (text.codeUnitAt(i) == 0x0A) line++;
    }
    return ContentHit(
      path: file.path,
      line: line,
      snippet: _snippetAround(text, at, needle.length),
      total: starts.length,
    );
  }

  /// Eşleşmeyi ortalayan tek satırlık bağlam.
  static String _snippetAround(String text, int at, int length) {
    const around = 40;
    final from = (at - around).clamp(0, text.length);
    final to = (at + length + around).clamp(0, text.length);
    final raw = text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim();
    return '${from > 0 ? '…' : ''}$raw${to < text.length ? '…' : ''}';
  }
}
