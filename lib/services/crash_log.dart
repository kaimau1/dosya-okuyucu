import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// **Çökme/hata günlüğü — cihazda, gönderimsiz.**
///
/// ## Kök neden (2026-08-28 durum değerlendirmesi)
/// Uygulama GitHub Releases üzerinden dağıtılıyor ve **hiçbir hata bildirimi
/// yoktu**: kullanıcının telefonunda bir çökme olduğunda bunu öğrenmenin bir
/// yolu yoktu. Tüm doğrulama "cihaz doğrulaması (kullanıcı)" maddelerine
/// (KALANLAR'da ~27 tane) bağlıydı; yani tek bir telefona. Ölçek büyüyünce bu
/// model çöker ve hata, mağaza yorumu olarak geri döner.
///
/// ## Niçin Crashlytics/Sentry DEĞİL (şimdilik)
/// İkisi de bir sunucu ucu ister: Crashlytics `google-services.json` (depoda
/// yok, uygulama yerel modda çalışıyor — bkz. `firebase_service.dart`),
/// Sentry ise bir DSN. Üstelik yeni bir paket, pubspec'teki sürüm duvarını
/// (Flutter 3.29.3) zorlayacak bir bağımlılık daha demek. Bu katman **sıfır
/// bağımlılıkla** geri bildirim döngüsünü bugün açar: kullanıcı çökmeden sonra
/// Ayarlar > Hata kayıtları'ndan raporu görüp **kendi isteğiyle** paylaşır.
/// Uzak bir uç (Crashlytics/Sentry) eklenince buraya bir "gönderici" takılır;
/// yakalama ve biçim aynı kalır.
///
/// ## Gizlilik sözü — burada tutuluyor
/// - Kayıt **yalnız cihazda** durur (uygulamanın özel dizini).
/// - Hiçbir ağ isteği YOK; paylaşmak kullanıcının tek tek yaptığı bir eylemdir
///   ve paylaşmadan önce metnin tamamını ekranda görür.
/// - Dosya adları/yollar hata metninde geçebileceği için ekran ham metni
///   gösterir — kullanıcı ne paylaştığını bilmeden paylaşmasın.
abstract final class CrashLog {
  static const _fileName = 'crash_log.json';

  /// En fazla kaç kayıt tutulur (en yenisi başta). Sınır YOKSA dosya sessizce
  /// büyür: bir çizim hatası saniyede onlarca kez tekrarlanabilir.
  static const maxRecords = 20;

  /// Tek bir yığın izinin kırpılma sınırı. Flutter yığınları 200+ satır
  /// olabiliyor; ilk satırlar hatanın nerede olduğunu zaten söyler.
  static const maxStackLines = 40;

  /// Testler için dizin geçersiz kılma (üretimde daima null).
  @visibleForTesting
  static String? dirOverride;

  static String? _dir;
  static bool _installed = false;

  /// Uygulama sürümü — raporun tek başına anlamlı olması için (kullanıcı
  /// "hangi sürümde" sorusuna cevap veremez). `pubspec.yaml`taki `version:`
  /// ile aynı tutulmalı.
  static const appVersion = '0.1.0';

