import 'dart:async';

import 'package:pdfrx/pdfrx.dart';

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import '../file_service.dart';
import 'content_search.dart';

/// "Dosyaların içinde" aramanın tek sonucu.
class DocTextHit {
  final FsEntry entry;

  /// Eşleşmenin çevresinden kısa alıntı (satırda gösterilir).
  final String snippet;

  /// Toplam eşleşme sayısı (bütün terimler).
  final int count;

  /// Hangi terimler bulundu (AI genişletmesinde "neden bu sonuç?").
  final List<String> terms;

  const DocTextHit(this.entry, this.snippet, this.count, this.terms);
}

/// **Seçili süzgeç içinde, dosyaların İÇİNDE arama** (2026-10-29 kullanıcı
/// isteği: *"bir butonla dosyalar içerisinde de ara seçeneği olsun, hem AI'lı
/// hem AI'sız; bu da seçilen filtre dahilinde arayacak"*).
///
/// [ContentSearch] yalnız düz metin dosyalarına (txt, md, csv…) bakıyordu ve
/// bir klasör ağacını geziyordu. Bu servis ise ÇAĞIRANIN verdiği listeyi
/// (ekranda o an görünen süzgeç: "yalnız PDF'ler", "WhatsApp'tan gelen
/// Word'ler") tarar ve PDF/Word/Excel/PowerPoint metnini de okur.
///
/// * **Cihazda** çalışır; AI'lı kipte bile dosya içeriği buluta GİTMEZ —
///   AI yalnız sorguyu eş anlamlılarla genişletir ([terms] listesi).
/// * Okunan metin bellekte önbelleklenir (yol + boyut + tarih): aynı
///   süzgeçte ikinci arama anında döner.
/// * Eşleşme Türkçe/ASCII katlamalı: "sozlesme" yazan "Sözleşme"yi bulur.
abstract final class DocTextSearch {
  static const _officeExts = {
    'pdf', 'docx', 'pptx', 'xlsx', 'doc', 'xls', 'ppt', 'rtf', 'odt',
  };

  /// Okunacak en büyük dosya (çok büyük PDF taramayı kilitlemesin).
  static const maxFileBytes = 60 * 1024 * 1024;

  /// PDF'te okunacak en çok sayfa.
  static const maxPdfPages = 120;

  /// Önbellek: anahtar → metin. Toplam ~[_cacheLimit] karakter.
  static final Map<String, String> _cache = {};
  static int _cacheChars = 0;
  static const _cacheLimit = 24 * 1024 * 1024;

  static bool supports(FsEntry e) {
    if (e.isDir) return false;
    final ext = e.extension.toLowerCase();
    return _officeExts.contains(ext) || ContentSearch.isSearchable(e.path);
  }

  static String _key(FsEntry e) => '${e.path}|${e.sizeBytes}|${e.modifiedMs}';

  /// Dosyanın düz metni (okunamazsa boş).
  static Future<String> textOf(FsEntry e) async {
    final key = _key(e);
    final cached = _cache[key];
    if (cached != null) return cached;
    var text = '';
    try {
      if (e.sizeBytes <= maxFileBytes) {
        if (e.extension.toLowerCase() == 'pdf') {
          text = await _pdfText(e.path);
        } else {
          text = (await FileService().load(e.path)).plainText;
        }
      }
    } catch (_) {
      text = '';
    }
    _remember(key, text);
    return text;
  }

  static void _remember(String key, String text) {
    _cache[key] = text;
    _cacheChars += text.length;
    while (_cacheChars > _cacheLimit && _cache.isNotEmpty) {
      final first = _cache.keys.first;
      _cacheChars -= _cache.remove(first)!.length;
    }
  }

  static Future<String> _pdfText(String path) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final out = StringBuffer();
      var n = 0;
      for (final page in doc.pages) {
        if (++n > maxPdfPages) break;
        try {
          final dynamic layer = await page.loadText();
          if (layer != null) out.writeln(layer.fullText as String? ?? '');
        } catch (_) {}
      }
      return out.toString();
    } finally {
      await doc.dispose();
    }
  }

  /// [files] içinde (yalnız [supports] olanlar) [terms]'ten herhangi birini
  /// arar. Sonuç: en çok eşleşen üstte. İlk terim ağırlıklıdır (kullanıcının
  /// kendi yazdığı), genişletme terimleri daha hafif sayılır.
  static Future<List<DocTextHit>> search(
    List<FsEntry> files,
    List<String> terms, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    int limit = 300,
  }) async {
    final needles = <(String, String)>[
      for (final t in terms)
        if (t.trim().length >= 2) (t.trim(), asciiFold(t.trim())),
    ];
    if (needles.isEmpty) return const [];
    final targets = files.where(supports).toList();
    final hits = <(DocTextHit, double)>[];
    for (var i = 0; i < targets.length; i++) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call(i, targets.length);
      final e = targets[i];
      final text = await textOf(e);
      // Her dosyadan sonra nefes: arayüz yanıt versin.
      await Future<void>.delayed(Duration.zero);
      if (text.isEmpty) continue;
      final hay = asciiFold(text);
      var score = 0.0;
      var count = 0;
      var first = -1;
      var firstLen = 0;
      final found = <String>[];
      for (var k = 0; k < needles.length; k++) {
        final (raw, needle) = needles[k];
        var at = hay.indexOf(needle);
        if (at < 0) continue;
        // İlk bulunan terimin yeri alıntı olur (kullanıcının kendi terimi
        // önce denendiği için varsa o).
        if (first < 0) {
          first = at;
          firstLen = needle.length;
        }
        var c = 0;
        while (at >= 0 && c < 50) {
          c++;
          at = hay.indexOf(needle, at + needle.length);
        }
        if (c > 0) {
          found.add(raw);
          count += c;
          score += (k == 0 ? 2.0 : 1.0) * (1 + (c > 10 ? 10 : c) / 10);
        }
      }
      if (count == 0) continue;
      hits.add((DocTextHit(e, _snippet(text, first, firstLen), count, found), score));
    }
    onProgress?.call(targets.length, targets.length);
    hits.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final h in hits.take(limit)) h.$1];
  }

  static String _snippet(String text, int at, int len) {
    if (at < 0) return '';
    final start = (at - 50).clamp(0, text.length);
    final end = (at + len + 70).clamp(0, text.length);
    final body = text
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${start > 0 ? '…' : ''}$body${end < text.length ? '…' : ''}';
  }

  /// Testler için.
  static void clearCache() {
    _cache.clear();
    _cacheChars = 0;
  }
}
