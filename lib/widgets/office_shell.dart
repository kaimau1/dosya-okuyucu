import 'dart:async';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/edit/edit_session.dart';
import '../core/edit/editor_perf.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../models/document.dart';
import 'file_type_icon.dart';
import '../core/app_colors.dart';

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
/// **Okuma kipi** çubuk durumu (Faz 18 / G20, 2026-10-22).
///
/// Belge aşağı kaydırılınca üst/alt çubuklar çekilir, yukarı kaydırınca ya
/// da tek dokunuşla geri gelir (Acrobat/Drive dili). Kaydırma kaynağı ya
/// [OfficeShell]'in yakaladığı `ScrollUpdateNotification` (metin, slayt,
/// Excel) ya da görüntüleyicinin kendi jest geri çağrısıdır (PDF —
/// pdfrx kaydırma bildirimi yaymıyor: [scrolled] elle çağrılır).
class ReadingBars extends ValueNotifier<bool> {
  ReadingBars() : super(true);

  /// Yön değişmeden biriken kaydırma; eşik aşılınca karar verilir (titreyen
  /// parmakta çubuklar yanıp sönmesin).
  double _acc = 0;

  /// [delta] > 0: içerik aşağı kaydı (okumaya devam) → gizle.
  void scrolled(double delta, {bool atTop = false}) {
    if (atTop) {
      _acc = 0;
      value = true;
      return;
    }
    if (delta == 0) return;
    if ((delta > 0) != (_acc > 0)) _acc = 0;
    _acc += delta;
    if (_acc > 32) {
      value = false;
    } else if (_acc < -32) {
      value = true;
    }
  }

  void show() {
    _acc = 0;
    value = true;
  }
}

class OfficeShell extends StatefulWidget {
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

  /// Okuma kipi: verilirse çubuklar kaydırmayla gizlenir/gelir. Düzenleyici
  /// ekranlarında null — yazarken çubuk kaybolmamalı.
  final ReadingBars? readingBars;

  /// Düzenleme oturumu (Faz 20): verilirse başlığın durum satırı ondan gelir
  /// ("Kaydediliyor… / Kaydedildi 14:32 / Kaydedilmedi") ve [dirty] yok sayılır.
  final EditSession? session;

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
    this.readingBars,
    this.session,
  });

  @override
  State<OfficeShell> createState() => _OfficeShellState();
}

class _OfficeShellState extends State<OfficeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown;

  // Tek dokunuşu (çubukları geri getirmek için) jest arenasına girmeden
  // ölçeriz: belge kendi dokunuşlarını (köprü, seçim) aynen alır.
  Offset? _downAt;
  DateTime? _downTime;

  @override
  void initState() {
    super.initState();
    // Tembel (late) ilklendirme OLMAZ: hiç kaydırılmayan ekranda denetleyici
    // ilk kez dispose içinde kurulur ve ticker o anda ataya bakıp çöker.
    _shown = AnimationController(vsync: this, value: 1);
    widget.readingBars?.addListener(_onBars);
  }

  @override
  void didUpdateWidget(OfficeShell old) {
    super.didUpdateWidget(old);
    if (old.readingBars != widget.readingBars) {
      old.readingBars?.removeListener(_onBars);
      widget.readingBars?.addListener(_onBars);
    }
  }

  @override
  void dispose() {
    widget.readingBars?.removeListener(_onBars);
    _shown.dispose();
    super.dispose();
  }

  void _onBars() {
    final target = widget.readingBars!.value ? 1.0 : 0.0;
    final d = Motion.of(context, Motion.medium);
    if (d == Duration.zero) {
      _shown.value = target;
    } else {
      _shown.animateTo(target, duration: d, curve: Motion.standard);
    }
  }

  bool _onScroll(ScrollUpdateNotification n) {
    final bars = widget.readingBars;
    if (bars != null &&
        n.metrics.axis == Axis.vertical &&
        n.dragDetails != null) {
      bars.scrolled(n.scrollDelta ?? 0,
          atTop: n.metrics.pixels <= n.metrics.minScrollExtent);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appBar = AppBar(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: widget.session == null
          ? DocTitle(
              kind: widget.kind,
              title: widget.title,
              dirty: widget.dirty,
              subtitle: widget.subtitle,
            )
          : ListenableBuilder(
              listenable: widget.session!,
              builder: (context, _) => DocTitle(
                kind: widget.kind,
                title: widget.title,
                dirty: widget.session!.isDirty,
                subtitle: widget.subtitle,
                status: widget.session!.statusText(AppStrings.of(context)),
              ),
            ),
      actions: [...widget.actions, const SizedBox(width: 4)],
      bottom: widget.tabBar,
    );
    final bottom = widget.bottomBar == null
        ? null
        // Bildirim kartı dock'un üstüne kalksın (bkz. ToastAvoider).
        : ToastAvoider(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(top: false, child: widget.bottomBar!),
            ),
          );
    if (widget.readingBars == null) {
      return Scaffold(
        backgroundColor: OfficeColors.canvas(context),
        appBar: appBar,
        body: widget.session == null
            ? widget.body
            : EditorPerfOverlay(child: widget.body),
        bottomNavigationBar: bottom,
        floatingActionButton: widget.fab,
      );
    }
    final full = appBar.preferredSize.height;
    final body = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _downAt = e.position;
        _downTime = DateTime.now();
      },
      onPointerUp: (e) {
        final at = _downAt, time = _downTime;
        _downAt = null;
        if (at == null || time == null) return;
        if ((e.position - at).distance < 12 &&
            DateTime.now().difference(time) < kLongPressTimeout &&
            !widget.readingBars!.value) {
          widget.readingBars!.show();
        }
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: widget.body,
      ),
    );
    return AnimatedBuilder(
      animation: _shown,
      builder: (context, _) {
        final t = _shown.value;
        return Scaffold(
          backgroundColor: OfficeColors.canvas(context),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(full * t),
            child: ClipRect(
              // Üstten hizalı: gizliyken kalan şerit çubuğun durum çubuğu
              // dolgusudur (yüzey rengi) — simgeler yarım görünmez.
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: appBar,
              ),
            ),
          ),
          body: body,
          bottomNavigationBar: bottom == null
              ? null
              : ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: t,
                    child: bottom,
                  ),
                ),
          floatingActionButton: t < 0.5 ? null : widget.fab,
        );
      },
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

  /// Kaydetme durumu metni ([EditSession.statusText]); verilmezse kirliyken
  /// "Kaydedilmedi".
  final String? status;

  const DocTitle({
    super.key,
    required this.kind,
    required this.title,
    this.dirty = false,
    this.subtitle,
    this.status,
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
                  if (dirty || status != null) ...[
                    const SizedBox(width: 8),
                    if (dirty)
                      Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: brand, shape: BoxShape.circle),
                    ),
                    if (dirty) const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        status ?? context.t('shell.unsaved'),
                        key: const ValueKey('doc-save-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dirty ? brand : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
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
/// Eskiden üç ekranda üç ayrı siyah kutu vardı (`AppColors.mediaScrim`, kağıdın
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
      padding: EdgeInsetsDirectional.fromSTEB(14, 7, icon == null ? 14 : 10, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: context.type.compact.copyWith(
              color: fg,
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
            color: AppColors.shadow,
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
                child: Icon(AppIcons.ai, color: AppColors.onBrand, size: 24),
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
        duration: Motion.of(context, Motion.short),
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
