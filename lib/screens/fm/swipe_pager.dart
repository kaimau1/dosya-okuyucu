import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/app_icons.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// Kaydırmalı gezginin bir sayfası.
class SwipePage {
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const SwipePage({
    required this.label,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

/// **Kategoriler arasında sağa-sola kaydırarak geçiş** (2026-09-27,
/// kullanıcı: *"sağa sola kaydırarak İndirilenler, Görseller, Videolar gibi
/// sırayla geçiş olabilir"*).
///
/// Panodaki kutulardan biri açılınca bu gezgin açılır; her sayfa o kutunun
/// kendi ekranıdır (başlık, arama, seçim, geri tuşu olduğu gibi). Kaydırınca
/// komşu kategoriye geçilir; altta kısa süre beliren şerit nerede olunduğunu
/// ve yanlarda ne olduğunu gösterir.
///
/// Sayfalar TEMBEL kurulur (`PageView.builder`): Görüntüler'in binlerce
/// küçük resmi, kullanıcı oraya kaydırmadıkça çözülmez.
///
/// ## Seçim sürerken kaydırma KİLİTLİ (2026-10-17)
/// Kullanıcı: *"fotoğraf video PDF vs seçim yapılırken sağa sola kaydırıp
/// dosya sayfaları arasında geçiş olmamalı, seçimi zorlaştırıyor"*. Seçim
/// kipinde parmak hücreden hücreye gezerken biraz yana kayınca komşu
/// kategoriye geçiliyordu — ve sayfa kurulumu tembel olduğu için o ana kadar
/// yapılan SEÇİM de kayboluyordu. Artık sayfanın içinden bir [SwipeHold]
/// (seçim çubuğu bunu kendisi koyar) ağaçta durduğu sürece ve iki parmak
/// ekrandayken (galerideki pinch yakınlaştırması yatay sürüklemeyle
/// yarışıyordu) yatay geçiş kapalıdır.
class SwipePager extends StatefulWidget {
  final List<SwipePage> pages;
  final int initial;

  const SwipePager({super.key, required this.pages, this.initial = 0});

  @override
  State<SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<SwipePager> {
  late final PageController _controller =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _hintVisible = true;
  Timer? _hintTimer;

  /// Sayfaların içinden gelen kilit sayısı (bkz. [SwipeHold]).
  final ValueNotifier<int> _holds = ValueNotifier(0);

  /// Ekrandaki parmak sayısı — iki parmak = pinch, sayfa değişmesin.
  int _pointers = 0;

  bool get _locked => _holds.value > 0 || _pointers >= 2;

  @override
  void initState() {
    super.initState();
    _holds.addListener(_onHoldsChanged);
    _scheduleHide(const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _holds.removeListener(_onHoldsChanged);
    _holds.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Kilit, çocuk sayfanın KURULUMU ya da SÖKÜLMESİ sırasında değişir; o an
  /// ata öğede `setState` çağırmak yasak (build/finalize kilidi). Kare
  /// sürüyorsa yeniden çizim karenin sonuna ertelenir.
  void _onHoldsChanged() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  void _pointerDelta(int delta) {
    final before = _pointers >= 2;
    _pointers = (_pointers + delta).clamp(0, 10);
    if ((_pointers >= 2) != before) setState(() {});
  }

  void _scheduleHide(Duration after) {
    _hintTimer?.cancel();
    _hintTimer = Timer(after, () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = widget.pages;
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => _pointerDelta(1),
          onPointerUp: (_) => _pointerDelta(-1),
          onPointerCancel: (_) => _pointerDelta(-1),
          child: SwipeLock._(
            holds: _holds,
            child: PageView.builder(
              controller: _controller,
              // Kilitliyken sürükleme tanıyıcısı hiç kurulmaz; yarıda kalan bir
              // sürükleme PageView'un sayfa fiziğiyle en yakın sayfaya oturur.
              physics: _locked ? const NeverScrollableScrollPhysics() : null,
              itemCount: pages.length,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _hintVisible = true;
                });
                _scheduleHide(const Duration(milliseconds: 1400));
              },
              itemBuilder: (context, i) => pages[i].builder(context),
            ),
          ),
        ),
        // Nerede olduğunu gösteren şerit: dokunuşları YUTMAZ.
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 18,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              child: Center(
                child: Material(
                  color: scheme.inverseSurface.withValues(alpha: 0.9),
                  shape: const StadiumBorder(),
                  elevation: 3,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_index > 0) ...[
                          Icon(AppIcons.chevronLeft,
                              size: 16,
                              color: scheme.onInverseSurface
                                  .withValues(alpha: 0.6)),
                          Text(pages[_index - 1].label,
                              style: context.type.small.copyWith(
                                  color: scheme.onInverseSurface
                                      .withValues(alpha: 0.6),
                                )),
                          const SizedBox(width: 10),
                        ],
                        Icon(pages[_index].icon,
                            size: 16, color: pages[_index].color),
                        const SizedBox(width: 6),
                        Text(pages[_index].label,
                            style: context.type.compact.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onInverseSurface,
                              )),
                        if (_index < pages.length - 1) ...[
                          const SizedBox(width: 10),
                          Text(pages[_index + 1].label,
                              style: context.type.small.copyWith(
                                  color: scheme.onInverseSurface
                                      .withValues(alpha: 0.6),
                                )),
                          Icon(AppIcons.chevron,
                              size: 16,
                              color: scheme.onInverseSurface
                                  .withValues(alpha: 0.6)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// [SwipePager]'ın kilit kanalı — sayfalar bunu [SwipeHold] üstünden bulur.
/// Bağımlılık kaydı YOK (`getInheritedWidgetOfExactType`): kilit sayısı
/// değişince sayfaların yeniden kurulmasına gerek yok, yalnız gezgin
/// fiziğini değiştirir.
class SwipeLock extends InheritedWidget {
  final ValueNotifier<int> holds;

  const SwipeLock._({required this.holds, required super.child});

  static ValueNotifier<int>? _holdsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SwipeLock>()?.holds;

  @override
  bool updateShouldNotify(SwipeLock oldWidget) => false;
}

/// Ağaçta durduğu sürece en yakın [SwipePager]'ın yatay geçişini kilitler.
/// Gezgin dışında (sayfa doğrudan açıldıysa) hiçbir şey yapmaz.
///
/// Seçim çubuğu (`FmSelectionBar`) kendini bununla sarar: seçim başlayınca
/// çubuk belirir → kilit; seçim bitince çubuk kalkar → kilit çözülür. Her
/// ekranın kendi seçim durumunu gezgine bildirmesi gerekmiyor.
class SwipeHold extends StatefulWidget {
  final Widget child;

  const SwipeHold({super.key, required this.child});

  @override
  State<SwipeHold> createState() => _SwipeHoldState();
}

class _SwipeHoldState extends State<SwipeHold> {
  ValueNotifier<int>? _holds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final holds = SwipeLock._holdsOf(context);
    if (identical(holds, _holds)) return;
    _release();
    _holds = holds;
    if (holds != null) holds.value++;
  }

  void _release() {
    final holds = _holds;
    _holds = null;
    if (holds != null && holds.value > 0) holds.value--;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
