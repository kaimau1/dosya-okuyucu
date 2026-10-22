import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../fm/fm_env.dart';
import '../fm/video_transcode.dart';
import '../tts_service.dart';
import '../voice/neural_engine.dart';
import '../voice/neural_voices.dart';
import 'doc_chapters.dart';
import 'wav.dart';

/// Sesli kitabı hangi ses okusun?
enum AudiobookVoice {
  /// Cihazın konuşma motoru (Google TTS vb.) — indirme yok.
  system,
  antalia,
  ema;

  NeuralVoice? get neural => switch (this) {
        AudiobookVoice.system => null,
        AudiobookVoice.antalia => NeuralVoice.antalia,
        AudiobookVoice.ema => NeuralVoice.ema,
      };

  String get folderTag => switch (this) {
        AudiobookVoice.system => '',
        AudiobookVoice.antalia => ' (Antalia)',
        AudiobookVoice.ema => ' (EMA)',
      };
}

/// Üretim ilerlemesi.
class AudiobookProgress {
  final int chapter; // 0 tabanlı
  final int chapters;
  final double fraction; // bölüm içi 0..1
  final String stage; // 'synth' | 'merge' | 'encode' | 'skip'
  const AudiobookProgress(this.chapter, this.chapters, this.fraction, this.stage);

  double get overall =>
      chapters == 0 ? 1 : ((chapter + fraction) / chapters).clamp(0, 1);
}

/// **Belgeden sesli kitap** (2026-10-22, kullanıcı: *"PDF'yi, yazıyı, Word'ü,
/// slaytı uygun formatta ses dosyası oluşturma özelliği olsun ve ses dosyası
/// kaydedilsin; istediğim zaman tekrar üretmeye gerek kalmadan dinleyebileyim,
/// başlıklarında uygun olmalı"*).
///
/// Çıktı: `Music/Sesli Kitaplar/<belge>[ (ses)]/NN - <Bölüm başlığı>.m4a`
/// (AAC; yerel kodlayıcı yoksa WAV) + `çalma listesi.m3u8`. Var olan bölüm
/// dosyası ATLANIR: üretim yarıda kalırsa kaldığı yerden sürer, biten
/// bölümler bir daha üretilmez. WAV'larda ad/albüm/parça etiketi var.
class AudiobookMaker {
  AudiobookMaker({
    required this.voice,
    this.engine,
    TtsService? tts,
    this.speed = 1.0,
  }) : _tts = tts;

  final AudiobookVoice voice;
  final NeuralVoiceEngine? engine;
  final double speed;
  TtsService? _tts;

  /// Sesli kitapların kökü.
  static String get libraryRoot =>
      p.join(FmEnv.primaryRoot, 'Music', 'Sesli Kitaplar');

  static String folderFor(String docName, AudiobookVoice voice) => p.join(
      libraryRoot, DocChapters.fileSafe('$docName${voice.folderTag}'));

  /// Bölüm dosyasının adı (uzantısız): "03 - Giriş".
  static String chapterBase(int index, AudioChapter c) =>
      '${(index + 1).toString().padLeft(2, '0')} - ${DocChapters.fileSafe(c.title)}';

  /// Klasörde bu bölümün hazır dosyası (m4a ya da wav) varsa yolu.
  static String? existing(String folder, int index, AudioChapter c) {
    final base = p.join(folder, chapterBase(index, c));
    for (final ext in const ['.m4a', '.wav']) {
      final f = File('$base$ext');
      if (f.existsSync() && f.lengthSync() > 44) return f.path;
    }
    return null;
  }

