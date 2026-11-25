import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_mode.dart';

/// Yapay zekâ isteğinin kaynağı (`dosya okuyucu`).
///
/// Açık geçiş zorunludur: kullanıcı [AiSourceMode.byok] seçtiyse kendi API
/// anahtarı 401/403/429 verse bile asla sessizce [AiSourceMode.sharedPool]'a
/// geçilmez (0-fallback kuralı).
enum AiSourceMode {
  byok,
  sharedPool;

  static AiSourceMode fromId(String? raw, {bool hasOwnKey = true}) =>
      switch (raw) {
        'sharedPool' => AiSourceMode.sharedPool,
        'byok' => AiSourceMode.byok,
        // Güvenlik: bilinmeyen/boş kip ASLA sessizce ortak havuza düşmez.
        _ => AiSourceMode.byok,
      };
}

enum SharedAiPoolErrorKind {
  unauthenticated,
  insufficientCredits,
  byokExhausted,
  rateLimited,
  unavailable,
}

class SharedAiPoolException implements Exception {
  const SharedAiPoolException(this.kind, [this.message = '']);

  final SharedAiPoolErrorKind kind;
  final String message;

  @override
  String toString() => 'SharedAiPoolException(${kind.name}: $message)';
}

@immutable
class SharedAiPoolStatus {
  const SharedAiPoolStatus({
    required this.balance,
    required this.starterGranted,
    required this.apps,
  });

  final int balance;
  final bool starterGranted;
  final List<String> apps;
}

/// Saf HTTP (sıfır Firebase SDK) Ortak AI Havuzu istemcisi.
///
/// Notlar backend'inin `sharedAiPoolStatus` ve `sharedAiPoolGenerate` Cloud
/// Functions v2 uçlarına Google OAuth kimlik belirteci ile doğrudan bağlanır.
class SharedAiPoolClient {
  SharedAiPoolClient({http.Client? client, Uri? baseUri})
    : httpClient = client,
      baseUri = baseUri ?? Uri.parse(defaultBaseUrl);

  static const String appId = 'dosya_okuyucu';
  static const int starterCredits = 500;
  static const String defaultBaseUrl = String.fromEnvironment(
    'NOTLAR_AI_POOL_URL',
    defaultValue: 'https://us-central1-notlar-app.cloudfunctions.net',
  );

  static const String modePrefsKey = 'ai_source_mode';
  static const String balancePrefsKey = 'shared_ai_pool_balance_v1';

  final http.Client? httpClient;
  final Uri baseUri;
  int? _knownBalance;

  int? get knownBalance => _knownBalance;

  @visibleForTesting
  void setKnownBalanceForTest(int? balance) => _knownBalance = balance;

  /// Güvenlik kuralı: BYOK kipinde 401/403/429 gelirse ortak havuza DÜŞÜLMEZ.
  static Never guardByokFailure({
    required AiSourceMode mode,
    required int statusCode,
  }) {
    if (mode == AiSourceMode.byok &&
        (statusCode == 401 || statusCode == 403 || statusCode == 429)) {
      throw SharedAiPoolException(
        SharedAiPoolErrorKind.byokExhausted,
        'status:$statusCode',
      );
    }
    throw SharedAiPoolException(
      SharedAiPoolErrorKind.unavailable,
      'status:$statusCode',
    );
  }

  static Future<AiSourceMode> loadMode({bool hasOwnKey = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return AiSourceMode.fromId(
      prefs.getString(modePrefsKey),
      hasOwnKey: hasOwnKey,
    );
  }

  static Future<void> saveMode(AiSourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modePrefsKey, mode.name);
  }

