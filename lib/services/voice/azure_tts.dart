import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/private_zone.dart';
import '../key_vault.dart';
import '../offline_mode.dart';

/// **Microsoft Azure konuşma sesleri** — "Ahmet" (`tr-TR-AhmetNeural`)
/// (2026-11-25, kullanıcı: *"seslere haritalardaki Ahmet sesini de ekle"*).
///
/// Ahmet Microsoft'un Türkçe erkek sinir ağı sesi; cihaza indirilebilen bir
/// modeli YOK. Ücretsiz "Edge sesli oku" ucu Edge tarayıcısını taklit eden
/// ödünç bir belirteçle çalışıyor (izinsiz erişim) — o yol BİLEREK
/// kullanılmadı. Bunun yerine resmî Azure Speech REST API'si, kullanıcının
/// KENDİ anahtarıyla (Gemini'deki gibi): Azure'un ücretsiz F0 katmanı ayda
/// 500 bin karakter verir.
///
/// * Anahtar Keystore'la mühürlü saklanır ([KeyVault]); mühür yoksa düz.
/// * İnternet ister, okunan metin Microsoft'a gider (kart bunu yazar);
///   çevrimdışı kipte istek yok. Hata olursa okuma cihaz sesine düşer.
/// * Çıktı MP3 — oynatıcı (ExoPlayer) doğrudan çalar.
abstract final class AzureTts {
  static const _prefSealed = 'azure_tts_key_sealed';
  static const _prefPlain = 'azure_tts_key';
  static const _prefRegion = 'azure_tts_region';

  static const defaultRegion = 'westeurope';

  /// Bir parça için üst süre.
  static const timeout = Duration(seconds: 25);

  static String _key = '';
  static String _region = defaultRegion;
  static bool _loaded = false;

  /// Anahtar girildi mi (ses "kurulu" sayılır). Arayüz dinler.
  static final ValueNotifier<bool> configured = ValueNotifier<bool>(false);

  static String get region => _region;

  /// Tercih okundu mu (arayüz bir kez okutur).
  static bool get loaded => _loaded;

  /// Test kancası.
  @visibleForTesting
  static http.Client? debugClient;

  @visibleForTesting
  static void debugReset() {
    _key = '';
    _region = defaultRegion;
    _loaded = false;
    configured.value = false;
    debugClient = null;
  }

  /// Bölge adı: Azure'un küçük harf/rakam kimliği (`westeurope`).
  static bool validRegion(String r) => RegExp(r'^[a-z0-9]{3,40}$').hasMatch(r);

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sealed = prefs.getString(_prefSealed);
      var key = '';
      if (sealed != null && sealed.isNotEmpty) {
        key = await KeyVault.open(sealed) ?? '';
      }
      if (key.isEmpty) key = prefs.getString(_prefPlain) ?? '';
      _key = key.trim();
      final r = prefs.getString(_prefRegion) ?? defaultRegion;
      _region = validRegion(r) ? r : defaultRegion;
    } catch (_) {
      // Bilinçli: tercih okunamadı — anahtarsız (ses kurulu görünmez).
    }
    _loaded = true;
    configured.value = _key.isNotEmpty;
  }

  /// Anahtarı + bölgeyi yazar; boş anahtar siler.
  static Future<void> save({required String key, required String region}) async {
    final prefs = await SharedPreferences.getInstance();
    final k = key.trim();
    final r = region.trim().toLowerCase().replaceAll(' ', '');
    await prefs.remove(_prefSealed);
    await prefs.remove(_prefPlain);
    if (k.isNotEmpty) {
      final sealed = await KeyVault.seal(k);
      if (sealed != null) {
        await prefs.setString(_prefSealed, sealed);
      } else {
        await prefs.setString(_prefPlain, k);
      }
    }
    _region = validRegion(r) ? r : defaultRegion;
    await prefs.setString(_prefRegion, _region);
    _key = k;
    _loaded = true;
    configured.value = _key.isNotEmpty;
  }

  /// [text]i [voice] (`tr-TR-AhmetNeural`) ile MP3'e (sesli okuma) ya da
  /// [wav] ise 24 kHz 16 bit mono WAV'a (sesli kitap: `Wav.concat` hattı)
  /// çevirir. [rate] ve [pitch] çarpan (1.0 = normal; 0.5–2.0).
  static Future<Uint8List> synthesize(
    String text, {
    required String voice,
    double rate = 1.0,
    double pitch = 1.0,
    bool wav = false,
  }) async {
    if (PrivateZone.active) {
      throw const SocketException('Gizli bölgede bulut sentezi kapalı');
    }
    if (OfflineMode.enabled) {
      throw const SocketException('Çevrimdışı kip açık');
    }
    await load();
    if (_key.isEmpty) throw StateError('Azure konuşma anahtarı girilmemiş');
    final clean = sanitize(text);
    if (clean.isEmpty) return Uint8List(0);
    final client = debugClient ?? http.Client();
    try {
      final resp = await client
          .post(
            Uri.https('$_region.tts.speech.microsoft.com', '/cognitiveservices/v1'),
            headers: {
              'Ocp-Apim-Subscription-Key': _key,
              'Content-Type': 'application/ssml+xml',
              'X-Microsoft-OutputFormat': wav
                  ? 'riff-24khz-16bit-mono-pcm'
                  : 'audio-24khz-48kbitrate-mono-mp3',
              'User-Agent': 'DosyaOkuyucu',
            },
            body: utf8.encode(ssml(clean, voice: voice, rate: rate, pitch: pitch)),
          )
          .timeout(timeout);
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        throw HttpException('Azure konuşma hatası (${resp.statusCode})');
      }
      return resp.bodyBytes;
    } finally {
      if (debugClient == null) client.close();
    }
  }

  /// SSML gövdesi. Saf → testli.
  static String ssml(
    String text, {
    required String voice,
    double rate = 1.0,
    double pitch = 1.0,
  }) {
    final lang = voice.length >= 5 ? voice.substring(0, 5) : 'tr-TR';
    final r = ((rate.clamp(0.5, 2.0) - 1) * 100).round();
    final pt = ((pitch.clamp(0.5, 2.0) - 1) * 50).round();
    String sign(int v) => v >= 0 ? '+$v' : '$v';
    return "<speak version='1.0' xml:lang='$lang'>"
        "<voice name='$voice'>"
        "<prosody rate='${sign(r)}%' pitch='${sign(pt)}%'>"
        '${escape(text)}'
        '</prosody></voice></speak>';
  }

  /// XML kaçışı.
  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Sunucunun reddettiği denetim karakterleri boşluğa çevrilir.
  static String sanitize(String s) => s
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
