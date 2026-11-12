import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

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

/// Göz atma tercihleri (düzen, sıralama, gizli dosyalar, küçük resim,
/// klasör boyutu, çöp, yer imleri, son hedefler, kilitli klasörler) — A4.2.
/// Değerler `AppState`te; değişim YALNIZ bunu uyandırır.
///
/// Kimse dinlemiyorsa (`watched` false — ör. dilimleri sağlamayan test
/// ağacı) `AppState` yine bildirir; okuyan yer [AppSliceWatch.watchBrowse]
/// kullanmalı.
class BrowseState extends ChangeNotifier {
  void changed() => notifyListeners();
  bool get watched => hasListeners;
}

/// AI ayarları (anahtarlar, modeller, kapsam, gönderim onayı) — A4.2.
/// Kurallar [BrowseState] ile aynı.
class AiState extends ChangeNotifier {
  void changed() => notifyListeners();
  bool get watched => hasListeners;
}

/// Dilim izleme kısayolları: ilgili dilimi (varsa) VE `AppState`i izler,
/// `AppState`i döndürür. Dilim sağlanmamışsa (eski test ağacı) yalnız
/// `AppState` izlenir — o durumda `AppState` dilim değişiminde de bildirir.
extension AppSliceWatch on BuildContext {
  AppState watchBrowse() {
    watch<BrowseState?>();
    return watch<AppState>();
  }

  AppState watchAi() {
    watch<AiState?>();
    return watch<AppState>();
  }

  /// `select` kullanan yerler için: yalnız dilime bağımlılık ekler.
  void dependOnBrowse() => watch<BrowseState?>();
  void dependOnAi() => watch<AiState?>();
}