  /// Motorun tek seferde alacağı parça boyu.
  @visibleForTesting
  static List<String> pieces(String text, int max) {
    // Cümleler tek tek değil, sınıra kadar birleştirilerek verilir: her
    // motor çağrısı kendi başına ısınma/tonlama maliyeti taşır.
    final out = <String>[];
    final buf = StringBuffer();
    for (final s in splitForSpeech(text, maxLength: max)) {
      if (buf.isNotEmpty && buf.length + 1 + s.length > max) {
        out.add(buf.toString());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(s);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  Future<List<String>> make({
    required String docName,
    required List<AudioChapter> chapters,
    /// Bölümlerin belgedeki sıra numarası (0 tabanlı; dosya adı ve parça no
    /// bundan). Verilmezse 0..n-1 — kullanıcı bölüm seçtiyse numaralar
    /// BELGEDEKİ sırayı korur ("03 - …" seçim yüzünden "01" olmaz).
    List<int>? numbers,
    void Function(AudiobookProgress p)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final folder = folderFor(docName, voice);
    await Directory(folder).create(recursive: true);
    final tmp = await Directory(p.join(FmEnv.appSupportDir, 'audiobook_tmp'))
        .create(recursive: true);
    final outputs = <String>[];
    for (var i = 0; i < chapters.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final c = chapters[i];
      final n = numbers == null ? i : numbers[i];
      final ready = existing(folder, n, c);
      if (ready != null) {
        outputs.add(ready);
        onProgress?.call(AudiobookProgress(i, chapters.length, 1, 'skip'));
        continue;
      }
      final parts = <String>[];
      final texts = pieces(c.text, voice == AudiobookVoice.system ? 3500 : 1800);
      try {
        for (var k = 0; k < texts.length; k++) {
          if (isCancelled?.call() ?? false) break;
          final part = p.join(tmp.path, 'p${i}_$k.wav');
          await _synth(texts[k], part, (d, t) {
            final within = t == 0 ? 0.0 : d / t;
            onProgress?.call(AudiobookProgress(
                i, chapters.length, ((k + within) / texts.length) * 0.9, 'synth'));
          });
          parts.add(part);
          onProgress?.call(AudiobookProgress(
              i, chapters.length, ((k + 1) / texts.length) * 0.9, 'synth'));
        }
        if (isCancelled?.call() ?? false) break;
        onProgress?.call(AudiobookProgress(i, chapters.length, 0.92, 'merge'));
        final base = p.join(folder, chapterBase(n, c));
        final wavPath = '$base.wav';
        final fmt = await Wav.concat(parts, wavPath,
            title: c.title, album: docName, track: n + 1);
        if (fmt == null) throw StateError('ses üretilemedi');
        onProgress?.call(AudiobookProgress(i, chapters.length, 0.95, 'encode'));
        var out = wavPath;
        if (Platform.isAndroid &&
            await VideoTranscoder.audioToAac(wavPath, '$base.m4a')) {
          await File(wavPath).delete();
          out = '$base.m4a';
        }
        outputs.add(out);
        onProgress?.call(AudiobookProgress(i, chapters.length, 1, 'done'));
      } finally {
        for (final part in parts) {
          try {
            await File(part).delete();
          } catch (_) {
            // Geçici dosya: bir sonraki üretimde üzerine yazılır.
          }
        }
      }
    }
    await _writePlaylist(folder, outputs);
    return outputs;
  }

  Future<void> _synth(String text, String target,
      void Function(int done, int total) progress) async {
    final neural = voice.neural;
    if (neural == null) {
      final tts = _tts ??= TtsService();
      if (!await tts.synthesizeToFile(text, target)) {
        throw StateError('cihaz sesi dosya üretemedi');
      }
      return;
    }
    final e = engine;
    if (e == null) throw StateError('ses motoru yok');
    final bytes = await e.synthesize(neural, text,
        speed: speed, onProgress: progress);
    await File(target).writeAsBytes(bytes, flush: true);
  }

  static Future<void> _writePlaylist(String folder, List<String> files) async {
    if (files.isEmpty) return;
    final lines = ['#EXTM3U', for (final f in files) p.basename(f)];
    await File(p.join(folder, 'çalma listesi.m3u8'))
        .writeAsString('${lines.join('\n')}\n', flush: true);
  }

  /// Kütüphanedeki kitaplar: (klasör, ses dosyaları sıralı).
  static Future<List<(Directory, List<File>)>> library() async {
    final root = Directory(libraryRoot);
    if (!await root.exists()) return const [];
    final out = <(Directory, List<File>)>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final files = <File>[];
      await for (final f in e.list()) {
        if (f is File && RegExp(r'\.(m4a|wav)$', caseSensitive: false).hasMatch(f.path)) {
          files.add(f);
        }
      }
      if (files.isEmpty) continue;
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      out.add((e, files));
    }
    out.sort((a, b) => p.basename(a.$1.path).compareTo(p.basename(b.$1.path)));
    return out;
  }
}
