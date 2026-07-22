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

  String _readError(http.Response resp) => _readErrorStatic(resp);

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}\n…(kısaltıldı)';

  /// Bu API anahtarıyla kullanılabilir modelleri Gemini'den çeker (ListModels).
  /// Yalnızca `generateContent` destekleyenler döner, en yeni/yetenekli
  /// modeller öne gelecek şekilde sıralanır. Anahtar geçersiz/ağ hatasıysa
  /// [GeminiException] fırlatır — çağıran statik yedek listeye düşebilir.
  static Future<List<String>> listModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw GeminiException('API anahtarı boş.');
    }
    late http.Response resp;
    try {
      resp = await http.get(Uri.parse('$_base/models?key=$key&pageSize=200'));
    } catch (e) {
      throw GeminiException('Ağ hatası: $e');
    }
    if (resp.statusCode != 200) {
      throw GeminiException(_readErrorStatic(resp));
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (map['models'] as List?) ?? const [];
    final names = <String>[];
    for (final m in list) {
      if (m is! Map) continue;
      final methods =
          (m['supportedGenerationMethods'] as List?)?.cast<String>() ??
              const [];
      if (!methods.contains('generateContent')) continue;
      final name = m['name'] as String?; // "models/gemini-2.0-flash"
      if (name == null) continue;
      names.add(name.startsWith('models/') ? name.substring(7) : name);
    }
    names.sort(_modelRank);
    return names;
  }

  /// "gemini-2.5-pro" gibi daha yeni/yetenekli modeller listede öne gelsin.
  static int _modelRank(String a, String b) {
    int score(String m) {
      if (m.contains('embedding') || m.contains('aqa')) return 100;
      var s = 0;
      final verMatch = RegExp(r'gemini-(\d+)\.(\d+)').firstMatch(m);
      if (verMatch != null) {
        s -= int.parse(verMatch.group(1)!) * 100 + int.parse(verMatch.group(2)!) * 10;
      }
      if (m.contains('pro')) s -= 3;
      if (m.contains('flash')) s -= 2;
      if (m.contains('lite')) s += 1;
      if (m.contains('exp') || m.contains('preview')) s += 2;
      return s;
    }

    final cmp = score(a).compareTo(score(b));
    return cmp != 0 ? cmp : a.compareTo(b);
  }

  /// `_readError` ile aynı biçim; instance metotları statik `listModels`'tan
  /// da çağrılabilsin diye statik olarak tanımlı.
  static String _readErrorStatic(http.Response resp) {
    try {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = map['error']?['message'];
      if (msg is String) return 'Gemini hatası (${resp.statusCode}): $msg';
    } catch (_) {}
    return 'Gemini hatası (${resp.statusCode}).';
  }
}
