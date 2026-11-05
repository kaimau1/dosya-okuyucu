import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';

/// Tek bir dosyanın yeniden adlandırma önizlemesi.
class RenamePreview {
  final FsEntry entry;
  final String newName;

  /// Sorun varsa açıklaması (çakışma, boş ad…); null ise sağlam.
  final String? problem;

  const RenamePreview(this.entry, this.newName, {this.problem});

  bool get changed => newName != entry.name;
  bool get isValid => problem == null && newName.trim().isNotEmpty;
}

/// **Toplu yeniden adlandırma** planlayıcısı (saf, test edilebilir).
///
/// Kalıptaki yer tutucular:
/// - `{ad}`     → uzantısız eski ad
/// - `{n}`      → sıra numarası ([startAt]'ten başlar)
/// - `{n2}`/`{n3}` → sıfır dolgulu sıra (01, 001)
/// - `{tarih}`  → dosyanın değiştirilme tarihi (2026-07-29)
/// - `{uzanti}` → uzantı (noktasız)
///
/// Uzantı kalıpta geçmiyorsa **otomatik korunur**: kullanıcı `.jpg`'yi
/// yanlışlıkla silerse dosya açılamaz hâle gelir; bu sessiz veri kaybıdır.
///
/// [find]/[replace] verilirse önce eski ad üzerinde değiştirme uygulanır
/// (kalıp `{ad}` kullanıyorsa sonucu etkiler).
List<RenamePreview> planBatchRename(
  List<FsEntry> entries, {
  required String pattern,
  int startAt = 1,
  String find = '',
  String replace = '',
}) {
  final out = <RenamePreview>[];
  final used = <String>{};
  var index = startAt;

  for (final entry in entries) {
    final ext = entry.extension;
    var base = ext.isEmpty
        ? entry.name
        : entry.name.substring(0, entry.name.length - ext.length - 1);
    if (find.isNotEmpty) base = base.replaceAll(find, replace);

    final date = entry.modifiedMs <= 0
        ? ''
        : _isoDate(DateTime.fromMillisecondsSinceEpoch(entry.modifiedMs));

    // Faz 41 / 1: büyük/küçük harf ve klasör adı yer tutucuları. Türkçe
    // i/İ ve ı/I doğru çevrilir (Dart'ın toUpperCase'i 'i'yi 'I' yapar).
    var name = pattern
        .replaceAll('{AD}', trUpper(base))
        .replaceAll('{ad_kucuk}', trLower(base))
        .replaceAll('{klasor}', p.basename(p.dirname(entry.path)))
        .replaceAll('{ad}', base)
        .replaceAll('{n3}', index.toString().padLeft(3, '0'))
        .replaceAll('{n2}', index.toString().padLeft(2, '0'))
        .replaceAll('{n}', index.toString())
        .replaceAll('{tarih}', date)
        .replaceAll('{uzanti}', ext)
        .trim();

    // Yol ayracı ve kontrol karakterleri temizlenir (FileOps.sanitizeName ile
    // aynı kural; burada tekrar edilmesi bilinçli — plan saf kalsın).
    name = name.replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_').trim();

    // Uzantı korunur (kalıpta zaten varsa ikinci kez eklenmez).
    if (ext.isNotEmpty && !name.toLowerCase().endsWith('.${ext.toLowerCase()}')) {
      name = '$name.$ext';
    }

    String? problem;
    if (name.isEmpty || name == '.$ext') {
      problem = 'ad boş kalıyor';
    } else if (!used.add(_key(entry, name))) {
      problem = 'aynı klasörde bu ad zaten üretildi';
    }

    out.add(RenamePreview(entry, name, problem: problem));
    index++;
  }
  return out;
}

/// Çakışma denetimi klasör bazlıdır: farklı klasörlerdeki aynı ad sorun değil.
/// Türkçe kurallı büyük harf (i → İ, ı → I).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Türkçe kurallı küçük harf (I → ı, İ → i).
String trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

String _key(FsEntry entry, String name) =>
    '${p.dirname(entry.path)}|${name.toLowerCase()}';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Hazır kalıplar (arayüzde tek dokunuşla seçilir).
///
/// `labelKey` çeviri anahtarıdır (bu dosya saf Dart, `AppStrings`'i tanımaz).
/// **Kalıbın kendisi çevrilmez:** `{ad}` `{n}` `{n2}` `{tarih}` `{uzanti}`
/// yer tutucuları [applyBatchRename]'in sözleşmesidir ve birim testlidir;
/// çevrilirse eşleşme sessizce bozulur. Kullanıcı kalıbı zaten kutuda
/// düzenleyebiliyor.
const batchRenamePresets = <({String labelKey, String pattern})>[
  (labelKey: 'br.preset_prefix', pattern: 'Tatil-{n}'),
  (labelKey: 'br.preset_date_seq', pattern: '{tarih}-{n2}'),
  (labelKey: 'br.preset_name_seq', pattern: '{ad}-{n2}'),
  (labelKey: 'br.preset_date_name', pattern: '{tarih}-{ad}'),
];

/// Desteklenen yer tutucular (sayfadaki yardım satırı).
const batchRenamePlaceholders =
    '{ad} {AD} {ad_kucuk} {n} {n2} {n3} {tarih} {klasor} {uzanti}';

/// **Kullanıcının kaydettiği kalıplar** (Faz 41 / 1). En çok [max]; en son
/// kaydedilen başta; aynı kalıp ikinci kez eklenmez. Kalıcılık çağıranın
/// işi değil: [load]/[save] `SharedPreferences` üzerinden.
class BatchRenameTemplates {
  static const prefKey = 'fm_rename_templates';
  static const max = 12;

  static List<String> add(List<String> current, String pattern) {
    final t = pattern.trim();
    if (t.isEmpty) return current;
    return [t, ...current.where((e) => e != t)].take(max).toList();
  }

  static List<String> remove(List<String> current, String pattern) =>
      current.where((e) => e != pattern).toList();
}
