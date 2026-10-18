import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/text_search.dart';
import 'ai_ask.dart';
import 'ai_index.dart';
import 'ai_scope.dart';

/// Kayıtlı bir AI araması.
@immutable
class SmartFolder {
  final String id;
  final String name;

  /// Kullanıcının AI'ya sorduğu cümle ("fatura", "kimlik fotokopileri").
  final String query;
  final int createdMs;

  /// Klasöre en son bakıldığı an — sonra gelen dosyalar "yeni" rozetli.
  final int seenMs;

  const SmartFolder({
    required this.id,
    required this.name,
    required this.query,
    required this.createdMs,
    this.seenMs = 0,
  });

  SmartFolder copyWith({String? name, int? seenMs}) => SmartFolder(
        id: id,
        name: name ?? this.name,
        query: query,
        createdMs: createdMs,
        seenMs: seenMs ?? this.seenMs,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'query': query,
        'created': createdMs,
        'seen': seenMs,
      };

  static SmartFolder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'], query = raw['query'];
    if (id is! String || name is! String || query is! String) return null;
    return SmartFolder(
      id: id,
      name: name,
      query: query,
      createdMs: (raw['created'] as num?)?.toInt() ?? 0,
      seenMs: (raw['seen'] as num?)?.toInt() ?? 0,
    );
  }
}

/// **Akıllı klasörler** (2026-10-18, kullanıcının onayladığı öneri: *"AI
/// aramayı akıllı klasörlere çevirmek: 'fatura' araması kayıtlı bir klasör
/// olarak kalsın, yeni gelen faturalar kendiliğinden eklensin"*).
///
/// Klasör diskte bir dizin DEĞİL, kayıtlı bir sorgudur: her açılışta AI
/// dizininde ([AiIndex]) cihaz üstünde yeniden aranır ([AiAsk.rank] — ağ yok,
/// ücretsiz). Yeni dosya analiz edildikçe kendiliğinden içeri girer; dosya
/// silinince düşer. Gemini'ye yalnız sohbetteki ilk soru gitmişti; klasörün
/// kendisi hiç istek atmaz.
class SmartFolders extends ChangeNotifier {
  SmartFolders._();

  static final instance = SmartFolders._();

  static const _kFolders = 'smart_folders';

  /// Bir klasörde gösterilen en fazla dosya.
  static const maxItems = 400;

  List<SmartFolder> _folders = const [];
  bool _loaded = false;

  List<SmartFolder> get folders => List.unmodifiable(_folders);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kFolders);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          _folders = [
            for (final e in list)
              if (SmartFolder.fromJson(e) case final f?) f,
          ];
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kFolders, jsonEncode([for (final f in _folders) f.toJson()]));
    } catch (_) {}
  }

  /// Sorudan okunur bir klasör adı: ilk harf büyük, fazla boşluk yok.
  static String nameFor(String query) {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return q;
    final cut = q.length > 40 ? '${q.substring(0, 40)}…' : q;
    return cut[0].toUpperCase() + cut.substring(1);
  }

  /// Aynı sorgu zaten kayıtlıysa onu döner (ikinci kopya açılmaz).
  Future<SmartFolder> add(String query, {String? name, int? nowMs}) async {
    await ensureLoaded();
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Karşılaştırma katlanmış: "FATURALARIM" ile "faturalarım" aynı sorgu
    // (Dart'ın `toLowerCase`i Türkçe I/ı'yı bilmiyor).
    for (final f in _folders) {
      if (asciiFold(f.query) == asciiFold(q)) return f;
    }
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final folder = SmartFolder(
      id: 'sf$now',
      name: (name ?? '').trim().isEmpty ? nameFor(q) : name!.trim(),
      query: q,
      createdMs: now,
      seenMs: now,
    );
    _folders = [..._folders, folder];
    await _save();
    return folder;
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    _folders = [
      for (final f in _folders) f.id == id ? f.copyWith(name: name.trim()) : f
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    _folders = [for (final f in _folders) if (f.id != id) f];
    await _save();
  }

  Future<void> markSeen(String id, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _folders = [
      for (final f in _folders) f.id == id ? f.copyWith(seenMs: now) : f
    ];
    await _save();
  }

  /// Klasörün ŞU ANKİ içeriği — en yeni önce.
  static List<AiRecord> contents(SmartFolder folder, AiScope scope) {
    final hits = AiAsk.rank(folder.query, scope: scope, limit: maxItems);
    return [...hits]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
  }

  /// Son bakıştan sonra gelen dosya sayısı.
  static int newCount(SmartFolder folder, List<AiRecord> items) =>
      items.where((r) => r.modifiedMs > folder.seenMs).length;

  @visibleForTesting
  void debugReset() {
    _folders = const [];
    _loaded = false;
  }
}