  static Future<int?> loadCachedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(balancePrefsKey);
  }

  static Future<void> saveCachedBalance(int balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(balancePrefsKey, balance);
  }

  Uri _endpoint(String fnName) => baseUri.replace(
    path:
        '${baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path}/$fnName',
  );

  Future<Map<String, dynamic>> _postCallable(
    String fnName, {
    required String? idToken,
    required Map<String, dynamic> data,
  }) async {
    final token = idToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const SharedAiPoolException(SharedAiPoolErrorKind.unauthenticated);
    }
    final uri = _endpoint(fnName);
    OfflineMode.check(uri);

    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    try {
      final res = await client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const SharedAiPoolException(
          SharedAiPoolErrorKind.unauthenticated,
        );
      }

      Map<String, dynamic> body = const {};
      if (res.bodyBytes.isNotEmpty) {
        try {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          } else if (decoded is Map) {
            body = {for (final e in decoded.entries) '${e.key}': e.value};
          }
        } catch (_) {
          // Hata durumlarında gövde ayrıştırılamayabilir.
        }
      }

      final errorObj = body['error'];
      if (errorObj is Map) {
        final status = '${errorObj['status'] ?? ''}'.toUpperCase();
        final msg = '${errorObj['message'] ?? ''}';
        if (status == 'UNAUTHENTICATED' || status == 'PERMISSION_DENIED') {
          throw SharedAiPoolException(
            SharedAiPoolErrorKind.unauthenticated,
            msg,
          );
        }
        if (status == 'RESOURCE_EXHAUSTED') {
          throw SharedAiPoolException(
            msg == 'rate-limited'
                ? SharedAiPoolErrorKind.rateLimited
                : SharedAiPoolErrorKind.insufficientCredits,
            msg,
          );
        }
        throw SharedAiPoolException(SharedAiPoolErrorKind.unavailable, msg);
      }

      if (res.statusCode == 429) {
        throw const SharedAiPoolException(SharedAiPoolErrorKind.rateLimited);
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw SharedAiPoolException(
          SharedAiPoolErrorKind.unavailable,
          'http:${res.statusCode}',
        );
      }

      final result = body['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is Map) {
        return {for (final e in result.entries) '${e.key}': e.value};
      }
      return body;
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<SharedAiPoolStatus> fetchStatus({required String? idToken}) async {
    final result = await _postCallable(
      'sharedAiPoolStatus',
      idToken: idToken,
      data: const {'appId': appId},
    );
    final bal = (result['balance'] as num?)?.toInt() ?? 0;
    _knownBalance = bal;
    final rawApps = result['apps'];
    final apps = rawApps is List
        ? [for (final a in rawApps) '$a']
        : const ['notlar', 'dosya_okuyucu'];
    return SharedAiPoolStatus(
      balance: bal,
      starterGranted: result['starterGranted'] == true,
      apps: apps,
    );
  }

  Future<({String text, int remainingCredits, int cost})> generate({
    required AiSourceMode mode,
    required String? idToken,
    required List<Map<String, dynamic>> contents,
    String model = 'gemini-2.5-flash',
    Map<String, dynamic>? generationConfig,
    String? integrityToken,
    bool requireIntegrity = false,
  }) async {
    if (mode != AiSourceMode.sharedPool) {
      throw const SharedAiPoolException(
        SharedAiPoolErrorKind.byokExhausted,
        'byok-mode-no-fallback',
      );
    }
    final cleanIntegrity = integrityToken?.trim() ?? '';
    if (requireIntegrity && cleanIntegrity.isEmpty) {
      throw const SharedAiPoolException(
        SharedAiPoolErrorKind.unauthenticated,
        'missing-integrity-token',
      );
    }
    // 0-bakiye koruma duvarı: bilinen bakiye <= 0 ise HİÇ ağ isteği atılmaz.
    if (_knownBalance != null && _knownBalance! <= 0) {
      throw const SharedAiPoolException(
        SharedAiPoolErrorKind.insufficientCredits,
        'cached-zero-balance',
      );
    }
    try {
      final result = await _postCallable(
        'sharedAiPoolGenerate',
        idToken: idToken,
        data: {
          'appId': appId,
          'model': model,
          'contents': contents,
          if (generationConfig != null) 'generationConfig': generationConfig,
          if (cleanIntegrity.isNotEmpty) 'integrityToken': cleanIntegrity,
        },
      );
      final text = (result['text'] as String? ?? '').trim();
      final rem =
          (result['remainingCredits'] as num?)?.toInt() ?? _knownBalance ?? 0;
      final cost = (result['cost'] as num?)?.toInt() ?? 1;
      _knownBalance = rem;
      return (text: text, remainingCredits: rem, cost: cost);
    } on SharedAiPoolException catch (e) {
      if (e.kind == SharedAiPoolErrorKind.insufficientCredits) {
        _knownBalance = 0;
      }
      rethrow;
    }
  }
}
