import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'doc_classifier.dart';

/// **Önemli Galeri** süzgeç modeli (2026-11-10, kullanıcı: *"önemli
/// dosyalardaki Tümü galerisini ayrı bir ana ekran kartı olarak hazırla;
/// filtre seçenekleri çok daha geniş ve kategorize olsun"*).
///
/// Saf Dart — widget kurmadan birim testlenir. Boyutlar arasında VE, bir
/// boyutun içindeki seçimler arasında VEYA (ör. "PDF veya Word" ve "Bu ay").

/// Galerinin ince türü (FmCategory'den daha ayrıntılı).
enum ImpKind {
  photo,
  screenshot,
  video,
  pdf,
  word,
  sheet,
  slides,
  text,
  book,
  audio,
  archive,
  other,
}

/// Tür levhasındaki gruplar.
enum ImpKindGroup { visual, document, other }

extension ImpKindInfo on ImpKind {
  String get labelKey => 'ig.kind_$name';

  ImpKindGroup get group => switch (this) {
        ImpKind.photo || ImpKind.screenshot || ImpKind.video =>
          ImpKindGroup.visual,
        ImpKind.pdf ||
        ImpKind.word ||
        ImpKind.sheet ||
        ImpKind.slides ||
        ImpKind.text ||
        ImpKind.book =>
          ImpKindGroup.document,
        _ => ImpKindGroup.other,
      };
}

/// Değiştirilme zamanı kovası.
enum ImpTime { today, week, month, year, older }

/// Boyut kovası.
enum ImpSize { small, medium, large, huge }

enum ImpSort { newest, oldest, name, largest }

extension ImpTimeInfo on ImpTime {
  String get labelKey => 'ig.time_$name';
}

extension ImpSizeInfo on ImpSize {
  String get labelKey => 'ig.size_$name';
}

extension ImpSortInfo on ImpSort {
  String get labelKey => 'ig.sort_$name';
}

abstract final class ImpClassify {
  static const _word = {'doc', 'docx', 'odt', 'rtf', 'dot', 'dotx', 'pages'};
  static const _sheet = {'xls', 'xlsx', 'xlsm', 'csv', 'ods', 'tsv', 'numbers'};
  static const _slides = {'ppt', 'pptx', 'pps', 'ppsx', 'odp', 'key'};
  static const _text = {
    'txt', 'md', 'json', 'xml', 'html', 'htm', 'log', 'yaml', 'yml', 'ini',
  };
  static const _book = {'epub', 'mobi', 'azw', 'azw3', 'fb2', 'djvu', 'cbz'};

  static bool _looksScreenshot(String name) {
    final n = name.toLowerCase();
    return n.contains('screenshot') ||
        n.contains('screen_shot') ||
        n.contains('ekran') ||
        n.startsWith('scr_');
  }

  static ImpKind kindOf(FsEntry e) {
    final ext = e.extension.toLowerCase();
    switch (e.category) {
      case FmCategory.image:
        return _looksScreenshot(e.name) ? ImpKind.screenshot : ImpKind.photo;
      case FmCategory.video:
        return ImpKind.video;
      case FmCategory.audio:
        return ImpKind.audio;
      case FmCategory.archive:
      case FmCategory.apk:
        return ImpKind.archive;
      default:
        break;
    }
    if (ext == 'pdf') return ImpKind.pdf;
    if (_word.contains(ext)) return ImpKind.word;
    if (_sheet.contains(ext)) return ImpKind.sheet;
    if (_slides.contains(ext)) return ImpKind.slides;
    if (_text.contains(ext)) return ImpKind.text;
    if (_book.contains(ext)) return ImpKind.book;
    return ImpKind.other;
  }

  static ImpTime timeOf(int modifiedMs, DateTime now) {
    final t = DateTime.fromMillisecondsSinceEpoch(modifiedMs);
    final startOfDay = DateTime(now.year, now.month, now.day);
    if (!t.isBefore(startOfDay)) return ImpTime.today;
    final age = now.difference(t);
    if (age.inDays < 7) return ImpTime.week;
    if (age.inDays < 31) return ImpTime.month;
    if (age.inDays < 366) return ImpTime.year;
    return ImpTime.older;
  }

  static const _mb = 1024 * 1024;

  static ImpSize sizeOf(int bytes) {
    if (bytes < _mb) return ImpSize.small;
    if (bytes < 10 * _mb) return ImpSize.medium;
    if (bytes < 100 * _mb) return ImpSize.large;
    return ImpSize.huge;
  }

  /// Önemli Dosyalar kökünün altındaki üst düzey alt klasör ('' = kök/Genel).
  static String folderOf(String root, String path) {
    final rel = p.relative(path, from: root);
    final parts = p.split(rel);
    return parts.length > 1 ? parts.first : '';
  }

  /// Konu: dosya ADI + alt klasör adından anahtar sözcükle (çevrimdışı;
  /// içerik okunmaz — galeri anında açılmalı). "Faturalar" klasöründeki her
  /// dosya fatura sayılır.
  static DocClass topicOf(String root, String path) {
    final rel = p.relative(path, from: root);
    final text = rel.replaceAll(RegExp(r'[_\-./\\]+'), ' ');
    final guess = classifyDocumentText(text, fileName: p.basename(path));
    if (guess.type != DocClass.diger && guess.score >= 1) return guess.type;
    // Klasör adı DocClass.folder'la birebir eşleşiyorsa (öneriyle açılmış
    // kategori) doğrudan o.
    final folder = folderOf(root, path).toLowerCase();
    for (final c in DocClass.values) {
      if (c != DocClass.diger && c.folder.toLowerCase() == folder) return c;
    }
    return DocClass.diger;
  }
}

