import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';

/// Dosyaların hangi ölçüte göre klasörleneceği.
enum OrganizeBy { type, date, source }

extension OrganizeByInfo on OrganizeBy {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        OrganizeBy.type => 'enum.org_type',
        OrganizeBy.date => 'enum.org_date',
        OrganizeBy.source => 'enum.org_source',
      };

  String get descriptionKey => switch (this) {
        OrganizeBy.type => 'enum.org_type_desc',
        OrganizeBy.date => 'enum.org_date_desc',
        OrganizeBy.source => 'enum.org_source_desc',
      };

  String get label => switch (this) {
        OrganizeBy.type => 'Türüne göre',
        OrganizeBy.date => 'Tarihine göre',
        OrganizeBy.source => 'Kaynağına göre',
      };

  String get description => switch (this) {
        OrganizeBy.type => 'Görüntüler, Videolar, Belgeler…',
        OrganizeBy.date => '2026-07, 2026-06…',
        OrganizeBy.source => 'Kamera, WhatsApp, İndirilenler…',
      };
}

/// Tek bir dosyanın planlanan yeni yeri.
class OrganizeMove {
  final FsEntry entry;

  /// Hedef **alt klasör adı** (kök klasöre göre göreli).
  final String folder;
  const OrganizeMove(this.entry, this.folder);
}

/// Bir düzenleme planı: hangi dosya nereye gidecek + klasör özetleri.
class OrganizePlan {
  final List<OrganizeMove> moves;

  /// Klasör adı → dosya sayısı (önizleme listesi).
  final Map<String, int> folderCounts;

  /// Zaten doğru klasörde olduğu için dokunulmayacak dosya sayısı.
  final int alreadyPlaced;

  const OrganizePlan({
    required this.moves,
    required this.folderCounts,
    required this.alreadyPlaced,
  });

  static const empty =
      OrganizePlan(moves: [], folderCounts: {}, alreadyPlaced: 0);

  bool get isEmpty => moves.isEmpty;
  int get fileCount => moves.length;
  int get folderCount => folderCounts.length;
  int get bytes => moves.fold(0, (sum, m) => sum + m.entry.sizeBytes);
}

/// **Otomatik düzenleme planı** üretir — hiçbir dosyaya dokunmadan.
///
/// Plan/uygula ayrımı bilinçli: kullanıcı 3.000 dosyayı taşımadan ÖNCE ne
/// olacağını görmeli ("6 klasör, 812 dosya"). Dosya sistemine dokunan tek yer
/// `FileOps.moveAll`; buradaki her şey saf ve test edilebilir.
///
/// Kurallar:
/// - Dosya zaten doğru adlı klasörün İÇİNDEYSE taşınmaz ([alreadyPlaced]).
/// - Klasörler (dizinler) plana girmez: klasör taşımak kullanıcının kendi
///   düzenini bozar.
/// - Tek dosyalık gruplar da klasörlenir; "Diğer" çöplüğü üretmek yerine
///   ölçütün kendi adı kullanılır (tahmin edilebilirlik > az klasör).
OrganizePlan planOrganize(
  Iterable<FsEntry> entries,
  OrganizeBy by, {
  DateTime? now,
}) {
  final moves = <OrganizeMove>[];
  final counts = <String, int>{};
  var already = 0;

  for (final entry in entries) {
    if (entry.isDir) continue;
    final folder = _folderFor(entry, by);
    if (folder.isEmpty) continue;
    // Zaten hedef klasörde mi? (Üst klasörün adı hedefle aynıysa.)
    if (p.basename(p.dirname(entry.path)) == folder) {
      already++;
      continue;
    }
    moves.add(OrganizeMove(entry, folder));
    counts[folder] = (counts[folder] ?? 0) + 1;
  }

  return OrganizePlan(
    moves: moves,
    folderCounts: counts,
    alreadyPlaced: already,
  );
}

String _folderFor(FsEntry entry, OrganizeBy by) => switch (by) {
      OrganizeBy.type => entry.category.label,
      // "2026-07" biçimi sıralanabilir: klasör listesi kendiliğinden kronolojik.
      OrganizeBy.date => _yearMonth(entry.modifiedMs),
      OrganizeBy.source => bucketForPath(entry.path).label,
    };

String _yearMonth(int ms) {
  if (ms <= 0) return 'Tarihsiz';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
