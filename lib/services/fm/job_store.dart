import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';
import 'job_queue.dart';

/// [JobQueue]'nun **diske yazma** gerçekleştirmesi.
///
/// ## Niye var (kullanıcı hatası 2026-07-31)
/// *"İşlemler menüsünde birkaç işlem yapılıyor diyelim, uygulamayı 1-2 kez alta
/// alıp yeniden üste aldığımda … diğer tüm işlemler kayboluyor, boşa yapmış
/// oluyorum."*
///
/// Kök neden **iptal mantığı değildi** (bir işi durdurmanın ötekilere
/// dokunmadığı `test/fm_job_queue_test.dart`te kilitli): kuyruk **yalnız
/// bellekteydi**. Android arka plandaki süreci öldürünce — özellikle son iş
/// bitip ön plan servisi kapandıktan sonra, ki o an süreç korumasız kalıyor —
/// listedeki her şey, kullanıcının henüz görmediği SONUÇLAR dahil, izsiz yok
/// oluyordu. Uygulama geri gelince İşlemler ekranı bomboştu ve yapılan iş
/// gerçekten boşa gitmiş gibi görünüyordu.
///
/// ## Ne kaydedilir, ne kaydedilmez
/// İşin **hikâyesi** kaydedilir: ne yapıldı, hangi durumda bitti, ne kadar
/// sürdü, hangi dosyaları üretti, dokununca nereye gidilir. Kaydedilmeyen iki
/// şey var ve ikisi de kaydedilemez:
/// - `FmJob.result` — rastgele bir Dart nesnesi (tarama grupları). Sonucu
///   gereken ekranlar zaten "sonuç yoksa yeniden tara" diye yazılmış.
/// - iş gövdesi (closure) — bu yüzden yarıda kalan iş kendiliğinden devam
///   ETMEZ; [JobStatus.interrupted] damgalanır ve karta dokunmak kullanıcıyı
///   işin ekranına götürür, tarama oradan yeniden başlar.
///
/// ## Niye kısılmış yazma
/// İlerleme saniyede ~7 kez bildiriliyor; her birinde JSON yazmak diski
/// döverdi. Yazma [_gap] kadar geciktirilir ve aradaki tüm değişiklikler tek
/// yazmada birleşir. Durum değişimleri (başladı/bitti/iptal) da aynı yoldan
/// geçer — en fazla [_gap] kadar geriden gelir, ki süreç ölümünde kaybedilecek
/// en kötü şey birkaç saniyelik ilerleme metnidir.
class JobStore implements JobPersistence {
  static const _fileName = 'jobs.json';
  static const _gap = Duration(seconds: 2);

  /// Diskte tutulacak en fazla iş. `JobQueue.historyLimit` zaten listeyi
  /// kırpıyor; bu ikinci kemer, bozuk/şişmiş bir dosyanın açılışı
  /// yavaşlatmasını engeller.
  static const maxSaved = 60;

  Timer? _pending;
  List<Map<String, Object?>>? _latest;
  bool _writing = false;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Önceki oturumdan kalan işler. Dosya yoksa/bozuksa boş liste — kayıt
  /// okunamadı diye uygulamanın açılmaması saçma olurdu.
  static Future<List<FmJob>> load() async {
    if (FmEnv.appSupportDir.isEmpty) return const [];
    try {
      final file = File(_path);
      if (!file.existsSync()) return const [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (FmJob.fromJson(item) case final job?) job,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  void save(List<FmJob> jobs) {
    // Anlık görüntü ŞİMDİ alınır: yazma gecikirken liste değişebilir ve
    // `jobs` canlı listenin ta kendisi (yazarken değişirse tutarsız JSON).
    final trimmed =
        jobs.length > maxSaved ? jobs.sublist(jobs.length - maxSaved) : jobs;
    _latest = [for (final job in trimmed) job.toJson()];
    if (_pending?.isActive ?? false) return;
    _pending = Timer(_gap, _flush);
  }

  Future<void> _flush() async {
    final snapshot = _latest;
    _latest = null;
    if (snapshot == null || FmEnv.appSupportDir.isEmpty) return;
    if (_writing) {
      // Yazma sürerken gelen değişiklik kaybolmasın: sıradaki tura bırakılır.
      _latest = snapshot;
      _pending = Timer(_gap, _flush);
      return;
    }
    _writing = true;
    try {
      final file = File(_path);
      // Geçici dosya + rename: yazma ortasında süreç ölürse (ki tam olarak
      // korktuğumuz şey bu) yarım JSON kalmaz, eski kayıt bozulmadan durur.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(snapshot), flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // Disk dolu / izin yok: iş kuyruğu çalışmaya devam etsin, kalıcılık bir
      // güvence ağı, işin kendisi ona bağlı değil.
    } finally {
      _writing = false;
    }
  }

  /// Bekleyen yazmayı hemen boşaltır (test ve kapanış için).
  Future<void> flushNow() async {
    _pending?.cancel();
    _pending = null;
    await _flush();
  }
}
