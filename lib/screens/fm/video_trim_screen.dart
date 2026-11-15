import 'dart:async';
import 'dart:io';
import 'dart:math' show min;

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/edit/edit_session.dart'
    show UnsavedChoice, showUnsavedChanges;
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/video_edit.dart';
import '../../models/video_trim.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/video_transcode.dart';
import '../../widgets/fm/fm_file_image.dart';
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
  final List<VideoEdit> _future = [];

  /// Tutamaç sürüklemesi başlamadan önceki plan (Geri al tek adım saysın).
  VideoEdit? _dragFrom;
  List<String> _frames = const [];
  Directory? _frameDir;

  /// Oynatma yeri. Bildirici: her konum değişiminde bütün ekran değil yalnız
  /// saat + şerit yeniden kurulur (sürüklerken kare düşmesin).
  final ValueNotifier<int> _pos = ValueNotifier(0);
  int get _positionMs => _pos.value;
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
  final ValueNotifier<String?> _scrubShown = ValueNotifier(null);
  final ValueNotifier<bool> _scrubbing = ValueNotifier(false);

  /// Parmak şeritte (tarama/tutamaç). Kalkınca katman, oynatıcı o kareye
  /// yetişene dek kalır ([_maybeRelease]) — eski kareye sıçrama görünmez.
  bool _dragging = false;
  Timer? _releaseTimer;

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
    // Oynatıcı kurulumu sayfa geçişi BİTİNCE (kurulum platform iş parçacığını
    // meşgul ediyor; geçişin içinde olunca ekran takılarak açılıyordu).
    WidgetsBinding.instance.addPostFrameCallback((_) => _previewAfterRoute());
    unawaited(_loadDuration());
  }

  void _previewAfterRoute() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      unawaited(_openPreview());
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.forward) return;
      animation.removeStatusListener(listener);
      if (status == AnimationStatus.completed && mounted) {
        unawaited(_openPreview());
      }
    };
    animation.addStatusListener(listener);
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
      // Son kullanım işareti (budama buna göre sıralar).
      try {
        await dir.create(recursive: true);
        await File(p.join(dir.path, '.son')).writeAsString('1');
      } catch (_) {
        // Bilinçli: işaret yalnız budama sırası içindir; yazılamazsa önemsiz.
      }
      // Şerit kareleri ayrı çıkarılmıyor: tarama ızgarasının (60) alt
      // kümesi (bkz. [_stripIndex]) — aynı kareyi iki kez çözmek yok.
      if (mounted) await _loadScrubFrames(dir);
    } catch (_) {
      // Bilinçli: kare şeridi süs; yoksa düz şerit, tutamaçlar yine çalışır.
    }
  }

  /// Tarama kareleri: şeritten sık (60) ve büyük (320 px).
  ///
  /// **Kabadan inceye** (2026-11-14, kullanıcı: *"en başta çektiğimde
  /// göremiyorum, birkaç sn sonra canlı görme geliyor"*). Kök: 60 kare tek
  /// yerel çağrıda çıkarılıyordu (kare başı ~50–150 ms → 3–9 sn hiç kare
  /// yok). Şimdi (1) şeridin 12 küçük karesi hemen tarama karesi olur,
  /// (2) 60'lık ızgara 6'şar dilimlik parçalarla, ekrana yayılan sırayla
  /// (bit ters çevirme) istenir; her parça gelince liste incelir.
  /// Dosya adındaki sıra no'su (`kare_<i>`) zamanı verir.
  static const _scrubCount = 60;
  static const _scrubBatch = 6;
  bool _scrubLoading = false;

  static final _kareRe = RegExp(r'kare_(\d+)\.jpg$');

  /// [paths] (her biri `kare_<i>`, ızgara [count]) → (ms, yol).
  List<({int ms, String path})> _timed(List<String> paths, int count) => [
        for (final f in paths)
          if (_kareRe.firstMatch(f) case final m?)
            (
              // Yerel taraf her dilimin ORTASINI alır: (2i+1)/(2n).
              ms: (_durationMs * (2 * int.parse(m.group(1)!) + 1)) ~/
                  (2 * count),
              path: f,
            ),
      ];

  void _mergeScrub(List<({int ms, String path})> add, {bool precache = true}) {
    if (add.isEmpty) return;
    final byMs = {for (final f in _scrubFrames) f.ms: f};
    for (final f in add) {
      byMs[f.ms] = f;
    }
    _scrubFrames = byMs.values.toList()..sort((a, b) => a.ms.compareTo(b.ms));
    // Parmak dururken gelen daha yakın kare hemen gösterilir.
    if (_scrubbing.value) {
      final near = _nearestScrubFrame(_positionMs);
      if (near != null) _scrubShown.value = near;
    }
    if (!precache) return;
    // Görüntüleri önceden çöz: taramada boş kare yanıp sönmesin.
    for (final f in add) {
      if (!mounted) return;
      unawaited(precacheImage(FmFileImage(f.path), context)
          .catchError((Object _) {}));
    }
  }

  // ── Parmağın altındaki TAM kare (2026-11-15) ───────────────────────────
  //
  // 60'lık ızgara uzun videoda kaba kalıyor (10 dk → 10 sn'de bir kare) ve
  // anahtar karelerden oluşuyor. Sürüklerken parmağın durduğu an için ince
  // ızgaradan (≈0,2 sn'de bir) TEK kare, tam o andan istenir; bir istek
  // sürerken gelenlerden yalnız sonuncusu tutulur.
  static const _fineStepMs = 200;
  static const _fineMax = 3000;
  int get _fineCount =>
      (_durationMs ~/ _fineStepMs).clamp(_scrubCount, _fineMax);
  final Set<int> _fineGot = {};
  bool _fineBusy = false;
  int? _finePending;

  void _wantFine(int ms) {
    final dir = _frameDir;
    if (dir == null || _durationMs <= 0) return;
    final n = _fineCount;
    final i = (ms * n ~/ _durationMs).clamp(0, n - 1);
    if (_fineGot.contains(i)) return;
    if (_fineBusy) {
      _finePending = ms;
      return;
    }
    _fineBusy = true;
    unawaited(_fetchFine(dir, i, n));
  }

  Future<void> _fetchFine(Directory dir, int i, int n) async {
    try {
      final paths = await VideoTranscoder.frames(widget.path,
          dir: p.join(dir.path, 'ince'),
          count: n,
          width: 320,
          indices: [i],
          exact: true);
      if (!mounted) return;
      // Çıkarılamayan kare de işaretlenir: aynı an yeniden istenmez.
      _fineGot.add(i);
      _mergeScrub(_timed(paths, n), precache: false);
    } finally {
      _fineBusy = false;
      final next = _finePending;
      _finePending = null;
      if (next != null && mounted && _scrubbing.value) _wantFine(next);
    }
  }

  /// 0..n-1'i ekrana yayılan sırayla verir (6 bitlik ters çevirme).
  static List<int> _spreadOrder(int n) {
    var bits = 1;
    while ((1 << bits) < n) {
      bits++;
    }
    final out = <int>[];
    for (var i = 0; i < (1 << bits); i++) {
      var r = 0;
      for (var b = 0; b < bits; b++) {
        if (i & (1 << b) != 0) r |= 1 << (bits - 1 - b);
      }
      if (r < n) out.add(r);
    }
    return out;
  }

  /// Şeridin [j]. karesi = tarama ızgarasının hangi dilimi? Dilim ortaları
  /// çakışır: 12'lik ızgarada (2j+1)/24 = 60'lıkta (10j+5)/120 → i = 5j+2.
  static int _stripIndex(int j) =>
      j * (_scrubCount ~/ _stripCount) + (_scrubCount ~/ _stripCount) ~/ 2;
  static const _stripCount = 12;

  /// **İlk kare gecikmesi** (kullanıcı 2026-11-15: *"ilk önizleme karesi
  /// uzun süre kalıyor, kaydırınca uzun süre girmiyor"*). Kök: önce 12'lik
  /// şerit TEK yerel çağrıda (hepsi bitene dek hiç kare yok, 1–3 sn), sonra
  /// 60'lık tarama baştan çıkarılıyordu; her açılışta yeniden. Şimdi:
  /// (1) önceki açılıştan kalan kareler (video değişmemişse) anında,
  /// (2) eksikler 2 → 4 → 6'lık parçalarla, önce şeridin kareleri,
  /// (3) şerit, kareleri tamamlanınca tarama karelerinden kurulur.
  Future<void> _loadScrubFrames(Directory stripDir) async {
    if (_durationMs <= 0) return;
    final dir = p.join(stripDir.path, 'tarama');
    final got = <int, String>{};
    try {
      final videoAt = (await File(widget.path).stat()).modified;
      final stats = await Future.wait([
        for (var i = 0; i < _scrubCount; i++)
          File(p.join(dir, 'kare_$i.jpg')).stat(),
      ]);
      for (var i = 0; i < _scrubCount; i++) {
        final st = stats[i];
        if (st.type == FileSystemEntityType.file &&
            st.size > 0 &&
            !st.modified.isBefore(videoAt)) {
          got[i] = p.join(dir, 'kare_$i.jpg');
        }
      }
    } catch (_) {
      // Bilinçli: önbellek okunamazsa kareler baştan çıkarılır.
    }
    if (!mounted) return;
    if (got.isNotEmpty) {
      _mergeScrub(_timed(got.values.toList(), _scrubCount));
      _syncStrip(got);
    }
    final strip = [for (final j in _spreadOrder(_stripCount)) _stripIndex(j)];
    final stripSet = strip.toSet();
    final order = [
      ...strip,
      for (final i in _spreadOrder(_scrubCount))
        if (!stripSet.contains(i)) i,
    ].where((i) => !got.containsKey(i)).toList();
    if (order.isEmpty) return;
    setState(() => _scrubLoading = true);
    try {
      var i = 0;
      var size = 2;
      while (i < order.length) {
        if (!mounted) return;
        final batch = order.sublist(i, min(i + size, order.length));
        i += batch.length;
        size = min(size + 2, _scrubBatch);
        final paths = await VideoTranscoder.frames(widget.path,
            dir: dir, count: _scrubCount, width: 320, indices: batch);
        if (!mounted) return;
        for (final path in paths) {
          final m = _kareRe.firstMatch(path);
          if (m != null) got[int.parse(m.group(1)!)] = path;
        }
        _mergeScrub(_timed(paths, _scrubCount));
        _syncStrip(got);
      }
    } finally {
      if (mounted) {
        setState(() {
          _scrubLoading = false;
          // Bazı kareler çıkarılamadıysa şerit eldekilerle kurulur.
          if (_frames.length < _stripCount) {
            _frames = [
              for (var j = 0; j < _stripCount; j++)
                ?got[_stripIndex(j)],
            ];
          }
        });
      }
    }
  }

  static Future<void> _pruneFrameDirs(Directory root) async {
    try {
      final dirs = <(Directory, DateTime)>[];
      await for (final e in root.list()) {
        if (e is Directory) {
          dirs.add((e, (await File(p.join(e.path, '.son')).stat()).modified));
        }
      }
      dirs.sort((a, b) => b.$2.compareTo(a.$2));
      for (final (d, _) in dirs.skip(5)) {
        await d.delete(recursive: true);
      }
    } catch (_) {
      // Bilinçli: budama süs; geçici klasörü sistem de temizler.
    }
  }

  /// Şeridin 12 karesi tamamsa şeridi kurar (bir kez).
  void _syncStrip(Map<int, String> got) {
    if (_frames.length == _stripCount) return;
    final strip = <String>[];
    for (var j = 0; j < _stripCount; j++) {
      final f = got[_stripIndex(j)];
      if (f == null) return;
      strip.add(f);
    }
    setState(() => _frames = strip);
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

  /// Şeritteki sürükleme bitti: tutamaç çekildiyse Geri al adımı yazılır,
  /// canlı kare katmanı oynatıcı yetişince kalkar.
  void _endScrub() {
    final from = _dragFrom;
    _dragFrom = null;
    if (from != null && from.keep != _edit.keep) {
      setState(() {
        _history.add(from);
        _future.clear();
      });
    }
    _dragging = false;
    _maybeRelease();
  }

  /// Katmanı kaldırır — ama ancak parmak kalkmış ve oynatıcının araması
  /// bitmişse, üstüne kısa bir pay ([Motion.busyDefer]: `seekTo` kare
  /// çizilmeden döner). Kök: katman hemen kalkınca önizleme bir an ESKİ
  /// kareye sıçrıyordu.
  void _maybeRelease() {
    if (!_scrubbing.value || _dragging) return;
    if (_video == null) {
      _releaseNow();
      return;
    }
    if (_seekBusy || _seekPending != null) return;
    _releaseTimer?.cancel();
    _releaseTimer = Timer(Motion.busyDefer, _releaseNow);
  }

  void _releaseNow() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _dragging = false;
    _scrubbing.value = false;
    _scrubShown.value = null;
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
    if (!_scrubbing.value && pos != _positionMs && mounted) _pos.value = pos;
    if (!c.value.isPlaying) {
      _pauseAudio();
      return;
    }
    // Bölge seçerken oynatma yalnız seçili bölgeyi gösterir: sonuna gelince
    // durur, başa sarar (neyin silineceği/susacağı görülsün).
    if (_tool != null && pos >= _sel.endMs) {
      unawaited(c.pause());
      _pauseAudio();
      unawaited(c.seekTo(Duration(milliseconds: _sel.startMs)));
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
    final active = <String>{};
    for (final a in _edit.inserts) {
      if (pos < a.at.startMs || pos >= a.at.endMs) continue;
      final ac = _audio[a.path];
      if (ac == null || !ac.value.isInitialized) continue;
      active.add(a.path);
      final want = _edit.toOutput(pos) - _edit.toOutput(a.at.startMs);
      final have = ac.value.position.inMilliseconds;
      if ((want - have).abs() > 400) {
        unawaited(ac.seekTo(Duration(milliseconds: want)));
      }
      if (!ac.value.isPlaying) unawaited(ac.play());
    }
    // Bölgesi dışındaki — ve düzenlemeden KALDIRILMIŞ — sesler susar
    // (eskiden kaldırılan ses çalmayı sürdürüyordu).
    for (final e in _audio.entries) {
      if (!active.contains(e.key) && e.value.value.isPlaying) {
        unawaited(e.value.pause());
      }
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
    _releaseNow();
    final range = _tool != null ? _sel : _edit.keep;
    final pos = c.value.position.inMilliseconds;
    if (pos < range.startMs || pos >= range.endMs - 100) {
      unawaited(c.seekTo(Duration(milliseconds: range.startMs)));
    }
    unawaited(c.play());
  }

  /// Şeritte tarama / tutamaç: canlı kare katmanı açılır.
  void _seek(int ms) {
    final c = _video;
    _releaseTimer?.cancel();
    _dragging = true;
    _pos.value = ms;
    _scrubbing.value = true;
    final near = _nearestScrubFrame(ms);
    if (near != null) _scrubShown.value = near;
    _wantFine(ms);
    if (c == null) return;
    if (c.value.isPlaying) unawaited(c.pause());
    _pauseAudio();
    _seekTo(c, ms);
  }

  /// Düğme / liste satırı: o ana git. Katman AÇILMAZ (yaklaşık kare yerine
  /// oynatıcının kesin karesi görünsün; eskiden satıra dokununca katman
  /// takılı kalıyor, oynatma çizgisi donuyordu).
  void _jump(int ms) {
    final c = _video;
    final to = ms.clamp(0, _durationMs);
    _releaseNow();
    _pos.value = to;
    if (c == null) return;
    if (c.value.isPlaying) unawaited(c.pause());
    _pauseAudio();
    _seekTo(c, to);
  }

  /// İnce ayar adımı (0,1 sn).
  static const _stepMs = 100;

  void _step(int direction) {
    AppHaptics.step();
    _jump(_positionMs + direction * _stepMs);
  }

  /// Başlangıcı / bitişi oynatma yerine çeker (bölge seçerken bölgenin).
  void _setEdge({required bool start}) {
    if (_durationMs <= 0) return;
    final ms = _positionMs;
    AppHaptics.selection();
    if (_tool != null) {
      setState(() => _sel = start
          ? _sel.withStart(ms, _durationMs)
          : _sel.withEnd(ms, _durationMs));
      return;
    }
    final keep = start
        ? _edit.keep.withStart(ms, _durationMs)
        : _edit.keep.withEnd(ms, _durationMs);
    if (keep == _edit.keep) return;
    _apply(_edit.copyWith(keep: keep));
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
      if (next != null && mounted && identical(c, _video)) {
        _seekTo(c, next);
      } else if (mounted) {
        _maybeRelease();
      }
    }));
  }

  // ── Düzenleme ───────────────────────────────────────────────────────────

  void _apply(VideoEdit next) {
    if (identical(next, _edit)) return;
    setState(() {
      _history.add(_edit);
      _future.clear();
      _edit = next;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    AppHaptics.selection();
    setState(() {
      _future.add(_edit);
      _edit = _history.removeLast();
    });
  }

  void _redo() {
    if (_future.isEmpty) return;
    AppHaptics.selection();
    setState(() {
      _history.add(_edit);
      _edit = _future.removeLast();
    });
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
    // `maybePop` değil: kaydedilmemiş değişiklik sorusu araya girmesin.
    Navigator.of(context).pop();
  }

  /// Geri: bölge seçimi açıksa onu kapatır; değişiklik varsa sorar.
  Future<void> _onBack() async {
    if (_tool != null) {
      _cancelTool();
      return;
    }
    unawaited(_video?.pause());
    _pauseAudio();
    final choice = await showUnsavedChanges(context);
    if (!mounted) return;
    switch (choice) {
      case UnsavedChoice.save:
        _save();
      case UnsavedChoice.discard:
        Navigator.of(context).pop();
      case UnsavedChoice.cancel:
        break;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _video
      ?..removeListener(_onTick)
      ..dispose();
    for (final c in _audio.values) {
      unawaited(c.dispose());
    }
    // Kareler SİLİNMEZ (2026-11-15): aynı video yeniden açılınca anında
    // gelsin. Yalnız son 5 videonunki tutulur (~1 MB/video, geçici klasör).
    final dir = _frameDir;
    if (dir != null) unawaited(_pruneFrameDirs(dir.parent));
    _pos.dispose();
    _scrubShown.dispose();
    _scrubbing.dispose();
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
    return PopScope(
      canPop: _tool == null && _edit.isUnchanged,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.mediaSurface,
        appBar: AppBar(
          backgroundColor: AppColors.mediaSurface,
          foregroundColor: AppColors.onMedia,
          title: Text(context.t('ved.title')),
          actions: [
            IconButton(
              key: const ValueKey('edit-undo'),
              tooltip: context.t('ved.undo'),
              onPressed: _history.isEmpty || _tool != null ? null : _undo,
              icon: const Icon(AppIcons.undo),
            ),
            IconButton(
              key: const ValueKey('edit-redo'),
              tooltip: context.t('common.redo'),
              onPressed: _future.isEmpty || _tool != null ? null : _redo,
              icon: const Icon(AppIcons.redo),
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
              _transport(context),
              _infoRow(context),
              if (_durationMs > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pos,
                    builder: (context, pos, _) => VideoTrimTimeline(
                      key: ValueKey(_tool == null ? 'tl-keep' : 'tl-sel'),
                      durationMs: _durationMs,
                      range: _tool == null ? _edit.keep : _sel,
                      frames: _frames,
                      marks: _marks,
                      playheadMs: _video == null ? null : pos,
                      accent: _tool == null ? null : scheme.tertiary,
                      dimOutside: _tool == null,
                      onChanged: (r) => setState(() {
                        if (_tool == null) {
                          _dragFrom ??= _edit;
                          _edit = _edit.copyWith(keep: r);
                        } else {
                          _sel = r;
                        }
                      }),
                      onSeek: _seek,
                      onDragEnd: _endScrub,
                    ),
                  ),
                ),
              if (_durationMs > 0) _edgeRow(context),
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
      ),
    );
  }

  /// Saat (onda bir saniyeyle) · bir adım geri · oynat/duraklat · bir adım
  /// ileri · kareyi fotoğraf kaydet.
  Widget _transport(BuildContext context) {
    final c = _video;
    final ready = _durationMs > 0;
    final off = AppColors.onMediaSoft.withValues(alpha: 0.4);
    final clock = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.onMedia,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: Gap.sm),
              child: ValueListenableBuilder<int>(
                valueListenable: _pos,
                builder: (context, ms, _) => Text(
                  '${formatClock(ms)}.${(ms < 0 ? 0 : ms) % 1000 ~/ 100}',
                  key: const ValueKey('ved-clock'),
                  maxLines: 1,
                  style: clock,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('ved-step-back'),
            tooltip: context.t('ved.step_back'),
            color: AppColors.onMedia,
            disabledColor: off,
            onPressed: ready ? () => _step(-1) : null,
            icon: const Icon(AppIcons.skipPrevious),
          ),
          if (c == null)
            IconButton(
              tooltip: context.t('mp.play'),
              disabledColor: off,
              onPressed: null,
              icon: const Icon(AppIcons.play),
            )
          else
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) => IconButton.filledTonal(
                key: const ValueKey('ved-play'),
                tooltip: context.t(v.isPlaying ? 'mp.pause' : 'mp.play'),
                onPressed: _togglePlay,
                icon: Icon(v.isPlaying ? AppIcons.pause : AppIcons.play),
              ),
            ),
          IconButton(
            key: const ValueKey('ved-step-fwd'),
            tooltip: context.t('ved.step_fwd'),
            color: AppColors.onMedia,
            disabledColor: off,
            onPressed: ready ? () => _step(1) : null,
            icon: const Icon(AppIcons.skipNext),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              // Kareyi fotoğraf kaydet (Ferrari H8.5): önizlemedeki o anki kare.
              child: IconButton(
                key: const ValueKey('ved-frame'),
                tooltip: context.t('ved.save_frame'),
                color: AppColors.onMedia,
                disabledColor: off,
                onPressed: c == null || _tool != null ? null : _saveFrame,
                icon: const Icon(AppIcons.photoCamera),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Başlangıcı / bitişi oynatma yerine çeken iki düğme (ince ayar: önce
  /// adım düğmeleriyle kareyi bul, sonra dokun).
  Widget _edgeRow(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.onMedia,
      visualDensity: VisualDensity.compact,
    );
    Widget edge(Key key, IconData icon, String label, bool start) => Expanded(
          child: TextButton.icon(
            key: key,
            style: style,
            onPressed: () => _setEdge(start: start),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Row(
        children: [
          edge(const ValueKey('ved-set-start'), AppIcons.firstPage,
              context.t('ved.set_start'), true),
          edge(const ValueKey('ved-set-end'), AppIcons.lastPage,
              context.t('ved.set_end'), false),
        ],
      ),
    );
  }

  bool get _hasEdits =>
      _edit.cuts.isNotEmpty ||
      _edit.mutes.isNotEmpty ||
      _edit.inserts.isNotEmpty;

  /// Sonucun süresi (bölge seçerken bölgenin aralığı).
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
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
      child: Text(
        right,
        key: const ValueKey('trim-label'),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
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
          onTap: () => _jump(_edit.cuts[i].startMs),
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
          onTap: () => _jump(_edit.mutes[i].startMs),
          onRemove: () => _apply(_edit.removeMute(i)),
        ),
      for (var i = 0; i < _edit.inserts.length; i++)
        _EditRow(
          key: ValueKey('ved-row-audio-$i'),
          icon: AppIcons.libraryMusic,
          text: '${p.basename(_edit.inserts[i].path)} · '
              '${formatClock(_edit.inserts[i].at.startMs)}–'
              '${formatClock(_edit.inserts[i].at.endMs)}',
          onTap: () => _jump(_edit.inserts[i].at.startMs),
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
                    // Canlı kare katmanı: yalnız BU alt ağaç yeniden kurulur.
                    ListenableBuilder(
                      listenable: Listenable.merge([_scrubShown, _scrubbing]),
                      builder: (context, _) => _scrubLayer(),
                    ),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([c, _scrubbing]),
              builder: (context, _) => c.value.isPlaying || _scrubbing.value
                  ? const SizedBox.shrink()
                  : const Icon(AppIcons.playCircle,
                      size: 64, color: AppColors.onMediaSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrubLayer() {
    final shown = _scrubShown.value;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (shown != null)
          Image(
            image: FmFileImage(shown),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Kareler hâlâ geliyor: sürüklerken küçük dönence (karesiz bölgede
        // ortada, varken köşede).
        if (_dragging && _scrubbing.value && (_scrubLoading || shown == null))
          Align(
            alignment:
                shown == null ? Alignment.center : AlignmentDirectional.topEnd,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                key: ValueKey('ved-scrub-loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.onMedia,
                ),
              ),
            ),
          ),
      ],
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
