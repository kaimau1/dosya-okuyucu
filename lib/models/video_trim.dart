/// **Video kesme aralığı** (Ferrari H8, 2026-11-14) — saf model, birim testli.
///
/// Kes ekranındaki iki tutamaç bu aralığı yazar; yerel taraf
/// (`ci/MediaTranscode.kt` `trim`) yalnız bu aralığı yazar, özgün korunur.
class TrimRange {
  final int startMs;
  final int endMs;

  const TrimRange(this.startMs, this.endMs);

  /// En kısa kesit (tutamaçlar birbirinin üstüne binmesin; 0 sn'lik dosya
  /// anlamsız).
  static const minLengthMs = 1000;

  int get lengthMs => endMs - startMs;

  /// Aralık videonun tamamı mı (kesilecek bir şey yok)?
  bool isWhole(int durationMs) => startMs <= 0 && endMs >= durationMs;

  /// Başlangıç tutamacı [ms]'ye çekildi: bitişe en az [minLengthMs] kalır.
  TrimRange withStart(int ms, int durationMs) {
    final max = endMs - _minFor(durationMs);
    return TrimRange(ms.clamp(0, max < 0 ? 0 : max), endMs);
  }

  /// Bitiş tutamacı [ms]'ye çekildi: başlangıçtan en az [minLengthMs] sonra.
  TrimRange withEnd(int ms, int durationMs) {
    final min = startMs + _minFor(durationMs);
    final upper = durationMs < min ? min : durationMs;
    return TrimRange(startMs, ms.clamp(min, upper));
  }

  /// Kısa videoda (≤ 1 sn) asgari uzunluk videonun kendisi.
  static int _minFor(int durationMs) =>
      durationMs < minLengthMs ? durationMs : minLengthMs;

  @override
  bool operator ==(Object other) =>
      other is TrimRange && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);

  @override
  String toString() => 'TrimRange($startMs–$endMs)';
}

/// Süreyi `dd:ss` (bir saatten uzunsa `s:dd:ss`) yazar — tutamaç etiketi.
String formatClock(int ms) {
  final total = (ms < 0 ? 0 : ms) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Kesit uzunluğu saniye (yukarı yuvarlanmaz: 52,9 sn → 52).
int trimSeconds(TrimRange r) => r.lengthMs ~/ 1000;