  /// Yakalayıcıları kurar. `main()`in en başında, `runApp`tan ÖNCE çağrılır.
  ///
  /// İki ayrı kanal var ve ikisi de gerekli:
  /// - [FlutterError.onError] — çizim/yerleşim ve widget yaşam döngüsü hataları
  ///   (framework'ün kendi yakaladıkları).
  /// - [PlatformDispatcher.onError] — kök zondaki yakalanmamış **asenkron**
  ///   hatalar (bir `Future` hata verip kimse dinlemediğinde). `runZonedGuarded`
  ///   yerine bu seçildi: Flutter 3.10+'ta önerilen yol ve `main()`i bir zona
  ///   sarmak, testlerde ve `WidgetsFlutterBinding` ilklendirmesinde bilinen
  ///   tuzaklar üretiyor.
  ///
  /// Önceki işleyiciler **korunur** (debug'da konsola basan varsayılan
  /// davranış kaybolmamalı — yoksa geliştirme sırasında hata görünmez olurdu).
  static void install() {
    if (_installed) return;
    _installed = true;
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(record(details.exception, details.stack,
          context: details.context?.toDescription(), kind: 'flutter'));
      previousFlutterError?.call(details);
    };
    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error, stack, kind: 'async'));
      // `true` = "hata ele alındı". Önceki işleyici varsa onun kararına
      // uyulur; yoksa true döneriz — false, süreci sonlandırabilir.
      return previousPlatformError?.call(error, stack) ?? true;
    };
  }

  /// Bir hatayı kaydeder. **Hiçbir koşulda fırlatmaz:** hata kaydedicinin
  /// kendisi hata verirse (disk dolu, izin yok) uygulamayı çökertmek en kötü
  /// sonuç olurdu.
  static Future<void> record(Object error, StackTrace? stack,
      {String? context, String kind = 'error'}) async {
    try {
      final dir = await _resolveDir();
      if (dir == null) return;
      final records = await load();
      final entry = CrashRecord(
        time: DateTime.now(),
        kind: kind,
        error: _clip(error.toString(), 1000),
        stack: _trimStack(stack),
        context: context == null ? null : _clip(context, 200),
      );
      // Aynı hata art arda tekrarlıyorsa (çizim döngüsü) yeni satır açmak
      // yerine sayacı artır — 20 kaydın hepsi aynı hatayla dolmasın.
      if (records.isNotEmpty &&
          records.first.error == entry.error &&
          records.first.stack == entry.stack) {
        records[0] = records.first.repeated(entry.time);
      } else {
        records.insert(0, entry);
      }
      final kept = records.take(maxRecords).toList();
      final file = File(p.join(dir, _fileName));
      await file.writeAsString(
          jsonEncode(kept.map((r) => r.toJson()).toList()),
          flush: true);
    } catch (_) {
      // Bilerek yutuluyor (yukarıdaki gerekçe).
    }
  }

  /// Kayıtlar — en yenisi başta. Dosya yoksa/bozuksa boş liste.
  static Future<List<CrashRecord>> load() async {
    try {
      final dir = await _resolveDir();
      if (dir == null) return [];
      final file = File(p.join(dir, _fileName));
      if (!await file.exists()) return [];
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(CrashRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final dir = await _resolveDir();
      if (dir == null) return;
      final file = File(p.join(dir, _fileName));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Yok sayılır — temizleme bir kolaylık, kritik yol değil.
    }
  }

  /// Paylaşılacak/kopyalanacak düz metin. Kullanıcı bunu ekranda AYNEN görür.
  static String asShareText(List<CrashRecord> records) {
    final buffer = StringBuffer()
      ..writeln('Dosya Okuyucu $appVersion — hata kaydı')
      ..writeln('Platform: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}')
      ..writeln('Kayıt sayısı: ${records.length}')
      ..writeln();
    for (final r in records) {
      buffer.writeln(r.asText());
      buffer.writeln('---');
    }
    return buffer.toString();
  }

  static Future<String?> _resolveDir() async {
    if (dirOverride != null) return dirOverride;
    if (_dir != null) return _dir;
    try {
      // `FmEnv.appSupportDir`e BAĞLANMIYOR: o `ensureInit()` beklerken ilk
      // kareden önceki bir çökme kaydedilemezdi.
      return _dir = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      return null;
    }
  }

  static String _trimStack(StackTrace? stack) {
    if (stack == null) return '';
    final lines = stack.toString().split('\n');
    final kept = lines.take(maxStackLines).join('\n');
    return lines.length > maxStackLines
        ? '$kept\n… (${lines.length - maxStackLines} satır daha)'
        : kept;
  }

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}

/// Tek bir hata kaydı.
class CrashRecord {
  final DateTime time;

  /// `flutter` (çizim/widget) · `async` (yakalanmamış Future) · `error` (elle).
  final String kind;
  final String error;
  final String stack;

  /// Framework'ün "hata sırasında ne yapılıyordu" açıklaması.
  final String? context;

  /// Aynı hatanın kaç kez üst üste geldiği (1 = bir kez).
  final int count;

  const CrashRecord({
    required this.time,
    required this.kind,
    required this.error,
    required this.stack,
    this.context,
    this.count = 1,
  });

  CrashRecord repeated(DateTime at) => CrashRecord(
        time: at,
        kind: kind,
        error: error,
        stack: stack,
        context: context,
        count: count + 1,
      );

  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'k': kind,
        'e': error,
        's': stack,
        if (context != null) 'c': context,
        if (count > 1) 'n': count,
      };

  static CrashRecord fromJson(Map<String, dynamic> json) => CrashRecord(
        time: DateTime.tryParse('${json['t']}') ?? DateTime(1970),
        kind: '${json['k'] ?? 'error'}',
        error: '${json['e'] ?? ''}',
        stack: '${json['s'] ?? ''}',
        context: json['c'] as String?,
        count: json['n'] is int ? json['n'] as int : 1,
      );

  String asText() {
    final buffer = StringBuffer()
      ..writeln('[$kind] ${time.toIso8601String()}'
          '${count > 1 ? ' (×$count)' : ''}');
    if (context != null) buffer.writeln('Bağlam: $context');
    buffer.writeln(error);
    if (stack.isNotEmpty) buffer.writeln(stack);
    return buffer.toString();
  }
}
