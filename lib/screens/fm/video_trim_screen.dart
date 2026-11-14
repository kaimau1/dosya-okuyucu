import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/video_edit.dart';
import '../../models/video_trim.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/video_transcode.dart';
import '../../widgets/fm/video_trim_timeline.dart';
import 'pick_file_screen.dart';

/// Bölge seçiminin hangi işe gideceği.
enum _Tool { cut, mute, audio }

/// **Videoyu düzenle** (Ferrari H8 kesme ekranı, 2026-11-14'te genişledi —
/// kullanıcı: *"ara kırpmalar da yapılabilsin istendiği kadar, ses ekleme
/// çıkarma, ara bölgelerde ses ekleme çıkarma yapılabilsin, arayüz de iyi
/// olsun"*).
///
/// Üstte önizleme (silinen bölümleri atlar, sessiz bölgede sesi kısar,
/// eklenen sesi bölgesinde çalar). Altta kare şeridi: dış tutamaçlar baş/son
/// kırpma; düzenlemeler şeritte işaretli (silinen koyu + makas, sessiz bölge
/// altta kırmızı, eklenen ses üstte renkli şerit). Araç sırası: **Bölüm sil ·
/// Sesi kapat · Ses ekle · Tüm ses** — ilk üçü şeritte ayrı renkli bir bölge
/// seçtirir, "Uygula" ile listeye ekler. Her düzenleme listede tek dokunuşla
/// kaldırılır; üst çubukta Geri al. Kaydet işi kuyruğa verir; özgün KORUNUR.
class VideoTrimScreen extends StatefulWidget {
  const VideoTrimScreen({super.key, required this.path, this.durationMs});

  final String path;

  /// Biliniyorsa süre (önizleme açılamasa da tutamaçlar çalışsın).
  final int? durationMs;

