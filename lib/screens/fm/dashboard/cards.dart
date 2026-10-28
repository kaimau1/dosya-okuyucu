part of '../dashboard_screen.dart';

class _VolumeCard extends StatelessWidget {
  final StorageVolume volume;

  /// Kırılım çubuğunun verisi. Tarama zaten yapıldı — ek maliyet yok.
  final StorageIndex index;
  final VoidCallback onTap;

  /// Uzun basış menüsü (analiz, güvenle çıkar).
  final VoidCallback? onLongPress;

  const _VolumeCard({
    required this.volume,
    required this.index,
    required this.onTap,
    this.onLongPress,
  });

  /// Kategori paylı yığın çubuğu: "98,4/128 GB" tek başına NEYİN yer
  /// kapladığını söylemiyordu. Kalan (ölçülemeyen sistem/uygulama verisi)
  /// "diğer" payına yazılır — çubuk her zaman doluluğu kadar dolar.
  ///
  /// **Yalnız ANA bellekte kırılım var (2026-09-02).** [index] telefonun
  /// taramasıdır; takılan bir USB'nin kartında o sayıları göstermek, USB'de
  /// olmayan fotoğrafları USB'de varmış gibi çizerdi. Harici bellekte tek
  /// pay: "kullanılan" — doluluk doğru, uydurma kırılım yok.
  List<({Color color, String label, int bytes})> _breakdown(
          BuildContext context) =>
      _volumeBreakdown(context, volume, index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dilimli doluluk halkası: her kategorinin rengiyle.
                    // Tarama yapılmamışsa / istatistik yoksa boş halka.
                    CustomPaint(
                      size: const Size(52, 52),
                      painter: _RingPainter(
                        slices: volume.hasStats
                            ? _breakdown(context)
                                .where((p) => p.bytes > 0)
                                .map((p) => (
                                      color: p.color,
                                      bytes: p.bytes,
                                    ))
                                .toList()
                            : const [],
                        total: volume.hasStats
                            ? volume.capacityBytes
                            : 1,
                        trackColor: scheme.surfaceContainerHighest,
                        strokeWidth: 6,
                      ),
                    ),
                    Icon(
                      volumeIcon(volume),
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(volume.displayLabel(context.t),
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    // **İKİ SATIR** (kullanıcı 2026-08-25: *"yazıları
                    // düzenle"*). Tek satırda "307 GB / 512 GB · 205 GB boş"
                    // yazıyordu ve yanındaki analiz kutusu daralttığı için
                    // cihazda "307 GB / 512 GB · 20…" diye KIRPILIYORDU —
                    // yani kullanıcının asıl aradığı sayı (kaç GB boş) tam da
                    // görünmeyen yarıya düşüyordu.
                    //
                    // Birim ilk sayıdan atıldı: "307 / 512 GB" aynı şeyi
                    // söylüyor, iki kez "GB" yazmak yer harcıyordu.
                    volume.hasStats
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoText(
                                // Kapasite ONDALIK (telefonun üstünde yazan
                                // sayı).
                                '${FsPaths.humanCapacity(volume.usedBytes)}'
                                ' / '
                                '${FsPaths.humanCapacity(volume.capacityBytes)}',
                                size: 12,
                              ),
                              MonoText(
                                context.t('fm.free_bytes', {
                                  'v':
                                      FsPaths.humanCapacity(volume.freeBytes),
                                }),
                                size: 12,
                              ),
                            ],
                          )
                        : MonoText(volume.path, size: 12),
                  ],
                ),
              ),
              Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
            ],
          ),
              if (volume.hasStats) ...[
                const SizedBox(height: Gap.sm + 2),
                _breakdownBar(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Yığın çubuğu + renk açıklaması. Çubuğun boş kalan kısmı kağıdın kendisi
  /// (dolgu yok) — "boş yer" görsel olarak da boşluk.
  Widget _breakdownBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = _breakdown(context).where((p) => p.bytes > 0).toList();
    final free = volume.freeBytes;
    final total = volume.capacityBytes <= 0 ? 1 : volume.capacityBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                for (final part in parts)
                  Expanded(
                    flex: part.bytes,
                    child: ColoredBox(color: part.color),
                  ),
                if (free > 0)
                  Expanded(
                    flex: free,
                    child: ColoredBox(color: scheme.outlineVariant),
                  ),
                // Sıfır genişlikli satır olmasın (tüm paylar 0 ise).
                if (parts.isEmpty && free <= 0)
                  Expanded(
                    flex: total,
                    child: ColoredBox(color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
        ),
        // **Renk açıklaması KALKTI** (kullanıcı isteği 2026-08-25: *"işaretlediğim
        // yerdeki 'Diğer, Videolar, Görüntüler' gibi alt yazıları kaldır"*).
        //
        // Üç turda küçüldü ama sorun boyutu değil VARLIĞIYDI: kartın altındaki
        // yazı sırası, üstteki "Ana bellek / 307 GB / 512 GB" bilgisinden daha
        // çok yer kaplıyor ve göze ondan önce çarpıyordu — oysa hangi rengin
        // ne olduğu panoda sorulan bir soru değil. Çubuğun kendisi oranı zaten
        // gösteriyor; hangi kategorinin ne kadar tuttuğu **Bellek Analizi**
        // ekranının işi ve o düğme hemen yanında duruyor.
      ],
    );
  }

}

