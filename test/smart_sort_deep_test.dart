import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_local_rules.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_input.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';

void main() {
  late Directory tmp;
  final today = DateTime(2026, 11, 28);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('smart_deep_');
    SmartSortInput.allowAudioFilesUpload = false;
    SmartSortInput.videoCoverOnly = true;
    GeminiService.debugClient = null;
  });

  tearDown(() async {
    await SmartSort.setSettings(deepMedia: false);
    GeminiService.debugClient = null;
    SmartSortInput.allowAudioFilesUpload = false;
    SmartSortInput.videoCoverOnly = true;
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  FsEntry entry(String path, int size) {
    final name = path.split(Platform.pathSeparator).last;
    return FsEntry(
      path: path,
      name: name,
      sizeBytes: size,
      modifiedMs: today.millisecondsSinceEpoch,
      isDir: false,
    );
  }

  DecisionAnswer choice(String id, String c, double conf) => DecisionAnswer(
        question: DecisionQuestion.choice(id, '', '', const {}),
        choice: c,
        confidence: conf,
      );

  DecisionAnswer yes(String id, double p) => DecisionAnswer(
        question: DecisionQuestion.yesNo(id, '', ''),
        yes: p,
        confidence: p,
      );

  group('derin medya girdisi', () {
    test('deep=true fotoda 2048px ve media_resolution=high kullanir', () async {
      final image = img.Image(width: 3000, height: 1500);
      img.fill(image, color: img.ColorRgb8(20, 120, 200));
      final jpg = img.encodeJpg(image, quality: 90);
      final file = File('${tmp.path}/manzara.jpg')..writeAsBytesSync(jpg);

      final prep = await SmartSortInput.prepare(
        entry(file.path, jpg.length),
        const ['k1'],
        deep: true,
      );

      expect(prep.block['type'], 'image');
      expect(prep.block['media_resolution'], 'high');
      final decoded = img.decodeJpg(
        base64Decode(prep.block['data'] as String),
      );
      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
    });

    test('deep=true 512KB ustu sesi dogrudan gonderir', () async {
      final audio = File('${tmp.path}/davet.mp3')
        ..writeAsBytesSync(List.filled(700 * 1024, 7));

      final prep = await SmartSortInput.prepare(
        entry(audio.path, 700 * 1024),
        const ['k1'],
        deep: true,
      );

      expect(prep.remote, isNull);
      expect(prep.block['type'], 'audio');
      expect((prep.block['data'] as String).isNotEmpty, isTrue);
    });

    test('deep=true 14MB ustu sesi Files API ile yukler ve serbest birakir',
        () async {
      final audio = File('${tmp.path}/konser.mp3')
        ..writeAsBytesSync(List.filled(64, 5));
      var deleted = false;
      GeminiService.debugClient = MockClient((req) async {
        if (req.method == 'POST' && req.url.path.contains('/upload/v1beta/files')) {
          return http.Response(
            '',
            200,
            headers: {
              'x-goog-upload-url':
                  'https://generativelanguage.googleapis.com/upload/audio1',
            },
          );
        }
        if (req.method == 'POST' && req.url.toString().endsWith('/audio1')) {
          return http.Response(
            jsonEncode({
              'file': {
                'name': 'files/audio1',
                'uri': 'https://generativelanguage.googleapis.com/v1beta/files/audio1',
                'mimeType': 'audio/mp3',
                'state': 'ACTIVE',
              },
            }),
            200,
          );
        }
        if (req.method == 'DELETE') {
          deleted = true;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 200);
      });

      final prep = await SmartSortInput.prepare(
        entry(audio.path, 20 * 1024 * 1024),
        const ['k1'],
        deep: true,
      );

      expect(prep.remote, 'files/audio1');
      expect(prep.block['type'], 'audio');
      expect(
        (prep.block['file_data'] as Map)['file_uri'],
        'https://generativelanguage.googleapis.com/v1beta/files/audio1',
      );
      prep.release();
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isTrue);
    });

    test('deep=true videoda videoCoverOnly bayragini asip medium cozunurluk gonderir',
        () async {
      final video = File('${tmp.path}/dugun.mp4')
        ..writeAsBytesSync(List.filled(1024, 9));

      final prep = await SmartSortInput.prepare(
        entry(video.path, 1024),
        const ['k1'],
        deep: true,
      );

      expect(prep.block['type'], 'video');
      expect(prep.block['media_resolution'], 'medium');
      expect((prep.block['video_metadata'] as Map)['end_offset'], '60s');
    });
  });

  group('ses ve video icerik siniflandirmasi', () {
    test('muzik sesi SmartTaxonomy.music olarak siniflanir', () {
      final e = entry('${tmp.path}/sarki.mp3', 1024);
      final fromSub = SmartSort.fromAnswers(
        e,
        DecisionResult([
          choice('sub_audio', 'music', 0.85),
          choice('speech_lang', 'none', 0.9),
          choice('quality', 'clear', 0.9),
          choice('audio_topic', 'none', 0.8),
        ]),
        today: today,
      )!;
      expect(fromSub.cat, SmartTaxonomy.music);
      expect(fromSub.sub, '');

      final fromTopic = SmartSort.fromAnswers(
        e,
        DecisionResult([
          choice('sub_audio', 'other', 0.5),
          choice('speech_lang', 'tr', 0.8),
          choice('quality', 'clear', 0.9),
          choice('audio_topic', 'music', 0.80),
        ]),
        today: today,
      )!;
      expect(fromTopic.cat, SmartTaxonomy.music);
      expect(fromTopic.sub, '');
    });

    test('sesli ve videolu davetler event/invitation olarak siniflanir', () {
      final audioInv = SmartSort.fromAnswers(
        entry('${tmp.path}/davet.m4a', 1024),
        DecisionResult([
          choice('sub_audio', 'invitation_audio', 0.85),
          choice('speech_lang', 'tr', 0.9),
          choice('quality', 'clear', 0.9),
          choice('audio_topic', 'event', 0.80),
        ]),
        today: today,
      )!;
      expect(audioInv.cat, 'event');
      expect(audioInv.sub, 'invitation_audio');

      final videoInv = SmartSort.fromAnswers(
        entry('${tmp.path}/davet.mp4', 1024),
        DecisionResult([
          choice('sub_video', 'invitation_video', 0.85),
          yes('accidental', 0.1),
          choice('video_topic', 'event', 0.80),
        ]),
        today: today,
      )!;
      expect(videoInv.cat, 'event');
      expect(videoInv.sub, 'invitation_video');
    });

    test('SmartLocalRules ses ve video dosyalarini isimle erken elemez', () {
      final e = entry('${tmp.path}/fatura_duyuru.mp3', 1024);
      expect(SmartLocalRules.classify(e), isNull);
    });

    test('SmartSort.setSettings deepMedia ayarini saklar', () async {
      await SmartSort.readSettings();
      expect(SmartSort.deepMedia, isFalse);
      await SmartSort.setSettings(deepMedia: true);
      expect(SmartSort.deepMedia, isTrue);
    });
  });
}
