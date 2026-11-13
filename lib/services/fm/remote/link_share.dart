import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../offline_mode.dart';
import '../drive_service.dart';
import '../file_ops.dart';
import '../fs_events.dart';
import 'peer_crypto.dart';
import 'zip_stream.dart';

/// **"Bağlantıyla gönder"** (2026-11-13 kullanıcı isteği; aynı Wi-Fi şartı
/// olmadan, internet üzerinden).
///
/// Akış: dosya telefonda [LinkCipher] ile şifrelenir (Aktar'ın kayıt biçimi,
/// [peer_crypto.dart]) → gönderenin KENDİ Google Drive'ına yüklenir (anlamsız
/// adla: `dosya-aktar-<rastgele>.dok`) → "bağlantıya sahip herkes okuyabilir"
/// izni → bağlantı + anahtar QR ve sistem paylaşımıyla verilir.
///
/// ## Anahtar sunucuya gitmez
/// Bağlantı `https://drive.google.com/file/d/<kimlik>/view#dosya-aktar=<anahtar>`:
/// anahtar `#` sonrasında (URL parçası). Tarayıcılar parçayı sunucuya
/// göndermez; Google yalnız şifreli kabı görür. Bağlantıyı ele geçiren dosyayı
/// açabilir — bu yüzden gönderen "Bağlantıyı iptal et" ile Drive'dan siler.
///
/// ## Alıcı nasıl indirir (2026-11-13 doğrulandı, Drive v3 belgesi)
/// Resmî yol `files.get?alt=media` — oturum (OAuth) ya da Cloud projesine
/// bağlı API anahtarı İSTER; API anahtarı konsol işi olduğu için yok.
/// 1. Alıcı uygulamada Drive'a bağlıysa: KENDİ oturumuyla resmî API
///    (herkese açık dosyayı her Google hesabı okuyabilir).
/// 2. Değilse: Drive'ın web indirme adresi ([DriveService.publicDownloadUri]),
///    oturumsuz. Resmî API değil; Google değiştirirse dönen gövde HTML olur →
///    kabın imzası tutmaz → arayüz "Drive ile bağlan" der.
///
/// HAFIZA §4'teki "aktarımda üçüncü taraf yükleme reddedildi (gizlilik)"
/// kararının istisnası: içerik uçtan uca şifreli + gönderenin kendi hesabı
/// (kullanıcı onayı 2026-11-13).
class LinkTicket {
  final String fileId;
  final Uint8List key;

  const LinkTicket(this.fileId, this.key);

  static const fragmentKey = 'dosya-aktar';

  String toUrl() =>
      'https://drive.google.com/file/d/$fileId/view#$fragmentKey=${base64Url.encode(key).replaceAll('=', '')}';

  static final _idPath = RegExp(r'/file/d/([A-Za-z0-9_-]{10,})');
  static final _idQuery = RegExp(r'[?&]id=([A-Za-z0-9_-]{10,})');
  static final _keyPart = RegExp('$fragmentKey=([A-Za-z0-9_-]{43})');

  /// Yapıştırılan metinden (WhatsApp iletisi, QR) bileti çıkarır; yoksa null.
  static LinkTicket? parse(String text) {
    final id = _idPath.firstMatch(text)?.group(1) ?? _idQuery.firstMatch(text)?.group(1);
    final k = _keyPart.firstMatch(text)?.group(1);
    if (id == null || k == null) return null;
    try {
      final key = base64Url.decode('$k=');
      if (key.length != 32) return null;
      return LinkTicket(id, key);
    } catch (_) {
      return null;
    }
  }
}

/// Kap biçimi bozuk ya da bu bir Aktar kabı değil (ör. Drive HTML sayfası).
class LinkFormatError implements Exception {
  const LinkFormatError();
}

/// Şifreli kap: `DOAKLNK1` (8 bayt) ‖ kayıtlar. Kayıt 0 = üstveri JSON
/// `{n: ad, s: boyut}`, sonrakiler dosyanın baytları; sonuncusu "son"
/// işaretli. Anahtar dosya başına rastgele → akış numarası 0 güvenli.
abstract final class LinkCipher {
  static final magic = Uint8List.fromList(utf8.encode('DOAKLNK1'));
  static final _aad = utf8.encode('DOAKLNK1');

