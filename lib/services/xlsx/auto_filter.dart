/// B10 m.5 — süzgeç/sıralama 2: sütun süzgeci ölçütü (değer listesi,
/// "içerir", ilk/son N, dolgu rengi) ve dosyadaki `<autoFilter>` içeriği
/// (`filterColumn` + `sortState`).
///
/// Bir sütunda tek ölçüt türü (Excel'deki gibi): [top] > [contains] >
/// [fillArgb] > değer listesi ([hiddenValues]).
library;

import 'package:xml/xml.dart';

class ColumnFilter {
  /// İşaretsiz (gizlenen) ham değerler; değer listesi süzgeci.
  final Set<String> hiddenValues;

  /// Metin süzgeci "içerir" (büyük/küçük harf duyarsız).
  final String? contains;

  /// İlk/son N (sayısal değerler).
  final int? top;
  final bool bottom;

  /// Yalnız bu dolgu rengindeki satırlar görünür (null = renk süzgeci yok).
  final int? fillArgb;

  const ColumnFilter({
    this.hiddenValues = const {},
    this.contains,
    this.top,
    this.bottom = false,
    this.fillArgb,
  });

  bool get isEmpty =>
      hiddenValues.isEmpty &&
      (contains == null || contains!.isEmpty) &&
      top == null &&
      fillArgb == null;

  /// [first]..[last] veri satırlarından gizlenecekler.
  Set<int> hiddenRows(int first, int last,
      {required String Function(int r) raw,
      required double? Function(int r) number,
      int? Function(int r)? fill}) {
    final out = <int>{};
    if (top != null) {
      final nums = <double>[
        for (var r = first; r <= last; r++) ?number(r),
      ]..sort();
      final n = top!.clamp(0, nums.length);
      if (n == 0) {
        for (var r = first; r <= last; r++) {
          out.add(r);
        }
        return out;
      }
      final cut = bottom ? nums[n - 1] : nums[nums.length - n];
      for (var r = first; r <= last; r++) {
        final v = number(r);
        if (v == null || (bottom ? v > cut : v < cut)) out.add(r);
      }
      return out;
    }
    final needle = contains?.toLowerCase();
    for (var r = first; r <= last; r++) {
      final v = raw(r);
      final hide = needle != null && needle.isNotEmpty
          ? !v.toLowerCase().contains(needle)
          : fillArgb != null
              ? fill?.call(r) != fillArgb
              : hiddenValues.contains(v);
      if (hide) out.add(r);
    }
    return out;
  }

  /// `<filterColumn>` (colId = süzgeç aralığında 0 tabanlı sütun). Renk
  /// süzgeci `dxfId` ister: burada [kFillArgbAttr] yer tutucusu yazılır,
  /// kaydetme yaması `styles.xml`e `<dxf>` ekleyip gerçek `dxfId` koyar.
  String? toXml(int colId, List<String> allValues) {
    if (isEmpty) return null;
    final String inner;
    if (top != null) {
      inner = '<top10${bottom ? ' top="0"' : ''} val="$top"/>';
    } else if (contains != null && contains!.isNotEmpty) {
      inner = '<customFilters><customFilter val="*${_esc(contains!)}*"/>'
          '</customFilters>';
    } else if (fillArgb != null) {
      final hex = (fillArgb! & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
      inner = '<colorFilter dxfId="0" $kFillArgbAttr="${hex.toUpperCase()}"/>';
    } else {
      final shown = [
        for (final v in allValues)
          if (!hiddenValues.contains(v) && v.isNotEmpty) v,
      ];
      final blank =
          allValues.contains('') && !hiddenValues.contains('') ? ' blank="1"' : '';
      inner = '<filters$blank>'
          '${shown.map((v) => '<filter val="${_esc(v)}"/>').join()}</filters>';
    }
    return '<filterColumn colId="$colId">$inner</filterColumn>';
  }
}

/// Renk süzgecinin kaydetmeye kadar taşıdığı dolgu (dosyaya YAZILMAZ;
/// `xlsx_save_patch` `dxfId`ye çevirip siler).
const kFillArgbAttr = 'fillArgb';

/// Dosyadaki `<filterColumn>` ölçütü (B10 m.5). Değer listesi Excel'de
/// GÖSTERİLEN değerlerdir; gizlenenler sayfadaki gizli satırlardan bulunur
/// ([resolve]). Renk süzgeci (`colorFilter` → dxf) ve "içerir" dışındaki
/// özel ölçütler okunmaz — dosyada korunur. ponytail: Excel değerleri
/// biçimli metin yazar (`1.234,50`); ham değerle eşleşmeyen sayı gizli
/// satırdaysa yine gizli sayılır, görünür satıra etkisi yok.
class FileFilter {
  final ColumnFilter base;
  final Set<String>? shown;
  final bool blank;
  const FileFilter(this.base, {this.shown, this.blank = false});

