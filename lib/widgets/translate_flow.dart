import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../services/doc_translate.dart';
import '../services/pdf_translate_doc.dart';
import '../services/ocr_service.dart';
import '../services/translate_service.dart';
import 'pdf_save_dialog.dart';
import '../core/snack.dart';

/// Akış sırasında ilerlemeyi yazan ve **iptal isteğini taşıyan** tutamak.
///
/// Metni toplayan kod (OCR, metin katmanı) arayüzü tanımaz; ilerlemeyi buraya
/// yazar, iptali buradan okur.
class TranslateProgress {
  final ValueNotifier<String> message;
  bool _cancelled = false;

  TranslateProgress(String initial) : message = ValueNotifier(initial);

  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
  void status(String text) => message.value = text;
  void dispose() => message.dispose();
}

/// Çevrilecek metni **çeviri anında** üreten yükleyici (OCR burada koşar).
typedef TranslatePageLoader = Future<List<OcrPage>> Function(
    TranslateProgress progress);

/// Çeviri akışı: dil seç → (ilk kullanımda) dil modelini indir → metni topla
/// (gerekirse OCR) → sayfa sayfa çevir → sonucu kopyalanabilir bir sayfada
/// göster.
///
/// İki giriş noktası var, ikisi de aynı gövdeyi kullanır:
/// - [run]: elde **hazır metin** varken (PDF'te seçili metin, düz metin belge).
/// - [runDocument]: belgenin tamamı için — metin akış içinde toplanır, yani
///   taranmış PDF'te OCR'ı kullanıcı ayrıca çalıştırmaz (istek 2026-07-31:
///   *"tek butonla"*).
class TranslateFlow {
  static Future<void> run(
    BuildContext context,
    String text, {
    String? title,
  }) async {
    final str = AppStrings.of(context);
    final source = text.trim();
    if (source.isEmpty) {
      _snack(context, str.t('tf.no_text'));
      return;
    }
    await _run(
      context,
      title: title ?? str.t('tf.title'),
      load: (_) async => [OcrPage(1, source)],
    );
  }

