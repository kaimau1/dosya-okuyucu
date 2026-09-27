/// **Tek yerden geçen kısa bildirim (toast).**
///
/// ## Tarihçe
/// 1. (2026-08-30) *"Uyarı yazıları gitmiyor, elle kapatmak gerekiyor"* —
///    `ScaffoldMessenger` şeritleri kuyruğa alıyordu; yeni bildirim eskisinin
///    yerine geçer oldu.
/// 2. (2026-09-27) Kullanıcı: *"alt alanda çıkan uyarılar çok yukarıda, alt
///    kısma sığmalı ve bir geri sayım çubuğu ile otomatik kapanmalı"* +
///    *"alttaki uyarılar gitmiyor"*. İki ayrı kök neden:
///    - **Yukarıda:** yüzen SnackBar, Scaffold'un alt çubuğunun VE yüzen
///      düğmenin (AI düğmesi) üstüne yerleşir. Belge ekranında bu, sayfa
///      rozeti ve dock'un üstünde, ekranın ortasına yakın bir şerit demekti.
///    - **Gitmiyor:** SnackBar'ın zamanlayıcısını `ScaffoldMessenger` kurar
///      ve (a) cihazda bir erişilebilirlik hizmeti açıksa
///      (`accessibleNavigation`) DÜĞMELİ şeritleri hiç kapatmaz, (b) yalnız
///      mesajı gösteren rota EN ÜSTTEYKEN sayar — üstte bir sayfa/pencere
///      açıkken süre hiç işlemez. Kalem ekranındaki "2. sayfadan devam
///      ediliyor · Baştan başla" şeridi bu yüzden duruyordu.
///
/// ## Şimdi
/// Bildirim SnackBar değil, uygulamanın en üst katmanında (`MaterialApp.
/// builder`, bkz. [ToastLayer]) çizilen kendi kartımız:
/// - ekranın **en altında**, sistem çubuğunun hemen üstünde (klavye açıksa
///   onun üstünde); hiçbir ekranın alt çubuğuna/yüzen düğmesine bağlı değil;
/// - süresini **kendisi sayar** ve altındaki ince çubuk kalan süreyi gösterir;
///   parmak kartın üstündeyken sayım durur, kaydırınca kapanır;
/// - yeni bildirim eskisinin yerine geçer (kuyruk yok);
/// - uzun süren işin **kalıcı** kartı ([showStickyToast]) ayrı bir yuvada
///   durur: araya giren kısa bildirim onu süpürmez, ÜSTÜNDE görünür.
///
/// Eski API (`showSnack`, `showSnackOn`, `showSnackBarReplacing` +
/// `SnackBar`/`SnackBarAction`) aynen duruyor: 60'a yakın çağıran
/// değişmeden yeni karta geçti.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_strings.dart';

/// Bilgi bildiriminin ömrü.
const Duration kSnackInfo = Duration(seconds: 3);

/// Düğmesi olan bildirimin ömrü: kullanıcı okuyup basacak.
const Duration kSnackAction = Duration(seconds: 6);

/// Giriş/çıkış canlandırması.
const Duration _kFade = Duration(milliseconds: 200);

/// Gösterilen bildirimin verisi.
class _Toast {
  final int id;
  final Widget content;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// null = kalıcı (elle kapatılana dek).
  final Duration? duration;

  _Toast({
    required this.id,
    required this.content,
    this.actionLabel,
    this.onAction,
    this.duration,
  });
}

/// Bir bildirimi sonradan kapatmak için tutamak.
class ToastHandle {
  final int _id;
  final bool _sticky;

  const ToastHandle._(this._id, this._sticky);

  /// Bu bildirimi kapatır (o an başka bildirim gösteriliyorsa ona dokunmaz).
  void close() => _ToastCenter.close(_id, sticky: _sticky);
}

/// Bildirimlerin tek kaynağı (uygulama genelinde bir tane).
abstract final class _ToastCenter {
  static int _seq = 0;
  static final transient = ValueNotifier<_Toast?>(null);
  static final sticky = ValueNotifier<_Toast?>(null);

  /// Ağaçta kaç [ToastLayer] var (uygulamada 1; testte / özel ağaçta 0).
  static int layers = 0;

