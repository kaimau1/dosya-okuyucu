import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatTurn {
  final bool fromUser;
  final String text;
  ChatTurn({required this.fromUser, required this.text});
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Gemini REST API istemcisi (google_generative_ai paketine bağımlı değil).
class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({required this.apiKey, required this.model});

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  Uri _endpoint() =>
      Uri.parse('$_base/models/$model:generateContent?key=$apiKey');

  /// Sohbet geçmişi + opsiyonel dosya bağlamı + kalıcı hafıza ile yanıt üretir.
  Future<String> chat({
    required List<ChatTurn> history,
    String? fileContext,
    List<String> memory = const [],
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException('Önce Ayarlar > API anahtarı bölümünden '
          'Gemini API anahtarınızı girin.');
    }

    final systemParts = <String>[
      'Sen "Dosya Okuyucu" uygulamasının içindeki yardımcı bir yapay zekasın. '
          'Türkçe, kısa ve net yanıt ver. Kullanıcının açtığı dosyalar üzerinde '
          'okuma, özetleme, analiz ve düzenleme önerileri yapabilirsin.',
    ];
    if (memory.isNotEmpty) {
      systemParts.add('Kalıcı hafızandaki notlar:\n- ${memory.join('\n- ')}');
    }
    if (fileContext != null && fileContext.trim().isNotEmpty) {
      systemParts.add('Şu an açık olan dosyanın içeriği (bağlam):\n'
          '"""\n${_truncate(fileContext, 24000)}\n"""');
    }

    final contents = history
        .map((t) => {
              'role': t.fromUser ? 'user' : 'model',
              'parts': [
                {'text': t.text}
              ],
            })
        .toList();

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemParts.join('\n\n')}
        ]
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.4},
    };

    late http.Response resp;
    try {
      resp = await http.post(
        _endpoint(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }

    if (resp.statusCode != 200) {
      throw GeminiException(_readError(resp));
    }

    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = map['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final block = map['promptFeedback']?['blockReason'];
      throw GeminiException(block != null
          ? 'Yanıt engellendi: $block'
          : 'Model boş yanıt döndürdü.');
    }
    final parts =
        (candidates.first['content']?['parts'] as List?) ?? const [];
    final text = parts
        .map((p) => p is Map && p['text'] != null ? p['text'] as String : '')
        .join();
    return text.trim().isEmpty ? '(Boş yanıt)' : text.trim();
  }

  String _readError(http.Response resp) {
    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = map['error']?['message'];
      if (msg is String) return 'Gemini hatası (${resp.statusCode}): $msg';
    } catch (_) {}
    return 'Gemini hatası (${resp.statusCode}).';
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}\n…(kısaltıldı)';
}
