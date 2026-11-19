import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'gemini_service.dart';

/// **Gemini Decisions API** istemcisi (2026-11-18, kullanıcı: *"Gemini yeni
/// bir model çıkarmış, AI özelliklerimizde en iyi şekilde değerlendirelim"*).
///
/// `gemini-decision-1` kapalı uçlu soruları — evet/hayır (`noul`), çoktan
/// seçmeli (`choice`), ölçek (`score`) — PDF, görsel, ses, video ve yazı
/// üzerinde **tek geçişte** puanlar: ayrı OCR/döküm adımı yok, çıktı belirteci
/// sıfır (yalnız girdi ücretli), yanıt ~150–250 ms. Üretken modelden farkı:
/// yanıt serbest metin değil olasılık; "uydurma" riski yok, sonuç her zaman
/// verilen seçeneklerden biri ve güven yüzdesiyle gelir.
///
/// Uygulamadaki yeri: dosya menüsünde **"AI ile hızlı kontrol"** — belge
/// imzalı mı, kişisel veri var mı, belge türü ne, okunaklı mı… Sohbet/özet
/// gibi serbest metin işleri üretken modelde kalır.
///
/// Gövde biçimi (REST başvurusu): `{model, input: [blok], questions: {id: …}}`;
/// blok `{type: text|image|audio|video|document, data(base64)|text, mime_type}`.
abstract final class GeminiDecisions {
  static const model = 'gemini-decision-1';

  /// Satır içi (base64) gönderilebilecek en büyük dosya. Gemini satır içi
  /// istek sınırı ~20 MB; base64 şişmesi (×4/3) payı bırakıldı.
  static const maxInlineBytes = 14 * 1024 * 1024;

  /// Tek istekte en çok soru (API 1000'e izin veriyor; ekran için bol).
  static const maxQuestions = 40;

