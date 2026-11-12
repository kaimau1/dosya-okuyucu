import 'package:flutter/foundation.dart';

/// Dosya panosu (Kopyala / Kes → Yapıştır) — A4.2.
///
/// Eskiden `AppState`teydi: her kopyala/kes, `AppState`i izleyen 60+ yeri
/// (açık gezgin listesi dahil) yeniden kurduruyordu. Pano bellekte durur,
/// diske yazılmaz; yalnız "Yapıştır" düğmesini gösteren yerler bunu izler.
class ClipboardState extends ChangeNotifier {
  List<String> _paths = const [];
  bool _cut = false;

  List<String> get paths => List.unmodifiable(_paths);
  bool get cut => _cut;
  bool get hasItems => _paths.isNotEmpty;
  int get length => _paths.length;

  void set(List<String> paths, {required bool cut}) {
    _paths = List.of(paths);
    _cut = cut;
    notifyListeners();
  }

  void clear() {
    if (_paths.isEmpty) return;
    _paths = const [];
    _cut = false;
    notifyListeners();
  }
}

/// Kayıtlı uzak bağlantılar listesinin değişim bildiricisi (A4.2). Liste
/// `AppState.remotes`te kalır (kalıcı kayıt orada); ekleme/silme YALNIZ bunu
/// uyandırır — bağlantılar ekranı bunu izler.
class RemotesState extends ChangeNotifier {
  void changed() => notifyListeners();
}

/// AI kalıcı hafıza notlarının değişim bildiricisi (A4.2). Notlar
/// `AppState.memory`de kalır; sohbette "Hafızaya kaydet" uygulamayı değil
/// yalnız hafıza listesini gösteren ayar bölümünü uyandırır.
class AiMemoryState extends ChangeNotifier {
  void changed() => notifyListeners();
}
