import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/screen_awake.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../services/audiobook/audiobook_maker.dart';
import '../../services/audiobook/doc_chapters.dart';
import '../../services/voice/neural_engine.dart';
import '../../services/voice/neural_voices.dart';
import '../fm/media_player_screen.dart';
import 'voices_screen.dart';

/// Desteklenen kaynak uzantıları.
const audiobookExtensions = {'.pdf', '.docx', '.pptx', '.txt', '.md', '.markdown'};

bool canMakeAudiobook(String path) =>
    audiobookExtensions.contains(p.extension(path).toLowerCase());

/// **Sesli kitap oluştur** (2026-10-22): belge → başlıklı bölüm dosyaları.
///
/// Ekran açık kaldığı sürece üretir (ekran kilidi tutulur): yapay sinir ağı
/// sesleri bu ekranın içindeki görünmez WebView'da çalışıyor. Yarıda
/// bırakılırsa biten bölümler kalır; yeniden açınca kaldığı yerden sürer.
class AudiobookScreen extends StatefulWidget {
  final String path;

  /// Testler bölümleri doğrudan verir (dosya çözümlemesi yok).
  final List<AudioChapter>? chaptersForTest;

  const AudiobookScreen({super.key, required this.path, this.chaptersForTest});

  @override
  State<AudiobookScreen> createState() => _AudiobookScreenState();
}

class _AudiobookScreenState extends State<AudiobookScreen> {
  List<AudioChapter>? _chapters;
  Set<int> _picked = {};
  String? _error;
  AudiobookVoice _voice = AudiobookVoice.system;
  double _speed = 1.0;
  NeuralVoiceEngine? _engine;
  bool _running = false;
  bool _cancel = false;
  AudiobookProgress? _progress;
  String? _loadingVoice;
  List<String> _done = const [];

  /// Üretilen bölümlerin belgedeki numaraları (ilerleme satırı için).
  List<int> _numbers = const [];