  /// Uzantı → (blok türü, MIME). Desteklenmeyen uzantı `null`.
  static ({String type, String mime})? mediaFor(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'pdf' => (type: 'document', mime: 'application/pdf'),
      'jpg' || 'jpeg' => (type: 'image', mime: 'image/jpeg'),
      'png' => (type: 'image', mime: 'image/png'),
      'webp' => (type: 'image', mime: 'image/webp'),
      'heic' => (type: 'image', mime: 'image/heic'),
      'heif' => (type: 'image', mime: 'image/heif'),
      'gif' => (type: 'image', mime: 'image/gif'),
      'mp3' => (type: 'audio', mime: 'audio/mp3'),
      'wav' => (type: 'audio', mime: 'audio/wav'),
      'm4a' || 'aac' => (type: 'audio', mime: 'audio/aac'),
      'ogg' || 'opus' => (type: 'audio', mime: 'audio/ogg'),
      'flac' => (type: 'audio', mime: 'audio/flac'),
      'mp4' || 'm4v' => (type: 'video', mime: 'video/mp4'),
      'webm' => (type: 'video', mime: 'video/webm'),
      'mov' => (type: 'video', mime: 'video/quicktime'),
      '3gp' => (type: 'video', mime: 'video/3gpp'),
      'mkv' => (type: 'video', mime: 'video/x-matroska'),
      _ => null,
    };
  }

  /// Dosyayı bloğa çevirir. Desteklenmeyen tür ya da çok büyükse
  /// [GeminiException] (kullanıcıya gösterilecek metinle).
  static Future<Map<String, Object?>> fileBlock(String path,
      {String tooLarge = 'Dosya çok büyük.',
      String unsupported = 'Bu dosya türü desteklenmiyor.'}) async {
    final media = mediaFor(path);
    if (media == null) throw GeminiException(unsupported, statusCode: -1);
    final file = File(path);
    if (await file.length() > maxInlineBytes) {
      throw GeminiException(tooLarge, statusCode: -1);
    }
    return {
      'type': media.type,
      'mime_type': media.mime,
      // B1 m.5: okuma + base64 (≤ 14 MB → ~19 MB yazı) izolatta; ana
      // izlek yalnız sonucu alır.
      'data': await _base64Of(path),
    };
  }

  static Future<String> _base64Of(String path) =>
      Isolate.run(() => base64Encode(File(path).readAsBytesSync()));

  /// Satır içi verisi bu kadar karakteri aşan gövde izolatta kodlanır.
  static const isolateEncodeChars = 256 * 1024;

  /// İstek gövdesinin JSON yazısı. Satır içi (base64) verisi büyükse
  /// [jsonEncode] izolatta (her karakter kaçış için taranır — 19 MB'ta
  /// ana izlekte onlarca ms); sonuç kopyasız döner.
  static Future<String> encodeBody(
    List<Map<String, Object?>> input,
    List<DecisionQuestion> questions,
  ) {
    final b = body(input, questions);
    var inline = 0;
    for (final block in input) {
      final d = block['data'];
      if (d is String) inline += d.length;
    }
    if (inline <= isolateEncodeChars) return Future.value(jsonEncode(b));
    return _encodeOffMain(b);
  }

  static Future<String> _encodeOffMain(Map<String, Object?> b) =>
      Isolate.run(() => jsonEncode(b));

  /// Yazı bloğu (`text` alanı kişisel veri maskesinden geçer).
  static Map<String, Object?> textBlock(String text) =>
      {'type': 'text', 'text': text};

  /// İstek gövdesi (test edilebilir, saf).
  static Map<String, Object?> body(
    List<Map<String, Object?>> input,
    List<DecisionQuestion> questions,
  ) =>
      {
        'model': model,
        'input': input,
        'questions': {
          for (final q in questions.take(maxQuestions)) q.id: q.toJson(),
        },
      };

  /// Soruları sorar. Anahtarlar sırayla denenir: kota (429) ya da yetki
  /// (401/403) hatasında sıradaki anahtara geçilir.
  static Future<DecisionResult> ask({
    required List<String> keys,
    required List<Map<String, Object?>> input,
    required List<DecisionQuestion> questions,
  }) async {
    final clean = [
      for (final k in keys)
        if (k.trim().isNotEmpty) k.trim()
    ];
    if (clean.isEmpty) {
      throw GeminiException('Önce Ayarlar > API anahtarı bölümünden '
          'Gemini API anahtarınızı girin.');
    }
    if (questions.isEmpty) throw GeminiException('Soru yok.', statusCode: -1);
    final payload = await encodeBody(input, questions);
    GeminiException? last;
    for (final key in clean) {
      final http.Response resp;
      try {
        resp = await GeminiService.postDecision(key, payload);
      } on GeminiException {
        rethrow;
      } catch (e) {
        throw GeminiException('Ağ hatası: $e');
      }
      if (resp.statusCode == 200) {
        return DecisionResult.parse(utf8.decode(resp.bodyBytes), questions);
      }
      last = GeminiException(GeminiService.readError(resp),
          statusCode: resp.statusCode);
      if (!const {401, 403, 429}.contains(resp.statusCode)) break;
    }
    throw last!;
  }
}

/// Soru türü (API adlarıyla).
enum DecisionKind { noul, choice, score }

/// Tek soru. [options]: `choice` için kimlik → açıklama; `score` için
/// düşükten yükseğe düzey açıklamaları (değerler sırayla 0, 1, 2…).
class DecisionQuestion {
  final String id;
  final DecisionKind kind;
  final String instructions;

  /// Kullanıcıya görünen başlık (ör. "İmzalı mı?").
  final String label;
  final Map<String, String> options;
  final List<String> levels;
  final String? trueText;
  final String? falseText;

  const DecisionQuestion.yesNo(this.id, this.label, this.instructions,
      {this.trueText, this.falseText})
      : kind = DecisionKind.noul,
        options = const {},
        levels = const [];

  const DecisionQuestion.choice(
      this.id, this.label, this.instructions, this.options)
      : kind = DecisionKind.choice,
        levels = const [],
        trueText = null,
        falseText = null;

