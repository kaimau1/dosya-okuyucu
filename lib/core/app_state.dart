import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_language.dart';
import 'theme.dart';
import '../models/fm_layout.dart';
import '../models/fs_entry.dart';
import '../models/media_open_with.dart';
import '../models/photo_group.dart';
import '../models/remote_connection.dart';
import '../models/recent_file.dart';
import '../services/firebase_service.dart';
import '../services/fm/folder_lock.dart';
import '../services/tts_service.dart' show TtsPrefs;

/// Uygulama genel durumu: tema, AI ayarları, son açılan dosyalar.
/// SharedPreferences ile kalıcı; Firebase senkronu build-2'de eklenecek.
class AppState extends ChangeNotifier {
  static const _kApiKey = 'gemini_api_key';
  static const _kModel = 'gemini_model';
  static const _kThemeMode = 'theme_mode';
  static const _kLanguage = 'app_language';
  static const _kRecents = 'recent_files';
  static const _kMemory = 'ai_memory';
  // Dosya yöneticisi tercihleri
  static const _kBookmarks = 'fm_bookmarks';
  static const _kRecentDests = 'fm_recent_destinations';
  static const _kLockPin = 'fm_lock_pin';
  static const _kLockedFolders = 'fm_locked_folders';
  static const _kFmLayout = 'fm_layout';
  static const _kFmPhotoLayout = 'fm_photo_layout';
  static const _kFmPhotoGroup = 'fm_photo_group';
  static const _kFmMediaOpenWith = 'fm_media_open_with';
  static const _kFmSort = 'fm_sort';
  static const _kFmSortDesc = 'fm_sort_desc';
  static const _kFmHidden = 'fm_show_hidden';
  static const _kFmThumbs = 'fm_thumbnails';
  static const _kFmUseTrash = 'fm_use_trash';
  static const _kFmConfirmDelete = 'fm_confirm_delete';
  static const _kFmTrashAutoDays = 'fm_trash_auto_days';
  static const _kRemotes = 'fm_remote_connections';
  static const _kUiFont = 'ui_font';
  static const _kUiTextScale = 'ui_text_scale';
  // Pil ve başarım
  static const _kHighRefresh = 'perf_high_refresh';
  static const _kAutoRescan = 'perf_auto_rescan';
  // Sesli okuma tercihleri (ses/hız/perde + "AI ile oku")
  static const _kTtsPrefs = 'tts_prefs';
  static const _kTtsAiRead = 'tts_ai_read';

  late SharedPreferences _prefs;

  final FirebaseService firebase = FirebaseService();
  String? _uid;
  String? _userEmail;

  String _apiKey = '';
  String _model = 'gemini-2.0-flash';
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.system;

  /// Arayüz yazı tipi. Varsayılan `AppTheme.uiFontDefault` = tasarımın kendi
  /// karışımı (serif başlık + Carlito gövde + tek aralıklı veri satırları);
  /// bir aile seçilirse **başlık dahil her yer** onunla çizilir.
  String _uiFont = AppTheme.uiFontDefault;

  /// Arayüz yazı ölçeği. **Cihazın sistem ayarından BAĞIMSIZ** (bkz.
  /// `DosyaOkuyucuApp`): uygulama her telefonda aynı görünsün, büyütmek
  /// isteyen buradan büyütsün.
  double _uiTextScale = 1.0;

  /// 120 Hz+ ekranlarda yüksek tazeleme hızı isteniyor mu?
  ///
  /// Açıkken kaydırma ve animasyonlar belirgin biçimde akıcı; kapalıyken ekran
  /// 60 Hz'de kalır ve **GPU'nun karesi yarıya iner** — uzun belge okurken en
  /// gözle görülür pil kazancı budur. Varsayılan AÇIK: uygulamanın satır
  /// başlarından biri hız hissi.
  bool _highRefreshRate = true;