  static ToastHandle show(_Toast Function(int id) build,
      {required bool isSticky}) {
    final toast = build(++_seq);
    (isSticky ? sticky : transient).value = toast;
    return ToastHandle._(toast.id, isSticky);
  }

  static void close(int id, {required bool sticky}) {
    final slot = sticky ? _ToastCenter.sticky : transient;
    if (slot.value?.id == id) slot.value = null;
  }

  static void clear() {
    transient.value = null;
    sticky.value = null;
  }
}

/// Katman yoksa (testler, `MaterialApp.builder` dışı ağaçlar) bildirim
/// verilen bağlamın kök `Overlay`ına geçici bir katman olarak eklenir.
/// Yedek katmanın eklendiği `Overlay` (aynı ağaca ikinci kez eklenmesin —
/// giriş bir sonraki karede kurulduğu için sayaç o ana dek sıfırdır).
OverlayState? _fallbackOverlay;

void _ensureLayer(BuildContext? context) {
  if (_ToastCenter.layers > 0) return;
  final overlay =
      context == null ? null : Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  if (identical(overlay, _fallbackOverlay) && overlay.mounted) return;
  _fallbackOverlay = overlay;
  overlay.insert(
      OverlayEntry(builder: (_) => const ToastLayer(child: SizedBox.shrink())));
}

/// [message]'ı gösterir; ekranda bekleyen bildirim varsa **onun yerine geçer**.
///
/// [copyable] verilirse karta **"Kopyala"** düğmesi konur ve mesaj panoya
/// alınabilir (2026-09-04) — hata metinlerini ekran görüntüsü almadan
/// aktarabilmek için. Kendi eylemi olan kartta ([action]) kopyalama konmaz.
ToastHandle showSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration? duration,
  bool copyable = false,
}) {
  final effective = action ??
      (copyable
          ? SnackBarAction(
              label: AppStrings.of(context).t('common.copy'),
              onPressed: () => Clipboard.setData(ClipboardData(text: message)),
            )
          : null);
  _ensureLayer(context);
  return _showToast(Text(message), effective, duration);
}

/// [showSnack]'in bağlamsız hâli (asenkron akışlar için; messenger yalnız
/// eski imzayla uyum için alınır).
ToastHandle showSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  _ensureLayer(messenger.mounted ? messenger.context : null);
  return _showToast(Text(message), action, duration);
}

/// Hazır bir [SnackBar]ın içeriğini, eylemini ve süresini aynı kuralla
/// gösterir. Özel içerikli bildirimler için.
ToastHandle showSnackBarReplacing(
  ScaffoldMessengerState messenger,
  SnackBar bar,
) {
  _ensureLayer(messenger.mounted ? messenger.context : null);
  return _showToast(bar.content, bar.action, bar.duration);
}

ToastHandle _showToast(
    Widget content, SnackBarAction? action, Duration? duration) {
  return _ToastCenter.show(
    (id) => _Toast(
      id: id,
      content: content,
      actionLabel: action?.label,
      onAction: action?.onPressed,
      duration: duration ?? (action == null ? kSnackInfo : kSnackAction),
    ),
    isSticky: false,
  );
}

