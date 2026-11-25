import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../services/audiobook/audiobook_job.dart';
import '../../services/audiobook/audiobook_maker.dart';
import '../../services/audiobook/doc_chapters.dart';
import '../../services/ai_pool.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice/neural_voices.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/pro_gate.dart';
import '../fm/media_player_screen.dart';
import 'voices_screen.dart';

/// Desteklenen kaynak uzantıları.
const audiobookExtensions = {
  '.pdf',
  '.docx',
  '.pptx',
  '.txt',
  '.md',
  '.markdown'
};

bool canMakeAudiobook(String path) =>
    audiobookExtensions.contains(p.extension(path).toLowerCase());

/// **Sesli kitap oluştur** (2026-10-22): belge → başlıklı bölüm dosyaları.
///
/// 2026-10-23: üretim artık ekranın değil [AudiobookJob]un işi — ekrandan
/// çıkılabilir, uygulama alta alınabilir; ilerleme şeritte ve bildirimde
/// görünür, bildirime dokununca bu ekran ilerlemesiyle açılır. Yarıda
/// bırakılırsa biten bölümler kalır; yeniden başlatınca kaldığı yerden sürer.
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
  late AudiobookVoice _voice = _preferredVoice();
  late TtsPrefs _ttsPrefs = _initialTtsPrefs();
  double _speed = 1.0;

  List<String> _engines = const [];
  List<TtsVoiceInfo> _systemVoices = const [];
  bool _stripPageNumbers = true;
  bool _stripSymbols = true;
  bool _expandAbbr = true;
  bool _aiTidy = false;
  TtsService? _previewTts;

  /// İzlenen iş (süren ya da bu belgenin son biten işi).
  AudiobookJob? _job;
  bool _reported = false;

  String get _docName => p.basenameWithoutExtension(widget.path);

  bool get _running => _job?.running ?? false;
  AudiobookProgress? get _progress => _job?.progress;
  List<int> get _numbers => _job?.numbers ?? const [];

  SpeechCleanOptions get _cleanOptions => SpeechCleanOptions(
        stripPageNumbers: _stripPageNumbers,
        stripParentheticals: _stripSymbols,
        stripSymbolsAndUrls: _stripSymbols,
        expandAbbreviations: _expandAbbr,
      );

  TtsPrefs _initialTtsPrefs() {
    try {
      return context.read<AppState>().ttsPrefs;
    } catch (_) {
      return TtsPrefs.defaults;
    }
  }

  /// Okuma ayarında bir yapay zekâ sesi seçiliyse (ve kuruluysa) o.
  AudiobookVoice _preferredVoice() {
    try {
      final neural =
          NeuralVoiceId.parse(context.read<AppState>().ttsPrefs.voiceName);
      final ab = neural == null ? null : AudiobookVoice.of(neural);
      if (neural != null &&
          ab != null &&
          NeuralVoiceStore.instance.isInstalled(neural)) {
        return ab;
      }
    } catch (_) {
      // Testte AppState yok: cihaz sesi.
    }
    return AudiobookVoice.system;
  }

  @override
  void initState() {
    super.initState();
    _attach(AudiobookJob.of(widget.path));
    _load();
    _loadVoiceOptions();
  }

  @override
  void dispose() {
    _detach();
    _previewTts?.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceOptions() async {
    if (!Edition.current.has(Feature.audiobook)) return;
    try {
      final lang = AppStrings.of(context).language.code;
      final engines = await TtsService.engines();
      var voices = await TtsService.voices(
        languagePrefix: lang,
        engineName: _ttsPrefs.engineName,
      );
      if (voices.isEmpty) {
        voices = await TtsService.voices(engineName: _ttsPrefs.engineName);
      }
      if (!mounted) return;
      setState(() {
        _engines = engines;
        _systemVoices = voices;
      });
    } catch (_) {
      // Bilinçli: testlerde platform kanalı olmayabilir.
    }
  }

  Future<void> _saveTtsPrefs(TtsPrefs next) async {
    setState(() => _ttsPrefs = next);
    try {
      await context.read<AppState>().setTtsPrefs(next);
    } catch (_) {
      // Testte AppState yok.
    }
  }

  Future<void> _selectEngine(String engine) async {
    final next = _ttsPrefs.copyWith(
      engineName: engine,
      voiceName: '',
      voiceLocale: '',
    );
    await _saveTtsPrefs(next);
    try {
      final lang = mounted ? AppStrings.of(context).language.code : 'tr';
      var voices = await TtsService.voices(
        languagePrefix: lang,
        engineName: engine,
      );
      if (voices.isEmpty) {
        voices = await TtsService.voices(engineName: engine);
      }
      if (mounted) setState(() => _systemVoices = voices);
    } catch (_) {
      // Testte platform kanalı yok.
    }
  }

  Future<void> _selectSystemVoice(String voiceName) async {
    final match = _systemVoices.where((v) => v.name == voiceName).firstOrNull;
    await _saveTtsPrefs(_ttsPrefs.copyWith(
      voiceName: match?.name ?? '',
      voiceLocale: match?.locale ?? '',
    ));
  }

  Future<void> _previewVoice() async {
    final neural = _voice.neural;
    final sample = cleanForSpeech(
      AppStrings.of(context).t('ab.preview_sample'),
      options: _cleanOptions,
    );
    final tts = _previewTts ??= TtsService();
    tts.prefs = neural != null
        ? _ttsPrefs.copyWith(
            voiceName: NeuralVoiceId.of(neural),
            voiceLocale: neural.locale,
            rate: _speed,
          )
        : _ttsPrefs.copyWith(rate: _speed);
    await tts.preview(sample);
  }

  Future<void> _toggleAiTidy(bool value) async {
    if (!value) {
      setState(() => _aiTidy = false);
      return;
    }
    if (!await ProGate.check(context, Feature.ai)) return;
    if (!mounted) return;
    if (!await ensureAiKey(context)) return;
    if (mounted) setState(() => _aiTidy = true);
  }

  void _attach(AudiobookJob? job) {
    _detach();
    _job = job;
    if (job == null) return;
    _reported = !job.running; // eski biten işin sonucu tekrar söylenmez
    _voice = job.voice;
    _speed = job.speed;
    if (job.running) _picked = job.numbers.toSet();
    job.watched = true;
    job.addListener(_onJob);
  }

  void _detach() {
    final job = _job;
    if (job == null) return;
    job.watched = false;
    job.removeListener(_onJob);
  }

  void _onJob() {
    if (!mounted) return;
    setState(() {});
    final job = _job;
    if (job == null || job.running || _reported) return;
    _reported = true;
    final strings = AppStrings.of(context);
    final folder = p.basename(AudiobookMaker.folderFor(_docName, job.voice));
    showSnack(
        context,
        job.error != null
            ? strings.t('ab.failed', {'error': job.error})
            : strings.t(job.cancelled ? 'ab.stopped' : 'ab.done',
                {'n': job.outputs.length, 'folder': folder}));
  }

  Future<void> _load() async {
    try {
      final chapters =
          widget.chaptersForTest ?? await DocChapters.load(widget.path);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        if (!_running) {
          _picked = {for (var i = 0; i < chapters.length; i++) i};
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  Future<void> _start() async {
    if (!await ProGate.check(context, Feature.audiobook)) return;
    if (!mounted) return;
    final chapters = _chapters;
    if (chapters == null || _picked.isEmpty) return;

    GeminiService? aiGemini;
    if (_aiTidy) {
      if (!await ProGate.check(context, Feature.ai)) return;
      if (!mounted) return;
      if (!await ensureAiKey(context)) return;
      if (!mounted) return;
      try {
        final creds = context.read<AppState>().aiCredentials;
        if (creds.keys.isNotEmpty) {
          // Havuz üzerinden (2026-11-25 denetimi): ham `GeminiService`
          // onay/gizli kasa kapısını ve kota soğumasını atlıyordu; kotası
          // dolan anahtarla her bölüm yeniden (boşuna) istek atılıyordu.
          aiGemini = PooledGemini(creds);
        }
      } catch (_) {
        // Testte AppState yok.
      }
    }

    final numbers = [
      for (var i = 0; i < chapters.length; i++)
        if (_picked.contains(i)) i,
    ];
    final job = AudiobookJob.start(
      path: widget.path,
      chapters: chapters,
      numbers: numbers,
      voice: _voice,
      speed: _speed,
      ttsPrefs: _ttsPrefs,
      cleanOptions: _cleanOptions,
      aiTidy: _aiTidy && aiGemini != null,
      aiGemini: aiGemini,
    );
    setState(() => _attach(job));
    _reported = false;
  }

  List<String> get _done {
    final job = _job;
    if (job != null && !job.running && job.outputs.isNotEmpty) {
      return job.outputs;
    }
    // İş yoksa da (uygulama yeniden açıldı) hazır bölümler dinlenebilir.
    final chapters = _chapters;
    if (chapters == null || _running) return const [];
    final folder = AudiobookMaker.folderFor(_docName, _voice);
    final out = <String>[];
    for (var i = 0; i < chapters.length; i++) {
      final f = AudiobookMaker.existing(folder, i, chapters[i]);
      if (f != null) out.add(f);
    }
    return out;
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
    if (!Edition.current.has(Feature.audiobook)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t('ab.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.pro,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: Gap.md),
                Text(
                  context.t('ab.pro_locked_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  context.t('ab.pro_locked_sub'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.lg),
                FilledButton.icon(
                  key: const ValueKey('ab-pro-unlock'),
                  onPressed: () => ProGate.check(context, Feature.audiobook),
                  icon: const Icon(AppIcons.pro),
                  label: Text(context.t('ab.pro_unlock')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final chapters = _chapters;
    final theme = Theme.of(context);
    final done = _done;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ab.title')),
        bottom: _running
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _progress?.overall),
              )
            : null,
      ),
      body: _error != null
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
                    if (_running) ...[
                      const SizedBox(height: Gap.sm),
                      Card(
                        color: theme.colorScheme.primaryContainer,
                        child: ListTile(
                          leading: const Icon(AppIcons.audiobook),
                          title: Text(context.t('ab.background')),
                          subtitle: Text(context.t('ab.background_sub')),
                        ),
                      ),
                    ],
                    const SizedBox(height: Gap.md),
                    Text(context.t('ab.voice'),
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: Gap.xs),
                    _systemVoiceCard(context),
                    if (_voice == AudiobookVoice.system)
                      _systemEnginePicker(context),
                    ListenableBuilder(
                      listenable: NeuralVoiceStore.instance,
                      builder: (context, _) => Column(children: [
                        for (final v in NeuralVoice.usable)
                          if (AudiobookVoice.of(v) != null)
                            VoiceCard(
                              voice: v,
                              selected: _voice.neural == v,
                              onSelect: _running
                                  ? null
                                  : () => setState(
                                      () => _voice = AudiobookVoice.of(v)!),
                            ),
                      ]),
                    ),
                    const SizedBox(height: Gap.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        key: const ValueKey('ab-preview-voice'),
                        onPressed: _running ? null : _previewVoice,
                        icon: const Icon(AppIcons.volumeUp),
                        label: Text(context.t('ab.preview')),
                      ),
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
                          onChanged: AppHaptics.slider(_speed, _running
                              ? null
                              : (v) => setState(() => _speed = v)),
                        ),
                      ),
                    ]),
                    _cleanupCard(context),
                    const Divider(),
                    Text(context.t('ab.chapters', {'n': chapters.length}),
                        style: theme.textTheme.titleSmall),
                    for (var i = 0; i < chapters.length; i++)
                      _chapterTile(context, i, chapters[i]),
                    const SizedBox(height: 96),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: _running
              ? OutlinedButton.icon(
                  key: const ValueKey('ab-stop'),
                  onPressed: () => _job?.cancel(),
                  icon: const Icon(AppIcons.close),
                  label: Text(_job?.loadingVoice != null
                      ? context.t('ab.preparing', {'voice': _job!.loadingVoice})
                      : context.t('ab.running', {
                          'n': (_progress?.chapter ?? 0) + 1,
                          'total': _progress?.chapters ?? _picked.length,
                        })),
                )
              : Row(children: [
                  if (done.isNotEmpty) ...[
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

  Widget _systemEnginePicker(BuildContext context) {
    final currentEngine =
        _engines.contains(_ttsPrefs.engineName) ? _ttsPrefs.engineName : '';
    final currentVoice = _systemVoices.any((v) => v.name == _ttsPrefs.voiceName)
        ? _ttsPrefs.voiceName
        : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('ab.engine_section'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Gap.sm),
            DropdownButtonFormField<String>(
              key: const ValueKey('ab-engine-dropdown'),
              initialValue: currentEngine,
              decoration: InputDecoration(
                labelText: context.t('ab.engine_label'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(context.t('tts.engine_default')),
                ),
                for (final e in _engines)
                  DropdownMenuItem(
                    value: e,
                    child: Text(TtsService.engineLabel(e),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _running ? null : (v) => v == null ? null : _selectEngine(v),
            ),
            if (_systemVoices.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              DropdownButtonFormField<String>(
                key: const ValueKey('ab-system-voice-dropdown'),
                initialValue: currentVoice,
                decoration: InputDecoration(
                  labelText: context.t('ab.system_voice_label'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(context.t('ab.system_voice_default')),
                  ),
                  for (final v in _systemVoices)
                    DropdownMenuItem(
                      value: v.name,
                      child: Text('${v.label} (${v.locale})',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _running
                    ? null
                    : (v) => v == null ? null : _selectSystemVoice(v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cleanupCard(BuildContext context) {
    final aiLocked = !Edition.current.has(Feature.ai);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: Text(context.t('ab.clean_section'),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            SwitchListTile(
              dense: true,
              title: Text(context.t('ab.clean_pages')),
              value: _stripPageNumbers,
              onChanged: _running
                  ? null
                  : (v) => setState(() => _stripPageNumbers = v),
            ),
            SwitchListTile(
              dense: true,
              title: Text(context.t('ab.clean_symbols')),
              value: _stripSymbols,
              onChanged:
                  _running ? null : (v) => setState(() => _stripSymbols = v),
            ),
            SwitchListTile(
              dense: true,
              title: Text(context.t('ab.clean_abbr')),
              value: _expandAbbr,
              onChanged:
                  _running ? null : (v) => setState(() => _expandAbbr = v),
            ),
            SwitchListTile(
              dense: true,
              title: Row(
                children: [
                  Flexible(child: Text(context.t('ab.ai_tidy'))),
                  if (aiLocked) ...[
                    const SizedBox(width: Gap.xs),
                    const ProBadge(),
                  ],
                ],
              ),
              subtitle: Text(context.t('ab.ai_tidy_sub')),
              value: _aiTidy,
              onChanged: _running ? null : _toggleAiTidy,
            ),
          ],
        ),
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
          : (v) =>
              setState(() => v == true ? _picked.add(i) : _picked.remove(i)),
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