  /// Arama dizini bayatlayınca (12 saat) pano kendiliğinden yeniden tarasın mı?
  ///
  /// Tarama tüm depolamayı gezer: on binlerce dosyada dakikalarca CPU + disk.
  /// Kapatan kullanıcı listeleri kendisi tazeler (aşağı çekme) — sık dosya
  /// eklemeyen telefonlarda saf kazanç.
  bool _autoRescan = true;
  List<RecentFile> _recents = [];
  List<String> _memory = [];

  String get apiKey => _apiKey;
  String get model => _model;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  ThemeMode get themeMode => _themeMode;

  /// Arayüz dili. `system` = cihazın dili (desteklenmiyorsa Türkçe).
  AppLanguage get language => _language;

  /// Arayüz yazı tipi: gömülü aile adı ya da `AppTheme.uiFontDefault`.
  String get uiFont => _uiFont;

  /// Arayüz yazı ölçeği (1.0 = tasarım boyutu). Sistem ayarı okunmaz.
  double get uiTextScale => _uiTextScale;

  Future<void> setUiFont(String family) async {
    _uiFont = family;
    await _prefs.setString(_kUiFont, family);
    notifyListeners();
  }

  /// Ölçek 0,85–1,40 arasına kısılır: altında dokunma hedefleri okunmaz
  /// küçüklüğe, üstünde çubuk/etiketler taşmaya başlıyor.
  /// Yüksek tazeleme hızı tercihi (bkz. [_highRefreshRate]).
  bool get highRefreshRate => _highRefreshRate;

  /// Otomatik arka plan taraması tercihi (bkz. [_autoRescan]).
  bool get autoRescan => _autoRescan;

  Future<void> setHighRefreshRate(bool value) async {
    _highRefreshRate = value;
    await _prefs.setBool(_kHighRefresh, value);
    notifyListeners();
  }

  Future<void> setAutoRescan(bool value) async {
    _autoRescan = value;
    await _prefs.setBool(_kAutoRescan, value);
    notifyListeners();
  }

  Future<void> setUiTextScale(double value) async {
    _uiTextScale = value.clamp(0.85, 1.4);
    await _prefs.setDouble(_kUiTextScale, _uiTextScale);
    notifyListeners();
  }
  List<RecentFile> get recents => List.unmodifiable(_recents);

  /// AI'nın kalıcı hafızası (RAG-lite): kaydedilen bilgi notları.
  List<String> get memory => List.unmodifiable(_memory);

  // ── Dosya yöneticisi durumu ───────────────────────────────────────────────
  List<String> _bookmarks = [];
  List<String> _recentDests = [];
  String _fmLockPinHash = '';
  List<String> _lockedFolders = [];
  FmLayout _fmLayout = FmLayout.list;
  FmLayout _fmPhotoLayout = FmLayout.grid3;
  PhotoGroup _fmPhotoGroup = PhotoGroup.day;
  MediaOpenWith _fmMediaOpenWith = MediaOpenWith.ask;
  FmSort _fmSort = FmSort.name;
  bool _fmSortDesc = false;
  bool _fmShowHidden = false;
  List<String> _clipboard = [];
  bool _clipboardCut = false;
  bool _fmThumbnails = true;
  bool _fmUseTrash = true;
  bool _fmConfirmDelete = true;
  int _fmTrashAutoDays = 0;
  List<RemoteConnection> _remotes = [];
  TtsPrefs _ttsPrefs = TtsPrefs.defaults;
  bool _ttsAiRead = false;

  /// Kayıtlı uzak depolama bağlantıları (FTP/FTPS/SFTP/SMB/WebDAV).
  ///
  /// Parola YALNIZ `savePassword` açıkken diske yazılır (bkz.
  /// [RemoteConnection]); kapalıysa bellekteki nesne parolayı oturum boyunca
  /// taşır ama kayıt parolasız kalır.
  List<RemoteConnection> get remotes => List.unmodifiable(_remotes);

