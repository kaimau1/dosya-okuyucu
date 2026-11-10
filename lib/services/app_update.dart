import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_version.dart';
import 'fm/native_extras.dart';
import 'fm/storage_permission.dart';
import 'offline_mode.dart';

/// GitHub'daki en son sürüm (yalnız bizim APK'mız).
class AppUpdateInfo {
  final String version;
  final String url;
  final int size;

  /// Son kullanıcı sürüm notu (sürüm gövdesindeki `<!-- notlar -->` kısmı).
  final String notes;
  const AppUpdateInfo(
      {required this.version,
      required this.url,
      required this.size,
      this.notes = ''});
}

/// **GitHub'dan otomatik güncelleme** (2026-11-09 kullanıcı isteği: *"Gitten
/// oto güncelleme getirelim, yeni sürüm gelince oto güncellensin"*).
///
/// Akış: açılıştan sonra (en çok 6 saatte bir) `releases/latest` sorulur;
/// `dosya-okuyucu-v<ANA.ARA.YAMA>.apk` bu kurulumdan yeniyse arka planda
/// uygulamanın önbelleğine indirilir (boyut denetimli), sonra sistem
/// kurucusuna verilir. Android 12+'da uygulama kendi kurulumunun sahibiyse
/// onay penceresi ÇIKMADAN kurulur; değilse sistem tek dokunuşluk "Güncelle"
/// sorar — bu Android'in kuralı, atlatılamaz.
///
/// **Kurulum anı:** iş ortasında (belge düzenlerken) süreç kapanmasın diye
/// indirme bitince kurulum HEMEN değil, bir sonraki açılışta (kullanıcı
/// henüz bir şey açmamışken) ya da kullanıcı "Şimdi güncelle" deyince başlar.
///
/// Atlanan durumlar: çevrimdışı kip, ayar kapalı, geliştirici derlemesi
/// (yama 0), `okuyucu` derlemesi (kurulum izni yok), Android dışı.
abstract final class AppUpdate {
  static const repo = 'kaimau1/dosya-okuyucu';
  static const _prefAuto = 'app_update_auto';
  static const _prefLastCheck = 'app_update_last_check';

  /// Kullanıcının sistem penceresinde vazgeçtiği sürüm: açılışta yeniden
  /// sorulmaz (Ayarlar'daki "Şimdi güncelle" yine kurar).
  static const _prefDeclined = 'app_update_declined';

  /// "Yenilikler" (2026-11-10): indirilen sürümün notu saklanır; o sürüm
  /// kurulup uygulama ilk açıldığında bir kez gösterilir.
  static const _prefNotesVersion = 'app_update_notes_v';
  static const _prefNotes = 'app_update_notes';
  static const _prefNotesSeen = 'app_update_notes_seen';
  static const checkEvery = Duration(hours: 6);

  /// Kişisel derleme `kisisel` ön-sürümünü izler; genel sürüm kişisel
  /// özellikleri (arka planda görünürlük) silerdi.
  static const personalBuild =
      String.fromEnvironment('DOSYA_KISISEL') == '1';

  /// Kurulmayı bekleyen sürüm (indirildi), arayüz için.
  static final ready = ValueNotifier<AppUpdateInfo?>(null);

  /// İndirme yüzdesi (0–100), indirme yoksa null.
  static final progress = ValueNotifier<int?>(null);