  const DecisionQuestion.score(
      this.id, this.label, this.instructions, this.levels)
      : kind = DecisionKind.score,
        options = const {},
        trueText = null,
        falseText = null;

  Map<String, Object?> toJson() => switch (kind) {
        DecisionKind.noul => {
            'type': 'noul',
            'instructions': instructions,
            if (trueText != null && falseText != null)
              'criteria': {
                'true_description': trueText,
                'false_description': falseText,
              },
          },
        DecisionKind.choice => {
            'type': 'choice',
            'instructions': instructions,
            'criteria': options,
          },
        DecisionKind.score => {
            'type': 'score',
            'instructions': instructions,
            'criteria': levels,
          },
      };
}

/// Tek yanıt.
class DecisionAnswer {
  final DecisionQuestion question;

  /// `noul`: P(evet) 0–1.
  final double? yes;

  /// `choice`: seçilen seçenek kimliği.
  final String? choice;

  /// `score`: olasılık ağırlıklı beklenen değer (0 … düzey-1).
  final double? score;

  /// Modelin güveni (0–1).
  final double confidence;

  const DecisionAnswer({
    required this.question,
    this.yes,
    this.choice,
    this.score,
    this.confidence = 0,
  });

  bool get isYes => (yes ?? 0) >= 0.5;

  /// `score` için en yakın düzeyin açıklaması.
  String? get levelText {
    final s = score;
    final levels = question.levels;
    if (s == null || levels.isEmpty) return null;
    return levels[s.round().clamp(0, levels.length - 1)];
  }

  /// `choice` için seçeneğin açıklaması.
  String? get choiceText => choice == null ? null : question.options[choice];
}

class DecisionResult {
  final List<DecisionAnswer> answers;

  /// İçerik güvenlik nedeniyle engellendiyse dolu.
  final String? blockReason;

  /// Faturalanan girdi belirteci (yanıtın `usage` alanından; gelmediyse
  /// null). Decisions'ta çıktı belirteci yok.
  final int? inputTokens;

  const DecisionResult(this.answers, {this.blockReason, this.inputTokens});

  static double? _num(Object? v) => v is num ? v.toDouble() : null;

  /// `usage` / `usage_metadata` / `usageMetadata` içinden girdi belirteci
  /// (alan adları API sürümüne göre değişebilir; bilinmeyen biçim null).
  static int? usageTokens(Map<Object?, Object?> data) {
    final u = data['usage'] ?? data['usage_metadata'] ?? data['usageMetadata'];
    if (u is! Map) return null;
    for (final k in const [
      'input_tokens',
      'inputTokens',
      'prompt_token_count',
      'promptTokenCount',
      'total_tokens',
      'totalTokenCount',
    ]) {
      final v = u[k];
      if (v is num) return v.toInt();
    }
    return null;
  }

  /// Yanıt gövdesini çözer; soruların sırası korunur, yanıtı gelmeyen soru
  /// listeden düşer.
  static DecisionResult parse(String raw, List<DecisionQuestion> questions) {
    final Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      throw GeminiException('Model yanıtı okunamadı.');
    }
    if (data is! Map) throw GeminiException('Model yanıtı okunamadı.');
    final feedback = data['prompt_feedback'] ?? data['promptFeedback'];
    final block = feedback is Map
        ? (feedback['block_reason'] ?? feedback['blockReason'])
        : null;
    final answers = data['answers'];
    final out = <DecisionAnswer>[];
    if (answers is Map) {
      for (final q in questions) {
        final a = answers[q.id];
        if (a is! Map) continue;
        final choice = a['choice'];
        out.add(DecisionAnswer(
          question: q,
          yes: _num(a['noul']),
          choice: choice is String ? choice : null,
          score: _num(a['score']),
          confidence: _num(a['confidence']) ?? 0,
        ));
      }
    }
    return DecisionResult(out,
        blockReason: block is String ? block : null,
        inputTokens: usageTokens(data));
  }
}