  /// **PDF'i kendi düzeninde çevirir** — sonuç metin sayfası değil, aynı
  /// belgenin hedef dildeki hâli (bkz. [PdfInPlaceTranslate]).
  ///
  /// Kullanıcı isteği 2026-08-30: *"çevir özelliği PDF'i aynı formata çevirip
  /// sanki aynı belge diğer dildeymiş gibi yazabilmeli."*
  ///
  /// Akış metin çevirisiyle aynı iskeleti kullanır (dil seç → model indir →
  /// durdurulabilir ilerleme), sonu farklı: çevrilen baytlar `savePdfWithChoice`
  /// ile kaydediliyor (üzerine yaz / kopya / klasör seç) ve hemen açılabiliyor.
  static Future<void> runPdfInPlace(
    BuildContext context, {
    required String path,
    required List<int> bytes,
    required int pageCount,
  }) async {
    final str = AppStrings.of(context);
    final pair = await TranslateService.lastPair();
    if (!context.mounted) return;
    final chosen = await _pickLanguages(context, pair.$1, pair.$2);
    if (chosen == null || !context.mounted) return;
    final (from, to) = chosen;
    await TranslateService.savePair(from, to);
    if (!context.mounted) return;

    final progress = TranslateProgress(str.t('tf.preparing'));
    _showProgress(context, progress);

    PdfTranslateOutcome? outcome;
    String? error;
    try {
      for (final lang in {from, to}) {
        if (progress.cancelled) break;
        if (!await TranslateService.isModelReady(lang)) {
          progress.status('${str.t('tf.downloading', {
                'lang': TranslateService.languages[lang],
              })}\n${str.t('tf.first_use')}');
          await TranslateService.downloadModel(lang);
        }
      }
      if (!progress.cancelled) {
        // Çevirmen TEK bir kez açılır ve sonunda kapatılır: her paragraf için
        // yeniden kurmak yüzlerce paragraflık bir belgede saniyeler yer.
        final translator = TranslateService.translator(from: from, to: to);
        try {
          outcome = await PdfInPlaceTranslate.run(
            bytes: bytes,
            pageCount: pageCount,
            translate: (text) => TranslateService.translateWith(
              translator,
              text,
              cancelled: () => progress.cancelled,
            ),
            onPage: (done, total) => progress.status(str.t(
                'tf.page_translating', {'n': done + 1, 'total': total})),
            cancelled: () => progress.cancelled,
          );
        } finally {
          await translator.close();
        }
      }
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) {
      progress.dispose();
      return;
    }
    Navigator.of(context).pop(); // ilerleme penceresi
    final cancelled = progress.cancelled;
    progress.dispose();

    if (error != null) {
      _snack(context, str.t('tf.failed', {'error': error}));
      return;
    }
    final result = outcome;
    if (result == null || !result.changed) {
      // Durduruldu, çevrilecek paragraf yok ya da hiçbiri belgeye yazılamadı —
      // üçü ayrı şey, üçü de ayrı söyleniyor.
      _snack(
        context,
        cancelled
            ? str.t('tf.stopped')
            : (result != null && result.skipped > 0)
                ? str.t('tf.inplace_none', {'n': result.skipped})
                : str.t('tf.empty_result'),
      );
      return;
    }

    // Not DÜRÜST: kaç paragraf çevrildi, kaçı olduğu gibi kaldı.
    final note = result.skipped > 0
        ? str.t('tf.inplace_partial',
            {'n': result.translated, 'skipped': result.skipped})
        : str.t('tf.inplace_done',
            {'n': result.translated, 'pages': result.pages});
    if (cancelled) _snack(context, str.t('tf.stopped'));
    await savePdfWithChoice(
      context,
      originalPath: path,
      bytes: result.bytes,
      note: note,
    );
  }

  /// Tüm belgeyi çevirir. [load] metni akış içinde toplar (sayfa sayfa);
  /// döndürdüğü liste boşsa "metin yok" denir.
  static Future<void> runDocument(
    BuildContext context, {
    required String title,
    required TranslatePageLoader load,
  }) =>
      _run(context, title: title, load: load);

  static Future<void> _run(
    BuildContext context, {
    required String title,
    required TranslatePageLoader load,
  }) async {
    final str = AppStrings.of(context);
    final pair = await TranslateService.lastPair();
    if (!context.mounted) return;
    final chosen = await _pickLanguages(context, pair.$1, pair.$2);
    if (chosen == null || !context.mounted) return;
    final (from, to) = chosen;
    await TranslateService.savePair(from, to);
    if (!context.mounted) return;

    final progress = TranslateProgress(str.t('tf.preparing'));
    _showProgress(context, progress);

    List<OcrPage> result = const [];
    var sourcePages = 0;
    String? error;
    try {
      // Modeller yoksa indir (tek seferlik, internet gerekir; sonrası çevrimdışı).
      for (final lang in {from, to}) {
        if (progress.cancelled) break;
        if (!await TranslateService.isModelReady(lang)) {
          progress.status('${str.t('tf.downloading', {
                'lang': TranslateService.languages[lang],
              })}\n${str.t('tf.first_use')}');
          await TranslateService.downloadModel(lang);
        }
      }
      final pages = progress.cancelled ? <OcrPage>[] : await load(progress);
      sourcePages = pages.length;
      if (pages.isNotEmpty && !progress.cancelled) {
        result = await DocTranslate.translatePages(
          pages,
          from: from,
          to: to,
          onPage: (done, total) => progress.status(total > 1
              ? str.t('tf.page_translating', {'n': done + 1, 'total': total})
              : str.t('tf.working')),
          cancelled: () => progress.cancelled,
        );
      }
    } catch (e) {
      error = '$e';
    }

    if (!context.mounted) {
      progress.dispose();
      return;
    }
    Navigator.of(context).pop(); // ilerleme penceresi
    final cancelled = progress.cancelled;
    progress.dispose();

    if (error != null) {
      _snack(context, str.t('tf.failed', {'error': error}));
      return;
    }
    if (result.isEmpty) {
      // Durdurulan iş "başarısız" değildir; kullanıcı ne olduğunu bilsin.
      _snack(context,
          cancelled ? str.t('tf.stopped') : str.t('tf.empty_result'));
      return;
    }
    _showResult(
      context,
      title: title,
      pages: result,
      from: from,
      to: to,
      // Yarım kalan çeviri sonuç sayfasında açıkça yazar: eksik metni tam
      // sanmak, çeviriyi hiç görmemekten daha kötü.
      partialOf: cancelled && result.length < sourcePages ? sourcePages : null,
    );
  }

  /// Kaynak/hedef dil seçimi. Kullanıcı iptal ederse null döner.
  static Future<(TranslateLanguage, TranslateLanguage)?> _pickLanguages(
    BuildContext context,
    TranslateLanguage initialFrom,
    TranslateLanguage initialTo,
  ) {
    var from = initialFrom;
    var to = initialTo;
    return showDialog<(TranslateLanguage, TranslateLanguage)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget dropdown(
              TranslateLanguage value, ValueChanged<TranslateLanguage> onChange) {
            return DropdownButton<TranslateLanguage>(
              value: value,
              isExpanded: true,
              items: [
                for (final e in TranslateService.languages.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => v == null ? null : onChange(v),
            );
          }

          return AlertDialog(
            title: Text(ctx.t('tf.lang_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(ctx.t('tf.source_lang'))),
                dropdown(from, (v) => setLocal(() => from = v)),
                const SizedBox(height: 8),
                IconButton(
                  tooltip: ctx.t('tf.swap'),
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => setLocal(() {
                    final t = from;
                    from = to;
                    to = t;
                  }),
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(ctx.t('tf.target_lang'))),
                dropdown(to, (v) => setLocal(() => to = v)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.t('common.cancel')),
              ),
              FilledButton(
                onPressed: from == to
                    ? null // aynı dil → çeviri anlamsız
                    : () => Navigator.pop(ctx, (from, to)),
                child: Text(ctx.t('common.translate')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// İlerleme penceresi — **durdurulabilir**: 200 sayfalık taranmış bir belge
  /// on dakika sürebiliyor ve eskiden pencerenin kapatılmasının hiçbir yolu
  /// yoktu (`barrierDismissible: false`, düğme yok).
  static void _showProgress(
      BuildContext context, TranslateProgress progress) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress.message,
                builder: (_, v, __) => Text(v),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            // Pencere KAPATILMAZ: iş döngüsü iptal bayrağını görüp durunca
            // akışın kendisi kapatıyor. Burada kapatmak, arkada süren OCR'ı
            // görünmez bırakırdı.
            onPressed: () {
              progress.cancel();
              progress.status(ctx.t('tf.stopping'));
            },
            child: Text(ctx.t('common.stop')),
          ),
        ],
      ),
    );
  }

  static void _showResult(
    BuildContext context, {
    required String title,
    required List<OcrPage> pages,
    required TranslateLanguage from,
    required TranslateLanguage to,
    int? partialOf,
  }) {
    final str = AppStrings.of(context);
    final text = OcrService.joinPages(
        pages, (n) => str.t('tf.page_header', {'n': n}));
    final header = '$title — ${TranslateService.languages[from]} → '
        '${TranslateService.languages[to]}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(header,
                        style: Theme.of(ctx).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: ctx.t('common.share'),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    onPressed: () => Share.share(text, subject: title),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        _snack(context, context.t('tf.copied'));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(ctx.t('common.copy')),
                  ),
                ],
              ),
              if (partialOf != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    ctx.t('tf.partial',
                        {'n': pages.length, 'total': partialOf}),
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.only(top: 12),
                  child: SelectableText(text,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    showSnack(context, msg);
  }
}