  static Future<bool> autoEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefAuto) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAutoEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAuto, on);
  }

  /// `1.2.10` → (1, 2, 10); bozuksa null.
  @visibleForTesting
  static List<int>? parseVersion(String v) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(v.trim());
    if (m == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  /// [remote] [local]'den yeni mi? (ANA, ARA, YAMA sırasıyla.)
  @visibleForTesting
  static bool isNewer(String remote, String local) {
    final r = parseVersion(remote), l = parseVersion(local);
    if (r == null || l == null) return false;
    for (var i = 0; i < 3; i++) {
      if (r[i] != l[i]) return r[i] > l[i];
    }
    return false;
  }

  /// Sürüm JSON'undan bizim APK'yı seçer (`dosya-okuyucu-v1.2.3.apk`).
  @visibleForTesting
  static AppUpdateInfo? pickAsset(Object? release) {
    if (release is! Map || release['assets'] is! List) return null;
    final re = RegExp(r'^dosya-okuyucu-v(\d+\.\d+\.\d+)\.apk$');
    AppUpdateInfo? best;
    for (final a in release['assets'] as List) {
      if (a is! Map) continue;
      final m = re.firstMatch('${a['name'] ?? ''}');
      final url = a['browser_download_url'];
      if (m == null || url is! String) continue;
      final info = AppUpdateInfo(
          version: m.group(1)!,
          url: url,
          size: (a['size'] as num?)?.toInt() ?? 0,
          notes: AppUpdate.extractNotes(release['body']));
      if (best == null || isNewer(info.version, best.version)) best = info;
    }
    if (best != null) return best;
    // Yedek: sürümlü dosya yoksa sabit `dosya-okuyucu.apk` + başlıktaki
    // sürüm ("Dosya Okuyucu nightly v1.2.12").
    final title = RegExp(r'v(\d+\.\d+\.\d+)\s*$')
        .firstMatch('${release['name'] ?? ''}'.trim());
    if (title == null) return null;
    for (final a in release['assets'] as List) {
      if (a is! Map || a['name'] != 'dosya-okuyucu.apk') continue;
      final url = a['browser_download_url'];
      if (url is! String) continue;
      return AppUpdateInfo(
          version: title.group(1)!,
          url: url,
          size: (a['size'] as num?)?.toInt() ?? 0,
          notes: AppUpdate.extractNotes(release['body']));
    }
    return null;
  }

  static bool get supported =>
      !kIsWeb &&
      Platform.isAndroid &&
      appVersionPatch > 0 &&
      !StoragePermission.readerBuild;

  /// En son sürümü sorar; bu kurulumdan yeni değilse null.
  static Future<AppUpdateInfo?> check() async {
    if (OfflineMode.enabled) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
          Uri.parse(personalBuild
              ? 'https://api.github.com/repos/$repo/releases/tags/kisisel'
              : 'https://api.github.com/repos/$repo/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'dosya-okuyucu-guncelleme')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != HttpStatus.ok) return null;
      final info = pickAsset(jsonDecode(body));
      if (info == null || !isNewer(info.version, appVersionName)) return null;
      if (info.notes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefNotesVersion, info.version);
        await prefs.setString(_prefNotes, info.notes);
      }
      return info;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> _fileFor(AppUpdateInfo info) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'guncelleme'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'dosya-okuyucu-v${info.version}.apk'));
  }

  /// APK'yı indirir (varsa ve boyu tutuyorsa yeniden indirmez).
  static Future<File?> download(AppUpdateInfo info) async {
    final file = await _fileFor(info);
    if (await file.exists() && info.size > 0 && await file.length() == info.size) {
      return file;
    }
    final part = File('${file.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    progress.value = 0;
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      req.headers.set(HttpHeaders.userAgentHeader, 'dosya-okuyucu-guncelleme');
      final res = await req.close();
      if (res.statusCode != HttpStatus.ok) return null;
      final total = info.size > 0 ? info.size : res.contentLength;
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) progress.value = (got * 100 ~/ total).clamp(0, 100).toInt();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (total > 0 && got != total) {
        await part.delete().catchError((_) => part);
        return null;
      }
      if (await file.exists()) await file.delete();
      return await part.rename(file.path);
    } catch (_) {
      return null;
    } finally {
      progress.value = null;
      client.close(force: true);
    }
  }

  /// İndirilmiş APK'yı kurar. Sonuç: `done` · `aborted` · `need_permission`
  /// · `error:…` · null (kanal yok).
  static Future<String?> install(AppUpdateInfo info) async {
    final file = await _fileFor(info);
    if (!await file.exists()) return 'missing';
    return NativeExtras.installPackageFile(file.path, selfUpdate: true);
  }

  /// Önbellekte bu sürümden yeni, tam inmiş bir APK var mı?
  static Future<AppUpdateInfo?> _pending() async {
    try {
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'guncelleme'));
      if (!await dir.exists()) return null;
      AppUpdateInfo? best;
      await for (final e in dir.list()) {
        final m = RegExp(r'dosya-okuyucu-v(\d+\.\d+\.\d+)\.apk$').firstMatch(e.path);
        if (e is! File || m == null) continue;
        final v = m.group(1)!;
        if (!isNewer(v, appVersionName)) {
          // Kurulmuş ya da eski: yer kaplamasın.
          await e.delete().catchError((_) => e);
          continue;
        }
        if (best == null || isNewer(v, best.version)) {
          best = AppUpdateInfo(version: v, url: '', size: await e.length());
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// Sürüm gövdesinden son kullanıcı notunu düz metin olarak çıkarır:
  /// `<!-- notlar -->` … `<!-- /notlar -->` arası (tool/surum_notu.sh);
  /// `### ✨ Yenilikler` başlıkları `✨ Yenilikler` olur, maddeler `• `.
  static String extractNotes(Object? body) {
    if (body is! String) return '';
    final start = body.indexOf('<!-- notlar -->');
    final end = body.indexOf('<!-- /notlar -->');
    if (start < 0 || end <= start) return '';
    final lines = body
        .substring(start + '<!-- notlar -->'.length, end)
        .split('\n')
        .map((l) => l.trimRight())
        .map((l) => l.startsWith('### ')
            ? l.substring(4)
            : (l.startsWith('- ') ? '• ${l.substring(2)}' : l))
        .toList();
    return lines.join('\n').trim();
  }

  /// Bu sürüm kurulduktan sonraki ilk açılışta gösterilecek not (bir kez).
  static Future<String?> takeWhatsNew() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefNotesVersion) != appVersionName) return null;
      if (prefs.getString(_prefNotesSeen) == appVersionName) return null;
      final notes = prefs.getString(_prefNotes) ?? '';
      await prefs.setString(_prefNotesSeen, appVersionName);
      return notes.isEmpty ? null : notes;
    } catch (_) {
      return null;
    }
  }

  /// Açılış işi: bekleyen indirme varsa kur; yoksa (süresi geldiyse) denetle,
  /// yeniyse indir ve [onReady] ile haber ver.
  static Future<void> runOnStartup(
      {void Function(AppUpdateInfo info)? onReady,
      void Function(String notes)? onWhatsNew}) async {
    if (!supported) return;
    final news = await takeWhatsNew();
    if (news != null) onWhatsNew?.call(news);
    if (OfflineMode.enabled || !await autoEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = await _pending();
    if (pending != null) {
      ready.value = pending;
      if (prefs.getString(_prefDeclined) == pending.version) return;
      final result = await install(pending);
      if (result == 'aborted') {
        await prefs.setString(_prefDeclined, pending.version);
      }
      return;
    }
    final last = prefs.getInt(_prefLastCheck) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < checkEvery.inMilliseconds) return;
    await prefs.setInt(_prefLastCheck, now);
    try {
      final info = await check();
      if (info == null) return;
      final file = await download(info);
      if (file == null) return;
      ready.value = info;
      onReady?.call(info);
    } catch (_) {
      // Ağ yok / GitHub yanıtsız: bir sonraki açılışta yeniden denenir.
    }
  }
}
