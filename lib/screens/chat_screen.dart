import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../core/markdown.dart';
import '../core/theme.dart';
import '../services/conversion_service.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/markdown_export.dart';
import '../widgets/markdown_text.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  /// Açık dosyanın metni (opsiyonel bağlam).
  final String? fileContext;
  final String? fileName;
  const ChatScreen({super.key, this.fileContext, this.fileName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatTurn> _turns = [];
  bool _busy = false;

  /// Bağlam artık DEĞİŞTİRİLEBİLİR: eskiden yalnız görüntüleyiciden gelebilen
  /// dosya bağlamı, composer'daki (+) ile sohbetin içinden de seçilebiliyor.
  String? _ctxText;
  String? _ctxName;

  @override
  void initState() {
    super.initState();
    _ctxText = widget.fileContext;
    _ctxName = widget.fileName;
  }

  /// (+) — bağlam dosyası seç/değiştir. Metni uygulamanın kendi yükleyicisi
  /// çıkarır (PDF metin katmanı, Word/Excel içeriği…), ayrı bir yol yazılmadı.
  Future<void> _pickContext() async {
    final s = AppStrings.of(context);
    try {
      final path = await FileService().pickFilePath();
      if (path == null) return;
      final doc = await FileService().load(path);
      if (!mounted) return;
      setState(() {
        _ctxText = doc.plainText;
        _ctxName = doc.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('home.open_error', {'error': e}))),
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Dosya açıkken hazır komut çipleri (Özetle vb.) buradan gönderilir.
  void _quickAsk(String prompt) {
    if (_busy) return;
    _input.text = prompt;
    _send();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final appState = context.read<AppState>();

    if (!appState.hasApiKey) {
      _promptForKey();
      return;
    }

    setState(() {
      _turns.add(ChatTurn(fromUser: true, text: text));
      _busy = true;
      _input.clear();
    });
    _scrollToEnd();

    final service =
        GeminiService(apiKey: appState.apiKey, model: appState.model);
    try {
      final reply = await service.chat(
        history: _turns,
        fileContext: _ctxText,
        memory: appState.memory,
      );
      setState(() => _turns.add(ChatTurn(fromUser: false, text: reply)));
    } catch (e) {
      setState(() => _turns.add(ChatTurn(fromUser: false, text: '⚠️ $e')));
    } finally {
      setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _promptForKey() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.t('chat.key_required')),
        content: Text(context.t('chat.key_required_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsScreen()));
            },
            child: Text(context.t('common.settings')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToMemory(String text) async {
    await context.read<AppState>().addMemory(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('chat.saved_to_memory'))),
      );
    }
  }

  /// Üretilen baytları geçici dosyaya yazıp paylaşım sayfasını açar.
  Future<void> _shareBytes(String fileName, List<int> bytes) async {
    final f = File('${Directory.systemTemp.path}/$fileName');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: fileName);
  }

  /// AI yanıtını seçilen Office biçiminde dışa aktarır.
  Future<void> _export(String text, _ExportKind kind) async {
    // Başlıklar await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    try {
      switch (kind) {
        case _ExportKind.word:
          await _shareBytes(
              'AI_Yaniti.docx',
              MarkdownExport.toDocx(text, title: str.t('chat.answer_title')));
          break;
        case _ExportKind.excel:
          await _shareBytes('AI_Yaniti.xlsx', MarkdownExport.toXlsx(text));
          break;
        case _ExportKind.csv:
          // BOM + UTF-8: Excel Türkçe karakterleri doğru açsın.
          await _shareBytes(
              'AI_Yaniti.csv', utf8.encode('﻿${MarkdownExport.toCsv(text)}'));
          break;
        case _ExportKind.slides:
          final bytes = await ConversionService()
              .textToSlidesPdf(str.t('chat.deck_title'), stripMarkdown(text));
          await _shareBytes('AI_Sunumu.pdf', bytes);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(str.t('chat.export_failed', {'error': e}))),
        );
      }
    }
  }

  /// AI yanıtını düz metin olarak panoya kopyalar.
  Future<void> _copyPlain(String text) async {
    await Clipboard.setData(ClipboardData(text: stripMarkdown(text)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('chat.copied'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContext = _ctxText?.trim().isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('chat.title')),
        // **Rozet şeridi**: hangi modelle konuşulduğunu görmek için Ayarlar'a
        // gitmek gerekiyordu; bağlam dosyası da yalnız başlıkta bir satırdı.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: Row(
              children: [
                _badge(context, Icons.smart_toy_outlined,
                    context.watch<AppState>().model),
                if (_ctxName != null) ...[
                  const SizedBox(width: Gap.sm),
                  Flexible(
                    child: _badge(
                      context,
                      Icons.attach_file,
                      context.t('chat.context_badge', {'f': _ctxName}),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty
                ? _ChatHint(hasContext: hasContext)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _turns.length,
                    itemBuilder: (_, i) => _Bubble(
                      turn: _turns[i],
                      onSaveMemory: _saveToMemory,
                      onExport: _export,
                      onCopy: _copyPlain,
                    ),
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          // Hızlı komutlar KALICI (eskiden yalnız sohbet boşken ve yalnız
          // dosya bağlamı varken görünüyordu) — ikinci soruda da lazım.
          _QuickBar(onQuick: _quickAsk, enabled: !_busy),
          _Composer(
            controller: _input,
            onSend: _send,
            enabled: !_busy,
            onAttach: _pickContext,
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Paper.faint(context)),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Paper.faint(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Composer'ın üstündeki kalıcı hızlı komut şeridi.
class _QuickBar extends StatelessWidget {
  final void Function(String) onQuick;
  final bool enabled;
  const _QuickBar({required this.onQuick, required this.enabled});

  /// Etiket ve **AI'ya gidecek istem** aynı dilden olmalı, yoksa Arapça
  /// arayüzde Türkçe istem giderdi.
  static const quick = <(String, String)>[
    ('chat.quick_summarize', 'chat.quick_summarize_prompt'),
    ('chat.quick_points', 'chat.quick_points_prompt'),
    ('chat.quick_simple', 'chat.quick_simple_prompt'),
    ('chat.quick_slides', 'chat.quick_slides_prompt'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final q in quick)
              Padding(
                padding: const EdgeInsets.only(right: Gap.sm),
                child: ActionChip(
                  label: Text(context.t(q.$1)),
                  onPressed: enabled ? () => onQuick(context.t(q.$2)) : null,
                ),
              ),
          ],
        ),
      );
}

class _ChatHint extends StatelessWidget {
  final bool hasContext;
  const _ChatHint({this.hasContext = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              context
                  .t(hasContext ? 'chat.empty_file' : 'chat.empty_general'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatTurn turn;
  final Future<void> Function(String) onSaveMemory;
  final Future<void> Function(String, _ExportKind) onExport;
  final Future<void> Function(String) onCopy;
  const _Bubble({
    required this.turn,
    required this.onSaveMemory,
    required this.onExport,
    required this.onCopy,
  });

  static final _actionStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    minimumSize: const Size(0, 30),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = turn.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Gap.xs),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color:
              isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          // Konuşan tarafa bakan köşe sivri: kimin konuştuğu renkten bağımsız
          // da okunur (renk tek gösterge olmasın).
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.card),
            topRight: const Radius.circular(Radii.card),
            bottomLeft: Radius.circular(isUser ? Radii.card : Gap.xs),
            bottomRight: Radius.circular(isUser ? Gap.xs : Radii.card),
          ),
          border: isUser
              ? null
              : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kullanıcı mesajı düz; AI yanıtı Markdown biçimli çizilir
            // (ham `**`/`#`/`-` işaretleri ekranda kalmaz).
            if (isUser)
              SelectableText(turn.text)
            else
              MarkdownText(
                turn.text,
                baseStyle: DefaultTextStyle.of(context).style,
              ),
            if (!isUser) ...[
              // Eylemler metinden cetvelle ayrılır — yanıtın kendisiyle
              // düğmeler aynı akışta okunuyordu.
              const SizedBox(height: Gap.sm),
              Divider(height: 1, color: scheme.outlineVariant),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Office biçimlerine dışa aktarım tek menüde toplandı.
                    PopupMenuButton<_ExportKind>(
                      tooltip: context.t('chat.export'),
                      onSelected: (k) => onExport(turn.text, k),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _ExportKind.word,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.description_outlined),
                            title: Text('Word (.docx)'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ExportKind.excel,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.table_chart_outlined),
                            title: Text('Excel (.xlsx)'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ExportKind.csv,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.grid_on_outlined),
                            title: Text('CSV (.csv)'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ExportKind.slides,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.slideshow_outlined),
                            title: Text('Sunum (PDF)'),
                          ),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.ios_share, size: 16),
                            SizedBox(width: 4),
                            Text('Aktar'),
                            Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      style: _actionStyle,
                      onPressed: () => onCopy(turn.text),
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: Text(context.t('common.copy')),
                    ),
                    TextButton.icon(
                      style: _actionStyle,
                      // Hafızaya düz metin yaz (işaretsiz).
                      onPressed: () => onSaveMemory(stripMarkdown(turn.text)),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: Text(context.t('chat.save_to_memory')),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final VoidCallback onAttach;
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: context.t('chat.pick_context'),
              onPressed: enabled ? onAttach : null,
              icon: const Icon(Icons.add),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: context.t('chat.ask_hint'),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled ? onSend : null,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI yanıtının dışa aktarılabileceği Office biçimleri.
enum _ExportKind { word, excel, csv, slides }