  static Uint8List _meta(String name, int size) =>
      Uint8List.fromList(utf8.encode(jsonEncode({'n': name, 's': size})));

  /// Kabın toplam boyu (yükleme `Content-Length`'i).
  static int sealedLength(String name, int size) =>
      magic.length +
      SealedChunks.overhead +
      _meta(name, size).length +
      SealedChunks.sealedLength(size);

  static Stream<List<int>> seal(
      Stream<List<int>> plain, Uint8List key, String name, int size,
      {Aead? aead}) async* {
    final sealer = ChunkSealer(key, 0, aad: _aad, aead: aead);
    yield magic;
    yield await sealer.seal(_meta(name, size), last: false);
    yield* sealer.sealStream(plain);
  }

  /// İmzayı (ilk 8 bayt) doğrular, gerisini verir.
  static Stream<List<int>> _strip(Stream<List<int>> raw) async* {
    final head = BytesBuilder(copy: false);
    var checked = false;
    await for (final c in raw) {
      if (checked) {
        yield c;
        continue;
      }
      head.add(c);
      if (head.length < magic.length) continue;
      final all = head.takeBytes();
      if (!listEquals(all.sublist(0, magic.length), magic)) {
        throw const LinkFormatError();
      }
      checked = true;
      if (all.length > magic.length) yield all.sublist(magic.length);
    }
    if (!checked) throw const LinkFormatError();
  }

  /// Kabı açıp [dir] içine yazar; yazılan dosyanın yolunu döner. Yarıda
  /// kalırsa / anahtar yanlışsa yarım dosya SİLİNİR, istisna fırlar.
  static Future<String> open(Stream<List<int>> raw, Uint8List key, String dir,
      {Aead? aead, void Function(int done, int total)? onProgress}) async {
    final reader = RecordReader(_strip(raw));
    final opener = ChunkOpener(key, 0, aad: _aad, aead: aead);
    final head = await opener.next(reader);
    final meta = jsonDecode(utf8.decode(head.payload));
    if (meta is! Map || head.last) throw const LinkFormatError();
    final name = FileOps.sanitizeName('${meta['n'] ?? ''}');
    final size = (meta['s'] as num?)?.toInt() ?? -1;
    await Directory(dir).create(recursive: true);
    final part = File(p.join(dir, '.dosya-aktar-baglanti-${DateTime.now().microsecondsSinceEpoch}'));
    var done = 0;
    final sink = part.openWrite();
    try {
      await sink.addStream(opener.rest(reader).map((c) {
        done += c.length;
        onProgress?.call(done, size);
        return c;
      }));
      await sink.flush();
      await sink.close();
      if (size >= 0 && done != size) throw const AeadFailure('boy');
      final target =
          FileOps.uniquePath(p.join(dir, name.isEmpty ? 'dosya' : name));
      await part.rename(target);
      return target;
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {
        // Bilinçli: zaten kapalı.
      }
      try {
        await part.delete();
      } catch (_) {
        // Bilinçli: temizlik — yarım dosya kalmasın; silinemezse yapılacak bir şey yok.
      }
      rethrow;
    }
  }
}

/// Gönderilmiş bir bağlantı (cihazda saklanır: iptal + yeniden paylaşım için).
class SentLink {
  final String fileId;
  final String name;
  final int size;
  final DateTime at;
  final String url;

  const SentLink(this.fileId, this.name, this.size, this.at, this.url);

  Map<String, Object> toJson() =>
      {'id': fileId, 'n': name, 's': size, 't': at.millisecondsSinceEpoch, 'u': url};

  static SentLink? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['u'] is! String) return null;
    return SentLink(
      raw['id'] as String,
      '${raw['n'] ?? ''}',
      (raw['s'] as num?)?.toInt() ?? 0,
      DateTime.fromMillisecondsSinceEpoch((raw['t'] as num?)?.toInt() ?? 0),
      raw['u'] as String,
    );
  }
}

/// Bağlantıyla gönder / al — durum + gönderilenler listesi.
class LinkShare extends ChangeNotifier {
  LinkShare._();
  static final instance = LinkShare._();

  static const _key = 'aktar_baglanti_v1';

  @visibleForTesting
  DriveService drive = DriveService();

  @visibleForTesting
  Aead? aead;

  final List<SentLink> _items = [];
  Future<void>? _loading;

