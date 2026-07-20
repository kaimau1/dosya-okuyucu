import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_file.dart';
import '../services/firebase_service.dart';

/// Uygulama genel durumu: tema, AI ayarları, son açılan dosyalar.
/// SharedPreferences ile kalıcı; Firebase senkronu build-2'de eklenecek.
class AppState extends ChangeNotifier {
  static const _kApiKey = 'gemini_api_key';
  static const _kModel = 'gemini_model';
  static const _kThemeMode = 'theme_mode';
  static const _kRecents = 'recent_files';
  static const _kMemory = 'ai_memory';

  late SharedPreferences _prefs;

  final FirebaseService firebase = FirebaseService();
  String? _uid;
  String? _userEmail;

  String _apiKey = '';
  String _model = 'gemini-2.0-flash';
  ThemeMode _themeMode = ThemeMode.system;
  List<RecentFile> _recents = [];
  List<String> _memory = [];

  String get apiKey => _apiKey;
  String get model => _model;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  ThemeMode get themeMode => _themeMode;
  List<RecentFile> get recents => List.unmodifiable(_recents);

  /// AI'nın kalıcı hafızası (RAG-lite): kaydedilen bilgi notları.
  List<String> get memory => List.unmodifiable(_memory);

  bool get firebaseAvailable => firebase.available;
  bool get signedIn => _uid != null;
  String? get userEmail => _userEmail;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiKey = _prefs.getString(_kApiKey) ?? '';
    _model = _prefs.getString(_kModel) ?? 'gemini-2.0-flash';
    _themeMode = _themeModeFromString(_prefs.getString(_kThemeMode));
    _recents = (_prefs.getStringList(_kRecents) ?? [])
        .map(RecentFile.tryDecode)
        .whereType<RecentFile>()
        .toList();
    _memory = _prefs.getStringList(_kMemory) ?? [];
    notifyListeners();

    // Firebase'i güvenli başlat; config yoksa yerel modda kalır.
    await firebase.init();
    if (firebase.available) {
      firebase.authState().listen(_onAuthChanged);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _uid = user?.uid;
    _userEmail = user?.email;
    if (user != null) {
      await _mergeFromCloud(user.uid);
    }
    notifyListeners();
  }

  /// Buluttaki veriyi yerelle birleştirir (recents + memory) ve geri yazar.
  Future<void> _mergeFromCloud(String uid) async {
    final data = await firebase.pull(uid);
    if (data != null) {
      final cloudRecents = (data['recents'] as List? ?? [])
          .whereType<Map>()
          .map((m) => RecentFile.tryDecode(_encodeMap(m)))
          .whereType<RecentFile>();
      final byPath = <String, RecentFile>{};
      for (final r in [..._recents, ...cloudRecents]) {
        final existing = byPath[r.path];
        if (existing == null || r.openedAtMs > existing.openedAtMs) {
          byPath[r.path] = r;
        }
      }
      _recents = byPath.values.toList()
        ..sort((a, b) => b.openedAtMs.compareTo(a.openedAtMs));
      if (_recents.length > 40) _recents = _recents.sublist(0, 40);

      final cloudMemory = (data['memory'] as List? ?? []).whereType<String>();
      final mergedMemory = <String>{..._memory, ...cloudMemory}.toList();
      _memory = mergedMemory.length > 200
          ? mergedMemory.sublist(0, 200)
          : mergedMemory;

      await _persistRecents();
      await _prefs.setStringList(_kMemory, _memory);
    }
    await _pushToCloud();
  }

  Future<void> _pushToCloud() async {
    if (_uid == null || !firebase.available) return;
    await firebase.push(
      _uid!,
      recents: _recents.map((r) => r.toMap()).toList(),
      memory: _memory,
    );
  }

  String _encodeMap(Map m) =>
      RecentFile(
        path: (m['path'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        openedAtMs: (m['openedAtMs'] as num?)?.toInt() ?? 0,
      ).encode();

  Future<String?> signInWithEmail(String email, String password) =>
      firebase.signInWithEmail(email, password);
  Future<String?> registerWithEmail(String email, String password) =>
      firebase.registerWithEmail(email, password);
  Future<String?> signInWithGoogle() => firebase.signInWithGoogle();
  Future<void> signOut() async {
    await firebase.signOut();
    _uid = null;
    _userEmail = null;
    notifyListeners();
  }

  Future<void> setApiKey(String value) async {
    _apiKey = value.trim();
    await _prefs.setString(_kApiKey, _apiKey);
    notifyListeners();
  }

  Future<void> setModel(String value) async {
    _model = value.trim();
    await _prefs.setString(_kModel, _model);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> _persistRecents() =>
      _prefs.setStringList(_kRecents, _recents.map((r) => r.encode()).toList());

  Future<void> addRecent(RecentFile file) async {
    _recents.removeWhere((r) => r.path == file.path);
    _recents.insert(0, file);
    if (_recents.length > 40) _recents = _recents.sublist(0, 40);
    await _persistRecents();
    notifyListeners();
    await _pushToCloud();
  }

  Future<void> removeRecent(String path) async {
    _recents.removeWhere((r) => r.path == path);
    await _persistRecents();
    notifyListeners();
    await _pushToCloud();
  }

  Future<void> addMemory(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    _memory.insert(0, trimmed);
    if (_memory.length > 200) _memory = _memory.sublist(0, 200);
    await _prefs.setStringList(_kMemory, _memory);
    notifyListeners();
    await _pushToCloud();
  }

  Future<void> removeMemory(int index) async {
    if (index < 0 || index >= _memory.length) return;
    _memory.removeAt(index);
    await _prefs.setStringList(_kMemory, _memory);
    notifyListeners();
    await _pushToCloud();
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