/// Uzun süren işin **kalıcı** kartı (ilerleme). Kısa bildirimler onu
/// süpürmez; iş bitince dönen tutamakla kapatılır.
ToastHandle showStickyToast(
  BuildContext? context,
  Widget content, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  _ensureLayer(context);
  return _ToastCenter.show(
    (id) => _Toast(
      id: id,
      content: content,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    isSticky: true,
  );
}

/// Görünen kısa bildirimi hemen kaldırır (ör. ekran değişirken).
void hideToast() => _ToastCenter.transient.value = null;

/// Uygulamanın en üst katmanı: [child] + ekranın altında bildirim kartları.
///
/// `MaterialApp.builder`'da bir kez kurulur; böylece kart her rotanın,
/// pencerenin ve alt çubuğun ÜSTÜNDE ve hep aynı yerde durur.
class ToastLayer extends StatefulWidget {
  final Widget child;

  const ToastLayer({super.key, required this.child});

  @override
  State<ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<ToastLayer> {
  @override
  void initState() {
    super.initState();
    _ToastCenter.layers++;
  }

  @override
  void dispose() {
    _ToastCenter.layers--;
    // Ağaç söküldü (test sonu, uygulama kapanışı): asılı bildirim bir
    // sonraki ağaçta hortlamasın.
    if (_ToastCenter.layers <= 0) _ToastCenter.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final bottom = (media?.viewInsets.bottom ?? 0) > 0
        ? media!.viewInsets.bottom + 8
        : (media?.viewPadding.bottom ?? 0) + 10;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          left: 12,
          right: 12,
          bottom: bottom,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<_Toast?>(
                      valueListenable: _ToastCenter.transient,
                      builder: (_, toast, __) => toast == null
                          ? const SizedBox.shrink()
                          : _ToastCard(
                              key: ValueKey(toast.id),
                              toast: toast,
                              onGone: () =>
                                  _ToastCenter.close(toast.id, sticky: false),
                            ),
                    ),
                    ValueListenableBuilder<_Toast?>(
                      valueListenable: _ToastCenter.sticky,
                      builder: (_, toast, __) => toast == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _ToastCard(
                                key: ValueKey(toast.id),
                                toast: toast,
                                onGone: () =>
                                    _ToastCenter.close(toast.id, sticky: true),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tek kart: giriş/çıkış solması + kalan süre çubuğu.
///
/// Tek bir `AnimationController` kartın bütün ömrünü sürer (giriş + görünme
/// + çıkış). Zamanlayıcı widget'ın içinde: ağaç sökülünce kendiliğinden
/// durur (testlerde "bekleyen zamanlayıcı" kalmaz).
class _ToastCard extends StatefulWidget {
  final _Toast toast;
  final VoidCallback onGone;

  const _ToastCard({super.key, required this.toast, required this.onGone});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life;
  late final Duration _total;

  bool get _sticky => widget.toast.duration == null;

  @override
  void initState() {
    super.initState();
    final shown = widget.toast.duration ?? Duration.zero;
    _total = _sticky ? _kFade : _kFade * 2 + shown;
    _life = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_sticky) widget.onGone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  double get _fadeFraction =>
      _kFade.inMicroseconds / _total.inMicroseconds.clamp(1, 1 << 62);

  double _opacity(double t) {
    final f = _fadeFraction;
    if (t < f) return t / f;
    if (_sticky) return 1;
    if (t > 1 - f) return ((1 - t) / f).clamp(0.0, 1.0);
    return 1;
  }

  /// Kalan görünme süresi (1 → 0).
  double _remaining(double t) {
    final f = _fadeFraction;
    if (_sticky) return 1;
    final span = 1 - 2 * f;
    if (span <= 0) return 0;
    return (1 - (t - f) / span).clamp(0.0, 1.0);
  }

  void _pause() {
    if (!_sticky && _life.isAnimating) _life.stop();
  }

  void _resume() {
    if (!_sticky && !_life.isAnimating && !_life.isCompleted) _life.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final toast = widget.toast;
    final fg = scheme.onInverseSurface;
    return Dismissible(
      key: ValueKey('toast-${toast.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => widget.onGone(),
      child: Listener(
        onPointerDown: (_) => _pause(),
        onPointerUp: (_) => _resume(),
        onPointerCancel: (_) => _resume(),
        child: AnimatedBuilder(
          animation: _life,
          builder: (context, child) {
            final t = _life.value;
            final o = _opacity(t);
            return Opacity(
              opacity: o,
              child: Transform.translate(
                offset: Offset(0, (1 - o) * 12),
                child: child,
              ),
            );
          },
          child: Material(
            color: scheme.inverseSurface,
            elevation: 6,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 46),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                        start: 16, end: toast.actionLabel == null ? 16 : 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: DefaultTextStyle.merge(
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: fg),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              child: IconTheme.merge(
                                data: IconThemeData(color: fg),
                                child: toast.content,
                              ),
                            ),
                          ),
                        ),
                        if (toast.actionLabel != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.inversePrimary,
                              textStyle: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              widget.onGone();
                              toast.onAction?.call();
                            },
                            child: Text(toast.actionLabel!),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!_sticky)
                  AnimatedBuilder(
                    animation: _life,
                    builder: (_, __) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: _remaining(_life.value),
                        child: Container(
                          height: 3,
                          color: scheme.inversePrimary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