  static FileFilter? parse(XmlElement fc) {
    for (final e in fc.childElements) {
      switch (e.name.local) {
        case 'filters':
          return FileFilter(const ColumnFilter(),
              shown: {
                for (final f in e.childElements)
                  if (f.name.local == 'filter') f.getAttribute('val') ?? '',
              },
              blank: e.getAttribute('blank') == '1' ||
                  e.getAttribute('blank') == 'true');
        case 'top10':
          final n = int.tryParse(e.getAttribute('val') ?? '');
          if (n == null || e.getAttribute('percent') == '1') return null;
          final top = e.getAttribute('top');
          return FileFilter(
              ColumnFilter(top: n, bottom: top == '0' || top == 'false'));
        case 'customFilters':
          final cs = e.childElements
              .where((c) => c.name.local == 'customFilter')
              .toList();
          if (cs.length != 1 || cs.first.getAttribute('operator') != null) {
            return null;
          }
          final v = cs.first.getAttribute('val') ?? '';
          if (v.length < 3 || !v.startsWith('*') || !v.endsWith('*')) {
            return null;
          }
          return FileFilter(
              ColumnFilter(contains: v.substring(1, v.length - 1)));
      }
    }
    return null;
  }

  /// [hiddenValues]: süzgeç aralığında GİZLİ satırların değerleri.
  ColumnFilter resolve(Iterable<String> hiddenValues) {
    final s = shown;
    if (s == null) return base;
    return ColumnFilter(hiddenValues: {
      for (final v in hiddenValues)
        if (v.isEmpty ? !blank : !s.contains(v)) v,
    });
  }
}

/// Süzgeç aralığının sıralama düzeyi: mutlak sütun + yön.
typedef SortLevelRef = ({int col, bool descending});

/// `<autoFilter>` iç XML'i: sütun süzgeçleri + `sortState`. [r1] başlık
/// satırı, veri [r1]+1..[r2].
String autoFilterInnerXml({
  required int r1,
  required int c1,
  required int r2,
  required int c2,
  required Map<int, ColumnFilter> filters,
  required List<String> Function(int col) valuesOf,
  List<SortLevelRef> sort = const [],
}) {
  final b = StringBuffer();
  for (final c in filters.keys.toList()..sort()) {
    if (c < c1 || c > c2) continue;
    final x = filters[c]!.toXml(c - c1, valuesOf(c));
    if (x != null) b.write(x);
  }
  if (sort.isNotEmpty && r2 > r1) {
    b.write('<sortState ref="${_ref(r1 + 1, c1, r2, c2)}">');
    for (final s in sort) {
      b.write('<sortCondition${s.descending ? ' descending="1"' : ''} '
          'ref="${_ref(r1 + 1, s.col, r2, s.col)}"/>');
    }
    b.write('</sortState>');
  }
  return b.toString();
}

String _col(int c) {
  var n = c + 1;
  final s = <int>[];
  while (n > 0) {
    s.add(65 + (n - 1) % 26);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(s.reversed);
}

String _ref(int r1, int c1, int r2, int c2) =>
    '${_col(c1)}${r1 + 1}:${_col(c2)}${r2 + 1}';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