  /// Düzenleme ekranını açar; açık oynatıcı varsa çağıran önce duraklatır.
  static Future<void> open(BuildContext context, String path) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VideoTrimScreen(path: path),
      ));

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  VideoPlayerController? _video;
  bool _previewFailed = false;
  int _durationMs = 0;
  VideoEdit _edit = VideoEdit.whole(0);
  final List<VideoEdit> _history = [];
  List<String> _frames = const [];
  Directory? _frameDir;
  int _positionMs = 0;
  double _volume = 1;

  /// **Canlı tarama karesi** (2026-11-14, kullanıcı: *"alt panelde
  /// kaydırınca canlı olarak kare gösterilmeli"*). Kök: oynatıcının
  /// `seekTo`'su KESİN arama yapar (anahtar kareden hedefe kadar çözer);
  /// 720p videoda arama başı yüzlerce ms → önizleme parmağın çok gerisinde
  /// kalıyor, çoğu kare hiç görünmüyordu. Şimdi sürükleme süresince yerelden
  /// önceden çıkarılmış en yakın kare ([_scrubFrames], anında) önizlemenin
  /// üstünde gösterilir; parmak kalkınca katman kalkar, oynatıcı kesin
  /// kareyi gösterir.
  List<({int ms, String path})> _scrubFrames = const [];
  String? _scrubShown;
  bool _scrubbing = false;

  /// Bölge seçimi sürerken: hangi araç, hangi aralık, (ses için) hangi dosya.
  _Tool? _tool;
  TrimRange _sel = const TrimRange(0, 0);
  String? _selAudio;
  int _selAudioMs = 0;

  /// Eklenen seslerin önizleme oynatıcıları (yol → oynatıcı).
  final Map<String, VideoPlayerController> _audio = {};

  @override
  void initState() {
    super.initState();
    final known = widget.durationMs ?? 0;
    if (known > 0) _setDuration(known);
    unawaited(_openPreview());
    unawaited(_loadDuration());
  }

  void _setDuration(int ms) {
    _durationMs = ms;
    _edit = VideoEdit.whole(ms);
  }

  Future<void> _openPreview() async {
    final c = VideoPlayerController.file(File(widget.path));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _previewFailed = true);
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.addListener(_onTick);
    setState(() {
      _video = c;
      final ms = c.value.duration.inMilliseconds;
      if (_durationMs <= 0 && ms > 0) _setDuration(ms);
    });
  }

  /// Süre + kare şeridi yerelden (önizleme açılamasa da).
  Future<void> _loadDuration() async {
    if (_durationMs <= 0) {
      final probe = await VideoTranscoder.probe(widget.path);
      if (!mounted) return;
      if (probe != null && probe.durationMs > 0 && _durationMs <= 0) {
        setState(() => _setDuration(probe.durationMs));
      }
    }
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(p.join(tmp.path, 'video_trim_frames',
          '${widget.path.hashCode.toUnsigned(32)}'));
      _frameDir = dir;
      final frames =
          await VideoTranscoder.frames(widget.path, dir: dir.path, count: 12);
      if (mounted) setState(() => _frames = frames);
      if (mounted) await _loadScrubFrames(dir);
    } catch (_) {
      // Bilinçli: kare şeridi süs; yoksa düz şerit, tutamaçlar yine çalışır.
    }
  }

  /// Tarama kareleri: şeritten sık (60) ve büyük (320 px). Şeritten SONRA
  /// çıkarılır — şerit önce görünsün. Dosya adındaki sıra no'su (`kare_<i>`)
  /// zamanı verir: okunamayan kare atlanırsa liste kısalır, sıra kaymaz.
  static const _scrubCount = 60;

  Future<void> _loadScrubFrames(Directory stripDir) async {
    final paths = await VideoTranscoder.frames(widget.path,
        dir: p.join(stripDir.path, 'tarama'), count: _scrubCount, width: 320);
    if (!mounted || paths.isEmpty || _durationMs <= 0) return;
    final re = RegExp(r'kare_(\d+)\.jpg$');
    final list = <({int ms, String path})>[];
    for (final f in paths) {
      final m = re.firstMatch(f);
      if (m == null) continue;
      final i = int.parse(m.group(1)!);
      // Yerel taraf her dilimin ORTASINI alır: (2i+1)/(2n).
      list.add((
        ms: (_durationMs * (2 * i + 1)) ~/ (2 * _scrubCount),
        path: f,
      ));
    }
    setState(() => _scrubFrames = list);
    // Görüntüleri önceden çöz: ilk taramada boş kare yanıp sönmesin.
    for (final f in list) {
      if (!mounted) return;
      unawaited(precacheImage(FileImage(File(f.path)), context)
          .catchError((Object _) {}));
    }
  }

  String? _nearestScrubFrame(int ms) {
    final list = _scrubFrames;
    if (list.isEmpty) return null;
    var lo = 0, hi = list.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].ms < ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 && (ms - list[lo - 1].ms) < (list[lo].ms - ms)) lo--;
    return list[lo].path;
  }

  void _endScrub() {
    if (!_scrubbing) return;
    setState(() {
      _scrubbing = false;
      _scrubShown = null;
    });
  }

  // ── Önizleme ────────────────────────────────────────────────────────────

  /// Önizleme çıktıyı taklit eder: silinen bölümü atlar, sonda başa sarar,
  /// sessiz bölgede sesi kısar, eklenen sesi bölgesinde çalar.
  void _onTick() {
    final c = _video;
    if (c == null) return;
    final pos = c.value.position.inMilliseconds;
    // Tarama sürerken oynatıcının (geride kalan) konumu oynatma çizgisini
    // parmaktan geri çekmesin.
    if (!_scrubbing && pos != _positionMs && mounted) {
      setState(() => _positionMs = pos);
    }
    if (!c.value.isPlaying) {
      _pauseAudio();
      return;
    }
    final next = _edit.nextKeptFrom(pos);
    if (next == null) {
      unawaited(c.pause());
      _pauseAudio();
      unawaited(c.seekTo(Duration(milliseconds: _edit.keep.startMs)));
      return;
    }
    if (next > pos + 150) {
      unawaited(c.seekTo(Duration(milliseconds: next)));
      return;
    }
    final vol = _edit.originalAudibleAt(pos) ? 1.0 : 0.0;
    if (vol != _volume) {
      _volume = vol;
      unawaited(c.setVolume(vol));
    }
    _syncAudio(pos);
  }

  void _syncAudio(int pos) {
    for (final a in _edit.inserts) {
      final ac = _audio[a.path];
      if (ac == null || !ac.value.isInitialized) continue;
      final inside = pos >= a.at.startMs && pos < a.at.endMs;
      if (!inside) {
        if (ac.value.isPlaying) unawaited(ac.pause());
        continue;
      }
      final want = _edit.toOutput(pos) - _edit.toOutput(a.at.startMs);
      final have = ac.value.position.inMilliseconds;
      if ((want - have).abs() > 400) {
        unawaited(ac.seekTo(Duration(milliseconds: want)));
      }
      if (!ac.value.isPlaying) unawaited(ac.play());
    }
  }

  void _pauseAudio() {
    for (final ac in _audio.values) {
      if (ac.value.isPlaying) unawaited(ac.pause());
    }
  }

  Future<void> _ensureAudioPreview(String path) async {
    if (_audio.containsKey(path)) return;
    final c = VideoPlayerController.file(File(path));
    _audio[path] = c;
    try {
      await c.initialize();
    } catch (_) {
      // Bilinçli: eklenen sesin önizlemesi süs; dışa aktarım yine çalışır.
    }
  }

  void _togglePlay() {
    final c = _video;
    if (c == null) return;
    AppHaptics.selection();
    if (c.value.isPlaying) {
      unawaited(c.pause());
      _pauseAudio();
      return;
    }
    final range = _tool != null ? _sel : _edit.keep;
    final pos = c.value.position.inMilliseconds;
    if (pos < range.startMs || pos >= range.endMs - 100) {
      unawaited(c.seekTo(Duration(milliseconds: range.startMs)));
    }
    unawaited(c.play());
  }

  void _seek(int ms) {
    final c = _video;
    setState(() {
      _positionMs = ms;
      _scrubbing = true;
      _scrubShown = _nearestScrubFrame(ms) ?? _scrubShown;
    });
    if (c == null) return;
    if (c.value.isPlaying) unawaited(c.pause());
    _seekTo(c, ms);
  }

  /// Şeritte tarama saniyede onlarca konum üretir; her biri için `seekTo`
  /// sıraya girerse önizleme parmağın çok gerisinde kalır. Bir arama
  /// sürerken gelenlerden yalnız SONUNCUSU tutulur, arama bitince ona
  /// gidilir — önizleme kod çözücünün yetiştiği hızda kare kare izler ve
  /// parmağın bıraktığı karede durur.
  bool _seekBusy = false;
  int? _seekPending;

  void _seekTo(VideoPlayerController c, int ms) {
    if (_seekBusy) {
      _seekPending = ms;
      return;
    }
    _seekBusy = true;
    unawaited(c.seekTo(Duration(milliseconds: ms)).whenComplete(() {
      _seekBusy = false;
      final next = _seekPending;
      _seekPending = null;
      if (next != null && mounted && identical(c, _video)) _seekTo(c, next);
    }));
  }

  // ── Düzenleme ───────────────────────────────────────────────────────────

  void _apply(VideoEdit next) {
    if (identical(next, _edit)) return;
    setState(() {
      _history.add(_edit);
      _edit = next;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    AppHaptics.selection();
    setState(() => _edit = _history.removeLast());
  }

  /// Bölge seçimini başlatır: oynatma yerinin çevresinde (videonun ~%15'i,
  /// en az 1, en çok 10 sn); ses eklerken sesin süresi kadar.
  Future<void> _startTool(_Tool tool) async {
    if (_durationMs <= 0) return;
    String? audio;
    var audioMs = 0;
    if (tool == _Tool.audio) {
      final picked = await AppFilePicker.pickFiles(type: FileType.audio);
      final files = picked?.files ?? const <PickedFile>[];
      final path = files.isEmpty ? null : files.first.path;
      if (path == null || !mounted) return;
      audio = path;
      audioMs = (await VideoTranscoder.probe(path))?.durationMs ?? 0;
      if (!mounted) return;
      unawaited(_ensureAudioPreview(path));
    }
    unawaited(_video?.pause());
    final keep = _edit.keep;
    var start = _positionMs.clamp(keep.startMs, keep.endMs);
    var len = tool == _Tool.audio && audioMs > 0
        ? audioMs
        : (_durationMs * 0.15).round().clamp(1000, 10000);
    if (start + len > keep.endMs) start = keep.endMs - len;
    if (start < keep.startMs) start = keep.startMs;
    if (start + len > keep.endMs) len = keep.endMs - start;
    AppHaptics.selection();
    setState(() {
      _tool = tool;
      _sel = TrimRange(start, start + len);
      _selAudio = audio;
      _selAudioMs = audioMs;
    });
  }

  void _cancelTool() => setState(() {
        _tool = null;
        _selAudio = null;
      });

  void _commitTool() {
    final tool = _tool;
    if (tool == null) return;
    final VideoEdit next;
    switch (tool) {
      case _Tool.cut:
        next = _edit.addCut(_sel);
        if (identical(next, _edit)) {
          showSnack(context, context.t('ved.cut_too_much'));
          return;
        }
      case _Tool.mute:
        next = _edit.addMute(_sel);
      case _Tool.audio:
        final path = _selAudio;
        if (path == null) return;
        next = _edit.addInsert(
            AudioInsert(path: path, at: _sel, audioMs: _selAudioMs));
        if (identical(next, _edit)) {
          showSnack(context, context.t('ved.audio_overlap'));
          return;
        }
    }
    AppHaptics.done();
    _apply(next);
    _cancelTool();
  }

  bool _frameBusy = false;

  Future<void> _saveFrame() async {
    if (_frameBusy) return;
    _frameBusy = true;
    unawaited(_video?.pause());
    _pauseAudio();
    AppHaptics.selection();
    final out = await VideoTranscoder.saveFrame(widget.path, _positionMs,
        rotationDegrees: _edit.rotationDegrees);
    _frameBusy = false;
    if (!mounted) return;
    if (out == null) {
      showSnack(context, context.t('ved.frame_failed'));
      return;
    }
    FsEvents.changed([out]);
    AppHaptics.done();
    showSnack(context, context.t('ved.frame_saved', {'name': p.basename(out)}));
  }

  bool get _canSave => _durationMs > 0 && !_edit.isUnchanged && _tool == null;

  void _save() {
    if (!_canSave) return;
    unawaited(_video?.pause());
    _pauseAudio();
    AppHaptics.done();
    startEditJob(context, widget.path, _edit);
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  void dispose() {
    _video
      ?..removeListener(_onTick)
      ..dispose();
    for (final c in _audio.values) {
      unawaited(c.dispose());
    }
    final dir = _frameDir;
    if (dir != null) {
      dir.delete(recursive: true).catchError((Object _) => dir);
    }
    super.dispose();
  }

  // ── Arayüz ──────────────────────────────────────────────────────────────

  List<TimelineMark> get _marks => [
        for (final c in _edit.cuts) TimelineMark(c, TimelineMarkKind.cut),
        for (final m in _edit.mutes) TimelineMark(m, TimelineMarkKind.mute),
        for (final a in _edit.inserts)
          TimelineMark(a.at, TimelineMarkKind.audio),
        // Bölge seçerken kırpılan baş/son da "silinmiş" görünsün.
        if (_tool != null && _edit.keep.startMs > 0)
          TimelineMark(TrimRange(0, _edit.keep.startMs), TimelineMarkKind.cut),
        if (_tool != null && _edit.keep.endMs < _durationMs)
          TimelineMark(TrimRange(_edit.keep.endMs, _durationMs),
              TimelineMarkKind.cut),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.mediaSurface,
      appBar: AppBar(
        backgroundColor: AppColors.mediaSurface,
        foregroundColor: AppColors.onMedia,
        title: Text(context.t('ved.title')),
        actions: [
          // Kareyi fotoğraf kaydet (Ferrari H8.5): önizlemedeki o anki kare.
          IconButton(
            key: const ValueKey('ved-frame'),
            tooltip: context.t('ved.save_frame'),
            onPressed: _video == null || _tool != null ? null : _saveFrame,
            icon: const Icon(AppIcons.photoCamera),
          ),
          IconButton(
            key: const ValueKey('edit-undo'),
            tooltip: context.t('ved.undo'),
            onPressed: _history.isEmpty || _tool != null ? null : _undo,
            icon: const Icon(AppIcons.undo),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Gap.sm),
            child: FilledButton(
              key: const ValueKey('trim-save'),
              onPressed: _canSave ? _save : null,
              child: Text(context.t('common.save')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _preview(context)),
            _infoRow(context),
            if (_durationMs > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: VideoTrimTimeline(
                  key: ValueKey(_tool == null ? 'tl-keep' : 'tl-sel'),
                  durationMs: _durationMs,
                  range: _tool == null ? _edit.keep : _sel,
                  frames: _frames,
                  marks: _marks,
                  playheadMs: _video == null ? null : _positionMs,
                  accent: _tool == null ? null : scheme.tertiary,
                  dimOutside: _tool == null,
                  onChanged: (r) => _tool == null
                      ? setState(() => _edit = _edit.copyWith(keep: r))
                      : setState(() => _sel = r),
                  onSeek: _seek,
                  onDragEnd: _endScrub,
                ),
              ),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              child: _tool == null ? _toolbar(context) : _selectBar(context),
            ),
            if (_tool == null && _hasEdits) _editList(context),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  bool get _hasEdits =>
      _edit.cuts.isNotEmpty ||
      _edit.mutes.isNotEmpty ||
      _edit.inserts.isNotEmpty;

  /// Oynatma yeri solda, sonucun süresi sağda.
  Widget _infoRow(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppColors.onMediaSoft);
    final String right;
    if (_durationMs <= 0) {
      right = '';
    } else if (_tool != null) {
      right = context.t('vtr.range', {
        'start': formatClock(_sel.startMs),
        'end': formatClock(_sel.endMs),
        'n': trimSeconds(_sel),
      });
    } else if (_edit.isUnchanged) {
      right = context.t('vtr.whole');
    } else {
      right = context.t('ved.result', {'t': formatClock(_edit.outputMs)});
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      child: Row(
        children: [
          Text(formatClock(_positionMs), style: style),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              right,
              key: const ValueKey('trim-label'),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  /// Beş araç: simge üstte, ad altta (oynatıcı alt çubuğuyla aynı dil).
  Widget _toolbar(BuildContext context) {
    final enabled = _durationMs > 0;
    Widget tool(Key key, IconData icon, String label, VoidCallback? onTap,
            {bool on = false}) =>
        Expanded(
          child: _ToolButton(
            key: key,
            icon: icon,
            label: label,
            selected: on,
            onTap: enabled ? onTap : null,
          ),
        );
    return Padding(
      key: const ValueKey('ved-tools'),
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.md, Gap.sm, 0),
      child: Row(
        children: [
          tool(const ValueKey('ved-cut'), AppIcons.cut,
              context.t('ved.tool_cut'), () => _startTool(_Tool.cut)),
          tool(const ValueKey('ved-mute'), AppIcons.volumeOff,
              context.t('ved.tool_mute'), () => _startTool(_Tool.mute)),
          tool(const ValueKey('ved-audio'), AppIcons.libraryMusic,
              context.t('ved.tool_audio'), () => _startTool(_Tool.audio)),
          tool(
            const ValueKey('trim-mute'),
            _edit.muteAll ? AppIcons.volumeOff : AppIcons.volumeUp,
            context.t(_edit.muteAll ? 'ved.sound_off' : 'ved.sound_on'),
            () {
              AppHaptics.selection();
              _apply(_edit.copyWith(muteAll: !_edit.muteAll));
            },
            on: _edit.muteAll,
          ),
          // Döndür (Ferrari H8.5): her dokunuş saat yönünde 90°.
          tool(
            const ValueKey('ved-rotate'),
            AppIcons.rotate,
            context.t('ved.tool_rotate'),
            () {
              AppHaptics.selection();
              _apply(_edit.rotated());
            },
            on: _edit.quarterTurns != 0,
          ),
        ],
      ),
    );
  }

  /// Bölge seçilirken: ne yapılacağı + Vazgeç / Uygula.
  Widget _selectBar(BuildContext context) {
    final theme = Theme.of(context);
    final tool = _tool!;
    final (hint, apply, icon) = switch (tool) {
      _Tool.cut => ('ved.sel_cut', 'ved.apply_cut', AppIcons.cut),
      _Tool.mute => ('ved.sel_mute', 'ved.apply_mute', AppIcons.volumeOff),
      _Tool.audio => ('ved.sel_audio', 'ved.apply_audio', AppIcons.libraryMusic),
    };
    final audio = _selAudio;
    return Padding(
      key: const ValueKey('ved-select'),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            audio == null
                ? context.t(hint)
                : '${context.t(hint)} · ${p.basename(audio)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.onMediaSoft),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('ved-cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onMedia),
                  onPressed: _cancelTool,
                  child: Text(context.t('common.cancel')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('ved-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
                  ),
                  onPressed: _commitTool,
                  icon: Icon(icon),
                  label: Text(context.t(apply),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Yapılan düzenlemeler: her biri tek satır, sağda kaldır.
  Widget _editList(BuildContext context) {
    final rows = <Widget>[
      for (var i = 0; i < _edit.cuts.length; i++)
        _EditRow(
          key: ValueKey('ved-row-cut-$i'),
          icon: AppIcons.cut,
          text: context.t('ved.row_cut', {
            'start': formatClock(_edit.cuts[i].startMs),
            'end': formatClock(_edit.cuts[i].endMs),
          }),
          onTap: () => _seek(_edit.cuts[i].startMs),
          onRemove: () => _apply(_edit.removeCut(i)),
        ),
      for (var i = 0; i < _edit.mutes.length; i++)
        _EditRow(
          key: ValueKey('ved-row-mute-$i'),
          icon: AppIcons.volumeOff,
          text: context.t('ved.row_mute', {
            'start': formatClock(_edit.mutes[i].startMs),
            'end': formatClock(_edit.mutes[i].endMs),
          }),
          onTap: () => _seek(_edit.mutes[i].startMs),
          onRemove: () => _apply(_edit.removeMute(i)),
        ),
      for (var i = 0; i < _edit.inserts.length; i++)
        _EditRow(
          key: ValueKey('ved-row-audio-$i'),
          icon: AppIcons.libraryMusic,
          text: '${p.basename(_edit.inserts[i].path)} · '
              '${formatClock(_edit.inserts[i].at.startMs)}–'
              '${formatClock(_edit.inserts[i].at.endMs)}',
          onTap: () => _seek(_edit.inserts[i].at.startMs),
          onRemove: () => _apply(_edit.removeInsert(i)),
          trailing: TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.onMediaSoft,
                visualDensity: VisualDensity.compact),
            onPressed: () => _apply(_edit.toggleReplace(i)),
            child: Text(context.t(_edit.inserts[i].replace
                ? 'ved.replace_on'
                : 'ved.replace_off')),
          ),
        ),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 148),
      child: ListView(
        key: const ValueKey('ved-list'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
        children: rows,
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final c = _video;
    if (c == null) {
      return Center(
        child: _previewFailed
            ? Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Text(context.t('vtr.no_preview'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.onMediaSoft)),
              )
            : const CircularProgressIndicator(),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Döndürme önizlemesi (H8.5): ağaç şekli sabit, 0'da dönüş yok.
            RotatedBox(
              key: const ValueKey('ved-preview-rotation'),
              quarterTurns: _edit.quarterTurns,
              child: AspectRatio(
                aspectRatio:
                    c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(c),
                    if (_scrubShown != null)
                      Image.file(
                        File(_scrubShown!),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) => v.isPlaying || _scrubbing
                  ? const SizedBox.shrink()
                  : const Icon(AppIcons.playCircle,
                      size: 64, color: AppColors.onMediaSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Araç düğmesi: yuvarlak simge zemini + altta ad; seçiliyken dolu.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = onTap == null
        ? AppColors.onMediaSoft.withValues(alpha: 0.4)
        : selected
            ? scheme.onPrimaryContainer
            : AppColors.onMedia;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.of(context, Motion.short),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? scheme.primaryContainer
                      : AppColors.onMedia.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: AppColors.onMediaSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Düzenleme listesinin bir satırı.
class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    required this.onRemove,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Material(
        color: AppColors.onMedia.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: Gap.sm),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.onMediaSoft),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.onMedia),
                  ),
                ),
                ?trailing,
                IconButton(
                  tooltip: context.t('ved.remove'),
                  visualDensity: VisualDensity.compact,
                  color: AppColors.onMediaSoft,
                  onPressed: () {
                    AppHaptics.selection();
                    onRemove();
                  },
                  icon: const Icon(AppIcons.close, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Düzenleme işini kuyruğa verir: kullanıcı ekranı kapatabilir; ilerleme alt
/// şeritte ve bildirimde, çıktı İşlemler ekranında (Aç / Paylaş).
void startEditJob(BuildContext context, String path, VideoEdit edit) {
  final messenger = ScaffoldMessenger.of(context);
  final str = AppStrings.of(context);
  final name = p.basename(path);
  final id = 'trim_${Object.hash(
    path,
    edit.keep,
    Object.hashAll(edit.cuts),
    Object.hashAll(edit.mutes),
    Object.hashAll([for (final a in edit.inserts) Object.hash(a.path, a.at)]),
    edit.muteAll,
    edit.quarterTurns,
  )}';
  final before = JobQueue.instance.find(id);
  final alreadyRunning = before != null && before.status.isActive;
  final job = JobQueue.instance.enqueue(
    id: id,
    title: str.t('vtr.job', {'name': name}),
    name: str.t('vtr.job_name', {'name': name}),
    total: 1,
    run: (handle) async {
      handle.report(
          done: 0,
          total: 1,
          detail: formatClock(edit.outputMs));
      final out = await VideoTranscoder.edit(path, edit, handle: handle);
      handle.addOutput(out, source: path);
      handle.report(done: 1, total: 1);
      FsEvents.changed([out]);
    },
  );
  showSnackOn(
      messenger,
      str.t(alreadyRunning
          ? 'ra.already_running'
          : job.status == JobStatus.queued && JobQueue.instance.hasActive
              ? 'ra.queued'
              : 'ra.started'));
}
