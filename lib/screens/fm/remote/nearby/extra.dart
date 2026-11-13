part of '../nearby_screen.dart';

/// Yakındakiler ekranının ana dosyası 1000 satır sınırına dayandığı için
/// (2026-11-13) ayrılan davranışlar: gelen yazı, şifreleme (G5) yardımcıları,
/// otomatik eşitleme ve bağlantıyla gönderme bağlantıları.
extension _NearbyExtra on _NearbyScreenState {
  /// Gelen yazı: diske yazılmaz, kopyalanabilir olarak gösterilir.
  void _showIncomingText(String text, String from) {
    if (!mounted) return;
    AppHaptics.step();
    unawaited(showAppSheet<void>(
      context,
      title: context.t('near.text_from', {'from': from}),
      builder: (ctx) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45),
              child: SingleChildScrollView(
                child: SelectableText(
                  key: const ValueKey('near-text-in'),
                  text,
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            FilledButton.icon(
              key: const ValueKey('near-text-copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(ctx);
                showSnack(context, context.t('near.copied'));
              },
              icon: const Icon(AppIcons.copyPlain),
              label: Text(ctx.t('near.text_copy')),
            ),
          ],
        ),
      ),
    ));
  }


  /// Otomatik eşitleme (2026-11-13): kuralı açık, şifreli bir eş görününce
  /// yeni dosyaları gönderir ([AutoSync]; tek seferde bir tur).
  void _maybeSync(Peer peer) {
    final me = _key;
    if (me == null || !peer.secure || _out != null) return;
    if (!(AutoSync.instance.rule(peer.fingerprint)?.on ?? false)) return;
    unawaited(AutoSync.instance
        .runFor(peer, me: me, name: _deviceName, id: _id)
        .then((n) {
      if (n > 0 && mounted) {
        showSnack(context, context.t('sync.done', {'n': n, 'name': peer.name}));
      }
    }));
  }
}
