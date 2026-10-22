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
