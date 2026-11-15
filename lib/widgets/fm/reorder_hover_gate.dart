import '../../core/motion.dart';

// "not" uygulamasından (P56) uyarlandı — ana ekran kutularını sürükle-sırala
// (2026-11-15).

/// Sürükle-sırala önizlemesinin HEDEF KAPISI (P56, kullanıcı 2026-11-13:
/// "not sıralama iki sütunun arasında geldiğinde anlık bir sağa bir sola
/// geçtiği için aşırı zıplamalar oluyor").
///
/// KÖK NEDEN: her hücre `DragTarget.onMove` ile parmak üstünden geçtiği AN
/// sırayı değiştiriyordu (histerezis yok). İki sütunlu dengeli ızgarada yer
/// değişince parmağın altına komşu kart gelir; onun `onMove`u hemen geri
/// değiştirir → kart sağ/sol arasında her karede gidip gelir.
///
/// Kapı üç kural koyar:
/// 1. **Durma:** aynı hedef en az [dwell] boyunca üzerinde kalınmadan yer
///    değişmez (sınırdan geçerken anlık değmeler sayılmaz).
/// 2. **Soğuma:** bir yer değişiminden sonra [cooldown] boyunca yenisi yok —
///    kartlar yerine otururken altta kalan hücre yeniden hedeflenmez.
/// 3. **Kilit:** az önce yeri değişen (itilen) kart, parmak ondan ÇIKANA dek
///    ([leave]) hedef olamaz — geri alma ancak bilinçli bir çıkış-giriş ile.
///
/// Saf Dart; saat dışarıdan verilebilir (test).
class ReorderHoverGate {
  ReorderHoverGate({
    this.dwell = Motion.short,
    // Kartların yerine oturma süresi kadar (AnimatedSlide/ızgara geçişi).
    this.cooldown = Motion.medium,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration dwell;
  final Duration cooldown;
  final DateTime Function() _clock;

  String? _candidate;
  DateTime? _candidateSince;
  String? _blocked;
  DateTime? _lastCommit;

  /// Şu an üzerinde beklenen hedef (zamanlayıcı yeniden denesin diye).
  String? get candidate => _candidate;

  /// Parmak [targetId] kartının üzerinde. Yer değişimi ŞİMDİ yapılmalıysa
  /// `true` döner (ve kapı bunu kaydeder).
  bool offer(String targetId) {
    if (targetId == _blocked) {
      // Kilitli kartın üstündeyken başka hedefte "duruluyor" sayılmaz —
      // sınırda kilitli kart ile komşu arasında gidip gelmek durma değildir.
      _candidate = null;
      _candidateSince = null;
      return false;
    }
    final now = _clock();
    if (_candidate != targetId) {
      _candidate = targetId;
      _candidateSince = now;
      if (dwell > Duration.zero) return false;
    }
    if (now.difference(_candidateSince!) < dwell) return false;
    final last = _lastCommit;
    if (last != null && now.difference(last) < cooldown) return false;
    _lastCommit = now;
    _blocked = targetId;
    _candidate = null;
    _candidateSince = null;
    return true;
  }

  /// Parmak [targetId] kartından çıktı.
  void leave(String targetId) {
    if (_blocked == targetId) _blocked = null;
    if (_candidate == targetId) {
      _candidate = null;
      _candidateSince = null;
    }
  }

  /// Yeni sürükleme / sürükleme bitti.
  void reset() {
    _candidate = null;
    _candidateSince = null;
    _blocked = null;
    _lastCommit = null;
  }

  /// Bekleyen hedefin ne zaman olgunlaşacağı (zamanlayıcı için): durma ve
  /// soğumanın ikisi de dolana dek kalan süre; hedef yoksa `null`.
  Duration? remaining() {
    final since = _candidateSince;
    if (_candidate == null || since == null) return null;
    final now = _clock();
    var wait = dwell - now.difference(since);
    final last = _lastCommit;
    if (last != null) {
      final cool = cooldown - now.difference(last);
      if (cool > wait) wait = cool;
    }
    return wait.isNegative ? Duration.zero : wait;
  }
}
