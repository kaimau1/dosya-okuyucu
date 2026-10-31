/// **Asistandan sesli okuma / durdurma** (2026-10-31; kullanıcının kişisel
/// sesli asistanı, asistan deposu PLAN K7).
///
/// Kişisel derlemedeki köprü (`ci/kisisel/AsistanKopru.kt`) uygulamayı
/// `oku:/yol`, `ozet:/yol` ya da `durdur:` bağlantısıyla açar
/// (`app_links.dart`). Okuma uygulamanın KENDİ sesli okumasıdır
/// (`TtsService`, görüntüleyicinin "Sesli oku"su); burada yalnız başlatılır,
/// ses koduna dokunulmaz.
///
/// Genel APK'da da bulunur ama etkisizdir: bu bağlantıları veren köprü yalnız
/// kişisel derlemede var.
///
/// Açık görüntüleyiciler kendilerini [kaydet] ile bildirir (üstteki sonda).
/// İstenen dosya açık değilse önce açılır; görüntüleyici kurulunca
/// [bekleyenOkuAl] ile isteği alıp okumaya başlar.
class AsistanKomutlari {
  AsistanKomutlari._();

  static final List<AcikOkuyucu> _acik = [];
  static String? _bekleyenOku;

  /// Görüntüleyici açıldı (initState). Dönen nesne [birak]a verilir.
  static AcikOkuyucu kaydet(
    String yol, {
    required void Function() oku,
    required void Function() durdur,
  }) {
    final o = AcikOkuyucu._(yol, oku, durdur);
    _acik.add(o);
    return o;
  }

  /// Görüntüleyici kapandı (dispose).
  static void birak(AcikOkuyucu o) => _acik.remove(o);

  /// En üstteki açık görüntüleyici, yoksa null.
  static AcikOkuyucu? get ustteki => _acik.isEmpty ? null : _acik.last;

  /// `oku:` isteği. Dosya zaten üstte açıksa hemen okunur ve true döner;
  /// değilse istek bekletilir, çağıran dosyayı açar (false).
  static bool oku(String yol) {
    final u = ustteki;
    if (u != null && (yol.isEmpty || u.yol == yol)) {
      _bekleyenOku = null;
      u._oku();
      return true;
    }
    _bekleyenOku = yol;
    return false;
  }

  /// [yol] için bekleyen okuma isteği varsa tüketir (görüntüleyici kurulunca).
  static bool bekleyenOkuAl(String yol) {
    if (_bekleyenOku != yol) return false;
    _bekleyenOku = null;
    return true;
  }

  /// `durdur:` isteği: üstteki görüntüleyicinin okuması durur. Bekleyen okuma
  /// isteği de düşer (dosya açılırken "dur" denmiş olabilir).
  static bool durdur() {
    _bekleyenOku = null;
    final u = ustteki;
    if (u == null) return false;
    u._durdur();
    return true;
  }
}

/// [AsistanKomutlari.kaydet]in döndürdüğü kayıt.
class AcikOkuyucu {
  AcikOkuyucu._(this.yol, this._oku, this._durdur);

  final String yol;
  final void Function() _oku;
  final void Function() _durdur;
}