  /// Kullanıcının yıldızladığı klasörler (kalıcı).
  List<String> get bookmarks => List.unmodifiable(_bookmarks);

  /// Klasör kilidi PIN özeti (boşsa kilit kurulmamış).
  String get fmLockPinHash => _fmLockPinHash;
  bool get fmHasLockPin => _fmLockPinHash.isNotEmpty;

  /// Kilitli klasörler (bunların altındaki her şey gizlenir).
  List<String> get fmLockedFolders => List.unmodifiable(_lockedFolders);

  /// **Son taşıma/kopyalama hedefleri** (en yeni başta, en çok 8).
  ///
  /// Kullanıcı isteği (2026-07-29): "taşıma kopyalama şu an çok zor".
  /// İnsanlar dosyaları hep aynı birkaç klasöre koyar; hedef seçicide bunlar
  /// tek dokunuşla gelsin diye hatırlanır.
  List<String> get fmRecentDestinations => List.unmodifiable(_recentDests);

  /// Klasör/kategori listelerinin yerleşimi (liste, büyük liste, 2–5 sütun).
  FmLayout get fmLayout => _fmLayout;

  /// Görsel/video (Fotoğraflar) ekranının yerleşimi — ayrı tutulur: kullanıcı
  /// dosyalarda listeyi, fotoğraflarda ızgarayı ister.
  FmLayout get fmPhotoLayout => _fmPhotoLayout;

  /// Fotoğraflar ekranındaki zaman gruplaması (gün/ay/yıl).
  PhotoGroup get fmPhotoGroup => _fmPhotoGroup;

  /// Video/ses/görsel neyle açılsın (sor / uygulama içi / başka uygulama).
  MediaOpenWith get fmMediaOpenWith => _fmMediaOpenWith;

  FmSort get fmSort => _fmSort;
  bool get fmSortDesc => _fmSortDesc;
  bool get fmShowHidden => _fmShowHidden;

  /// Küçük resimler (görsel/video) gösterilsin mi? Çok yavaş cihazda kapatılır.
  bool get fmThumbnails => _fmThumbnails;

  /// Silme çöp kutusuna mı gitsin (kapalıysa doğrudan kalıcı silme)?
  bool get fmUseTrash => _fmUseTrash;

  /// Silmeden önce onay sorulsun mu?
  bool get fmConfirmDelete => _fmConfirmDelete;

  /// Çöp kutusu kaç günde bir kendini temizlesin (0 = kapalı).
  int get fmTrashAutoDays => _fmTrashAutoDays;

  Future<void> setFmThumbnails(bool value) async {
    _fmThumbnails = value;
    await _prefs.setBool(_kFmThumbs, value);
    notifyListeners();
  }

  Future<void> setFmUseTrash(bool value) async {
    _fmUseTrash = value;
    await _prefs.setBool(_kFmUseTrash, value);
    notifyListeners();
  }

  Future<void> setFmConfirmDelete(bool value) async {
    _fmConfirmDelete = value;
    await _prefs.setBool(_kFmConfirmDelete, value);
    notifyListeners();
  }

  Future<void> setFmTrashAutoDays(int days) async {
    _fmTrashAutoDays = days;
    await _prefs.setInt(_kFmTrashAutoDays, days);
    notifyListeners();
  }

  /// Kopyala/kes panosu — bilinçli olarak KALICI DEĞİL: uygulama yeniden
  /// açıldığında artık var olmayabilecek yolları yapıştırmayı önler.
  List<String> get clipboard => List.unmodifiable(_clipboard);
  bool get clipboardCut => _clipboardCut;
  bool get hasClipboard => _clipboard.isNotEmpty;

  bool isBookmarked(String path) => _bookmarks.contains(path);