/// Dilimli doluluk halkası boyayıcısı.
///
/// `slices` listesindeki her dilim kendi rengiyle saat yönünde çizilir;
/// geri kalan açı `trackColor` (boş alan) rengiyle tamamlanır.
/// `total` ≤ 0 ise tüm çember `trackColor` ile çizilir.
class _RingPainter extends CustomPainter {
  final List<({Color color, int bytes})> slices;
  final int total;
  final Color trackColor;
  final double strokeWidth;

  const _RingPainter({
    required this.slices,
    required this.total,
    required this.trackColor,
    this.strokeWidth = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock
    const fullSweep = 2 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Arka plan halkası (her zaman tam çember).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      trackPaint,
    );

    if (total <= 0 || slices.isEmpty) return;

    // Dilimler saat yönünde üst üste çizilir.
    var currentAngle = startAngle;
    for (final s in slices) {
      final sweep = (s.bytes / total).clamp(0.0, 1.0) * fullSweep;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        false,
        paint,
      );
      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      !listEquals(old.slices, slices) ||
      old.total != total ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// **Panonun yüzen çubuğu**: çöp kutusu · QR ile al | Belge Tara.
///
/// QR ile al (2026-10-28, kullanıcı: *"QR'la al seçeneği yüzen buton olmalı
/// — biri paylaşırken uygulama içinden alma"*): karşı taraf "QR ile
/// paylaş"ı açtığında tek dokunuşla tarayıcı açılır, gelecek dosyalar
/// gösterilip onay istenir (bkz. `QrReceiveFlow`).
///
/// Yeni klasör düğmesi 2026-10-23'te kaldırıldı (kullanıcı isteği) — klasör
/// gezginin kendi menüsünden oluşturulur.
///
/// Çöp kutusu doluyken simgesi dolu ve turuncu, üstünde sayı rozeti var
/// (2026-08-06 isteği: kutuyu açmadan durum görünsün) — ama artık koca
/// turuncu bir kare değil. [expanded] false iken (liste aşağı kaydırılıyor)
/// kapsül yalnız tarama simgesine katlanır; içeriğin üstünü daha az kapatır.
class _QuickDock extends StatelessWidget {
  final bool expanded;
  final int trashCount;
  final VoidCallback onTrash;
  final VoidCallback onScan;
  final VoidCallback onQrReceive;

  const _QuickDock({
    required this.expanded,
    required this.trashCount,
    required this.onTrash,
    required this.onScan,
    required this.onQrReceive,
  });

  static const _trashFull = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = trashCount > 0;
    final trashIcon = Icon(
      full ? AppIcons.delete : AppIcons.delete,
      color: full ? _trashFull : scheme.onSurfaceVariant,
    );
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: AppColors.shade.withValues(alpha: 0.35),
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Curves.easeOutCubic,
              child: expanded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: full
                              ? '${context.t('fm.trash')} · '
                                  '${context.t('fm.trash_count', {'n': trashCount})}'
                              : context.t('fm.trash'),
                          onPressed: onTrash,
                          icon: full
                              ? Badge(
                                  label: Text(trashCount > 99
                                      ? '99+'
                                      : '$trashCount'),
                                  backgroundColor: _trashFull,
                                  child: trashIcon,
                                )
                              : trashIcon,
                        ),
                        IconButton(
                          key: const ValueKey('dock-qr-receive'),
                          tooltip: context.t('qrr.fab'),
                          onPressed: onQrReceive,
                          icon: Icon(AppIcons.qrScan,
                              color: scheme.onSurfaceVariant),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: scheme.outlineVariant,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            Tooltip(
              message: context.t('fm.scan_document'),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.symmetric(horizontal: expanded ? 18 : 12),
                  shape: const StadiumBorder(),
                ),
                onPressed: onScan,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.ocr, size: 22),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.medium),
                      curve: Curves.easeOutCubic,
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: Text(context.t('fm.scan_document'),
                                  maxLines: 1),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Pano taramasının ilerlemesi** — "Depolama taranıyor · ~8 sn kaldı".
///
/// Tarama tek bir yalıtılmış yürüyüş ve ara ilerleme vermiyor; ama bir önceki
/// taramanın süresi biliniyor (aynı telefon, aynı depolama — süre turdan tura
/// pek değişmez). Çubuk bu süreye göre dolar (%95'te durur: tahmin aşıldıysa
/// "bitti" demez), metin kalan ya da geçen süreyi söyler. Kullanıcı 2026-10-18:
/// *"ne zaman bitecek, ne kadar sürecek … soru işareti kalmamalı"* — eskiden
/// yalnız sonsuz dönen bir çubuk ve "Depolama taranıyor…" vardı.
class _ScanProgress extends StatefulWidget {
  final int startedAtMs;
  final int? expectedMs;
  const _ScanProgress({required this.startedAtMs, required this.expectedMs});

  @override
  State<_ScanProgress> createState() => _ScanProgressState();
}

class _ScanProgressState extends State<_ScanProgress> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - widget.startedAtMs;
    final expected = widget.expectedMs;
    // Çok kısa geçmiş taramada (önbellekten) tahmin anlamsız: süre yazılır.
    final usable = expected != null && expected >= 2000;
    final value =
        usable ? (elapsed / expected).clamp(0.0, 0.95).toDouble() : null;
    final left = usable ? expected - elapsed : 0;
    final when = usable && left > 1000
        ? context.t('job.eta',
            {'time': roughDuration(Duration(milliseconds: left))})
        : humanDuration(Duration(milliseconds: elapsed));
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: value, minHeight: 3),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '${context.t('fm.scanning_storage')} · $when',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
