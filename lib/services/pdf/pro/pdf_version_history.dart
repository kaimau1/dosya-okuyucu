/// **PDF sürüm geçmişi** (PDF Pro Faz 54 / 3): Kaydet özgün dosyanın üstüne
/// yazmadan önce dosyanın o anki hâlini uygulama içi geçmişe koyar; kullanıcı
/// 14 gün içinde "önceki sürüme dön" diyebilir.
///
/// Geçmiş uygulamanın özel alanındadır (kullanıcının klasörünü kirletmez,
/// uygulama silinince gider). Belge başına klasör dosya YOLUNUN özetiyle
/// adlanır; sürüm dosyasının adı kayıt anıdır (ms).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../fm/fm_env.dart';
import '../../fm/safe_write.dart';

class PdfVersion {
  final File file;
  final DateTime savedAt;
  final int size;
  const PdfVersion(this.file, this.savedAt, this.size);
}

abstract final class PdfVersionHistory {
  /// Sürümler bu kadar saklanır.
  static const keep = Duration(days: 14);

  /// Belge başına en çok sürüm (büyük dosyada depolama taşmasın).
  static const maxPerDocument = 20;

  /// Test için kök klasör; null → uygulama destek dizini.
  static String? rootOverride;

  static String get _root =>
      rootOverride ?? p.join(FmEnv.appSupportDir, 'pdf_versions');

  static bool get _usable =>
      rootOverride != null || FmEnv.appSupportDir.isNotEmpty;

  static Directory _dirFor(String path) => Directory(p.join(
      _root, sha1.convert(utf8.encode(p.normalize(path))).toString()));

  /// [path]'in diskteki şimdiki hâlini geçmişe koyar. Son sürümle bayt bayt
  /// aynıysa yeni kopya açılmaz. Geçmiş kullanılamıyorsa null (kayıt yine
  /// de sürer — geçmiş bir emniyet ağı, kaydın önkoşulu değil).
  static Future<PdfVersion?> push(String path, {DateTime? now}) async {
    if (!_usable) return null;
    try {
      final src = File(path);
      if (!await src.exists()) return null;
      final dir = _dirFor(path);
      await dir.create(recursive: true);
      final at = now ?? DateTime.now();
      final existing = await _read(dir);
      if (existing.isNotEmpty && await _same(existing.first.file, src)) {
        return existing.first;
      }
      var stamp = at.millisecondsSinceEpoch;
      while (File(p.join(dir.path, '$stamp.pdf')).existsSync()) {
        stamp++;
      }
      final target = File(p.join(dir.path, '$stamp.pdf'));
      await src.copy(target.path);
      await File(p.join(dir.path, 'path.txt')).writeAsString(path);
      await _prune(dir, at);
      return PdfVersion(target, DateTime.fromMillisecondsSinceEpoch(stamp),
          await target.length());
    } catch (_) {
      return null;
    }
  }

  /// [path]'in saklanan sürümleri, en yeni üstte. Süresi dolanlar silinir.
  static Future<List<PdfVersion>> list(String path, {DateTime? now}) async {
    if (!_usable) return const [];
    try {
      final dir = _dirFor(path);
      if (!await dir.exists()) return const [];
      await _prune(dir, now ?? DateTime.now());
      return _read(dir);
    } catch (_) {
      return const [];
    }
  }

  /// [version]'ı [path]'in yerine koyar. Şimdiki hâl önce geçmişe girer —
  /// geri dönüş de geri alınabilir.
  static Future<void> restore(String path, PdfVersion version,
      {DateTime? now}) async {
    await push(path, now: now);
    await SafeWrite.copy(version.file.path, path);
  }

  /// Bütün belgelerde süresi dolan sürümleri siler (açılışta bir kez).
  static Future<void> pruneAll({DateTime? now}) async {
    if (!_usable) return;
    try {
      final root = Directory(_root);
      if (!await root.exists()) return;
      final at = now ?? DateTime.now();
      await for (final d in root.list()) {
        if (d is! Directory) continue;
        await _prune(d, at);
        if ((await _read(d)).isEmpty) await d.delete(recursive: true);
      }
    } catch (_) {
      // Bilinçli: budama bir temizlik işi; başarısızsa sonraki açılışta
      // yeniden denenir, kullanıcıya gösterilecek bir hata değil.
    }
  }

  static Future<List<PdfVersion>> _read(Directory dir) async {
    final out = <PdfVersion>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.pdf')) continue;
      final ms = int.tryParse(p.basenameWithoutExtension(f.path));
      if (ms == null) continue;
      out.add(PdfVersion(
          f, DateTime.fromMillisecondsSinceEpoch(ms), await f.length()));
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  static Future<void> _prune(Directory dir, DateTime now) async {
    final all = await _read(dir);
    for (var i = 0; i < all.length; i++) {
      if (i >= maxPerDocument || now.difference(all[i].savedAt) > keep) {
        await all[i].file.delete();
      }
    }
  }

  /// Boyut eşitse içerik parça parça karşılaştırılır (tümü belleğe alınmaz).
  static Future<bool> _same(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    final ra = await a.open(), rb = await b.open();
    try {
      const chunk = 64 * 1024;
      while (true) {
        final ca = await ra.read(chunk), cb = await rb.read(chunk);
        if (ca.length != cb.length) return false;
        if (ca.isEmpty) return true;
        for (var i = 0; i < ca.length; i++) {
          if (ca[i] != cb[i]) return false;
        }
      }
    } finally {
      await ra.close();
      await rb.close();
    }
  }
}
