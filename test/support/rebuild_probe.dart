import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// B12 m.3 — editör yeniden kurulum bütçeleri: bir eylemin (bir harf, bir
/// hücre girişi, şekil sürükleme, sayfa değişimi) kaç widget'ı yeniden
/// kurduğunu sayar. Eylemden önce her öğenin widget örneği alınır; sonra
/// widget'ı DEĞİŞEN (yeni örnek = `build`/`update` yoluna giren) ya da yeni
/// doğan öğeler sayılır. Aynı örnekle atlanan alt ağaç sayılmaz — daraltma
/// (önbellek, `const`, seçici dinleyici) doğrudan bu sayıyı düşürür.
class RebuildCount {
  /// Aynı öğe, yeni widget örneği.
  final int updated;

  /// Eylemde doğan öğe.
  final int created;

  /// Tür adı → sayı (`updated + created`).
  final Map<String, int> byType;

  const RebuildCount(this.updated, this.created, this.byType);

  int get total => updated + created;

  /// [type] türündeki yeniden kurulumlar (genel türde tür argümanı dahil ad).
  int of(Type type) => byType['$type'] ?? 0;

  /// `PERF` satırı için en çok kurulan [n] tür.
  String top([int n = 6]) {
    final e = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return e.take(n).map((x) => '${x.key}:${x.value}').join(',');
  }
}

Future<RebuildCount> countRebuilds(
    WidgetTester t, Future<void> Function() action) async {
  final before = <Element, Widget>{
    for (final e in t.allElements) e: e.widget,
  };
  await action();
  var updated = 0, created = 0;
  final byType = <String, int>{};
  for (final e in t.allElements) {
    final w = before[e];
    if (w != null && identical(w, e.widget)) continue;
    if (w == null) {
      created++;
    } else {
      updated++;
    }
    final k = '${e.widget.runtimeType}';
    byType[k] = (byType[k] ?? 0) + 1;
  }
  return RebuildCount(updated, created, byType);
}
