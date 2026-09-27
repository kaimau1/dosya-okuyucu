import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _scheduleHide(const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
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
        PageView.builder(
          controller: _controller,
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
        // Nerede olduğunu gösteren şerit: dokunuşları YUTMAZ.
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 18,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: const Duration(milliseconds: 220),
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
                          Icon(Icons.chevron_left_rounded,
                              size: 16,
                              color: scheme.onInverseSurface
                                  .withValues(alpha: 0.6)),
                          Text(pages[_index - 1].label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onInverseSurface
                                      .withValues(alpha: 0.6))),
                          const SizedBox(width: 10),
                        ],
                        Icon(pages[_index].icon,
                            size: 16, color: pages[_index].color),
                        const SizedBox(width: 6),
                        Text(pages[_index].label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onInverseSurface)),
                        if (_index < pages.length - 1) ...[
                          const SizedBox(width: 10),
                          Text(pages[_index + 1].label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onInverseSurface
                                      .withValues(alpha: 0.6))),
                          Icon(Icons.chevron_right_rounded,
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
