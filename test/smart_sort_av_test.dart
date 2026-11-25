import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as imglib;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_input.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı düzen 2.0 — ses ve video (PLAN §1.1 m.2, 2026-11-18): istek
/// gövdesi (ses/video blokları, video ofsetleri), Files API eşiği ve akışı
/// (ağ sahte), şema soruları, yanıt → kayıt, Ayıkla yönlendirmesi. Dosyalar
/// sentetik ve küçük; anahtarlar uydurma.
void main() {
  const tr = AppStrings(AppLanguage.tr);
  const en = AppStrings(AppLanguage.en);
  final today = DateTime(2026, 11, 18);

  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ssav_');
    SharedPreferences.setMockInitialValues({});
    GeminiService.filePollInterval = Duration.zero;
    SmartSortInput.clipVideo = (_) async => null;
    // Bu dosya eski (kesit / Files API) ses-video yolunu sınar; güvenli
    // varsayılanlar ayrı testte.
    SmartSortInput.videoCoverOnly = false;
    SmartSortInput.allowAudioFilesUpload = true;
  });
  tearDown(() {
    SmartSortInput.videoCoverOnly = true;
    SmartSortInput.allowAudioFilesUpload = false;
    SmartSortInput.scannedPdfFirstPageRaster = null;
    GeminiService.debugClient = null;
    tmp.deleteSync(recursive: true);
  });

  FsEntry entry(String path, int size) => FsEntry(
      path: path, name: path.split('/').last, isDir: false,
      sizeBytes: size, modifiedMs: 3);

  DecisionAnswer choice(String id, String value, double conf) => DecisionAnswer(
        question: DecisionQuestion.choice(id, id, id, const {'a': 'a', 'b': 'b'}),
        choice: value,
        confidence: conf,
      );

  DecisionAnswer yes(String id, double p) => DecisionAnswer(
        question: DecisionQuestion.yesNo(id, id, id),
        yes: p,
        confidence: 0.9,
      );

  group('istek gövdesi', () {
    test('ses bloğu: satır içi, video alanı yok', () {
      final b = SmartSortInput.avBlock('audio/ogg', video: false, data: 'QUJD');
      expect(b, {'type': 'audio', 'mime_type': 'audio/ogg', 'data': 'QUJD'});
    });

    test('video bloğu: düşük çözünürlük, yalnız ilk 60 sn, Files API adresi',
        () {
      final b = SmartSortInput.avBlock('video/mp4',
          video: true, fileUri: 'https://x/v1beta/files/v1');
      expect(b['type'], 'video');
      expect(b['media_resolution'], 'low');
      expect(b['video_metadata'], {'start_offset': '0s', 'end_offset': '60s'});
      expect((b['file_data'] as Map)['file_uri'], 'https://x/v1beta/files/v1');
      expect(b.containsKey('data'), isFalse);
    });

    test('küçük ses satır içi gider (izolatta base64), yükleme yok', () async {
      final f = File('${tmp.path}/not.opus')..writeAsBytesSync([1, 2, 3, 4]);
      GeminiService.debugClient = MockClient((req) async {
        fail('satır içi dosyada ağ isteği olmamalı: ${req.url}');
      });
      final prep = await SmartSortInput.prepare(entry(f.path, 4), ['k1', 'k2']);
      expect(prep.remote, isNull);
      expect(prep.keys, ['k1', 'k2']);
      expect(prep.block['type'], 'audio');
      expect(prep.block['data'], base64Encode([1, 2, 3, 4]));
      prep.release(); // yükleme yok → silme isteği de yok
    });
  });

  group('Files API (14 MB üstü)', () {
    test('yükle → işlenmeyi bekle → file_uri; ad gitmez; iş bitince silinir',
        () async {
      final f = File('${tmp.path}/Toplantı Ahmet.m4a')
        ..writeAsBytesSync(List.filled(32, 7));
      final seen = <http.Request>[];
      GeminiService.debugClient = MockClient((req) async {
        seen.add(req);
        final u = req.url.toString();
        if (u.endsWith('/upload/v1beta/files')) {
          return http.Response('{}', 200,
              headers: {'x-goog-upload-url': 'https://generativelanguage.googleapis.com/upload/s1'});
        }
        if (u == 'https://generativelanguage.googleapis.com/upload/s1') {
          return http.Response(
              jsonEncode({
                'file': {
                  'name': 'files/abc',
                  'uri': 'https://g.test/v1beta/files/abc',
                  'state': 'PROCESSING',
                },
              }),
              200);
        }
        if (req.method == 'GET' && u.endsWith('/v1beta/files/abc')) {
          return http.Response(
              jsonEncode({
                'name': 'files/abc',
                'uri': 'https://g.test/v1beta/files/abc',
                'state': 'ACTIVE',
              }),
              200);
        }
        if (req.method == 'DELETE') return http.Response('{}', 200);
        if (u.endsWith('/v1beta/decisions')) {
          return http.Response(
              jsonEncode({
                'answers': {
                  'sub_audio': {'choice': 'meeting_recording', 'confidence': 0.8},
                },
              }),
              200);
        }
        return http.Response('beklenmeyen', 404);
      });
      final e = entry(f.path, GeminiDecisions.maxInlineBytes + 1);
      final prep = await SmartSortInput.prepare(e, ['k1']);
      expect(prep.remote, 'files/abc');
      expect(prep.keys, ['k1']);
      expect(prep.block['type'], 'audio');
      expect(prep.block.containsKey('data'), isFalse);
      expect((prep.block['file_data'] as Map)['file_uri'],
          'https://g.test/v1beta/files/abc');

      final start = seen[0];
      expect(start.headers['X-Goog-Upload-Command'], 'start');
      expect(start.headers['X-Goog-Upload-Header-Content-Type'], 'audio/aac');
      expect(start.headers['x-goog-api-key'], 'k1');
      expect(start.url.toString(), isNot(contains('key=')));
      expect(start.body, isNot(contains('Ahmet')),
          reason: 'kişisel dosya adı sunucuya yazılmaz');
      expect(start.body, contains(GeminiService.uploadDisplayName));
      final up = seen[1];
      expect(up.headers['X-Goog-Upload-Command'], 'upload, finalize');
      expect(up.bodyBytes, List.filled(32, 7));
      expect(seen[2].method, 'GET', reason: 'PROCESSING → ACTIVE beklenir');

      // Decisions isteğinde yalnız adres gider.
      final r = await GeminiDecisions.ask(
          keys: prep.keys,
          input: [prep.block],
          questions: SmartTaxonomy.audioQuestions);
      final body = jsonDecode(seen.last.body) as Map;
      final block = (body['input'] as List).single as Map;
      expect(block['file_data'], isNotNull);
      expect(body['questions'], contains('speech_lang'));
      expect(r.answers.single.choice, 'meeting_recording');

      prep.release();
      await pumpEventQueue();
      expect(seen.last.method, 'DELETE');
      expect(seen.last.url.path, endsWith('/v1beta/files/abc'));
    });

    test('kota (429) yüklemede sıradaki anahtar; blok yalnız o anahtarla',
        () async {
      final f = File('${tmp.path}/v.mp4')..writeAsBytesSync([9, 9]);
      final keys = <String?>[];
      GeminiService.debugClient = MockClient((req) async {
        final u = req.url.toString();
        if (u.endsWith('/upload/v1beta/files')) {
          keys.add(req.headers['x-goog-api-key']);
          if (keys.length == 1) {
            return http.Response('{"error":{"message":"quota"}}', 429);
          }
          return http.Response('{}', 200,
              headers: {'x-goog-upload-url': 'https://generativelanguage.googleapis.com/upload/s2'});
        }
        return http.Response(
            jsonEncode({
              'file': {'name': 'files/v', 'uri': 'https://g.test/files/v'},
            }),
            200);
      });
      final prep = await SmartSortInput.prepare(
          entry(f.path, GeminiDecisions.maxInlineBytes + 1), ['k1', 'k2']);
      expect(keys, ['k1', 'k2']);
      expect(prep.keys, ['k2']);
      expect(prep.block['type'], 'video');
      expect(prep.block['video_metadata'],
          {'start_offset': '0s', 'end_offset': '60s'});
    });

    test('işlenemeyen dosya: hata, sunucudaki kopya silinir', () async {
      final f = File('${tmp.path}/b.mp3')..writeAsBytesSync([1]);
      final methods = <String>[];
      GeminiService.debugClient = MockClient((req) async {
        methods.add(req.method);
        if (req.url.toString().endsWith('/upload/v1beta/files')) {
          return http.Response('{}', 200,
              headers: {'x-goog-upload-url': 'https://generativelanguage.googleapis.com/upload/s3'});
        }
        if (req.method == 'DELETE') return http.Response('{}', 200);
        return http.Response(
            jsonEncode({
              'file': {
                'name': 'files/b',
                'uri': 'https://g.test/files/b',
                'state': 'FAILED',
              },
            }),
            200);
      });
      await expectLater(
          SmartSortInput.prepare(
              entry(f.path, GeminiDecisions.maxInlineBytes + 1), ['k1']),
          throwsA(isA<GeminiException>()));
      await pumpEventQueue();
      expect(methods.last, 'DELETE');
    });

    test('yükleme sınırı: ses 100 MB, video kaynağı 1 GB (kesitle)', () {
      expect(SmartSort.supports(entry('/s/Recordings/a.mp3', 90 << 20)), isTrue);
      expect(SmartSort.supports(entry('/s/Recordings/a.mp3', 101 << 20)),
          isFalse);
      expect(SmartSort.supports(entry('/s/Download/v.mp4', 40 << 20)), isTrue);
      expect(SmartSort.supports(entry('/s/Download/v.mp4', 51 << 20)), isTrue);
      expect(SmartSort.supports(entry('/s/Download/v.mp4', 1025 << 20)),
          isFalse);
      expect(GeminiService.fileInfoOf('{"name":"files/x","uri":"u"}').state,
          'ACTIVE');
    });
  });

  group('büyük video: yalnız ilk dakika (m.5)', () {
    test('kesit küçükse satır içi gider, yükleme yok, kesit silinir',
        () async {
      final f = File('${tmp.path}/uzun.mp4')..writeAsBytesSync([7]);
      final clip = File('${tmp.path}/kesit.mp4')..writeAsBytesSync([1, 2, 3]);
      String? asked;
      SmartSortInput.clipVideo = (path) async {
        asked = path;
        return clip.path;
      };
      var calls = 0;
      GeminiService.debugClient = MockClient((req) async {
        calls++;
        return http.Response('{}', 500);
      });
      final prep = await SmartSortInput.prepare(
          entry(f.path, 300 << 20), ['k1', 'k2']);
      expect(asked, f.path);
      expect(calls, 0);
      expect(prep.keys, ['k1', 'k2']);
      expect(prep.block['type'], 'video');
      expect(prep.block['mime_type'], 'video/mp4');
      expect(prep.block['data'], base64Encode([1, 2, 3]));
      expect(prep.block['video_metadata'],
          {'start_offset': '0s', 'end_offset': '60s'});
      expect(clip.existsSync(), isFalse);
    });

    test('kesit yapılamazsa: 50 MB altı bütün dosya yüklenir, üstü gitmez',
        () async {
      final f = File('${tmp.path}/v.mkv')..writeAsBytesSync([9]);
      final uploads = <String>[];
      GeminiService.debugClient = MockClient((req) async {
        final u = req.url.toString();
        if (u.endsWith('/upload/v1beta/files')) {
          uploads.add(u);
          return http.Response('{}', 200,
              headers: {'x-goog-upload-url': 'https://generativelanguage.googleapis.com/upload/s9'});
        }
        return http.Response(
            jsonEncode({
              'file': {'name': 'files/v', 'uri': 'https://g.test/files/v'},
            }),
            200);
      });
      final prep = await SmartSortInput.prepare(
          entry(f.path, GeminiDecisions.maxInlineBytes + 1), ['k1']);
      expect(uploads, hasLength(1));
      expect(prep.block['mime_type'], 'video/x-matroska');
      await expectLater(
          SmartSortInput.prepare(entry(f.path, 51 << 20), ['k1']),
          throwsA(isA<GeminiException>()
              .having((e) => e.statusCode, 'durum', -1)));
      expect(uploads, hasLength(1));
    });

    test('kesit hata verirse sessizce eski yola döner', () async {
      final f = File('${tmp.path}/h.mp4')..writeAsBytesSync([9]);
      SmartSortInput.clipVideo = (_) async => throw StateError('kodlayıcı');
      await expectLater(
          SmartSortInput.prepare(entry(f.path, 60 << 20), ['k1']),
          throwsA(isA<GeminiException>()
              .having((e) => e.statusCode, 'durum', -1)));
    });
  });

  group('şema', () {
    test('ses: tek istekte tür, dil, kalite; video: tür + yanlışlıkla', () {
      final a = SmartTaxonomy.questions(image: false, audio: true);
      expect(a.map((q) => q.id), ['sub_audio', 'speech_lang', 'quality']);
      expect(a.first.options.keys, containsAll([
        'voice_note', 'meeting_recording', 'lecture', 'call_recording',
        'music', 'whatsapp_voice', 'other',
      ]));
      expect(a[1].options.keys, containsAll(['tr', 'en', 'ar', 'none']));
      expect(a[2].options.keys, ['clear', 'noisy', 'poor']);
      final v = SmartTaxonomy.questions(image: false, video: true);
      expect(v.map((q) => q.id), ['sub_video', 'accidental']);
      expect(v.first.options.keys, containsAll([
        'family_video', 'screen_recording', 'lecture_video', 'clip_meme',
        'document_video', 'other',
      ]));
      for (final q in [...a, ...v]) {
        if (q.kind == DecisionKind.choice) {
          expect(q.options.length, inInclusiveRange(2, 255), reason: q.id);
        }
      }
      // Belge/görsel isteğine ses/video soruları girmez.
      for (final img in [true, false]) {
        final ids = SmartTaxonomy.questions(image: img, today: today)
            .map((q) => q.id);
        expect(ids, isNot(contains('sub_audio')));
        expect(ids, isNot(contains('sub_video')));
        expect(ids, isNot(contains('speech_lang')));
      }
      expect(SmartTaxonomy.categoryIds, containsAll(['audio', 'video']));
      // Konuşma dillerinin üç dilde adı var.
      for (final s in const [tr, en, AppStrings(AppLanguage.ar)]) {
        for (final l in SmartTaxonomy.speechLanguages.keys) {
          if (l == 'other' || l == 'none') continue;
          expect(s.t('sm.l_$l'), isNot('sm.l_$l'), reason: l);
        }
      }
    });

    test('soru seçimi dosya türünden', () {
      List<String> ids(String path) => SmartSort.questionsFor(path,
              today: today, learned: '')
          .map((q) => q.id)
          .toList();
      expect(ids('/a/kayit.ogg').first, 'sub_audio');
      expect(ids('/a/klip.3gp').first, 'sub_video');
      expect(ids('/a/f.pdf').first, 'cat');
    });
  });

  group('yanıt → kayıt', () {
    test('ses: alt tür, dil, kalite; düşük güven alınmaz; arama dilde bulur',
        () {
      final e = entry('/s/Recordings/r1.m4a', 100);
      final rec = SmartSort.fromAnswers(
        e,
        DecisionResult([
          choice('sub_audio', 'lecture', 0.8),
          choice('speech_lang', 'en', 0.9),
          choice('quality', 'noisy', 0.7),
        ]),
        today: today,
      )!;
      expect(rec.cat, SmartTaxonomy.audio);
      expect(rec.sub, 'lecture');
      expect(rec.lang, 'en');
      expect(rec.quality, 'noisy');
      expect(rec.clutter, isFalse);
      expect(SmartSort.render(rec, tr), 'Ders kaydı');
      expect(SmartSort.render(rec, en), 'Lecture recording');

      final weak = SmartSort.fromAnswers(
        e,
        DecisionResult([
          choice('sub_audio', 'music', 0.2),
          choice('speech_lang', 'tr', 0.3),
          choice('quality', 'poor', 0.4),
        ]),
      )!;
      expect(weak.sub, '');
      expect(weak.lang, '');
      expect(weak.quality, '');
      expect(SmartSort.render(weak, tr), 'Ses kaydı');
      expect(SmartSort.fromAnswers(e, const DecisionResult([])), isNull);

      SmartSort.debugReset([rec]);
      expect(SmartSort.keywordsOf(e.path), contains('ingilizce'));
      expect(SmartSort.matches('ingilizce ders').map((r) => r.path), [e.path]);
      expect(SmartSort.needs(e), isFalse, reason: 'aynı dosya yeniden sorulmaz');
      SmartSort.debugReset();
    });

    test('video: yanlışlıkla çekilmiş → Ayıkla; aile videosuna ad yok', () {
      final e = entry('/s/WhatsApp/Media/WhatsApp Video/v.mp4', 100);
      final junk = SmartSort.fromAnswers(
        e,
        DecisionResult([
          choice('sub_video', 'family_video', 0.9),
          yes('accidental', 0.9),
          // Videoda dil/kalite sorulmaz; gelse de alınmaz.
          choice('speech_lang', 'tr', 0.9),
        ]),
        today: today,
      )!;
      expect(junk.cat, SmartTaxonomy.video);
      expect(junk.accidental, isTrue);
      expect(junk.lang, '');
      expect(junk.clutterReason, 'accidental');
      expect(SmartSort.render(junk, tr), '');

      final screen = SmartSort.fromAnswers(
        entry('/s/Download/s.mp4', 100),
        DecisionResult([
          choice('sub_video', 'screen_recording', 0.8),
          yes('accidental', 0.2),
        ]),
      )!;
      expect(screen.clutter, isFalse);
      expect(SmartSort.render(screen, tr), 'Ekran kaydı');

      SmartSort.debugReset([junk, screen]);
      expect(SmartSort.clutter().map((r) => r.path), [e.path]);
      SmartSort.debugReset();
    });

    test('JSON: yeni alanlar gidiş-dönüş; eski kayıt bozulmaz', () {
      const r = SmartRecord(
          path: '/a.ogg', size: 5, modifiedMs: 6, cat: 'audio', conf: 1,
          sub: 'voice_note', lang: 'tr', quality: 'clear', asked: 20000);
      final back = SmartRecord.fromJson(jsonDecode(jsonEncode(r.toJson())))!;
      expect(back.lang, 'tr');
      expect(back.quality, 'clear');
      expect(back.sub, 'voice_note');
      final old = SmartRecord.fromJson(
          {'p': '/b.pdf', 's': 1, 'm': 2, 'c': 'invoice', 'lg': 5})!;
      expect(old.lang, '', reason: 'türü bozuk alan boş sayılır');
      expect(old.quality, '');
      expect(r.toJson().containsKey('lg'), isTrue);
      expect(old.toJson().containsKey('lg'), isFalse);
    });
  });

  group('video = yalnız kapak karesi (2026-11-22)', () {
    test('kare görsel blok olarak satır içi gider, kare silinir; yükleme yok',
        () async {
      SmartSortInput.videoCoverOnly = true;
      final frame = File('${tmp.path}/kare.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1, 2, 3]);
      final video = File('${tmp.path}/v.mp4')
        ..writeAsBytesSync(List.filled(64, 7));
      SmartSortInput.coverFrame = (_) async => frame.path;
      SmartSortInput.clipVideo =
          (_) async => throw StateError('kesit çağrılmamalı');
      GeminiService.debugClient =
          MockClient((_) async => throw StateError('ağ çağrılmamalı'));
      final prep = await SmartSortInput.prepare(
          entry(video.path, 200 * 1024 * 1024), const ['k1', 'k2']);
      expect(prep.block['type'], 'image');
      expect(prep.block['mime_type'], 'image/jpeg');
      expect(prep.block['data'], base64Encode(const [0xFF, 0xD8, 0xFF, 1, 2, 3]));
      expect(prep.keys, ['k1', 'k2']);
      expect(frame.existsSync(), isFalse);
    });

    test('kare alınamazsa gönderilmez (durum -1, tur durmaz)', () async {
      SmartSortInput.videoCoverOnly = true;
      SmartSortInput.coverFrame = (_) async => null;
      final video = File('${tmp.path}/v.mp4')..writeAsBytesSync([1]);
      await expectLater(
        SmartSortInput.prepare(entry(video.path, 1), const ['k']),
        throwsA(isA<GeminiException>()
            .having((e) => e.statusCode, 'statusCode', -1)),
      );
    });
  });

  group('maliyet güvenliği varsayılanları', () {
    test('varsayılan allowAudioFilesUpload=false iken >512KB ses metaText gider',
        () async {
      SmartSortInput.allowAudioFilesUpload = false;
      final audio = File('${tmp.path}/kayit.mp3')
        ..writeAsBytesSync(List.filled(64, 1));
      GeminiService.debugClient =
          MockClient((_) async => throw StateError('ağ çağrılmamalı'));
      final prep = await SmartSortInput.prepare(
        entry(audio.path, 20 * 1024 * 1024),
        const ['k1'],
      );
      expect(prep.remote, isNull);
      expect(prep.block['type'], 'text');
      expect(prep.block['text'], contains('kayit.mp3'));
    });

    test('>400KB taranmış PDF asla ham application/pdf olarak gitmez',
        () async {
      final doc = sfpdf.PdfDocument()..pages.add();
      final base = Uint8List.fromList(await doc.save());
      doc.dispose();
      // 400 KB üstüne tamamlamak için yasal PDF sonuna yorum dolgusu ekle.
      final padLen = SmartSortInput.maxInlineScannedPdfBytes + 4096 - base.length;
      final bigPdfBytes = Uint8List.fromList([
        ...base,
        ...utf8.encode('\n%${'0' * (padLen > 0 ? padLen : 1024)}\n'),
      ]);
      final bigPdf = File('${tmp.path}/tarama_buyuk.pdf')
        ..writeAsBytesSync(bigPdfBytes);

      final fakeJpg = imglib.encodeJpg(imglib.Image(width: 16, height: 16));
      SmartSortInput.scannedPdfFirstPageRaster = (_) async =>
          Uint8List.fromList(fakeJpg);
      final imgBlock = await SmartSortInput.blockFor(
          entry(bigPdf.path, bigPdfBytes.length));
      expect(imgBlock['type'], 'image');
      expect(imgBlock['mime_type'], 'image/jpeg');

      // Rasterizer düşerse çok MB base64 PDF yerine ucuz meta yazısına düşer.
      SmartSortInput.scannedPdfFirstPageRaster = (_) async => null;
      final fallbackBlock = await SmartSortInput.blockFor(
          entry(bigPdf.path, bigPdfBytes.length));
      expect(fallbackBlock['type'], 'text');
      expect(fallbackBlock['text'], contains('tarama_buyuk.pdf'));
    });
  });
}