  List<SentLink> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() => _loading ??= () async {
        try {
          final raw = (await SharedPreferences.getInstance()).getString(_key);
          if (raw == null) return;
          _items
            ..clear()
            ..addAll((jsonDecode(raw) as List).map(SentLink.fromJson).whereType<SentLink>());
          notifyListeners();
        } catch (_) {
          // Bozuk kayıt: liste boş başlar (Drive'daki dosyalar yerinde kalır).
        }
      }();

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, jsonEncode([for (final e in _items) e.toJson()]));
    } catch (_) {
      // Bilinçli: kalıcı kayıt yazılamadı — bellekteki liste geçerli kalır.
    }
  }

  /// Drive oturumu: yoksa giriş penceresi açılır. Olmazsa [DriveException].
  Future<void> _ensureSignedIn() async {
    if (await drive.signInSilently()) return;
    final r = await drive.signIn();
    if (!r.success) throw const DriveException(DriveError.notSignedIn);
  }

  /// [paths]'i şifreleyip Drive'a yükler (birden çok dosya/klasör tek ZIP
  /// olur), herkese okunur yapar ve bağlantıyı döner.
  Future<SentLink> send(List<String> paths,
      {void Function(int done, int total)? onProgress}) async {
    if (paths.isEmpty) throw ArgumentError('boş');
    NetGuard.allow('link_share');
    await ensureLoaded();
    await _ensureSignedIn();
    final String name;
    final int size;
    final Stream<List<int>> plain;
    final single = paths.length == 1 && await FileSystemEntity.isFile(paths.first);
    if (single) {
      name = p.basename(paths.first);
      size = await File(paths.first).length();
      plain = File(paths.first).openRead();
    } else {
      final zip = await ZipStream.of(paths);
      if (zip == null) throw const LinkFormatError();
      name = paths.length == 1 ? '${p.basename(paths.first)}.zip' : 'dosyalar.zip';
      size = zip.length;
      plain = zip.open();
    }
    final key = PeerIdentity.randomSeed();
    final total = LinkCipher.sealedLength(name, size);
    var done = 0;
    final body = LinkCipher.seal(plain, key, name, size, aead: aead).map((c) {
      done += c.length;
      onProgress?.call(done, total);
      return c;
    });
    final file = await drive.uploadStream(body, total,
        name: 'dosya-aktar-${_randomName()}.dok',
        appProperties: const {'dosyaAktar': '1'});
    await drive.allowAnyoneRead(file.id);
    final link = SentLink(file.id, name, size, DateTime.now(),
        LinkTicket(file.id, key).toUrl());
    _items.insert(0, link);
    notifyListeners();
    await _save();
    return link;
  }

  /// Drive'daki ad içerik hakkında bir şey söylemesin.
  static String _randomName() =>
      PeerIdentity.fingerprintOf(PeerIdentity.randomSeed()).substring(0, 12);

  /// Bağlantıyı iptal eder: Drive'daki şifreli kap silinir (bağlantı ölür).
  Future<void> revoke(SentLink link) async {
    NetGuard.allow('link_share');
    await _ensureSignedIn();
    try {
      await drive.delete(link.fileId);
    } on DriveException catch (e) {
      // Zaten silinmiş (Drive'dan elle): listeden yine çıkar.
      if (e.error != DriveError.notFound) rethrow;
    }
    _items.removeWhere((e) => e.fileId == link.fileId);
    notifyListeners();
    await _save();
  }

  /// Bağlantıdaki dosyayı indirip çözer, [dir]'e yazar; yolu döner.
  /// Drive oturumu varsa resmî API, yoksa oturumsuz web indirmesi; ikincisi
  /// Aktar kabı vermezse [LinkFormatError] (arayüz: "Drive ile bağlan").
  Future<String> receive(LinkTicket ticket, String dir,
      {void Function(int done, int total)? onProgress}) async {
    NetGuard.allow('link_share');
    final signedIn = await drive.signInSilently();
    final client = http.Client();
    try {
      final res = await drive.openMedia(ticket.fileId, signedIn: signedIn, client: client);
      final path = await LinkCipher.open(
          res.stream.timeout(const Duration(minutes: 2)), ticket.key, dir,
          aead: aead, onProgress: onProgress);
      FsEvents.changed([path]);
      return path;
    } finally {
      client.close();
    }
  }

  @visibleForTesting
  void debugReset() {
    _items.clear();
    _loading = null;
  }
}
