/// Sözdizimi renklendirmeli ve parantez eşlemeli metin denetleyicisi (Faz 30).
///
/// `TextEditingController.buildTextSpan` geçersiz kılınır: metin aynı
/// kalır, yalnız boyası değişir — imleç, seçim, IME ve geri al çalışmaya
/// devam eder. IME birleştirme sürerken (Türkçe/öneri) renklendirme atlanır,
/// alttaki çizgi bozulmasın.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import 'code_editing.dart';
import 'code_highlight.dart';

class CodeTextController extends TextEditingController {
  CodeLang _lang;
  bool _enabled;

  CodeTextController({super.text, CodeLang lang = CodeLang.plain, bool enabled = true})
      : _lang = lang,
        _enabled = enabled;

  CodeLang get lang => _lang;
  set lang(CodeLang v) {
    if (v == _lang) return;
    _lang = v;
    _cacheText = null;
    notifyListeners();
  }

  bool get enabled => _enabled;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    notifyListeners();
  }

  /// Renklendirme bu metinde etkin mi?
  bool get highlighting =>
      _enabled &&
      _lang != CodeLang.plain &&
      text.length <= codeHighlightIsolateMaxChars;

  /// Büyük metin (> 1 MB) arka planda mı renkleniyor.
  bool get backgroundHighlighting =>
      highlighting && text.length > codeHighlightMaxChars;

  String? _cacheText;
  CodeLang? _cacheLang;
  List<CodeToken> _cache = const [];

  /// Arka plan renklendirmesinin çalıştırıcısı (testte eşzamanlı; üretimde
  /// izolat — `compute` flutter_test'te tamamlanmıyor).
  static Future<List<CodeToken>> Function(String text, CodeLang lang)
      backgroundTokenize = _inIsolate;

  static Future<List<CodeToken>> _inIsolate(String text, CodeLang lang) =>
      compute(_tokenizeEntry, (text, lang));

  static List<CodeToken> _tokenizeEntry((String, CodeLang) a) =>
      tokenizeCode(a.$1, a.$2);

  /// Yazma durduktan sonra arka plan renklendirmesi.
  static const backgroundDelay = Motion.long;
  Timer? _bgTimer;
  int _bgSeq = 0;

  List<CodeToken> get tokens {
    final t = text;
    final fresh = (identical(t, _cacheText) || t == _cacheText) &&
        _cacheLang == _lang;
    if (fresh) return _cache;
    if (t.length <= codeHighlightMaxChars) {
      _cache = tokenizeCode(t, _lang);
      _cacheText = t;
      _cacheLang = _lang;
      return _cache;
    }
    // Büyük metin: eski belirteçler kaymış olur → o an düz çizilir, yazma
    // durunca izolatta hesaplanıp yeniden boyanır.
    _scheduleBackground(t, _lang);
    return const [];
  }

  void _scheduleBackground(String t, CodeLang lang) {
    _bgTimer?.cancel();
    final seq = ++_bgSeq;
    _bgTimer = Timer(backgroundDelay, () async {
      final result = await backgroundTokenize(t, lang);
      if (seq != _bgSeq || text != t || _lang != lang) return;
      _cache = result;
      _cacheText = t;
      _cacheLang = lang;
      notifyListeners(); // yalnız boya; metin aynı
    });
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    super.dispose();
  }

  /// Renk paleti — açık/koyu temaya göre (`AppColors.syntax*`).
  static Color colorOf(CodeTokenKind k, bool dark) => switch (k) {
        CodeTokenKind.keyword =>
          dark ? AppColors.syntaxKeywordDark : AppColors.syntaxKeywordLight,
        CodeTokenKind.string =>
          dark ? AppColors.syntaxStringDark : AppColors.syntaxStringLight,
        CodeTokenKind.comment =>
          dark ? AppColors.syntaxCommentDark : AppColors.syntaxCommentLight,
        CodeTokenKind.number =>
          dark ? AppColors.syntaxNumberDark : AppColors.syntaxNumberLight,
        CodeTokenKind.type =>
          dark ? AppColors.syntaxTypeDark : AppColors.syntaxTypeLight,
        CodeTokenKind.tag =>
          dark ? AppColors.syntaxTagDark : AppColors.syntaxTagLight,
      };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed;
    final matchPair = _enabled && value.selection.isValid && value.selection.isCollapsed
        ? matchBracket(text, value.selection.baseOffset)
        : null;
    if (composing || (!highlighting && matchPair == null)) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = text;
    final spans = <InlineSpan>[];
    var pos = 0;
    // Parantez eşi vurgusu için kesim noktaları.
    final marks = <int>{};
    if (matchPair != null) {
      marks
        ..add(matchPair.$1)
        ..add(matchPair.$2);
    }
    void plain(int from, int to, TextStyle? st) {
      // Vurgulanacak parantezi ayrı aralığa böl.
      var a = from;
      for (final m in (marks.where((m) => m >= from && m < to).toList()..sort())) {
        if (m > a) spans.add(TextSpan(text: t.substring(a, m), style: st));
        spans.add(TextSpan(
          text: t.substring(m, m + 1),
          style: (st ?? const TextStyle()).copyWith(
            backgroundColor: AppColors.bracketMatch,
            fontWeight: FontWeight.w700,
          ),
        ));
        a = m + 1;
      }
      if (a < to) spans.add(TextSpan(text: t.substring(a, to), style: st));
    }

    if (highlighting) {
      for (final tk in tokens) {
        if (tk.start > pos) plain(pos, tk.start, null);
        plain(tk.start, tk.end,
            TextStyle(color: colorOf(tk.kind, dark)));
        pos = tk.end;
      }
    }
    if (pos < t.length) plain(pos, t.length, null);
    return TextSpan(style: style, children: spans);
  }
}
