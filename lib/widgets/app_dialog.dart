import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

/// **Ortak iletişim penceresi ve levha** (Faz 15 / madde 6, 2026-10-22).
///
/// KÖK NEDEN: 94 `showDialog` ve 55 `showModalBottomSheet` her ekranda elle
/// kuruluyordu. Onay pencerelerinde birincil eylem kimi yerde solda, kimi
/// yerde sağdaydı; "Sil" bir yerde vurgu renginde, öbüründe kırmızıydı;
/// levhaların bir kısmı alt sistem çubuğunun altında kalıyordu. Kurallar:
/// * **birincil eylem SONDA** (soldan sağa dilde sağda, Arapçada solda —
///   Material'in `actions` sırası yönü kendisi çevirir);
/// * **yıkıcı eylem** tehlike rengi dolgulu (`colorScheme.error`);
/// * levha içeriği alttan `SafeArea` ile korunur, klavye açılınca yukarı
///   çıkar, başlık `titleMedium`.
///
/// Yeni kod bu ikisini kullanır (bekçi: `design_tokens_test` — `dialogs`
/// ve `sheets` tavanı).

/// Evet/hayır onayı. Vazgeçme ya da dışarı dokunma `false` döner.
Future<bool> showAppConfirm(
  BuildContext context, {
  String? title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            // Tema `error` rolü = ailenin `danger`ı (AppColors.danger ile aynı).
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ??
                ctx.t(destructive ? 'common.delete' : 'common.ok')),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Alt levha: tutamaç (tema), isteğe bağlı başlık, kaydırılabilir gövde,
/// alt sistem çubuğu ve klavye payı.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final body = builder(ctx);
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
                  child: Text(title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                      semanticsLabel: title),
                ),
              if (scrollable)
                Flexible(child: SingleChildScrollView(child: body))
              else
                Flexible(child: body),
            ],
          ),
        ),
      );
    },
  );
}

/// Tek satırlık metin sorusu (ad ver, yeniden adlandır…). Vazgeçme, boş ya
/// da yalnız boşluk yanıt `null` döner; yanıt kırpılmış gelir.
/// Denetleyiciyi pencerenin kendi durumu tutar: `await` sonrası elle
/// `dispose` kapanış animasyonu sürerken alanı çökertir ("used after being
/// disposed") — elle kurulan eski pencerelerin ortak hatası.
Future<String?> showAppPrompt(
  BuildContext context, {
  String? title,
  String? label,
  String initial = '',
  String? confirmLabel,
  int? maxLength,
  int? selectEnd,
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      selectEnd: selectEnd,
    ),
  );
  final clean = text?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    this.title,
    this.label,
    required this.initial,
    this.confirmLabel,
    this.maxLength,
    this.selectEnd,
  });

  final String? title, label, confirmLabel;
  final String initial;
  final int? maxLength;

  /// Seçimin sonu (ad değiştirirken uzantı seçilmesin); null = tümü.
  final int? selectEnd;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: (widget.selectEnd ?? widget.initial.length)
            .clamp(0, widget.initial.length));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: widget.title == null ? null : Text(widget.title!),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(widget.confirmLabel ?? context.t('common.ok')),
          ),
        ],
      );
}