  String get _docName => p.basenameWithoutExtension(widget.path);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel = true;
    unawaited(_engine?.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chapters =
          widget.chaptersForTest ?? await DocChapters.load(widget.path);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _picked = {for (var i = 0; i < chapters.length; i++) i};
      });
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  Future<void> _start() async {
    final chapters = _chapters;
    if (chapters == null || _picked.isEmpty) return;
    final numbers = [
      for (var i = 0; i < chapters.length; i++)
        if (_picked.contains(i)) i,
    ];
    final chosen = [for (final i in numbers) chapters[i]];
    _numbers = numbers;
    setState(() {
      _running = true;
      _cancel = false;
      _progress = null;
    });
    final release = ScreenAwake.request();
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final neural = _voice.neural;
      if (neural != null && _engine == null) {
        final engine = await NeuralVoiceEngine.start();
        engine.onLoading = (v, loaded, total) {
          if (mounted) {
            setState(() => _loadingVoice = total > 0
                ? '${v.label} · %${(loaded * 100 / total).round()}'
                : v.label);
          }
        };
        setState(() => _engine = engine);
      }
      if (neural != null) {
        setState(() => _loadingVoice = neural.label);
        await _engine!.prepare(neural);
        if (mounted) setState(() => _loadingVoice = null);
      }
      final maker =
          AudiobookMaker(voice: _voice, engine: _engine, speed: _speed);
      final out = await maker.make(
        docName: _docName,
        chapters: chosen,
        numbers: numbers,
        isCancelled: () => _cancel,
        onProgress: (pr) {
          if (mounted) setState(() => _progress = pr);
        },
      );
      if (!mounted) return;
      setState(() => _done = out);
      showSnackOn(
          messenger,
          strings.t(_cancel ? 'ab.stopped' : 'ab.done', {
            'n': out.length,
            'folder': p.basename(AudiobookMaker.folderFor(_docName, _voice)),
          }));
    } catch (e) {
      showSnackOn(messenger,
          strings.t('ab.failed', {'error': userErrorText(e)}));
    } finally {
      release();
      if (mounted) {
        setState(() {
          _running = false;
          _loadingVoice = null;
        });
      }
    }
  }

  void _listen() {
    final files = _done;
    if (files.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaPlayerScreen(path: files.first, playlist: files),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _chapters;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _cancel = true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('ab.title')),
          bottom: _running
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: _progress?.overall),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (_engine != null) NeuralVoiceHost(engine: _engine!),
            Positioned.fill(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : chapters == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.all(Gap.md),
                          children: [
                            Text(_docName, style: theme.textTheme.titleLarge),
                            const SizedBox(height: Gap.xs),
                            Text(context.t('ab.intro'),
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: Gap.md),
                            Text(context.t('ab.voice'),
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: Gap.xs),
                            _systemVoiceCard(context),
                            ListenableBuilder(
                              listenable: NeuralVoiceStore.instance,
                              builder: (context, _) => Column(children: [
                                for (final v in NeuralVoice.values)
                                  VoiceCard(
                                    voice: v,
                                    selected: _voice.neural == v,
                                    onSelect: _running
                                        ? null
                                        : () => setState(() => _voice =
                                            AudiobookVoice.values.firstWhere(
                                                (a) => a.neural == v)),
                                  ),
                              ]),
                            ),
                            const SizedBox(height: Gap.sm),
                            Row(children: [
                              Text(context.t('ab.speed')),
                              Expanded(
                                child: Slider(
                                  value: _speed,
                                  min: 0.7,
                                  max: 1.4,
                                  divisions: 7,
                                  label: '${_speed.toStringAsFixed(1)}×',
                                  onChanged: _running
                                      ? null
                                      : (v) => setState(() => _speed = v),
                                ),
                              ),
                            ]),
                            const Divider(),
                            Text(
                                context.t('ab.chapters',
                                    {'n': chapters.length}),
                                style: theme.textTheme.titleSmall),
                            for (var i = 0; i < chapters.length; i++)
                              _chapterTile(context, i, chapters[i]),
                            const SizedBox(height: 96),
                          ],
                        ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: _running
                ? OutlinedButton.icon(
                    onPressed: () => setState(() => _cancel = true),
                    icon: const Icon(AppIcons.close),
                    label: Text(_loadingVoice != null
                        ? context.t('ab.preparing', {'voice': _loadingVoice})
                        : context.t('ab.running', {
                            'n': (_progress?.chapter ?? 0) + 1,
                            'total': _progress?.chapters ?? _picked.length,
                          })),
                  )
                : Row(children: [
                    if (_done.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('ab-listen'),
                          onPressed: _listen,
                          icon: const Icon(AppIcons.audiobook),
                          label: Text(context.t('ab.listen')),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('ab-start'),
                        onPressed: chapters == null ||
                                _picked.isEmpty ||
                                (_voice.neural != null &&
                                    !NeuralVoiceStore.instance
                                        .isInstalled(_voice.neural!))
                            ? null
                            : _start,
                        icon: const Icon(AppIcons.audiobook),
                        label: Text(context.t('ab.start')),
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _systemVoiceCard(BuildContext context) {
    final selected = _voice == AudiobookVoice.system;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: ListTile(
        key: const ValueKey('ab-voice-system'),
        leading: Icon(selected ? AppIcons.checkCircle : AppIcons.voice,
            color: scheme.primary),
        title: Text(context.t('ab.voice_system')),
        subtitle: Text(context.t('ab.voice_system_sub')),
        onTap: _running
            ? null
            : () => setState(() => _voice = AudiobookVoice.system),
      ),
    );
  }

  Widget _chapterTile(BuildContext context, int i, AudioChapter c) {
    final pr = _progress;
    final folder = AudiobookMaker.folderFor(_docName, _voice);
    final ready = AudiobookMaker.existing(folder, i, c) != null;
    final minutes = (c.length / 900).ceil(); // ~150 kelime/dk ≈ 900 krk/dk
    return CheckboxListTile(
      value: _picked.contains(i),
      onChanged: _running
          ? null
          : (v) => setState(() => v == true ? _picked.add(i) : _picked.remove(i)),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(ready
          ? context.t('ab.chapter_ready')
          : context.t('ab.chapter_len', {'min': minutes})),
      secondary: _running &&
              pr != null &&
              pr.chapter < _numbers.length &&
              _numbers[pr.chapter] == i
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(value: pr.fraction))
          : Icon(ready ? AppIcons.checkCircle : AppIcons.audiobook),
    );
  }
}
