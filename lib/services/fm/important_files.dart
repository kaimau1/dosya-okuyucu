import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **Önemli dosyalar** — adlandırma ve tanıma kuralları (saf, testli).
///
/// Kullanıcı isteği (2026-11-04): *"önemli dosyalara kopyalanmış her türlü
/// dosyanın üzerinde yıldız simgesi olsun her nerede olursa olsun ve
/// kopyalanan dosyanın adının sonuna onemli yazılsın ki karışmasın,
/// yanlışlıkla silinmesin; ayrıca silinmesi istendiğinde tekli veya toplu
/// silme içerisinde onlar onay alınmadan silinmesin."*
///
/// Kararlar:
/// - Kopya adı `rapor.pdf` → `rapor_onemli.pdf` (uzantıdan ÖNCE: dosya yine
///   aynı uygulamayla açılır). Klasörde sona eklenir. Ek ASCII (`_onemli`):
///   bilgisayara, USB'ye, buluta giden adda Türkçe harf sorun çıkarmasın.
/// - "Önemli" sayılan: adında ek olan HER dosya (galeri, kategori, arama,
///   son açılanlar — nerede görünürse görünsün) + Önemli Dosyalar klasörünün
///   kendisi ve içindeki her şey.
/// - Silme: önemli öğe için onay HİÇBİR ayarla atlanmaz (bkz.
///   `deleteEntries`); otomatik temizlik önerileri onlara hiç dokunmaz.
abstract final class ImportantFiles {
  /// Klasörün adı. DİKKAT: dosya sisteminde gerçek dizin adı — çevrilmez.
  static const folderName = 'Önemli Dosyalar';

  /// Kopyanın adına eklenen iz.
  static const suffix = '_onemli';

  /// `rapor_onemli`, `rapor_onemli (1)` (aynı adlı ikinci kopya) ve büyük/
  /// küçük harf farkı da tanınır.
  static final _marked = RegExp(r'_onemli(?: \(\d+\))?$', caseSensitive: false);

  static String folderIn(String root) => p.join(root, folderName);

  /// Adın (uzantısız gövdesinde) önemli izi var mı?
  static bool hasMark(String name, {bool isDir = false}) {
    final stem = isDir ? name : p.basenameWithoutExtension(name);
    return _marked.hasMatch(stem);
  }

  /// Önemli kopyanın adı. İz zaten varsa ad değişmez (iki kez eklenmez).
  static String markedName(String name, {bool isDir = false}) {
    if (hasMark(name, isDir: isDir)) return name;
    if (isDir) return '$name$suffix';
    final ext = p.extension(name);
    final stem = ext.isEmpty ? name : name.substring(0, name.length - ext.length);
    if (stem.isEmpty) return '$name$suffix';
    return '$stem$suffix$ext';
  }

  /// Kaynağın ([src]) Önemli Dosyalar'daki kopya adı (klasör mü, diske bakar).
  static String markedNameFor(String src) =>
      markedName(p.basename(src), isDir: Directory(src).existsSync());

  /// [path] önemli mi? [root] verilmezse ana bellek ([FmEnv.primaryRoot]).
  static bool isImportant(String path, {String? root}) {
    if (path.isEmpty) return false;
    final base = p.basename(path);
    // Klasörlerin uzantısı yok sayılır: `Tez_onemli.v2` gibi bir klasör adı
    // nadir; iki biçimi de denemek ucuz.
    if (hasMark(base) || hasMark(base, isDir: true)) return true;
    final folder = folderIn(root ?? FmEnv.primaryRoot);
    return p.equals(folder, path) || p.isWithin(folder, path);
  }

  /// Silinecekleri ikiye ayırır: (önemli, diğerleri) — sıra korunur.
  static (List<T>, List<T>) split<T>(Iterable<T> items, String Function(T) pathOf,
      {String? root}) {
    final important = <T>[];
    final rest = <T>[];
    for (final item in items) {
      (isImportant(pathOf(item), root: root) ? important : rest).add(item);
    }
    return (important, rest);
  }
}