  /// Hedef klasörü "son kullanılanlar"ın başına taşır (yinelenmez, en çok 8).
  Future<void> rememberDestination(String path) async {
    _recentDests
      ..remove(path)
      ..insert(0, path);
    if (_recentDests.length > 8) {
      _recentDests = _recentDests.sublist(0, 8);
    }
    await _prefs.setStringList(_kRecentDests, _recentDests);
    notifyListeners();
  }

  /// PIN'i kurar/değiştirir; boş verilirse kilit tamamen kalkar (kilitli
  /// klasörler de listeden düşer — PIN'siz kilit kullanıcıyı kendi dosyasından
  /// kalıcı olarak edemez).
  Future<void> setFmLockPin(String pin) async {
    _fmLockPinHash = pin.trim().isEmpty ? '' : FolderLock.hashPin(pin);
    if (_fmLockPinHash.isEmpty) {
      _lockedFolders = [];
      await _prefs.setStringList(_kLockedFolders, _lockedFolders);
    }
    await _prefs.setString(_kLockPin, _fmLockPinHash);
    notifyListeners();
  }

  Future<void> toggleLockedFolder(String path) async {
    if (!_lockedFolders.remove(path)) _lockedFolders.add(path);
    await _prefs.setStringList(_kLockedFolders, _lockedFolders);
    notifyListeners();
  }

  bool isFolderLocked(String path) =>
      FolderLock.isLocked(path, _lockedFolders);

  Future<void> toggleBookmark(String path) async {
    if (!_bookmarks.remove(path)) _bookmarks.insert(0, path);
    await _prefs.setStringList(_kBookmarks, _bookmarks);
    notifyListeners();
  }

  Future<void> setFmLayout(FmLayout value) async {
    _fmLayout = value;
    await _prefs.setString(_kFmLayout, value.name);
    notifyListeners();
  }

  Future<void> setFmPhotoLayout(FmLayout value) async {
    _fmPhotoLayout = value;
    await _prefs.setString(_kFmPhotoLayout, value.name);
    notifyListeners();
  }

  Future<void> setFmPhotoGroup(PhotoGroup value) async {
    _fmPhotoGroup = value;
    await _prefs.setString(_kFmPhotoGroup, value.name);
    notifyListeners();
  }

  Future<void> setFmMediaOpenWith(MediaOpenWith value) async {
    _fmMediaOpenWith = value;
    await _prefs.setString(_kFmMediaOpenWith, value.name);
    notifyListeners();
  }

  Future<void> setFmSort(FmSort sort, {bool? descending}) async {
    _fmSort = sort;
    if (descending != null) _fmSortDesc = descending;
    await _prefs.setString(_kFmSort, sort.name);
    await _prefs.setBool(_kFmSortDesc, _fmSortDesc);
    notifyListeners();
  }

  Future<void> setFmShowHidden(bool value) async {
    _fmShowHidden = value;
    await _prefs.setBool(_kFmHidden, value);
    notifyListeners();
  }

  void setClipboard(List<String> paths, {required bool cut}) {
    _clipboard = List.of(paths);
    _clipboardCut = cut;
    notifyListeners();
  }

  void clearClipboard() {
    if (_clipboard.isEmpty) return;
    _clipboard = [];
    _clipboardCut = false;
    notifyListeners();
  }

