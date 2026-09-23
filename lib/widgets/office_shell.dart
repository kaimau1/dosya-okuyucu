import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../models/document.dart';
import 'file_type_icon.dart';

/// Tüm belge ekranlarının ortak Office kabuğu.
///
/// **2026-09-23 tasarım turu** (kullanıcı: *"PDF, Word, slayt, Excel, not,
/// görseller … çok basit görünüyor, şimdiki tasarım standartlarına
/// uymuyor"*). Eski kabuk 2018'in M365 mobil dilindeydi: dosya türü renginde
/// DOLU bir üst şerit, beyaz simgeler, başlığın sonunda " •". Bugünün belge
/// uygulamaları (Acrobat, Drive, yeni M365) üst çubuğu NÖTR yüzeyde tutar;
/// dosya kimliği küçük renkli bir rozetle ve başlığın altındaki bilgi
/// satırıyla verilir. Kazançlar:
/// * Göz belgeye gider, kalın renkli bir bant her ekranda dikkati çalmaz.
/// * Koyu temada göz alan dolu kırmızı/yeşil şerit kalkar.
/// * "Kaydedilmedi" artık bir nokta değil, okunur bir durum etiketi.
///
/// Alt sistem çubuğu (geri/ana menü) çakışmaları yine tek yerden çözülür;
/// ekranlar kendi Scaffold'unu kurmaz.
class OfficeShell extends StatelessWidget {
  final DocKind kind;
  final String title;
  final bool dirty;
  final List<Widget> actions;
  final PreferredSizeWidget? tabBar;
  final Widget body;
  final Widget? bottomBar;
  final Widget? fab;

  /// Başlığın altındaki bilgi satırına tür adından sonra eklenen kısa bilgi
  /// ("28 sayfa", "3 sayfa · Sayfa1"). Null ise yalnız tür adı yazar.
  final String? subtitle;

  const OfficeShell({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    this.dirty = false,
    this.actions = const [],
    this.tabBar,
    this.bottomBar,
    this.fab,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: OfficeColors.canvas(context),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: DocTitle(
          kind: kind,
          title: title,
          dirty: dirty,
          subtitle: subtitle,
        ),
        actions: [...actions, const SizedBox(width: 4)],
        bottom: tabBar,
      ),
      body: body,
      bottomNavigationBar: bottomBar == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(top: false, child: bottomBar!),
            ),
      floatingActionButton: fab,
    );
  }
}

/// Üst çubuğun başlığı: renkli tür rozeti + dosya adı + bilgi satırı.
///
/// Bilgi satırı "PDF · 28 sayfa" gibi okunur; kaydedilmemiş değişiklik varsa
/// sonuna marka renginde "● Kaydedilmedi" eklenir. Eski " •" işaretini
/// kullanıcı fark etmiyordu (başlık kısaltılınca "…" arkasında kayboluyordu).
class DocTitle extends StatelessWidget {
  final DocKind kind;
  final String title;
  final bool dirty;
  final String? subtitle;

  const DocTitle({
    super.key,
    required this.kind,
    required this.title,
    this.dirty = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = OfficeColors.tint(context, kind);
    final info = [
      context.t(kind.labelKey),
      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
    ].join(' · ');
    return Row(
      children: [
        FileTypeIcon(kind: kind, size: 36, framed: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (dirty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: brand, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.t('shell.unsaved'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: brand,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Belgenin üstünde yüzen **hap rozeti** — sayfa numarası ("4 / 28"),
/// yakınlaştırma yüzdesi, slayt konumu.
///
/// Eskiden üç ekranda üç ayrı siyah kutu vardı (`Colors.black54`, kağıdın
/// mürekkep tonu, farklı yarıçaplar). Tek bileşen: ters yüzey rengi (açık
/// temada koyu, koyu temada açık — her iki temada da belgeden ayrışır),
/// tam yuvarlak uçlar, yumuşak gölge. [onTap] varsa dokunulabilir olduğunu
/// sağdaki küçük simge söyler.
class DocPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Dokunma hedefinin anahtarı (testler rozete bu anahtarla dokunur).
  final Key? tapKey;

  const DocPill({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
    this.tapKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(14, 7, icon == null ? 14 : 10, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: fg.withValues(alpha: 0.8)),
          ],
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: scheme.inverseSurface.withValues(alpha: 0.9),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(key: tapKey, onTap: onTap, child: content),
      ),
    );
  }
}

/// Belge ekranlarının **AI düğmesi** — dört ekranda aynı görünüm.
///
/// Eski düğme temanın düz FAB'ıydı ve simgesi bir robot başıydı
/// (`smart_toy`); bugünün uygulamalarında "AI" dili parıltı simgesi
/// (`auto_awesome`) ve hafif bir renk geçişidir. Geçiş belgenin marka
/// renginden temanın vurgusuna akar: PDF'te kırmızıdan, Excel'de yeşilden
/// başlar — düğme hangi belgede olduğunu da söyler.
class DocAiButton extends StatelessWidget {
  final DocKind kind;
  final VoidCallback? onPressed;
  final String tooltip;

  const DocAiButton({
    super.key,
    required this.kind,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final brand = OfficeColors.tint(context, kind);
    final accent = Theme.of(context).colorScheme.primary;
    final end = brand == accent
        ? Color.lerp(accent, const Color(0xFF8E44D8), 0.6)!
        : accent;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brand, end],
            ),
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onPressed,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinch sırasında görünen zoom yüzdesi rozeti. Widget ağaçta hep durur
/// (örtük animasyon tuzağı: yapı değişirse geçiş oynamaz), sadece opaklığı değişir.
class ZoomBadge extends StatelessWidget {
  final double zoom;
  final bool visible;

  /// PDF'te rozet KALICI ve sayfa numarası da taşır ("4 / 28 · %120"):
  /// pinch dışında sayfa numarasını görmenin tek yolu ayrı bir gezinme
  /// satırıydı (2026-08-04 tasarım turu, 2. not).
  final String? page;

  const ZoomBadge({
    super.key,
    required this.zoom,
    required this.visible,
    this.page,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: DocPill(
          text: page == null
              ? '%${(zoom * 100).round()}'
              : '$page · %${(zoom * 100).round()}',
        ),
      ),
    );
  }
}

/// Zoom rozetini kısa süre gösterip söndüren küçük yardımcı durum.
/// Kullanım: pinch güncellemesinde [bump], build'de [visible] + [zoom].
class ZoomBadgeController {
  final void Function(void Function()) _setState;
  Timer? _timer;
  bool visible = false;
  double zoom = 1;

  ZoomBadgeController(this._setState);

  void bump(double value) {
    _timer?.cancel();
    _setState(() {
      zoom = value;
      visible = true;
    });
    _timer = Timer(const Duration(milliseconds: 900), () {
      _setState(() => visible = false);
    });
  }

  void dispose() => _timer?.cancel();
}
