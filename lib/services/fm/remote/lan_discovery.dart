import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import '../../../models/remote_connection.dart';

/// Yerel ağda bulunan bir sunucu adayı.
class LanHost {
  final String host;
  final int port;
  final RemoteProtocol protocol;

  /// mDNS'ten gelen okunur ad ("Synology"); yoksa adresin kendisi.
  final String name;

  const LanHost({
    required this.host,
    required this.port,
    required this.protocol,
    required this.name,
  });

  String get key => '$host:$port:${protocol.name}';
}

/// Yerel ağdaki NAS/paylaşım sunucularını bulur.
///
/// **İki yöntem birlikte, çünkü tek başına ikisi de yetmiyor:**
/// 1. **mDNS/Bonjour** — Synology/QNAP/Samba kendini `_smb._tcp` gibi
///    servislerle duyurur. Adı ve portu doğrudan verir ama duyuru yapmayan
///    (ya da mDNS'i kapalı) sunucuyu bulamaz. Android'de bazı ROM'lar
///    çoklu yayını kısıtlar.
/// 2. **Alt ağ port taraması** — cihazın kendi IPv4'ünden /24 alt ağı çıkarıp
///    bilinen portlara TCP bağlantısı dener. Duyuru yapmayan sunucuyu da
///    bulur; karşılığında yavaş, o yüzden eşzamanlı ve kısa zaman aşımlı.
///
/// Sonuçlar **akış** olarak veriliyor: kullanıcı 254 adresin bitmesini
/// beklemeden ilk bulunanı görüyor (tarama uzun sürerse "hiçbir şey yok"
/// sanılırdı).
class LanDiscovery {
  /// Taranan portlar ve karşılık gelen protokol.
  static const probes = <int, RemoteProtocol>{
    445: RemoteProtocol.smb,
    22: RemoteProtocol.sftp,
    21: RemoteProtocol.ftp,
    5005: RemoteProtocol.webdav,
    5006: RemoteProtocol.webdav,
  };

  /// mDNS servis adı → protokol.
  static const mdnsServices = <String, RemoteProtocol>{
    '_smb._tcp': RemoteProtocol.smb,
    '_sftp-ssh._tcp': RemoteProtocol.sftp,
    '_ftp._tcp': RemoteProtocol.ftp,
    '_webdav._tcp': RemoteProtocol.webdav,
    '_webdavs._tcp': RemoteProtocol.webdav,
  };

  /// `192.168.1.37` → `192.168.1.` (tarama öneki). IPv4 olmayan ya da
  /// beklenmedik biçimde null.
  static String? subnetPrefix(String ipv4) {
    final parts = ipv4.split('.');
    if (parts.length != 4) return null;
    if (parts.any((p) => int.tryParse(p) == null)) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.';
  }

  /// Cihazın yerel ağ IPv4 adresleri (geri döngü ve bağlantı-yerel hariç).
  ///
  /// `169.254.` (APIPA) elenir: o adres "DHCP bulunamadı" demektir, o alt ağı
  /// taramak boşa 254 bağlantı denemesidir.
  static Future<List<String>> localIPv4s() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.address.startsWith('169.254.')) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Tek bir adres:port canlı mı?
  static Future<bool> probe(String host, int port,
      {Duration timeout = const Duration(milliseconds: 400)}) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// mDNS ile duyuru yapan sunucular.
  static Stream<LanHost> discoverMdns({
    Duration timeout = const Duration(seconds: 4),
  }) async* {
    final client = MDnsClient();
    try {
      await client.start();
      for (final entry in mdnsServices.entries) {
        await for (final ptr in client
            .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(entry.key))
            .timeout(timeout, onTimeout: (sink) => sink.close())) {
          await for (final srv in client
              .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName))
              .timeout(timeout, onTimeout: (sink) => sink.close())) {
            await for (final ip in client
                .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target))
                .timeout(timeout, onTimeout: (sink) => sink.close())) {
              yield LanHost(
                host: ip.address.address,
                port: srv.port,
                protocol: entry.value,
                name: _friendlyName(ptr.domainName, ip.address.address),
              );
            }
          }
        }
      }
    } catch (_) {
      // Çoklu yayın kısıtlı ROM / izin yok: sessizce port taramasına kalır.
    } finally {
      try {
        client.stop();
      } catch (_) {}
    }
  }

  /// `Synology._smb._tcp.local` → `Synology`.
  static String _friendlyName(String domainName, String fallback) {
    final cut = domainName.indexOf('._');
    final name = cut > 0 ? domainName.substring(0, cut) : domainName;
    return name.trim().isEmpty ? fallback : name.replaceAll(r'\032', ' ');
  }

  /// Alt ağ port taraması. [concurrency] aynı anda kaç adres denensin —
  /// telefonda çok yüksek değer soket sınırına takılıyor.
  static Stream<LanHost> discoverSubnet({
    int concurrency = 32,
    Duration timeout = const Duration(milliseconds: 400),
  }) async* {
    final ips = await localIPv4s();
    final prefixes = <String>{};
    for (final ip in ips) {
      final prefix = subnetPrefix(ip);
      if (prefix != null) prefixes.add(prefix);
    }
    for (final prefix in prefixes) {
      final self = ips.where((ip) => ip.startsWith(prefix)).toSet();
      final targets = [
        for (var i = 1; i <= 254; i++)
          if (!self.contains('$prefix$i')) '$prefix$i',
      ];
      for (var start = 0; start < targets.length; start += concurrency) {
        final batch = targets.sublist(
            start, (start + concurrency).clamp(0, targets.length));
        final found = await Future.wait([
          for (final host in batch) _probeHost(host, timeout),
        ]);
        for (final hosts in found) {
          for (final host in hosts) {
            yield host;
          }
        }
      }
    }
  }

  static Future<List<LanHost>> _probeHost(String host, Duration timeout) async {
    final out = <LanHost>[];
    for (final entry in probes.entries) {
      if (await probe(host, entry.key, timeout: timeout)) {
        out.add(LanHost(
          host: host,
          port: entry.key,
          protocol: entry.value,
          name: host,
        ));
        // Bir makinede birden çok protokol açık olabilir; hepsini listeleriz
        // ki kullanıcı SFTP'yi FTP'ye tercih edebilsin.
      }
    }
    return out;
  }

  /// İkisini birlikte koşturur; aynı `host:port:protokol` iki kez verilmez.
  static Stream<LanHost> discover() async* {
    final seen = <String>{};
    await for (final host in discoverMdns()) {
      if (seen.add(host.key)) yield host;
    }
    await for (final host in discoverSubnet()) {
      if (seen.add(host.key)) yield host;
    }
  }
}
