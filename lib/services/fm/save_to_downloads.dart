import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';
import 'fs_events.dart';

/// "İndir": açık dosyayı telefonun **İndirilenler** klasörüne koyar.
///
/// Kullanıcı 2026-09-22: *"açılan PDF vs indir seçeneği olmalı, sadece
/// paylaş yaparak iniyor; direkt İndirilenler'e insin"* ve *"tarayıcıda PDF
/// açtığımda onu bulamıyorum, yeni dosyalara düşmeli"*.
///
/// KÖK NEDEN: "Birlikte aç" / paylaş ile gelen dosya
/// (`receive_sharing_intent`) uygulamanın ÖZEL önbelleğine kopyalanıyor
/// (`/data/user/0/<paket>/cache/…`). Kullanıcı o klasörü göremez, dosya
/// yöneticimiz de oraya bakmaz; Android önbelleği temizleyince dosya
/// sessizce yok olur. Kalıcı yapmanın tek yolu "Paylaş → Dosyalar'a kaydet"
/// dolambacıydı.
///
/// Kopya `Download/` köküne gider: orası [StorageStats.hotFolders] içinde,
/// yani "Yeni Dosyalar" listesine kendiliğinden düşer (kopyanın değişme
/// zamanı "şimdi").
class SaveToDownloads {
  SaveToDownloads._();

  /// Birincil depolamadaki İndirilenler klasörü.
  static String get downloadDir => p.join(FmEnv.primaryRoot, 'Download');

  /// [path] kullanıcının göremediği bir yerde mi (uygulamanın özel önbelleği
  /// ya da `Android/data/<paket>`)? "İndir" düğmesi yalnız bunlarda anlamlı:
  /// zaten depolamada duran dosyayı İndirilenler'e kopyalamak kopya üretir.
  ///
  /// Saf fonksiyon — birim testli.
  static bool isPrivateCopy(String path, List<String> publicRoots) {
    final normalized = p.normalize(path);
    for (final root in publicRoots) {
      final r = p.normalize(root);
      if (!p.isWithin(r, normalized)) continue;
      // Uygulama klasörleri birimin içinde ama kullanıcıya kapalı
      // (Android 11+ `Android/data` erişimi yok).
      return p.isWithin(p.join(r, 'Android', 'data'), normalized);
    }
    return true;
  }

  /// [dir] içinde [name] için boş bir ad: `rapor.pdf`, `rapor (1).pdf`, …
  ///
  /// Saf fonksiyon — birim testli.
  static String uniqueName(String name, bool Function(String name) taken) {
    if (!taken(name)) return name;
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    for (var i = 1;; i++) {
      final candidate = '$base ($i)$ext';
      if (!taken(candidate)) return candidate;
    }
  }

  /// Dosyayı İndirilenler'e kopyalar. Aynı adla **aynı içerik** zaten varsa
  /// ikinci kopya üretmez, onu döndürür (tarayıcıdan aynı PDF'i iki kez açmak
  /// "rapor (1).pdf" yığını bırakmasın).
  ///
  /// [name] verilmezse kaynağın adı kullanılır. Hata fırlatabilir (izin yok,
  /// yer yok) — çağıran kullanıcıya söyler. [intoDir] yalnız testler için
  /// (İndirilenler yerine geçici klasör).
  static Future<SavedDownload> saveFile(
    String source, {
    String? name,
    String? intoDir,
  }) async {
    return _save(name ?? p.basename(source), File(source), intoDir: intoDir);
  }

  /// Bellekteki baytları (editörün o anki içeriği) İndirilenler'e yazar.
  static Future<SavedDownload> saveBytes(
    String name,
    List<int> bytes, {
    String? intoDir,
  }) async {
    return _save(name, null, bytes: bytes, intoDir: intoDir);
  }

  static Future<SavedDownload> _save(
    String name,
    File? source, {
    List<int>? bytes,
    String? intoDir,
  }) async {
    if (intoDir == null) await FmEnv.ensureInit();
    final dir = Directory(intoDir ?? downloadDir);
    if (!dir.existsSync()) await dir.create(recursive: true);
    final safeName = _safeName(name);

    final existing = File(p.join(dir.path, safeName));
    if (existing.existsSync() &&
        await _sameContent(existing, source: source, bytes: bytes)) {
      return SavedDownload(existing.path, alreadyThere: true);
    }

    final target = File(p.join(
      dir.path,
      uniqueName(safeName, (n) => File(p.join(dir.path, n)).existsSync()),
    ));
    if (source != null) {
      await source.copy(target.path);
    } else {
      await target.writeAsBytes(bytes!, flush: true);
    }
    FsEvents.changed();
    return SavedDownload(target.path, alreadyThere: false);
  }

  /// Dosya adında klasör ayırıcısı ya da boşluk kalmasın.
  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[/\\]'), '_').trim();
    return cleaned.isEmpty ? 'dosya' : cleaned;
  }

  /// Önce boy (ucuz), eşitse içerik. Büyük dosyada içerik karşılaştırması
  /// parça parça — belleğe iki kez 200 MB video almamak için.
  static Future<bool> _sameContent(
    File existing, {
    File? source,
    List<int>? bytes,
  }) async {
    final length = await existing.length();
    if (bytes != null) {
      if (bytes.length != length) return false;
      final have = await existing.readAsBytes();
      for (var i = 0; i < length; i++) {
        if (have[i] != bytes[i]) return false;
      }
      return true;
    }
    if (source == null || await source.length() != length) return false;
    final a = await existing.open();
    final b = await source.open();
    try {
      const chunk = 1 << 20;
      while (true) {
        final x = await a.read(chunk);
        final y = await b.read(chunk);
        if (x.length != y.length) return false;
        if (x.isEmpty) return true;
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return false;
        }
      }
    } finally {
      await a.close();
      await b.close();
    }
  }
}

/// [SaveToDownloads] sonucu.
class SavedDownload {
  /// İndirilenler'deki dosyanın yolu.
  final String path;

  /// Aynı içerik zaten oradaydı (yeni kopya yazılmadı).
  final bool alreadyThere;

  const SavedDownload(this.path, {required this.alreadyThere});
}
