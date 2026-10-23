part of '../ai_hub_screen.dart';

class _ChatMsg {
  final bool fromUser;
  final String text;
  final List<AiRecord> sources;

  /// Hata cevabı (anahtar/kota/ağ): balon uyarı renginde çizilir — eskiden
  /// hata metni sıradan bir cevap gibi görünüyordu.
  final bool error;
  const _ChatMsg(this.fromUser, this.text,
      {this.sources = const [], this.error = false});
}

class _ChatTab extends StatefulWidget {
  /// Henüz analiz yoksa boş ekrandaki düğme Analiz sekmesine götürür.
  final VoidCallback onOpenAnalysis;

  const _ChatTab({required this.onOpenAnalysis});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

/// `AutomaticKeepAliveClientMixin`: **sohbet sekme değişince silinmesin.**
/// `TabBarView` görünmeyen sekmelerin durumunu atıyor; kullanıcı bir kaynak
/// dosyaya bakmak için Etiketler'e geçip döndüğünde bütün konuşma
/// kayboluyordu.
class _ChatTabState extends State<_ChatTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMsg>[];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;
    final state = context.read<AppState>();
    if (!await ensureAiKey(context) || !mounted) return;
    setState(() {
      _messages.add(_ChatMsg(true, question));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final answer = await AiAsk.ask(
        question: question,
        gemini: state.gemini,
        scope: state.aiScopeRules,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(answer.empty
            ? _ChatMsg(false, context.t('aih.no_match'))
            : _ChatMsg(false, answer.text, sources: answer.sources));
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(false, e.message, error: true)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMsg(false, userErrorText(e), error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  /// Bir AI cevabının sorusu (kaynağı olan cevaplarda): akıllı klasöre
  /// kaydedilecek sorgu.
  String? _questionFor(int i) {
    final m = _messages[i];
    if (m.fromUser || m.error || m.sources.isEmpty || i == 0) return null;
    final q = _messages[i - 1];
    return q.fromUser ? q.text : null;
  }

  /// **Akıllı klasör olarak kaydet** (2026-10-18): soru kalıcı bir klasöre
  /// döner; yeni analiz edilen eşleşen dosyalar kendiliğinden eklenir.
  Future<void> _saveSmart(String question) async {
    final folder = await SmartFolders.instance.add(question);
    if (!mounted) return;
    showSnack(
      context,
      context.t('smart.saved', {'name': folder.name}),
      action: SnackBarAction(
        label: context.t('common.open'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SmartFolderScreen(folderId: folder.id))),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      Motion.scrollTo(context, _scroll, _scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final faint = Paper.faint(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _chatEmpty(context)
              : ListView.builder(
                  controller: _scroll,
                  padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) => i == _messages.length
                      ? const _TypingBubble()
                      : _Bubble(
                          message: _messages[i],
                          onSaveSmart: _questionFor(i) == null
                              ? null
                              : () => _saveSmart(_questionFor(i)!),
                        ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.sm),
            child: Row(
              children: [
                // Konuşmayı temizle — yalnız mesaj varken.
                if (_messages.isNotEmpty)
                  IconButton(
                    tooltip: context.t('aih.chat_clear'),
                    icon: const Icon(AppIcons.deleteSweep),
                    onPressed: _busy ? null : () => setState(_messages.clear),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.t('aih.chat_hint'),
                      hintStyle: context.type.compact.copyWith(color: faint),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: Gap.md, vertical: Gap.sm + 2),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                IconButton.filled(
                  tooltip: context.t('common.send'),
                  onPressed: _busy ? null : _send,
                  icon: const Icon(AppIcons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Boş sohbet: ne sorulabileceğini gösteren **örnek soru çipleri** (dokununca
  /// gönderilir). Henüz analiz yoksa sohbet hiçbir şey bulamaz — bunu baştan
  /// söyler ve Analiz sekmesine götürür.
  Widget _chatEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    final noIndex = AiIndex.count == 0;
    return ListView(
      padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
      children: [
        const SizedBox(height: Gap.lg),
        Icon(AppIcons.forum, size: 48, color: faint),
        const SizedBox(height: Gap.md),
        Text(context.t('aih.chat_empty'),
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(
          context.t(noIndex ? 'aih.chat_need_analysis' : 'aih.chat_try'),
          textAlign: TextAlign.center,
          style: context.type.small.copyWith(color: faint),
        ),
        const SizedBox(height: Gap.md),
        if (noIndex)
          Center(
            child: FilledButton.tonalIcon(
              icon: const Icon(AppIcons.ai),
              label: Text(context.t('aih.tab_analysis')),
              onPressed: widget.onOpenAnalysis,
            ),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final key in const [
                'aih.ex1',
                'aih.ex2',
                'aih.ex3',
                'aih.ex4'
              ])
                ActionChip(
                  avatar: const Icon(AppIcons.chatBubbleOutline, size: 16),
                  label: Text(context.t(key)),
                  onPressed: _busy ? null : () => _send(context.t(key)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Cevap beklenirken karşı tarafın balonu: "yazıyor…" göstergesi. Eskiden
/// yalnız giriş kutusunun üstünde ince bir çizgi vardı; göz orada değildi.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm + 2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
            const SizedBox(width: Gap.sm),
            Text(context.t('aih.thinking'),
                style: context.type.compact.copyWith(color: Paper.faint(context))),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMsg message;

  /// Cevabın sorusunu akıllı klasöre kaydeder (yalnız kaynaklı cevaplarda).
  final VoidCallback? onSaveSmart;
  const _Bubble({required this.message, this.onSaveSmart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.all(Gap.md),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: message.error
              ? scheme.errorContainer
              : (message.fromUser
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest),
          // Konuşan tarafın köşesi sivri: kimin söylediği renkten önce
          // biçimden okunuyor.
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(message.fromUser ? 16 : 4),
            bottomEnd: Radius.circular(message.fromUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.error)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Icon(AppIcons.error,
                    size: 18, color: scheme.onErrorContainer),
              ),
            SelectableText(
              message.text,
              style: message.error
                  ? TextStyle(color: scheme.onErrorContainer)
                  : null,
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                context.t('aih.sources'),
                style: context.type.caption.copyWith(color: Paper.faint(context)),
              ),
              const SizedBox(height: Gap.xs),
              // **Önizlemeli kaynaklar** (2026-10-18, kullanıcı ekran
              // görüntüsüyle: *"fatura diye AI'ya sordum, sadece ad verdi;
              // direkt görüntüler önizleme şeklinde olmalı — PDF, video
              // hepsi öyle"*). Eskiden yalnız adı yazan çipler vardı; on
              // faturanın hangisi olduğu ancak açınca anlaşılıyordu. Şimdi
              // her kaynak bir kart: PDF'in kapak sayfası, fotoğrafın
              // kendisi, videonun karesi, APK'nın simgesi (gezgindeki aynı
              // küçük resim hattı — `FmEntryIcon`), altında adı.
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.sources.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
                  itemBuilder: (context, i) =>
                      AiPreviewCard(record: message.sources[i]),
                ),
              ),
              if (onSaveSmart != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero),
                    onPressed: onSaveSmart,
                    icon: const Icon(AppIcons.newFolder,
                        size: 18),
                    label: Text(context.t('smart.save')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
