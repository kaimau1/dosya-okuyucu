import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/fs_entry.dart';

/// **Kullanıcının kendi kartları** (2026-11-13, kullanıcı: *"Önemli
/// dosyalarda yeni tür kartı açabilme ve içerisine ne girecek seçebilme ve
/// içerisine bir şeyler atabilme; görünüm şekli galeri gibi olabilir, klasör
/// gibi olabilir; kişi istediği simge/tip ayarı yapabilsin; aynı şey ana
/// ekrana da yeni kart olarak eklenebilsin"*).
///
/// Kararlar:
/// - Kartın içi **gerçek bir klasördür** ([path]) — Önemli Dosyalar'daki
///   kategorilerle aynı ilke: telefon bilgisayara takılınca da, uygulama
///   silinince de dosyalar yerinde. Kartın kendisi (ad, simge, renk, görünüm,
///   tür süzgeci, ana ekranda mı) yalnız ayar olarak saklanır; ayar kaybolsa
///   da dosya kaybolmaz.
/// - [kinds] boşsa her tür kabul edilir; doluysa "Ekle" yalnız o türleri
///   alır, diğerleri atlanır (kullanıcıya sayısı söylenir).
/// - Ana ekran kimliği `card:<id>` — `DashboardLayout` bu öneki tanır,
///   sırası/gizliliği diğer kutular gibi saklanır.
@immutable
class CustomCard {
  final String id;
  final String name;
  final String path;
  final String icon;
  final int color;
  final CardView view;
  final Set<FmCategory> kinds;
  final bool onHome;

  const CustomCard({
    required this.id,
    required this.name,
    required this.path,
    this.icon = 'star',
    this.color = 0xFFF2A600,
    this.view = CardView.gallery,
    this.kinds = const {},
    this.onHome = false,
  });

  String get tileId => '${CustomCards.tilePrefix}$id';

  /// [kinds] boşsa her şey kabul.
  bool accepts(FmCategory c) => kinds.isEmpty || kinds.contains(c);

  bool acceptsPath(String path) => accepts(
      FsEntry.categoryForExtension(p.extension(path).replaceFirst('.', '')));

  CustomCard copyWith({
    String? name,
    String? path,
    String? icon,
    int? color,
    CardView? view,
    Set<FmCategory>? kinds,
    bool? onHome,
  }) =>
      CustomCard(
        id: id,
        name: name ?? this.name,
        path: path ?? this.path,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        view: view ?? this.view,
        kinds: kinds ?? this.kinds,
        onHome: onHome ?? this.onHome,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'icon': icon,
        'color': color,
        'view': view.name,
        'kinds': [for (final k in kinds) k.name],
        'home': onHome,
      };

  static CustomCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'], path = raw['path'];
    if (id is! String || name is! String || path is! String) return null;
    final kinds = <FmCategory>{
      for (final k in (raw['kinds'] as List?) ?? const [])
        for (final c in FmCategory.values)
          if (c.name == k) c,
    };
    return CustomCard(
      id: id,
      name: name,
      path: path,
      icon: raw['icon'] is String ? raw['icon'] as String : 'star',
      color: raw['color'] is int ? raw['color'] as int : 0xFFF2A600,
      view: CardView.values.firstWhere((v) => v.name == raw['view'],
          orElse: () => CardView.gallery),
      kinds: kinds,
      onHome: raw['home'] == true,
    );
  }
}

enum CardView { gallery, folder }

/// Kart deposu (SharedPreferences, JSON listesi).
class CustomCards extends ChangeNotifier {
  CustomCards._();

  static final instance = CustomCards._();

  static const tilePrefix = 'card:';
  static const _key = 'custom_cards_v1';

  /// Ana bellekte (Önemli Dosyalar dışı) kart klasörlerinin kökü.
  /// DİKKAT: gerçek dizin adı — çevrilmez.
  static const homeFolderName = 'Kartlarım';

  List<CustomCard> _cards = const [];
  bool _loaded = false;

  List<CustomCard> get cards => List.unmodifiable(_cards);
  List<CustomCard> get homeCards => [
        for (final c in _cards)
          if (c.onHome) c,
      ];

  CustomCard? byId(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// [dir] klasörüne bağlı kart (Önemli Dosyalar alt klasörünü kart gibi
  /// göstermek için).
  CustomCard? byPath(String dir) {
    for (final c in _cards) {
      if (p.equals(c.path, dir)) return c;
    }
    return null;
  }

  /// [root] içindeki (ya da altındaki) kartlar.
  List<CustomCard> within(String root) => [
        for (final c in _cards)
          if (p.isWithin(root, c.path)) c,
      ];

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _cards = [
        for (final e in list) ?CustomCard.fromJson(e),
      ];
      notifyListeners();
    } catch (_) {
      // Bozuk ayar: kartsız başla (klasörler diskte yerinde).
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final c in _cards) c.toJson()]));
    } catch (_) {
      // Bilinçli: kayıt yazılamadı — bellekteki durum geçerli, sonraki kayıtta yeniden denenir.
    }
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> upsert(CustomCard card) {
    final i = _cards.indexWhere((c) => c.id == card.id);
    _cards = [..._cards];
    if (i < 0) {
      _cards.add(card);
    } else {
      _cards[i] = card;
    }
    return _save();
  }

  /// Yalnız kart kaydını kaldırır — klasör ve içi diskte kalır.
  Future<void> remove(String id) {
    _cards = [
      for (final c in _cards)
        if (c.id != id) c,
    ];
    return _save();
  }

  /// Klasör yeniden adlandırılınca / taşınınca yolu güncelle.
  Future<void> repath(String from, String to) {
    final i = _cards.indexWhere((c) => p.equals(c.path, from));
    if (i < 0) return Future.value();
    _cards = [..._cards]..[i] = _cards[i].copyWith(path: to);
    return _save();
  }

  @visibleForTesting
  void debugReset([List<CustomCard> cards = const []]) {
    _cards = cards;
    _loaded = true;
  }
}
