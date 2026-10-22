import 'package:shared_preferences/shared_preferences.dart';

import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';

/// Liste ekranlarının **hafızası** (Faz 13, K17 (c), 2026-10-22).
///
/// * **Sıralama + yerleşim ekran başına KALICI** (`list.<ekran>.sort|desc|
///   layout`): "İndirilenler tarihe, Son açılanlar ada göre" bir kez seçilir.
/// * **Tür/tarih süzgeci yalnız OTURUM boyunca** (bellekte): ekrandan çıkıp
///   dönünce PDF süzgeci durur, uygulama yeniden açılınca temiz başlar — "liste
///   neden boş?" şaşkınlığı olmasın (KÖK NEDEN G3: süzgeç ekrandan çıkınca
///   sıfırlanıyordu, sıralama ise tek global ayardı).
abstract final class ListMemory {
  static final Map<String, FmFilter> _session = {};

  /// Ekranın bu oturumdaki son süzgeci (yoksa [FmFilter.none]).
  static FmFilter filterOf(String screen) => _session[screen] ?? FmFilter.none;

  static void rememberFilter(String screen, FmFilter filter) {
    if (filter.isActive) {
      _session[screen] = filter;
    } else {
      _session.remove(screen);
    }
  }

  static String _k(String screen, String field) => 'list.$screen.$field';

  /// Kayıtlı sıralama/yerleşim; kayıt yoksa alanlar null.
  static Future<({FmSort? sort, bool? descending, FmLayout? layout})> load(
      String screen) async {
    final prefs = await SharedPreferences.getInstance();
    T? byName<T extends Enum>(List<T> values, String? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null; // bilinmeyen/eski değer sessizce yok sayılır
    }

    return (
      sort: byName(FmSort.values, prefs.getString(_k(screen, 'sort'))),
      descending: prefs.getBool(_k(screen, 'desc')),
      layout: byName(FmLayout.values, prefs.getString(_k(screen, 'layout'))),
    );
  }

  static Future<void> saveSort(String screen, FmSort sort, bool descending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(screen, 'sort'), sort.name);
    await prefs.setBool(_k(screen, 'desc'), descending);
  }

  static Future<void> saveLayout(String screen, FmLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(screen, 'layout'), layout.name);
  }

  /// Testler için.
  static void resetForTest() => _session.clear();
}
