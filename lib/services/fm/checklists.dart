import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../gemini_decisions.dart';

/// **Kontrol listesi** (B2 dilim 3, PLAN §1.2): "vize dosyası", "kira
/// sözleşmesi" gibi evrak listesi. Belgeye ya da klasöre uygulanır; her
/// dosyaya listenin maddeleri evet/hayır sorusu olarak (Gemini Decisions)
/// sorulur, madde başına ✓/✗ + güven çıkar, eksik evrak listelenir.
class Checklist {
  final String id;
  final String name;
  final List<String> items;

  const Checklist(this.id, this.name, this.items);

  /// Hazır liste (silinemez).
  bool get builtIn => id.startsWith('p_');

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'items': items};

  static Checklist? fromJson(Object? m) {
    if (m is! Map) return null;
    final id = m['id'], name = m['name'], items = m['items'];
    if (id is! String || name is! String || items is! List) return null;
    final clean = Checklists.parseItems(items.whereType<String>().join('\n'));
    return clean.isEmpty ? null : Checklist(id, name, clean);
  }
}

/// Madde sonucu. [ok] ise [path] maddeyi karşılayan dosya, [confidence]
/// onun P(evet)'i; değilse [confidence] eksik olma olasılığı (1 - en yüksek
/// P(evet)). Hiçbir dosya yanıtlanamadıysa [answered] yanlış, güven 0.
class ChecklistItemResult {
  final String item;
  final bool ok;
  final bool answered;
  final double confidence;
  final String? path;

  const ChecklistItemResult(this.item,
      {required this.ok,
      required this.answered,
      required this.confidence,
      this.path});
}

abstract final class Checklists {
  static const maxItems = 20;
  static const _kSaved = 'ckl_lists';
  static const presetIds = ['visa', 'rent', 'rx', 'discharge', 'job'];

  /// Satır ya da `|` ile ayrılmış maddeler; boş/yinelenen düşer, en çok
  /// [maxItems].
  static List<String> parseItems(String raw) => raw
      .split(RegExp(r'[\n|]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .take(maxItems)
      .toList();

  static List<Checklist> presets(AppStrings s) => [
        for (final id in presetIds)
          Checklist('p_$id', s.t('ckl.p_$id'), parseItems(s.t('ckl.p_${id}_items'))),
      ];

  static Future<List<Checklist>> loadSaved() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kSaved);
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final m in list) ?Checklist.fromJson(m),
      ];
    } catch (_) {
      return []; // Bilinçli: bozuk kayıt → yalnız hazır listeler.
    }
  }

  static Future<void> _write(List<Checklist> lists) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSaved, jsonEncode([for (final c in lists) c.toJson()]));
  }

  /// Adı ve maddeleri olan yeni liste kaydeder (aynı kimlik varsa günceller).
  static Future<List<Checklist>> save(Checklist c) async {
    final all = [
      for (final o in await loadSaved())
        if (o.id != c.id) o,
      c,
    ];
    await _write(all);
    return all;
  }

  static Future<List<Checklist>> delete(String id) async {
    final all = [
      for (final o in await loadSaved())
        if (o.id != id) o,
    ];
    await _write(all);
    return all;
  }

  /// Her madde bir evet/hayır sorusu (kimlik `i<sıra>`).
  static List<DecisionQuestion> questions(Checklist c) => [
        for (var i = 0; i < c.items.length && i < maxItems; i++)
          DecisionQuestion.yesNo(
            'i$i',
            c.items[i],
            'Is this file (or does it clearly contain) the following '
            'document or item: "${c.items[i]}"? Answer true only if it '
            'clearly is or contains it.',
          ),
      ];

  /// Dosya başına yanıtlardan madde sonuçları (saf, test edilebilir).
  static List<ChecklistItemResult> evaluate(
      Checklist c, Map<String, List<DecisionAnswer>> byPath) {
    final out = <ChecklistItemResult>[];
    for (var i = 0; i < c.items.length && i < maxItems; i++) {
      double? best;
      String? bestPath;
      for (final e in byPath.entries) {
        for (final a in e.value) {
          if (a.question.id != 'i$i' || a.yes == null) continue;
          if (best == null || a.yes! > best) {
            best = a.yes;
            bestPath = e.key;
          }
        }
      }
      final ok = best != null && best >= 0.5;
      out.add(ChecklistItemResult(
        c.items[i],
        ok: ok,
        answered: best != null,
        confidence: best == null ? 0 : (ok ? best : 1 - best),
        path: ok ? bestPath : null,
      ));
    }
    return out;
  }

  /// PDF raporun düz yazısı (dosya adları yalnız ad, yol değil).
  static String report(AppStrings s, Checklist c,
      List<ChecklistItemResult> results, int files, DateTime at) {
    String pct(double v) => '%${(v * 100).round()}';
    final ok = results.where((r) => r.ok).length;
    final b = StringBuffer()
      ..writeln(s.t('ckl.report_meta', {
        'n': files,
        'date': '${at.day.toString().padLeft(2, '0')}.'
            '${at.month.toString().padLeft(2, '0')}.${at.year}',
      }))
      ..writeln(s.t('ckl.summary', {'ok': ok, 'total': results.length}))
      ..writeln();
    for (final r in results) {
      final name = r.path?.split(RegExp(r'[\\/]')).last;
      b.writeln(r.ok
          ? '[${s.t('ckl.found')}] ${r.item} — ${pct(r.confidence)}'
              '${name == null ? '' : ' ($name)'}'
          : '[${s.t('ckl.absent')}] ${r.item}'
              '${r.answered ? ' — ${pct(r.confidence)}' : ''}');
    }
    final missing = [
      for (final r in results)
        if (!r.ok) r.item
    ];
    if (missing.isNotEmpty) {
      b
        ..writeln()
        ..writeln(s.t('ckl.missing', {'n': missing.length}))
        ..writeln(missing.map((m) => '• $m').join('\n'));
    }
    return b.toString();
  }
}
