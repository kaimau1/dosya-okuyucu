import 'package:flutter/material.dart';

/// İlerlemeyi TalkBack'e **%10 adımlarla** duyuran sarmalayıcı (Faz 16 /
/// madde 4 — "iş ilerlemesi `liveRegion`").
///
/// Neden adım: ilerleme satırı saniyede bir değişiyor ("%42 · ~2 dk kaldı");
/// onu doğrudan canlı bölge yapmak ekran okuyucuyu her saniye konuşturur ve
/// kullanıcı başka hiçbir şey duyamaz. Bu düğüm yalnız etiketi ve %10'luk
/// basamağı taşır; basamak değişince bir kez duyurulur. Çocuğun kendi
/// anlamları (`container`) ayrı kalır — dokunarak keşifte ayrıntı okunur.
class LiveProgress extends StatelessWidget {
  const LiveProgress({
    super.key,
    required this.label,
    required this.progress,
    required this.child,
  });

  /// İşin adı ("3 dosya kopyalanıyor").
  final String label;

  /// 0..1; belirsizse null (o zaman yalnız etiket duyurulur, bir kez).
  final double? progress;
  final Widget child;

  /// "%40" — aşağı yuvarlanmış %10 basamağı; belirsizse null.
  static String? step(double? progress) {
    if (progress == null || progress.isNaN) return null;
    final p = (progress.clamp(0.0, 1.0) * 100).floor();
    return '%${p ~/ 10 * 10}';
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        liveRegion: true,
        label: label,
        value: step(progress),
        child: child,
      );
}