  bool get firebaseAvailable => firebase.available;
  bool get signedIn => _uid != null;
  String? get userEmail => _userEmail;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiKey = _prefs.getString(_kApiKey) ?? '';
    _model = _prefs.getString(_kModel) ?? 'gemini-2.0-flash';
    _themeMode = _themeModeFromString(_prefs.getString(_kThemeMode));
    _language = AppLanguageInfo.byCode(_prefs.getString(_kLanguage));
    _uiFont = _prefs.getString(_kUiFont) ?? AppTheme.uiFontDefault;
    _uiTextScale = (_prefs.getDouble(_kUiTextScale) ?? 1.0).clamp(0.85, 1.4);
    _highRefreshRate = _prefs.getBool(_kHighRefresh) ?? true;
    _autoRescan = _prefs.getBool(_kAutoRescan) ?? true;
    _recents = (_prefs.getStringList(_kRecents) ?? [])
        .map(RecentFile.tryDecode)
        .whereType<RecentFile>()
        .toList();
    _memory = _prefs.getStringList(_kMemory) ?? [];
    _bookmarks = _prefs.getStringList(_kBookmarks) ?? [];
    _recentDests = _prefs.getStringList(_kRecentDests) ?? [];
    _fmLockPinHash = _prefs.getString(_kLockPin) ?? '';
    _lockedFolders = _prefs.getStringList(_kLockedFolders) ?? [];
    _fmLayout = FmLayoutInfo.byName(_prefs.getString(_kFmLayout),
        // Eski sürümün iki durumlu tercihi korunur: ızgara açıksa 3 sütun.
        fallback: (_prefs.getBool('fm_grid') ?? false)
            ? FmLayout.grid3
            : FmLayout.list);
    _fmPhotoLayout = FmLayoutInfo.byName(_prefs.getString(_kFmPhotoLayout),
        fallback: FmLayout.grid3);
    _fmPhotoGroup = PhotoGroupLabel.byName(_prefs.getString(_kFmPhotoGroup));
    _fmMediaOpenWith =
        MediaOpenWithLabel.byName(_prefs.getString(_kFmMediaOpenWith));
    _fmSort = FmSort.values.firstWhere(
      (s) => s.name == _prefs.getString(_kFmSort),
      orElse: () => FmSort.name,
    );
    _fmSortDesc = _prefs.getBool(_kFmSortDesc) ?? false;
    _fmShowHidden = _prefs.getBool(_kFmHidden) ?? false;
    _fmThumbnails = _prefs.getBool(_kFmThumbs) ?? true;
    _fmUseTrash = _prefs.getBool(_kFmUseTrash) ?? true;
    _fmConfirmDelete = _prefs.getBool(_kFmConfirmDelete) ?? true;
    _fmTrashAutoDays = _prefs.getInt(_kFmTrashAutoDays) ?? 0;
    _remotes = (_prefs.getStringList(_kRemotes) ?? [])
        .map(RemoteConnection.tryDecode)
        .whereType<RemoteConnection>()
        .toList();
    _ttsPrefs = TtsPrefs.decode(_prefs.getString(_kTtsPrefs));
    _ttsAiRead = _prefs.getBool(_kTtsAiRead) ?? false;
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

  String _encodeMap(Map m) => RecentFile(
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

  /// Sesli okuma tercihleri (ses, hız, perde).
  TtsPrefs get ttsPrefs => _ttsPrefs;

  /// Sesli okumada metin önce AI ile toparlansın mı? (Gemini anahtarı şart.)
  bool get ttsAiRead => _ttsAiRead;

  Future<void> setTtsPrefs(TtsPrefs value) async {
    _ttsPrefs = value;
    await _prefs.setString(_kTtsPrefs, value.encode());
    notifyListeners();
  }

  Future<void> setTtsAiRead(bool value) async {
    _ttsAiRead = value;
    await _prefs.setBool(_kTtsAiRead, value);
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

  Future<void> _persistRemotes() => _prefs.setStringList(
      _kRemotes, _remotes.map((r) => r.encode()).toList());

  /// Bağlantıyı ekler ya da (aynı `id` varsa) günceller.
  Future<void> saveRemote(RemoteConnection connection) async {
    final index = _remotes.indexWhere((r) => r.id == connection.id);
    if (index < 0) {
      _remotes.add(connection);
    } else {
      _remotes[index] = connection;
    }
    await _persistRemotes();
    notifyListeners();
  }

  Future<void> removeRemote(String id) async {
    _remotes.removeWhere((r) => r.id == id);
    await _persistRemotes();
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs.setString(_kLanguage, language.code);
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
