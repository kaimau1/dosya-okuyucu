import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_file.dart';

/// Uygulama genel durumu: tema, AI ayarları, son açılan dosyalar.
/// SharedPreferences ile kalıcı; Firebase senkronu build-2'de eklenecek.
class AppState extends ChangeNotifier {
  static const _kApiKey = 'gemini_api_key';
  static const _kModel = 'gemini_model';
  static const _kThemeMode = 'theme_mode';
  static const _kRecents = 'recent_files';
  static const _kMemory = 'ai_memory';

  late SharedPreferences _prefs;

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

  Future<void> addRecent(RecentFile file) async {
    _recents.removeWhere((r) => r.path == file.path);
    _recents.insert(0, file);
    if (_recents.length > 40) _recents = _recents.sublist(0, 40);
    await _prefs.setStringList(
      _kRecents,
      _recents.map((r) => r.encode()).toList(),
    );
    notifyListeners();
  }

  Future<void> removeRecent(String path) async {
    _recents.removeWhere((r) => r.path == path);
    await _prefs.setStringList(
      _kRecents,
      _recents.map((r) => r.encode()).toList(),
    );
    notifyListeners();
  }

  Future<void> addMemory(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    _memory.insert(0, trimmed);
    if (_memory.length > 200) _memory = _memory.sublist(0, 200);
    await _prefs.setStringList(_kMemory, _memory);
    notifyListeners();
  }

  Future<void> removeMemory(int index) async {
    if (index < 0 || index >= _memory.length) return;
    _memory.removeAt(index);
    await _prefs.setStringList(_kMemory, _memory);
    notifyListeners();
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
