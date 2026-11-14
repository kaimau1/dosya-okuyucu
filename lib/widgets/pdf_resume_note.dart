import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme.dart';

/// "42. sayfadan devam ediliyor" notu — okuma kipine uygun, sayfanın üstünde
/// duran ince hap (2026-11-02).
///
/// Eskiden ekranın altına inen bir SnackBar'dı: okuma sırasında çubuk gibi
/// kayıp sayfayı örtüyor, kendi başına kaybolmuyordu. Şimdi sayfa rozetiyle
/// (`PdfPageChip`) aynı dili konuşuyor: yer imi simgesi + tek cümle + tek
/// dokunuşluk "Baştan başla"; birkaç saniye sonra yumuşakça çekiliyor.
///
/// Bir `Stack`in DOĞRUDAN çocuğu olmalı (`PositionedDirectional` üretir).
class PdfResumeNote extends StatefulWidget {
  final int page;
  final double top;
  final VoidCallback onRestart;
  final VoidCallback onDismiss;
  final Duration? stay;

  const PdfResumeNote({
    super.key,
    required this.page,
    required this.onRestart,
    required this.onDismiss,
    this.top = 12,
    this.stay,
  });

  @override
  State<PdfResumeNote> createState() => _PdfResumeNoteState();
}

class _PdfResumeNoteState extends State<PdfResumeNote> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _timer = Timer(widget.stay ?? Motion.noteStay, _leave);
  }

  void _leave() {
    if (!mounted) return;
    setState(() => _shown = false);
    // Solma bitince sahibine haber ver (yoksa widget ağaçta kalırdı).
    _timer = Timer(Motion.medium, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;
    return PositionedDirectional(
      top: widget.top,
      start: 16,
      end: 16,
      child: Center(
        child: AnimatedSlide(
          duration: Motion.medium,
          curve: Motion.enter,
          offset: _shown ? Offset.zero : const Offset(0, -0.6),
          child: AnimatedOpacity(
            duration: Motion.medium,
            opacity: _shown ? 1 : 0,
            child: Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 12,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: Material(
                  color: scheme.inverseSurface.withValues(alpha: 0.92),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.bookmark,
                            size: 16, color: scheme.inversePrimary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            context.t('vw.resumed_page', {'n': '${widget.page}'}),
                            style: context.type.compact.copyWith(color: fg),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          key: const ValueKey('pdf-resume-restart'),
                          onPressed: () {
                            _timer?.cancel();
                            widget.onRestart();
                            widget.onDismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.inversePrimary,
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(48, 40),
                          ),
                          child: Text(context.t('vw.restart_doc')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
