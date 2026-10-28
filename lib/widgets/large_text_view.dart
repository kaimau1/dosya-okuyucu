import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../core/user_error.dart';
import '../services/large_text.dart';
import 'office_shell.dart' show ReadingChrome;

/// Büyük metin dosyasının **sanal listesi** (bkz. [LargeTextFile]).
///
/// Yalnız ekrandaki satırlar diskten okunur: satırlar [_block]'luk bloklar
/// hâlinde getirilir, en çok [_maxBlocks] blok bellekte tutulur. Kaydırma
/// çubuğu tutulup sürüklenebilir — 400 bin satırlık kayıtta parmakla
/// kaydırmak yerine doğrudan ortasına atlanır.
class LargeTextView extends StatefulWidget {
  final String path;
  final double fontSize;
  final String? fontFamily;
  final bool lineNumbers;

  /// Testler dizini hazır verebilsin diye (gerçek kullanımda null → açılır).
  final LargeTextFile? file;

  const LargeTextView({
    super.key,
    required this.path,
    required this.fontSize,
    this.fontFamily,
    this.lineNumbers = true,
    this.file,
  });

  @override
  State<LargeTextView> createState() => _LargeTextViewState();
}

class _LargeTextViewState extends State<LargeTextView> {
  static const _block = 200;
  static const _maxBlocks = 40;

  LargeTextFile? _file;
  Object? _error;
  final _blocks = <int, List<String>>{};
  final _loading = <int>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final given = widget.file;
    if (given != null) {
      _file = given;
    } else {
      LargeTextFile.open(widget.path).then((f) {
        if (mounted) setState(() => _file = f);
      }, onError: (Object e) {
        if (mounted) setState(() => _error = e);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _line(int index) {
    final b = index ~/ _block;
    final block = _blocks[b];
    if (block != null) {
      // Son kullanılan blok sona taşınır (en eski baştan atılır).
      _blocks.remove(b);
      _blocks[b] = block;
      final k = index - b * _block;
      return k < block.length ? block[k] : '';
    }
    if (_loading.add(b)) {
      _file!.lines(b * _block, _block).then((lines) {
        _loading.remove(b);
        if (!mounted) return;
        setState(() {
          _blocks[b] = lines;
          while (_blocks.length > _maxBlocks) {
            _blocks.remove(_blocks.keys.first);
          }
        });
      }, onError: (Object _) => _loading.remove(b));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Okuma kipinde çubuklar belgenin üstünde kayan katman: dev dosyada
    // içerik onların altından başlar (pay sabit — yerleşim titremez).
    return Padding(
      padding: ReadingChrome.insetsOf(context),
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = _file;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(userErrorText(_error!), textAlign: TextAlign.center),
        ),
      );
    }
    if (file == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.t('lt.indexing')),
          ],
        ),
      );
    }
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      height: 1.4,
      color: scheme.onSurface,
    );
    final numberStyle = style.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final digits = '${file.lineCount}'.length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(AppIcons.lock, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('lt.banner', {
                    'n': file.lineCount,
                    'enc': file.encodingLabel,
                  }),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Paper.docSurface(context),
            child: Scrollbar(
              controller: _scroll,
              interactive: true,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 24),
                itemCount: file.lineCount,
                itemBuilder: (context, i) {
                  final text = _line(i);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.lineNumbers)
                        SizedBox(
                          width: widget.fontSize * 0.62 * digits + 12,
                          child: Text('${i + 1}',
                              style: numberStyle, textAlign: TextAlign.end),
                        ),
                      if (widget.lineNumbers) const SizedBox(width: 10),
                      Expanded(
                        child: text == null
                            ? SizedBox(height: widget.fontSize * 1.4)
                            : SelectableText(text, style: style),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
