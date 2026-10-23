import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/user_error.dart';
import '../fm/job_queue.dart' show FmJobTarget, FmJobTargetKind;
import '../fm/tracked_task.dart';
import '../voice/neural_engine.dart';
import 'audiobook_maker.dart';
import 'doc_chapters.dart';

/// **Arka planda süren sesli kitap üretimi** (2026-10-23).
///
/// Kullanıcı: *"sesli kitap oluştur arka planda çalışabilmeli"*. Üretim
/// eskiden sesli kitap EKRANININ durumunda koşuyordu: ekrandan çıkmak
/// (geri tuşu kapalıydı) ya da uygulamayı alta almak işi durdurabiliyordu.
/// Artık iş bu nesnede yaşar; ekran yalnız onu İZLER:
/// * iş sistemine hemen kaydolur → ana ekran şeridi, İşlemler, sistem
///   bildirimi ve **ön plan servisi** (uygulama alttayken süreç donmasın),
/// * bildirimdeki "Durdur" işi durdurur; bildirime dokunmak sesli kitap
///   ekranını (ilerlemesiyle) açar,
/// * yapay zekâ sesleri kökteki paylaşılan motoru kullanır
///   ([NeuralVoiceEngine.acquire]) — ekran kapansa da motor yaşar.
class AudiobookJob extends ChangeNotifier {
  AudiobookJob._({
    required this.path,
    required this.voice,
    required this.speed,
    required this.numbers,
  });

  /// Kaynak belge.
  final String path;
  final AudiobookVoice voice;
  final double speed;

  /// Üretilen bölümlerin belgedeki sıra numaraları.
  final List<int> numbers;

  AudiobookProgress? progress;

  /// Yapay ses yüklenirken "Antalia-2 Mini · %40"; değilse null.
  String? loadingVoice;

  /// Hazır bölüm dosyaları (iş bitince dolar).
  List<String> outputs = const [];

  bool running = true;
  bool _cancel = false;
  String? error;

  /// Kullanıcı sesli kitap ekranında izliyor mu? (Bitişte bildirim sessiz mi.)
  bool watched = false;

  late final TrackedTask _task;

  bool get cancelled => _cancel || _task.cancelRequested;

  void cancel() {
    _cancel = true;
    notifyListeners();
  }

  // ── Kayıt ──────────────────────────────────────────────────────────────
  static final Map<String, AudiobookJob> _jobs = {};

  /// Bu belgenin süren ya da son biten işi.
  static AudiobookJob? of(String path) => _jobs[path];

  /// Testler için.
  @visibleForTesting
  static void reset() => _jobs.clear();

  /// İşi başlatır; aynı belgede süren iş varsa YENİSİ açılmaz.
  static AudiobookJob start({
    required String path,
    required List<AudioChapter> chapters,
    required List<int> numbers,
    required AudiobookVoice voice,
    double speed = 1.0,
  }) {
    final existing = _jobs[path];
    if (existing != null && existing.running) return existing;
    final job = AudiobookJob._(
        path: path, voice: voice, speed: speed, numbers: numbers);
    _jobs[path] = job;
    final str = AppStrings.current;
    final docName = p.basenameWithoutExtension(path);
    job._task = TrackedTask(
      title: str.t('ab.job_running', {'name': docName}),
      name: str.t('ab.job_name', {'name': docName}),
      target:
          FmJobTarget(FmJobTargetKind.audiobook, paths: [path], title: docName),
      // Hemen kaydolur: ön plan servisi baştan korusun (bölümler dakikalar
      // sürer; kullanıcı ilk saniyelerde uygulamayı alta alabilir).
      threshold: Duration.zero,
    );
    unawaited(job._run(docName, [for (final i in numbers) chapters[i]], str));
    return job;
  }

  Future<void> _run(
      String docName, List<AudioChapter> chosen, AppStrings str) async {
    final neural = voice.neural;
    NeuralVoiceEngine? engine;
    try {
      if (neural != null) {
        loadingVoice = neural.label;
        notifyListeners();
        engine = await NeuralVoiceEngine.acquire();
        engine.onLoading = (v, loaded, total) {
          loadingVoice = total > 0
              ? '${v.label} · %${(loaded * 100 / total).round()}'
              : v.label;
          notifyListeners();
        };
        await engine.prepare(neural);
        loadingVoice = null;
        notifyListeners();
      }
      final maker = AudiobookMaker(voice: voice, engine: engine, speed: speed);
      outputs = await maker.make(
        docName: docName,
        chapters: chosen,
        numbers: numbers,
        isCancelled: () => cancelled,
        onProgress: (pr) {
          progress = pr;
          _task.report(
            done: pr.chapter,
            total: pr.chapters,
            unit: pr.fraction,
            detail: pr.chapter < chosen.length ? chosen[pr.chapter].title : '',
          );
          notifyListeners();
        },
      );
      final folder = p.basename(AudiobookMaker.folderFor(docName, voice));
      final quiet = watched && TrackedTask.userWatching;
      if (cancelled) {
        await _task.stopped(
            detail:
                str.t('ab.stopped', {'n': outputs.length, 'folder': folder}),
            quiet: quiet);
      } else {
        await _task.complete(
            detail: str.t('ab.done', {'n': outputs.length, 'folder': folder}),
            quiet: quiet);
      }
    } catch (e) {
      error = userErrorText(e);
      await _task.fail(str.t('ab.failed', {'error': error}),
          quiet: watched && TrackedTask.userWatching);
    } finally {
      if (engine != null) {
        engine.onLoading = null;
        NeuralVoiceEngine.release();
      }
      running = false;
      loadingVoice = null;
      notifyListeners();
    }
  }
}