/// Bir dosyanın önceden hesaplanmış süzgeç anahtarları (süzme her
/// dokunuşta tüm listeyi yeniden sınıflandırmasın).
class ImpItem {
  final FsEntry entry;
  final ImpKind kind;
  final String folder;
  final DocClass topic;
  final Set<String> tags;

  const ImpItem({
    required this.entry,
    required this.kind,
    required this.folder,
    required this.topic,
    this.tags = const {},
  });

  factory ImpItem.of(String root, FsEntry e, {Set<String> tags = const {}}) =>
      ImpItem(
        entry: e,
        kind: ImpClassify.kindOf(e),
        folder: ImpClassify.folderOf(root, e.path),
        topic: ImpClassify.topicOf(root, e.path),
        tags: tags,
      );
}

class ImpFilter {
  final Set<ImpKind> kinds;
  final Set<String> folders;
  final Set<DocClass> topics;
  final Set<String> tags;
  final Set<ImpTime> times;
  final Set<ImpSize> sizes;
  final String query;
  final ImpSort sort;

  const ImpFilter({
    this.kinds = const {},
    this.folders = const {},
    this.topics = const {},
    this.tags = const {},
    this.times = const {},
    this.sizes = const {},
    this.query = '',
    this.sort = ImpSort.newest,
  });

  static Set<T> _toggle<T>(Set<T> s, T v) =>
      s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  ImpFilter copyWith({
    Set<ImpKind>? kinds,
    Set<String>? folders,
    Set<DocClass>? topics,
    Set<String>? tags,
    Set<ImpTime>? times,
    Set<ImpSize>? sizes,
    String? query,
    ImpSort? sort,
  }) =>
      ImpFilter(
        kinds: kinds ?? this.kinds,
        folders: folders ?? this.folders,
        topics: topics ?? this.topics,
        tags: tags ?? this.tags,
        times: times ?? this.times,
        sizes: sizes ?? this.sizes,
        query: query ?? this.query,
        sort: sort ?? this.sort,
      );

  ImpFilter toggleKind(ImpKind k) => copyWith(kinds: _toggle(kinds, k));
  ImpFilter toggleFolder(String f) => copyWith(folders: _toggle(folders, f));
  ImpFilter toggleTopic(DocClass t) => copyWith(topics: _toggle(topics, t));
  ImpFilter toggleTag(String t) => copyWith(tags: _toggle(tags, t));
  ImpFilter toggleTime(ImpTime t) => copyWith(times: _toggle(times, t));
  ImpFilter toggleSize(ImpSize s) => copyWith(sizes: _toggle(sizes, s));

  /// Tür grubundaki her türü birlikte aç/kapat ("Tüm belgeler").
  ImpFilter toggleGroup(ImpKindGroup g) {
    final members = ImpKind.values.where((k) => k.group == g).toSet();
    final all = members.every(kinds.contains);
    return copyWith(
        kinds: all ? ({...kinds}..removeAll(members)) : {...kinds, ...members});
  }

  int get typeActive => kinds.length;
  int get topicActive => folders.length + topics.length + tags.length;
  int get whenActive => times.length + sizes.length;
  bool get isEmpty =>
      typeActive == 0 && topicActive == 0 && whenActive == 0 && query.isEmpty;

  ImpFilter clearType() => copyWith(kinds: const {});
  ImpFilter clearTopic() =>
      copyWith(folders: const {}, topics: const {}, tags: const {});
  ImpFilter clearWhen() => copyWith(times: const {}, sizes: const {});
  ImpFilter clearAll() => ImpFilter(sort: sort);

  bool matches(ImpItem i, DateTime now) {
    if (kinds.isNotEmpty && !kinds.contains(i.kind)) return false;
    if (folders.isNotEmpty && !folders.contains(i.folder)) return false;
    if (topics.isNotEmpty && !topics.contains(i.topic)) return false;
    if (tags.isNotEmpty && !i.tags.any(tags.contains)) return false;
    if (times.isNotEmpty &&
        !times.contains(ImpClassify.timeOf(i.entry.modifiedMs, now))) {
      return false;
    }
    if (sizes.isNotEmpty &&
        !sizes.contains(ImpClassify.sizeOf(i.entry.sizeBytes))) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !i.entry.name.toLowerCase().contains(q)) return false;
    return true;
  }

  List<ImpItem> apply(List<ImpItem> items, DateTime now) {
    final out = [for (final i in items) if (matches(i, now)) i];
    int byName(ImpItem a, ImpItem b) =>
        a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
    switch (sort) {
      case ImpSort.newest:
        out.sort((a, b) => b.entry.modifiedMs.compareTo(a.entry.modifiedMs));
      case ImpSort.oldest:
        out.sort((a, b) => a.entry.modifiedMs.compareTo(b.entry.modifiedMs));
      case ImpSort.name:
        out.sort(byName);
      case ImpSort.largest:
        out.sort((a, b) => b.entry.sizeBytes.compareTo(a.entry.sizeBytes));
    }
    return out;
  }

  /// "Buna dokunursam kaç dosya kalır" sayısı (öteki ölçütler korunur).
  int countIf(List<ImpItem> items, DateTime now, ImpFilter probe) {
    var n = 0;
    for (final i in items) {
      if (probe.matches(i, now)) n++;
    }
    return n;
  }
}
